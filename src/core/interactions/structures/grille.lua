local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Grille = {
  profiles = { "goon-grille-v1" },
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
    tags = { "grille", "npc", "structure" },
  }
end

Grille.actions = {
  ["goon-grille-v1"] = {
    action(
      "cut-grille",
      "grille.cut",
      "wirecutters",
      0,
      "/obj/mesh/grille/attackby"
    ),
    action("inspect", "common.inspect", nil, 0, "/obj/mesh/grille/get_desc"),
    action(
      "repair-grille",
      "grille.repair",
      "rods",
      20,
      "/obj/mesh/attackby"
    ),
  },
}

local DEFAULT_STATE = {
  destroyed = false,
  health = 30,
  maximum = 30,
}

function Grille.dynamic_gate(_, target, action_record)
  if not target.world:has_feature(target.index, Constants.FEATURE.GRILLE) then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(
    target.world,
    target.index,
    "grille",
    DEFAULT_STATE
  )
  if action_record.id == "cut-grille" and state.destroyed then
    return false, Shared.rejection("destroyed")
  elseif action_record.id == "repair-grille" and not state.destroyed then
    return false, Shared.rejection("invalid-target-state")
  end
  return true
end

Grille.handlers = {
  ["grille.cut"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "grille",
      DEFAULT_STATE
    )
    state.destroyed = true
    state.health = 0
    Shared.touch(target.world, target.index, true)
    return true
  end,
  ["grille.repair"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "grille",
      DEFAULT_STATE
    )
    state.destroyed = false
    state.health = state.maximum
    Shared.touch(target.world, target.index, true)
    return true
  end,
}

return Grille
