local Constants = require("src.core.constants")
local DmAppearanceCatalog =
  require("src.assets.dm_appearance_catalog")

local MapAppearance = {}
MapAppearance.__index = MapAppearance

local function catalog_matches_scenario(catalog, scenario)
  local source_map = catalog
    and catalog.catalog
    and catalog.catalog.source_map
  local provenance = scenario and scenario.provenance
  local sources = provenance and provenance.sources
  if type(source_map) ~= "table" or type(sources) ~= "table" then
    return false
  end
  for source_index = 1, #sources do
    local source = sources[source_index]
    if type(source) == "table"
      and source.commit == catalog.catalog.source_commit
      and source.path == source_map.path
      and source.git_blob == source_map.git_blob
      and source.sha256 == source_map.sha256
    then
      local crop = source_map.crop
      return type(crop) == "table"
        and scenario.map.width == crop.max_x - crop.min_x + 1
        and scenario.map.height == crop.max_y - crop.min_y + 1
    end
  end
  return false
end

local function path_is(path, root)
  return path == root
    or (
      path:sub(1, #root) == root
      and path:sub(#root + 1, #root + 1) == "/"
    )
end

local function path_ends_with(path, suffix)
  return path:sub(-#suffix) == suffix
end

local function has_intact_feature(world, index, feature, component)
  return world:has_feature(index, feature)
    and world:feature_is_intact(index, component)
end

local function appearance_is_door(path)
  return path_is(path, "/obj/machinery/door")
    or path_is(path, "/obj/door")
end

local function path_has_segment(path, wanted)
  for segment in path:gmatch("[^/]+") do
    if segment == wanted then
      return true
    end
  end
  return false
end

local function appearance_turf_kind(path)
  if path_is(path, "/turf/space") then
    return Constants.TURF.SPACE
  elseif path_is(path, "/turf/simulated/floor/engine") then
    return Constants.TURF.REINFORCED_FLOOR
  elseif path_has_segment(path, "plating") then
    return Constants.TURF.PLATING
  end
  return Constants.TURF.FLOOR
end

local function boundary_at(world, index)
  if not index then
    return false
  end
  local structure = world.structure[index]
  return structure == Constants.STRUCTURE.WALL
    or structure == Constants.STRUCTURE.DOOR_CLOSED
    or structure == Constants.STRUCTURE.DOOR_OPEN
    or has_intact_feature(
      world,
      index,
      Constants.FEATURE.WINDOW,
      "window"
    )
end

local function appearance_is_visible(world, record)
  local appearance = record.appearance
  local path = appearance.source_path
  local index = appearance.index
  if appearance.role == "turf" then
    if path_is(path, "/turf/space") then
      return world.tile[index] == Constants.TILE.SPACE
    elseif path:find("/wall", 1, true) then
      local reinforced = path_has_segment(path, "reinforced")
      local current_reinforced =
        world.wall_kind[index] == Constants.WALL.REINFORCED
      return world.structure[index] == Constants.STRUCTURE.WALL
        and reinforced == current_reinforced
    end
    return world.tile[index] == Constants.TILE.FLOOR
      and world.structure[index] ~= Constants.STRUCTURE.WALL
      and appearance_turf_kind(path) == world.turf_kind[index]
  end

  if appearance_is_door(path) then
    local structure = world.structure[index]
    return structure == Constants.STRUCTURE.DOOR_CLOSED
      or structure == Constants.STRUCTURE.DOOR_OPEN
  elseif path_is(path, "/obj/mapping_helper/wingrille_spawn") then
    return has_intact_feature(
      world,
      index,
      Constants.FEATURE.WINDOW,
      "window"
    ) or has_intact_feature(
      world,
      index,
      Constants.FEATURE.GRILLE,
      "grille"
    )
  elseif path_is(path, "/obj/window") then
    return has_intact_feature(
      world,
      index,
      Constants.FEATURE.WINDOW,
      "window"
    )
  elseif path_is(path, "/obj/mesh/grille") then
    return has_intact_feature(
      world,
      index,
      Constants.FEATURE.GRILLE,
      "grille"
    )
  elseif path_is(path, "/obj/table") then
    return world:has_feature(index, Constants.FEATURE.TABLE)
  elseif path_is(path, "/obj/stool/chair") then
    return world:has_feature(index, Constants.FEATURE.CHAIR)
  elseif path_is(path, "/obj/storage/crate") then
    return world:has_feature(index, Constants.FEATURE.CRATE)
  elseif path_is(path, "/obj/storage") then
    return world:has_feature(index, Constants.FEATURE.STORAGE)
  elseif path_is(path, "/obj/cable") then
    return world.cable[index] == true
  elseif path_is(path, "/obj/lattice") then
    return world:has_feature(index, Constants.FEATURE.LATTICE)
  elseif path_is(path, "/obj/mesh/catwalk") then
    return world:has_feature(index, Constants.FEATURE.CATWALK)
  elseif path_is(path, "/obj/machinery/atmospherics/pipe") then
    return world:has_feature(index, Constants.FEATURE.PIPE)
  elseif path_is(path, "/obj/disposalpipe")
    or path_is(path, "/obj/machinery/disposal")
    or path_is(path, "/obj/disposaloutlet")
  then
    return world:has_feature(index, Constants.FEATURE.DISPOSAL)
  elseif path_is(path, "/obj/machinery/light") then
    return world:has_feature(index, Constants.FEATURE.LIGHT)
  elseif path_is(path, "/obj/decal") then
    return world:has_feature(index, Constants.FEATURE.DECAL)
      or world:has_feature(index, Constants.FEATURE.SIGN)
  end
  return true
end

local function connection_at(world, index, path)
  if path_is(
    path,
    "/turf/simulated/floor/airless/plating/catwalk/auto"
  ) then
    return index and world:has_feature(index, Constants.FEATURE.CATWALK)
  elseif path_is(path, "/obj/table") then
    return index and world:has_feature(index, Constants.FEATURE.TABLE)
  elseif path_is(path, "/obj/mesh/grille") then
    return index and world:has_feature(index, Constants.FEATURE.GRILLE)
  elseif path_is(path, "/obj/window")
    or path_is(path, "/obj/mapping_helper/wingrille_spawn")
  then
    return boundary_at(world, index)
  end
  return boundary_at(world, index)
end

local function connection_mask(world, record, diagonal)
  local x = record.x
  local y = record.y
  local path = record.appearance.source_path
  local north = connection_at(world, world:index(x, y - 1), path)
  local south = connection_at(world, world:index(x, y + 1), path)
  local east = connection_at(world, world:index(x + 1, y), path)
  local west = connection_at(world, world:index(x - 1, y), path)
  local mask =
    (north and 1 or 0)
    + (south and 2 or 0)
    + (east and 4 or 0)
    + (west and 8 or 0)
  if not diagonal then
    return mask
  end
  if north and east
    and connection_at(world, world:index(x + 1, y - 1), path)
  then
    mask = mask + 16
  end
  if south and east
    and connection_at(world, world:index(x + 1, y + 1), path)
  then
    mask = mask + 32
  end
  if south and west
    and connection_at(world, world:index(x - 1, y + 1), path)
  then
    mask = mask + 64
  end
  if north and west
    and connection_at(world, world:index(x - 1, y - 1), path)
  then
    mask = mask + 128
  end
  return mask
end

local function grille_connection_state(mask)
  return ({
    [0] = 1,
    [1] = 1,
    [2] = 3,
    [3] = 3,
    [4] = 4,
    [5] = 4,
    [6] = 6,
    [7] = 6,
    [8] = 8,
    [9] = 8,
    [10] = 10,
    [11] = 10,
    [12] = 12,
    [13] = 12,
    [14] = 14,
    [15] = 14,
  })[mask] or 1
end

local function connected_state(world, record, rule)
  if rule.fidelity ~= "connected-state-deferred"
    and rule.fidelity ~= "map-helper-expanded"
  then
    return nil
  end
  local prefixed = {}
  local has_prefixed_state = false
  for part_index = 1, #rule.parts do
    local part = rule.parts[part_index]
    local prefix = part.state_prefix
    if type(prefix) == "string" then
      local diagonal = prefix:find("norn", 1, true) ~= nil
        or prefix == "W-"
        or prefix == "R-"
      local mask = connection_mask(world, record, diagonal)
      if prefix == "grille" then
        mask = grille_connection_state(mask)
      end
      prefixed[part_index] =
        prefix .. tostring(mask) .. (part.state_suffix or "")
      has_prefixed_state = true
    end
  end
  if has_prefixed_state then
    return prefixed
  end
  if #rule.parts ~= 1 then
    return nil
  end
  local part = rule.parts[1]
  local icon = (part.source_icon or ""):lower()
  local source_state = part.source_state or ""
  if path_is(
    record.appearance.source_path,
    "/turf/simulated/floor/airless/plating/catwalk/auto"
  ) then
    return tostring(connection_mask(world, record, false))
  elseif icon:find("/supernorn/", 1, true) then
    local prefix = source_state == "mapwall_r" and "norn-R-" or "norn-"
    return prefix .. tostring(connection_mask(world, record, true))
  elseif path_ends_with(icon, "/turf/walls/auto.dmi")
    or path_ends_with(icon, "/walls/auto.dmi")
  then
    local prefix = source_state == "mapwall_r" and "R" or ""
    return prefix .. tostring(connection_mask(world, record, false))
  elseif path_is(record.appearance.source_path, "/obj/table")
    and source_state:match("^%d+")
  then
    local material_suffix = source_state:match("(%$%$.*)$") or ""
    return tostring(connection_mask(world, record, false)) .. material_suffix
  elseif source_state:match("^grille%-%d+$") then
    return "grille-" .. tostring(connection_mask(world, record, false))
  end
  return nil
end

local function door_state(world, record, rule)
  local structure = world.structure[record.appearance.index]
  if (
      structure ~= Constants.STRUCTURE.DOOR_CLOSED
      and structure ~= Constants.STRUCTURE.DOOR_OPEN
    )
    or #rule.parts ~= 1
  then
    return nil
  end
  local state = record.appearance.resolved_icon_state
    or record.appearance.icon_state_override
    or rule.parts[1].source_state
  if type(state) ~= "string" then
    return nil
  end

  local want_open = structure == Constants.STRUCTURE.DOOR_OPEN
  local base = state:match("^(.-)_closed$")
    or state:match("^(.-)_open$")
  local projected
  if base then
    projected = base .. (want_open and "_open" or "_closed")
  elseif state:match("^pdoor[01]$") then
    projected = "pdoor" .. (want_open and "0" or "1")
  else
    base = state:match("^(bdoor.-)[01]$")
    if base then
      projected = base .. (want_open and "0" or "1")
    elseif state:match("^wood[01]$") then
      projected = "wood" .. (want_open and "0" or "1")
    end
  end

  -- Toilet-stall doors use the same numeric open/closed convention, but
  -- ordinary airlocks also have unrelated `door_*` states.
  local icon = (rule.parts[1].source_icon or ""):lower()
  if not projected
    and path_ends_with(icon, "/doors/door_stall.dmi")
  then
    base = state:match("^(doorc?)[01]$")
    if base then
      projected = base .. (want_open and "0" or "1")
    end
  end
  return projected ~= state and projected or nil
end

local function deterministic_random_state(record, rule)
  if rule.fidelity ~= "runtime-random-deferred" then
    return nil
  end
  if path_is(
    record.appearance.source_path,
    "/turf/simulated/floor/plating/random"
  ) then
    -- `plating_random` exists only behind Goon's IN_MAP_EDITOR define.
    -- Runtime inherits the ordinary plating base before optional damage
    -- overlays are rolled, so never expose the editor's question-mark tile.
    return "plating"
  end
  return nil
end

local function runtime_state(world, record, rule)
  return connected_state(world, record, rule)
    or door_state(world, record, rule)
    or deterministic_random_state(record, rule)
end

local function command_plane(record)
  local appearance = record.appearance
  local path = appearance.source_path
  if appearance.role == "turf"
    and path:find("/wall", 1, true)
  then
    return 1
  elseif appearance.role == "object" then
    -- These families live on or below the floor plane in BYOND.  Keeping
    -- them below turf walls prevents adjacent pipes, cables, catwalks, and
    -- decals from painting over the native wall silhouette.
    if path_is(path, "/obj/cable")
      or path_is(path, "/obj/lattice")
      or path_is(path, "/obj/mesh/catwalk")
      or path_is(path, "/obj/machinery/atmospherics/pipe")
      or path_is(path, "/obj/disposalpipe")
      or path_is(path, "/obj/machinery/disposal")
      or path_is(path, "/obj/disposaloutlet")
      or path_is(path, "/obj/decal")
    then
      return 0
    end
    return 2
  end
  return 0
end

local function command_less(left, right)
  if left.plane ~= right.plane then
    return left.plane < right.plane
  elseif left.sort_y ~= right.sort_y then
    return left.sort_y < right.sort_y
  elseif left.layer ~= right.layer then
    return left.layer < right.layer
  elseif left.x ~= right.x then
    return left.x < right.x
  elseif left.order ~= right.order then
    return left.order < right.order
  elseif left.part ~= right.part then
    return left.part < right.part
  end
  return left.drawable.id < right.drawable.id
end

local function append_commands(commands, record, resolved)
  local appearance = record.appearance
  for part_index = 1, #resolved do
    local drawable = resolved[part_index].drawable
    local part = resolved[part_index].metadata
    local pixel_x = appearance.pixel_x
    if pixel_x == nil then
      pixel_x = part.pixel_x or 0
    end
    local pixel_y = appearance.pixel_y
    if pixel_y == nil then
      pixel_y = part.pixel_y or 0
    end
    local layer = appearance.layer_milli
    if layer == nil then
      layer = part.layer_milli
        or (appearance.role == "turf" and 2000 or 3000)
    end
    commands[#commands + 1] = {
      drawable = drawable,
      layer = layer,
      order = appearance.order,
      part = resolved[part_index].part,
      plane = command_plane(record),
      x = record.x,
      sort_y = record.y * Constants.TILE_SIZE - pixel_y,
      draw_x = (record.x - 1) * Constants.TILE_SIZE + pixel_x,
      draw_y = record.y * Constants.TILE_SIZE
        - drawable.height
        - pixel_y,
    }
  end
end

local function resolve_for_draw(catalog, appearance, projected_state)
  local resolved, resolve_error = catalog:resolve(
    appearance,
    projected_state
  )
  if resolved or not projected_state then
    return resolved, false, resolve_error
  end
  -- A projected family state should normally be present in the compact
  -- selection. Keep the reviewed static source sprite as a safe last resort
  -- and expose the miss through diagnostics.
  local static = catalog:resolve(appearance)
  return static, true, resolve_error
end

local function synthetic_space_state(index)
  -- Stable variation for a newly exposed space turf. Imported space retains
  -- its exact upstream state; this only covers simulation-created cells.
  return tostring(((index * 17 + 11) % 25) + 1)
end

local function synthetic_turf_record(world, index, x, y)
  local path
  if world.tile[index] == Constants.TILE.SPACE then
    path = "/turf/space"
  elseif world.structure[index] == Constants.STRUCTURE.WALL then
    path = world.wall_kind[index] == Constants.WALL.REINFORCED
        and "/turf/simulated/wall/auto/reinforced/supernorn"
      or "/turf/simulated/wall/auto/supernorn"
  elseif world.turf_kind[index] == Constants.TURF.PLATING then
    path = "/turf/simulated/floor/plating"
  elseif world.turf_kind[index] == Constants.TURF.REINFORCED_FLOOR then
    path = "/turf/simulated/floor/engine"
  else
    path = "/turf/simulated/floor"
  end
  local appearance = {
    direction = "south",
    index = index,
    order = 0,
    role = "turf",
    source_path = path,
  }
  if path == "/turf/space" then
    appearance.resolved_icon_state = synthetic_space_state(index)
  end
  return {
    appearance = appearance,
    x = x,
    y = y,
  }
end

local function synthetic_door_direction(world, x, y)
  local north_south =
    boundary_at(world, world:index(x, y - 1))
    or boundary_at(world, world:index(x, y + 1))
  local east_west =
    boundary_at(world, world:index(x - 1, y))
    or boundary_at(world, world:index(x + 1, y))
  if north_south and not east_west then
    return "east"
  end
  return "south"
end

local function synthetic_door_record(world, index, x, y)
  return {
    appearance = {
      direction = synthetic_door_direction(world, x, y),
      index = index,
      order = 1000000,
      role = "object",
      source_path = "/obj/machinery/door/airlock/pyro",
    },
    x = x,
    y = y,
  }
end

function MapAppearance.new(world, content)
  local catalog = DmAppearanceCatalog.new()
  local scenario = content
    and content.by_id
    and content.by_id[world.map_id]
  local appearances = scenario
    and scenario.map
    and scenario.map.appearances
    or {}
  local provenance_matches =
    catalog.available and catalog_matches_scenario(catalog, scenario)
  local self = setmetatable({
    active = provenance_matches and #appearances > 0,
    catalog = catalog,
    chunks = {},
    error = catalog.error
      or (
        #appearances > 0
          and not provenance_matches
          and "DM appearance catalog does not match scenario provenance"
        or nil
      ),
    records_by_chunk = {},
    sources_by_index = {},
    render_runs = {},
    render_signature = false,
    visible_chunks = 0,
    rebuilt_chunks = 0,
    dynamic_fallbacks = 0,
    missing_states = {},
    synthetic_fallbacks = 0,
    unresolved = 0,
  }, MapAppearance)
  if not self.active then
    return self
  end
  for appearance_index = 1, #appearances do
    local appearance = appearances[appearance_index]
    local x, y = world:coordinates(appearance.index)
    local chunk_index = world:chunk_index(x, y)
    local records = self.records_by_chunk[chunk_index]
    if not records then
      records = {}
      self.records_by_chunk[chunk_index] = records
    end
    local record = {
      appearance = appearance,
      x = x,
      y = y,
    }
    records[#records + 1] = record
    local sources = self.sources_by_index[appearance.index]
    if not sources then
      sources = {}
      self.sources_by_index[appearance.index] = sources
    end
    sources[appearance.source_path] = appearance
  end
  return self
end

function MapAppearance:covers_machine(machine)
  if not self.active then
    return false
  end
  local sources = self.sources_by_index[machine.index]
  local appearance = sources and sources[machine.source_path]
  return appearance ~= nil
    and self.catalog:rule_for("object", appearance.source_path) ~= nil
end

function MapAppearance:_rebuild_chunk(world, chunk_index)
  local commands = {}
  local records = self.records_by_chunk[chunk_index] or {}
  local dynamic_fallbacks = 0
  local missing_states = {}
  local synthetic_fallbacks = 0
  local unresolved = 0
  local visible_doors = {}
  local visible_turfs = {}

  local function add_record(record)
    local appearance = record.appearance
    local rule = self.catalog:rule_for(
      appearance.role,
      appearance.source_path
    )
    if not rule then
      unresolved = unresolved + 1
      return false
    end
    if not appearance_is_visible(world, record) then
      return false
    end
    local projected_state = runtime_state(world, record, rule)
    local resolved, used_static, resolve_error = resolve_for_draw(
      self.catalog,
      appearance,
      projected_state
    )
    if used_static then
      dynamic_fallbacks = dynamic_fallbacks + 1
      local key = tostring(resolve_error)
      missing_states[key] = (missing_states[key] or 0) + 1
    end
    if not resolved then
      unresolved = unresolved + 1
      return false
    end
    append_commands(commands, record, resolved)
    return true
  end

  for record_index = 1, #records do
    local record = records[record_index]
    local appearance = record.appearance
    if add_record(record) then
      if appearance.role == "turf" then
        visible_turfs[appearance.index] = true
      elseif appearance_is_door(appearance.source_path) then
        visible_doors[appearance.index] = true
      end
    end
  end

  -- A native map record describes the initial BYOND atom, while the
  -- simulation can replace that atom later. Fill only semantic holes so a
  -- dismantled wall exposes a real Goon floor and constructed walls/airlocks
  -- never fall back to rectangles or disappear.
  local chunk_x = ((chunk_index - 1) % world.chunks_x) + 1
  local chunk_y = math.floor((chunk_index - 1) / world.chunks_x) + 1
  local start_x = (chunk_x - 1) * Constants.CHUNK_SIZE + 1
  local start_y = (chunk_y - 1) * Constants.CHUNK_SIZE + 1
  local end_x = math.min(
    start_x + Constants.CHUNK_SIZE - 1,
    world.width
  )
  local end_y = math.min(
    start_y + Constants.CHUNK_SIZE - 1,
    world.height
  )
  for y = start_y, end_y do
    for x = start_x, end_x do
      local index = world:index(x, y)
      if not visible_turfs[index]
        and add_record(synthetic_turf_record(world, index, x, y))
      then
        synthetic_fallbacks = synthetic_fallbacks + 1
      end
      local structure = world.structure[index]
      if (
          structure == Constants.STRUCTURE.DOOR_CLOSED
          or structure == Constants.STRUCTURE.DOOR_OPEN
        )
        and not visible_doors[index]
        and add_record(synthetic_door_record(world, index, x, y))
      then
        synthetic_fallbacks = synthetic_fallbacks + 1
      end
    end
  end
  table.sort(commands, command_less)
  self.chunks[chunk_index] = {
    commands = commands,
    revision = world.chunk_revision[chunk_index],
    topology_revision = world.topology_revision,
    dynamic_fallbacks = dynamic_fallbacks,
    missing_states = missing_states,
    synthetic_fallbacks = synthetic_fallbacks,
    unresolved = unresolved,
  }
  return self.chunks[chunk_index]
end

local function finish_run(runs, commands, first, last)
  if first > last then
    return
  end
  local image = commands[first].drawable.image
  local batch = love.graphics.newSpriteBatch(
    image,
    last - first + 1,
    "static"
  )
  batch:setColor(1, 1, 1, 1)
  for command_index = first, last do
    local command = commands[command_index]
    batch:add(
      command.drawable.quad,
      command.draw_x,
      command.draw_y
    )
  end
  batch:flush()
  runs[#runs + 1] = batch
end

function MapAppearance:_build_runs(commands, signature)
  local runs = {}
  local first = 1
  for command_index = 2, #commands do
    if commands[command_index].drawable.image
      ~= commands[command_index - 1].drawable.image
    then
      finish_run(runs, commands, first, command_index - 1)
      first = command_index
    end
  end
  finish_run(runs, commands, first, #commands)
  self.render_runs = runs
  self.render_signature = signature
end

function MapAppearance:draw(world, min_x, min_y, max_x, max_y)
  if not self.active then
    return false
  end
  local chunk_size = Constants.CHUNK_SIZE
  local first_chunk_x = math.floor((min_x - 1) / chunk_size) + 1
  local first_chunk_y = math.floor((min_y - 1) / chunk_size) + 1
  local last_chunk_x = math.floor((max_x - 1) / chunk_size) + 1
  local last_chunk_y = math.floor((max_y - 1) / chunk_size) + 1
  local commands = {}
  local signature_parts = {}
  self.visible_chunks = 0
  self.rebuilt_chunks = 0
  self.dynamic_fallbacks = 0
  self.missing_states = {}
  self.synthetic_fallbacks = 0
  self.unresolved = 0
  for chunk_y = first_chunk_y, last_chunk_y do
    for chunk_x = first_chunk_x, last_chunk_x do
      local chunk_index = (chunk_y - 1) * world.chunks_x + chunk_x
      local chunk = self.chunks[chunk_index]
      if not chunk
        or chunk.revision ~= world.chunk_revision[chunk_index]
        or chunk.topology_revision ~= world.topology_revision
      then
        chunk = self:_rebuild_chunk(world, chunk_index)
        self.rebuilt_chunks = self.rebuilt_chunks + 1
      end
      signature_parts[#signature_parts + 1] =
        tostring(chunk_index)
        .. ":" .. tostring(chunk.revision)
        .. ":" .. tostring(chunk.topology_revision)
      for command_index = 1, #chunk.commands do
        commands[#commands + 1] = chunk.commands[command_index]
      end
      self.unresolved = self.unresolved + chunk.unresolved
      self.dynamic_fallbacks =
        self.dynamic_fallbacks + chunk.dynamic_fallbacks
      self.synthetic_fallbacks =
        self.synthetic_fallbacks + (chunk.synthetic_fallbacks or 0)
      for message, count in pairs(chunk.missing_states) do
        self.missing_states[message] =
          (self.missing_states[message] or 0) + count
      end
      self.visible_chunks = self.visible_chunks + 1
    end
  end
  local signature = table.concat(signature_parts, ",")
  if signature ~= self.render_signature then
    table.sort(commands, command_less)
    self:_build_runs(commands, signature)
  end
  love.graphics.setColor(1, 1, 1, 1)
  for run_index = 1, #self.render_runs do
    love.graphics.draw(self.render_runs[run_index])
  end
  return true, #self.render_runs
end

function MapAppearance:diagnostics()
  return {
    active = self.active,
    dynamic_fallbacks = self.dynamic_fallbacks,
    missing_states = self.missing_states,
    synthetic_fallbacks = self.synthetic_fallbacks,
    unresolved = self.unresolved,
    visible_chunks = self.visible_chunks,
  }
end

return MapAppearance
