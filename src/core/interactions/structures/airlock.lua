local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Airlock = {
  profiles = { "goon-airlock-v1" },
}

local function action(id, handler, tool, duration, source)
  return {
    id = id,
    handler = handler,
    implemented = true,
    range = "adjacent",
    duration_ds = duration or 0,
    requires = tool and { tools_any = { tool } } or {},
    parameters = {},
    source_symbol = source,
    tags = { "airlock", "npc", "structure" },
  }
end

Airlock.actions = {
  ["goon-airlock-v1"] = {
    action(
      "close-door",
      "airlock.close",
      nil,
      0,
      "/obj/machinery/door/proc/close"
    ),
    action(
      "inspect",
      "common.inspect",
      nil,
      0,
      "/obj/machinery/door/get_desc"
    ),
    action(
      "open-door",
      "airlock.open",
      nil,
      0,
      "/obj/machinery/door/proc/open"
    ),
    action(
      "pry-door",
      "airlock.pry",
      "crowbar",
      0,
      "/obj/machinery/door/airlock/proc/unpowered_open_close"
    ),
    action(
      "toggle-door-panel",
      "airlock.toggle-panel",
      "screwdriver",
      0,
      "/obj/machinery/door/airlock/attackby"
    ),
    action(
      "weld-door",
      "airlock.weld",
      "welder",
      20,
      "/obj/machinery/door/airlock/proc/weld_action"
    ),
  },
}

local DEFAULT_STATE = {
  bolted = false,
  panel_open = false,
  welded = false,
}

function Airlock.dynamic_gate(_, target, action_record, actor)
  local world = target.world
  local structure = world.structure[target.index]
  if structure ~= Constants.STRUCTURE.DOOR_CLOSED
    and structure ~= Constants.STRUCTURE.DOOR_OPEN
  then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(world, target.index, "airlock", DEFAULT_STATE)
  if action_record.id == "open-door" then
    if structure ~= Constants.STRUCTURE.DOOR_CLOSED then
      return false, Shared.rejection("invalid-target-state")
    elseif state.welded then
      return false, Shared.rejection("welded")
    elseif state.bolted then
      return false, Shared.rejection("bolted")
    elseif not world.powered[target.index] then
      return false, Shared.rejection("unpowered")
    elseif not Shared.actor_has_access(actor, world.door_access[target.index]) then
      return false, Shared.rejection("access-denied")
    end
  elseif action_record.id == "close-door" then
    if structure ~= Constants.STRUCTURE.DOOR_OPEN then
      return false, Shared.rejection("invalid-target-state")
    elseif state.welded then
      return false, Shared.rejection("welded")
    elseif state.bolted then
      return false, Shared.rejection("bolted")
    elseif not world.powered[target.index] then
      return false, Shared.rejection("unpowered")
    end
  elseif action_record.id == "pry-door" then
    if state.welded then
      return false, Shared.rejection("welded")
    elseif state.bolted then
      return false, Shared.rejection("bolted")
    elseif world.powered[target.index] then
      return false, Shared.rejection("invalid-target-state")
    end
  elseif action_record.id == "weld-door"
    and structure ~= Constants.STRUCTURE.DOOR_CLOSED
  then
    return false, Shared.rejection("invalid-target-state")
  end
  return true
end

Airlock.handlers = {
  ["airlock.open"] = function(simulation, target, actor)
    return target.world:open_door(
      target.index,
      simulation.tick,
      actor and actor.access or {}
    )
  end,
  ["airlock.close"] = function(_, target)
    return target.world:close_door(target.index)
  end,
  ["airlock.pry"] = function(simulation, target)
    if target.world.structure[target.index] == Constants.STRUCTURE.DOOR_CLOSED then
      return target.world:open_door(
        target.index,
        simulation.tick,
        "override",
        true
      )
    end
    return target.world:close_door(target.index)
  end,
  ["airlock.toggle-panel"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "airlock",
      DEFAULT_STATE
    )
    state.panel_open = not state.panel_open
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["airlock.weld"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "airlock",
      DEFAULT_STATE
    )
    state.welded = not state.welded
    Shared.touch(target.world, target.index, false)
    return true
  end,
}

return Airlock
