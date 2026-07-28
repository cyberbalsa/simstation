local Json = require("src.vendor.json")

local AudioCatalog = {}
AudioCatalog.__index = AudioCatalog

local DEFAULT_CATALOG_PATH =
  "assets/runtime/goon/audio/foundation.json"
local DEFAULT_ASSET_ROOT = "assets/runtime/goon/audio/"

local function load_catalog(path)
  local source, read_error = love.filesystem.read(path)
  if not source then
    return nil, read_error or ("could not read " .. path)
  end
  local ok, value = pcall(Json.decode, source)
  if not ok then
    return nil, value
  end
  if type(value) ~= "table"
    or value.format_version ~= 1
    or value.kind ~= "foundation-audio-selection"
    or type(value.entries) ~= "table"
  then
    return nil, "unsupported foundation audio catalog"
  end
  return value
end

function AudioCatalog.new(options)
  options = options or {}
  local catalog, catalog_error = load_catalog(
    options.catalog_path or DEFAULT_CATALOG_PATH
  )
  return setmetatable({
    asset_root = options.asset_root or DEFAULT_ASSET_ROOT,
    catalog = catalog,
    available = catalog ~= nil,
    error = catalog_error,
    prototypes = {},
    source_errors = {},
    voice_limit = catalog and catalog.voice_limit or 0,
  }, AudioCatalog)
end

function AudioCatalog:entry(alias)
  if not self.available then
    return nil
  end
  return self.catalog.entries[alias]
end

function AudioCatalog:new_voice(alias)
  local entry = self:entry(alias)
  if not entry then
    return nil, "unknown foundation audio alias: " .. tostring(alias)
  end
  if self.source_errors[alias] then
    return nil, self.source_errors[alias]
  end
  local prototype = self.prototypes[alias]
  if not prototype then
    local path = self.asset_root .. entry.runtime_path
    local ok, result = pcall(
      love.audio.newSource,
      path,
      entry.source_type or "static"
    )
    if not ok then
      self.source_errors[alias] = result
      return nil, result
    end
    prototype = result
    self.prototypes[alias] = prototype
  end

  local ok, source = pcall(prototype.clone, prototype)
  if not ok then
    self.source_errors[alias] = source
    return nil, source
  end
  source:setLooping(entry.loop == true)
  source:setRelative(true)
  source:setPosition(0, 0, 0)
  return source, entry
end

return AudioCatalog
