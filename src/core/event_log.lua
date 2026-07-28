local Constants = require("src.core.constants")

local EventLog = {}
EventLog.__index = EventLog

function EventLog.new()
  return setmetatable({
    next_id = 1,
    values = {},
  }, EventLog)
end

function EventLog:emit(tick, kind, payload)
  local event = {
    id = self.next_id,
    tick = tick,
    kind = kind,
    payload = payload or {},
  }
  self.next_id = self.next_id + 1
  self.values[#self.values + 1] = event
  if #self.values > Constants.MAX_EVENTS then
    table.remove(self.values, 1)
  end
  return event
end

function EventLog:since(event_id)
  local result = {}
  for i = 1, #self.values do
    local event = self.values[i]
    if event.id > event_id then
      result[#result + 1] = event
    end
  end
  return result
end

function EventLog:snapshot()
  local values = {}
  for i = 1, #self.values do
    values[i] = self.values[i]
  end
  return {
    next_id = self.next_id,
    values = values,
  }
end

return EventLog
