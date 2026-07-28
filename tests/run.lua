package.path = "./?.lua;./?/init.lua;" .. package.path

local Stable = require("src.core.stable")
local Rng = require("src.core.rng")
local Constants = require("src.core.constants")
local ContentId = require("src.content.id")
local Simulation = require("src.core.simulation")
local Machine = require("src.core.machine")
local Scenario = require("src.core.scenario")
local Json = require("src.vendor.json")
local Resolver = require("src.mods.resolver")
local Hooks = require("src.mods.hooks")
local Semver = require("src.mods.semver")
local Manifest = require("src.mods.manifest")
local Registry = require("src.content.registry")
local ModLoader = require("src.mods.loader")
local HookContext = require("src.mods.context")
local RuntimeContent = require("src.content.runtime")
local Camera = require("src.presentation.camera")
local Ui = require("src.presentation.ui")
local World = require("src.core.world")

local tests = {}

local function test(name, callback)
  tests[#tests + 1] = { name = name, callback = callback }
end

local function equal(actual, expected, message)
  if actual ~= expected then
    error(string.format(
      "%s\nexpected: %s\nactual:   %s",
      message or "values differ",
      tostring(expected),
      tostring(actual)
    ), 2)
  end
end

local function truthy(value, message)
  if not value then
    error(message or "expected a truthy value", 2)
  end
end

test("RNG sequence is reproducible", function()
  local first = Rng.new(1984)
  local second = Rng.new(1984)
  for _ = 1, 1000 do
    equal(first:next_int(), second:next_int())
  end
end)

test("camera keeps native pixels aligned inside its world viewport", function()
  equal(Constants.TILE_SIZE, 32)
  local foundation_handle = assert(io.open(
    "assets/runtime/goon/graphics/foundation.json",
    "rb"
  ))
  local foundation = Json.decode(foundation_handle:read("*a"))
  foundation_handle:close()
  equal(#Stable.sorted_keys(foundation.sprites), 29)
  equal(#foundation.pages, 14)
  for _, entry in pairs(foundation.sprites) do
    equal(entry.cell_width, Constants.TILE_SIZE)
    equal(entry.cell_height, Constants.TILE_SIZE)
    for _, frames in pairs(entry.directions) do
      for frame_index = 1, #frames do
        equal(frames[frame_index].w, Constants.TILE_SIZE)
        equal(frames[frame_index].h, Constants.TILE_SIZE)
      end
    end
  end

  local viewport_x, viewport_y, viewport_width, viewport_height =
    Ui.world_viewport(1280, 720)
  equal(viewport_x, 192)
  equal(viewport_y, 64)
  equal(viewport_width, 896)
  equal(viewport_height, 640)
  equal(viewport_width % Constants.TILE_SIZE, 0)
  equal(viewport_height % Constants.TILE_SIZE, 0)
  equal(viewport_width * 5, viewport_height * 7)

  viewport_x, viewport_y, viewport_width, viewport_height =
    Ui.world_viewport(960, 540)
  equal(viewport_x, 144)
  equal(viewport_y, 54)
  equal(viewport_width, 672)
  equal(viewport_height, 480)
  equal(viewport_width / Constants.TILE_SIZE, 21)
  equal(viewport_height / Constants.TILE_SIZE, 15)
  equal(viewport_width * 5, viewport_height * 7)

  local world = World.new(64, 64)
  local camera = Camera.new(world, 1001, 553, 0, 48)
  viewport_x, viewport_y, viewport_width, viewport_height =
    camera:viewport_rect()
  equal(viewport_x, 0)
  equal(viewport_y, 48)
  equal(viewport_width, 1001)
  equal(viewport_height, 553)
  truthy(not camera:contains_screen_point(500, 47))
  truthy(camera:contains_screen_point(500, 48))

  local center_x = viewport_x + math.floor(viewport_width / 2)
  local center_y = viewport_y + math.floor(viewport_height / 2)
  local world_x, world_y = camera:screen_to_world(center_x, center_y)
  equal(world_x, 1024)
  equal(world_y, 1024)
  equal(camera:screen_to_tile(center_x, 47, world), nil)

  camera.x = 100.3
  camera.y = 200.7
  camera.zoom = 0.5
  local render_x, render_y = camera:render_position()
  equal((render_x * camera.zoom) % 1, 0)
  equal((render_y * camera.zoom) % 1, 0)
  camera:set_zoom(1.7, center_x, center_y, world)
  equal(camera.zoom, 2)
  render_x, render_y = camera:render_position()
  equal((render_x * camera.zoom) % 1, 0)
  equal((render_y * camera.zoom) % 1, 0)

  local camera_positions = {
    { 100.3, 200.7 },
    { 511.5, 1024.25 },
    { 1600.9, 901.1 },
  }
  local world_points = {
    { 0, 0 },
    { 96, 160 },
    { 641.5, 319.25 },
  }
  for zoom_index = 1, #Camera.ZOOM_LEVELS do
    camera.zoom = Camera.ZOOM_LEVELS[zoom_index]
    for position_index = 1, #camera_positions do
      camera.x = camera_positions[position_index][1]
      camera.y = camera_positions[position_index][2]
      render_x, render_y = camera:render_position()
      equal((render_x * camera.zoom) % 1, 0)
      equal((render_y * camera.zoom) % 1, 0)
      for point_index = 1, #world_points do
        local point = world_points[point_index]
        local screen_x =
          center_x + (point[1] - render_x) * camera.zoom
        local screen_y =
          center_y + (point[2] - render_y) * camera.zoom
        local roundtrip_x, roundtrip_y =
          camera:screen_to_world(screen_x, screen_y)
        truthy(math.abs(roundtrip_x - point[1]) < 0.000000001)
        truthy(math.abs(roundtrip_y - point[2]) < 0.000000001)
      end
    end
  end

  camera:resize(800, 400, 10, 60)
  truthy(camera:contains_screen_point(10, 60))
  truthy(not camera:contains_screen_point(810, 60))
end)

test("content IDs enforce namespace and kind", function()
  local parsed = assert(ContentId.parse("org.simstation.core:item/steel-sheet"))
  equal(parsed.pack, "org.simstation.core")
  equal(parsed.kind, "item")
  equal(parsed.name, "steel-sheet")
  truthy(not ContentId.parse("core:item/steel"))
  truthy(not ContentId.parse("org..bad:item/steel"))
end)

test("JSON is deterministic and round-trips authoritative values", function()
  local value = {
    z = true,
    a = { 1, 2, 3 },
    nested = { message = "airlock\\nready", count = 42 },
  }
  local encoded = Json.encode(value)
  equal(encoded, Json.encode(value))
  local decoded = Json.decode(encoded)
  equal(Stable.hash(decoded), Stable.hash(value))
end)

test("mod resolver is deterministic and detects cycles", function()
  local resolved = assert(Resolver.resolve({
    { id = "org.example.addon", version = "1.0.0", dependencies = { "org.example.base" } },
    { id = "org.example.base", version = "1.0.0" },
  }))
  equal(resolved[1].id, "org.example.base")
  equal(resolved[2].id, "org.example.addon")
  local cycle = Resolver.resolve({
    { id = "a.example.mod", version = "1", dependencies = { "b.example.mod" } },
    { id = "b.example.mod", version = "1", dependencies = { "a.example.mod" } },
  })
  equal(cycle, nil)
end)

test("hook order and transforms are stable", function()
  local order = assert(Resolver.resolve({
    { id = "org.example.addon", version = "1.0.0",
      dependencies = { { id = "org.example.base", version = "^1.0.0" } } },
    { id = "org.example.base", version = "1.0.0" },
  }))
  local hooks = Hooks.new(order)
  hooks:register("org.example.addon", "transform", "price", function(_, value)
    return value + 2
  end, 0)
  hooks:register("org.example.base", "transform", "price", function(_, value)
    return value * 3
  end, 0)
  equal(assert(hooks:transform("price", 10, {})), 32)
end)

test("SemVer constraints cover exact, caret, range, and prerelease rules", function()
  truthy(Semver.satisfies("1.2.3", "=1.2.3"))
  truthy(Semver.satisfies("1.8.0", "^1.2.3"))
  truthy(not Semver.satisfies("2.0.0", "^1.2.3"))
  truthy(Semver.satisfies("0.2.9", "^0.2.3"))
  truthy(not Semver.satisfies("0.3.0", "^0.2.3"))
  truthy(Semver.satisfies("1.4.2", ">=1.2.0,<2.0.0"))
  truthy(not Semver.satisfies("1.4.2-alpha", ">=1.2.0,<2.0.0"))
  truthy(Semver.satisfies("1.4.2-alpha", ">=1.4.2-alpha,<2.0.0"))
  equal(Semver.parse("01.2.3"), nil)
end)

test("manifest subset parses the shipped core pack", function()
  local handle = assert(io.open("mods/org.simstation.core/mod.toml", "rb"))
  local source = handle:read("*a")
  handle:close()
  local manifest = Manifest.parse(source)
  equal(manifest.id, "org.simstation.core")
  equal(manifest.version, "0.1.0")
  equal(manifest.content[1], "content/*.json")
end)

test("content registry applies declared replacements deterministically", function()
  local registry = Registry.new()
  registry:add_pack(
    { id = "org.example.base", dependencies = {}, replaces = {} },
    { { definitions = {
      { id = "org.example.base:item/widget", kind = "item", value = 1 },
    } } }
  )
  registry:add_pack(
    {
      id = "org.example.patch",
      dependencies = { { id = "org.example.base", version = "^1.0.0" } },
      replaces = { "org.example.base:item/widget" },
    },
    { { definitions = {
      {
        id = "org.example.base:item/widget",
        kind = "item",
        replaces = "org.example.base:item/widget",
        value = 2,
      },
    } } }
  )
  registry:seal()
  equal(registry:get("org.example.base:item/widget").value, 2)
  equal(registry:report().replacements[1].to, "org.example.patch")
end)

local function read_files(root, paths)
  local files = {}
  for i = 1, #paths do
    local handle = assert(io.open(root .. "/" .. paths[i], "rb"))
    files[paths[i]] = handle:read("*a")
    handle:close()
  end
  return files
end

local function load_core_runtime_content()
  local root = "mods/org.simstation.core"
  local files = read_files(root, {
    "mod.toml",
    "content/incidents.json",
    "content/jobs.json",
    "content/machines.json",
    "content/materials.json",
    "content/recipes.json",
    "content/structures.json",
  })
  local session = assert(ModLoader.load({
    { root = root, files = files },
  }, { api_version = "0.1.0" }))
  return RuntimeContent.from_registry(session.registry), session
end

local function add_test_machine(
  sim,
  definition_id,
  kind,
  x,
  y,
  ordinal,
  source_overrides
)
  local machine = Machine.create(sim, {
    id = string.format(
      "org.simstation.core:scenario-fixture/test/%s-%d",
      kind,
      sim.next_entity_id
    ),
    definition_id = definition_id,
    kind = kind,
    name = "Test " .. kind,
    index = assert(sim.world:index(x, y)),
    x = x,
    y = y,
    department = "engineering",
    source_path = "/obj/machinery/" .. kind,
    source_overrides = source_overrides or {},
  }, sim.next_entity_id, ordinal or (#sim.machines + 1))
  sim.next_entity_id = sim.next_entity_id + 1
  sim.machines[#sim.machines + 1] = machine
  return machine
end

local function test_actor_at(sim, machine, options)
  options = options or {}
  return {
    id = options.id or 9001,
    index = options.index or machine.index,
    alive = options.alive ~= false,
    incapacitated = options.incapacitated or false,
    access = options.access or {
      "public",
      "engineering",
      "engineering_power",
    },
    tools = options.tools or {
      "crowbar",
      "multitool",
      "screwdriver",
      "wirecutters",
    },
    remote_machine_access = options.remote_machine_access or false,
    silicon = options.silicon or false,
  }
end

local function wire_with_id(machine, wanted)
  for index = 1, #machine.wires do
    if machine.wires[index].id == wanted then
      return machine.wires[index]
    end
  end
  return nil
end

local function action_ids(actions)
  local result = {}
  for index = 1, #(actions or {}) do
    local action = actions[index]
    result[index] = type(action) == "table" and action.id or action
  end
  return result
end

local function find_affordance(affordances, action_id)
  for index = 1, #(affordances or {}) do
    if affordances[index].id == action_id then
      return affordances[index]
    end
  end
  return nil
end

test("base content and trusted-code example load through one mod path", function()
  local core_root = "mods/org.simstation.core"
  local smart_root = "mods/examples/org.simstation.example.smart-grid"
  local core_files = read_files(core_root, {
    "mod.toml",
    "content/incidents.json",
    "content/jobs.json",
    "content/machines.json",
    "content/materials.json",
    "content/recipes.json",
    "content/structures.json",
    "scenarios/goon-atlas.json",
    "locales/en.json",
  })
  local smart_files = read_files(smart_root, { "mod.toml", "lua/init.lua" })
  local session = assert(ModLoader.load({
    { root = core_root, files = core_files },
    {
      root = smart_root,
      files = smart_files,
      load_chunk = function(_, path)
        return loadstring(smart_files[path], "@" .. smart_root .. "/" .. path)
      end,
    },
  }, {
    api_version = "0.1.0",
    trusted_code = { ["org.simstation.example.smart-grid"] = true },
  }))
  equal(session.registry:report().definition_count, 37)
  local allowed, reason = session.hooks:validate(
    "org.simstation.core:hook/command/validate",
    { kind = "disconnect_network", payload = { essential = true } },
    {}
  )
  truthy(not allowed)
  equal(reason, "org.simstation.example.smart-grid.reason.essential-network")
  local score = assert(session.hooks:transform(
    "org.simstation.core:hook/task/score",
    100,
    { subject = { tags = { power_emergency = true } } }
  ))
  equal(score, 350)

  local hooked = Simulation.new({
    seed = 31,
    width = 48,
    height = 48,
    crew_count = 0,
    hooks = session.hooks,
  })
  hooked:enqueue("disconnect_network", { essential = true })
  hooked:step()
  local rejected = hooked.events.values[#hooked.events.values]
  equal(rejected.kind, "command_rejected")
  equal(
    rejected.payload.reason,
    "org.simstation.example.smart-grid.reason.essential-network"
  )
  hooked:_emit("power_restored", { network = "essential" })
  equal(
    hooked.mod_state["org.simstation.example.smart-grid"].restorations,
    1
  )
  local restored = Simulation.from_snapshot(hooked:snapshot(), {
    hooks = session.hooks,
  })
  equal(restored:state_hash(), hooked:state_hash())
  equal(
    restored.mod_state["org.simstation.example.smart-grid"].restorations,
    1
  )
end)

test("salvage example loads and instantiates as a native scenario", function()
  local core_root = "mods/org.simstation.core"
  local salvage_root =
    "mods/examples/org.simstation.example.salvage-scenario"
  local core_files = read_files(core_root, {
    "mod.toml",
    "content/incidents.json",
    "content/jobs.json",
    "content/machines.json",
    "content/materials.json",
    "content/recipes.json",
    "content/structures.json",
  })
  local salvage_files = read_files(salvage_root, {
    "mod.toml",
    "content/recovery.json",
    "scenarios/last-chance.json",
  })
  local session = assert(ModLoader.load({
    { root = core_root, files = core_files },
    { root = salvage_root, files = salvage_files },
  }, { api_version = "0.1.0" }))
  local content = RuntimeContent.from_registry(session.registry)
  local scenario = assert(content.by_id[
    "org.simstation.example.salvage-scenario:scenario/last-chance"
  ])
  local world, setup = Scenario.instantiate(scenario, content)

  equal(world.width, 16)
  equal(world.height, 16)
  equal(#world.areas, 2)
  equal(#setup.fixtures, 8)
  equal(#setup.spawns, 4)
  equal(#setup.meteor_targets, 2)
  truthy(world.area_powered[1], "engineering should start powered")
  truthy(world.area_powered[2], "cargo should start powered")
  equal(
    setup.starting_inventory["org.simstation.core:item/steel-sheet"],
    20
  )

  local profile = assert(content.by_id[
    "org.simstation.example.salvage-scenario:scenario-profile/last-chance"
  ])
  equal(profile.default_seed, 90210)
  equal(profile.station_credits, 8000)
  equal(profile.crew_count, 16)
  equal(profile.objectives[1],
    "org.simstation.example.salvage-scenario:objective/export-control-assemblies")

  local invalid = Stable.deep_copy(scenario)
  invalid.areas[1].key =
    "org.example.other:scenario-area/last-chance/engineering"
  local valid, validation_error = pcall(Scenario.validate, invalid, content)
  truthy(not valid, "nested scenario IDs must remain in the scenario namespace")
  truthy(tostring(validation_error):match("must belong to scenario"))

  invalid = Stable.deep_copy(scenario)
  invalid.map.unexpected = true
  valid, validation_error = pcall(Scenario.validate, invalid, content)
  truthy(not valid, "unknown native-map keys must be rejected")
  truthy(tostring(validation_error):match("unknown key"))

  invalid = Stable.deep_copy(scenario)
  invalid.map.runs[1][3] = invalid.map.default_palette
  valid, validation_error = pcall(Scenario.validate, invalid, content)
  truthy(not valid, "default-valued map runs must be rejected")
  truthy(tostring(validation_error):match("default palette"))

  invalid = Stable.deep_copy(scenario)
  local duplicate_cell = Stable.deep_copy(invalid.map.palette[1])
  duplicate_cell.key = "duplicate-" .. duplicate_cell.key
  invalid.map.palette[#invalid.map.palette + 1] = duplicate_cell
  valid, validation_error = pcall(Scenario.validate, invalid, content)
  truthy(not valid, "semantic palette duplicates must be rejected")
  truthy(tostring(validation_error):match("duplicate semantic"))

  local interior_wall
  for index = 1, world.size do
    if world.structure[index] == Constants.STRUCTURE.WALL then
      local x, y = world:coordinates(index)
      local neighbors = {
        world:index(x, y - 1),
        world:index(x - 1, y),
        world:index(x + 1, y),
        world:index(x, y + 1),
      }
      local exposed = false
      for neighbor_index = 1, 4 do
        local neighbor = neighbors[neighbor_index]
        if not neighbor or world.tile[neighbor] == Constants.TILE.SPACE then
          exposed = true
          break
        end
      end
      if not exposed then
        interior_wall = { x = x, y = y }
        break
      end
    end
  end
  truthy(interior_wall, "salvage fixture should contain an interior wall")
  invalid = Stable.deep_copy(scenario)
  invalid.meteor_targets = { interior_wall }
  valid, validation_error = pcall(Scenario.instantiate, invalid, content)
  truthy(not valid, "meteor targets must be exterior hull walls")
  truthy(tostring(validation_error):match("not exterior"))
end)

test("simulation command stream is deterministic", function()
  local first = Simulation.new({ seed = 77, width = 48, height = 48, crew_count = 12 })
  local second = Simulation.new({ seed = 77, width = 48, height = 48, crew_count = 12 })
  local commands = {
    { tick = 1, kind = "blueprint", payload = { x = 40, y = 24, kind = "floor" } },
    { tick = 20, kind = "trigger_meteor", payload = {} },
    { tick = 30, kind = "set_speed", payload = { speed = 4 } },
  }
  for tick = 1, 180 do
    for i = 1, #commands do
      if commands[i].tick == tick then
        first:enqueue(commands[i].kind, commands[i].payload)
        second:enqueue(commands[i].kind, commands[i].payload)
      end
    end
    first:step()
    second:step()
  end
  equal(first:state_hash(), second:state_hash())
  truthy(first.metrics.construction_completed >= 1, "crew should complete construction")
end)

test("snapshot restoration preserves state hash and continuation", function()
  local original = Simulation.new({ seed = 91, width = 48, height = 48, crew_count = 8 })
  original:enqueue("trigger_meteor")
  for _ = 1, 90 do
    original:step()
  end
  local restored = Simulation.from_snapshot(original:snapshot())
  equal(restored:state_hash(), original:state_hash())
  for _ = 1, 120 do
    original:step()
    restored:step()
  end
  equal(restored:state_hash(), original:state_hash())
end)

test("structure definitions own closed sorted interaction profiles", function()
  local Interaction = require("src.core.interaction")
  local content = load_core_runtime_content()
  local expected_actions = {
    ["org.simstation.core:structure/floor"] = {
      profile = "goon-floor-v1",
      actions = {
        "inspect",
        "place-floor",
        "pry-floor",
        "reinforce-floor",
        "remove-floor-reinforcement",
      },
    },
    ["org.simstation.core:structure/wall"] = {
      profile = "goon-wall-v1",
      actions = { "dismantle-wall", "inspect", "repair-wall" },
    },
    ["org.simstation.core:structure/door"] = {
      profile = "goon-airlock-v1",
      actions = {
        "close-door",
        "inspect",
        "open-door",
        "pry-door",
        "toggle-door-panel",
        "weld-door",
      },
    },
  }
  local definitions = content.by_kind.structure or {}
  truthy(#definitions >= 3)
  local saw_expected = {}
  for index = 1, #definitions do
    local definition = definitions[index]
    equal(definition.schema, 2)
    truthy(
      definition.interaction_profile,
      definition.id .. " must reference an interaction profile"
    )
    equal(type(definition.interaction_profile), "string")
    local ids = action_ids(definition.actions)
    truthy(#ids > 0, definition.id .. " interaction profile has no actions")
    local sorted = Stable.deep_copy(ids)
    table.sort(sorted)
    equal(
      Stable.hash(ids),
      Stable.hash(sorted),
      definition.id .. " interaction actions must be sorted"
    )
    local seen = {}
    for action_index = 1, #ids do
      local action = definition.actions[action_index]
      equal(type(action), "table")
      truthy(not seen[ids[action_index]], "duplicate action " .. ids[action_index])
      seen[ids[action_index]] = true
      truthy(
        Interaction.is_handler_registered(
          definition.interaction_profile,
          action.handler
        ),
        definition.id .. " has no handler " .. tostring(action.handler)
      )
    end
    local expected = expected_actions[definition.id]
    if expected then
      saw_expected[definition.id] = true
      equal(definition.interaction_profile, expected.profile)
      equal(#ids, #expected.actions, definition.id .. " action set is not closed")
      for expected_index = 1, #expected.actions do
        equal(ids[expected_index], expected.actions[expected_index])
      end
    end
  end
  local expected_ids = Stable.sorted_keys(expected_actions)
  for index = 1, #expected_ids do
    truthy(saw_expected[expected_ids[index]], "missing " .. expected_ids[index])
  end
end)

test("tile interaction gates and physical transitions are deterministic", function()
  local Interaction = require("src.core.interaction")
  local traversal_world = World.new(3, 1)
  local catwalk_index = assert(traversal_world:index(1, 1))
  local lattice_index = assert(traversal_world:index(2, 1))
  local traversal_revision = traversal_world.topology_revision
  truthy(traversal_world:set_feature(
    catwalk_index,
    Constants.FEATURE.CATWALK,
    true
  ))
  truthy(traversal_world.topology_revision > traversal_revision)
  truthy(traversal_world:set_feature(
    lattice_index,
    Constants.FEATURE.LATTICE,
    true
  ))
  truthy(traversal_world:is_passable(catwalk_index))
  truthy(traversal_world:is_passable(lattice_index))
  truthy(not traversal_world:is_gas_cell(catwalk_index))
  truthy(traversal_world:set_feature(
    lattice_index,
    Constants.FEATURE.GRILLE,
    true
  ))
  truthy(not traversal_world:is_passable(lattice_index))

  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 1201,
    width = 48,
    height = 48,
    crew_count = 1,
    content = content,
  })
  local actor = sim.crew[1]
  actor.tools[#actor.tools + 1] = "floor_tile"
  table.sort(actor.tools)

  local floor_index = assert(sim.world:index(25, 24))
  local floor_target = { kind = "tile", index = floor_index }
  actor.index = assert(sim.world:index(24, 24))

  local allowed, reason = Interaction.can_action(
    sim,
    floor_target,
    "unknown-action",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "unknown-action")
  allowed, reason = Interaction.can_action(
    sim,
    { kind = "tile", index = 0 },
    "inspect",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "outside-map")
  allowed, reason = Interaction.can_action(
    sim,
    { kind = "machine", index = floor_index },
    "inspect",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "unsupported")

  local far_actor = Stable.deep_copy(actor)
  far_actor.index = assert(sim.world:index(1, 1))
  allowed, reason = Interaction.can_action(
    sim,
    floor_target,
    "pry-floor",
    far_actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "not-adjacent")

  local unequipped = Stable.deep_copy(actor)
  unequipped.tools = {}
  allowed, reason = Interaction.can_action(
    sim,
    floor_target,
    "pry-floor",
    unequipped,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "wrong-tool")
  local denied_affordances = Interaction.affordances(
    sim,
    floor_target,
    unequipped
  )
  local denied_pry = find_affordance(denied_affordances, "pry-floor")
  truthy(denied_pry, "NPC affordances should retain unavailable actions")
  truthy(not denied_pry.available)
  equal(denied_pry.reason, "wrong-tool")

  sim.crew[2] = {
    id = 999001,
    index = floor_index,
    alive = true,
    tools = {},
    access = { "public" },
  }
  allowed, reason = Interaction.can_action(
    sim,
    floor_target,
    "pry-floor",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "occupied")
  sim.crew[2] = nil

  local affordances = Interaction.affordances(sim, floor_target, actor)
  local ids = action_ids(affordances)
  local sorted_ids = Stable.deep_copy(ids)
  table.sort(sorted_ids)
  equal(Stable.hash(ids), Stable.hash(sorted_ids))
  equal(#ids, #Stable.sorted_keys((function()
    local unique = {}
    for index = 1, #ids do unique[ids[index]] = true end
    return unique
  end)()))
  truthy(find_affordance(affordances, "pry-floor").available)

  local floor_chunk = sim.world:chunk_index(25, 24)
  local floor_revision = sim.world.chunk_revision[floor_chunk]
  truthy(Interaction.perform(
    sim,
    floor_target,
    "pry-floor",
    actor,
    {}
  ))
  equal(sim.world.tile[floor_index], Constants.TILE.FLOOR)
  equal(sim.world.turf_kind[floor_index], Constants.TURF.PLATING)
  truthy(sim.world.chunk_revision[floor_chunk] > floor_revision)
  allowed, reason = Interaction.can_action(
    sim,
    floor_target,
    "pry-floor",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "invalid-target-state")
  local plating_affordances = Interaction.affordances(
    sim,
    floor_target,
    actor
  )
  local invalid_pry = find_affordance(plating_affordances, "pry-floor")
  truthy(invalid_pry, "known sibling actions should remain NPC-visible")
  truthy(not invalid_pry.available)
  equal(invalid_pry.reason, "invalid-target-state")
  truthy(find_affordance(plating_affordances, "place-floor").available)
  truthy(Interaction.can_action(
    sim,
    floor_target,
    "place-floor",
    actor,
    {}
  ))
  truthy(Interaction.perform(
    sim,
    floor_target,
    "place-floor",
    actor,
    {}
  ))
  equal(sim.world.turf_kind[floor_index], Constants.TURF.FLOOR)

  local wall_index = assert(sim.world:index(9, 23))
  local wall_target = { kind = "tile", index = wall_index }
  actor.index = assert(sim.world:index(10, 23))
  local wall_chunk = sim.world:chunk_index(9, 23)
  local wall_revision = sim.world.chunk_revision[wall_chunk]
  local damaged, damage_result = sim.world:damage_structure(
    wall_index,
    25,
    "brute"
  )
  truthy(damaged, tostring(damage_result))
  truthy(sim.world.chunk_revision[wall_chunk] > wall_revision)
  local damaged_affordances = Interaction.affordances(
    sim,
    wall_target,
    actor
  )
  truthy(find_affordance(damaged_affordances, "repair-wall").available)
  allowed, reason = Interaction.can_action(
    sim,
    wall_target,
    "repair-wall",
    unequipped,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "not-adjacent")
  unequipped.index = actor.index
  allowed, reason = Interaction.can_action(
    sim,
    wall_target,
    "repair-wall",
    unequipped,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "wrong-tool")
  truthy(Interaction.perform(
    sim,
    wall_target,
    "repair-wall",
    actor,
    {}
  ))
  allowed, reason = Interaction.can_action(
    sim,
    wall_target,
    "repair-wall",
    actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "invalid-target-state")

  local before_invalid_damage = sim.world.chunk_revision[wall_chunk]
  damaged, damage_result = sim.world:damage_structure(
    wall_index,
    0,
    "brute"
  )
  truthy(not damaged)
  equal(sim.world.chunk_revision[wall_chunk], before_invalid_damage)

  local no_welder = Stable.deep_copy(actor)
  no_welder.tools = { "wrench" }
  allowed, reason = Interaction.can_action(
    sim,
    wall_target,
    "dismantle-wall",
    no_welder,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "wrong-tool")
  local topology_revision = sim.world.topology_revision
  truthy(Interaction.perform(
    sim,
    wall_target,
    "dismantle-wall",
    actor,
    {}
  ))
  equal(sim.world.structure[wall_index], Constants.STRUCTURE.EMPTY)
  equal(sim.world.wall_kind[wall_index], Constants.WALL.NONE)
  truthy(sim.world:is_passable(wall_index))
  truthy(sim.world.topology_revision > topology_revision)

  local restored = Simulation.from_snapshot(sim:snapshot(), {
    content = content,
  })
  equal(restored:state_hash(), sim:state_hash())
  equal(restored.world.turf_kind[floor_index], Constants.TURF.FLOOR)
  equal(restored.world.wall_kind[wall_index], Constants.WALL.NONE)
  equal(
    Stable.hash(restored.world:feature_ids(floor_index)),
    Stable.hash(sim.world:feature_ids(floor_index))
  )
end)

test("tile actions enforce power and access at the command boundary", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 1202,
    width = 48,
    height = 48,
    crew_count = 1,
    content = content,
  })
  local door_index = assert(sim.world:index(24, 13))
  local actor = sim.crew[1]
  actor.index = assert(sim.world:index(24, 14))
  actor.access = { "public", "general" }
  sim.world.door_access[door_index] = "security"
  sim.world.powered[door_index] = false

  local payload = {
    target = { kind = "tile", index = door_index },
    actor_id = actor.id,
    action_id = "open-door",
    parameters = {},
  }
  sim:enqueue("tile_action", payload)
  sim:step()
  local event = sim.events.values[#sim.events.values]
  equal(event.kind, "command_rejected")
  equal(event.payload.reason, "unpowered")
  equal(
    sim.world.structure[door_index],
    Constants.STRUCTURE.DOOR_CLOSED
  )

  sim.world.powered[door_index] = true
  sim:enqueue("tile_action", payload)
  sim:step()
  event = sim.events.values[#sim.events.values]
  equal(event.kind, "command_rejected")
  equal(event.payload.reason, "access-denied")
  equal(
    sim.world.structure[door_index],
    Constants.STRUCTURE.DOOR_CLOSED
  )

  actor.access = { "public", "security" }
  sim:enqueue("tile_action", payload)
  sim:step()
  event = sim.events.values[#sim.events.values]
  equal(event.kind, "tile_action_completed")
  equal(event.payload.action_id, "open-door")
  equal(event.payload.actor_id, actor.id)
  equal(event.payload.target.index, door_index)
  equal(sim.world.structure[door_index], Constants.STRUCTURE.DOOR_OPEN)
end)

test("department machine modules own every implemented core handler", function()
  local content = load_core_runtime_content()
  local definitions = content.by_kind.machine or {}
  equal(#definitions, 13)
  for definition_index = 1, #definitions do
    local definition = definitions[definition_index]
    for action_index = 1, #(definition.actions or {}) do
      local action = definition.actions[action_index]
      if action.implemented then
        truthy(
          Machine.is_handler_registered(definition, action.handler),
          string.format(
            "%s action %s has no department-module handler %s",
            definition.id,
            action.id,
            action.handler
          )
        )
      end
    end
  end
end)

test("machine scheduler follows deterministic Goon decisecond buckets", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 902,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  local apc = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-apc",
    "apc",
    24,
    24,
    1
  )
  local vent = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-passive-vent",
    "vent",
    24,
    24,
    2
  )
  local apc_later = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-apc",
    "apc",
    25,
    24,
    2
  )

  equal(apc.processing.next_due_ds, 4)
  equal(vent.processing.next_due_ds, 4)
  equal(apc_later.processing.next_due_ds, 8)
  Machine.step_all(sim, 3)
  equal(apc.processing.process_count, 0)
  equal(vent.processing.process_count, 0)
  equal(apc_later.processing.process_count, 0)
  Machine.step_all(sim, 4)
  equal(apc.processing.process_count, 1)
  equal(vent.processing.process_count, 1)
  equal(apc_later.processing.process_count, 0)
  equal(apc.processing.last_process_ds, 4)
  equal(vent.processing.last_process_ds, 4)
  Machine.step_all(sim, 8)
  equal(apc_later.processing.process_count, 1)
  equal(apc_later.processing.last_process_ds, 8)
  Machine.step_all(sim, 35)
  equal(apc.processing.process_count, 1)
  equal(vent.processing.process_count, 2)
  equal(apc_later.processing.process_count, 1)
  Machine.step_all(sim, 36)
  equal(apc.processing.process_count, 2)
  equal(vent.processing.process_count, 3)
  equal(apc_later.processing.process_count, 1)
  equal(apc.processing.next_due_ds, 68)
  equal(vent.processing.next_due_ds, 52)
  equal(apc_later.processing.next_due_ds, 40)
  equal(sim.machine_time_ds, 36)
end)

test("machine affordances expose stable NPC action denial reasons", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 903,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  local apc = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-apc",
    "apc",
    24,
    24,
    1
  )
  local manufacturer = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-manufacturer",
    "fabricator",
    25,
    24,
    2
  )
  manufacturer.powered = true
  manufacturer.status.no_power = false

  local far_actor = test_actor_at(sim, apc, {
    index = assert(sim.world:index(1, 1)),
  })
  local allowed, reason = Machine.can_action(
    sim,
    apc,
    "inspect",
    far_actor,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "not-adjacent")

  local assistant = test_actor_at(sim, manufacturer, {
    id = 9002,
    access = { "public", "general" },
    tools = {},
  })
  allowed, reason = Machine.can_action(
    sim,
    manufacturer,
    "toggle-panel",
    assistant,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "wrong-tool")

  local engineer = test_actor_at(sim, apc)
  allowed, reason = Machine.can_action(
    sim,
    apc,
    "set-operating",
    engineer,
    { value = false }
  )
  truthy(not allowed)
  equal(reason.code, "interface-locked")
  truthy(Machine.perform(sim, apc, "swipe-id", engineer, {}))
  truthy(Machine.perform(
    sim,
    apc,
    "set-operating",
    engineer,
    { value = false }
  ))
  equal(apc.data.operating, false)
  allowed, reason = Machine.can_action(
    sim,
    apc,
    "set-operating",
    engineer,
    { unexpected = true, value = true }
  )
  truthy(not allowed)
  equal(reason.code, "invalid-parameter")
  equal(reason.parameter, "unexpected")

  allowed, reason = Machine.can_action(
    sim,
    apc,
    "repair-controller",
    engineer,
    {}
  )
  truthy(not allowed)
  equal(reason.code, "not-implemented")

  local affordances = Machine.affordances(sim, manufacturer, assistant)
  local saw_inspect = false
  local saw_toggle_panel = false
  for index = 1, #affordances do
    if affordances[index].id == "inspect" then
      saw_inspect = affordances[index].available
    elseif affordances[index].id == "toggle-panel" then
      saw_toggle_panel =
        not affordances[index].available
        and affordances[index].reason == "wrong-tool"
    end
  end
  truthy(saw_inspect, "adjacent NPC should be able to inspect")
  truthy(saw_toggle_panel, "affordances should preserve the wrong-tool reason")

  sim.crew = { assistant }
  local hook_actions = assert(HookContext.new(sim):machine_actions(
    manufacturer.scenario_fixture_id,
    assistant.id
  ))
  equal(#hook_actions, #affordances)
  equal(hook_actions[1].id, affordances[1].id)
  equal(
    HookContext.new(sim):machine_actions(
      manufacturer.scenario_fixture_id,
      123456
    ),
    nil
  )
end)

test("machine actions enter through the serialized command boundary", function()
  local content = load_core_runtime_content()
  local hooks = Hooks.new({
    {
      id = "org.example.machine-policy",
      dependency_phase = 0,
    },
  })
  local sim = Simulation.new({
    seed = 907,
    width = 48,
    height = 48,
    crew_count = 1,
    content = content,
    hooks = hooks,
  })
  local pad = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-cargo-pad",
    "cargo_pad",
    24,
    24,
    1
  )
  local actor = sim.crew[1]
  actor.index = pad.index
  truthy(pad.data.active)

  sim:enqueue("machine_action", {
    machine_id = pad.scenario_fixture_id,
    actor_id = actor.id,
    action_id = "toggle-receiver",
    parameters = {},
  })
  sim:step()
  truthy(not pad.data.active)
  local event = sim.events.values[#sim.events.values]
  equal(event.kind, "machine_action_completed")
  equal(event.payload.machine_id, pad.id)
  equal(event.payload.actor_id, actor.id)

  sim:enqueue("machine_action", {
    machine_id = pad.id,
    actor_id = actor.id,
    action_id = "missing-action",
    parameters = {},
  })
  sim:step()
  event = sim.events.values[#sim.events.values]
  equal(event.kind, "command_rejected")
  equal(event.payload.reason, "unknown-action")

  hooks:register(
    "org.example.machine-policy",
    "validate",
    "org.simstation.core:hook/machine/action/validate",
    function(_, request)
      if request.machine_id == pad.id then
        return false, "receiver-policy-denied"
      end
      return true
    end,
    0
  )
  sim:enqueue("machine_action", {
    machine_id = pad.id,
    actor_id = actor.id,
    action_id = "toggle-receiver",
    parameters = {},
  })
  sim:step()
  truthy(not pad.data.active)
  event = sim.events.values[#sim.events.values]
  equal(event.kind, "command_rejected")
  equal(event.payload.reason, "receiver-policy-denied")
end)

test("manufacturer completion rechecks inputs and survives save-load", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 904,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  sim.inventory["org.simstation.core:item/steel-sheet"] = 25
  sim.inventory["org.simstation.core:item/cable-coil"] = 25
  sim.inventory["org.simstation.core:item/circuit"] = 0
  local manufacturer = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-manufacturer",
    "fabricator",
    24,
    24,
    1
  )
  manufacturer.powered = true
  manufacturer.status.no_power = false
  local engineer = test_actor_at(sim, manufacturer)

  truthy(Machine.perform(
    sim,
    manufacturer,
    "set-speed",
    engineer,
    { value = 8 }
  ))
  equal(manufacturer.data.speed, 3, "ordinary speed should clamp at three")
  truthy(Machine.perform(
    sim,
    manufacturer,
    "toggle-panel",
    engineer,
    {}
  ))
  local extend_wire = assert(wire_with_id(manufacturer, "extend"))
  truthy(Machine.perform(
    sim,
    manufacturer,
    "pulse-wire",
    engineer,
    { wire = extend_wire.color }
  ))
  truthy(manufacturer.data.hacked)
  truthy(Machine.perform(
    sim,
    manufacturer,
    "set-speed",
    engineer,
    { value = 8 }
  ))
  equal(manufacturer.data.speed, 5, "hacked speed should clamp at five")
  truthy(Machine.perform(
    sim,
    manufacturer,
    "set-speed",
    engineer,
    { value = 3 }
  ))

  local recipe_id = "org.simstation.core:recipe/fabricate-circuit"
  truthy(Machine.queue_recipe(sim, manufacturer, recipe_id))
  equal(manufacturer.data.mode, "working")
  equal(manufacturer.data.work_finish_ds, 600)
  equal(Machine.power_request(manufacturer), 6950)
  equal(
    sim.inventory["org.simstation.core:item/steel-sheet"],
    25,
    "manufacturer inputs remain physical until completion"
  )
  equal(sim.inventory["org.simstation.core:item/cable-coil"], 25)

  Machine.step_all(sim, 300)
  local restored = Simulation.from_snapshot(sim:snapshot(), {
    content = content,
  })
  equal(restored:state_hash(), sim:state_hash())
  local restored_manufacturer
  for index = 1, #restored.machines do
    if restored.machines[index].id == manufacturer.id then
      restored_manufacturer = restored.machines[index]
      break
    end
  end
  truthy(restored_manufacturer, "machine IDs must survive save restoration")
  equal(restored_manufacturer.data.work_finish_ds, 600)
  equal(
    restored_manufacturer.wires[1].color,
    manufacturer.wires[1].color,
    "global wire colors must survive save restoration"
  )

  Machine.step_all(sim, 599)
  Machine.step_all(restored, 599)
  equal(sim.inventory["org.simstation.core:item/steel-sheet"], 25)
  equal(restored.inventory["org.simstation.core:item/steel-sheet"], 25)
  Machine.step_all(sim, 600)
  Machine.step_all(restored, 600)
  equal(sim.inventory["org.simstation.core:item/steel-sheet"], 24)
  equal(sim.inventory["org.simstation.core:item/cable-coil"], 24)
  equal(sim.inventory["org.simstation.core:item/circuit"], 1)
  equal(restored:state_hash(), sim:state_hash())

  local blocked_sim = Simulation.new({
    seed = 908,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  blocked_sim.inventory["org.simstation.core:item/steel-sheet"] = 1
  blocked_sim.inventory["org.simstation.core:item/cable-coil"] = 1
  blocked_sim.inventory["org.simstation.core:item/circuit"] = 0
  local blocked_machine = add_test_machine(
    blocked_sim,
    "org.simstation.core:machine/goon-manufacturer",
    "fabricator",
    24,
    24,
    1
  )
  blocked_machine.powered = true
  blocked_machine.status.no_power = false
  local blocked_actor = test_actor_at(blocked_sim, blocked_machine)
  truthy(Machine.queue_recipe(blocked_sim, blocked_machine, recipe_id))
  Machine.step_all(blocked_sim, 100)
  truthy(Machine.perform(
    blocked_sim,
    blocked_machine,
    "pause",
    blocked_actor,
    {}
  ))
  equal(blocked_machine.data.mode, "halt")
  equal(blocked_machine.data.time_left_ds, 500)
  truthy(Machine.perform(
    blocked_sim,
    blocked_machine,
    "continue",
    blocked_actor,
    {}
  ))
  equal(
    blocked_machine.data.work_finish_ds,
    700,
    "upstream continue path restarts the current item duration"
  )
  blocked_sim.inventory["org.simstation.core:item/steel-sheet"] = 0
  Machine.step_all(blocked_sim, 700)
  equal(blocked_machine.data.mode, "halt")
  equal(blocked_machine.data.error, "insufficient-materials")
  equal(blocked_sim.inventory["org.simstation.core:item/cable-coil"], 1)
  equal(blocked_sim.inventory["org.simstation.core:item/circuit"], 0)
end)

test("manufacturer queue, damage, and global wire harness match contracts", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 905,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  sim.inventory["org.simstation.core:item/steel-sheet"] = 100
  sim.inventory["org.simstation.core:item/cable-coil"] = 100
  local manufacturer = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-manufacturer",
    "fabricator",
    24,
    24,
    1
  )
  local apc = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-apc",
    "apc",
    24,
    24,
    2
  )
  manufacturer.powered = true
  manufacturer.status.no_power = false

  equal(#manufacturer.wires, 4)
  equal(#apc.wires, 4)
  for index = 1, 4 do
    equal(
      manufacturer.wires[index].color,
      apc.wires[index].color,
      "wire colors must use one deterministic round-wide permutation"
    )
  end

  local recipe_id = "org.simstation.core:recipe/fabricate-circuit"
  for _ = 1, 20 do
    truthy(Machine.queue_recipe(sim, manufacturer, recipe_id))
  end
  equal(#manufacturer.data.queue, 20)
  local queued, queue_error = Machine.queue_recipe(
    sim,
    manufacturer,
    recipe_id
  )
  truthy(not queued)
  equal(queue_error.code, "queue-full")

  truthy(Machine.damage(sim, manufacturer, 75))
  equal(manufacturer.health, 25)
  truthy(manufacturer.status.broken)
  truthy(Machine.damage(sim, manufacturer, -35))
  equal(manufacturer.health, 60)
  truthy(not manufacturer.status.broken)

  apc.data.wiresexposed = true
  apc.data.locked = true
  local id_scan = assert(wire_with_id(apc, "id-scan"))
  local engineer = test_actor_at(sim, apc)
  truthy(Machine.perform(
    sim,
    apc,
    "pulse-wire",
    engineer,
    { wire = id_scan.color }
  ))
  truthy(not apc.data.locked)
  equal(apc.data.unlock_until_ds, 300)
  Machine.step_all(sim, 299)
  truthy(not apc.data.locked)
  Machine.step_all(sim, 300)
  truthy(apc.data.locked)
  equal(apc.data.unlock_until_ds, 0)
end)

test("nanofabricator completes its upstream-immediate recipe path", function()
  local content = load_core_runtime_content()
  local sim = Simulation.new({
    seed = 906,
    width = 48,
    height = 48,
    crew_count = 0,
    content = content,
  })
  sim.inventory["org.simstation.core:item/iron-ore"] = 2
  sim.inventory["org.simstation.core:item/steel-sheet"] = 0
  local nanofab = add_test_machine(
    sim,
    "org.simstation.core:machine/goon-nanofab",
    "nanofab",
    24,
    24,
    1
  )

  truthy(Machine.queue_recipe(
    sim,
    nanofab,
    "org.simstation.core:recipe/smelt-steel"
  ))
  equal(sim.inventory["org.simstation.core:item/iron-ore"], 0)
  equal(sim.inventory["org.simstation.core:item/steel-sheet"], 1)
  equal(nanofab.processing.subscribed, false)
end)

test("breaches depressurize an exposed hull cell", function()
  local sim = Simulation.new({ seed = 5, width = 48, height = 48, crew_count = 0 })
  local index = assert(sim.world:index(39, 24))
  local before = sim.world:pressure_dkpa(index)
  truthy(sim.world:make_breach(39, 24))
  for _ = 1, 8 do
    sim.world:step_atmosphere()
  end
  truthy(sim.world:pressure_dkpa(index) < before, "breach should lose pressure")
end)

test("native Atlas scenario manufactures and round-trips", function()
  local core_root = "mods/org.simstation.core"
  local files = read_files(core_root, {
    "mod.toml",
    "content/incidents.json",
    "content/jobs.json",
    "content/machines.json",
    "content/materials.json",
    "content/recipes.json",
    "content/structures.json",
    "scenarios/goon-atlas.json",
    "locales/en.json",
  })
  local session = assert(ModLoader.load({
    { root = core_root, files = files },
  }, { api_version = "0.1.0" }))
  local content = RuntimeContent.from_registry(session.registry)
  local scenario = assert(
    content.by_id["org.simstation.core:scenario/goon-atlas"]
  )
  local sim = Simulation.new({
    seed = 2026,
    crew_count = 24,
    content = content,
    scenario = scenario,
  })
  equal(sim.world.width, 192)
  equal(sim.world.height, 192)
  equal(#sim.crew, 24)
  equal(#sim.world.areas, 92, "Atlas should preserve authored areas")
  equal(#sim.machines, 134, "Atlas should instantiate adapted fixtures")
  local machine_census = {}
  local positions = {}
  local smes_count = 0
  local smes_with_initial_charge = 0
  local brig_apc
  for index = 1, #sim.machines do
    local machine = sim.machines[index]
    machine_census[machine.kind] = (machine_census[machine.kind] or 0) + 1
    local position = tostring(machine.x) .. "," .. tostring(machine.y)
    positions[position] = (positions[position] or 0) + 1
    if machine.kind == "battery" then
      smes_count = smes_count + 1
      equal(machine.data.chargelevel, 15000)
      equal(machine.data.output, 10000)
      if machine.data.charge == 1000000 then
        smes_with_initial_charge = smes_with_initial_charge + 1
      end
    elseif machine.scenario_fixture_id
      == "org.simstation.core:scenario-fixture/goon-atlas/apc-x114-y064"
    then
      brig_apc = machine
    end
  end
  local expected_census = {
    apc = 81,
    barcode_computer = 1,
    battery = 6,
    cargo_pad = 5,
    circulator = 2,
    fabricator = 20,
    generator = 1,
    nanofab = 2,
    portable_scrubber = 3,
    reclaimer = 7,
    supply_console = 2,
    vent = 3,
    vent_pump = 1,
  }
  local census_kinds = Stable.sorted_keys(expected_census)
  for index = 1, #census_kinds do
    local kind = census_kinds[index]
    equal(machine_census[kind], expected_census[kind])
  end
  equal(#Stable.sorted_keys(machine_census), #census_kinds)
  equal(smes_count, 6)
  equal(smes_with_initial_charge, 2)
  truthy(brig_apc, "Atlas should retain the authored Brig APC")
  equal(brig_apc.name, "Brig APC")
  equal(brig_apc.data.areastring, "Brig")
  equal(brig_apc.data.dir, 8)
  equal(brig_apc.data.pixel_x, -20)
  local layered_positions = 0
  local ordered_positions = Stable.sorted_keys(positions)
  for index = 1, #ordered_positions do
    if positions[ordered_positions[index]] > 1 then
      layered_positions = layered_positions + 1
    end
  end
  equal(layered_positions, 5, "Atlas machine layers must not be flattened")
  equal(#scenario.spawns, 85, "Atlas should preserve authored job starts")
  equal(#sim.scenario.meteor_targets, 64, "Atlas should expose stable hull targets")
  equal(
    scenario.provenance.sources[1].commit,
    "1b2b250abb5be747d55e274de0203a59cfc8da78",
    "Atlas provenance should pin the reviewed Goonstation commit"
  )
  equal(
    sim.inventory["org.simstation.core:item/iron-ore"],
    36,
    "Atlas starting inventory should load"
  )
  local context = HookContext.new(sim)
  equal(
    context:query(
      "inventory",
      "org.simstation.core:item/iron-ore"
    ),
    36,
    "hook queries should expose stable-ID inventory projections"
  )
  local metal_ids = context:definitions("item", "metal")
  equal(#metal_ids, 1)
  equal(metal_ids[1], "org.simstation.core:item/steel-sheet")
  local copied_item = assert(context:definition(
    "org.simstation.core:item/steel-sheet"
  ))
  copied_item.stack_limit = 1
  equal(
    content.by_id["org.simstation.core:item/steel-sheet"].stack_limit,
    50,
    "hook definitions must not expose mutable registry values"
  )
  truthy(context:query_tile(sim.world.map_id, 1, 1))
  equal(
    context:query_tile("org.example.missing:scenario/nope", 1, 1),
    nil,
    "tile queries should reject another map identity"
  )

  local security_door
  for index = 1, sim.world.size do
    if sim.world.structure[index] == Constants.STRUCTURE.DOOR_CLOSED
      and sim.world.door_access[index] == "security"
      and sim.world.powered[index]
    then
      security_door = index
      break
    end
  end
  truthy(security_door, "Atlas should contain a powered security door")
  local allowed, denial = sim.world:can_open_door(
    security_door,
    { "public", "general" }
  )
  truthy(not allowed, "general crew should not open security doors")
  equal(denial, "access denied")
  truthy(sim.world:can_open_door(
    security_door,
    { "public", "security" }
  ))
  local topology_revision = sim.world.topology_revision
  truthy(sim.world:open_door(
    security_door,
    sim.tick,
    { "public", "security" }
  ))
  equal(
    sim.world.topology_revision,
    topology_revision,
    "door animation should not invalidate access-aware paths"
  )
  sim.world:step_doors(Constants.DOOR_AUTO_CLOSE_TICKS, {})
  equal(
    sim.world.structure[security_door],
    Constants.STRUCTURE.DOOR_CLOSED,
    "powered doors should auto-close"
  )

  sim:enqueue("queue_recipe", {
    recipe_id = "org.simstation.core:recipe/smelt-steel",
  })
  for _ = 1, 1200 do
    sim:step()
  end
  equal(
    sim.inventory["org.simstation.core:item/iron-ore"],
    34,
    "manufacturing should reserve recipe inputs"
  )
  truthy(
    sim.inventory["org.simstation.core:item/steel-sheet"] >= 9,
    "crew should complete steel production"
  )
  local restored = Simulation.from_snapshot(sim:snapshot(), {
    content = content,
  })
  equal(restored:state_hash(), sim:state_hash())
  for _ = 1, 120 do
    sim:step()
    restored:step()
  end
  equal(restored:state_hash(), sim:state_hash())
end)

local failures = 0
local started = os.clock()
for i = 1, #tests do
  local current = tests[i]
  local ok, err = xpcall(current.callback, debug.traceback)
  if ok then
    io.write(string.format("ok %02d - %s\n", i, current.name))
  else
    failures = failures + 1
    io.write(string.format("not ok %02d - %s\n%s\n", i, current.name, err))
  end
end
io.write(string.format(
  "\n%d tests, %d failures, %.3fs\n",
  #tests,
  failures,
  os.clock() - started
))
os.exit(failures == 0 and 0 or 1)
