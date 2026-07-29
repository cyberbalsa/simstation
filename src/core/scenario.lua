local Constants = require("src.core.constants")
local Stable = require("src.core.stable")
local World = require("src.core.world")
local ContentId = require("src.content.id")

local Scenario = {}

local MAX_DIMENSION = 256
local MAX_PALETTE = 2048
local MAX_RUNS = 200000
local MAX_APPEARANCES = 1000000
local MAX_AREAS = 1024
local MAX_FIXTURES = 8192
local MAX_SPAWNS = 1024
local MAX_TARGETS = 1024

local TILE_VALUES = {
  space = Constants.TILE.SPACE,
  floor = Constants.TILE.FLOOR,
}

local TURF_VALUES = {
  space = Constants.TURF.SPACE,
  plating = Constants.TURF.PLATING,
  floor = Constants.TURF.FLOOR,
  reinforced_floor = Constants.TURF.REINFORCED_FLOOR,
}

local STRUCTURE_VALUES = {
  empty = Constants.STRUCTURE.EMPTY,
  wall = Constants.STRUCTURE.WALL,
  door_closed = Constants.STRUCTURE.DOOR_CLOSED,
  door_open = Constants.STRUCTURE.DOOR_OPEN,
}

local WALL_VALUES = {
  standard = Constants.WALL.STANDARD,
  reinforced = Constants.WALL.REINFORCED,
}

local FEATURE_VALUES = {
  window = Constants.FEATURE.WINDOW,
  grille = Constants.FEATURE.GRILLE,
  table = Constants.FEATURE.TABLE,
  chair = Constants.FEATURE.CHAIR,
  light = Constants.FEATURE.LIGHT,
  storage = Constants.FEATURE.STORAGE,
  crate = Constants.FEATURE.CRATE,
  lattice = Constants.FEATURE.LATTICE,
  catwalk = Constants.FEATURE.CATWALK,
  pipe = Constants.FEATURE.PIPE,
  disposal = Constants.FEATURE.DISPOSAL,
  sign = Constants.FEATURE.SIGN,
  decal = Constants.FEATURE.DECAL,
}

local FIXTURE_KINDS = {
  apc = true,
  barcode_computer = true,
  battery = true,
  cargo_pad = true,
  circulator = true,
  fabricator = true,
  generator = true,
  generic = true,
  nanofab = true,
  portable_scrubber = true,
  reclaimer = true,
  refinery = true,
  scrubber = true,
  supply_console = true,
  vent = true,
  vent_pump = true,
}

local EXPECTED_NESTED_KINDS = {
  area = "scenario-area",
  fixture = "scenario-fixture",
  spawn = "scenario-spawn",
}

local DEPARTMENTS = {
  cargo = true,
  command = true,
  engineering = true,
  general = true,
  medical = true,
  science = true,
  security = true,
  service = true,
}

local DEFINITION_KEYS = {
  areas = true,
  description = true,
  fixtures = true,
  id = true,
  kind = true,
  map = true,
  meteor_targets = true,
  name = true,
  power_supply_w = true,
  provenance = true,
  replaces = true,
  schema = true,
  spawns = true,
  starting_inventory = true,
}

local MAP_KEYS = {
  appearances = true,
  default_palette = true,
  format = true,
  height = true,
  palette = true,
  runs = true,
  width = true,
}

local APPEARANCE_KEYS = {
  direction = true,
  icon_override = true,
  icon_state_override = true,
  index = true,
  layer_milli = true,
  order = true,
  pixel_x = true,
  pixel_y = true,
  resolved_icon_state = true,
  role = true,
  source_path = true,
}

local AREA_KEYS = {
  access = true,
  department = true,
  id = true,
  key = true,
  name = true,
  source_path = true,
}

local PALETTE_KEYS = {
  access = true,
  area = true,
  cable = true,
  features = true,
  key = true,
  pressurized = true,
  source_objects = true,
  source_turfs = true,
  structure = true,
  tile = true,
  turf_kind = true,
  wall_kind = true,
}

local FIXTURE_KEYS = {
  definition_id = true,
  department = true,
  id = true,
  kind = true,
  name = true,
  source_overrides = true,
  source_path = true,
  x = true,
  y = true,
}

local SPAWN_KEYS = {
  department = true,
  id = true,
  job = true,
  source_path = true,
  x = true,
  y = true,
}

