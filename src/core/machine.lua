local Stable = require("src.core.stable")
local Rng = require("src.core.rng")
local ContentId = require("src.content.id")
local Behaviors = require("src.core.machines")
local Shared = require("src.core.machines.shared")
local Pipes = require("src.core.pipes")

local Machine = {}

local WIRE_COLORS = {
  "orange",
  "dark-red",
  "white",
  "yellow",
}

local LEGACY_DEFINITION_IDS = {
  apc = "org.simstation.core:machine/goon-apc",
  barcode_computer = "org.simstation.core:machine/goon-qm-barcode-computer",
  battery = "org.simstation.core:machine/goon-smes",
  cargo_pad = "org.simstation.core:machine/goon-cargo-pad",
  circulator = "org.simstation.core:machine/goon-teg-circulator",
  fabricator = "org.simstation.core:machine/goon-manufacturer",
  generator = "org.simstation.core:machine/goon-teg-generator",
  nanofab = "org.simstation.core:machine/goon-nanofab",
  portable_scrubber =
    "org.simstation.core:machine/goon-portable-scrubber",
  reclaimer = "org.simstation.core:machine/goon-portable-reclaimer",
  refinery = "org.simstation.core:machine/goon-nanofab",
  scrubber = "org.simstation.core:machine/goon-portable-scrubber",
  supply_console = "org.simstation.core:machine/goon-supply-console",
  vent = "org.simstation.core:machine/goon-passive-vent",
  vent_pump = "org.simstation.core:machine/goon-vent-pump",
}

local LEGACY_BEHAVIOR_IDS = {
  apc = "org.simstation.core:machine-behavior/goon-apc-v1",
  barcode_computer =
    "org.simstation.core:machine-behavior/goon-qm-barcode-v1",
  battery = "org.simstation.core:machine-behavior/goon-smes-v1",
  cargo_pad = "org.simstation.core:machine-behavior/goon-cargo-pad-v1",
  circulator =
    "org.simstation.core:machine-behavior/goon-teg-circulator-v1",
  fabricator =
    "org.simstation.core:machine-behavior/goon-manufacturer-v1",
  generator = "org.simstation.core:machine-behavior/goon-teg-v1",
  nanofab = "org.simstation.core:machine-behavior/goon-nanofab-v1",
  portable_scrubber =
    "org.simstation.core:machine-behavior/goon-portable-scrubber-v1",
  reclaimer =
    "org.simstation.core:machine-behavior/goon-portable-reclaimer-v1",
  refinery = "org.simstation.core:machine-behavior/goon-nanofab-v1",
  scrubber =
    "org.simstation.core:machine-behavior/goon-portable-scrubber-v1",
  supply_console =
    "org.simstation.core:machine-behavior/goon-supply-console-v1",
  vent = "org.simstation.core:machine-behavior/goon-passive-vent-v1",
  vent_pump =
    "org.simstation.core:machine-behavior/goon-vent-pump-v1",
}

local LEGACY_POWER = {
  apc = { false, "none", 0, 1 },
  barcode_computer = { true, "equipment", 250, 4 },
  battery = { false, "none", 0, 3 },
  cargo_pad = { false, "none", 0, 6 },
  circulator = { true, "equipment", 0, 2 },
  fabricator = { true, "equipment", 200, 5 },
  generator = { false, "none", 0, 3 },
  nanofab = { false, "none", 0, 5 },
  portable_scrubber = { true, "environment", 1000, 2 },
  reclaimer = { false, "none", 0, 5 },
  refinery = { false, "none", 0, 5 },
  scrubber = { true, "environment", 1000, 2 },
  supply_console = { true, "equipment", 250, 4 },
  vent = { false, "none", 0, 2 },
  vent_pump = { false, "none", 0, 2 },
}

local function merge_missing(target, defaults)
  for key, value in pairs(defaults or {}) do
    if target[key] == nil then
      target[key] = Stable.deep_copy(value)
    elseif type(target[key]) == "table" and type(value) == "table" then
      merge_missing(target[key], value)
    end
  end
end

