package.path = "./?.lua;./?/init.lua;" .. package.path

local Stable = require("src.core.stable")
local Rng = require("src.core.rng")
local Constants = require("src.core.constants")
local ContentId = require("src.content.id")
local Simulation = require("src.core.simulation")
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

test("base content and trusted-code example load through one mod path", function()
  local core_root = "mods/org.simstation.core"
  local smart_root = "mods/examples/org.simstation.example.smart-grid"
  local core_files = read_files(core_root, {
    "mod.toml",
    "content/incidents.json",
    "content/jobs.json",
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
  equal(session.registry:report().definition_count, 24)
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
  equal(#sim.world.areas, 84, "Atlas should preserve authored areas")
  equal(#sim.machines, 121, "Atlas should instantiate adapted fixtures")
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
