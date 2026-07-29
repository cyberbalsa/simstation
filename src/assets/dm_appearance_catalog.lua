local Json = require("src.vendor.json")

local DmAppearanceCatalog = {}
DmAppearanceCatalog.__index = DmAppearanceCatalog

local DEFAULT_CATALOG_PATH =
  "assets/runtime/goon/graphics/dm-appearances.json"
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
local DIAGONAL_FALLBACKS = {
  northeast = { "north", "east" },
  northwest = { "north", "west" },
  southeast = { "south", "east" },
  southwest = { "south", "west" },
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
    or value.kind ~= "goon-dm-appearance-selection"
    or type(value.pages) ~= "table"
    or type(value.sprites) ~= "table"
    or type(value.rules) ~= "table"
  then
    return nil, "unsupported Goon DM appearance catalog"
  end
  return value
end

local function sorted_keys(value)
  local result = {}
  for key in pairs(value) do
    result[#result + 1] = key
  end
  table.sort(result)
  return result
end

local function page_key(bundle, page)
  return bundle .. ":" .. tostring(page)
end

local function state_key(icon, state)
  return icon .. "\0" .. state
end

local function rule_key(role, path)
  return role .. "\0" .. path
end

local function direction_frames(entry, direction)
  if direction and entry.directions[direction] then
    return direction, entry.directions[direction]
  end
  local available = sorted_keys(entry.directions)
  if #available == 1 then
    local only = available[1]
    return only, entry.directions[only]
  end
  local fallbacks = direction and DIAGONAL_FALLBACKS[direction]
  if fallbacks then
    for index = 1, #fallbacks do
      local candidate = fallbacks[index]
      if entry.directions[candidate] then
        return candidate, entry.directions[candidate]
      end
    end
  end
  if direction then
    return nil, nil
  end
  for index = 1, #DIRECTION_FALLBACKS do
    local candidate = DIRECTION_FALLBACKS[index]
    if entry.directions[candidate] then
      return candidate, entry.directions[candidate]
    end
  end
  return nil, nil
end

local function path_is_in_subtree(path, root)
  return path == root
    or (
      path:sub(1, #root) == root
      and path:sub(#root + 1, #root + 1) == "/"
    )
end

function DmAppearanceCatalog.new(options)
  options = options or {}
  local catalog_path = options.catalog_path or DEFAULT_CATALOG_PATH
  local catalog, catalog_error = load_catalog(catalog_path)
  local self = setmetatable({
    asset_root = options.asset_root or DEFAULT_ASSET_ROOT,
    available = catalog ~= nil,
    catalog = catalog,
    error = catalog_error,
    pages = {},
    images = {},
    page_errors = {},
    drawables = {},
    exact_rules = {},
    subtree_rules = {},
    rule_cache = {},
    state_sprites = {},
  }, DmAppearanceCatalog)
  if not catalog then
    return self
  end

  for index = 1, #catalog.pages do
    local page = catalog.pages[index]
    if type(page) ~= "table"
      or type(page.bundle) ~= "string"
      or type(page.page) ~= "number"
      or type(page.runtime_path) ~= "string"
    then
      self.available = false
      self.error = "invalid Goon DM appearance page record"
      return self
    end
    self.pages[page_key(page.bundle, page.page)] = page
  end

  local sprite_ids = sorted_keys(catalog.sprites)
  for index = 1, #sprite_ids do
    local sprite_id = sprite_ids[index]
    local sprite = catalog.sprites[sprite_id]
    if type(sprite) ~= "table"
      or sprite.id ~= sprite_id
      or type(sprite.bundle) ~= "string"
      or type(sprite.source_path) ~= "string"
      or type(sprite.source_state) ~= "string"
      or type(sprite.directions) ~= "table"
    then
      self.available = false
      self.error = "invalid Goon DM appearance sprite record"
      return self
    end
    local key = state_key(sprite.source_path, sprite.source_state)
    if self.state_sprites[key] == nil then
      self.state_sprites[key] = sprite_id
    end
  end

  for index = 1, #catalog.rules do
    local rule = catalog.rules[index]
    if type(rule) ~= "table"
      or type(rule.type_path) ~= "string"
      or (rule.match ~= "exact" and rule.match ~= "subtree")
      or (rule.role ~= "turf" and rule.role ~= "object")
      or type(rule.parts) ~= "table"
    then
      self.available = false
      self.error = "invalid Goon DM appearance rule"
      return self
    end
    if rule.match == "exact" then
      self.exact_rules[rule_key(rule.role, rule.type_path)] = rule
    else
      self.subtree_rules[#self.subtree_rules + 1] = rule
    end
  end
  table.sort(self.subtree_rules, function(left, right)
    if #left.type_path ~= #right.type_path then
      return #left.type_path > #right.type_path
    end
    if left.role ~= right.role then
      return left.role < right.role
    end
    return left.type_path < right.type_path
  end)
  return self
end

function DmAppearanceCatalog:_load_page(bundle, page_number)
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
    local message = "appearance catalog does not declare atlas page " .. key
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

function DmAppearanceCatalog:_sprite(sprite_id, direction, frame_number)
  local entry = self.catalog.sprites[sprite_id]
  if not entry then
    return nil, "unknown appearance sprite: " .. tostring(sprite_id)
  end
  local resolved_direction, frames = direction_frames(entry, direction)
  if not frames or #frames == 0 then
    return nil, "appearance sprite has no usable frames: " .. sprite_id
  end
  frame_number = math.floor(tonumber(frame_number) or 1)
  frame_number = ((frame_number - 1) % #frames) + 1
  local cache_key =
    sprite_id .. "\0" .. resolved_direction .. "\0" .. tostring(frame_number)
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
    direction = resolved_direction,
    duration_ds = tonumber(frame.duration_ds) or 1,
    height = frame.h,
    id = sprite_id,
    image = image,
    quad = quad,
    source_path = entry.source_path,
    source_state = entry.source_state,
    width = frame.w,
  }
  self.drawables[cache_key] = drawable
  return drawable
end

function DmAppearanceCatalog:_rule(role, source_path)
  local key = rule_key(role, source_path)
  local cached = self.rule_cache[key]
  if cached ~= nil then
    return cached or nil
  end
  local exact = self.exact_rules[key]
  if exact then
    self.rule_cache[key] = exact
    return exact
  end
  for index = 1, #self.subtree_rules do
    local candidate = self.subtree_rules[index]
    if candidate.role == role
      and path_is_in_subtree(source_path, candidate.type_path)
    then
      self.rule_cache[key] = candidate
      return candidate
    end
  end
  self.rule_cache[key] = false
  return nil
end

function DmAppearanceCatalog:rule_for(role, source_path)
  if not self.available then
    return nil
  end
  return self:_rule(role, source_path)
end

local function requested_state(appearance)
  return appearance.resolved_icon_state
    or appearance.icon_state_override
end

function DmAppearanceCatalog:resolve(appearance, runtime_state)
  if not self.available then
    return nil, self.error
  end
  local rule = self:_rule(appearance.role, appearance.source_path)
  if not rule then
    return nil, "unmapped DM appearance: " .. appearance.source_path
  end
  local result = {}
  for part_index = 1, #rule.parts do
    local part = rule.parts[part_index]
    local sprite_id = part.sprite_id
    local state
    if type(runtime_state) == "table" then
      state = runtime_state[part_index]
    elseif type(runtime_state) == "string" then
      state = runtime_state
    elseif #rule.parts == 1 then
      state = requested_state(appearance)
    end
    local icon = part.source_icon
    if #rule.parts == 1 and appearance.icon_override then
      icon = appearance.icon_override
      state = state or part.source_state
    end
    if state then
      sprite_id = icon and self.state_sprites[state_key(icon, state)] or nil
      if not sprite_id then
        return nil, string.format(
          "unmapped DM icon state %s:%s",
          tostring(icon),
          tostring(state)
        )
      end
    end
    local direction = appearance.direction or "south"
    if part.direction_policy == "fixed" then
      direction = part.fixed_direction or "south"
    end
    local drawable, drawable_error =
      self:_sprite(sprite_id, direction, 1)
    if not drawable then
      return nil, drawable_error
    end
    result[#result + 1] = {
      drawable = drawable,
      part = part_index,
      metadata = part,
    }
  end
  return result, nil, rule
end

return DmAppearanceCatalog