local function fallback_definition(kind)
  local power = LEGACY_POWER[kind] or { true, "equipment", 50, 100 }
  local atmos = kind == "vent"
    or kind == "vent_pump"
    or kind == "portable_scrubber"
    or kind == "scrubber"
    or kind == "circulator"
  local interval = kind == "cargo_pad" and 0 or atmos and 16 or 32
  local process_class = interval == 0 and "none"
    or atmos and "atmos"
    or "general"
  return {
    id = LEGACY_DEFINITION_IDS[kind]
      or "org.simstation.core:machine/legacy-generic",
    kind = "machine",
    schema = 2,
    name_key = "machine." .. tostring(kind),
    fixture_kind = kind,
    behavior = LEGACY_BEHAVIOR_IDS[kind]
      or "org.simstation.core:machine-behavior/legacy-generic-v1",
    source = {
      repository = "goonstation/goonstation",
      commit = "1b2b250abb5be747d55e274de0203a59cfc8da78",
      type_path = "/obj/machinery",
      files = { "code/obj/machinery.dm" },
    },
    process = {
      class = process_class,
      tier = process_class == "general" and 4 or 0,
      interval_ds = interval,
      mult_base_ds = process_class == "general" and 48 or 0,
      mult_cap_ds = process_class == "general" and 480 or 0,
    },
    power = {
      requires_power = power[1],
      channel = power[2],
      idle_w = power[3],
      priority = power[4],
    },
    tags = {},
    map_override_fields = {},
    state_defaults = {},
    wires = {},
    actions = {},
    fidelity = {
      profile = "goon-near-1",
      ledger = {
        {
          feature = "legacy-save-compatibility",
          status = "engine-adapted",
          source = "src/core/machine.lua",
        },
      },
    },
  }
end

function Machine.wire_permutation(seed)
  local values = Stable.deep_copy(WIRE_COLORS)
  local rng = Rng.new(math.floor(seed or 0) + 1907)
  for index = #values, 2, -1 do
    local other = rng:integer(1, index)
    values[index], values[other] = values[other], values[index]
  end
  return values
end

function Machine.validate_definition(definition)
  assert(type(definition) == "table", "machine definition must be an object")
  local parsed, id_error = ContentId.parse(definition.id)
  assert(parsed, id_error)
  assert(parsed.kind == "machine", "machine definition has the wrong kind")
  assert(definition.kind == "machine", "machine definition kind is required")
  assert(definition.schema == 2, "unsupported machine definition schema")
  assert(type(definition.fixture_kind) == "string"
    and definition.fixture_kind ~= "", "machine fixture kind is required")
  assert(type(definition.behavior) == "string"
    and definition.behavior ~= "", "machine behavior is required")
  assert(type(definition.process) == "table", "machine process is required")
  assert(type(definition.process.interval_ds) == "number"
    and definition.process.interval_ds % 1 == 0
    and definition.process.interval_ds >= 0,
    "machine process interval must be a non-negative integer")
  assert(type(definition.power) == "table", "machine power is required")
  assert(type(definition.power.requires_power) == "boolean",
    "machine requires_power must be boolean")
  assert(type(definition.power.idle_w) == "number"
    and definition.power.idle_w % 1 == 0
    and definition.power.idle_w >= 0,
    "machine idle power must be a non-negative integer")
  local action_ids = {}
  for index = 1, #(definition.actions or {}) do
    local action = definition.actions[index]
    assert(type(action.id) == "string" and action.id ~= "",
      "machine action ID is required")
    assert(not action_ids[action.id],
      "duplicate machine action ID: " .. action.id)
    action_ids[action.id] = true
    assert(type(action.handler) == "string" and action.handler ~= "",
      "machine action handler is required")
    assert(type(action.implemented) == "boolean",
      "machine action implemented flag is required")
  end
  return definition
end

function Machine.definition(content, definition_id)
  local value = content
    and content.by_id
    and content.by_id[definition_id]
  if value and value.kind == "machine" then
    return value
  end
  return nil
end

