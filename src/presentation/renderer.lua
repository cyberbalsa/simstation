local Constants = require("src.core.constants")
local AtlasCatalog = require("src.assets.atlas_catalog")

local Renderer = {}
Renderer.__index = Renderer

local COLORS = {
  space = { 0.012, 0.018, 0.035, 1 },
  floor = { 0.12, 0.16, 0.20, 1 },
  wall = { 0.42, 0.48, 0.52, 1 },
  wall_edge = { 0.68, 0.75, 0.78, 1 },
  door = { 0.72, 0.48, 0.18, 1 },
  cable = { 0.88, 0.30, 0.18, 1 },
  powered = { 0.98, 0.85, 0.32, 0.16 },
  blueprint = { 0.20, 0.75, 1.00, 0.52 },
  low_pressure = { 0.30, 0.55, 1.00, 0.20 },
  fire = { 1.00, 0.25, 0.05, 0.68 },
  grid = { 0.28, 0.34, 0.39, 0.34 },
  machine = { 0.34, 0.48, 0.58, 1 },
  machine_powered = { 0.28, 0.95, 0.48, 1 },
  machine_unpowered = { 0.95, 0.25, 0.18, 1 },
}

local MACHINE_SPRITES = {
  apc = "apc",
  fabricator = "fabricator",
  generator = "generator",
  refinery = "refinery",
  scrubber = "scrubber",
  vent = "vent",
}

local function set_color(color)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

local function set_batch_color(batch, color)
  batch:setColor(color[1], color[2], color[3], color[4] or 1)
end

local function make_white_image()
  local data = love.image.newImageData(1, 1, "rgba8")
  data:setPixel(0, 0, 1, 1, 1, 1)
  local image = love.graphics.newImage(data, {
    mipmaps = false,
    linear = false,
    dpiscale = 1,
  })
  image:setFilter("nearest", "nearest", 1)
  image:setWrap("clamp", "clamp")
  return image
end

function Renderer.new(world)
  local atlas = AtlasCatalog.new()
  return setmetatable({
    image = make_white_image(),
    atlas = atlas,
    media_enabled = atlas:has_all({
      "floor",
      "wall",
      "door_closed",
      "door_open",
    }),
    crew_media_enabled = atlas:has_all({ "crew_male", "crew_female" }),
    machine_media_enabled = atlas:has_all({
      "apc",
      "fabricator",
      "generator",
      "refinery",
      "scrubber",
      "vent",
    }),
    chunks = {},
    selected_x = false,
    selected_y = false,
    hovered_x = false,
    hovered_y = false,
    visible_chunks = 0,
    rebuilt_chunks = 0,
    last_draw_calls = 0,
    world_width = world.width,
    world_height = world.height,
  }, Renderer)
end

function Renderer:set_selection(x, y)
  self.selected_x = x
  self.selected_y = y
end

function Renderer:set_hover(x, y)
  self.hovered_x = x
  self.hovered_y = y
end

function Renderer:_rebuild_fallback_chunk(world, chunk_x, chunk_y, chunk_index)
  local max_sprites = Constants.CHUNK_SIZE * Constants.CHUNK_SIZE * 3
  local batch = love.graphics.newSpriteBatch(self.image, max_sprites, "static")
  local start_x = (chunk_x - 1) * Constants.CHUNK_SIZE + 1
  local start_y = (chunk_y - 1) * Constants.CHUNK_SIZE + 1
  local end_x = math.min(start_x + Constants.CHUNK_SIZE - 1, world.width)
  local end_y = math.min(start_y + Constants.CHUNK_SIZE - 1, world.height)
  local tile_size = Constants.TILE_SIZE

  for y = start_y, end_y do
    for x = start_x, end_x do
      local index = world:index(x, y)
      if world.tile[index] == Constants.TILE.FLOOR then
        set_batch_color(batch, COLORS.floor)
        batch:add((x - 1) * tile_size, (y - 1) * tile_size, 0, tile_size, tile_size)
      end
      local structure = world.structure[index]
      if structure == Constants.STRUCTURE.WALL then
        set_batch_color(batch, COLORS.wall)
        batch:add((x - 1) * tile_size, (y - 1) * tile_size, 0, tile_size, tile_size)
        set_batch_color(batch, COLORS.wall_edge)
        batch:add((x - 1) * tile_size, (y - 1) * tile_size, 0, tile_size, 4)
      elseif structure == Constants.STRUCTURE.DOOR_CLOSED then
        set_batch_color(batch, COLORS.door)
        batch:add(
          (x - 1) * tile_size + 4,
          (y - 1) * tile_size + 4,
          0,
          tile_size - 8,
          tile_size - 8
        )
      elseif structure == Constants.STRUCTURE.DOOR_OPEN then
        batch:setColor(COLORS.door[1], COLORS.door[2], COLORS.door[3], 0.42)
        batch:add((x - 1) * tile_size, (y - 1) * tile_size, 0, tile_size, 4)
      end
      if world.cable[index] then
        set_batch_color(batch, COLORS.cable)
        batch:add(
          (x - 1) * tile_size + tile_size / 2 - 1,
          (y - 1) * tile_size + tile_size / 2 - 1,
          0,
          3,
          3
        )
      end
    end
  end
  batch:flush()
  self.chunks[chunk_index] = {
    revision = world.chunk_revision[chunk_index],
    batch = batch,
    media = false,
  }
  self.rebuilt_chunks = self.rebuilt_chunks + 1
