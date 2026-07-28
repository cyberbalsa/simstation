local Constants = require("src.core.constants")
local Stable = require("src.core.stable")

local Camera = {}
Camera.__index = Camera

Camera.ZOOM_LEVELS = { 0.25, 0.5, 1, 2, 4 }

local function nearest_zoom(value)
  local best = Camera.ZOOM_LEVELS[1]
  local best_distance = math.abs(value - best)
  for index = 2, #Camera.ZOOM_LEVELS do
    local candidate = Camera.ZOOM_LEVELS[index]
    local distance = math.abs(value - candidate)
    if distance < best_distance then
      best = candidate
      best_distance = distance
    end
  end
  return best
end

function Camera.new(
  world,
  viewport_width,
  viewport_height,
  viewport_x,
  viewport_y
)
  local center_x = world.width * Constants.TILE_SIZE / 2
  local center_y = world.height * Constants.TILE_SIZE / 2
  return setmetatable({
    x = center_x,
    y = center_y,
    zoom = 1,
    viewport_x = viewport_x or 0,
    viewport_y = viewport_y or 0,
    viewport_width = viewport_width,
    viewport_height = viewport_height,
    dragging = false,
  }, Camera)
end

function Camera:resize(width, height, x, y)
  self.viewport_x = x or self.viewport_x
  self.viewport_y = y or self.viewport_y
  self.viewport_width = width
  self.viewport_height = height
end

function Camera:viewport_rect()
  return
    self.viewport_x,
    self.viewport_y,
    self.viewport_width,
    self.viewport_height
end

function Camera:contains_screen_point(screen_x, screen_y)
  return screen_x >= self.viewport_x
    and screen_y >= self.viewport_y
    and screen_x < self.viewport_x + self.viewport_width
    and screen_y < self.viewport_y + self.viewport_height
end

function Camera:pan(dx, dy)
  self.x = self.x + dx / self.zoom
  self.y = self.y + dy / self.zoom
end

function Camera:clamp(world)
  local half_width = self.viewport_width / (2 * self.zoom)
  local half_height = self.viewport_height / (2 * self.zoom)
  local world_width = world.width * Constants.TILE_SIZE
  local world_height = world.height * Constants.TILE_SIZE
  if half_width * 2 >= world_width then
    self.x = world_width / 2
  else
    self.x = Stable.clamp(self.x, half_width, world_width - half_width)
  end
  if half_height * 2 >= world_height then
    self.y = world_height / 2
  else
    self.y = Stable.clamp(self.y, half_height, world_height - half_height)
  end
end

function Camera:render_position()
  -- Snap the camera translation in DPI-scaled screen-unit space. This keeps
  -- source texel boundaries stable at every supported zoom and gives exact
  -- backing-pixel replication whenever the platform DPI scale is integral.
  return
    math.floor(self.x * self.zoom + 0.5) / self.zoom,
    math.floor(self.y * self.zoom + 0.5) / self.zoom
end

function Camera:set_zoom(next_zoom, screen_x, screen_y, world)
  local before_x, before_y = self:screen_to_world(screen_x, screen_y)
  self.zoom = nearest_zoom(Stable.clamp(next_zoom, 0.25, 4))
  local after_x, after_y = self:screen_to_world(screen_x, screen_y)
  self.x = self.x + before_x - after_x
  self.y = self.y + before_y - after_y
  self:clamp(world)
end

function Camera:screen_to_world(screen_x, screen_y)
  local center_x =
    self.viewport_x + math.floor(self.viewport_width / 2)
  local center_y =
    self.viewport_y + math.floor(self.viewport_height / 2)
  local camera_x, camera_y = self:render_position()
  local world_x = (screen_x - center_x) / self.zoom + camera_x
  local world_y = (screen_y - center_y) / self.zoom + camera_y
  return world_x, world_y
end

function Camera:screen_to_tile(screen_x, screen_y, world)
  if not self:contains_screen_point(screen_x, screen_y) then
    return nil
  end
  local world_x, world_y = self:screen_to_world(screen_x, screen_y)
  local tile_x = math.floor(world_x / Constants.TILE_SIZE) + 1
  local tile_y = math.floor(world_y / Constants.TILE_SIZE) + 1
  if not world:index(tile_x, tile_y) then
    return nil
  end
  return tile_x, tile_y
end

function Camera:visible_tile_bounds(world, margin)
  margin = margin or 1
  local left, top = self:screen_to_world(
    self.viewport_x,
    self.viewport_y
  )
  local right, bottom = self:screen_to_world(
    self.viewport_x + self.viewport_width,
    self.viewport_y + self.viewport_height
  )
  return
    Stable.clamp(math.floor(left / Constants.TILE_SIZE) + 1 - margin, 1, world.width),
    Stable.clamp(math.floor(top / Constants.TILE_SIZE) + 1 - margin, 1, world.height),
    Stable.clamp(math.floor(right / Constants.TILE_SIZE) + 1 + margin, 1, world.width),
    Stable.clamp(math.floor(bottom / Constants.TILE_SIZE) + 1 + margin, 1, world.height)
end

function Camera:apply()
  local center_x =
    self.viewport_x + math.floor(self.viewport_width / 2)
  local center_y =
    self.viewport_y + math.floor(self.viewport_height / 2)
  local camera_x, camera_y = self:render_position()
  love.graphics.push()
  love.graphics.translate(center_x, center_y)
  love.graphics.scale(self.zoom, self.zoom)
  love.graphics.translate(-camera_x, -camera_y)
end

function Camera:finish()
  love.graphics.pop()
end

return Camera