function Machine.definition_for_fixture(content, fixture)
  if fixture.definition_id then
    local explicit = Machine.definition(content, fixture.definition_id)
    assert(explicit,
      "unknown machine definition: " .. tostring(fixture.definition_id))
    return Machine.validate_definition(explicit)
  end

  local values = content
    and content.by_kind
    and content.by_kind.machine
    or {}
  local best
  local best_score = -1
  for index = 1, #values do
    local definition = values[index]
    if definition.fixture_kind == fixture.kind then
      local root = definition.source and definition.source.type_path or ""
      local path = fixture.source_path or ""
      local matches = root == ""
        or path == root
        or path:sub(1, #root + 1) == root .. "/"
      local score = matches and #root or 0
      if matches
        and (
          score > best_score
          or (
            score == best_score
            and (not best or definition.id < best.id)
          )
        )
      then
        best = definition
        best_score = score
      end
    end
  end
  if best then
    return Machine.validate_definition(best)
  end
  return fallback_definition(fixture.kind)
end

local function first_process_due(definition, processing_bucket)
  local process = definition.process
  if process.interval_ds <= 0 or process.class == "none" then
    return 0
  elseif process.class == "atmos" then
    return 4
  end
  local bucket_count = 2 ^ math.max(0, process.tier - 1)
  local bucket = processing_bucket % bucket_count
  return 4 + bucket * 4
end

local function build_wires(definition, colors)
  local wires = {}
  for index = 1, #(definition.wires or {}) do
    local source = definition.wires[index]
    wires[#wires + 1] = {
      id = source.id,
      index = source.index,
      color = colors[source.index] or ("wire-" .. tostring(source.index)),
      intact = true,
      source_symbol = source.source_symbol,
    }
  end
  table.sort(wires, function(a, b)
    return a.index < b.index
  end)
  return wires
end

function Machine.create(simulation, fixture, entity_id, ordinal)
  local definition = Machine.definition_for_fixture(simulation.content, fixture)
  local process_bucket = (math.max(1, ordinal or 1) - 1) % 32
  local source_overrides = fixture.source_overrides or {}
  local allowed_overrides = {}
  for index = 1, #(definition.map_override_fields or {}) do
    allowed_overrides[definition.map_override_fields[index]] = true
  end
  local data = Stable.deep_copy(definition.state_defaults or {})
  for key, value in pairs(source_overrides) do
    if allowed_overrides[key] then
      data[key] = Stable.deep_copy(value)
    end
  end

  local health = definition.health
    and definition.health.maximum
    or false
  local display_name = type(data.name) == "string"
      and data.name
    or fixture.name
    or fixture.kind:gsub("_", " ")
  local machine = {
    schema = 2,
    id = entity_id,
    scenario_fixture_id = fixture.id,
    definition_id = definition.id,
    behavior_id = definition.behavior,
    kind = fixture.kind,
    name = display_name,
    index = fixture.index,
    x = fixture.x,
    y = fixture.y,
    department = fixture.department or "general",
    machine_tag = false,
    source_path = fixture.source_path or definition.source.type_path,
    source_overrides = Stable.deep_copy(source_overrides),
    tags = Stable.deep_copy(definition.tags or {}),
    state = "idle",
    status = {
      broken = false,
      emp_short = false,
      high_load = false,
      maintenance = false,
      no_power = not not definition.power.requires_power,
      power_off = false,
      requires_physical_access = false,
    },
    health = health,
    health_contract = Stable.deep_copy(definition.health or {}),
    destroyed = false,
    powered = not definition.power.requires_power,
    requested_watts = 0,
    served_watts = 0,
    power = Stable.deep_copy(definition.power),
    processing = {
      class = definition.process.class,
      tier = definition.process.tier,
      bucket = process_bucket,
      interval_ds = definition.process.interval_ds,
      mult_base_ds = definition.process.mult_base_ds,
      mult_cap_ds = definition.process.mult_cap_ds,
      last_process_ds = 0,
      next_due_ds = first_process_due(definition, process_bucket),
      subscribed = definition.process.interval_ds > 0,
      process_count = 0,
    },
    data = data,
    wires = build_wires(
      definition,
      simulation.machine_wire_colors or WIRE_COLORS
    ),
    faults = {},
    task_id = false,
    recipe_id = false,
  }
  local behavior = Behaviors.for_machine(machine)
  machine.machine_tag = behavior and behavior.machine_tag or false
  if behavior and behavior.initialize then
    behavior.initialize(simulation, machine, fixture, definition)
  end
  return machine
end

function Machine.upgrade_instance(simulation, machine, ordinal)
  local fixture = {
    id = machine.scenario_fixture_id
      or ("legacy-machine-" .. tostring(machine.id)),
    definition_id = machine.definition_id,
    kind = machine.kind or "generic",
    name = machine.name,
    index = machine.index,
    x = machine.x,
    y = machine.y,
    department = machine.department,
    source_path = machine.source_path,
    source_overrides = machine.source_overrides,
  }
  local fresh = Machine.create(simulation, fixture, machine.id, ordinal)
  merge_missing(machine, fresh)
  machine.schema = 2
  local process = machine.processing
  local now_ds = simulation.machine_time_ds or 0
  if process.subscribed
    and process.interval_ds > 0
    and process.next_due_ds <= now_ds
  then
    local missed = math.floor(
      (now_ds - process.next_due_ds) / process.interval_ds
    ) + 1
    process.next_due_ds =
      process.next_due_ds + missed * process.interval_ds
  end
  return machine
end

local function definition_for_machine(simulation, machine)
  return Machine.definition(simulation.content, machine.definition_id)
    or fallback_definition(machine.kind)
end

function Machine.action_definition(simulation, machine, action_id)
  local definition = definition_for_machine(simulation, machine)
  for index = 1, #(definition.actions or {}) do
    if definition.actions[index].id == action_id then
      return definition.actions[index]
    end
  end
  return nil
end

local function actor_is_remote(actor)
  return actor
    and (
      actor.remote_machine_access == true
      or actor.silicon == true
      or actor.ai == true
    )
end

local function actor_is_adjacent(simulation, machine, actor)
  if not actor or not actor.index then
    return false
  end
  local actor_x, actor_y = simulation.world:coordinates(actor.index)
  if not actor_x then
    return false
  end
  return math.max(
    math.abs(actor_x - machine.x),
    math.abs(actor_y - machine.y)
  ) <= 1
end

local function actor_has_any(actor, field, requirements)
  for index = 1, #(requirements or {}) do
    if Shared.set_contains(actor and actor[field], requirements[index]) then
      return true
    end
  end
  return #(requirements or {}) == 0
end

local function actor_has_all(actor, field, requirements)
  for index = 1, #(requirements or {}) do
    if not Shared.set_contains(actor and actor[field], requirements[index]) then
      return false
    end
  end
  return true
end

local function validate_parameters(action, parameters)
  parameters = parameters or {}
  if type(parameters) ~= "table" then
    return false, Shared.rejection(
      "invalid-parameter",
      { parameter = "$" }
    )
  end
  local contracts = action.parameters or {}
  local provided_names = Stable.sorted_keys(parameters)
  for index = 1, #provided_names do
    local name = provided_names[index]
    if type(name) ~= "string" or contracts[name] == nil then
      return false, Shared.rejection(
        "invalid-parameter",
        { parameter = tostring(name) }
      )
    end
  end
  local names = Stable.sorted_keys(contracts)
  for index = 1, #names do
    local name = names[index]
    local contract = contracts[name]
    local value = parameters[name]
    if value == nil then
      return false, Shared.rejection(
        "invalid-parameter",
        { parameter = name }
      )
    elseif contract.type == "boolean" then
      if type(value) ~= "boolean" then
        return false, Shared.rejection(
          "invalid-parameter",
          { parameter = name }
        )
      end
    elseif contract.type == "integer" then
      if type(value) ~= "number"
        or value % 1 ~= 0
        or value < contract.minimum
        or value > contract.maximum
      then
        return false, Shared.rejection(
          "invalid-parameter",
          { parameter = name }
        )
      end
    elseif contract.type == "enum" then
      if not Shared.array_contains(contract.values, value) then
        return false, Shared.rejection(
          "invalid-parameter",
          { parameter = name }
        )
      end
    elseif contract.type == "content-id" then
      if not ContentId.parse(value) then
        return false, Shared.rejection(
          "invalid-parameter",
          { parameter = name }
        )
      end
    end
  end
  return true
end

local function dynamic_gate(
  simulation,
  machine,
  action,
  actor,
  parameters,
  validate_parameter_values
)
  if (action.handler == "wire.cut"
      or action.handler == "wire.mend"
      or action.handler == "wire.pulse")
    and validate_parameter_values
  then
    local wire = Shared.wire_by_key(machine, parameters.wire)
    if not wire then
      return false, Shared.rejection("invalid-wire")
    elseif action.handler == "wire.cut" and not wire.intact then
      return false, Shared.rejection(
        "wire-already-cut",
        { wire = wire.color }
      )
    elseif action.handler == "wire.mend" and wire.intact then
      return false, Shared.rejection(
        "wire-not-cut",
        { wire = wire.color }
      )
    elseif action.handler == "wire.pulse" and not wire.intact then
      return false, Shared.rejection("wire-cut", { wire = wire.color })
    end
  end
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.gate then
    return behavior.gate(
      simulation,
      machine,
      action,
      actor_is_remote(actor),
      actor,
      parameters
    )
  end
  return true
end

function Machine.can_action(
  simulation,
  machine,
  action_id,
  actor,
  parameters,
  options
)
  options = options or {}
  local action = Machine.action_definition(simulation, machine, action_id)
  if not action then
    return false, Shared.rejection(
      "unknown-action",
      { action_id = action_id }
    )
  end
  if not action.implemented then
    return false, Shared.rejection(
      "not-implemented",
      { action_id = action_id }
    )
  end
  if machine.destroyed then
    return false, Shared.rejection("destroyed")
  end
  local requirements = action.requires or {}
  if requirements.not_broken and machine.status.broken then
    return false, Shared.rejection("broken")
  end
  if requirements.power and not machine.powered then
    return false, Shared.rejection("no-power")
  end
  if requirements.panel_open
    and not machine.data.panel_open
    and not machine.data.wiresexposed
  then
    return false, Shared.rejection("panel-closed")
  end
  if #(requirements.modes or {}) > 0
    and not Shared.array_contains(requirements.modes, machine.data.mode)
  then
    return false, Shared.rejection(
      "invalid-mode",
      { mode = machine.data.mode }
    )
  end

  if not options.ignore_actor then
    if not actor then
      return false, Shared.rejection("actor-missing")
    elseif actor.alive == false or actor.incapacitated == true then
      return false, Shared.rejection("incapacitated")
    end
    local adjacent = actor_is_adjacent(simulation, machine, actor)
    local remote = actor_is_remote(actor)
    if action.range == "adjacent" and not adjacent then
      return false, Shared.rejection("not-adjacent")
    elseif action.range == "remote-or-adjacent"
      and not adjacent
      and not (remote and requirements.allow_remote)
    then
      return false, Shared.rejection(
        remote and "remote-disabled" or "not-adjacent"
      )
    end
    if not actor_has_any(actor, "access", requirements.access_any) then
      return false, Shared.rejection("access-denied", {
        access_any = Stable.deep_copy(requirements.access_any),
      })
    end
    if not actor_has_any(actor, "tools", requirements.tools_any)
      or not actor_has_all(actor, "tools", requirements.tools_all)
    then
      return false, Shared.rejection("wrong-tool", {
        tools_any = Stable.deep_copy(requirements.tools_any or {}),
        tools_all = Stable.deep_copy(requirements.tools_all or {}),
      })
    end
  elseif not options.ignore_proximity and action.range ~= "none" then
    return false, Shared.rejection("actor-missing")
  end

  if not options.skip_parameters then
    local valid, parameter_error = validate_parameters(action, parameters)
    if not valid then
      return false, parameter_error
    end
  end
  return dynamic_gate(
    simulation,
    machine,
    action,
    actor,
    parameters or {},
    not options.skip_parameters
  )
end

function Machine.affordances(simulation, machine, actor)
  local definition = definition_for_machine(simulation, machine)
  local result = {}
  for index = 1, #(definition.actions or {}) do
    local action = definition.actions[index]
    local available, reason = Machine.can_action(
      simulation,
      machine,
      action.id,
      actor,
      {},
      { skip_parameters = true }
    )
    local reason_code = false
    if not available then
      reason_code = reason.code
    end
    result[#result + 1] = {
      id = action.id,
      available = available,
      reason = reason_code,
      duration_ds = action.duration_ds,
      implemented = action.implemented,
      parameters = Stable.deep_copy(action.parameters or {}),
      range = action.range,
      requirements = Stable.deep_copy(action.requires or {}),
      source_symbol = action.source_symbol,
      tags = Stable.deep_copy(action.tags or {}),
    }
  end
  table.sort(result, function(a, b)
    return a.id < b.id
  end)
  return result
end

local function toggle_panel(_, machine)
  machine.data.panel_open = not machine.data.panel_open
  return true
end

local function apply_wire_operation(
  simulation,
  machine,
  parameters,
  operation
)
  local wire = Shared.wire_by_key(machine, parameters.wire)
  if not wire then
    return false, Shared.rejection("invalid-wire")
  elseif operation == "cut" and not wire.intact then
    return false, Shared.rejection("wire-already-cut")
  elseif operation == "mend" and wire.intact then
    return false, Shared.rejection("wire-not-cut")
  elseif operation == "pulse" and not wire.intact then
    return false, Shared.rejection("wire-cut")
  end
  if operation == "cut" then
    wire.intact = false
  elseif operation == "mend" then
    wire.intact = true
  end
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.wire_effect then
    behavior.wire_effect(simulation, machine, wire, operation)
  end
  return true
end

local GENERIC_HANDLERS = {
  ["common.inspect"] = function()
    return true
  end,
  ["common.toggle-panel"] = toggle_panel,
  ["wire.cut"] = function(simulation, machine, _, parameters)
    return apply_wire_operation(simulation, machine, parameters, "cut")
  end,
  ["wire.mend"] = function(simulation, machine, _, parameters)
    return apply_wire_operation(simulation, machine, parameters, "mend")
  end,
  ["wire.pulse"] = function(simulation, machine, _, parameters)
    return apply_wire_operation(simulation, machine, parameters, "pulse")
  end,
}

function Machine.is_handler_registered(definition, handler_id)
  local behavior = Behaviors.for_definition(definition)
  return GENERIC_HANDLERS[handler_id] ~= nil
    or (
      behavior ~= nil
      and behavior.handlers ~= nil
      and behavior.handlers[handler_id] ~= nil
    )
end

function Machine.perform(
  simulation,
  machine,
  action_id,
  actor,
  parameters,
  options
)
  options = options or {}
  local allowed, reason = Machine.can_action(
    simulation,
    machine,
    action_id,
    actor,
    parameters,
    {
      ignore_actor = options.ignore_actor,
      ignore_proximity = options.ignore_proximity,
    }
  )
  if not allowed then
    return false, reason
  end
  local action = assert(
    Machine.action_definition(simulation, machine, action_id)
  )
  local behavior = Behaviors.for_machine(machine)
  local handler = GENERIC_HANDLERS[action.handler]
    or (behavior and behavior.handlers[action.handler])
  if not handler then
    return false, Shared.rejection(
      "unregistered-handler",
      { handler = action.handler }
    )
  end
  local ok, result = handler(
    simulation,
    machine,
    actor,
    Stable.deep_copy(parameters or {})
  )
  if not ok then
    return false, result
  end
  Machine.refresh_state(machine)
  simulation:_emit("machine_action_completed", {
    action_id = action_id,
    actor_id = actor and actor.id or false,
    machine_id = machine.id,
    scenario_fixture_id = machine.scenario_fixture_id,
  })
  return true, result
end

function Machine.power_priority(machine)
  return machine.power.priority or 100
end

function Machine.power_request(machine)
  if machine.destroyed
    or machine.status.broken
    or machine.status.power_off
  then
    return 0
  end
  local request = machine.power.idle_w or 0
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.power_request then
    request = behavior.power_request(machine, request)
  end
  return math.max(0, math.floor(request))
end

function Machine.is_connected(simulation, machine)
  if machine.destroyed or machine.status.power_off then
    return false
  end
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.is_connected
    and not behavior.is_connected(simulation, machine)
  then
    return false
  end
  if not machine.power.requires_power then
    return true
  end
  return simulation.world.powered[machine.index] == true
end

function Machine.set_power(machine, connected, served_watts)
  local powered = connected
    and served_watts >= (machine.requested_watts or 0)
  if (machine.requested_watts or 0) == 0 then
    powered = connected
  end
  machine.powered = powered
  machine.served_watts = powered and (machine.requested_watts or 0) or 0
  machine.status.no_power = machine.power.requires_power and not powered
  Machine.refresh_state(machine)
end

function Machine.refresh_state(machine)
  if machine.destroyed then
    machine.state = "destroyed"
  elseif machine.status.broken then
    machine.state = "broken"
  elseif machine.status.no_power then
    machine.state = "unpowered"
  else
    local behavior = Behaviors.for_machine(machine)
    local state = behavior
      and behavior.refresh_state
      and behavior.refresh_state(machine)
      or nil
    machine.state = state or "idle"
  end
end

local function process_machine(simulation, machine, due_ds)
  machine.processing.last_process_ds = due_ds
  machine.processing.process_count =
    machine.processing.process_count + 1
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.process then
    behavior.process(simulation, machine, due_ds)
  end
  Machine.refresh_state(machine)
end

local function process_delayed(simulation, machine, now_ds)
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.delayed then
    behavior.delayed(simulation, machine, now_ds)
  end
  Machine.refresh_state(machine)
end

function Machine.step_all(simulation, target_ds)
  target_ds = math.floor(target_ds)
  local current_ds = math.floor(simulation.machine_time_ds or 0)
  assert(target_ds >= current_ds, "machine calendar cannot run backwards")
  local ordered = Stable.sorted_values_by_id(simulation.machines)
  for now_ds = current_ds + 1, target_ds do
    for index = 1, #ordered do
      local machine = ordered[index]
      local process = machine.processing
      if process.subscribed
        and process.class == "atmos"
        and process.next_due_ds == now_ds
      then
        process_machine(simulation, machine, now_ds)
        process.next_due_ds = process.next_due_ds + process.interval_ds
      end
    end
    -- Pipe networks reconcile every 16 ds with the +4 ds phase after the
    -- atmosphere machines (docs/technical/09, authoritative ds schedule).
    if now_ds % 16 == 8 then
      Pipes.step(simulation, now_ds)
    end
    for index = 1, #ordered do
      local machine = ordered[index]
      local process = machine.processing
      if process.subscribed
        and process.class == "general"
        and process.next_due_ds == now_ds
      then
        process_machine(simulation, machine, now_ds)
        process.next_due_ds = process.next_due_ds + process.interval_ds
      end
    end
    simulation.machine_time_ds = now_ds
    for index = 1, #ordered do
      process_delayed(simulation, ordered[index], now_ds)
    end
  end
  simulation.machine_time_ds = target_ds
end

function Machine.damage(simulation, machine, amount)
  amount = math.floor(amount or 0)
  if amount == 0 or machine.health == false or machine.destroyed then
    return false
  end
  local maximum = machine.health_contract.maximum or 100
  machine.health = Stable.clamp(machine.health - amount, 0, maximum)
  if machine.health == 0 then
    machine.destroyed = true
    machine.status.broken = true
  else
    local behavior = Behaviors.for_machine(machine)
    if behavior and behavior.damage then
      behavior.damage(simulation, machine, amount)
    elseif amount > 0
      and machine.health <= (machine.health_contract.break_at or 0)
    then
      machine.status.broken = true
    elseif amount < 0
      and machine.health >= (
        machine.health_contract.repair_at or maximum
      )
    then
      machine.status.broken = false
    end
  end
  simulation._machine_power_dirty = true
  Machine.refresh_state(machine)
  simulation:_emit(
    amount > 0 and "machine_damaged" or "machine_repaired",
    {
      amount = math.abs(amount),
      health = machine.health,
      machine_id = machine.id,
    }
  )
  return true
end

function Machine.queue_recipe(simulation, machine, recipe_id)
  local behavior = Behaviors.for_machine(machine)
  if behavior and behavior.queue_recipe then
    return behavior.queue_recipe(simulation, machine, recipe_id)
  end
  return Machine.perform(
    simulation,
    machine,
    "queue-product",
    nil,
    { recipe_id = recipe_id },
    { ignore_actor = true, ignore_proximity = true }
  )
end

return Machine
