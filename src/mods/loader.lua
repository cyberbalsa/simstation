local Json = require("src.vendor.json")
local Manifest = require("src.mods.manifest")
local Resolver = require("src.mods.resolver")
local Registry = require("src.content.registry")
local Hooks = require("src.mods.hooks")
local Stable = require("src.core.stable")

local Loader = {}

local function escape_pattern(value)
  return (value:gsub("([^%w])", "%%%1"))
end

local function glob_pattern(value)
  local token = "\1"
  value = value:gsub("%*%*", token)
  value = escape_pattern(value)
  value = value:gsub(escape_pattern(token), ".*")
  value = value:gsub("%%%*", "[^/]*")
  value = value:gsub("%%%?", "[^/]")
  return "^" .. value .. "$"
end

local function matches_any(path, patterns)
  for i = 1, #(patterns or {}) do
    if path:match(glob_pattern(patterns[i])) then
      return true
    end
  end
  return false
end

local function register_code(pack, hooks, load_chunk)
  for entrypoint_index = 1, #(pack.manifest.entrypoints or {}) do
    local path = pack.manifest.entrypoints[entrypoint_index]
    local chunk, load_error = load_chunk(pack, path)
    assert(chunk, load_error)
    local ok, registration = xpcall(chunk, debug.traceback)
    assert(ok, registration)
    assert(type(registration) == "function",
      "code entrypoint must return a registration function")
    local api = {}
    local function register(kind, hook_id, options, callback)
      options = options or {}
      assert(type(options.name) == "string" and options.name ~= "",
        "hook registration name is required")
      hooks:register(
        pack.manifest.id,
        kind,
        hook_id,
        callback,
        options.priority or 0
      )
    end
    function api:register_observer(hook_id, options, callback)
      register("observe", hook_id, options, callback)
    end
    function api:register_validator(hook_id, options, callback)
      register("validate", hook_id, options, callback)
    end
    function api:register_transform(hook_id, options, callback)
      register("transform", hook_id, options, callback)
    end
    local registered, registration_error = xpcall(
      registration,
      debug.traceback,
      api
    )
    assert(registered, registration_error)
  end
end

