-- Goon-compatible pipe topology and pipe-network gas solve pinned to
-- goonstation/goonstation commit 1b2b250abb5be747d55e274de0203a59cfc8da78.
--
-- Authoritative state lives in world.pipes: one record per pipe segment
-- {id, index, x, y, kind, dir, gas} where gas is a src.core.gas mixture and
-- carries the segment volume. Pipelines (connected segment runs) and
-- networks (pipelines plus attached machine port mixtures) are derived and
-- rebuilt deterministically; they are never saved.
--
-- Directions use the BYOND bitfield (NORTH=1, SOUTH=2, EAST=4, WEST=8;
-- diagonals are their unions). NORTH maps to screen-up (y - 1); the Atlas
-- importer must keep pipe dirs in the same frame it uses for fixtures.
local Constants = require("src.core.constants")
local Stable = require("src.core.stable")
local Gas = require("src.core.gas")

local Pipes = {}

-- code/modules/atmospherics/machinery/pipe.dm:300 (simple 70 L), :610
-- (manifold 105 L), :728 (quadway 140 L), :549 (vertical 250 L). Insulated,
-- junction, and heat-exchanging pipes are simple subtypes and keep 70 L.
Pipes.KIND_VOLUME_L = {
  simple = 70,
  heat_exchanging = 70,
  insulated = 70,
  insulated_cold = 70,
  junction = 70,
  manifold = 105,
  quadway = 140,
  vertical = 250,
}

-- Environment heat exchange per pipe kind: pipe.dm:305-308 (simple: wall
-- coefficient 0.12, minimum delta 300 K), :526-534 (heat exchanging: window
-- coefficient 0.18, minimum delta 20 K), :491-497 (insulated: none).
-- Manifolds, quadways, and verticals define no environment process.
local EXCHANGE = {
  simple = { conductivity = 0.12, minimum_delta_mk = 300000 },
  junction = { conductivity = 0.12, minimum_delta_mk = 300000 },
  heat_exchanging = { conductivity = 0.18, minimum_delta_mk = 20000 },
}

-- Kinds whose exposed ends mingle with their turf (pipe.dm:345-351 simple
-- subtypes including junction/insulated/heat-exchanging, :640-644 manifold,
-- :804+ quadway). Verticals connect z-levels and never mingle here.
local MINGLES = {
  simple = true,
  heat_exchanging = true,
  insulated = true,
  insulated_cold = true,
  junction = true,
  manifold = true,
  quadway = true,
}

local NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
local DIR_LIST = { NORTH, SOUTH, EAST, WEST }
local OPPOSITE = { [NORTH] = SOUTH, [SOUTH] = NORTH, [EAST] = WEST, [WEST] = EAST }
local DIR_DX = { [NORTH] = 0, [SOUTH] = 0, [EAST] = 1, [WEST] = -1 }
local DIR_DY = { [NORTH] = -1, [SOUTH] = 1, [EAST] = 0, [WEST] = 0 }
-- BYOND turn(dir, 90) is counterclockwise.
local TURN_CCW = { [NORTH] = WEST, [WEST] = SOUTH, [SOUTH] = EAST, [EAST] = NORTH }
local TURN_CW = { [NORTH] = EAST, [EAST] = SOUTH, [SOUTH] = WEST, [WEST] = NORTH }

Pipes.OPPOSITE = OPPOSITE
Pipes.TURN_CCW = TURN_CCW
Pipes.TURN_CW = TURN_CW

local SIMPLE_CLASS = {
  simple = true,
  heat_exchanging = true,
  insulated = true,
  insulated_cold = true,
  junction = true,
}

-- initialize_directions per kind: pipe.dm:314-320 (simple: cardinal dir
-- expands to its axis, diagonal keeps its two components), :622 (manifold:
-- all four except dir), :740 (quadway: all four), :555 (vertical: dir).
function Pipes.connect_bits(kind, dir)
  if kind == "manifold" then
    return 15 - dir
  elseif kind == "quadway" then
    return 15
  elseif kind == "vertical" then
    return dir
  end
  assert(SIMPLE_CLASS[kind], "unknown pipe kind: " .. tostring(kind))
  if dir == NORTH or dir == SOUTH then
    return NORTH + SOUTH
  elseif dir == EAST or dir == WEST then
    return EAST + WEST
  end
  return dir
