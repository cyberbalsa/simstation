-- A bounded TOML reader for runtime mod manifests.
--
-- Authoring/package validation uses Python's full tomllib implementation.
-- Runtime needs only the closed manifest schema: primitive assignments,
-- arrays, inline tables, [tables], and [[arrays.of.tables]]. Unsupported TOML
-- features fail closed with a line-numbered diagnostic.
local Toml = {}

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function strip_comment(line)
  local quote = false
  local escaped = false
  for index = 1, #line do
    local character = line:sub(index, index)
    if quote then
      if escaped then
        escaped = false
      elseif character == "\\" then
        escaped = true
      elseif character == '"' then
        quote = false
      end
    elseif character == '"' then
      quote = true
    elseif character == "#" then
      return line:sub(1, index - 1)
    end
  end
  return line
end

local ValueParser = {}
ValueParser.__index = ValueParser

function ValueParser.new(source)
  return setmetatable({
    source = source,
    position = 1,
    length = #source,
  }, ValueParser)
end

function ValueParser:error(message)
  error(message .. " at value byte " .. tostring(self.position), 0)
end

function ValueParser:skip_space()
  local _, finish = self.source:find("^[ \t]*", self.position)
  self.position = (finish or self.position - 1) + 1
end

function ValueParser:peek()
  return self.source:sub(self.position, self.position)
end

function ValueParser:string()
  self.position = self.position + 1
  local result = {}
  while self.position <= self.length do
    local character = self:peek()
    self.position = self.position + 1
    if character == '"' then
      return table.concat(result)
    elseif character == "\\" then
      local escape = self:peek()
      self.position = self.position + 1
      local replacements = {
        ['"'] = '"',
        ["\\"] = "\\",
        n = "\n",
        r = "\r",
        t = "\t",
        b = "\b",
        f = "\f",
      }
      if not replacements[escape] then
        self:error("unsupported string escape")
      end
      result[#result + 1] = replacements[escape]
    elseif character:byte() < 32 then
      self:error("control character in string")
    else
      result[#result + 1] = character
    end
  end
  self:error("unterminated string")
end

function ValueParser:bare()
  local start = self.position
  while self.position <= self.length do
    local character = self:peek()
    if character == "," or character == "]" or character == "}" then
      break
    end
    self.position = self.position + 1
  end
  local token = trim(self.source:sub(start, self.position - 1))
  if token == "true" then
    return true
  elseif token == "false" then
    return false
  elseif token:match("^[+-]?%d+$") then
    return tonumber(token)
  end
  self:error("unsupported bare TOML value " .. token)
end

function ValueParser:key()
  self:skip_space()
  if self:peek() == '"' then
    return self:string()
  end
  local key = self.source:match("^([A-Za-z0-9_-]+)", self.position)
  if not key then
    self:error("expected inline table key")
  end
  self.position = self.position + #key
  return key
end

function ValueParser:array()
  self.position = self.position + 1
  local result = {}
  self:skip_space()
  if self:peek() == "]" then
    self.position = self.position + 1
    return result
  end
  while true do
    result[#result + 1] = self:value()
    self:skip_space()
    local delimiter = self:peek()
    if delimiter == "]" then
      self.position = self.position + 1
      return result
    elseif delimiter ~= "," then
      self:error("expected ',' or ']'")
    end
    self.position = self.position + 1
    self:skip_space()
  end
end

function ValueParser:inline_table()
  self.position = self.position + 1
  local result = {}
  self:skip_space()
  if self:peek() == "}" then
    self.position = self.position + 1
    return result
  end
  while true do
    local key = self:key()
    self:skip_space()
    if self:peek() ~= "=" then
      self:error("expected '=' in inline table")
    end
    self.position = self.position + 1
    result[key] = self:value()
    self:skip_space()
    local delimiter = self:peek()
    if delimiter == "}" then
      self.position = self.position + 1
      return result
    elseif delimiter ~= "," then
      self:error("expected ',' or '}'")
    end
    self.position = self.position + 1
    self:skip_space()
  end
end

function ValueParser:value()
  self:skip_space()
  local character = self:peek()
  if character == '"' then
    return self:string()
  elseif character == "[" then
    return self:array()
  elseif character == "{" then
    return self:inline_table()
  end
  return self:bare()
end

local function parse_value(source)
  local parser = ValueParser.new(source)
  local value = parser:value()
  parser:skip_space()
  if parser.position <= parser.length then
    parser:error("trailing TOML value data")
  end
  return value
end

local function section_path(value)
  local result = {}
  for component in value:gmatch("[^.]+") do
    component = trim(component)
    if not component:match("^[A-Za-z0-9_-]+$") then
      error("unsupported TOML section key: " .. component, 0)
    end
    result[#result + 1] = component
  end
  if #result == 0 then
    error("empty TOML section", 0)
  end
  return result
end

local function descend(root, path, array_table)
  local current = root
  for index = 1, #path do
    local key = path[index]
    if index == #path and array_table then
      current[key] = current[key] or {}
      local value = {}
      current[key][#current[key] + 1] = value
      current = value
    else
      current[key] = current[key] or {}
      if type(current[key]) ~= "table" then
        error("TOML section collides with a value: " .. key, 0)
      end
      current = current[key]
    end
  end
  return current
end

function Toml.decode(source, options)
  options = options or {}
  assert(type(source) == "string", "TOML input must be a string")
  assert(#source <= (options.max_bytes or 1024 * 1024), "TOML input is too large")
  local root = {}
  local current = root
  local line_number = 0
  for raw_line in (source .. "\n"):gmatch("(.-)\r?\n") do
    line_number = line_number + 1
    local line = trim(strip_comment(raw_line))
    if line ~= "" then
      local ok, err = pcall(function()
        local array_section = line:match("^%[%[(.-)%]%]$")
        local normal_section = line:match("^%[(.-)%]$")
        if array_section then
          current = descend(root, section_path(array_section), true)
        elseif normal_section then
          current = descend(root, section_path(normal_section), false)
        else
          local key, raw_value = line:match("^([A-Za-z0-9_-]+)%s*=%s*(.+)$")
          if not key then
            error("unsupported TOML statement", 0)
          end
          if current[key] ~= nil then
            error("duplicate TOML key: " .. key, 0)
          end
          current[key] = parse_value(raw_value)
        end
      end)
      if not ok then
        error(string.format("TOML line %d: %s", line_number, tostring(err)), 0)
      end
    end
  end
  return root
end

return Toml
