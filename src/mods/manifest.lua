local Semver = require("src.mods.semver")
local Toml = require("src.vendor.toml_subset")

local Manifest = {}

local ROOT_KEYS = {
  schema = true,
  id = true,
  version = true,
  name = true,
  description = true,
  authors = true,
  license = true,
  homepage = true,
  api = true,
  class = true,
  load_priority = true,
  content = true,
  localization = true,
  atlas_indexes = true,
  audio_manifests = true,
  scenario_maps = true,
  dependencies = true,
  optional_dependencies = true,
  conflicts = true,
  load_after = true,
  load_before = true,
  replaces = true,
  entrypoints = true,
  state = true,
}

local function valid_pack_id(value)
  if type(value) ~= "string"
    or value:sub(1, 1) == "."
    or value:sub(-1) == "."
    or value:find("..", 1, true)
    or not value:find(".", 1, true)
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

local function array_of_strings(value, name)
  assert(type(value or {}) == "table", name .. " must be an array")
  for i = 1, #(value or {}) do
    assert(type(value[i]) == "string", name .. " must contain strings")
  end
end

local function safe_relative_path(path)
  if type(path) ~= "string"
    or path == ""
    or path:sub(1, 1) == "/"
    or path:find("\\", 1, true)
    or path:find("%z")
    or path:find("//", 1, true)
    or path:sub(-1) == "/"
    or path:match("^%a:")
  then
    return false
  end
  for component in path:gmatch("[^/]+") do
    if component == "." or component == ".." or component == "" then
      return false
    end
  end
  return #path <= 240
end

local function validate_records(records, name)
  assert(type(records or {}) == "table", name .. " must be an array")
  for i = 1, #(records or {}) do
    local record = records[i]
    assert(type(record) == "table", name .. " record must be a table")
    assert(valid_pack_id(record.id), name .. " record has an invalid ID")
    assert(type(record.version) == "string", name .. " record needs a version")
    local valid, err = Semver.satisfies("0.1.0", record.version)
    assert(valid ~= nil, name .. " record has an invalid constraint: " .. tostring(err))
  end
end

function Manifest.parse(source)
  local manifest = Toml.decode(source, { max_bytes = 1024 * 1024 })
  for key in pairs(manifest) do
    assert(ROOT_KEYS[key], "unknown manifest key: " .. tostring(key))
  end
  assert(manifest.schema == 1, "manifest schema must be 1")
  assert(valid_pack_id(manifest.id), "invalid reverse-DNS mod ID")
  assert(Semver.parse(manifest.version))
  assert(type(manifest.name) == "string" and manifest.name ~= "", "mod name is required")
  assert(type(manifest.authors) == "table" and #manifest.authors > 0,
    "mod authors are required")
  assert(type(manifest.license) == "string" and manifest.license ~= "",
    "mod license is required")
  assert(manifest.class == "data" or manifest.class == "code",
    "mod class must be data or code")
  manifest.api = manifest.api or "*"
  manifest.load_priority = manifest.load_priority or 0
  assert(manifest.load_priority % 1 == 0
    and manifest.load_priority >= -1000
    and manifest.load_priority <= 1000,
    "load_priority is out of range")

  local path_fields = {
    "content",
    "localization",
    "atlas_indexes",
    "audio_manifests",
    "scenario_maps",
    "entrypoints",
  }
  for i = 1, #path_fields do
    local field = path_fields[i]
    array_of_strings(manifest[field], field)
    for j = 1, #(manifest[field] or {}) do
      assert(safe_relative_path(manifest[field][j]), "unsafe " .. field .. " path")
    end
  end
  array_of_strings(manifest.load_after, "load_after")
  array_of_strings(manifest.load_before, "load_before")
  array_of_strings(manifest.replaces, "replaces")
  validate_records(manifest.dependencies, "dependencies")
  validate_records(manifest.optional_dependencies, "optional_dependencies")
  validate_records(manifest.conflicts, "conflicts")
  if manifest.class == "code" then
    assert(#(manifest.entrypoints or {}) > 0, "code mod requires an entrypoint")
  elseif #(manifest.entrypoints or {}) > 0 then
    error("data mod cannot declare code entrypoints")
  end
  return manifest
end

return Manifest