end

local function has_bit(bits, bit)
  return math.floor(bits / bit) % 2 == 1
end

-- cant_connect gates, pipe.dm:520-524 (junction: heat-exchanging pipes only
-- on the dir side, everything else only on the opposite side) and :539-541
-- (heat-exchanging: only heat-exchanging pipes or junctions). `incoming` is
-- the direction from the other object toward `kind`'s tile, matching the DM
-- get_dir(other, src) convention.
local function accepts(kind, dir, other_kind, incoming)
  if kind == "junction" then
    if other_kind == "heat_exchanging" then
      return incoming ~= dir
    end
    return incoming == dir
  elseif kind == "heat_exchanging" then
    return other_kind == "heat_exchanging" or other_kind == "junction"
  end
  return true
end

local function segment_accepts(segment, other_kind, incoming)
  return accepts(segment.kind, segment.dir, other_kind, incoming)
end

local PORT_SIDES = {
  dir = function(dir) return dir end,
  opposite = function(dir) return OPPOSITE[dir] end,
  ccw = function(dir) return TURN_CCW[dir] end,
  cw = function(dir) return TURN_CW[dir] end,
}

local function port_direction(machine, port)
  local dir = machine.data and machine.data.dir or NORTH
  local resolve = PORT_SIDES[port.side or "dir"]
  assert(resolve, "unknown gas port side: " .. tostring(port.side))
  return resolve(dir)
end

Pipes.port_direction = port_direction

local function find_root(parents, key)
  while parents[key] ~= key do
    parents[key] = parents[parents[key]]
    key = parents[key]
  end
  return key
end

local function union(parents, a, b)
  local root_a = find_root(parents, a)
  local root_b = find_root(parents, b)
  if root_a == root_b then
    return
  end
  -- Deterministic: the lexicographically smaller root wins.
  if root_a < root_b then
    parents[root_b] = root_a
  else
    parents[root_a] = root_b
  end
end

