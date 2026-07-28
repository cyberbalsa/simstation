local Simulation = require("src.core.simulation")
local SaveStore = require("src.platform.save_store")
local AtlasCatalog = require("src.assets.atlas_catalog")
local AudioCatalog = require("src.assets.audio_catalog")
local ModLoader = require("src.mods.loader")
local RuntimeContent = require("src.content.runtime")
local Json = require("src.vendor.json")

local SelfTest = {}

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format(
      "%s (expected %s, got %s)",
      message,
      tostring(expected),
      tostring(actual)
    ))
  end
end

function SelfTest.run()
  local started = love.timer.getTime()
  local mods, mod_error = ModLoader.discover_love({ api_version = "0.1.0" })
  assert(mods, mod_error and Json.encode(mod_error) or "unknown mod load error")
  local registry_report = mods.registry:report()
  assert_equal(registry_report.definition_count, 24,
    "unexpected base content definition count")
  local content = RuntimeContent.from_registry(mods.registry)
  local scenario = assert(
    content.by_id["org.simstation.core:scenario/goon-atlas"]
  )
  local mod_lock = {}
  for i = 1, #mods.order do
    mod_lock[#mod_lock + 1] = {
      id = mods.order[i].id,
      version = mods.order[i].version,
      package_sha256 = mods.order[i].package_sha256,
    }
  end

  local simulation = Simulation.new({
    seed = 424242,
    crew_count = 12,
    content = content,
    scenario = scenario,
  })
  simulation:enqueue("trigger_meteor")
  for _ = 1, 120 do
    simulation:step()
  end

  local store = SaveStore.new({ mod_lock = mod_lock, content = content })
  local encoded = store:encode(simulation)
  local restored, header = assert(store:decode(encoded))
  assert_equal(restored:state_hash(), simulation:state_hash(), "save hash mismatch")
  assert_equal(header.tick, simulation.tick, "save header tick mismatch")
  local wrong_store = SaveStore.new({ mod_lock = {} })
  local wrong_simulation, wrong_error = wrong_store:decode(encoded)
  assert(not wrong_simulation and wrong_error:match("mod lock"),
    "save should reject a mismatched mod lock")
  for _ = 1, 120 do
    simulation:step()
    restored:step()
  end
  assert_equal(restored:state_hash(), simulation:state_hash(),
    "save continuation mismatch")

  local atlas = AtlasCatalog.new()
  assert(atlas.available, atlas.error)
  local sprite = assert(atlas:sprite("floor", "south", 1))
  assert(sprite.width > 0 and sprite.height > 0, "invalid floor sprite")
  local machine_sprite = assert(atlas:sprite("fabricator", "south", 1))
  assert(machine_sprite.width > 0, "invalid fabricator sprite")

  local audio = AudioCatalog.new()
  assert(audio.available, audio.error)
  local voice = assert(audio:new_voice("station_chime"))
  assert(voice:typeOf("Source"), "catalog did not create an audio Source")
  voice:release()

  local report = {
    ok = true,
    tick = simulation.tick,
    state_hash = simulation:state_hash(),
    save_bytes = #encoded,
    mod_packs = #mods.order,
    core_package_sha256 = mods.order[1].package_sha256,
    definitions = registry_report.definition_count,
    atlas_pages_loaded = 2,
    audio_prototypes_loaded = 1,
    elapsed_seconds = love.timer.getTime() - started,
  }
  print(Json.encode(report))
  return report
end

return SelfTest
