local Hooks = {}
Hooks.__index = Hooks

local VALID_KINDS = {
  observe = true,
  validate = true,
  transform = true,
}

function Hooks.new(mod_order)
  local rank = {}
  local phase = {}
  for i = 1, #(mod_order or {}) do
    rank[mod_order[i].id] = i
    phase[mod_order[i].id] = mod_order[i].dependency_phase or 0
  end
  return setmetatable({
    handlers = {},
    registration_sequence = 1,
    mod_rank = rank,
    mod_phase = phase,
    faults = {},
  }, Hooks)
end

function Hooks:register(mod_id, kind, name, callback, priority)
  assert(VALID_KINDS[kind], "invalid hook kind")
  assert(type(mod_id) == "string" and mod_id ~= "", "mod ID is required")
  assert(type(name) == "string" and name ~= "", "hook name is required")
  assert(type(callback) == "function", "hook callback must be a function")
  priority = math.floor(priority or 0)
  assert(priority >= -1000 and priority <= 1000, "hook priority is out of range")
  local key = kind .. ":" .. name
  local handlers = self.handlers[key] or {}
  handlers[#handlers + 1] = {
    mod_id = mod_id,
    callback = callback,
    priority = priority,
    sequence = self.registration_sequence,
    disabled = false,
  }
  self.registration_sequence = self.registration_sequence + 1
  table.sort(handlers, function(a, b)
    local phase_a = self.mod_phase[a.mod_id] or 0
    local phase_b = self.mod_phase[b.mod_id] or 0
    if phase_a ~= phase_b then
      return phase_a < phase_b
    end
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    if a.mod_id ~= b.mod_id then
      return a.mod_id < b.mod_id
    end
    return a.sequence < b.sequence
  end)
  self.handlers[key] = handlers
end

function Hooks:_call(handler, ...)
  local started = os.clock()
  local ok, a, b = xpcall(handler.callback, debug.traceback, ...)
  local elapsed = os.clock() - started
  if not ok then
    handler.disabled = true
    self.faults[#self.faults + 1] = {
      mod_id = handler.mod_id,
      error = a,
      elapsed_seconds = elapsed,
    }
    return nil, a
  end
  return true, a, b, elapsed
end

function Hooks:observe(name, context)
  local handlers = self.handlers["observe:" .. name] or {}
  for i = 1, #handlers do
    if not handlers[i].disabled then
      local handler = handlers[i]
      local handler_context = context and context.for_pack
          and context:for_pack(handler.mod_id)
        or context
      self:_call(handler, handler_context, context and context.subject or nil)
    end
  end
end

function Hooks:validate(name, command, context)
  local handlers = self.handlers["validate:" .. name] or {}
  for i = 1, #handlers do
    local handler = handlers[i]
    if not handler.disabled then
      local handler_context = context and context.for_pack
          and context:for_pack(handler.mod_id)
        or context
      local ok, allowed, reason = self:_call(
        handler,
        handler_context,
        command
      )
      if ok and allowed == false then
        return false, reason or ("rejected by " .. handler.mod_id)
      elseif not ok then
        return false, "validation hook failed in " .. handler.mod_id
      end
    end
  end
  return true
end

function Hooks:transform(name, value, context)
  local handlers = self.handlers["transform:" .. name] or {}
  local current = value
  for i = 1, #handlers do
    local handler = handlers[i]
    if not handler.disabled then
      local handler_context = context and context.for_pack
          and context:for_pack(handler.mod_id)
        or context
      local ok, transformed = self:_call(
        handler,
        handler_context,
        current,
        context and context.subject or nil
      )
      if not ok then
        return nil, "transform hook failed in " .. handler.mod_id
      end
      if transformed ~= nil then
        current = transformed
      end
    end
  end
  return current
end

return Hooks
