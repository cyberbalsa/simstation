local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Floor = {
  profiles = {
    "goon-floor-v1",
    "goon-plating-v1",
    "goon-reinforced-floor-v1",
  },
}

local function action(id, handler, tool, duration_ds, source_symbol)
  return {
    id = id,
    handler = handler,
    implemented = true,
    range = id == "inspect" and "adjacent" or "adjacent",
    duration_ds = duration_ds or 0,
    requires = tool and {
      tools_any = { tool },
      unoccupied = id ~= "inspect",
    } or {},
    parameters = {},
    source_symbol = source_symbol,
    tags = { "npc", "turf" },
  }
end

Floor.actions = {
  ["goon-floor-v1"] = {
    action(
      "inspect",
      "common.inspect",
      nil,
      0,
      "/turf/simulated/floor/get_desc"
    ),
    action(
      "pry-floor",
      "floor.pry",
      "crowbar",
      0,
      "/turf/simulated/floor/proc/pry_tile"
    ),
  },
  ["goon-plating-v1"] = {
    action(
      "inspect",
      "common.inspect",
      nil,
      0,
      "/turf/simulated/floor/get_desc"
    ),
    action(
      "place-floor",
      "floor.place",
      "floor_tile",
      0,
      "/turf/simulated/floor/attackby"
    ),
    action(
      "reinforce-floor",
      "floor.reinforce",
      "rods",
      30,
      "/turf/simulated/floor/proc/reinforce"
    ),
  },
  ["goon-reinforced-floor-v1"] = {
    action(
      "inspect",
      "common.inspect",
      nil,
      0,
      "/turf/simulated/floor/get_desc"
    ),
    {
      id = "remove-floor-reinforcement",
      handler = "floor.remove-reinforcement",
      implemented = true,
      range = "adjacent",
      duration_ds = 30,
      requires = {
        tools_any = { "welder", "wrench" },
        unoccupied = true,
      },
      parameters = {},
      source_symbol = "/turf/simulated/floor/proc/remove_reinforcement",
      tags = { "construction", "npc", "turf" },
    },
  },
}

function Floor.dynamic_gate(_, target, action_record)
  local kind = target.world.turf_kind[target.index]
  if action_record.id == "pry-floor" and kind ~= Constants.TURF.FLOOR then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "place-floor"
    and kind ~= Constants.TURF.PLATING
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "reinforce-floor"
    and kind ~= Constants.TURF.PLATING
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "remove-floor-reinforcement"
    and kind ~= Constants.TURF.REINFORCED_FLOOR
  then
    return false, Shared.rejection("invalid-target-state")
  end
  return true
end

Floor.handlers = {
  ["floor.pry"] = function(_, target)
    target.world.turf_kind[target.index] = Constants.TURF.PLATING
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["floor.place"] = function(_, target)
    target.world.turf_kind[target.index] = Constants.TURF.FLOOR
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["floor.reinforce"] = function(_, target)
    target.world.turf_kind[target.index] = Constants.TURF.REINFORCED_FLOOR
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["floor.remove-reinforcement"] = function(_, target)
    target.world.turf_kind[target.index] = Constants.TURF.PLATING
    Shared.touch(target.world, target.index, false)
    return true
  end,
}

return Floor
