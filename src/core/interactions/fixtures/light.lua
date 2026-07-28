local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Light = {
  profiles = { "goon-light-v1" },
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
    tags = { "fixture", "light", "npc" },
  }
end

Light.actions = {
  ["goon-light-v1"] = {
    action(
      "inspect",
      "common.inspect",
      nil,
      0,
      "/obj/machinery/light/get_desc"
    ),
    action(
      "remove-light",
      "light.remove",
      "screwdriver",
      0,
      "/obj/machinery/light/attack_hand"
    ),
    action(
      "replace-light",
      "light.replace",
      "light_bulb",
      0,
      "/obj/machinery/light/attackby"
    ),
    action(
      "toggle-light",
      "light.toggle",
      nil,
      0,
      "/obj/machinery/light/lamp/attack_hand"
    ),
  },
}

local DEFAULT_STATE = {
  broken = false,
  installed = true,
  on = true,
}

function Light.dynamic_gate(_, target, action_record)
  if not target.world:has_feature(target.index, Constants.FEATURE.LIGHT) then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(target.world, target.index, "light", DEFAULT_STATE)
  if action_record.id == "remove-light" and not state.installed then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "replace-light"
    and state.installed
    and not state.broken
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "toggle-light" then
    if not state.installed or state.broken then
      return false, Shared.rejection("invalid-target-state")
    elseif not target.world.powered[target.index] and not state.on then
      return false, Shared.rejection("unpowered")
    end
  end
  return true
end

Light.handlers = {
  ["light.remove"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "light",
      DEFAULT_STATE
    )
    state.installed = false
    state.on = false
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["light.replace"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "light",
      DEFAULT_STATE
    )
    state.installed = true
    state.broken = false
    state.on = target.world.powered[target.index] == true
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["light.toggle"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "light",
      DEFAULT_STATE
    )
    state.on = not state.on
    Shared.touch(target.world, target.index, false)
    return true
  end,
}

return Light
