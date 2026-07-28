local Json = require("src.vendor.json")

local AtlasCatalog = {}
AtlasCatalog.__index = AtlasCatalog

local DEFAULT_CATALOG_PATH =
  "assets/runtime/goon/graphics/foundation.json"
local DEFAULT_ASSET_ROOT = "assets/runtime/goon/graphics/"
local DIRECTION_FALLBACKS = {
  "south",
  "north",
  "east",
  "west",
  "southeast",
  "southwest",
  "northeast",
  "northwest",
}

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
    or value.kind ~= "foundation-graphics-selection"
    or type(value.pages) ~= "table"
    or type(value.sprites) ~= "table"
  then
    return nil, "unsupported foundation graphics catalog"
  end
  return value
end

local function page_key(bundle, page)
  return bundle .. ":" .. tostring(page)
end

function AtlasCatalog.new(options)
  options = options or {}
  local catalog_path = options.catalog_path or DEFAULT_CATALOG_PATH
  local catalog, catalog_error = load_catalog(catalog_path)
  local self = setmetatable({
    asset_root = options.asset_root or DEFAULT_ASSET_ROOT,
    catalog = catalog,
    available = catalog ~= nil,
    error = catalog_error,
    pages = {},
    images = {},
    page_errors = {},
    drawables = {},
  }, AtlasCatalog)
  if not catalog then
    return self
  end
  for i = 1, #catalog.pages do
    local page = catalog.pages[i]
    if type(page.bundle) ~= "string"
      or type(page.page) ~= "number"
      or type(page.runtime_path) ~= "string"
    then
      self.available = false
      self.error = "invalid foundation atlas page record"
      return self
    end
    self.pages[page_key(page.bundle, page.page)] = page
  end
  return self
end

function AtlasCatalog:has(alias)
  return self.available and self.catalog.sprites[alias] ~= nil
end

function AtlasCatalog:has_all(aliases)
  if not self.available then
    return false
  end
  for i = 1, #aliases do
    if not self:has(aliases[i]) then
      return false
    end
  end
  return true
end

function AtlasCatalog:_load_page(bundle, page_number)
  local key = page_key(bundle, page_number)
  local image = self.images[key]
  if image then
    return image
  end
  if self.page_errors[key] then
    return nil, self.page_errors[key]
  end
  local page = self.pages[key]
  if not page then
    local message = "foundation catalog does not declare atlas page " .. key
    self.page_errors[key] = message
    return nil, message
  end
  local path = self.asset_root .. page.runtime_path
  local ok, result = pcall(love.graphics.newImage, path, {
    mipmaps = false,
    linear = false,
    dpiscale = 1,
  })
  if not ok then
    self.page_errors[key] = result
    return nil, result
  end
  result:setFilter("nearest", "nearest", 1)
  result:setWrap("clamp", "clamp")
  self.images[key] = result
  return result
end

local function direction_frames(entry, direction)
  if direction and entry.directions[direction] then
    return direction, entry.directions[direction]
  end
  for i = 1, #DIRECTION_FALLBACKS do
    local candidate = DIRECTION_FALLBACKS[i]
    if entry.directions[candidate] then
      return candidate, entry.directions[candidate]
    end
  end
  return nil, nil
end

function AtlasCatalog:sprite(alias, direction, frame_number)
  if not self.available then
    return nil, self.error
  end
  local entry = self.catalog.sprites[alias]
  if not entry then
    return nil, "unknown foundation sprite alias: " .. tostring(alias)
  end
  local resolved_direction, frames = direction_frames(entry, direction)
  if not frames or #frames == 0 then
    return nil, "sprite has no usable frames: " .. tostring(alias)
  end
  frame_number = math.floor(tonumber(frame_number) or 1)
  frame_number = ((frame_number - 1) % #frames) + 1
  local cache_key =
    alias .. "\0" .. resolved_direction .. "\0" .. tostring(frame_number)
  local cached = self.drawables[cache_key]
  if cached then
    return cached
  end
  local frame = frames[frame_number]
  local image, image_error = self:_load_page(entry.bundle, frame.page)
  if not image then
    return nil, image_error
  end
  local ok, quad = pcall(
    love.graphics.newQuad,
    frame.x,
    frame.y,
    frame.w,
    frame.h,
    image:getWidth(),
    image:getHeight()
  )
  if not ok then
    return nil, quad
  end
  local drawable = {
    alias = alias,
    id = entry.id,
    image = image,
    quad = quad,
    width = frame.w,
    height = frame.h,
    duration_ds = tonumber(frame.duration_ds) or 1,
  }
  self.drawables[cache_key] = drawable
  return drawable
end

function AtlasCatalog:new_batch(alias, capacity, usage)
  local sprite, sprite_error = self:sprite(alias, "south", 1)
  if not sprite then
    return nil, sprite_error
  end
  local ok, batch = pcall(
    love.graphics.newSpriteBatch,
    sprite.image,
    capacity,
    usage or "static"
  )
  if not ok then
    return nil, batch
  end
  return {
    batch = batch,
    quad = sprite.quad,
    width = sprite.width,
    height = sprite.height,
  }
end

return AtlasCatalog