-- Records are an adapter-neutral package representation:
-- { root, files = { ["mod.toml"] = "...", ["content/x.json"] = "..." } }.
-- The LÖVE adapter below creates these records for folders and mounted ZIPs;
-- tests and headless tools can construct them without requiring love.*.
function Loader.load(records, options)
  options = options or {}
  local diagnostics = {}
  local packs = {}
  for i = 1, #records do
    local record = records[i]
    local ok, manifest = pcall(Manifest.parse, assert(record.files["mod.toml"]))
    if not ok then
      return nil, {
        stage = "manifest",
        source = record.root,
        message = tostring(manifest),
      }
    end
    manifest.package_sha256 = record.package_sha256
      or string.format("bootstrap-%08x", Stable.hash(record.files))
    packs[#packs + 1] = {
      root = record.root,
      files = record.files,
      manifest = manifest,
      load_chunk = record.load_chunk,
    }
  end

  local manifests = {}
  for i = 1, #packs do
    manifests[i] = packs[i].manifest
  end
  local order, resolve_error = Resolver.resolve(manifests, {
    api_version = options.api_version or "0.1.0",
  })
  if not order then
    return nil, { stage = "resolve", message = resolve_error }
  end

  local by_id = {}
  for i = 1, #packs do
    by_id[packs[i].manifest.id] = packs[i]
  end
  local registry = Registry.new()
  local hooks = Hooks.new(order)
  local trusted = options.trusted_code or {}
  for i = 1, #order do
    local manifest = order[i]
    local pack = by_id[manifest.id]
    local documents = {}
    local sources = {}
    local names = {}
    for path in pairs(pack.files) do
      names[#names + 1] = path
    end
    table.sort(names)
    for j = 1, #names do
      local path = names[j]
      if matches_any(path, manifest.content)
        or matches_any(path, manifest.scenario_maps)
      then
        local ok, document = pcall(Json.decode, pack.files[path])
        if not ok then
          return nil, {
            stage = "content",
            pack = manifest.id,
            source = path,
            message = tostring(document),
          }
        end
        documents[#documents + 1] = document
        sources[#sources + 1] = path
      end
    end
    local content_ok, content_error = pcall(
      registry.add_pack,
      registry,
      manifest,
      documents,
      sources
    )
    if not content_ok then
      return nil, {
        stage = "registry",
        pack = manifest.id,
        message = tostring(content_error),
      }
    end
    if manifest.class == "code" then
      local trust = trusted[manifest.id]
      if trust == true or trust == manifest.package_sha256 then
        local code_ok, code_error = pcall(
          register_code,
          pack,
          hooks,
          pack.load_chunk or function()
            return nil, "package has no code loader"
          end
        )
        if not code_ok then
          return nil, {
            stage = "code",
            pack = manifest.id,
            message = tostring(code_error),
          }
        end
      else
        diagnostics[#diagnostics + 1] = {
          level = "warning",
          pack = manifest.id,
          message = trust
              and "code-pack hash changed; entrypoints skipped until reauthorized"
            or "trusted code pack was not authorized; entrypoints skipped",
        }
      end
    end
  end
  registry:seal()
  local mounts = {}
  for i = 1, #records do
    if records[i].mount_source then
      mounts[#mounts + 1] = {
        source = records[i].mount_source,
        mountpoint = records[i].mountpoint,
      }
    end
  end
  return {
    order = order,
    registry = registry,
    hooks = hooks,
    diagnostics = diagnostics,
    mounts = mounts,
  }
end

local function walk_love(root, relative, result)
  local path = relative == "" and root or root .. "/" .. relative
  local items = love.filesystem.getDirectoryItems(path)
  table.sort(items)
  for i = 1, #items do
    local child_relative = relative == "" and items[i] or relative .. "/" .. items[i]
    local child_path = root .. "/" .. child_relative
    local info = love.filesystem.getInfo(child_path)
    if info and info.type == "directory" then
      walk_love(root, child_relative, result)
    elseif info and info.type == "file" then
      result[child_relative] = assert(love.filesystem.read(child_path))
    end
  end
end

local function little_endian_u64(value)
  local bytes = {}
  for i = 1, 8 do
    bytes[i] = string.char(value % 256)
    value = math.floor(value / 256)
  end
  return table.concat(bytes)
end

local function sha256_hex(value)
  return love.data.encode(
    "string",
    "hex",
    love.data.hash("sha256", value)
  )
end

local function folder_record(root, package_sha256)
  local files = {}
  walk_love(root, "", files)
  local names = {}
  for path in pairs(files) do
    names[#names + 1] = path
  end
  table.sort(names)
  local hash_parts = {}
  for i = 1, #names do
    local path = names[i]
    local data = files[path]
    hash_parts[#hash_parts + 1] = little_endian_u64(#path)
    hash_parts[#hash_parts + 1] = path
    hash_parts[#hash_parts + 1] = little_endian_u64(#data)
    hash_parts[#hash_parts + 1] = data
  end
  package_sha256 = package_sha256 or sha256_hex(table.concat(hash_parts))
  return {
    root = root,
    files = files,
    package_sha256 = package_sha256,
    load_chunk = function(_, path)
      return love.filesystem.load(root .. "/" .. path)
    end,
  }
end

function Loader.discover_love(options)
  options = options or {}
  local records = {}
  local items = love.filesystem.getDirectoryItems("mods")
  table.sort(items)
  local mount_index = 0
  for i = 1, #items do
    local path = "mods/" .. items[i]
    local info = love.filesystem.getInfo(path)
    if info and info.type == "directory"
      and love.filesystem.getInfo(path .. "/mod.toml", "file")
    then
      records[#records + 1] = folder_record(path)
    elseif info and info.type == "file" and items[i]:sub(-7) == ".simmod" then
      mount_index = mount_index + 1
      local mountpoint = "__mods/session-" .. tostring(mount_index)
      local archive_bytes, archive_read_error = love.filesystem.read(path)
      if not archive_bytes then
        return nil, {
          stage = "mount",
          source = path,
          message = tostring(archive_read_error),
        }
      end
      local archive_sha256 = sha256_hex(archive_bytes)
      local mounted, mount_error = love.filesystem.mount(path, mountpoint, true)
      local mount_source = path
      if not mounted then
        -- love.filesystem.mount(path, ...) is intentionally limited to the
        -- save directory. Bundled archives are read through the source VFS
        -- and mounted as FileData instead.
        if archive_bytes then
          mount_source = love.filesystem.newFileData(archive_bytes, items[i])
          mounted = love.filesystem.mount(mount_source, mountpoint, true)
        else
          mount_error = archive_read_error
        end
      end
      if not mounted then
        return nil, {
          stage = "mount",
          source = path,
          message = tostring(mount_error),
        }
      end
      if not love.filesystem.getInfo(mountpoint .. "/mod.toml", "file") then
        love.filesystem.unmount(mount_source)
        return nil, {
          stage = "mount",
          source = path,
          message = "archive has no root mod.toml",
        }
      end
      local record = folder_record(mountpoint, archive_sha256)
      record.mount_source = mount_source
      record.mountpoint = mountpoint
      records[#records + 1] = record
    end
  end
  return Loader.load(records, options)
end

function Loader.read_trust_config(path)
  path = path or "mods/trust.json"
  local source = love.filesystem.read(path)
  if not source then
    return {}
  end
  local ok, config = pcall(Json.decode, source)
  if not ok or type(config) ~= "table" or config.schema ~= 1 then
    return nil, "invalid mod trust config"
  end
  local trusted = config.trusted_code or {}
  if type(trusted) ~= "table" then
    return nil, "trusted_code must be an object"
  end
  for id, hash in pairs(trusted) do
    if type(id) ~= "string"
      or type(hash) ~= "string"
      or not hash:match("^[0-9a-f]+$")
      or #hash ~= 64
    then
      return nil, "trusted_code entries must map pack IDs to SHA-256 hashes"
    end
  end
  return trusted
end

return Loader
