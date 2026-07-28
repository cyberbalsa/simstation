local Constants = require("src.core.constants")
local Simulation = require("src.core.simulation")
local Camera = require("src.presentation.camera")
local Renderer = require("src.presentation.renderer")
local Ui = require("src.presentation.ui")
local Audio = require("src.presentation.audio")
local SaveStore = require("src.platform.save_store")
local ModLoader = require("src.mods.loader")

local App = {}
App.__index = App

function App.new(args)
  local width, height = love.graphics.getDimensions()
  local trusted_code, trust_error = ModLoader.read_trust_config()
  local mod_session, mod_error = ModLoader.discover_love({
    api_version = "0.1.0",
    -- Trust is pinned to exact package bytes/tree content. The bundled core
    -- is data-only; code examples are not discovered from mods/examples.
    trusted_code = trusted_code or {},
  })
  if trust_error and not mod_error then
    mod_error = { message = trust_error }
  end
  local simulation = Simulation.new({
    seed = 1337,
    width = Constants.DEFAULT_WORLD_WIDTH,
    height = Constants.DEFAULT_WORLD_HEIGHT,
    crew_count = Constants.DEFAULT_CREW_COUNT,
    hooks = mod_session and mod_session.hooks or false,
  })
  local mod_lock = {}
  if mod_session then
    for i = 1, #mod_session.order do
      local manifest = mod_session.order[i]
      mod_lock[#mod_lock + 1] = {
        id = manifest.id,
        version = manifest.version,
        package_sha256 = manifest.package_sha256,
      }
    end
  end
  local camera = Camera.new(simulation.world, width, height)
  local app = setmetatable({
    args = args,
    simulation = simulation,
    camera = camera,
    renderer = Renderer.new(simulation.world),
    ui = Ui.new(),
    audio = Audio.new(),
    save_store = SaveStore.new({
      mod_lock = mod_lock,
      hooks = mod_session and mod_session.hooks or false,
    }),
    mod_session = mod_session,
    mod_error = mod_error,
    trust_error = trust_error,
    accumulator = 0,
    held_keys = {},
    dragging_camera = false,
    painting = false,
    last_painted_index = false,
    now = 0,
  }, App)
  if mod_session then
    local report = mod_session.registry:report()
    app.ui:set_notification(
      trust_error
          and ("Trust config ignored: " .. trust_error)
        or string.format(
          "Loaded %d pack%s / %d definitions",
          #mod_session.order,
          #mod_session.order == 1 and "" or "s",
          report.definition_count
        ),
      0,
      6
    )
  else
    app.ui:set_notification(
      "Mod load failed: " .. tostring(mod_error and mod_error.message),
      0,
      10
    )
  end
  return app
end

function App:_snapshot()
  return self.simulation:render_snapshot()
end

function App:_set_tool(tool)
  self.ui:set_tool(tool)
  self.painting = false
  self.last_painted_index = false
  self.ui:set_notification("Tool: " .. tool, self.now, 2)
end

function App:_enqueue_blueprint_at(screen_x, screen_y)
  local world = self.simulation.world
  local x, y = self.camera:screen_to_tile(screen_x, screen_y, world)
  if not x then
    return
  end
  local index = world:index(x, y)
  if index == self.last_painted_index then
    return
  end
  self.last_painted_index = index
  self.simulation:enqueue("blueprint", {
    x = x,
    y = y,
    kind = self.ui.selected_tool,
  })
end

function App:update(dt)
  dt = math.min(dt, 0.25)
  self.now = self.now + dt
  local pan_speed = 650 * dt
  local dx = ((self.held_keys.d and 1 or 0) - (self.held_keys.a and 1 or 0))
    * pan_speed
  local dy = ((self.held_keys.s and 1 or 0) - (self.held_keys.w and 1 or 0))
    * pan_speed
  if dx ~= 0 or dy ~= 0 then
    self.camera:pan(dx, dy)
  end
  self.camera:clamp(self.simulation.world)

  if self.painting and love.mouse.isDown(1) then
    local x, y = love.mouse.getPosition()
    if not self.ui:is_over_ui(x, y) then
      self:_enqueue_blueprint_at(x, y)
    end
  end

  -- Commands remain usable while paused; simulation time does not advance.
  self.simulation:flush_commands()
  if not self.simulation.paused then
    self.accumulator = self.accumulator
      + dt * Constants.SIM_HZ * self.simulation.speed
    local steps = 0
    while self.accumulator >= 1 and steps < 100 do
      self.simulation:step()
      self.accumulator = self.accumulator - 1
      steps = steps + 1
    end
    if steps == 100 then
      self.accumulator = 0
      self.ui:set_notification("Simulation catch-up capped", self.now, 4)
    end
  end

  local mouse_x, mouse_y = love.mouse.getPosition()
  local tile_x, tile_y = self.camera:screen_to_tile(
    mouse_x,
    mouse_y,
    self.simulation.world
  )
  self.renderer:set_hover(tile_x, tile_y)
  self.audio:update(self:_snapshot())
