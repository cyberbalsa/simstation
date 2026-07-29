local Constants = require("src.core.constants")

local LightField = {}
LightField.__index = LightField

LightField.UNITS = 1024
LightField.GOON_QUADRATIC_SCALE = 2.2
LightField.GOON_CONSTANT_OFFSET = -0.11
LightField.GOON_VISIBILITY_THRESHOLD = 2 / 256

local function opaque_at(world, x, y)
  local index = world:index(x, y)
  if not index then
    return false
  end
  local structure = world.structure[index]
  return structure == Constants.STRUCTURE.WALL
    or structure == Constants.STRUCTURE.DOOR_CLOSED
end

function LightField.is_opaque(world, index)
  if not index then
    return false
  end
  local structure = world.structure[index]
  return structure == Constants.STRUCTURE.WALL
    or structure == Constants.STRUCTURE.DOOR_CLOSED
end

-- Integer supercover traversal between tile centers. The destination itself
-- is visible even when opaque, matching Goon's lit wall-edge behavior. Two
-- touching opaque cardinal tiles close a diagonal corner.
function LightField.line_visible(world, source_x, source_y, target_x, target_y)
  if source_x == target_x and source_y == target_y then
    return true
  end
  local delta_x = target_x - source_x
  local delta_y = target_y - source_y
  local count_x = math.abs(delta_x)
  local count_y = math.abs(delta_y)
  local step_x = delta_x < 0 and -1 or delta_x > 0 and 1 or 0
  local step_y = delta_y < 0 and -1 or delta_y > 0 and 1 or 0
  local crossed_x = 0
  local crossed_y = 0
  local x = source_x
  local y = source_y

  while crossed_x < count_x or crossed_y < count_y do
    local through_x = (1 + crossed_x * 2) * count_y
    local through_y = (1 + crossed_y * 2) * count_x
    if through_x == through_y then
      if opaque_at(world, x + step_x, y)
        and opaque_at(world, x, y + step_y)
      then
        return false
      end
      x = x + step_x
      y = y + step_y
      crossed_x = crossed_x + 1
      crossed_y = crossed_y + 1
    elseif through_x < through_y then
      x = x + step_x
      crossed_x = crossed_x + 1
    else
      y = y + step_y
      crossed_y = crossed_y + 1
    end

    if x == target_x and y == target_y then
      return true
    end
    local index = world:index(x, y)
    if LightField.is_opaque(world, index) then
      return false
    end
  end
  return true
end

function LightField.projection_signature(world)
  local first = 1
  local second = 7
  for index = 1, world.size do
    local surface = world.tile[index] == Constants.TILE.SPACE and 1 or 0
    local opaque = LightField.is_opaque(world, index) and 2 or 0
    local value = surface + opaque
    first = (first * 131 + value * 17 + index) % 2147483647
    second = (second * 137 + value * 29 + index) % 2147483629
  end
  return string.format("%d:%d", first, second)
end

-- Retained for presentation extensions built against the initial prototype.
LightField.opacity_signature = LightField.projection_signature

local function channel_units(value)
  return math.floor(value * LightField.UNITS / 255 + 0.5)
end

local function fill_ambient(world, settings, red, green, blue)
  local station = settings.station_ambient_srgb8
  local space = settings.space_ambient_srgb8
  local station_r = channel_units(station[1])
  local station_g = channel_units(station[2])
  local station_b = channel_units(station[3])
  local space_r = channel_units(space[1])
  local space_g = channel_units(space[2])
  local space_b = channel_units(space[3])
  for index = 1, world.size do
    if world.tile[index] == Constants.TILE.SPACE then
      red[index] = space_r
      green[index] = space_g
      blue[index] = space_b
    else
      red[index] = station_r
      green[index] = station_g
      blue[index] = station_b
    end
  end
end

