local Constants = require("src.core.constants")
local LightField = require("src.presentation.light_field")
local LightSources = require("src.presentation.light_sources")
local LightingContent = require("src.content.lighting")

local Lighting = {}
Lighting.__index = Lighting

local SHADER_SOURCE = [[
vec4 effect(
  vec4 color,
  Image texture,
  vec2 texture_coords,
  vec2 screen_coords
) {
  vec3 light = Texel(texture, texture_coords).rgb;
  return vec4(light * color.rgb, 1.0);
}
]]

local function revision_signature(values)
  local first = 1
  local second = 7
  for index = 1, #values do
    local value = values[index] or 0
    first = (first * 131 + value * 17 + index) % 2147483647
    second = (second * 137 + value * 29 + index) % 2147483629
  end
  return tostring(first) .. ":" .. tostring(second)
end

local function make_bloom_image()
  local size = 65
  local radius = (size - 1) / 2
  local data = love.image.newImageData(size, size, "rgba8")
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      local delta_x = x - radius
      local delta_y = y - radius
      local distance = math.sqrt(
        delta_x * delta_x + delta_y * delta_y
      ) / radius
      local alpha = math.max(0, 1 - distance)
      data:setPixel(x, y, 1, 1, 1, alpha * alpha)
    end
  end
  local image = love.graphics.newImage(data, {
    mipmaps = false,
    linear = true,
    dpiscale = 1,
  })
  image:setFilter("linear", "linear", 1)
  image:setWrap("clamp", "clamp")
  return image
end

local function compile_shader(enabled)
  if not enabled then
    return nil, "disabled by lighting settings"
  end
  local ok, shader = pcall(love.graphics.newShader, SHADER_SOURCE)
  if not ok then
    return nil, tostring(shader)
  end
  return shader
end

local function make_light_image(width, height, linear)
  local data = love.image.newImageData(width, height, "rgba8")
  local image = love.graphics.newImage(data, {
    mipmaps = false,
    linear = linear,
    dpiscale = 1,
  })
  local filter = linear and "linear" or "nearest"
  image:setFilter(filter, filter, 1)
  image:setWrap("clamp", "clamp")
  return data, image
end

local function timer_now()
  if love.timer and love.timer.getTime then
    return love.timer.getTime()
  end
  return os.clock()
end

function Lighting.new(world, content)
  local contract = LightingContent.resolve(content)
  local settings = contract.settings
  local image_data, image = make_light_image(
    world.width,
    world.height,
    settings.linear_filter
  )
  local bloom_image = make_bloom_image()
  local bloom_batch = love.graphics.newSpriteBatch(
    bloom_image,
    settings.max_emitters,
    "stream"
  )
  local shader, shader_error = compile_shader(settings.shader)
  return setmetatable({
    content = content,
    contract = contract,
    image_data = image_data,
    image = image,
    shader = shader,
    shader_error = shader_error,
    bloom_image = bloom_image,
    bloom_batch = bloom_batch,
    field = nil,
    emitters = {},
    emitter_signature = false,
    projection_signature = false,
    observed_tick = false,
    observed_chunks = false,
    observed_power_revision = false,
    observed_gas_revision = false,
    observed_machine_signature = false,
    rebuild_count = 0,
    upload_count = 0,
    dropped_emitters = 0,
    work_units = 0,
    candidate_checks = 0,
    candidate_limit_reached = false,
    bloom_count = 0,
    last_build_ms = 0,
    last_candidate_cells = 0,
    last_lit_cells = 0,
  }, Lighting)
end

function Lighting:_upload()
  local units = LightField.UNITS
  for y = 1, self.field.height do
    for x = 1, self.field.width do
      local index = (y - 1) * self.field.width + x
      local red, green, blue = self.field:rgb(index)
      self.image_data:setPixel(
        x - 1,
        y - 1,
        red / units,
        green / units,
        blue / units,
        1
      )
    end
  end
  self.image:replacePixels(self.image_data)
  self.upload_count = self.upload_count + 1
end

