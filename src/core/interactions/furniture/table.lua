local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Table = {
  profiles = { "goon-table-v1" },
}

local function action(id, handler, tool, duration, source)
  return {
    id = id,
    handler = handler,
    implemented = true,
    range = "adjacent",
    duration_ds = duration or 0,
    requires = tool and {
      tools_any = { tool },
      unoccupied = true,
    } or {},
    parameters = {},
    source_symbol = source,
    tags = { "furniture", "npc", "structure" },
  }
end

Table.actions = {
  ["goon-table-v1"] = {
    action(
      "dismantle-table",
      "table.dismantle",
      "wrench",
      30,
      "/obj/table/attackby"
    ),
    action("flip-table", "table.flip", nil, 0, "/obj/table/attack_hand"),
    action("inspect", "common.inspect", nil, 0, "/obj/table/get_desc"),
  },
}

function Table.dynamic_gate(_, target)
  if not target.world:has_feature(target.index, Constants.FEATURE.TABLE) then
    return false, Shared.rejection("invalid-target-state")
  end
  return true
end

Table.handlers = {
  ["table.dismantle"] = function(_, target)
    return target.world:set_feature(
      target.index,
      Constants.FEATURE.TABLE,
      false
    )
  end,
  ["table.flip"] = function(_, target)
    local state = Shared.state(target.world, target.index, "table", {
      flipped = false,
    })
    state.flipped = not state.flipped
    Shared.touch(target.world, target.index, true)
    return true
  end,
}

return Table
