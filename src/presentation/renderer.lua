local Constants = require("src.core.constants")
local AtlasCatalog = require("src.assets.atlas_catalog")

local Renderer = {}
Renderer.__index = Renderer

local COLORS = {
  space = { 0.012, 0.018, 0.035, 1 },
  floor = { 0.12, 0.16, 0.20, 1 },
  plating = { 0.22, 0.27, 0.31, 1 },
  reinforced_floor = { 0.18, 0.23, 0.28, 1 },
  wall = { 0.42, 0.48, 0.52, 1 },
  reinforced_wall = { 0.31, 0.37, 0.42, 1 },
  wall_edge = { 0.68, 0.75, 0.78, 1 },
  door = { 0.72, 0.48, 0.18, 1 },
  cable = { 0.88, 0.30, 0.18, 1 },
  catwalk = { 0.45, 0.48, 0.50, 0.75 },
  chair = { 0.35, 0.24, 0.16, 1 },
  crate = { 0.48, 0.31, 0.15, 1 },
  decal = { 0.92, 0.72, 0.10, 0.75 },
  disposal = { 0.32, 0.38, 0.42, 1 },
  grille = { 0.58, 0.63, 0.67, 1 },
  lattice = { 0.40, 0.43, 0.46, 0.85 },
  light = { 1.00, 0.94, 0.58, 1 },
  pipe = { 0.42, 0.54, 0.62, 1 },
  sign = { 0.95, 0.78, 0.18, 1 },
  storage = { 0.30, 0.42, 0.48, 1 },
  table = { 0.46, 0.49, 0.51, 1 },
  window = { 0.35, 0.78, 0.92, 0.72 },
  powered = { 0.98, 0.85, 0.32, 0.16 },
  blueprint = { 0.20, 0.75, 1.00, 0.52 },
  low_pressure = { 0.30, 0.55, 1.00, 0.20 },
  fire = { 1.00, 0.25, 0.05, 0.68 },
  grid = { 0.28, 0.34, 0.39, 0.34 },
  machine = { 0.34, 0.48, 0.58, 1 },
  machine_powered = { 0.28, 0.95, 0.48, 1 },
  machine_unpowered = { 0.95, 0.25, 0.18, 1 },
}

-- The foundation media catalog intentionally opens only six machine sprites.
-- Keep every physical adapter visible by routing it to the closest available
-- alias until a dedicated catalog entry is promoted; unknown kinds still use
-- the deterministic shape fallback below.
local MACHINE_SPRITES = {
  apc = "apc",
  barcode_computer = "fabricator",
  battery = "generator",
  cargo_pad = "refinery",
  circulator = "generator",
  fabricator = "fabricator",
  generator = "generator",
  nanofab = "refinery",
  passive_vent = "vent",
  portable_scrubber = "scrubber",
  reclaimer = "refinery",
  refinery = "refinery",
  scrubber = "scrubber",
  supply_console = "fabricator",
  vent = "vent",
  vent_pump = "vent",
}

local DEFAULT_MEDIA_ALIASES = {
  catwalk = "catwalk",
  chair = "chair",
  crate = "crate",
  decal = "decal",
  disposal = "disposal",
  door_closed = "door_closed",
  door_open = "door_open",
  floor = "floor",
  grille = "grille",
  lattice = "lattice",
  light = "light",
  pipe = "pipe",
  plating = "plating",
  reinforced_floor = "reinforced_floor",
  reinforced_wall = "reinforced_wall",
  sign = "sign",
  storage = "storage",
  table = "table",
  wall = "wall",
  window = "window",
}

-- Groups are painter-ordered. Keep aliases together only when they are
-- mutually exclusive states at one tile; an overlapping component gets its
-- own group so atlas-page batching can never move it across another layer.
-- Within a group, aliases which occupy one atlas page share one SpriteBatch.
local STATIC_MEDIA_GROUPS = {
  { "plating", "floor", "reinforced_floor" },
  { "decal" },
  { "lattice" },
  { "catwalk" },
  { "pipe" },
  { "disposal" },
  { "wall", "reinforced_wall", "door_closed", "door_open" },
  { "grille" },
  { "window" },
  { "table" },
  { "chair" },
  { "storage", "crate" },
  { "light" },
  { "sign" },
}