local function topology_signature(simulation)
  local world = simulation.world
  local parts = {
    tostring(world.topology_revision),
    tostring(#(world.pipes or {})),
  }
  local machines = Stable.sorted_values_by_id(simulation.machines or {})
  for index = 1, #machines do
    local machine = machines[index]
    local data = machine.data
    if data and data.gas_ports then
      parts[#parts + 1] = table.concat({
        machine.id,
        tostring(data.dir or NORTH),
        tostring(#data.gas_ports),
        data.gas_bridge == true and "b" or "-",
      }, ":")
    end
  end
  return table.concat(parts, "|")
end

local function build_topology(simulation)
  local world = simulation.world
  local segments = {}
  for index = 1, #(world.pipes or {}) do
    segments[index] = world.pipes[index]
  end
  table.sort(segments, function(a, b)
    return a.id < b.id
  end)

  local by_tile = {}
  for index = 1, #segments do
    local segment = segments[index]
    local bucket = by_tile[segment.index]
    if not bucket then
      bucket = {}
      by_tile[segment.index] = bucket
    end
    bucket[#bucket + 1] = segment
  end

  -- Union pipe segments into pipelines. Mirrors simple/initialize
  -- (pipe.dm:405-431): for each connect direction pick the first object on
  -- the stepped tile that faces back and passes both cant_connect gates.
  local parents = {}
  for index = 1, #segments do
    parents[segments[index].id] = segments[index].id
  end
  local linked = {}
  for index = 1, #segments do
    local segment = segments[index]
    local bits = Pipes.connect_bits(segment.kind, segment.dir)
    for dir_index = 1, #DIR_LIST do
      local dir = DIR_LIST[dir_index]
      if has_bit(bits, dir) then
        local nx = segment.x + DIR_DX[dir]
        local ny = segment.y + DIR_DY[dir]
        local neighbor_index = world:index(nx, ny)
        local partner = nil
        local bucket = neighbor_index and by_tile[neighbor_index]
        if bucket then
          for candidate_index = 1, #bucket do
            local candidate = bucket[candidate_index]
            local candidate_bits =
              Pipes.connect_bits(candidate.kind, candidate.dir)
            if has_bit(candidate_bits, OPPOSITE[dir])
              and segment_accepts(segment, candidate.kind, OPPOSITE[dir])
              and segment_accepts(candidate, segment.kind, dir)
            then
              partner = candidate
              break
            end
          end
        end
        if partner then
          union(parents, segment.id, partner.id)
          linked[segment.id .. ":" .. dir] = true
        end
      end
    end
  end

  -- Machine gas ports join the pipeline component their facing tile offers,
  -- or pair directly with an opposing machine port (machines are valid
  -- atmospherics targets in the source initialize walk).
  local ports = {}
  local port_by_slot = {}
  local machines = Stable.sorted_values_by_id(simulation.machines or {})
  for index = 1, #machines do
    local machine = machines[index]
    local data = machine.data
    if data and data.gas_ports and not machine.destroyed then
      for port_index = 1, #data.gas_ports do
        local declared = data.gas_ports[port_index]
        local dir = port_direction(machine, declared)
        local port = {
          machine_id = machine.id,
          machine = machine,
          key = declared.key,
          dir = dir,
          node_id = "port/" .. machine.id .. "/" .. declared.key,
        }
        ports[#ports + 1] = port
        local nx = machine.x + DIR_DX[dir]
        local ny = machine.y + DIR_DY[dir]
        local neighbor_index = world:index(nx, ny)
        if neighbor_index then
          -- Keyed by (target tile, opposite of the port's facing): the slot
          -- a matching pipe end or opposing port would look up.
          port_by_slot[neighbor_index .. ":" .. OPPOSITE[dir]] = port
          port.target_index = neighbor_index
        end
      end
    end
  end
  for index = 1, #ports do
    local port = ports[index]
    parents[port.node_id] = port.node_id
  end
  for index = 1, #ports do
    local port = ports[index]
    local machine = port.machine
    local nx = machine.x + DIR_DX[port.dir]
    local ny = machine.y + DIR_DY[port.dir]
    local neighbor_index = world:index(nx, ny)
    if neighbor_index then
      local partner = nil
      local bucket = by_tile[neighbor_index]
      if bucket then
        for candidate_index = 1, #bucket do
          local candidate = bucket[candidate_index]
          local candidate_bits =
            Pipes.connect_bits(candidate.kind, candidate.dir)
          if has_bit(candidate_bits, OPPOSITE[port.dir])
            and segment_accepts(candidate, "machine", port.dir)
          then
            partner = candidate.id
            break
          end
        end
      end
      if not partner then
        -- An opposing port on the neighbor tile faces back at this machine,
        -- so its slot key is (this machine's tile, this port's facing).
        local facing = port_by_slot[machine.index .. ":" .. port.dir]
        if facing and facing.node_id ~= port.node_id
          and facing.machine.index == neighbor_index
        then
          partner = facing.node_id
        end
      end
      if partner then
        union(parents, port.node_id, partner)
        port.connected = true
      end
    end
  end

  -- Bridging machines (open valves) merge every network their ports touch.
  for index = 1, #machines do
    local machine = machines[index]
    local data = machine.data
    if data and data.gas_ports and data.gas_bridge == true
      and not machine.destroyed
    then
      local first = nil
      for port_index = 1, #data.gas_ports do
        local node_id = "port/" .. machine.id .. "/"
          .. data.gas_ports[port_index].key
        if first then
          union(parents, first, node_id)
        else
          first = node_id
        end
      end
    end
  end

  -- Collect pipelines (components restricted to segments).
  local pipeline_by_root = {}
  local pipelines = {}
  for index = 1, #segments do
    local segment = segments[index]
    local root = find_root(parents, segment.id)
    local pipeline = pipeline_by_root[root]
    if not pipeline then
      pipeline = { id = segment.id, segments = {}, volume_l = 0 }
      pipeline_by_root[root] = pipeline
      pipelines[#pipelines + 1] = pipeline
    end
    if segment.id < pipeline.id then
      pipeline.id = segment.id
    end
    pipeline.segments[#pipeline.segments + 1] = segment
    pipeline.volume_l = pipeline.volume_l + segment.gas.volume_l
  end
  table.sort(pipelines, function(a, b)
    return a.id < b.id
  end)

  -- Collect networks: every component holding at least one pipeline or at
  -- least two connected ports equalizes; an isolated port does not (a
  -- nodeless machine keeps a nil network in the source).
  local network_by_root = {}
  local networks = {}
  local function network_for(root)
    local network = network_by_root[root]
    if not network then
      network = {
        id = nil,
        pipelines = {},
        ports = {},
        update = true,
      }
      network_by_root[root] = network
      networks[#networks + 1] = network
    end
    return network
  end
  for index = 1, #pipelines do
    local pipeline = pipelines[index]
    local root = find_root(parents, pipeline.id)
    local network = network_for(root)
    network.pipelines[#network.pipelines + 1] = pipeline
    if network.id == nil or pipeline.id < network.id then
      network.id = pipeline.id
    end
  end
  for index = 1, #ports do
    local port = ports[index]
    local root = find_root(parents, port.node_id)
    local network = network_by_root[root]
    if not network and port.connected then
      network = network_for(root)
    end
    if network then
      network.ports[#network.ports + 1] = port
      if network.id == nil or port.node_id < network.id then
        network.id = port.node_id
      end
    end
  end
  local kept = {}
  for index = 1, #networks do
    local network = networks[index]
    if #network.pipelines > 0 or #network.ports > 1 then
      kept[#kept + 1] = network
    end
  end
  networks = kept
  table.sort(networks, function(a, b)
    return a.id < b.id
  end)

  local exposed = {}
  for index = 1, #segments do
    local segment = segments[index]
    local bits = Pipes.connect_bits(segment.kind, segment.dir)
    local open = false
    for dir_index = 1, #DIR_LIST do
      local dir = DIR_LIST[dir_index]
      if has_bit(bits, dir) and not linked[segment.id .. ":" .. dir] then
        -- A machine port on the stepped tile facing back covers this end;
        -- its slot key is (this segment's tile, this direction).
        local port = port_by_slot[segment.index .. ":" .. dir]
        if not (port and port.connected
          and port.target_index == segment.index) then
          open = true
        end
      end
    end
    exposed[segment.id] = open
  end

  return {
    segments = segments,
    pipelines = pipelines,
    networks = networks,
    exposed = exposed,
  }
end

local function ensure_topology(simulation)
  local signature = topology_signature(simulation)
  local cache = simulation._pipe_topology
  if cache and cache.signature == signature then
    return cache.topology
  end
  local topology = build_topology(simulation)
  simulation._pipe_topology = {
    signature = signature,
    topology = topology,
  }
  return topology
end

Pipes.ensure_topology = ensure_topology

-- Drops the derived cache; families call this after changing bridge state
-- (for example opening a valve) so the next solve rebuilds and reconciles.
function Pipes.invalidate(simulation)
  simulation._pipe_topology = nil
end

-- Marks the network containing the machine's ports for reconciliation.
function Pipes.mark_machine(simulation, machine)
  local cache = simulation._pipe_topology
  if not cache then
    return
  end
  local networks = cache.topology.networks
  for index = 1, #networks do
    local network = networks[index]
    for port_index = 1, #network.ports do
      if network.ports[port_index].machine_id == machine.id then
        network.update = true
      end
    end
  end
end

local TILE_SPECIES = {
  oxygen = "o2",
  nitrogen = "n2",
  carbon_dioxide = "co2",
  toxins = "plasma",
  nitrous_oxide = "n2o",
}

-- A pipe-facing view of a tile's legacy gas arrays (1 unit = 10 qmol,
-- 2500 L cell). Only the five mapped species move through the adapter;
-- farts, fallout, and oxygen agent B stay pipe-side and legacy vapor stays
-- tile-side (engine-adapted, recorded in the ledger).
local TILE_SPECIES_SET = {
  oxygen = true,
  nitrogen = true,
  carbon_dioxide = true,
  toxins = true,
  nitrous_oxide = true,
}

local function tile_view(world, index)
  local view = Gas.new(Gas.CELL_VOLUME_L, world.temperature_mk[index])
  for species, key in pairs(TILE_SPECIES) do
    view[species] = world[key][index] * Gas.TILE_UNIT_QMOL
  end
  return view
end

local function write_tile(world, index, view)
  local changed = false
  for species, key in pairs(TILE_SPECIES) do
    local units = view[species] / Gas.TILE_UNIT_QMOL
    assert(units % 1 == 0, "tile share must respect unit granularity")
    if world[key][index] ~= units then
      world[key][index] = units
      changed = true
    end
  end
  if world.temperature_mk[index] ~= view.temperature_mk then
    world.temperature_mk[index] = view.temperature_mk
    changed = true
  end
  return changed
end

local function network_members(network)
  local members = {}
  for pipeline_index = 1, #network.pipelines do
    local pipeline = network.pipelines[pipeline_index]
    for segment_index = 1, #pipeline.segments do
      members[#members + 1] = {
        gas = pipeline.segments[segment_index].gas,
      }
    end
  end
  local ports = {}
  for index = 1, #network.ports do
    ports[#ports + 1] = network.ports[index]
  end
  table.sort(ports, function(a, b)
    return a.node_id < b.node_id
  end)
  for index = 1, #ports do
    local port = ports[index]
    local gas = port.machine.data[port.key]
    if type(gas) == "table" then
      members[#members + 1] = { gas = gas }
    end
  end
  return members
end

-- pipe_network.dm:111-149: pool every member mixture, react the pooled
-- transient, then redistribute by volume ratio.
local function reconcile(network)
  local members = network_members(network)
  if #members == 0 then
    return false
  end
  local pooled = Gas.pool(members)
  if pooled.volume_l <= 0 then
    return false
  end
  if Gas.react(pooled, 1) then
    network.update = true
  end
  Gas.distribute(pooled, members)
  return true
end

-- pipeline.dm:191-261 adapted to the tile model: space turfs are the
-- unsimulated branch (2.7 K, 700 kJ/K, turf unchanged); gas cells exchange
-- symmetrically with tile air; other turfs are treated as insulated.
local function exchange_segment(simulation, network, pipeline, segment)
  local exchange = EXCHANGE[segment.kind]
  if not exchange then
    return
  end
  local world = simulation.world
  local index = segment.index
  local is_space = world.tile[index] == Constants.TILE.SPACE
  local is_cell = world:is_gas_cell(index)
  if not is_space and not is_cell then
    return
  end

  local total_capacity = 0
  local total_energy = 0
  for segment_index = 1, #pipeline.segments do
    local gas = pipeline.segments[segment_index].gas
    local capacity = Gas.heat_capacity_hcq(gas)
    total_capacity = total_capacity + capacity
    total_energy = total_energy + gas.temperature_mk * capacity
  end
  if total_capacity <= 0 then
    return
  end
  local pipe_temperature = math.floor(total_energy / total_capacity)

  local env_temperature
  local env_capacity
  local view
  if is_space then
    env_temperature = Gas.SPACE_TEMPERATURE_MK
    env_capacity = Gas.SPACE_HEAT_CAPACITY_HCQ
  else
    view = tile_view(world, index)
    env_temperature = view.temperature_mk
    env_capacity = Gas.heat_capacity_hcq(view)
    if env_capacity <= 0 then
      return
    end
  end

  local delta = env_temperature - pipe_temperature
  if delta <= exchange.minimum_delta_mk and delta >= -exchange.minimum_delta_mk then
    return
  end

  local partial_capacity = total_capacity
    * (segment.gas.volume_l / pipeline.volume_l)
  if partial_capacity <= 0 then
    return
  end
  local heat = exchange.conductivity * (pipe_temperature - env_temperature)
    * (partial_capacity * env_capacity / (partial_capacity + env_capacity))
  local pipe_delta = heat / total_capacity
  local applied = pipe_delta >= 0 and math.floor(pipe_delta)
    or -math.floor(-pipe_delta)
  if applied ~= 0 then
    for segment_index = 1, #pipeline.segments do
      local gas = pipeline.segments[segment_index].gas
      gas.temperature_mk = gas.temperature_mk - applied
    end
    network.update = true
  end
  if not is_space then
    local env_delta = heat / env_capacity
    local env_applied = env_delta >= 0 and math.floor(env_delta)
      or -math.floor(-env_delta)
    if env_applied ~= 0 then
      world.temperature_mk[index] = world.temperature_mk[index] + env_applied
      simulation._pipe_tile_changed = true
    end
  end
end

-- pipeline.dm:143-190 mingle_with_turf adapted per segment: after a
-- reconcile every segment holds exactly the pipeline's volume-proportional
-- sample, so equalizing the segment's own gas against the tile matches the
-- source's remove_ratio sample. Space tiles receive their share into the
-- void and the loss is counted in world.gas_vented_qmol.
local function mingle_segment(simulation, network, segment)
  local world = simulation.world
  local index = segment.index
  if world.tile[index] == Constants.TILE.SPACE then
    local gas = segment.gas
    local total_volume = gas.volume_l + Gas.CELL_VOLUME_L
    local vented = 0
    for species_index = 1, #Gas.SPECIES do
      local species = Gas.SPECIES[species_index]
      local keep = math.floor(gas[species] * gas.volume_l / total_volume)
      local lost = gas[species] - keep
      if lost > 0 then
        gas[species] = keep
        vented = vented + lost
      end
    end
    if vented > 0 then
      world.gas_vented_qmol = world.gas_vented_qmol + vented
      network.update = true
    end
    return
  end
  if not world:is_gas_cell(index) then
    return
  end
  local view = tile_view(world, index)
  local members = {
    { gas = segment.gas },
    {
      gas = view,
      granularity_qmol = Gas.TILE_UNIT_QMOL,
      species = TILE_SPECIES_SET,
    },
  }
  local changed = Gas.equalize(members)
  if changed then
    network.update = true
    if write_tile(world, index, view) then
      simulation._pipe_tile_changed = true
    end
  end
end

-- One pipe-network solve. Runs every 16 ds at ds = 8 (mod 16): after the
-- due atmosphere machines and before due general machines, holding the +4 ds
-- pipe phase from the machine fidelity contract.
function Pipes.step(simulation, now_ds)
  local world = simulation.world
  local has_pipes = world.pipes and #world.pipes > 0
  if not has_pipes then
    local machines = simulation.machines or {}
    local any_port = false
    for index = 1, #machines do
      local data = machines[index].data
      if data and data.gas_ports then
        any_port = true
        break
      end
    end
    if not any_port then
      return
    end
  end

  local topology = ensure_topology(simulation)
  simulation._pipe_tile_changed = false
  for network_index = 1, #topology.networks do
    local network = topology.networks[network_index]
    if network.update then
      network.update = false
      reconcile(network)
    end
    for pipeline_index = 1, #network.pipelines do
      local pipeline = network.pipelines[pipeline_index]
      for segment_index = 1, #pipeline.segments do
        local segment = pipeline.segments[segment_index]
        exchange_segment(simulation, network, pipeline, segment)
      end
      for segment_index = 1, #pipeline.segments do
        local segment = pipeline.segments[segment_index]
        if MINGLES[segment.kind] and topology.exposed[segment.id] then
          mingle_segment(simulation, network, segment)
        end
      end
    end
  end
  if simulation._pipe_tile_changed then
    world.gas_revision = world.gas_revision + 1
  end
  simulation._pipe_tile_changed = nil
end

return Pipes
