local Constants = require("src.core.constants")
local Stable = require("src.core.stable")

local World = {}
World.__index = World

local FEATURE_IDS = {
  { "catwalk", Constants.FEATURE.CATWALK },
  { "chair", Constants.FEATURE.CHAIR },
  { "crate", Constants.FEATURE.CRATE },
  { "decal", Constants.FEATURE.DECAL },
  { "disposal", Constants.FEATURE.DISPOSAL },
  { "grille", Constants.FEATURE.GRILLE },
  { "lattice", Constants.FEATURE.LATTICE },
  { "light", Constants.FEATURE.LIGHT },
  { "pipe", Constants.FEATURE.PIPE },
  { "sign", Constants.FEATURE.SIGN },
  { "storage", Constants.FEATURE.STORAGE },
  { "table", Constants.FEATURE.TABLE },
  { "window", Constants.FEATURE.WINDOW },
}

local TOPOLOGY_FEATURES = {
  [Constants.FEATURE.CATWALK] = true,
  [Constants.FEATURE.CRATE] = true,
  [Constants.FEATURE.GRILLE] = true,
  [Constants.FEATURE.LATTICE] = true,
  [Constants.FEATURE.STORAGE] = true,
  [Constants.FEATURE.TABLE] = true,
  [Constants.FEATURE.WINDOW] = true,
}

local function filled_array(size, value)
  local result = {}
  for i = 1, size do
    result[i] = value
  end
  return result
end

function World.new(width, height)
  assert(width > 0 and height > 0, "world dimensions must be positive")
  local size = width * height
  local chunks_x = math.ceil(width / Constants.CHUNK_SIZE)
  local chunks_y = math.ceil(height / Constants.CHUNK_SIZE)
  return setmetatable({
    map_id = false,
    width = width,
    height = height,
    size = size,
    chunks_x = chunks_x,
    chunks_y = chunks_y,
    tile = filled_array(size, Constants.TILE.SPACE),
    turf_kind = filled_array(size, Constants.TURF.SPACE),
    structure = filled_array(size, Constants.STRUCTURE.EMPTY),
    wall_kind = filled_array(size, Constants.WALL.NONE),
    feature_mask = filled_array(size, 0),
    structure_health = filled_array(size, 0),
    structure_max_health = filled_array(size, 0),
    interaction_state = filled_array(size, false),
    cable = filled_array(size, false),
    powered = filled_array(size, false),
    blueprint = filled_array(size, false),
    o2 = filled_array(size, 0),
    n2 = filled_array(size, 0),
    co2 = filled_array(size, 0),
    plasma = filled_array(size, 0),
    n2o = filled_array(size, 0),
    vapor = filled_array(size, 0),
    temperature_mk = filled_array(size, Constants.SPACE_TEMPERATURE_MK),
    fire = filled_array(size, 0),
    dirty = filled_array(size, 0),
    area = filled_array(size, 0),
    areas = {},
    -- Authoritative pipe segments (src.core.pipes); pipelines and networks
    -- are derived. Empty worlds omit the array from snapshots so legacy
    -- state hashes are unchanged.
    pipes = {},
    gas_vented_qmol = 0,
    door_access = filled_array(size, false),
    door_close_tick = filled_array(size, 0),
    open_door_indices = {},
    chunk_revision = filled_array(chunks_x * chunks_y, 1),
    topology_revision = 1,
    gas_revision = 1,
    power_revision = 1,
    generator_indices = {},
    apc_indices = {},
    area_powered = {},
    power_supply_w = 0,
    power_demand_w = 0,
    power_served_w = 0,
    _gas_delta = {
      o2 = filled_array(size, 0),
      n2 = filled_array(size, 0),
      co2 = filled_array(size, 0),
      plasma = filled_array(size, 0),
      n2o = filled_array(size, 0),
      vapor = filled_array(size, 0),
      temperature_mk = filled_array(size, 0),
    },
  }, World)
end

function World:index(x, y)
  if x < 1 or y < 1 or x > self.width or y > self.height then
    return nil
  end
  return (y - 1) * self.width + x
end