local STRUCTURE_SPRITE_STATES = {
  {
    id = "org.simstation.core:structure/floor",
    states = { "floor", "plating", "reinforced_floor" },
  },
  {
    id = "org.simstation.core:structure/wall",
    states = { "reinforced_wall", "wall" },
  },
  {
    id = "org.simstation.core:structure/door",
    states = { "door_closed", "door_open" },
  },
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

local function resolve_media_aliases(content)
  local aliases = {}
  for key, alias in pairs(DEFAULT_MEDIA_ALIASES) do
    aliases[key] = alias
  end
  local definitions = content and content.by_id or {}
  for definition_index = 1, #STRUCTURE_SPRITE_STATES do
    local contract = STRUCTURE_SPRITE_STATES[definition_index]
    local definition = definitions[contract.id]
    local sprites = definition and definition.sprites or {}
    for state_index = 1, #contract.states do
      local state = contract.states[state_index]
      if type(sprites[state]) == "string" then
        aliases[state] = sprites[state]
      end
    end
  end
  return aliases
end

local function required_media_aliases(aliases)
  local result = {}
  local seen = {}
  for group_index = 1, #STATIC_MEDIA_GROUPS do
    local group = STATIC_MEDIA_GROUPS[group_index]
    for alias_index = 1, #group do
      local alias = aliases[group[alias_index]]
      if not seen[alias] then
        seen[alias] = true
        result[#result + 1] = alias
      end
    end
  end
  table.sort(result)
  return result
end

function Renderer.new(world, content)
  local atlas = AtlasCatalog.new()
  local media_aliases = resolve_media_aliases(content)
  return setmetatable({
    image = make_white_image(),
    atlas = atlas,
    media_aliases = media_aliases,
    media_enabled = atlas:has_all(required_media_aliases(media_aliases)),
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

local function add_fallback_rect(batch, color, x, y, width, height)
  set_batch_color(batch, color)
  batch:add(x, y, 0, width, height)
end

local function has_intact_feature(world, index, feature, component)
  return world:has_feature(index, feature)
    and world:feature_is_intact(index, component)
end

function Renderer:_rebuild_fallback_chunk(world, chunk_x, chunk_y, chunk_index)
  local max_sprites = Constants.CHUNK_SIZE * Constants.CHUNK_SIZE * 24
  local batch = love.graphics.newSpriteBatch(self.image, max_sprites, "static")
  local start_x = (chunk_x - 1) * Constants.CHUNK_SIZE + 1
  local start_y = (chunk_y - 1) * Constants.CHUNK_SIZE + 1
  local end_x = math.min(start_x + Constants.CHUNK_SIZE - 1, world.width)
  local end_y = math.min(start_y + Constants.CHUNK_SIZE - 1, world.height)
  local tile_size = Constants.TILE_SIZE

  for y = start_y, end_y do
    for x = start_x, end_x do
      local index = world:index(x, y)
      local draw_x = (x - 1) * tile_size
      local draw_y = (y - 1) * tile_size
      if world.tile[index] == Constants.TILE.FLOOR then
        local floor_color = COLORS.floor
        if world.turf_kind[index] == Constants.TURF.PLATING then
          floor_color = COLORS.plating
        elseif world.turf_kind[index] == Constants.TURF.REINFORCED_FLOOR then
          floor_color = COLORS.reinforced_floor
        end
        add_fallback_rect(
          batch,
          floor_color,
          draw_x,
          draw_y,
          tile_size,
          tile_size
        )
      end
      local has_sign = world:has_feature(index, Constants.FEATURE.SIGN)
      local has_crate = world:has_feature(index, Constants.FEATURE.CRATE)
      if world:has_feature(index, Constants.FEATURE.DECAL) and not has_sign then
        add_fallback_rect(
          batch,
          COLORS.decal,
          draw_x,
          draw_y + tile_size - 4,
          tile_size,
          4
        )
      end
      if world:has_feature(index, Constants.FEATURE.LATTICE) then
        add_fallback_rect(
          batch,
          COLORS.lattice,
          draw_x + 4,
          draw_y + 14,
          tile_size - 8,
          4
        )
        add_fallback_rect(
          batch,
          COLORS.lattice,
          draw_x + 14,
          draw_y + 4,
          4,
          tile_size - 8
        )
      end
      if world:has_feature(index, Constants.FEATURE.CATWALK) then
        add_fallback_rect(
          batch,
          COLORS.catwalk,
          draw_x + 5,
          draw_y + 5,
          tile_size - 10,
          tile_size - 10
        )
      end
      if world:has_feature(index, Constants.FEATURE.PIPE) then
        add_fallback_rect(
          batch,
          COLORS.pipe,
          draw_x,
          draw_y + 13,
          tile_size,
          6
        )
      end
      if world:has_feature(index, Constants.FEATURE.DISPOSAL) then
        add_fallback_rect(
          batch,
          COLORS.disposal,
          draw_x + 7,
          draw_y + 7,
          tile_size - 14,
          tile_size - 14
        )
      end
      local structure = world.structure[index]
      local has_window = has_intact_feature(
        world,
        index,
        Constants.FEATURE.WINDOW,
        "window"
      )
      if structure == Constants.STRUCTURE.WALL and not has_window then
        local wall_color = world.wall_kind[index] == Constants.WALL.REINFORCED
            and COLORS.reinforced_wall
          or COLORS.wall
        add_fallback_rect(
          batch,
          wall_color,
          draw_x,
          draw_y,
          tile_size,
          tile_size
        )
        add_fallback_rect(
          batch,
          COLORS.wall_edge,
          draw_x,
          draw_y,
          tile_size,
          4
        )
      elseif structure == Constants.STRUCTURE.DOOR_CLOSED then
        add_fallback_rect(
          batch,
          COLORS.door,
          draw_x + 4,
          draw_y + 4,
          tile_size - 8,
          tile_size - 8
        )
      elseif structure == Constants.STRUCTURE.DOOR_OPEN then
        add_fallback_rect(
          batch,
          { COLORS.door[1], COLORS.door[2], COLORS.door[3], 0.42 },
          draw_x,
          draw_y,
          tile_size,
          4
        )
      end
      if world.cable[index] then
        add_fallback_rect(
          batch,
          COLORS.cable,
          draw_x + tile_size / 2 - 1,
          draw_y + tile_size / 2 - 1,
          3,
          3
        )
      end
      if has_intact_feature(
        world,
        index,
        Constants.FEATURE.GRILLE,
        "grille"
      ) then
        add_fallback_rect(
          batch,
          COLORS.grille,
          draw_x + 9,
          draw_y + 2,
          3,
          tile_size - 4
        )
        add_fallback_rect(
          batch,
          COLORS.grille,
          draw_x + 20,
          draw_y + 2,
          3,
          tile_size - 4
        )
      end
      if has_window then
        add_fallback_rect(batch, COLORS.window, draw_x, draw_y, tile_size, 3)
        add_fallback_rect(
          batch,
          COLORS.window,
          draw_x,
          draw_y + tile_size - 3,
          tile_size,
          3
        )
        add_fallback_rect(batch, COLORS.window, draw_x, draw_y, 3, tile_size)
        add_fallback_rect(
          batch,
          COLORS.window,
          draw_x + tile_size - 3,
          draw_y,
          3,
          tile_size
        )
      end
      if world:has_feature(index, Constants.FEATURE.TABLE) then
        add_fallback_rect(
          batch,
          COLORS.table,
          draw_x + 3,
          draw_y + 7,
          tile_size - 6,
          tile_size - 14
        )
      end
      if world:has_feature(index, Constants.FEATURE.CHAIR) then
        add_fallback_rect(
          batch,
          COLORS.chair,
          draw_x + 9,
          draw_y + 9,
          tile_size - 18,
          tile_size - 18
        )
      end
      if world:has_feature(index, Constants.FEATURE.STORAGE)
        and not has_crate
      then
        add_fallback_rect(
          batch,
          COLORS.storage,
          draw_x + 5,
          draw_y + 2,
          tile_size - 10,
          tile_size - 4
        )
      end
      if has_crate then
        add_fallback_rect(
          batch,
          COLORS.crate,
          draw_x + 5,
          draw_y + 5,
          tile_size - 10,
          tile_size - 10
        )
      end
      if world:has_feature(index, Constants.FEATURE.LIGHT) then
        add_fallback_rect(
          batch,
          COLORS.light,
          draw_x + 5,
          draw_y + 2,
          tile_size - 10,
          4
        )
      end
      if has_sign then
        add_fallback_rect(
          batch,
          COLORS.sign,
          draw_x + 9,
          draw_y + 3,
          tile_size - 18,
          9
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
  media.owner.batch:add(
    media.quad,
    x,
    y,
    0,
    tile_size / media.width,
    tile_size / media.height
  )
  media.owner.count = media.owner.count + 1
end

local function create_media_groups(renderer, tile_capacity)
  local groups = {}
  local media = {}
  for group_index = 1, #STATIC_MEDIA_GROUPS do
    local keys = STATIC_MEDIA_GROUPS[group_index]
    local group = {
      batches = {},
      by_image = {},
    }
    groups[group_index] = group
    for key_index = 1, #keys do
      local key = keys[key_index]
      local alias = renderer.media_aliases[key]
      local sprite, sprite_error = renderer.atlas:sprite(alias, "south", 1)
      if not sprite then
        return nil, nil, sprite_error
      end
      local owner = group.by_image[sprite.image]
      if not owner then
        local ok, batch = pcall(
          love.graphics.newSpriteBatch,
          sprite.image,
          tile_capacity * #keys,
          "static"
        )
        if not ok then
          return nil, nil, batch
        end
        batch:setColor(1, 1, 1, 1)
        owner = {
          batch = batch,
          count = 0,
        }
        group.by_image[sprite.image] = owner
        group.batches[#group.batches + 1] = owner
      end
      media[key] = {
        owner = owner,
        quad = sprite.quad,
        width = sprite.width,
        height = sprite.height,
      }
    end
  end
  return groups, media
end

local function append_populated_batches(result, group)
  for batch_index = 1, #group.batches do
    local owner = group.batches[batch_index]
    owner.batch:flush()
    if owner.count > 0 then
      result[#result + 1] = owner.batch
    end
  end
end

function Renderer:_rebuild_media_chunk(
  world,
  chunk_x,
  chunk_y,
  chunk_index
)
  local tile_capacity = Constants.CHUNK_SIZE * Constants.CHUNK_SIZE
  local groups, media, media_error = create_media_groups(
    self,
    tile_capacity
  )
  if not groups then
    return nil, media_error
  end
  local cable_batch = love.graphics.newSpriteBatch(
    self.image,
    tile_capacity,
    "static"
  )
  local cable_count = 0

  local start_x = (chunk_x - 1) * Constants.CHUNK_SIZE + 1
  local start_y = (chunk_y - 1) * Constants.CHUNK_SIZE + 1
  local end_x = math.min(start_x + Constants.CHUNK_SIZE - 1, world.width)
  local end_y = math.min(start_y + Constants.CHUNK_SIZE - 1, world.height)
  local tile_size = Constants.TILE_SIZE

  for y = start_y, end_y do
    for x = start_x, end_x do
      local index = world:index(x, y)
      local draw_x = (x - 1) * tile_size
      local draw_y = (y - 1) * tile_size
      if world.tile[index] == Constants.TILE.FLOOR then
        local floor_key = "floor"
        if world.turf_kind[index] == Constants.TURF.PLATING then
          floor_key = "plating"
        elseif world.turf_kind[index] == Constants.TURF.REINFORCED_FLOOR then
          floor_key = "reinforced_floor"
        end
        add_media_sprite(media[floor_key], draw_x, draw_y, tile_size)
      end

      local has_sign = world:has_feature(index, Constants.FEATURE.SIGN)
      local has_crate = world:has_feature(index, Constants.FEATURE.CRATE)
      if world:has_feature(index, Constants.FEATURE.DECAL) and not has_sign then
        add_media_sprite(media.decal, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.LATTICE) then
        add_media_sprite(media.lattice, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.CATWALK) then
        add_media_sprite(media.catwalk, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.PIPE) then
        add_media_sprite(media.pipe, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.DISPOSAL) then
        add_media_sprite(media.disposal, draw_x, draw_y, tile_size)
      end

      local structure = world.structure[index]
      local has_window = has_intact_feature(
        world,
        index,
        Constants.FEATURE.WINDOW,
        "window"
      )
      if structure == Constants.STRUCTURE.WALL and not has_window then
        local wall_key = world.wall_kind[index] == Constants.WALL.REINFORCED
            and "reinforced_wall"
          or "wall"
        add_media_sprite(media[wall_key], draw_x, draw_y, tile_size)
      elseif structure == Constants.STRUCTURE.DOOR_CLOSED then
        add_media_sprite(media.door_closed, draw_x, draw_y, tile_size)
      elseif structure == Constants.STRUCTURE.DOOR_OPEN then
        add_media_sprite(media.door_open, draw_x, draw_y, tile_size)
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
        cable_count = cable_count + 1
      end
      if has_intact_feature(
        world,
        index,
        Constants.FEATURE.GRILLE,
        "grille"
      ) then
        add_media_sprite(media.grille, draw_x, draw_y, tile_size)
      end
      if has_window then
        add_media_sprite(media.window, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.TABLE) then
        add_media_sprite(media.table, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.CHAIR) then
        add_media_sprite(media.chair, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.STORAGE)
        and not has_crate
      then
        add_media_sprite(media.storage, draw_x, draw_y, tile_size)
      end
      if has_crate then
        add_media_sprite(media.crate, draw_x, draw_y, tile_size)
      end
      if world:has_feature(index, Constants.FEATURE.LIGHT) then
        add_media_sprite(media.light, draw_x, draw_y, tile_size)
      end
      if has_sign then
        add_media_sprite(media.sign, draw_x, draw_y, tile_size)
      end
    end
  end

  cable_batch:flush()
  local media_batches = {}
  append_populated_batches(media_batches, groups[1])
  if cable_count > 0 then
    media_batches[#media_batches + 1] = cable_batch
  end
  for group_index = 2, #groups do
    append_populated_batches(media_batches, groups[group_index])
  end
  self.chunks[chunk_index] = {
    revision = world.chunk_revision[chunk_index],
    media = true,
    media_batches = media_batches,
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
  love.graphics.setScissor()
  love.graphics.clear(
    COLORS.space[1],
    COLORS.space[2],
    COLORS.space[3],
    COLORS.space[4]
  )
  local min_x, min_y, max_x, max_y = camera:visible_tile_bounds(world, 1)
  local viewport_x, viewport_y, viewport_width, viewport_height =
    camera:viewport_rect()
  love.graphics.setScissor(
    viewport_x,
    viewport_y,
    viewport_width,
    viewport_height
  )
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
  love.graphics.setScissor()
  love.graphics.setColor(1, 1, 1, 1)
  self.last_draw_calls = love.graphics.getStats().drawcalls
end

return Renderer