end

function App:draw()
  local snapshot = self:_snapshot()
  self.renderer:draw(snapshot, self.camera)
  self.ui:draw(snapshot, self.renderer, self.camera, self.now)
end

function App:resize(width, height)
  self.camera:resize(width, height)
  self.camera:clamp(self.simulation.world)
end

function App:keypressed(key, _, is_repeat)
  if is_repeat then
    return
  end
  self.held_keys[key] = true
  if key == "space" then
    self.simulation:enqueue("set_paused", {
      paused = not self.simulation.paused,
    })
  elseif key == "1" or key == "2" or key == "4" then
    self.simulation:enqueue("set_speed", { speed = tonumber(key) })
  elseif key == "f" then
    self:_set_tool(Constants.BLUEPRINT.FLOOR)
  elseif key == "x" then
    self:_set_tool(Constants.BLUEPRINT.WALL)
  elseif key == "c" then
    self:_set_tool(Constants.BLUEPRINT.CABLE)
  elseif key == "v" then
    self:_set_tool(Constants.BLUEPRINT.DOOR)
  elseif key == "escape" then
    self:_set_tool("inspect")
  elseif key == "m" then
    self.simulation:enqueue("trigger_meteor")
  elseif key == "f1" then
    self.ui:toggle_help()
  elseif key == "f5" then
    self.simulation:flush_commands()
    local ok, result = self.save_store:save(self.simulation)
    self.ui:set_notification(
      ok and "Saved: " .. result or "Save failed: " .. tostring(result),
      self.now,
      5
    )
  elseif key == "f9" then
    local loaded, result = self.save_store:load()
    if loaded then
      self.simulation = loaded
      self.renderer = Renderer.new(loaded.world)
      self.camera:clamp(loaded.world)
      self.ui:set_notification("Loaded tick " .. loaded.tick, self.now, 5)
    else
      self.ui:set_notification("Load failed: " .. tostring(result), self.now, 5)
    end
  end
end

function App:keyreleased(key)
  self.held_keys[key] = nil
end

function App:mousepressed(x, y, button)
  if button == 2 then
    self:_set_tool("inspect")
    return
  elseif button == 3 then
    self.dragging_camera = true
    return
  elseif button ~= 1 or self.ui:is_over_ui(x, y) then
    return
  end

  local tile_x, tile_y = self.camera:screen_to_tile(x, y, self.simulation.world)
  if not tile_x then
    return
  end
  if self.ui.selected_tool == "inspect" then
    self.renderer:set_selection(tile_x, tile_y)
    self.ui:set_selected_tile(tile_x, tile_y)
    local index = self.simulation.world:index(tile_x, tile_y)
    local structure = self.simulation.world.structure[index]
    if structure == Constants.STRUCTURE.DOOR_CLOSED
      or structure == Constants.STRUCTURE.DOOR_OPEN
    then
      self.simulation:enqueue("toggle_door", { x = tile_x, y = tile_y })
    end
  else
    self.painting = true
    self.last_painted_index = false
    self:_enqueue_blueprint_at(x, y)
  end
end

function App:mousereleased(_, _, button)
  if button == 1 then
    self.painting = false
    self.last_painted_index = false
  elseif button == 3 then
    self.dragging_camera = false
  end
end

function App:mousemoved(_, _, dx, dy)
  if self.dragging_camera then
    self.camera:pan(-dx, -dy)
  end
end

function App:wheelmoved(_, y)
  if y == 0 then
    return
  end
  local mouse_x, mouse_y = love.mouse.getPosition()
  local factor = y > 0 and 2 or 0.5
  self.camera:set_zoom(
    self.camera.zoom * factor,
    mouse_x,
    mouse_y,
    self.simulation.world
  )
end

function App:quit()
  return false
end

return App
