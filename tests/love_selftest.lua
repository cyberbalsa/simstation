local Simulation = require("src.core.simulation")
local SaveStore = require("src.platform.save_store")
local AtlasCatalog = require("src.assets.atlas_catalog")
local AudioCatalog = require("src.assets.audio_catalog")
local ModLoader = require("src.mods.loader")
local RuntimeContent = require("src.content.runtime")
local Json = require("src.vendor.json")
local Lighting = require("src.presentation.lighting")
local LightField = require("src.presentation.light_field")
local World = require("src.core.world")
local Constants = require("src.core.constants")

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

local function assert_close(actual, expected, message)
  if math.abs(actual - expected) > 0.000001 then
    error(string.format(
      "%s (expected %.8f, got %.8f)",
      message,
      expected,
      actual
    ))
  end
end

local function assert_lighting_restores_state(lighting, label)
  love.graphics.setColor(0.25, 0.5, 0.75, 0.8)
  love.graphics.setBlendMode("alpha", "alphamultiply")
  lighting:draw_field()
  local blend_mode, alpha_mode = love.graphics.getBlendMode()
  assert_equal(blend_mode, "alpha",
    label .. " did not restore blend mode")
  assert_equal(alpha_mode, "alphamultiply",
    label .. " did not restore blend alpha mode")
  local red, green, blue, alpha = love.graphics.getColor()
  assert_close(red, 0.25, label .. " did not restore draw color")
  assert_close(green, 0.5, label .. " did not restore draw color")
  assert_close(blue, 0.75, label .. " did not restore draw color")
  assert_close(alpha, 0.8, label .. " did not restore draw alpha")
end

function SelfTest.run()
  local started = love.timer.getTime()
  local mods, mod_error = ModLoader.discover_love({ api_version = "0.1.0" })
  assert(mods, mod_error and Json.encode(mod_error) or "unknown mod load error")
  local registry_report = mods.registry:report()
  assert_equal(registry_report.definition_count, 42,
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
  local lighting = Lighting.new(simulation.world, content)
  assert_equal(
    lighting.image:getWidth(),
    simulation.world.width,
    "light texture must use one texel per world tile"
  )
  assert_equal(
    lighting.image:getHeight(),
    simulation.world.height,
    "light texture must use one texel per world tile"
  )
  local minimum_filter, maximum_filter = lighting.image:getFilter()
  assert_equal(minimum_filter, "linear", "light texture minimum filter")
  assert_equal(maximum_filter, "linear", "light texture maximum filter")
  assert(lighting:update(
    simulation.world,
    simulation.machines,
    simulation.tick
  ), "initial light field did not build")
  assert_lighting_restores_state(lighting, "shader lighting path")
  local compiled_shader = lighting.shader
  lighting.shader = nil
  assert_lighting_restores_state(lighting, "fallback lighting path")
  lighting.shader = compiled_shader
  love.graphics.setColor(1, 1, 1, 1)
  lighting:draw_bloom(
    1,
    1,
    simulation.world.width,
    simulation.world.height
  )
  local lighting_report = lighting:diagnostics()
  assert(lighting_report.emitters > 0, "Atlas produced no light emitters")
  assert_equal(lighting_report.uploads, 1, "light field upload count")

  local apc_values = {}
  for machine_index = 1, #simulation.machines do
    local machine = simulation.machines[machine_index]
    if machine.kind == "apc" then
      apc_values[#apc_values + 1] = {
        machine = machine,
        lighting = machine.data.lighting,
      }
      machine.data.lighting = 1
    end
  end
  assert(#apc_values > 0, "Atlas produced no APC machines")
  assert(lighting:update(
    simulation.world,
    simulation.machines,
    simulation.tick
  ), "same-tick APC shutoff did not rebuild lighting")
  assert(
    lighting:diagnostics().emitters < lighting_report.emitters,
    "APC shutoff did not remove any served fixture emitters"
  )
  for index = 1, #apc_values do
    apc_values[index].machine.data.lighting = apc_values[index].lighting
  end
  assert(lighting:update(
    simulation.world,
    simulation.machines,
    simulation.tick
  ), "same-tick APC restoration did not rebuild lighting")

  local uploads_before_stable_power = lighting:diagnostics().uploads
  simulation.world.power_revision = simulation.world.power_revision + 1
  assert(not lighting:update(
    simulation.world,
    simulation.machines,
    simulation.tick
  ), "stable power revision should not rebuild the light field")
  assert_equal(
    lighting:diagnostics().uploads,
    uploads_before_stable_power,
    "stable lighting state caused a redundant texture upload"
  )

  local ambient_world = World.new(3, 3)
  local ambient_lighting = Lighting.new(ambient_world, nil)
  local ambient_index = assert(ambient_world:index(2, 2))
  assert(ambient_lighting:update(ambient_world, {}, 0))
  assert_equal(
    ambient_lighting.field:channel(ambient_index, 1),
    LightField.UNITS,
    "space ambient did not start full-bright"
  )
  ambient_world.tile[ambient_index] = Constants.TILE.FLOOR
  ambient_world.turf_kind[ambient_index] = Constants.TURF.FLOOR
  ambient_world:touch(2, 2, true)
  assert(
    ambient_lighting:update(ambient_world, {}, 0),
    "same-tick space-to-floor edit did not rebuild lighting"
  )
  assert_equal(
    ambient_lighting.field:channel(ambient_index, 1),
    0,
    "space-to-floor edit retained stale full-bright ambient"
  )
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
    light_emitters = lighting_report.emitters,
    lighting_shader = lighting_report.shader,
    lighting_build_ms = lighting_report.build_ms,
    elapsed_seconds = love.timer.getTime() - started,
  }
  print(Json.encode(report))
  return report
end

return SelfTest
