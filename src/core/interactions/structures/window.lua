local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Window = {
  profiles = { "goon-window-v1" },
}

local function action(id, handler, tool, duration, source)
  return {
    id = id,
    handler = handler,
    implemented = true,
    range = "adjacent",
    duration_ds = duration or 0,
    requires = tool and { tools_any = { tool } } or {},
    parameters = {},
    source_symbol = source,
    tags = { "npc", "structure", "window" },
  }
end

Window.actions = {
  ["goon-window-v1"] = {
    action(
      "dismantle-window",
      "window.dismantle",
      "wrench",
      30,
      "/obj/window/attackby"
    ),
    action("inspect", "common.inspect", nil, 0, "/obj/window/get_desc"),
    action("knock-window", "window.knock", nil, 0, "/obj/window/attack_hand"),
    action(
      "pry-window",
      "window.pry",
      "crowbar",
      20,
      "/obj/window/proc/assembly_handler"
    ),
    action(
      "repair-window",
      "window.repair",
      "glass_sheet",
      40,
      "/obj/window/proc/fix_window"
    ),
    action(
      "toggle-window-fasteners",
      "window.toggle-fasteners",
      "screwdriver",
      20,
      "/obj/window/proc/assembly_handler"
    ),
  },
}

local DEFAULT_STATE = {
  anchored = true,
  destroyed = false,
  health = 30,
  maximum = 30,
  pane_in_frame = true,
}

function Window.dynamic_gate(_, target, action_record)
  local world = target.world
  if not world:has_feature(target.index, Constants.FEATURE.WINDOW) then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(world, target.index, "window", DEFAULT_STATE)
  if state.destroyed and action_record.id ~= "inspect" then
    return false, Shared.rejection("destroyed")
  elseif action_record.id == "dismantle-window"
    and (state.anchored or state.pane_in_frame)
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "repair-window"
    and (state.health or state.maximum) >= (state.maximum or 30)
  then
    return false, Shared.rejection("invalid-target-state")
  end
  return true
end

Window.handlers = {
  ["window.dismantle"] = function(_, target)
    local removed, reason = target.world:set_feature(
      target.index,
      Constants.FEATURE.WINDOW,
      false
    )
    if not removed then
      return false, reason
    end
    -- Native maps represent full-tile windows through the legacy wall slot.
    -- Removing the final frame therefore releases that adapted boundary while
    -- preserving any colocated grille feature.
    if target.world.structure[target.index] == Constants.STRUCTURE.WALL then
      return target.world:set_wall_kind(
        target.index,
        Constants.WALL.NONE
      )
    end
    return true
  end,
  ["window.knock"] = function()
    return true
  end,
  ["window.pry"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "window",
      DEFAULT_STATE
    )
    state.pane_in_frame = not state.pane_in_frame
    Shared.touch(target.world, target.index, true)
    return true
  end,
  ["window.repair"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "window",
      DEFAULT_STATE
    )
    state.health = state.maximum
    state.destroyed = false
    Shared.touch(target.world, target.index, true)
    return true
  end,
  ["window.toggle-fasteners"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "window",
      DEFAULT_STATE
    )
    state.anchored = not state.anchored
    Shared.touch(target.world, target.index, true)
    return true
  end,
}

return Window
