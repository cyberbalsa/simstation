-- Strict SemVer 2.0 parsing and the deliberately small Sim Station
-- constraint grammar. This stays project-owned so package resolution does
-- not inherit a third-party library's range syntax.
local Semver = {}

local function split(value, delimiter)
  local result = {}
  local start = 1
  while true do
    local position = value:find(delimiter, start, true)
    if not position then
      result[#result + 1] = value:sub(start)
      return result
    end
    result[#result + 1] = value:sub(start, position - 1)
    start = position + #delimiter
  end
end

local function valid_identifier(value, numeric)
  if value == "" or not value:match("^[0-9A-Za-z-]+$") then
    return false
  end
  if numeric and #value > 1 and value:sub(1, 1) == "0" then
    return false
  end
  return true
end

function Semver.parse(value)
  if type(value) ~= "string" then
    return nil, "version must be a string"
  end
  if value == "" or value:find("%s") then
    return nil, "invalid semantic version"
  end
  local without_build = value
  local build = ""
  local plus = value:find("+", 1, true)
  if plus then
    if value:find("+", plus + 1, true) then
      return nil, "version contains more than one build separator"
    end
    without_build = value:sub(1, plus - 1)
    build = value:sub(plus + 1)
    if build == "" then
      return nil, "build metadata cannot be empty"
    end
  end
  local core = without_build
  local prerelease = ""
  local hyphen = without_build:find("-", 1, true)
  if hyphen then
    core = without_build:sub(1, hyphen - 1)
    prerelease = without_build:sub(hyphen + 1)
    if prerelease == "" then
      return nil, "prerelease cannot be empty"
    end
  end
  local major, minor, patch = core:match("^(%d+)%.(%d+)%.(%d+)$")
  if not major then
    return nil, "version must contain major.minor.patch"
  end
  if (#major > 1 and major:sub(1, 1) == "0")
    or (#minor > 1 and minor:sub(1, 1) == "0")
    or (#patch > 1 and patch:sub(1, 1) == "0")
  then
    return nil, "numeric version components cannot have leading zeroes"
  end

  local parsed_prerelease = {}
  if prerelease ~= "" then
    parsed_prerelease = split(prerelease, ".")
    for i = 1, #parsed_prerelease do
      local identifier = parsed_prerelease[i]
      if not valid_identifier(identifier, identifier:match("^%d+$") ~= nil) then
        return nil, "invalid prerelease identifier"
      end
    end
  end
  if build ~= "" then
    local identifiers = split(build, ".")
    for i = 1, #identifiers do
      if not valid_identifier(identifiers[i], false) then
        return nil, "invalid build identifier"
      end
    end
  end
  return {
    source = value,
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    prerelease = parsed_prerelease,
    build = build ~= "" and build or false,
  }
end

local function compare_prerelease(left, right)
  local left_empty = #left == 0
  local right_empty = #right == 0
  if left_empty or right_empty then
    if left_empty and right_empty then
      return 0
    end
    return left_empty and 1 or -1
  end
  local count = math.max(#left, #right)
  for i = 1, count do
    local a = left[i]
    local b = right[i]
    if not a or not b then
      return a and 1 or -1
    end
    local a_number = a:match("^%d+$") and tonumber(a) or nil
    local b_number = b:match("^%d+$") and tonumber(b) or nil
    if a_number and b_number and a_number ~= b_number then
      return a_number < b_number and -1 or 1
    elseif a_number and not b_number then
      return -1
    elseif b_number and not a_number then
      return 1
    elseif not a_number and not b_number and a ~= b then
      return a < b and -1 or 1
    end
  end
  return 0
end

function Semver.compare(left, right)
  if type(left) == "string" then
    left = assert(Semver.parse(left))
  end
  if type(right) == "string" then
    right = assert(Semver.parse(right))
  end
  local fields = { "major", "minor", "patch" }
  for i = 1, #fields do
    local field = fields[i]
    if left[field] ~= right[field] then
      return left[field] < right[field] and -1 or 1
    end
  end
  return compare_prerelease(left.prerelease, right.prerelease)
end

local function comparator_allows(version, operator, target)
  local comparison = Semver.compare(version, target)
  if operator == "=" then
    return comparison == 0
  elseif operator == ">" then
    return comparison > 0
  elseif operator == ">=" then
    return comparison >= 0
  elseif operator == "<" then
    return comparison < 0
  elseif operator == "<=" then
    return comparison <= 0
  end
  return false
end

local function caret_upper(version)
  if version.major > 0 then
    return {
      major = version.major + 1,
      minor = 0,
      patch = 0,
      prerelease = {},
    }
  elseif version.minor > 0 then
    return {
      major = 0,
      minor = version.minor + 1,
      patch = 0,
      prerelease = {},
    }
  end
  return {
    major = 0,
    minor = 0,
    patch = version.patch + 1,
    prerelease = {},
  }
end

function Semver.satisfies(version_value, constraint)
  local version, version_error = Semver.parse(version_value)
  if not version then
    return nil, version_error
  end
  if constraint == "*" then
    return #version.prerelease == 0
  end
  if type(constraint) ~= "string" or constraint == "" then
    return nil, "version constraint must be a non-empty string"
  end
  local parts = split(constraint, ",")
  local explicitly_allows_prerelease = false
  for i = 1, #parts do
    local part = parts[i]:match("^%s*(.-)%s*$")
    local operator, target_value
    if part:sub(1, 1) == "^" then
      operator = "^"
      target_value = part:sub(2)
    else
      local first_two = part:sub(1, 2)
      if first_two == ">=" or first_two == "<=" then
        operator = first_two
        target_value = part:sub(3)
      else
        local first = part:sub(1, 1)
        if first == ">" or first == "<" or first == "=" then
          operator = first
          target_value = part:sub(2)
        end
      end
    end
    if not operator then
      return nil, "invalid constraint comparator: " .. part
    end
    local target, target_error = Semver.parse(target_value)
    if not target then
      return nil, target_error
    end
    if #target.prerelease > 0 then
      explicitly_allows_prerelease = true
    end
    local allowed
    if operator == "^" then
      allowed = Semver.compare(version, target) >= 0
        and Semver.compare(version, caret_upper(target)) < 0
    else
      allowed = comparator_allows(version, operator, target)
    end
    if not allowed then
      return false
    end
  end
  if #version.prerelease > 0 and not explicitly_allows_prerelease then
    return false
  end
  return true
end

return Semver
