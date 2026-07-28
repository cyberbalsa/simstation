local App = require("src.app")

local app

local function has_argument(args, wanted)
  for i = 1, #(args or {}) do
    if args[i] == wanted then
      return true
    end
  end
  return false
end

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  love.graphics.setLineStyle("rough")
  if has_argument(args, "--self-test") then
    local SelfTest = require("tests.love_selftest")
    local ok, err = xpcall(SelfTest.run, debug.traceback)
    if not ok then
      io.stderr:write(tostring(err), "\n")
      love.event.quit(1)
    else
      love.event.quit(0)
    end
    return
  end
  app = App.new(args or {})
end

function love.update(dt)
  if app then
    app:update(dt)
  end
end

function love.draw()
  if app then
    app:draw()
  end
end

function love.resize(width, height)
  if app then
    app:resize(width, height)
  end
end

function love.keypressed(key, scancode, is_repeat)
  if app then
    app:keypressed(key, scancode, is_repeat)
  end
end

function love.keyreleased(key, scancode)
  if app then
    app:keyreleased(key, scancode)
  end
end

function love.mousepressed(x, y, button, is_touch, presses)
  if app then
    app:mousepressed(x, y, button, is_touch, presses)
  end
end

function love.mousereleased(x, y, button, is_touch, presses)
  if app then
    app:mousereleased(x, y, button, is_touch, presses)
  end
end

function love.mousemoved(x, y, dx, dy, is_touch)
  if app then
    app:mousemoved(x, y, dx, dy, is_touch)
  end
end

function love.wheelmoved(x, y)
  if app then
    app:wheelmoved(x, y)
  end
end

function love.quit()
  if app then
    return app:quit()
  end
end
