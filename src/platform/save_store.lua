local Json = require("src.vendor.json")
local Simulation = require("src.core.simulation")

local SaveStore = {}
SaveStore.__index = SaveStore

local MAGIC = "SSTN1\n"

function SaveStore.new(options)
  options = options or {}
  return setmetatable({
    directory = options.directory or "saves",
    filename = options.filename or "quicksave.sssave",
    mod_lock = options.mod_lock or {},
    hooks = options.hooks or false,
  }, SaveStore)
end

function SaveStore:path()
  return self.directory .. "/" .. self.filename
end

function SaveStore:encode(simulation)
  local header = Json.encode({
    container_version = 1,
    schema_version = simulation.schema_version,
    game_version = "0.0.1-foundation",
    tick = simulation.tick,
    seed = simulation.seed,
    station = simulation.station.name,
    mods = self.mod_lock,
  })
  local payload = Json.encode(simulation:snapshot())
  local compressed = love.data.compress("string", "zlib", payload, 9)
  return MAGIC .. tostring(#header) .. "\n" .. header .. compressed
end

function SaveStore:decode(data)
  if data:sub(1, #MAGIC) ~= MAGIC then
    return nil, "not a Sim Station save"
  end
  local length_end = data:find("\n", #MAGIC + 1, true)
  if not length_end then
    return nil, "save header length is missing"
  end
  local header_length = tonumber(data:sub(#MAGIC + 1, length_end - 1))
  if not header_length or header_length < 2 then
    return nil, "invalid save header length"
  end
  local header_start = length_end + 1
  local header_end = header_start + header_length - 1
  local header_ok, header = pcall(Json.decode, data:sub(header_start, header_end))
  if not header_ok then
    return nil, "invalid save header: " .. tostring(header)
  end
  if header.container_version ~= 1 then
    return nil, "unsupported save container version"
  end
  if Json.encode(header.mods or {}) ~= Json.encode(self.mod_lock) then
    return nil, "save mod lock does not match the enabled package set"
  end
  local compressed = data:sub(header_end + 1)
  local decompress_ok, payload = pcall(
    love.data.decompress,
    "string",
    "zlib",
    compressed
  )
  if not decompress_ok then
    return nil, "save decompression failed: " .. tostring(payload)
  end
  local decode_ok, snapshot = pcall(Json.decode, payload)
  if not decode_ok then
    return nil, "invalid save payload: " .. tostring(snapshot)
  end
  local restore_ok, simulation = pcall(
    Simulation.from_snapshot,
    snapshot,
    { hooks = self.hooks }
  )
  if not restore_ok then
    return nil, "save restore failed: " .. tostring(simulation)
  end
  return simulation, header
end

function SaveStore:save(simulation)
  love.filesystem.createDirectory(self.directory)
  local data = self:encode(simulation)
  local temporary = self:path() .. ".tmp"
  local backup = self:path() .. ".bak"
  local ok, err = love.filesystem.write(temporary, data)
  if not ok then
    return false, err
  end

  local root = love.filesystem.getSaveDirectory()
  local target_path = root .. "/" .. self:path()
  local temporary_path = root .. "/" .. temporary
  local backup_path = root .. "/" .. backup
  os.remove(backup_path)
  os.rename(target_path, backup_path)
  local renamed, rename_err = os.rename(temporary_path, target_path)
  if not renamed then
    os.rename(backup_path, target_path)
    return false, rename_err or "atomic rename failed"
  end
  return true, target_path
end

function SaveStore:load()
  local data, read_err = love.filesystem.read(self:path())
  if not data then
    return nil, read_err or "save not found"
  end
  return self:decode(data)
end

return SaveStore
