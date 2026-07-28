local Constants = require("src.core.constants")
local Stable = require("src.core.stable")
local Profiles = require("src.core.interactions.init")
local Shared = require("src.core.interactions.shared")

local Interaction = {}

local FEATURE_PROFILES = {
  { Constants.FEATURE.CATWALK, "goon-catwalk-v1" },
  { Constants.FEATURE.CHAIR, "goon-chair-v1" },
  { Constants.FEATURE.CRATE, "goon-crate-v1" },
  { Constants.FEATURE.DECAL, "goon-decal-v1" },
  { Constants.FEATURE.DISPOSAL, "goon-disposal-v1" },
  { Constants.FEATURE.GRILLE, "goon-grille-v1" },
  { Constants.FEATURE.LATTICE, "goon-lattice-v1" },
  { Constants.FEATURE.LIGHT, "goon-light-v1" },
  { Constants.FEATURE.PIPE, "goon-pipe-v1" },
  { Constants.FEATURE.SIGN, "goon-sign-v1" },
  { Constants.FEATURE.STORAGE, "goon-storage-v1" },
  { Constants.FEATURE.TABLE, "goon-table-v1" },
  { Constants.FEATURE.WINDOW, "goon-window-v1" },
}

local TURF_PROFILES = {
  [Constants.TURF.SPACE] = "goon-space-v1",
  [Constants.TURF.PLATING] = "goon-plating-v1",
  [Constants.TURF.FLOOR] = "goon-floor-v1",
  [Constants.TURF.REINFORCED_FLOOR] = "goon-reinforced-floor-v1",
}

local PROFILE_FAMILIES = {
  ["goon-floor-v1"] = {
    "goon-floor-v1",
    "goon-plating-v1",
    "goon-reinforced-floor-v1",
  },
  ["goon-plating-v1"] = {
    "goon-plating-v1",
    "goon-floor-v1",
    "goon-reinforced-floor-v1",
  },
  ["goon-reinforced-floor-v1"] = {
    "goon-reinforced-floor-v1",
    "goon-floor-v1",
    "goon-plating-v1",
  },
  ["goon-reinforced-wall-v1"] = {
    "goon-reinforced-wall-v1",
    "goon-wall-v1",
  },
  ["goon-wall-v1"] = {
    "goon-wall-v1",
    "goon-reinforced-wall-v1",
  },
}

local GENERIC_HANDLERS = {
  ["common.inspect"] = function()
    return true
  end,
}

local function normalize_target(simulation, target)
  if type(target) ~= "table"
    or (target.kind ~= nil and target.kind ~= "tile")
  then
    return nil, Shared.rejection("unsupported")
  end
  local world = simulation and simulation.world
  if not world then
    return nil, Shared.rejection("unsupported")
  end
  local index = target.index
  if index == nil
    and type(target.x) == "number"
    and type(target.y) == "number"
  then
    index = world:index(target.x, target.y)
  end
  if type(index) ~= "number"
    or index % 1 ~= 0
    or index < 1
    or index > world.size
  then
    return nil, Shared.rejection("outside-map")
  end
  local x, y = world:coordinates(index)
  return {
    kind = "tile",
    index = index,
    x = x,
    y = y,
    world = world,
  }
end