function World:coordinates(index)
  local y = math.floor((index - 1) / self.width) + 1
  local x = index - (y - 1) * self.width
  return x, y
end

function World:chunk_index(x, y)
  local chunk_x = math.floor((x - 1) / Constants.CHUNK_SIZE) + 1
  local chunk_y = math.floor((y - 1) / Constants.CHUNK_SIZE) + 1
  return (chunk_y - 1) * self.chunks_x + chunk_x
end

function World:touch(x, y, topology)
  local chunk = self:chunk_index(x, y)
  self.chunk_revision[chunk] = self.chunk_revision[chunk] + 1
  if topology then
    self.topology_revision = self.topology_revision + 1
  end
end

function World:has_feature(index, feature)
  if not index or type(feature) ~= "number" or feature < 1 then
    return false
  end
  local mask = self.feature_mask[index] or 0
  return math.floor(mask / feature) % 2 == 1
end

function World:feature_ids(index)
  local result = {}
  for feature_index = 1, #FEATURE_IDS do
    local record = FEATURE_IDS[feature_index]
    if self:has_feature(index, record[2]) then
      result[#result + 1] = record[1]
    end
  end
  return result
end

function World:feature_is_intact(index, component)
  local state = self:peek_interaction_state(index, component)
  return not state or state.destroyed ~= true
end

function World:set_feature(index, feature, enabled)
  if not index or type(feature) ~= "number" or feature < 1 then
    return false, "invalid-feature"
  end
  local mask = self.feature_mask[index] or 0
  local present = math.floor(mask / feature) % 2 == 1
  enabled = not not enabled
  if present == enabled then
    return true, false
  end
  self.feature_mask[index] = enabled and (mask + feature) or (mask - feature)
  local x, y = self:coordinates(index)
  self:touch(x, y, TOPOLOGY_FEATURES[feature] == true)
  return true, true
end

function World:peek_interaction_state(index, component)
  local state = index and self.interaction_state[index]
  return type(state) == "table" and state[component] or nil
end

function World:ensure_interaction_state(index, component, defaults)
  assert(index and index >= 1 and index <= self.size, "invalid tile index")
  assert(type(component) == "string" and component ~= "",
    "interaction component is required")
  local state = self.interaction_state[index]
  if type(state) ~= "table" then
    state = {}
    self.interaction_state[index] = state
  end
  local value = state[component]
  if type(value) ~= "table" then
    value = Stable.deep_copy(defaults or {})
    state[component] = value
  end
  return value
end

local function wall_max_health(wall_kind)
  if wall_kind == Constants.WALL.REINFORCED then
    return 300
  elseif wall_kind == Constants.WALL.STANDARD then
    return 100
  end
  return 0
end

function World:set_wall_kind(index, wall_kind)
  if not index
    or (
      wall_kind ~= Constants.WALL.NONE
      and wall_kind ~= Constants.WALL.STANDARD
      and wall_kind ~= Constants.WALL.REINFORCED
    )
  then
    return false, "invalid-wall-kind"
  end
  self.wall_kind[index] = wall_kind
  if wall_kind == Constants.WALL.NONE then
    if self.structure[index] == Constants.STRUCTURE.WALL then
      self.structure[index] = Constants.STRUCTURE.EMPTY
    end
    self.structure_health[index] = 0
    self.structure_max_health[index] = 0
  else
    self.structure[index] = Constants.STRUCTURE.WALL
    local maximum = wall_max_health(wall_kind)
    self.structure_max_health[index] = maximum
    self.structure_health[index] = maximum
  end
  local x, y = self:coordinates(index)
  self:touch(x, y, true)
  return true
end

function World:damage_structure(index, amount, damage_type)
  if not index or index < 1 or index > self.size then
    return false, "outside-map"
  end
  if type(amount) ~= "number"
    or amount % 1 ~= 0
    or amount <= 0
    or amount > 1000000
  then
    return false, "invalid-damage"
  end
  if damage_type ~= nil
    and damage_type ~= "brute"
    and damage_type ~= "burn"
    and damage_type ~= "corrosive"
    and damage_type ~= "explosive"
  then
    return false, "invalid-damage-type"
  end
  local structure = self.structure[index]
  if structure ~= Constants.STRUCTURE.WALL
    and structure ~= Constants.STRUCTURE.DOOR_CLOSED
    and structure ~= Constants.STRUCTURE.DOOR_OPEN
  then
    return false, "not-damageable"
  end
  local maximum = self.structure_max_health[index] or 0
  if maximum <= 0 then
    if structure == Constants.STRUCTURE.WALL then
      maximum = wall_max_health(self.wall_kind[index])
    else
      maximum = 100
    end
    self.structure_max_health[index] = maximum
  end
  local current = self.structure_health[index]
  if not current or current <= 0 then
    current = maximum
  end
  current = math.max(0, current - amount)
  self.structure_health[index] = current
  local destroyed = current == 0
  if destroyed then
    self.structure[index] = Constants.STRUCTURE.EMPTY
    self.wall_kind[index] = Constants.WALL.NONE
    self.structure_max_health[index] = 0
    self.door_access[index] = false
    self.door_close_tick[index] = 0
  end
  local x, y = self:coordinates(index)
  self:touch(x, y, destroyed)
  return true, {
    damage_type = damage_type or "brute",
    destroyed = destroyed,
    health = current,
    maximum = maximum,
  }
end

function World:repair_structure(index, amount)
  if not index or index < 1 or index > self.size then
    return false, "outside-map"
  end
  if type(amount) ~= "number"
    or amount % 1 ~= 0
    or amount <= 0
    or amount > 1000000
  then
    return false, "invalid-repair"
  end
  local maximum = self.structure_max_health[index] or 0
  local current = self.structure_health[index] or 0
  if maximum <= 0 or current <= 0 or current >= maximum then
    return false, "not-repairable"
  end
  current = math.min(maximum, current + amount)
  self.structure_health[index] = current
  local x, y = self:coordinates(index)
  self:touch(x, y, false)
  return true, {
    health = current,
    maximum = maximum,
  }
end

function World:is_gas_cell(index)
  if not index or self.tile[index] ~= Constants.TILE.FLOOR then
    return false
  end
  local structure = self.structure[index]
  return structure ~= Constants.STRUCTURE.WALL
    and not (
      self:has_feature(index, Constants.FEATURE.WINDOW)
      and self:feature_is_intact(index, "window")
    )
end

function World:is_passable(index)
  if not index then
    return false
  end
  local has_walkable_surface = self.tile[index] == Constants.TILE.FLOOR
    or self:has_feature(index, Constants.FEATURE.LATTICE)
    or self:has_feature(index, Constants.FEATURE.CATWALK)
  if not has_walkable_surface then
    return false
  end
  if self.structure[index] == Constants.STRUCTURE.WALL
    or self.structure[index] == Constants.STRUCTURE.DOOR_CLOSED
  then
    return false
  end
  if self:has_feature(index, Constants.FEATURE.WINDOW)
    and self:feature_is_intact(index, "window")
  then
    return false
  end
  return not (
      self:has_feature(index, Constants.FEATURE.GRILLE)
      and self:feature_is_intact(index, "grille")
    )
    and not self:has_feature(index, Constants.FEATURE.TABLE)
    and not self:has_feature(index, Constants.FEATURE.STORAGE)
    and not self:has_feature(index, Constants.FEATURE.CRATE)
end

function World:pressure_dkpa(index)
  local total = self.o2[index]
    + self.n2[index]
    + self.co2[index]
    + self.plasma[index]
    + self.n2o[index]
    + self.vapor[index]
  return math.floor(total / 100)
end

function World:seed_starting_core(center_x, center_y, half_width, half_height)
  local min_x = center_x - half_width
  local max_x = center_x + half_width
  local min_y = center_y - half_height
  local max_y = center_y + half_height

  for y = min_y, max_y do
    for x = min_x, max_x do
      local index = assert(self:index(x, y))
      self.tile[index] = Constants.TILE.FLOOR
      self.turf_kind[index] = Constants.TURF.FLOOR
      local perimeter = x == min_x or x == max_x or y == min_y or y == max_y
      self.structure[index] = perimeter and Constants.STRUCTURE.WALL
        or Constants.STRUCTURE.EMPTY
      self.wall_kind[index] = perimeter and Constants.WALL.STANDARD
        or Constants.WALL.NONE
      if perimeter then
        self.structure_health[index] = 100
        self.structure_max_health[index] = 100
      end
      self.temperature_mk[index] = Constants.STANDARD_TEMPERATURE_MK
      if not perimeter then
        self.o2[index] = Constants.STANDARD_O2
        self.n2[index] = Constants.STANDARD_N2
        self.cable[index] = true
      end
      self:touch(x, y, true)
    end
  end

  local doors = {
    { center_x, min_y },
    { center_x, max_y },
    { min_x, center_y },
    { max_x, center_y },
  }
  for i = 1, #doors do
    local x, y = doors[i][1], doors[i][2]
    local index = assert(self:index(x, y))
    self.structure[index] = Constants.STRUCTURE.DOOR_CLOSED
    self.wall_kind[index] = Constants.WALL.NONE
    self.structure_health[index] = 100
    self.structure_max_health[index] = 100
    self.o2[index] = Constants.STANDARD_O2
    self.n2[index] = Constants.STANDARD_N2
    self.cable[index] = true
    self:touch(x, y, true)
  end

  local generator = assert(self:index(center_x, center_y))
  self.generator_indices[1] = generator
  self.power_supply_w = 250000
end

function World:set_blueprint(x, y, kind)
  local index = self:index(x, y)
  if not index then
    return false, "outside map"
  end
  if kind == Constants.BLUEPRINT.FLOOR then
    if self.tile[index] == Constants.TILE.FLOOR then
      return false, "tile already has a floor"
    end
  elseif kind == Constants.BLUEPRINT.WALL then
    if self.tile[index] ~= Constants.TILE.FLOOR
      or self.structure[index] ~= Constants.STRUCTURE.EMPTY
    then
      return false, "wall requires an empty floor"
    end
  elseif kind == Constants.BLUEPRINT.DOOR then
    if self.tile[index] ~= Constants.TILE.FLOOR
      or self.structure[index] ~= Constants.STRUCTURE.EMPTY
    then
      return false, "door requires an empty floor"
    end
  elseif kind == Constants.BLUEPRINT.CABLE then
    if self.tile[index] ~= Constants.TILE.FLOOR or self.cable[index] then
      return false, "cable requires an uncabled floor"
    end
  else
    return false, "unknown blueprint"
  end
  if self.blueprint[index] then
    return false, "tile already has a blueprint"
  end
  self.blueprint[index] = kind
  self:touch(x, y, false)
  return true, index
end

function World:complete_blueprint(index)
  local kind = self.blueprint[index]
  if not kind then
    return false
  end
  local x, y = self:coordinates(index)
  if kind == Constants.BLUEPRINT.FLOOR then
    self.tile[index] = Constants.TILE.FLOOR
    self.turf_kind[index] = Constants.TURF.FLOOR
    self.structure[index] = Constants.STRUCTURE.EMPTY
    self.wall_kind[index] = Constants.WALL.NONE
    self.temperature_mk[index] = Constants.SPACE_TEMPERATURE_MK
  elseif kind == Constants.BLUEPRINT.WALL then
    self.structure[index] = Constants.STRUCTURE.WALL
    self.wall_kind[index] = Constants.WALL.STANDARD
    self.structure_health[index] = 100
    self.structure_max_health[index] = 100
  elseif kind == Constants.BLUEPRINT.DOOR then
    self.structure[index] = Constants.STRUCTURE.DOOR_CLOSED
    self.wall_kind[index] = Constants.WALL.NONE
    self.structure_health[index] = 100
    self.structure_max_health[index] = 100
  elseif kind == Constants.BLUEPRINT.CABLE then
    self.cable[index] = true
  end
  self.blueprint[index] = false
  self:touch(x, y, true)
  return true, kind
end

function World:make_breach(x, y)
  local index = self:index(x, y)
  if not index or self.tile[index] ~= Constants.TILE.FLOOR then
    return false
  end
  self.structure[index] = Constants.STRUCTURE.EMPTY
  self.wall_kind[index] = Constants.WALL.NONE
  self.structure_health[index] = 0
  self.structure_max_health[index] = 0
  self:touch(x, y, true)
  return true
end

function World:area_record(index)
  local area_id = index and self.area[index] or 0
  return area_id and area_id > 0 and self.areas[area_id] or nil
end

local function has_access(credentials, required)
  if not required or required == "public" then
    return true
  end
  if credentials == "override" then
    return true
  end
  for index = 1, #(credentials or {}) do
    if credentials[index] == required or credentials[index] == "all" then
      return true
    end
  end
  return false
end

function World:can_open_door(index, credentials, override)
  local structure = index and self.structure[index]
  if structure ~= Constants.STRUCTURE.DOOR_CLOSED
    and structure ~= Constants.STRUCTURE.DOOR_OPEN
  then
    return false, "tile is not a door"
  end
  if not override and not self.powered[index] then
    return false, "door has no power"
  end
  if not override and not has_access(credentials, self.door_access[index]) then
    return false, "access denied"
  end
  return true
end

function World:open_door(index, current_tick, credentials, override)
  local allowed, reason = self:can_open_door(index, credentials, override)
  if not allowed then
    return false, reason
  end
  if self.structure[index] == Constants.STRUCTURE.DOOR_CLOSED then
    self.structure[index] = Constants.STRUCTURE.DOOR_OPEN
    local x, y = self:coordinates(index)
    self:touch(x, y, false)
  end
  if self.door_close_tick[index] == 0 then
    self.open_door_indices[#self.open_door_indices + 1] = index
    table.sort(self.open_door_indices)
  end
  self.door_close_tick[index] =
    current_tick + Constants.DOOR_AUTO_CLOSE_TICKS
  return true
end

function World:close_door(index)
  if self.structure[index] ~= Constants.STRUCTURE.DOOR_OPEN then
    return false, "door is not open"
  end
  self.structure[index] = Constants.STRUCTURE.DOOR_CLOSED
  self.door_close_tick[index] = 0
  local x, y = self:coordinates(index)
  self:touch(x, y, false)
  return true
end

function World:step_doors(current_tick, occupied)
  local write = 1
  for read = 1, #self.open_door_indices do
    local index = self.open_door_indices[read]
    local keep = self.structure[index] == Constants.STRUCTURE.DOOR_OPEN
    if keep and self.door_close_tick[index] <= current_tick then
      if occupied[index] then
        self.door_close_tick[index] = current_tick + 10
      else
        self:close_door(index)
        keep = false
      end
    end
    if keep then
      self.open_door_indices[write] = index
      write = write + 1
    end
  end
  for index = #self.open_door_indices, write, -1 do
    self.open_door_indices[index] = nil
  end
end

local GAS_KEYS = { "o2", "n2", "co2", "plasma", "n2o", "vapor" }

local function transfer_species(world, source, target, key, divisor)
  local values = world[key]
  local delta = world._gas_delta[key]
  local difference = values[source] - values[target]
  if difference > 1 then
    local amount = math.floor(difference / divisor)
    delta[source] = delta[source] - amount
    delta[target] = delta[target] + amount
  elseif difference < -1 then
    local amount = math.floor((-difference) / divisor)
    delta[source] = delta[source] + amount
    delta[target] = delta[target] - amount
  end
end

local function vent_species(world, source, key, divisor)
  local values = world[key]
  local amount = math.floor(values[source] / divisor)
  world._gas_delta[key][source] = world._gas_delta[key][source] - amount
end

function World:step_atmosphere()
  local size = self.size
  for key_index = 1, #GAS_KEYS do
    local delta = self._gas_delta[GAS_KEYS[key_index]]
    for i = 1, size do
      delta[i] = 0
    end
  end

  local width = self.width
  for y = 1, self.height do
    for x = 1, width do
      local source = (y - 1) * width + x
      if self:is_gas_cell(source)
        and self.structure[source] ~= Constants.STRUCTURE.DOOR_CLOSED
      then
        local right = x < width and source + 1 or nil
        local down = y < self.height and source + width or nil
        local neighbors = { right, down }
        for n = 1, 2 do
          local target = neighbors[n]
          if target then
            if self:is_gas_cell(target)
              and self.structure[target] ~= Constants.STRUCTURE.DOOR_CLOSED
            then
              for key_index = 1, #GAS_KEYS do
                transfer_species(self, source, target, GAS_KEYS[key_index], 4)
              end
            elseif self.tile[target] == Constants.TILE.SPACE then
              for key_index = 1, #GAS_KEYS do
                vent_species(self, source, GAS_KEYS[key_index], 3)
              end
            end
          else
            for key_index = 1, #GAS_KEYS do
              vent_species(self, source, GAS_KEYS[key_index], 3)
            end
          end
        end
        -- Space on the left or above is not visited as a source edge, so vent
        -- those boundaries explicitly. Right/down space is handled above.
        local left = x > 1 and source - 1 or nil
        local up = y > 1 and source - width or nil
        if not left or self.tile[left] == Constants.TILE.SPACE then
          for key_index = 1, #GAS_KEYS do
            vent_species(self, source, GAS_KEYS[key_index], 3)
          end
        end
        if not up or self.tile[up] == Constants.TILE.SPACE then
          for key_index = 1, #GAS_KEYS do
            vent_species(self, source, GAS_KEYS[key_index], 3)
          end
        end
      end
    end
  end

  for key_index = 1, #GAS_KEYS do
    local key = GAS_KEYS[key_index]
    local values = self[key]
    local delta = self._gas_delta[key]
    for i = 1, size do
      local next_value = values[i] + delta[i]
      values[i] = next_value < 0 and 0 or next_value
    end
  end

  -- Fire consumes oxygen, produces carbon dioxide, and heats its tile.
  for i = 1, size do
    local intensity = self.fire[i]
    if intensity > 0 then
      local consumed = math.min(self.o2[i], intensity * 80)
      self.o2[i] = self.o2[i] - consumed
      self.co2[i] = self.co2[i] + math.floor(consumed * 3 / 4)
      self.temperature_mk[i] = self.temperature_mk[i] + intensity * 120
      if consumed < intensity * 20 then
        self.fire[i] = math.max(0, intensity - 1)
      end
    end
  end

  self.gas_revision = self.gas_revision + 1
end

function World:step_power()
  local visited = filled_array(self.size, false)
  local queue = {}
  local head = 1
  for i = 1, #self.generator_indices do
    local index = self.generator_indices[i]
    if self.cable[index] then
      visited[index] = true
      queue[#queue + 1] = index
    end
  end

  while head <= #queue do
    local index = queue[head]
    head = head + 1
    local x, y = self:coordinates(index)
    local candidates = {
      self:index(x + 1, y),
      self:index(x - 1, y),
      self:index(x, y + 1),
      self:index(x, y - 1),
    }
    for i = 1, 4 do
      local neighbor = candidates[i]
      if neighbor and self.cable[neighbor] and not visited[neighbor] then
        visited[neighbor] = true
        queue[#queue + 1] = neighbor
      end
    end
  end

  local area_powered = {}
  for area_id = 1, #self.areas do
    area_powered[area_id] = false
  end
  for apc_index = 1, #self.apc_indices do
    local apc = self.apc_indices[apc_index]
    local connected = visited[apc.index]
    if not connected then
      local x, y = self:coordinates(apc.index)
      local neighbors = {
        self:index(x, y - 1),
        self:index(x - 1, y),
        self:index(x + 1, y),
        self:index(x, y + 1),
      }
      for neighbor_index = 1, 4 do
        local neighbor = neighbors[neighbor_index]
        if neighbor and visited[neighbor] then
          connected = true
          break
        end
      end
    end
    if connected and apc.area > 0 then
      area_powered[apc.area] = true
    end
  end
  self.area_powered = area_powered

  local demand = 0
  for i = 1, self.size do
    local area_id = self.area[i]
    self.powered[i] = visited[i]
      or (area_id > 0 and area_powered[area_id] == true)
    if self.powered[i] then
      if self.tile[i] == Constants.TILE.FLOOR then
        demand = demand + 25
      end
    end
  end
  self.power_demand_w = demand
  self.power_served_w = math.min(demand, self.power_supply_w)
  self.power_revision = self.power_revision + 1
end

function World:snapshot()
  return {
    map_id = self.map_id,
    width = self.width,
    height = self.height,
    tile = self.tile,
    turf_kind = self.turf_kind,
    structure = self.structure,
    wall_kind = self.wall_kind,
    feature_mask = self.feature_mask,
    structure_health = self.structure_health,
    structure_max_health = self.structure_max_health,
    interaction_state = self.interaction_state,
    cable = self.cable,
    powered = self.powered,
    blueprint = self.blueprint,
    o2 = self.o2,
    n2 = self.n2,
    co2 = self.co2,
    plasma = self.plasma,
    n2o = self.n2o,
    vapor = self.vapor,
    temperature_mk = self.temperature_mk,
    fire = self.fire,
    dirty = self.dirty,
    area = self.area,
    areas = self.areas,
    pipes = #self.pipes > 0 and self.pipes or nil,
    gas_vented_qmol = self.gas_vented_qmol ~= 0 and self.gas_vented_qmol
      or nil,
    door_access = self.door_access,
    door_close_tick = self.door_close_tick,
    open_door_indices = self.open_door_indices,
    chunk_revision = self.chunk_revision,
    topology_revision = self.topology_revision,
    gas_revision = self.gas_revision,
    power_revision = self.power_revision,
    generator_indices = self.generator_indices,
    apc_indices = self.apc_indices,
    area_powered = self.area_powered,
    power_supply_w = self.power_supply_w,
    power_demand_w = self.power_demand_w,
    power_served_w = self.power_served_w,
  }
end

function World.from_snapshot(snapshot)
  local world = World.new(snapshot.width, snapshot.height)
  local keys = {
    "tile",
    "turf_kind",
    "structure",
    "wall_kind",
    "feature_mask",
    "structure_health",
    "structure_max_health",
    "interaction_state",
    "cable",
    "powered",
    "blueprint",
    "o2",
    "n2",
    "co2",
    "plasma",
    "n2o",
    "vapor",
    "temperature_mk",
    "fire",
    "dirty",
    "area",
    "pipes",
    "door_access",
    "door_close_tick",
    "open_door_indices",
    "chunk_revision",
    "generator_indices",
    "apc_indices",
  }
  for i = 1, #keys do
    local key = keys[i]
    if snapshot[key] ~= nil then
      world[key] = Stable.deep_copy(snapshot[key])
    end
  end
  world.map_id = snapshot.map_id or false
  world.gas_vented_qmol = snapshot.gas_vented_qmol or 0
  world.areas = Stable.deep_copy(snapshot.areas or {})
  world.area_powered = Stable.deep_copy(snapshot.area_powered or {})
  world.topology_revision = snapshot.topology_revision
  world.gas_revision = snapshot.gas_revision
  world.power_revision = snapshot.power_revision
  world.power_supply_w = snapshot.power_supply_w
  world.power_demand_w = snapshot.power_demand_w
  world.power_served_w = snapshot.power_served_w
  if snapshot.turf_kind == nil then
    for index = 1, world.size do
      world.turf_kind[index] = world.tile[index] == Constants.TILE.FLOOR
          and Constants.TURF.FLOOR
        or Constants.TURF.SPACE
      if world.structure[index] == Constants.STRUCTURE.WALL then
        world.wall_kind[index] = Constants.WALL.STANDARD
        world.structure_health[index] = 100
        world.structure_max_health[index] = 100
      elseif world.structure[index] == Constants.STRUCTURE.DOOR_CLOSED
        or world.structure[index] == Constants.STRUCTURE.DOOR_OPEN
      then
        world.structure_health[index] = 100
        world.structure_max_health[index] = 100
      end
    end
  end
  return world
end

return World
