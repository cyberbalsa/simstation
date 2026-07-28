local CommandQueue = {}
CommandQueue.__index = CommandQueue

function CommandQueue.new()
  return setmetatable({
    next_sequence = 1,
    pending = {},
  }, CommandQueue)
end

function CommandQueue:push(kind, payload, issuer)
  local command = {
    sequence = self.next_sequence,
    kind = kind,
    payload = payload or {},
    issuer = issuer or "player",
  }
  self.next_sequence = self.next_sequence + 1
  self.pending[#self.pending + 1] = command
  return command.sequence
end

function CommandQueue:drain()
  local result = self.pending
  self.pending = {}
  table.sort(result, function(a, b)
    if a.sequence ~= b.sequence then
      return a.sequence < b.sequence
    end
    return a.issuer < b.issuer
  end)
  return result
end

function CommandQueue:snapshot()
  return {
    next_sequence = self.next_sequence,
    pending = self.pending,
  }
end

return CommandQueue