end

local function add_media_sprite(media, x, y, tile_size)
  media.batch:add(
    media.quad,
    x,
    y,
    0,
    tile_size / media.width,
    tile_size / media.height
  )
end

function Renderer:_rebuild_media_chunk(
  world,
  chunk_x,
  chunk_y,
  chunk_index
)
  local tile_capacity = Constants.CHUNK_SIZE * Constants.CHUNK_SIZE
  local floor, floor_error = self.atlas:new_batch(
    "floor",
    tile_capacity,
    "static"
  )
  local wall, wall_error = self.atlas:new_batch(
    "wall",
    tile_capacity,
    "static"
  )
  local door_closed, closed_error = self.atlas:sprite(
    "door_closed",
    "south",
    1
  )
  local door_open, open_error = self.atlas:sprite("door_open", "south", 1)
  if not floor or not wall or not door_closed or not door_open then
    return nil, floor_error or wall_error or closed_error or open_error
  end
  if door_closed.image ~= door_open.image then
    return nil, "foundation door sprites are not on the same atlas page"
  end
  local ok, door_batch = pcall(
    love.graphics.newSpriteBatch,
    door_closed.image,
    tile_capacity,
    "static"
  )
  if not ok then
    return nil, door_batch
  end
  local cable_batch = love.graphics.newSpriteBatch(
    self.image,
    tile_capacity,
    "static"
  )

  local start_x = (chunk_x - 1) * Constants.CHUNK_SIZE + 1
  local start_y = (chunk_y - 1) * Constants.CHUNK_SIZE + 1
  local end_x = math.min(start_x + Constants.CHUNK_SIZE - 1, world.width)
  local end_y = math.min(start_y + Constants.CHUNK_SIZE - 1, world.height)
  local tile_size = Constants.TILE_SIZE

  floor.batch:setColor(1, 1, 1, 1)
  wall.batch:setColor(1, 1, 1, 1)
  door_batch:setColor(1, 1, 1, 1)
  for y = start_y, end_y do
    for x = start_x, end_x do
      local index = world:index(x, y)
      local draw_x = (x - 1) * tile_size
      local draw_y = (y - 1) * tile_size
      if world.tile[index] == Constants.TILE.FLOOR then
        add_media_sprite(floor, draw_x, draw_y, tile_size)
      end
      local structure = world.structure[index]
      if structure == Constants.STRUCTURE.WALL then
        add_media_sprite(wall, draw_x, draw_y, tile_size)
      elseif structure == Constants.STRUCTURE.DOOR_CLOSED then
        door_batch:add(
          door_closed.quad,
          draw_x,
          draw_y,
          0,
          tile_size / door_closed.width,
          tile_size / door_closed.height
        )
      elseif structure == Constants.STRUCTURE.DOOR_OPEN then
        door_batch:add(
          door_open.quad,
          draw_x,
          draw_y,
          0,
          tile_size / door_open.width,
          tile_size / door_open.height
        )
      end
      if world.cable[index] then
        set_batch_color(cable_batch, COLORS.cable)
        cable_batch:add(
          draw_x + tile_size / 2 - 1,
          draw_y + tile_size / 2 - 1,
          0,
          3,
          3
        )
      end
    end
  end
  floor.batch:flush()
  wall.batch:flush()
  door_batch:flush()
  cable_batch:flush()
  self.chunks[chunk_index] = {
    revision = world.chunk_revision[chunk_index],
    media = true,
    media_batches = {
      floor.batch,
      wall.batch,
      door_batch,
    },
    cable_batch = cable_batch,
  }
  self.rebuilt_chunks = self.rebuilt_chunks + 1
  return true
