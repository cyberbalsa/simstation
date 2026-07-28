local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Wall = {
  profiles = {
    "goon-wall-v1",
    "goon-reinforced-wall-v1",
  },
}

local function inspect(source_symbol)
  return {
    id = "inspect",
    handler = "common.inspect",
    implemented = true,
    range = "adjacent",
    duration_ds = 0,
    requires = {},
    parameters = {},
    source_symbol = source_symbol,
    tags = { "npc", "turf" },
  }
end

Wall.actions = {
  ["goon-wall-v1"] = {
    {
      id = "dismantle-wall",
      handler = "wall.dismantle",
      implemented = true,
      range = "adjacent",
      duration_ds = 100,
      requires = {
        tools_any = { "welder" },
        unoccupied = true,
      },
      parameters = {},
      source_symbol = "/turf/simulated/wall/proc/weld_action",
      tags = { "construction", "npc", "turf" },
    },
    inspect("/turf/simulated/wall/get_desc"),
    {
      id = "repair-wall",
      handler = "wall.repair",
      implemented = true,
      range = "adjacent",
      duration_ds = 20,
      requires = { tools_any = { "welder" } },
      parameters = {},
      source_symbol = "/turf/simulated/wall/attackby",
      tags = { "maintenance", "npc", "turf" },
    },
  },
  ["goon-reinforced-wall-v1"] = {
    inspect("/turf/simulated/wall/get_desc"),
    {
      id = "repair-wall",
      handler = "wall.repair",
      implemented = true,
      range = "adjacent",
      duration_ds = 100,
      requires = { tools_any = { "metal_sheet" } },
      parameters = {},
      source_symbol = "/turf/simulated/wall/r_wall/attackby",
      tags = { "maintenance", "npc", "turf" },
    },
  },
}

function Wall.dynamic_gate(_, target, action_record)
  local world = target.world
  if world.structure[target.index] ~= Constants.STRUCTURE.WALL then
    return false, Shared.rejection("invalid-target-state")
  end
  if action_record.id == "dismantle-wall"
    and world.wall_kind[target.index] ~= Constants.WALL.STANDARD
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "repair-wall" then
    local health = world.structure_health[target.index] or 0
    local maximum = world.structure_max_health[target.index] or 0
    if health <= 0 or maximum <= 0 or health >= maximum then
      return false, Shared.rejection("invalid-target-state")
    end
  end
  return true
end

Wall.handlers = {
  ["wall.dismantle"] = function(_, target)
    return target.world:set_wall_kind(target.index, Constants.WALL.NONE)
  end,
  ["wall.repair"] = function(_, target)
    return target.world:repair_structure(target.index, 1000000)
  end,
}

return Wall
