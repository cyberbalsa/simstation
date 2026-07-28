local Stable = require("src.core.stable")
local Json = require("src.vendor.json")

local Context = {}
Context.__index = Context

local MAX_STATE_BYTES = 8 * 1024 * 1024

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

function Context:query()
  return nil
end

function Context:query_tile(_, x, y)
  local world = self.simulation.world
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
  }
end

function Context:definitions()
  return {}
end

function Context:definition()
  return nil
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
