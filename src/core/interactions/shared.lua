local Stable = require("src.core.stable")

local Shared = {}

function Shared.rejection(code, details)
  local result = { code = code }
  local keys = Stable.sorted_keys(details or {})
  for index = 1, #keys do
    local key = keys[index]
    result[key] = Stable.deep_copy(details[key])
  end
  return result
end

function Shared.contains(values, wanted)
  for index = 1, #(values or {}) do
    if values[index] == wanted then
      return true
    end
  end
  return false
end

function Shared.actor_has_tool(actor, tools)
  if #(tools or {}) == 0 then
    return true
  end
  for tool_index = 1, #tools do
    if Shared.contains(actor and actor.tools or {}, tools[tool_index]) then
      return true
    end
  end
  return false
end

function Shared.actor_has_access(actor, access)
  if not access or access == "public" then
    return true
  end
  if actor and (actor.silicon or actor.access == "override") then
    return true
  end
  return Shared.contains(actor and actor.access or {}, access)
    or Shared.contains(actor and actor.access or {}, "all")
end

function Shared.touch(world, index, topology)
  local x, y = world:coordinates(index)
  world:touch(x, y, topology)
end

function Shared.state(world, index, component, defaults)
  return world:ensure_interaction_state(index, component, defaults)
end

function Shared.peek(world, index, component, defaults)
  local value = world:peek_interaction_state(index, component)
  if value then
    return value
  end
  return defaults or {}
end

return Shared