local TARGET_KEYS = {
  x = true,
  y = true,
}

local function closed_keys(value, allowed, name)
  local keys = Stable.sorted_keys(value)
  for index = 1, #keys do
    local key = keys[index]
    assert(type(key) == "string" and allowed[key],
      name .. " has unknown key " .. tostring(key))
  end
end

local function integer(value, name, minimum, maximum)
  assert(
    type(value) == "number"
      and value % 1 == 0
      and value >= minimum
      and value <= maximum,
    string.format("%s must be an integer from %d through %d", name, minimum, maximum)
  )
  return value
end

local function nonempty_string(value, name, maximum)
  assert(type(value) == "string" and value ~= "", name .. " must be a string")
  assert(#value <= (maximum or 240), name .. " is too long")
  return value
end

local function content_id(value, expected_kind, name)
  nonempty_string(value, name, 240)
  local parsed, err = ContentId.parse(value)
  assert(parsed, name .. ": " .. tostring(err))
  assert(parsed.kind == expected_kind,
    string.format("%s must have kind %s", name, expected_kind))
  return parsed
end

local function nested_content_id(value, expected_kind, scenario_id, name)
  local parsed = content_id(value, expected_kind, name)
  local expected_prefix = scenario_id.name .. "/"
  assert(
    parsed.pack == scenario_id.pack
      and parsed.name:sub(1, #expected_prefix) == expected_prefix,
    name .. " must belong to scenario " .. scenario_id.value
  )
  return parsed
end

local function validate_position(record, width, height, name)
  assert(type(record) == "table", name .. " must be an object")
  integer(record.x, name .. ".x", 1, width)
  integer(record.y, name .. ".y", 1, height)
end

local function validate_areas(definition, scenario_id)
  local areas = definition.areas or {}
  assert(type(areas) == "table", "scenario areas must be an array")
  assert(#areas <= MAX_AREAS, "scenario has too many areas")
  local keys = {}
  for index = 1, #areas do
    local area = areas[index]
    assert(type(area) == "table", "area must be an object")
    closed_keys(area, AREA_KEYS, "area")
    integer(area.id, "area.id", 1, #areas)
    assert(area.id == index, "area IDs must be contiguous and ordered")
    local key = nonempty_string(area.key, "area.key")
    nested_content_id(
      key,
      EXPECTED_NESTED_KINDS.area,
      scenario_id,
      "area.key"
    )
    assert(not keys[key], "duplicate area key: " .. key)
    keys[key] = true
    nonempty_string(area.name, "area.name")
    assert(DEPARTMENTS[area.department], "unknown area department")
    nonempty_string(area.access or "public", "area.access")
    if area.source_path ~= nil then
      nonempty_string(area.source_path, "area.source_path", 1024)
    end
  end
  return areas
end

local function validate_palette(map, area_count)
  local palette = map.palette
  assert(type(palette) == "table" and #palette > 0,
    "scenario map palette must not be empty")
  assert(#palette <= MAX_PALETTE, "scenario map palette is too large")
  local keys = {}
  local semantics = {}
  for index = 1, #palette do
    local cell = palette[index]
    assert(type(cell) == "table", "palette cell must be an object")
    closed_keys(cell, PALETTE_KEYS, "palette cell")
    local key = nonempty_string(cell.key, "palette.key")
    assert(not keys[key], "duplicate palette key: " .. key)
    keys[key] = true
    assert(TILE_VALUES[cell.tile], "unknown palette tile: " .. tostring(cell.tile))
    local turf_kind = cell.turf_kind
      or (cell.tile == "space" and "space" or "floor")
    assert(TURF_VALUES[turf_kind],
      "unknown palette turf kind: " .. tostring(turf_kind))
    assert(
      (cell.tile == "space") == (turf_kind == "space"),
      "palette turf kind must agree with tile"
    )
    assert(
      STRUCTURE_VALUES[cell.structure or "empty"] ~= nil,
      "unknown palette structure: " .. tostring(cell.structure)
    )
    if cell.wall_kind ~= nil then
      assert(WALL_VALUES[cell.wall_kind],
        "unknown palette wall kind: " .. tostring(cell.wall_kind))
      assert((cell.structure or "empty") == "wall",
        "palette wall kind requires a wall")
    end
    local features = cell.features or {}
    assert(type(features) == "table", "palette.features must be an array")
    local previous_feature = ""
    for feature_index = 1, #features do
      local feature = features[feature_index]
      assert(FEATURE_VALUES[feature],
        "unknown palette feature: " .. tostring(feature))
      assert(feature > previous_feature,
        "palette features must be sorted and unique")
      previous_feature = feature
    end
    for _, source_key in ipairs({ "source_turfs", "source_objects" }) do
      local values = cell[source_key] or {}
      assert(type(values) == "table", "palette." .. source_key .. " must be an array")
      local previous = ""
      for value_index = 1, #values do
        local value = nonempty_string(
          values[value_index],
          "palette." .. source_key,
          1024
        )
        assert(value:sub(1, 1) == "/",
          "palette source paths must be absolute DM type paths")
        assert(value > previous,
          "palette source paths must be sorted and unique")
        previous = value
      end
    end
    if cell.cable ~= nil then
      assert(type(cell.cable) == "boolean", "palette.cable must be boolean")
    end
    if cell.pressurized ~= nil then
      assert(type(cell.pressurized) == "boolean",
        "palette.pressurized must be boolean")
    end
    integer(cell.area or 0, "palette.area", 0, area_count)
    if cell.access ~= nil then
      nonempty_string(cell.access, "palette.access")
      assert(
        (cell.structure or "empty") == "door_closed"
          or (cell.structure or "empty") == "door_open",
        "palette.access is valid only on a door"
      )
    end
    local access = cell.access or ""
    local semantic = table.concat({
      cell.tile,
      turf_kind,
      cell.structure or "empty",
      cell.wall_kind or "",
      cell.cable == true and "1" or "0",
      cell.pressurized == true and "1" or "0",
      tostring(cell.area or 0),
      tostring(#access),
      access,
      table.concat(features, ","),
      table.concat(cell.source_turfs or {}, ","),
      table.concat(cell.source_objects or {}, ","),
    }, ":")
    assert(not semantics[semantic], "duplicate semantic palette cell")
    semantics[semantic] = true
  end
  return palette
end

local function validate_runs(map, width, height, palette_count, default_palette)
  local runs = map.runs or {}
  assert(type(runs) == "table", "scenario map runs must be an array")
  assert(#runs <= MAX_RUNS, "scenario map has too many runs")
  local size = width * height
  local previous_end = 0
  local previous_palette = 0
  for index = 1, #runs do
    local run = runs[index]
    assert(type(run) == "table" and #run == 3,
      "map run must be [start, length, palette]")
    local start = integer(run[1], "map run start", 1, size)
    local length = integer(run[2], "map run length", 1, width)
    integer(run[3], "map run palette", 1, palette_count)
    assert(run[3] ~= default_palette, "map run repeats the default palette")
    local finish = start + length - 1
    assert(finish <= size, "map run exceeds map bounds")
    assert(
      math.floor((start - 1) / width) == math.floor((finish - 1) / width),
      "map runs may not cross row boundaries"
    )
    assert(start > previous_end, "map runs must be ordered and non-overlapping")
    assert(
      start ~= previous_end + 1
        or run[3] ~= previous_palette
        or math.floor((start - 1) / width)
          ~= math.floor((previous_end - 1) / width),
      "adjacent same-palette map runs must be merged"
    )
    previous_end = finish
    previous_palette = run[3]
  end
  return runs
end

local APPEARANCE_DIRECTIONS = {
  east = true,
  north = true,
  northeast = true,
  northwest = true,
  south = true,
  southeast = true,
  southwest = true,
  west = true,
}

local function safe_dm_type_path(path, root)
  return type(path) == "string"
    and (
      path == root
      or path:sub(1, #root + 1) == root .. "/"
    )
    and path:match("^/[-A-Za-z0-9_/]+$") ~= nil
    and not path:find("//", 1, true)
end

local function safe_dmi_path(path)
  if type(path) ~= "string"
    or path:sub(1, 6) ~= "icons/"
    or path:sub(-4):lower() ~= ".dmi"
    or path:find("\\", 1, true)
    or path:find("//", 1, true)
  then
    return false
  end
  for component in path:gmatch("[^/]+") do
    if component == "." or component == ".." then
      return false
    end
  end
  return true
end

local function validate_appearances(map, width, height)
  local appearances = map.appearances or {}
  assert(type(appearances) == "table", "map.appearances must be an array")
  assert(#appearances <= MAX_APPEARANCES,
    "scenario map has too many appearances")
  local previous_index = 0
  local previous_order = 0
  for appearance_index = 1, #appearances do
    local appearance = appearances[appearance_index]
    assert(type(appearance) == "table", "map appearance must be an object")
    closed_keys(appearance, APPEARANCE_KEYS, "map appearance")
    local index = integer(
      appearance.index,
      "map appearance.index",
      1,
      width * height
    )
    local order = integer(
      appearance.order,
      "map appearance.order",
      1,
      4096
    )
    assert(
      index > previous_index
        or (index == previous_index and order > previous_order),
      "map appearances must be sorted by index and unique order"
    )
    previous_index = index
    previous_order = order
    assert(
      appearance.role == "turf" or appearance.role == "object",
      "map appearance role must be turf or object"
    )
    local source_path = nonempty_string(
      appearance.source_path,
      "map appearance.source_path",
      1024
    )
    local source_root = appearance.role == "turf" and "/turf" or "/obj"
    assert(safe_dm_type_path(source_path, source_root),
      "map appearance role and source path must match")
    if appearance.direction ~= nil then
      assert(APPEARANCE_DIRECTIONS[appearance.direction],
        "unknown map appearance direction")
    end
    if appearance.icon_override ~= nil then
      local icon = nonempty_string(
        appearance.icon_override,
        "map appearance.icon_override",
        1024
      )
      assert(
        safe_dmi_path(icon),
        "map appearance icon override must name an icons/*.dmi source"
      )
    end
    if appearance.icon_state_override ~= nil then
      nonempty_string(
        appearance.icon_state_override,
        "map appearance.icon_state_override",
        256
      )
    end
    if appearance.resolved_icon_state ~= nil then
      nonempty_string(
        appearance.resolved_icon_state,
        "map appearance.resolved_icon_state",
        256
      )
    end
    if appearance.pixel_x ~= nil then
      integer(appearance.pixel_x, "map appearance.pixel_x", -4096, 4096)
    end
    if appearance.pixel_y ~= nil then
      integer(appearance.pixel_y, "map appearance.pixel_y", -4096, 4096)
    end
    if appearance.layer_milli ~= nil then
      integer(
        appearance.layer_milli,
        "map appearance.layer_milli",
        -1000000000,
        1000000000
      )
    end
  end
  return appearances
end

local function validate_fixtures(definition, width, height, scenario_id)
  local fixtures = definition.fixtures or {}
  assert(type(fixtures) == "table", "scenario fixtures must be an array")
  assert(#fixtures <= MAX_FIXTURES, "scenario has too many fixtures")
  local ids = {}
  for index = 1, #fixtures do
    local fixture = fixtures[index]
    assert(type(fixture) == "table", "fixture must be an object")
    closed_keys(fixture, FIXTURE_KEYS, "fixture")
    validate_position(fixture, width, height, "fixture")
    local id = nonempty_string(fixture.id, "fixture.id")
    nested_content_id(
      id,
      EXPECTED_NESTED_KINDS.fixture,
      scenario_id,
      "fixture.id"
    )
    assert(not ids[id], "duplicate fixture ID: " .. id)
    ids[id] = true
    assert(FIXTURE_KINDS[fixture.kind],
      "unknown fixture kind: " .. tostring(fixture.kind))
    if fixture.definition_id ~= nil then
      local parsed, definition_error = ContentId.parse(fixture.definition_id)
      assert(parsed, definition_error)
      assert(parsed.kind == "machine",
        "fixture.definition_id must name machine content")
    end
    if fixture.department ~= nil then
      assert(DEPARTMENTS[fixture.department], "unknown fixture department")
    end
    if fixture.name ~= nil then
      nonempty_string(fixture.name, "fixture.name")
    end
    if fixture.source_path ~= nil then
      nonempty_string(fixture.source_path, "fixture.source_path", 1024)
    end
    if fixture.source_overrides ~= nil then
      assert(type(fixture.source_overrides) == "table",
        "fixture.source_overrides must be an object")
      for key, value in pairs(fixture.source_overrides) do
        assert(type(key) == "string" and key:match("^[A-Za-z_][A-Za-z0-9_]*$"),
          "invalid fixture source override name")
        local value_type = type(value)
        assert(
          value_type == "string"
            or value_type == "boolean"
            or (
              value_type == "number"
              and value == math.floor(value)
              and value >= -9007199254740991
              and value <= 9007199254740991
            ),
          "fixture source overrides must be safe scalar literals"
        )
      end
    end
  end
  return fixtures
end

local function validate_spawns(definition, width, height, scenario_id)
  local spawns = definition.spawns or {}
  assert(type(spawns) == "table", "scenario spawns must be an array")
  assert(#spawns <= MAX_SPAWNS, "scenario has too many spawns")
  local ids = {}
  local positions = {}
  for index = 1, #spawns do
    local spawn = spawns[index]
    assert(type(spawn) == "table", "spawn must be an object")
    closed_keys(spawn, SPAWN_KEYS, "spawn")
    validate_position(spawn, width, height, "spawn")
    local id = nonempty_string(spawn.id, "spawn.id")
    nested_content_id(
      id,
      EXPECTED_NESTED_KINDS.spawn,
      scenario_id,
      "spawn.id"
    )
    assert(not ids[id], "duplicate spawn ID: " .. id)
    ids[id] = true
    local position = tostring(spawn.y) .. ":" .. tostring(spawn.x)
    assert(not positions[position], "duplicate spawn coordinate")
    positions[position] = true
    if spawn.job ~= nil then
      content_id(spawn.job, "job", "spawn.job")
    end
    assert(DEPARTMENTS[spawn.department or "general"],
      "unknown spawn department")
    if spawn.source_path ~= nil then
      nonempty_string(spawn.source_path, "spawn.source_path", 1024)
    end
  end
  return spawns
end

local function validate_targets(definition, width, height)
  local targets = definition.meteor_targets or {}
  assert(type(targets) == "table", "meteor_targets must be an array")
  assert(#targets <= MAX_TARGETS, "scenario has too many meteor targets")
  local positions = {}
  for index = 1, #targets do
    local target = targets[index]
    assert(type(target) == "table", "meteor target must be an object")
    closed_keys(target, TARGET_KEYS, "meteor target")
    validate_position(target, width, height, "meteor target")
    local key = tostring(target.y) .. ":" .. tostring(target.x)
    assert(not positions[key], "duplicate meteor target coordinate")
    positions[key] = true
  end
  return targets
end

function Scenario.validate(definition, content)
  assert(type(definition) == "table", "scenario definition must be an object")
  closed_keys(definition, DEFINITION_KEYS, "scenario")
  local scenario_id = content_id(definition.id, "scenario", "scenario.id")
  assert(definition.kind == "scenario", "scenario kind must be 'scenario'")
  assert(definition.schema == 1, "unsupported scenario schema")
  nonempty_string(definition.name, "scenario.name")
  if definition.description ~= nil then
    nonempty_string(definition.description, "scenario.description", 4096)
  end

  local map = definition.map
  assert(type(map) == "table", "scenario map is required")
  closed_keys(map, MAP_KEYS, "scenario map")
  assert(map.format == "simstation-map-v1", "unsupported scenario map format")
  local width = integer(map.width, "map.width", 16, MAX_DIMENSION)
  local height = integer(map.height, "map.height", 16, MAX_DIMENSION)
  local areas = validate_areas(definition, scenario_id)
  local palette = validate_palette(map, #areas)
  local default_palette = integer(
    map.default_palette or 1,
    "map.default_palette",
    1,
    #palette
  )
  validate_runs(map, width, height, #palette, default_palette)
  validate_appearances(map, width, height)
  validate_fixtures(definition, width, height, scenario_id)
  validate_spawns(definition, width, height, scenario_id)
  validate_targets(definition, width, height)

  integer(definition.power_supply_w or 0, "scenario.power_supply_w", 0, 1000000000)
  local inventory = definition.starting_inventory or {}
  assert(type(inventory) == "table", "starting_inventory must be an object")
  local inventory_keys = Stable.sorted_keys(inventory)
  for index = 1, #inventory_keys do
    local id = inventory_keys[index]
    content_id(id, "item", "starting_inventory key")
    integer(inventory[id], "starting_inventory quantity", 0, 1000000000)
    if content and content.by_id then
      assert(content.by_id[id], "unknown starting inventory item: " .. id)
    end
  end
  if content and content.by_id then
    local fixtures = definition.fixtures or {}
    for index = 1, #fixtures do
      local definition_id = fixtures[index].definition_id
      if definition_id then
        local machine = content.by_id[definition_id]
        assert(machine and machine.kind == "machine",
          "unknown fixture machine definition: " .. definition_id)
      end
    end
    local spawns = definition.spawns or {}
    for index = 1, #spawns do
      local job_id = spawns[index].job
      if job_id then
        local job = content.by_id[job_id]
        assert(job and job.kind == "job", "unknown spawn job: " .. job_id)
      end
    end
  end
  return true
end

local function palette_value(cell, areas)
  local structure = STRUCTURE_VALUES[cell.structure or "empty"]
  local turf_kind = cell.turf_kind
    or (cell.tile == "space" and "space" or "floor")
  local access = cell.access
  if structure == Constants.STRUCTURE.DOOR_CLOSED
    or structure == Constants.STRUCTURE.DOOR_OPEN
  then
    local area = areas[cell.area or 0]
    access = access or (area and area.access) or "public"
  end
  local feature_mask = 0
  for index = 1, #(cell.features or {}) do
    feature_mask = feature_mask + FEATURE_VALUES[cell.features[index]]
  end
  return {
    tile = TILE_VALUES[cell.tile],
    turf_kind = TURF_VALUES[turf_kind],
    structure = structure,
    wall_kind = cell.wall_kind and WALL_VALUES[cell.wall_kind]
      or (
        structure == Constants.STRUCTURE.WALL
          and Constants.WALL.STANDARD
        or Constants.WALL.NONE
      ),
    feature_mask = feature_mask,
    cable = cell.cable == true,
    pressurized = cell.pressurized == true,
    area = cell.area or 0,
    access = access or false,
  }
end

local function apply_cell(world, index, cell)
  world.tile[index] = cell.tile
  world.turf_kind[index] = cell.turf_kind
  world.structure[index] = cell.structure
  world.wall_kind[index] = cell.wall_kind
  world.feature_mask[index] = cell.feature_mask
  if cell.structure == Constants.STRUCTURE.WALL then
    local maximum = cell.wall_kind == Constants.WALL.REINFORCED and 300 or 100
    world.structure_health[index] = maximum
    world.structure_max_health[index] = maximum
  elseif cell.structure == Constants.STRUCTURE.DOOR_CLOSED
    or cell.structure == Constants.STRUCTURE.DOOR_OPEN
  then
    world.structure_health[index] = 100
    world.structure_max_health[index] = 100
  end
  world.cable[index] = cell.cable
  world.area[index] = cell.area
  world.door_access[index] = cell.access
  if cell.pressurized
    and cell.tile == Constants.TILE.FLOOR
    and cell.structure ~= Constants.STRUCTURE.WALL
  then
    world.o2[index] = Constants.STANDARD_O2
    world.n2[index] = Constants.STANDARD_N2
    world.temperature_mk[index] = Constants.STANDARD_TEMPERATURE_MK
  elseif cell.tile == Constants.TILE.FLOOR then
    world.temperature_mk[index] = Constants.SPACE_TEMPERATURE_MK
  end
end

local function touches_cable(world, index)
  if world.cable[index] then
    return true
  end
  local x, y = world:coordinates(index)
  local neighbors = {
    world:index(x, y - 1),
    world:index(x - 1, y),
    world:index(x + 1, y),
    world:index(x, y + 1),
  }
  for neighbor = 1, 4 do
    if neighbors[neighbor] and world.cable[neighbors[neighbor]] then
      return true
    end
  end
  return false
end

local function validate_expanded(definition, world, fixtures, spawns, targets)
  for index = 1, #fixtures do
    local fixture = fixtures[index]
    local tile_index = fixture.index
    local structure = world.structure[tile_index]
    assert(
      world.tile[tile_index] == Constants.TILE.FLOOR
        and structure ~= Constants.STRUCTURE.WALL
        and structure ~= Constants.STRUCTURE.DOOR_CLOSED,
      "fixture is not anchored to a usable floor: " .. fixture.id
    )
    if fixture.kind == "apc" then
      assert(world.area[tile_index] > 0, "APC has no area: " .. fixture.id)
      assert(touches_cable(world, tile_index),
        "APC does not touch a cable: " .. fixture.id)
    elseif fixture.kind == "generator" then
      assert(touches_cable(world, tile_index),
        "generator does not touch a cable: " .. fixture.id)
    elseif fixture.kind == "vent"
      or fixture.kind == "vent_pump"
      or fixture.kind == "scrubber"
      or fixture.kind == "portable_scrubber"
      or fixture.kind == "circulator"
    then
      assert(world:is_gas_cell(tile_index),
        "atmos fixture is not in a gas cell: " .. fixture.id)
    end
  end
  for index = 1, #spawns do
    local spawn = spawns[index]
    local tile_index = assert(world:index(spawn.x, spawn.y))
    assert(world:is_passable(tile_index),
      "spawn is not on a passable floor: " .. spawn.id)
  end
  for index = 1, #targets do
    local target = targets[index]
    local tile_index = assert(world:index(target.x, target.y))
    assert(
      world.tile[tile_index] == Constants.TILE.FLOOR
        and world.structure[tile_index] == Constants.STRUCTURE.WALL,
      string.format("meteor target is not a wall at %d,%d", target.x, target.y)
    )
    local neighbors = {
      world:index(target.x, target.y - 1),
      world:index(target.x - 1, target.y),
      world:index(target.x + 1, target.y),
      world:index(target.x, target.y + 1),
    }
    local exposed = false
    for neighbor_index = 1, 4 do
      local neighbor = neighbors[neighbor_index]
      if not neighbor or world.tile[neighbor] == Constants.TILE.SPACE then
        exposed = true
        break
      end
    end
    assert(
      exposed,
      string.format("meteor target is not exterior at %d,%d", target.x, target.y)
    )
  end
end

function Scenario.instantiate(definition, content)
  Scenario.validate(definition, content)
  local map = definition.map
  local world = World.new(map.width, map.height)
  world.map_id = definition.id
  world.areas = Stable.deep_copy(definition.areas or {})
  world.power_supply_w = definition.power_supply_w or 0

  local palette = {}
  for index = 1, #map.palette do
    palette[index] = palette_value(map.palette[index], world.areas)
  end
  local default = palette[map.default_palette or 1]
  for index = 1, world.size do
    apply_cell(world, index, default)
  end
  for run_index = 1, #(map.runs or {}) do
    local run = map.runs[run_index]
    local cell = palette[run[3]]
    for index = run[1], run[1] + run[2] - 1 do
      apply_cell(world, index, cell)
    end
  end

  local fixtures = Stable.deep_copy(definition.fixtures or {})
  table.sort(fixtures, function(a, b)
    return a.id < b.id
  end)
  for index = 1, #fixtures do
    local fixture = fixtures[index]
    fixture.index = assert(world:index(fixture.x, fixture.y))
    if fixture.kind == "generator" then
      world.generator_indices[#world.generator_indices + 1] = fixture.index
    elseif fixture.kind == "apc" then
      world.apc_indices[#world.apc_indices + 1] = {
        index = fixture.index,
        area = world.area[fixture.index],
      }
    end
  end
  local spawns = Stable.deep_copy(definition.spawns or {})
  table.sort(spawns, function(a, b)
    return a.id < b.id
  end)
  local targets = Stable.deep_copy(definition.meteor_targets or {})
  table.sort(targets, function(a, b)
    if a.y ~= b.y then
      return a.y < b.y
    end
    return a.x < b.x
  end)
  for index = 1, world.size do
    if world.structure[index] == Constants.STRUCTURE.DOOR_OPEN then
      world.open_door_indices[#world.open_door_indices + 1] = index
      world.door_close_tick[index] = Constants.DOOR_AUTO_CLOSE_TICKS
    end
  end
  validate_expanded(definition, world, fixtures, spawns, targets)
  table.sort(world.generator_indices)
  table.sort(world.apc_indices, function(a, b)
    if a.area ~= b.area then
      return a.area < b.area
    end
    return a.index < b.index
  end)
  world:step_power()

  return world, {
    fixtures = fixtures,
    spawns = spawns,
    meteor_targets = targets,
    starting_inventory = Stable.deep_copy(definition.starting_inventory or {}),
    station_name = definition.name,
    scenario_id = definition.id,
    scenario_schema = definition.schema,
    map_format = map.format,
    provenance = Stable.deep_copy(definition.provenance or {}),
  }
end

return Scenario
