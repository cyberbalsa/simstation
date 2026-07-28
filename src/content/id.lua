local ContentId = {}

local KIND_PATTERN = "^[a-z][a-z0-9_%-]*$"
local NAME_PATTERN = "^[a-z0-9][a-z0-9_/%-]*$"

local function valid_pack(value)
  if not value:find(".", 1, true)
    or value:sub(1, 1) == "."
    or value:sub(-1) == "."
    or value:find("..", 1, true)
  then
    return false
  end
  for component in value:gmatch("[^.]+") do
    if not component:match("^[a-z0-9][a-z0-9-]*$") then
      return false
    end
  end
  return true
end

function ContentId.parse(value)
  if type(value) ~= "string" then
    return nil, "content ID must be a string"
  end
  local pack, kind, name = value:match("^([^:]+):([^/]+)/(.+)$")
  if not pack or not kind or not name then
    return nil, "expected <reverse-dns-pack>:<kind>/<name>"
  end
  if not valid_pack(pack) then
    return nil, "invalid reverse-DNS pack ID"
  end
  if not kind:match(KIND_PATTERN) then
    return nil, "invalid content kind"
  end
  if not name:match(NAME_PATTERN)
    or name:find("//", 1, true)
    or name:sub(-1) == "/"
  then
    return nil, "invalid content name"
  end
  return {
    value = value,
    pack = pack,
    kind = kind,
    name = name,
  }
end

function ContentId.assert_valid(value)
  local parsed, err = ContentId.parse(value)
  assert(parsed, err .. ": " .. tostring(value))
  return value
end

function ContentId.make(pack, kind, name)
  local value = string.format("%s:%s/%s", pack, kind, name)
  return ContentId.assert_valid(value)
end

return ContentId
