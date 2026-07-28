local Stable = require("src.core.stable")

local RuntimeContent = {}

function RuntimeContent.from_registry(registry)
  assert(registry and registry.ids and registry.get,
    "a sealed content registry is required")
  local by_id = {}
  local by_kind = {}
  local ids = registry:ids()
  for index = 1, #ids do
    local id = ids[index]
    local definition = assert(registry:get(id))
    by_id[id] = definition
    local kind = definition.kind
    local values = by_kind[kind]
    if not values then
      values = {}
      by_kind[kind] = values
    end
    values[#values + 1] = definition
  end
  return {
    by_id = by_id,
    by_kind = by_kind,
    ids = ids,
  }
end

function RuntimeContent.get(content, id)
  local value = content and content.by_id and content.by_id[id]
  return value and Stable.deep_copy(value) or nil
end

function RuntimeContent.ids(content, kind)
  local values = content and content.by_kind and content.by_kind[kind] or {}
  local result = {}
  for index = 1, #values do
    result[index] = values[index].id
  end
  return result
end

return RuntimeContent