end

function Renderer:_rebuild_chunk(world, chunk_x, chunk_y, chunk_index)
  if self.media_enabled then
    local ok = self:_rebuild_media_chunk(
      world,
      chunk_x,
      chunk_y,
      chunk_index
    )
    if ok then
      return
    end
    -- A missing or unsupported imported page must never make the game
    -- unplayable. Disable media for subsequent chunks and use primitives.
    self.media_enabled = false
  end
  self:_rebuild_fallback_chunk(world, chunk_x, chunk_y, chunk_index)
end

function Renderer:_draw_static(world, min_x, min_y, max_x, max_y)
  local chunk_size = Constants.CHUNK_SIZE
  local first_chunk_x = math.floor((min_x - 1) / chunk_size) + 1
  local first_chunk_y = math.floor((min_y - 1) / chunk_size) + 1
  local last_chunk_x = math.floor((max_x - 1) / chunk_size) + 1
  local last_chunk_y = math.floor((max_y - 1) / chunk_size) + 1
  self.visible_chunks = 0
  self.rebuilt_chunks = 0

  love.graphics.setColor(1, 1, 1, 1)
  for chunk_y = first_chunk_y, last_chunk_y do
    for chunk_x = first_chunk_x, last_chunk_x do
      local chunk_index = (chunk_y - 1) * world.chunks_x + chunk_x
      local cached = self.chunks[chunk_index]
      if not cached or cached.revision ~= world.chunk_revision[chunk_index] then
        self:_rebuild_chunk(world, chunk_x, chunk_y, chunk_index)
        cached = self.chunks[chunk_index]
      end
      if cached.media then
        for i = 1, #cached.media_batches do
          love.graphics.draw(cached.media_batches[i])
        end
        love.graphics.draw(cached.cable_batch)
      else
        love.graphics.draw(cached.batch)
      end
      self.visible_chunks = self.visible_chunks + 1
    end
  end
end

function Renderer:_draw_overlays(world, min_x, min_y, max_x, max_y, zoom)
  local tile_size = Constants.TILE_SIZE
  for y = min_y, max_y do
    for x = min_x, max_x do
      local index = world:index(x, y)
      local draw_x = (x - 1) * tile_size
      local draw_y = (y - 1) * tile_size
      if world.powered[index] and world.tile[index] == Constants.TILE.FLOOR then
        set_color(COLORS.powered)
        love.graphics.rectangle("fill", draw_x, draw_y, tile_size, tile_size)
      end
      if world:is_gas_cell(index) and world:pressure_dkpa(index) < 500 then
        set_color(COLORS.low_pressure)
        love.graphics.rectangle("fill", draw_x, draw_y, tile_size, tile_size)
      end
      if world.fire[index] > 0 then
        set_color(COLORS.fire)
        local inset = math.max(2, 8 - world.fire[index])
        love.graphics.rectangle(
          "fill",
          draw_x + inset,
          draw_y + inset,
          tile_size - inset * 2,
          tile_size - inset * 2
        )
      end
      if world.blueprint[index] then
        set_color(COLORS.blueprint)
        love.graphics.rectangle(
          "line",
          draw_x + 2,
          draw_y + 2,
          tile_size - 4,
          tile_size - 4
        )
        love.graphics.line(draw_x + 4, draw_y + 4, draw_x + tile_size - 4, draw_y + tile_size - 4)
        love.graphics.line(draw_x + tile_size - 4, draw_y + 4, draw_x + 4, draw_y + tile_size - 4)
      end
      if zoom >= 0.75 and world.tile[index] == Constants.TILE.FLOOR then
        set_color(COLORS.grid)
        love.graphics.rectangle("line", draw_x, draw_y, tile_size, tile_size)
      end
    end
  end
end

