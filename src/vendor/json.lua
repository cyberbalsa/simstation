-- Small deterministic JSON codec used by the core contracts. It intentionally
-- supports only JSON data: nil/null, booleans, finite numbers, strings, arrays,
-- and string-keyed objects.
local Stable = require("src.core.stable")

local Json = {}
Json.null = {}

local ESCAPES = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
    return ESCAPES[character]
      or string.format("\\u%04x", character:byte())
  end) .. '"'
end

local function array_length(value)
  local maximum = 0
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return nil
    end
    maximum = math.max(maximum, key)
    count = count + 1
  end
  if maximum ~= count then
    return nil
  end
  return maximum
end

local function encode_value(value, stack)
  local kind = type(value)
  if value == Json.null or kind == "nil" then
    return "null"
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "number" then
    assert(value == value and value ~= math.huge and value ~= -math.huge,
      "JSON cannot encode non-finite numbers")
    return string.format("%.17g", value)
  elseif kind == "string" then
    return encode_string(value)
  elseif kind ~= "table" then
    error("JSON cannot encode " .. kind)
  end
  if stack[value] then
    error("JSON cannot encode cyclic tables")
  end
  stack[value] = true

  local length = array_length(value)
  local pieces = {}
  if length then
    for i = 1, length do
      pieces[i] = encode_value(value[i], stack)
    end
    stack[value] = nil
    return "[" .. table.concat(pieces, ",") .. "]"
  end

  local keys = Stable.sorted_keys(value)
  for i = 1, #keys do
    local key = keys[i]
    assert(type(key) == "string", "JSON object keys must be strings")
    pieces[i] = encode_string(key) .. ":" .. encode_value(value[key], stack)
  end
  stack[value] = nil
  return "{" .. table.concat(pieces, ",") .. "}"
end

function Json.encode(value)
  return encode_value(value, {})
end

local Parser = {}
Parser.__index = Parser

function Parser.new(source)
  return setmetatable({ source = source, position = 1, length = #source }, Parser)
end

function Parser:error(message)
  error(string.format("JSON error at byte %d: %s", self.position, message), 0)
end

function Parser:skip_space()
  local _, finish = self.source:find("^[ \t\r\n]*", self.position)
  self.position = (finish or self.position - 1) + 1
end

function Parser:peek()
  return self.source:sub(self.position, self.position)
end

local SIMPLE_ESCAPE = {
  ['"'] = '"',
  ["\\"] = "\\",
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
}

local function utf8_from_codepoint(codepoint)
  if codepoint <= 0x7f then
    return string.char(codepoint)
  elseif codepoint <= 0x7ff then
    return string.char(
      0xc0 + math.floor(codepoint / 0x40),
      0x80 + (codepoint % 0x40)
    )
  elseif codepoint <= 0xffff then
    return string.char(
      0xe0 + math.floor(codepoint / 0x1000),
      0x80 + (math.floor(codepoint / 0x40) % 0x40),
      0x80 + (codepoint % 0x40)
    )
  end
  return string.char(
    0xf0 + math.floor(codepoint / 0x40000),
    0x80 + (math.floor(codepoint / 0x1000) % 0x40),
    0x80 + (math.floor(codepoint / 0x40) % 0x40),
    0x80 + (codepoint % 0x40)
  )
end

function Parser:parse_string()
  if self:peek() ~= '"' then
    self:error("expected string")
  end
  self.position = self.position + 1
  local pieces = {}
  local start = self.position
  while self.position <= self.length do
    local character = self:peek()
    if character == '"' then
      pieces[#pieces + 1] = self.source:sub(start, self.position - 1)
      self.position = self.position + 1
      return table.concat(pieces)
    elseif character == "\\" then
      pieces[#pieces + 1] = self.source:sub(start, self.position - 1)
      self.position = self.position + 1
      local escape = self:peek()
      if escape == "u" then
        local hex = self.source:sub(self.position + 1, self.position + 4)
        if not hex:match("^%x%x%x%x$") then
          self:error("invalid unicode escape")
        end
        local codepoint = tonumber(hex, 16)
        self.position = self.position + 5
        if codepoint >= 0xd800 and codepoint <= 0xdbff
          and self.source:sub(self.position, self.position + 1) == "\\u"
        then
          local low_hex = self.source:sub(self.position + 2, self.position + 5)
          local low = tonumber(low_hex, 16)
          if low and low >= 0xdc00 and low <= 0xdfff then
            codepoint = 0x10000 + (codepoint - 0xd800) * 0x400 + low - 0xdc00
            self.position = self.position + 6
          end
        end
        pieces[#pieces + 1] = utf8_from_codepoint(codepoint)
      else
        local replacement = SIMPLE_ESCAPE[escape]
        if not replacement then
          self:error("invalid string escape")
        end
        pieces[#pieces + 1] = replacement
        self.position = self.position + 1
      end
      start = self.position
    elseif character:byte() < 32 then
      self:error("control character in string")
    else
      self.position = self.position + 1
    end
  end
  self:error("unterminated string")
end

function Parser:parse_number()
  local token = self.source:match(
    "^-?%d+%.?%d*[eE]?[+-]?%d*",
    self.position
  )
  if not token or token == "" then
    self:error("invalid number")
  end
  local value = tonumber(token)
  if not value then
    self:error("invalid number")
  end
  self.position = self.position + #token
  return value
end

function Parser:parse_array()
  self.position = self.position + 1
  self:skip_space()
  local value = {}
  if self:peek() == "]" then
    self.position = self.position + 1
    return value
  end
  while true do
    value[#value + 1] = self:parse_value()
    self:skip_space()
    local delimiter = self:peek()
    if delimiter == "]" then
      self.position = self.position + 1
      return value
    elseif delimiter ~= "," then
      self:error("expected ',' or ']'")
    end
    self.position = self.position + 1
    self:skip_space()
  end
end

function Parser:parse_object()
  self.position = self.position + 1
  self:skip_space()
  local value = {}
  if self:peek() == "}" then
    self.position = self.position + 1
    return value
  end
  while true do
    local key = self:parse_string()
    self:skip_space()
    if self:peek() ~= ":" then
      self:error("expected ':'")
    end
    self.position = self.position + 1
    self:skip_space()
    value[key] = self:parse_value()
    self:skip_space()
    local delimiter = self:peek()
    if delimiter == "}" then
      self.position = self.position + 1
      return value
    elseif delimiter ~= "," then
      self:error("expected ',' or '}'")
    end
    self.position = self.position + 1
    self:skip_space()
  end
end

function Parser:parse_value()
  self:skip_space()
  local character = self:peek()
  if character == '"' then
    return self:parse_string()
  elseif character == "{" then
    return self:parse_object()
  elseif character == "[" then
    return self:parse_array()
  elseif character == "-" or character:match("%d") then
    return self:parse_number()
  elseif self.source:sub(self.position, self.position + 3) == "true" then
    self.position = self.position + 4
    return true
  elseif self.source:sub(self.position, self.position + 4) == "false" then
    self.position = self.position + 5
    return false
  elseif self.source:sub(self.position, self.position + 3) == "null" then
    self.position = self.position + 4
    return Json.null
  end
  self:error("unexpected token")
end

function Json.decode(source)
  assert(type(source) == "string", "JSON source must be a string")
  local parser = Parser.new(source)
  local result = parser:parse_value()
  parser:skip_space()
  if parser.position <= parser.length then
    parser:error("trailing content")
  end
  return result
end

return Json
