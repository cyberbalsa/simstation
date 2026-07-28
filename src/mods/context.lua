local Stable = require("src.core.stable")
local Machine = require("src.core.machine")
local Json = require("src.vendor.json")

local Context = {}
Context.__index = Context

local MAX_STATE_BYTES = 8 * 1024 * 1024

local function machine_by_id(simulation, stable_id)
  for index = 1, #simulation.machines do
    local machine = simulation.machines[index]
    if machine.id == stable_id
      or machine.scenario_fixture_id == stable_id
    then
      return machine
    end
  end
  return nil
end

local function crew_by_id(simulation, actor_id)
  for index = 1, #simulation.crew do
    if simulation.crew[index].id == actor_id then
      return simulation.crew[index]
    end
  end
  return nil
end

local function assert_primitive(value, seen)
  local kind = type(value)
  if kind == "nil" or kind == "boolean" or kind == "string" then
    return
  elseif kind == "number" then
    assert(value == value and value ~= math.huge and value ~= -math.huge,
      "mod state cannot contain non-finite numbers")
    assert(value % 1 == 0, "authoritative mod state numbers must be integers")
    return
  end
  assert(kind == "table", "mod state contains unsupported " .. kind)
  assert(not getmetatable(value), "mod state cannot contain metatables")
  seen = seen or {}
  assert(not seen[value], "mod state cannot contain cycles")
  seen[value] = true
  for key, child in pairs(value) do
    assert(type(key) == "string"
      or (type(key) == "number" and key >= 1 and key % 1 == 0),
      "mod state keys must be strings or positive array indexes")
    assert_primitive(child, seen)
  end
  seen[value] = nil
end

function Context.new(simulation, subject, pack_id, capabilities)
  return setmetatable({
    simulation = simulation,
    subject = subject,
    current_pack_id = pack_id or false,
    capabilities = capabilities or {},
  }, Context)
end

function Context:for_pack(pack_id)
  return Context.new(
    self.simulation,
    self.subject,
    pack_id,
    self.capabilities
  )
end

function Context:tick()
  return self.simulation.tick
end

function Context:pack_id()
  return self.current_pack_id
end

function Context:query(kind, stable_id)
  if kind == "inventory" then
    if stable_id ~= nil then
      return self.simulation.inventory[stable_id] or 0
    end
    return Stable.deep_copy(self.simulation.inventory)
  elseif kind == "machines" then
    if stable_id ~= nil then
      local machine = machine_by_id(self.simulation, stable_id)
      return machine and Stable.deep_copy(machine) or nil
    end
    return Stable.deep_copy(self.simulation.machines)
  elseif kind == "scenario" then
    return Stable.deep_copy(self.simulation.scenario)
  elseif kind == "station" then
    return {
      tick = self.simulation.tick,
      station = Stable.deep_copy(self.simulation.station),
      economy = Stable.deep_copy(self.simulation.economy),
      metrics = Stable.deep_copy(self.simulation.metrics),
    }
  end
  return nil
end

function Context:machine_actions(machine_id, actor_id)
  local machine = machine_by_id(self.simulation, machine_id)
  if not machine then
    return nil
  end
  local actor = actor_id ~= nil
      and crew_by_id(self.simulation, actor_id)
    or nil
  if actor_id ~= nil and not actor then
    return nil
  end
  return Machine.affordances(self.simulation, machine, actor)
end

function Context:query_tile(map_id, x, y)
  local world = self.simulation.world
  if map_id ~= nil and map_id ~= world.map_id then
    return nil
  end
  local index = world:index(x, y)
  if not index then
    return nil
  end
  return {
    x = x,
    y = y,
    tile = world.tile[index],
    structure = world.structure[index],
    pressure_dkpa = world:pressure_dkpa(index),
    powered = world.powered[index],
    fire = world.fire[index],
    area = world.area[index],
    area_record = Stable.deep_copy(world:area_record(index)),
    door_access = world.door_access[index],
  }
end

function Context:definitions(kind, tag)
  local values = self.simulation.content
    and self.simulation.content.by_kind
    and self.simulation.content.by_kind[kind]
    or {}
  local result = {}
  for index = 1, #values do
    local definition = values[index]
    local matches = tag == nil
    for tag_index = 1, #(definition.tags or {}) do
      if definition.tags[tag_index] == tag then
        matches = true
        break
      end
    end
    if matches then
      result[#result + 1] = definition.id
    end
  end
  table.sort(result)
  return result
end

function Context:definition(id)
  local value = self.simulation.content
    and self.simulation.content.by_id
    and self.simulation.content.by_id[id]
  return value and Stable.deep_copy(value) or nil
end

function Context:enqueue(command_type, payload)
  assert(self.capabilities.enqueue, "this hook kind cannot enqueue commands")
  assert(type(command_type) == "string" and command_type ~= "",
    "command type is required")
  assert_primitive(payload or {})
  return self.simulation:enqueue(
    command_type,
    Stable.deep_copy(payload or {}),
    "mod:" .. tostring(self.current_pack_id)
  )
end

function Context:get_state()
  local value = self.simulation.mod_state[self.current_pack_id] or {}
  return Stable.deep_copy(value)
end

function Context:set_state(next_state)
  assert(self.current_pack_id, "hook context has no owning pack")
  assert_primitive(next_state)
  local encoded = Json.encode(next_state)
  assert(#encoded <= MAX_STATE_BYTES, "mod state exceeds 8 MiB")
  self.simulation.mod_state[self.current_pack_id] = Stable.deep_copy(next_state)
end

function Context:event_variant(event_id, namespace, count)
  assert(type(event_id) == "number" and event_id % 1 == 0,
    "event ID must be an integer")
  assert(type(namespace) == "string", "event namespace must be a string")
  assert(type(count) == "number" and count >= 1 and count % 1 == 0,
    "variant count must be a positive integer")
  local value = Stable.hash({
    seed = self.simulation.seed,
    event_id = event_id,
    namespace = namespace,
  })
  return (value % count) + 1
end

function Context:log(level, message, fields)
  local diagnostics = self.simulation.mod_diagnostics
  diagnostics[#diagnostics + 1] = {
    tick = self.simulation.tick,
    pack = self.current_pack_id,
    level = tostring(level),
    message = tostring(message),
    fields = Stable.deep_copy(fields or {}),
  }
  if #diagnostics > 1000 then
    table.remove(diagnostics, 1)
  end
end

return Context
