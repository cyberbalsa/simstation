function love.conf(t)
  t.identity = "simstation"
  t.version = "11.5"
  t.console = false
  t.gammacorrect = false

  t.window.title = "Sim Station — Foundation"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 960
  t.window.minheight = 540
  t.window.resizable = true
  t.window.vsync = 1
  t.window.highdpi = true
  -- Keep graphics, resize, and pointer coordinates in LÖVE's shared
  -- DPI-scaled units; the camera preserves square 32px source cells and
  -- snaps its transform before LÖVE applies the platform backing scale.
  t.window.usedpiscale = true

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
end