local function target_profiles(target)
  local world = target.world
  local index = target.index
  local result = {}
  local function append_profile(profile)
    local family = PROFILE_FAMILIES[profile] or { profile }
    for family_index = 1, #family do
      result[#result + 1] = family[family_index]
    end
  end
  local structure = world.structure[index]
  if structure == Constants.STRUCTURE.DOOR_CLOSED
    or structure == Constants.STRUCTURE.DOOR_OPEN
  then
    result[1] = "goon-airlock-v1"
    return result
  end
  for feature_index = 1, #FEATURE_PROFILES do
    local record = FEATURE_PROFILES[feature_index]
    if world:has_feature(index, record[1]) then
      result[#result + 1] = record[2]
    end
  end
  if structure == Constants.STRUCTURE.WALL then
    append_profile(
      world.wall_kind[index] == Constants.WALL.REINFORCED
          and "goon-reinforced-wall-v1"
        or "goon-wall-v1"
    )
    return result
  end
  append_profile(
    TURF_PROFILES[world.turf_kind[index]] or "goon-space-v1"
  )
  return result
end

local function content_definitions(simulation)
  local result = {}
  local values = simulation.content
    and simulation.content.by_kind
    and simulation.content.by_kind.structure
    or {}
  for index = 1, #values do
    local definition = values[index]
    if definition.schema == 2 and definition.interaction_profile then
      assert(not result[definition.interaction_profile],
        "duplicate structure interaction profile: "
          .. definition.interaction_profile)
      result[definition.interaction_profile] = definition
    end
  end
  return result
end

local function actions_for_profile(simulation, profile, definitions)
  local definition = definitions[profile]
  if definition then
    return definition.actions or {}, definition.id
  end
  return Profiles.fallback_actions(profile), false
end

local function action_candidates(simulation, target)
  local definitions = content_definitions(simulation)
  local profiles = target_profiles(target)
  local result = {}
  local by_id = {}
  for profile_index = 1, #profiles do
    local profile = profiles[profile_index]
    local actions, definition_id =
      actions_for_profile(simulation, profile, definitions)
    for action_index = 1, #actions do
      local action = actions[action_index]
      if not by_id[action.id] then
        local record = {
          action = action,
          definition_id = definition_id,
          module = Profiles.for_profile(profile),
          profile = profile,
        }
        by_id[action.id] = record
        result[#result + 1] = record
      end
    end
  end
  table.sort(result, function(a, b)
    return a.action.id < b.action.id
  end)
  return result, by_id
end

local function actor_adjacent(target, actor)
  if not actor or not actor.index then
    return false
  end
  local actor_x, actor_y = target.world:coordinates(actor.index)
  return math.abs(actor_x - target.x) + math.abs(actor_y - target.y) <= 1
end

local function tile_occupied(simulation, target)
  for index = 1, #(simulation.crew or {}) do
    local actor = simulation.crew[index]
    if actor.alive ~= false and actor.index == target.index then
      return true
    end
  end
  for index = 1, #(simulation.machines or {}) do
    local machine = simulation.machines[index]
    if not machine.destroyed and machine.index == target.index then
      return true
    end
  end
  return false
end

local function validate_parameters(action, parameters)
  parameters = parameters or {}
  if type(parameters) ~= "table" then
    return false, Shared.rejection("invalid-parameters")
  end
  local schema = action.parameters or {}
  local keys = Stable.sorted_keys(parameters)
  for index = 1, #keys do
    local key = keys[index]
    local rule = schema[key]
    if not rule then
      return false, Shared.rejection("unknown-parameter", {
        parameter = key,
      })
    end
    local value = parameters[key]
    if rule.type == "boolean" and type(value) ~= "boolean" then
      return false, Shared.rejection("invalid-parameter", {
        parameter = key,
      })
    elseif rule.type == "integer"
      and (
        type(value) ~= "number"
        or value % 1 ~= 0
        or value < rule.minimum
        or value > rule.maximum
      )
    then
      return false, Shared.rejection("invalid-parameter", {
        parameter = key,
      })
    elseif rule.type == "enum" and not Shared.contains(rule.values, value) then
      return false, Shared.rejection("invalid-parameter", {
        parameter = key,
      })
    end
  end
  return true
end

local function actor_has_all_tools(actor, tools)
  for index = 1, #(tools or {}) do
    if not Shared.contains(actor and actor.tools or {}, tools[index]) then
      return false
    end
  end
  return true
end

local function can_candidate(
  simulation,
  target,
  candidate,
  actor,
  parameters,
  options
)
  local action = candidate.action
  if not action.implemented then
    return false, Shared.rejection("unsupported")
  end
  if not options.ignore_actor then
    if not actor then
      return false, Shared.rejection("actor-missing")
    elseif actor.alive == false or actor.incapacitated == true then
      return false, Shared.rejection("incapacitated")
    elseif action.range == "adjacent" and not actor_adjacent(target, actor) then
      return false, Shared.rejection("not-adjacent")
    end
  end
  local requirements = action.requires or {}
  if requirements.power and not target.world.powered[target.index] then
    return false, Shared.rejection("unpowered")
  end
  if not options.ignore_actor
    and not Shared.actor_has_tool(actor, requirements.tools_any)
  then
    return false, Shared.rejection("wrong-tool", {
      tools_any = Stable.deep_copy(requirements.tools_any or {}),
    })
  end
  if not options.ignore_actor
    and not actor_has_all_tools(actor, requirements.tools_all)
  then
    return false, Shared.rejection("wrong-tool", {
      tools_all = Stable.deep_copy(requirements.tools_all or {}),
    })
  end
  if requirements.unoccupied and tile_occupied(simulation, target) then
    return false, Shared.rejection("occupied")
  end
  if not options.skip_parameters then
    local valid, reason = validate_parameters(action, parameters)
    if not valid then
      return false, reason
    end
  end
  if candidate.module and candidate.module.dynamic_gate then
    return candidate.module.dynamic_gate(
      simulation,
      target,
      action,
      actor,
      parameters or {}
    )
  end
  return true
end

function Interaction.can_action(
  simulation,
  target,
  action_id,
  actor,
  parameters,
  options
)
  options = options or {}
  local normalized, target_error = normalize_target(simulation, target)
  if not normalized then
    return false, target_error
  end
  local _, by_id = action_candidates(simulation, normalized)
  local candidate = by_id[action_id]
  if not candidate then
    return false, Shared.rejection("unknown-action", {
      action_id = action_id,
    })
  end
  return can_candidate(
    simulation,
    normalized,
    candidate,
    actor,
    parameters or {},
    options
  )
end

function Interaction.affordances(simulation, target, actor)
  local normalized = normalize_target(simulation, target)
  if not normalized then
    return {}
  end
  local candidates = action_candidates(simulation, normalized)
  local result = {}
  for index = 1, #candidates do
    local candidate = candidates[index]
    local available, reason = can_candidate(
      simulation,
      normalized,
      candidate,
      actor,
      {},
      { skip_parameters = true }
    )
    local action = candidate.action
    local reason_code = false
    if not available and reason then
      reason_code = reason.code
    end
    result[#result + 1] = {
      id = action.id,
      available = available,
      reason = reason_code,
      definition_id = candidate.definition_id,
      duration_ds = action.duration_ds,
      implemented = action.implemented,
      interaction_profile = candidate.profile,
      parameters = Stable.deep_copy(action.parameters or {}),
      range = action.range,
      requirements = Stable.deep_copy(action.requires or {}),
      source_symbol = action.source_symbol,
      tags = Stable.deep_copy(action.tags or {}),
    }
  end
  return result
end

function Interaction.is_handler_registered(profile, handler_id)
  return GENERIC_HANDLERS[handler_id] ~= nil
    or (
      Profiles.for_profile(profile) ~= nil
      and Profiles.handler(handler_id) ~= nil
    )
end

function Interaction.perform(
  simulation,
  target,
  action_id,
  actor,
  parameters,
  options
)
  options = options or {}
  local normalized, target_error = normalize_target(simulation, target)
  if not normalized then
    return false, target_error
  end
  local _, by_id = action_candidates(simulation, normalized)
  local candidate = by_id[action_id]
  if not candidate then
    return false, Shared.rejection("unknown-action", {
      action_id = action_id,
    })
  end
  local allowed, reason = can_candidate(
    simulation,
    normalized,
    candidate,
    actor,
    parameters or {},
    options
  )
  if not allowed then
    return false, reason
  end
  local handler = GENERIC_HANDLERS[candidate.action.handler]
    or Profiles.handler(candidate.action.handler)
  if not handler then
    return false, Shared.rejection("unsupported", {
      handler = candidate.action.handler,
    })
  end
  local ok, result = handler(
    simulation,
    normalized,
    actor,
    Stable.deep_copy(parameters or {})
  )
  if not ok then
    if type(result) == "table" and result.code then
      return false, result
    end
    return false, Shared.rejection(tostring(result or "unsupported"))
  end
  simulation:_emit("tile_action_completed", {
    action_id = action_id,
    actor_id = actor and actor.id or false,
    index = normalized.index,
    target = {
      kind = "tile",
      index = normalized.index,
      x = normalized.x,
      y = normalized.y,
    },
    x = normalized.x,
    y = normalized.y,
  })
  return true, result
end

return Interaction
