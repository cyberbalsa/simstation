local Constants = require("src.core.constants")
local Stable = require("src.core.stable")

local Camera = {}
Camera.__index = Camera

function Camera.new(world, viewport_width, viewport_height)
  local center_x = world.width * Constants.TILE_SIZE / 2
  local center_y = world.height * Constants.TILE_SIZE / 2
  return setmetatable({
    x = center_x,
    y = center_y,
    zoom = 1,
    viewport_width = viewport_width,
    viewport_height = viewport_height,
    dragging = false,
  }, Camera)
end

function Camera:resize(width, height)
  self.viewport_width = width
  self.viewport_height = height
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

function Camera:set_zoom(next_zoom, screen_x, screen_y, world)
  local before_x, before_y = self:screen_to_world(screen_x, screen_y)
  self.zoom = Stable.clamp(next_zoom, 0.25, 4)
  local after_x, after_y = self:screen_to_world(screen_x, screen_y)
  self.x = self.x + before_x - after_x
  self.y = self.y + before_y - after_y
  self:clamp(world)
end

function Camera:screen_to_world(screen_x, screen_y)
  local world_x = (screen_x - self.viewport_width / 2) / self.zoom + self.x
  local world_y = (screen_y - self.viewport_height / 2) / self.zoom + self.y
  return world_x, world_y
end

function Camera:screen_to_tile(screen_x, screen_y, world)
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
  local left, top = self:screen_to_world(0, 0)
  local right, bottom = self:screen_to_world(
    self.viewport_width,
    self.viewport_height
  )
  return
    Stable.clamp(math.floor(left / Constants.TILE_SIZE) + 1 - margin, 1, world.width),
    Stable.clamp(math.floor(top / Constants.TILE_SIZE) + 1 - margin, 1, world.height),
    Stable.clamp(math.floor(right / Constants.TILE_SIZE) + 1 + margin, 1, world.width),
    Stable.clamp(math.floor(bottom / Constants.TILE_SIZE) + 1 + margin, 1, world.height)
end

function Camera:apply()
  love.graphics.push()
  love.graphics.translate(self.viewport_width / 2, self.viewport_height / 2)
  love.graphics.scale(self.zoom, self.zoom)
  love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:finish()
  love.graphics.pop()
end

return Camera
