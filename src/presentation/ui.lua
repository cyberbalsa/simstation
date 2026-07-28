local Constants = require("src.core.constants")

local Ui = {}
Ui.__index = Ui

local TOOL_LABELS = {
  inspect = "Inspect",
  floor = "Floor [F]",
  wall = "Wall [X]",
  cable = "Cable [C]",
  door = "Door [V]",
}

local function format_time(seconds)
  local hour = math.floor(seconds / 3600)
  local minute = math.floor((seconds % 3600) / 60)
  local second = seconds % 60
  return string.format("%02d:%02d:%02d", hour, minute, second)
end

function Ui.new()
  return setmetatable({
    help_visible = true,
    notification = "Foundation loaded",
    notification_until = 6,
    selected_tool = "inspect",
    selected_tile = false,
  }, Ui)
end

function Ui:set_tool(tool)
  self.selected_tool = tool
end

function Ui:set_notification(message, now, duration)
  self.notification = message
  self.notification_until = now + (duration or 4)
end

function Ui:set_selected_tile(x, y)
  self.selected_tile = x and { x = x, y = y } or false
end

function Ui:toggle_help()
  self.help_visible = not self.help_visible
end

function Ui:is_over_ui(_, y)
  return y <= 48
end

function Ui:draw(snapshot, renderer, camera, now)
  local width, height = love.graphics.getDimensions()
  love.graphics.origin()
  love.graphics.setColor(0.025, 0.035, 0.05, 0.96)
  love.graphics.rectangle("fill", 0, 0, width, 48)
  love.graphics.setColor(0.16, 0.22, 0.30, 1)
  love.graphics.rectangle("fill", 0, 47, width, 1)

  local status = snapshot.paused and "PAUSED" or tostring(snapshot.speed) .. "x"
  love.graphics.setColor(0.92, 0.95, 1, 1)
  love.graphics.print(snapshot.station.name, 14, 9)
  love.graphics.setColor(0.60, 0.72, 0.82, 1)
  love.graphics.print(
    string.format(
      "Shift %d  %s  %s",
      snapshot.shift_index,
      format_time(snapshot.seconds_in_shift),
      status
    ),
    14,
    27
  )

  love.graphics.setColor(0.92, 0.95, 1, 1)
  love.graphics.print(
    string.format(
      "¢%d   Materials %d   Power %.1f/%.1f kW",
      snapshot.economy.station_credits,
      snapshot.economy.material_units,
      snapshot.world.power_served_w / 1000,
      snapshot.world.power_demand_w / 1000
    ),
    250,
    17
  )

  local offered, active = 0, 0
  for i = 1, #snapshot.tasks do
    if snapshot.tasks[i].state == "offered" then
      offered = offered + 1
    elseif snapshot.tasks[i].state == "claimed"
      or snapshot.tasks[i].state == "executing"
    then
      active = active + 1
    end
  end
  love.graphics.print(
    string.format(
      "%s   Tasks %d/%d   Grade %s",
      TOOL_LABELS[self.selected_tool],
      active,
      offered,
      snapshot.station.grade
    ),
    width - 330,
    17
  )

  if self.selected_tile then
    local index = snapshot.world:index(
      self.selected_tile.x,
      self.selected_tile.y
    )
    if index then
      local pressure = snapshot.world:pressure_dkpa(index) / 10
      love.graphics.setColor(0.025, 0.035, 0.05, 0.92)
      love.graphics.rectangle("fill", 12, height - 116, 270, 104, 4, 4)
      love.graphics.setColor(0.88, 0.93, 0.98, 1)
      love.graphics.print(
        string.format("Tile %d, %d", self.selected_tile.x, self.selected_tile.y),
        24,
        height - 104
      )
      love.graphics.print(
        string.format("Pressure %.1f kPa", pressure),
        24,
        height - 84
      )
      love.graphics.print(
        string.format(
          "O₂ %.1f%%   Power %s",
          (snapshot.world.o2[index] + snapshot.world.n2[index] > 0)
              and snapshot.world.o2[index]
                / (snapshot.world.o2[index] + snapshot.world.n2[index])
                * 100
            or 0,
          snapshot.world.powered[index] and "yes" or "no"
        ),
        24,
        height - 64
      )
      love.graphics.print(
        "Blueprint: " .. tostring(snapshot.world.blueprint[index] or "none"),
        24,
        height - 44
      )
    end
  end

  local events = snapshot.events
  local event_y = 66
  for i = #events, math.max(1, #events - 4), -1 do
    local event = events[i]
    love.graphics.setColor(0.02, 0.03, 0.04, 0.78)
    love.graphics.rectangle("fill", width - 350, event_y, 336, 25, 3, 3)
    love.graphics.setColor(0.76, 0.84, 0.90, 1)
    love.graphics.print(
      string.format("T+%d  %s", event.tick, event.kind:gsub("_", " ")),
      width - 340,
      event_y + 5
    )
    event_y = event_y + 29
  end

  if now < self.notification_until then
    local text_width = love.graphics.getFont():getWidth(self.notification)
    love.graphics.setColor(0.03, 0.05, 0.07, 0.94)
    love.graphics.rectangle(
      "fill",
      (width - text_width) / 2 - 16,
      height - 54,
      text_width + 32,
      34,
      5,
      5
    )
    love.graphics.setColor(0.90, 0.95, 1, 1)
    love.graphics.print(self.notification, (width - text_width) / 2, height - 45)
  end

  if self.help_visible then
    local panel_width = 500
    local panel_height = 310
    local left = (width - panel_width) / 2
    local top = (height - panel_height) / 2
    love.graphics.setColor(0.02, 0.03, 0.045, 0.96)
    love.graphics.rectangle("fill", left, top, panel_width, panel_height, 8, 8)
    love.graphics.setColor(0.24, 0.36, 0.48, 1)
    love.graphics.rectangle("line", left, top, panel_width, panel_height, 8, 8)
    love.graphics.setColor(0.95, 0.97, 1, 1)
    love.graphics.printf("SIM STATION — FOUNDATION", left, top + 20, panel_width, "center")
    love.graphics.setColor(0.70, 0.80, 0.88, 1)
    local help = table.concat({
      "Run a persistent station without directly controlling crew.",
      "",
      "WASD / middle-drag       Pan camera",
      "Mouse wheel              Zoom 0.25×–4×",
      "Space / 1 / 2 / 4        Pause and speed",
      "F / X / C / V            Floor, wall, cable, door blueprint",
      "Left drag                Place blueprints",
      "Right click / Escape     Inspect",
      "M                        Meteor breach scenario",
      "F5 / F9                  Save / load",
      "F1                       Close this help",
      "",
      "Crew autonomously claim and complete work. Blue overlays mark low",
      "pressure; red marks fire. Goon-derived sprites and sounds are loaded",
      "from compact native LÖVE catalogs with deterministic shape fallbacks.",
    }, "\n")
    love.graphics.printf(help, left + 30, top + 55, panel_width - 60, "left")
  end

  love.graphics.setColor(0.52, 0.62, 0.68, 1)
  love.graphics.print(
    string.format(
      "tick %d  hash %d  chunks %d (+%d)  draws %d  zoom %.2f",
      snapshot.tick,
      snapshot.state_hash,
      renderer.visible_chunks,
      renderer.rebuilt_chunks,
      renderer.last_draw_calls,
      camera.zoom
    ),
    12,
    height - 18
  )
end

return Ui