function Renderer:_draw_machines(world, machines, min_x, min_y, max_x, max_y)
  local tile_size = Constants.TILE_SIZE
  local ordered = {}
  for index = 1, #machines do
    ordered[index] = machines[index]
  end
  table.sort(ordered, function(a, b)
    if a.index ~= b.index then
      return a.index < b.index
    end
    return a.id < b.id
  end)
  for index = 1, #ordered do
    local machine = ordered[index]
    local x, y = world:coordinates(machine.index)
    if x >= min_x and x <= max_x and y >= min_y and y <= max_y then
      local draw_x = (x - 1) * tile_size
      local draw_y = (y - 1) * tile_size
      local alias = MACHINE_SPRITES[machine.kind]
      local sprite = self.machine_media_enabled
        and alias
        and self.atlas:sprite(alias, "south", 1)
      if sprite then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
          sprite.image,
          sprite.quad,
          draw_x,
          draw_y,
          0,
          tile_size / sprite.width,
          tile_size / sprite.height
        )
      else
        set_color(COLORS.machine)
        love.graphics.rectangle(
          "fill",
          draw_x + 7,
          draw_y + 7,
          tile_size - 14,
          tile_size - 14,
          2,
          2
        )
      end
      set_color(
        machine.powered
            and COLORS.machine_powered
          or COLORS.machine_unpowered
      )
      love.graphics.rectangle("fill", draw_x + 24, draw_y + 3, 5, 5)
    end
  end
end

function Renderer:_draw_crew(world, crew)
  local tile_size = Constants.TILE_SIZE
  local ordered = {}
  for i = 1, #crew do
    ordered[i] = crew[i]
  end
  table.sort(ordered, function(a, b)
    if a.index ~= b.index then
      return a.index < b.index
    end
    return a.id < b.id
  end)

  local male
  local female
  if self.crew_media_enabled then
    male = self.atlas:sprite("crew_male", "south", 1)
    female = self.atlas:sprite("crew_female", "south", 1)
    if not male or not female then
      self.crew_media_enabled = false
    end
  end
  for i = 1, #ordered do
    local person = ordered[i]
    local x, y = world:coordinates(person.index)
    local color = Constants.JOB_COLORS[person.job] or Constants.JOB_COLORS.assistant
    if self.crew_media_enabled then
      local sprite = person.id % 2 == 0 and female or male
      if person.alive then
        love.graphics.setColor(1, 1, 1, 1)
      else
        love.graphics.setColor(0.55, 0.20, 0.20, 0.82)
      end
      love.graphics.draw(
        sprite.image,
        sprite.quad,
        (x - 1) * tile_size,
        (y - 1) * tile_size,
        0,
        tile_size / sprite.width,
        tile_size / sprite.height
      )
      love.graphics.setColor(color[1], color[2], color[3], 1)
      love.graphics.rectangle(
        "fill",
        (x - 1) * tile_size + 24,
        (y - 1) * tile_size + 25,
        5,
        5
      )
    else
      if not person.alive then
        love.graphics.setColor(0.25, 0.08, 0.08, 1)
      else
        love.graphics.setColor(color[1], color[2], color[3], 1)
      end
      love.graphics.circle(
        "fill",
        (x - 0.5) * tile_size,
        (y - 0.5) * tile_size,
        7
      )
      love.graphics.setColor(0.03, 0.04, 0.05, 1)
      love.graphics.circle(
        "line",
        (x - 0.5) * tile_size,
        (y - 0.5) * tile_size,
        7
      )
    end
  end
end

function Renderer:_draw_cursor()
  local tile_size = Constants.TILE_SIZE
  if self.hovered_x then
    love.graphics.setColor(0.9, 0.95, 1, 0.8)
    love.graphics.rectangle(
      "line",
      (self.hovered_x - 1) * tile_size + 1,
      (self.hovered_y - 1) * tile_size + 1,
      tile_size - 2,
      tile_size - 2
    )
  end
  if self.selected_x then
    love.graphics.setColor(0.98, 0.82, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle(
      "line",
      (self.selected_x - 1) * tile_size + 2,
      (self.selected_y - 1) * tile_size + 2,
      tile_size - 4,
      tile_size - 4
    )
    love.graphics.setLineWidth(1)
  end
end

function Renderer:draw(snapshot, camera)
  local world = snapshot.world
  love.graphics.clear(
    COLORS.space[1],
    COLORS.space[2],
    COLORS.space[3],
    COLORS.space[4]
  )
  local min_x, min_y, max_x, max_y = camera:visible_tile_bounds(world, 1)
  camera:apply()
  self:_draw_static(world, min_x, min_y, max_x, max_y)
  self:_draw_overlays(world, min_x, min_y, max_x, max_y, camera.zoom)
  self:_draw_machines(
    world,
    snapshot.machines or {},
    min_x,
    min_y,
    max_x,
    max_y
  )
  self:_draw_crew(world, snapshot.crew)
  self:_draw_cursor()
  camera:finish()
  love.graphics.setColor(1, 1, 1, 1)
  self.last_draw_calls = love.graphics.getStats().drawcalls
end

return Renderer
