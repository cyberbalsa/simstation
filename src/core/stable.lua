local Stable = {}

local HASH_MODULUS = 2147483647
local HASH_MULTIPLIER = 65599

function Stable.sorted_keys(value)
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    local type_a = type(a)
    local type_b = type(b)
    if type_a ~= type_b then
      return type_a < type_b
    end
    return a < b
  end)
  return keys
end

function Stable.sorted_values_by_id(values)
  local result = {}
  for i = 1, #values do
    result[i] = values[i]
  end
  table.sort(result, function(a, b)
    return a.id < b.id
  end)
  return result
end

function Stable.deep_copy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[Stable.deep_copy(key, seen)] = Stable.deep_copy(child, seen)
  end
  return copy
end

local function hash_bytes(hash, value)
  for i = 1, #value do
    hash = (hash * HASH_MULTIPLIER + value:byte(i)) % HASH_MODULUS
  end
  return hash
end

local function hash_value(hash, value, seen)
  local kind = type(value)
  hash = hash_bytes(hash, kind)
  if kind == "nil" then
    return hash_bytes(hash, ";")
  elseif kind == "boolean" then
    return hash_bytes(hash, value and "1;" or "0;")
  elseif kind == "number" then
    return hash_bytes(hash, string.format("%.17g;", value))
  elseif kind == "string" then
    hash = hash_bytes(hash, tostring(#value))
    hash = hash_bytes(hash, ":")
    return hash_bytes(hash, value)
  elseif kind ~= "table" then
    error("unsupported deterministic hash type: " .. kind)
  end

  if seen[value] then
    error("cycles are not valid authoritative state")
  end
  seen[value] = true
  hash = hash_bytes(hash, "{")
  local keys = Stable.sorted_keys(value)
  for i = 1, #keys do
    local key = keys[i]
    hash = hash_value(hash, key, seen)
    hash = hash_value(hash, value[key], seen)
  end
  hash = hash_bytes(hash, "}")
  seen[value] = nil
  return hash
end

function Stable.hash(value)
  return hash_value(17, value, {})
end

function Stable.clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  elseif value > maximum then
    return maximum
  end
  return value
end

function Stable.sign(value)
  if value < 0 then
    return -1
  elseif value > 0 then
    return 1
  end
  return 0
end

return Stable