function Lighting:update(world, machines, tick)
  local chunk_signature = revision_signature(world.chunk_revision)
  local machine_signature = LightSources.machine_signature(machines)
  local current_tick = tick or 0
  local unchanged = self.observed_tick == (tick or 0)
    and self.observed_chunks == chunk_signature
    and self.observed_power_revision == world.power_revision
    and self.observed_gas_revision == world.gas_revision
    and self.observed_machine_signature == machine_signature
  if unchanged then
    return false
  end
  local chunks_changed = self.observed_chunks ~= chunk_signature
  self.observed_tick = current_tick
  self.observed_chunks = chunk_signature
  self.observed_power_revision = world.power_revision
  self.observed_gas_revision = world.gas_revision
  self.observed_machine_signature = machine_signature

  local emitters,
    emitter_signature,
    dropped,
    work_units,
    candidate_checks,
    candidate_limit_reached =
    LightSources.collect(
      world,
      machines,
      self.content,
      self.contract,
      current_tick
    )
  local projection_signature = self.projection_signature
  if not self.field or chunks_changed then
    projection_signature = LightField.projection_signature(world)
  end
  self.dropped_emitters = dropped
  self.work_units = work_units
  self.candidate_checks = candidate_checks
  self.candidate_limit_reached = candidate_limit_reached
  if self.field
    and emitter_signature == self.emitter_signature
    and projection_signature == self.projection_signature
  then
    return false
  end

  local started = timer_now()
  self.emitters = emitters
  self.emitter_signature = emitter_signature
  self.projection_signature = projection_signature
  self.field = LightField.build(
    world,
    self.contract.settings,
    emitters
  )
  self:_upload()
  self.last_build_ms = (timer_now() - started) * 1000
  self.last_candidate_cells = self.field.candidate_cells
  self.last_lit_cells = self.field.lit_cells
  self.rebuild_count = self.rebuild_count + 1
  return true
end

local function restore_graphics_state(
  shader,
  blend_mode,
  alpha_mode,
  red,
  green,
  blue,
  alpha
)
  love.graphics.setShader(shader)
  love.graphics.setBlendMode(blend_mode, alpha_mode)
  love.graphics.setColor(red, green, blue, alpha)
end

function Lighting:draw_field()
  if not self.field then
    return
  end
  local previous_shader = love.graphics.getShader()
  local previous_blend, previous_alpha = love.graphics.getBlendMode()
  local red, green, blue, alpha = love.graphics.getColor()
  love.graphics.setShader(self.shader)
  love.graphics.setBlendMode("multiply", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    self.image,
    0,
    0,
    0,
    Constants.TILE_SIZE,
    Constants.TILE_SIZE
  )
  restore_graphics_state(
    previous_shader,
    previous_blend,
    previous_alpha,
    red,
    green,
    blue,
    alpha
  )
end

function Lighting:draw_bloom(min_x, min_y, max_x, max_y)
  local batch = self.bloom_batch
  batch:clear()
  local count = 0
  for index = 1, #self.emitters do
    local emitter = self.emitters[index]
    local profile = emitter.profile
    local center_x_tiles = emitter.x_256 / 256
    local center_y_tiles = emitter.y_256 / 256
    local bloom_radius_tiles = profile.bloom_radius_256 / 256
    if profile.bloom_ppm > 0
      and profile.bloom_radius_256 > 0
      and center_x_tiles + bloom_radius_tiles >= min_x - 1
      and center_x_tiles - bloom_radius_tiles <= max_x
      and center_y_tiles + bloom_radius_tiles >= min_y - 1
      and center_y_tiles - bloom_radius_tiles <= max_y
    then
      local center_x =
        center_x_tiles * Constants.TILE_SIZE
      local center_y =
        center_y_tiles * Constants.TILE_SIZE
      local scale = bloom_radius_tiles
      local alpha = math.min(
        1,
        profile.bloom_ppm
          * emitter.level_ppm
          / 1000000000000
      )
      batch:setColor(
        profile.color_srgb8[1] / 255,
        profile.color_srgb8[2] / 255,
        profile.color_srgb8[3] / 255,
        alpha
      )
      batch:add(
        center_x - 32 * scale,
        center_y - 32 * scale,
        0,
        scale,
        scale
      )
      count = count + 1
    end
  end
  self.bloom_count = count
  if count == 0 then
    return
  end
  batch:flush()
  local previous_shader = love.graphics.getShader()
  local previous_blend, previous_alpha = love.graphics.getBlendMode()
  local red, green, blue, alpha = love.graphics.getColor()
  love.graphics.setShader()
  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(batch)
  restore_graphics_state(
    previous_shader,
    previous_blend,
    previous_alpha,
    red,
    green,
    blue,
    alpha
  )
end

function Lighting:diagnostics()
  return {
    emitters = #self.emitters,
    dropped_emitters = self.dropped_emitters,
    shader = self.shader ~= nil,
    shader_error = self.shader_error,
    rebuilds = self.rebuild_count,
    uploads = self.upload_count,
    build_ms = self.last_build_ms,
    candidate_cells = self.last_candidate_cells,
    lit_cells = self.last_lit_cells,
    work_units = self.work_units,
    candidate_checks = self.candidate_checks,
    candidate_limit_reached = self.candidate_limit_reached,
    content_errors = self.contract.errors,
  }
end

return Lighting