local function source_strength(
  profile,
  radius_256,
  level_ppm,
  distance_squared,
  distance
)
  local brightness =
    profile.intensity_ppm * level_ppm / 1000000000000
  if brightness <= 0 then
    return 0
  end
  if profile.falloff == "goon-robust" then
    local height = profile.height_256 / 256
    local attenuation =
      brightness
        * LightField.GOON_QUADRATIC_SCALE
        / (distance_squared + height * height)
      + LightField.GOON_CONSTANT_OFFSET
    if attenuation < LightField.GOON_VISIBILITY_THRESHOLD then
      return 0
    end
    return brightness * attenuation
  end
  local radius = radius_256 / 256
  if radius <= 0 then
    return distance == 0 and brightness or 0
  end
  local remaining = math.max(0, 1 - distance / radius)
  if profile.falloff == "constant" then
    return brightness
  elseif profile.falloff == "linear" then
    return brightness * remaining
  end
  return brightness * remaining * remaining * (3 - 2 * remaining)
end

local function add_emitter(field, world, emitter)
  local profile = emitter.profile
  local radius_256 = emitter.radius_256
  local min_x = math.max(
    1,
    math.ceil((emitter.x_256 - radius_256 - 128) / 256) + 1
  )
  local max_x = math.min(
    world.width,
    math.floor((emitter.x_256 + radius_256 - 128) / 256) + 1
  )
  local min_y = math.max(
    1,
    math.ceil((emitter.y_256 - radius_256 - 128) / 256) + 1
  )
  local max_y = math.min(
    world.height,
    math.floor((emitter.y_256 + radius_256 - 128) / 256) + 1
  )
  local radius_squared = radius_256 * radius_256

  for y = min_y, max_y do
    local target_y_256 = (y - 1) * 256 + 128
    local delta_y_256 = target_y_256 - emitter.y_256
    for x = min_x, max_x do
      local target_x_256 = (x - 1) * 256 + 128
      local delta_x_256 = target_x_256 - emitter.x_256
      local fixed_distance_squared =
        delta_x_256 * delta_x_256 + delta_y_256 * delta_y_256
      local in_profile_footprint =
        profile.falloff == "goon-robust"
        or fixed_distance_squared <= radius_squared
      if in_profile_footprint then
        field.candidate_cells = field.candidate_cells + 1
        local visible = profile.occlusion == "none"
          or LightField.line_visible(
            world,
            emitter.tile_x,
            emitter.tile_y,
            x,
            y
          )
        if visible then
          local distance_squared = fixed_distance_squared / 65536
          local distance = math.sqrt(distance_squared)
          local strength = source_strength(
            profile,
            radius_256,
            emitter.level_ppm,
            distance_squared,
            distance
          )
          if strength > 0 then
            local index = assert(world:index(x, y))
            local scalar = strength * LightField.UNITS / 255
            field.red[index] = field.red[index]
              + math.floor(profile.color_srgb8[1] * scalar + 0.5)
            field.green[index] = field.green[index]
              + math.floor(profile.color_srgb8[2] * scalar + 0.5)
            field.blue[index] = field.blue[index]
              + math.floor(profile.color_srgb8[3] * scalar + 0.5)
            field.lit_cells = field.lit_cells + 1
          end
        end
      end
    end
  end
end

function LightField.build(world, settings, emitters)
  local field = setmetatable({
    width = world.width,
    height = world.height,
    size = world.size,
    red = {},
    green = {},
    blue = {},
    emitters = emitters,
    emitter_count = #emitters,
    candidate_cells = 0,
    lit_cells = 0,
  }, LightField)
  fill_ambient(world, settings, field.red, field.green, field.blue)
  for index = 1, #emitters do
    add_emitter(field, world, emitters[index])
  end
  return field
end

function LightField:channel(index, channel)
  local values = channel == 1 and self.red
    or channel == 2 and self.green
    or self.blue
  return math.min(LightField.UNITS, math.max(0, values[index] or 0))
end

function LightField:rgb(index)
  return
    self:channel(index, 1),
    self:channel(index, 2),
    self:channel(index, 3)
end

return LightField
