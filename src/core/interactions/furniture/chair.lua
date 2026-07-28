local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Chair = {
  profiles = { "goon-chair-v1" },
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

Chair.actions = {
  ["goon-chair-v1"] = {
    action(
      "dismantle-chair",
      "chair.dismantle",
      "wrench",
      0,
      "/obj/stool/attackby"
    ),
    action("inspect", "common.inspect", nil, 0, "/obj/stool/chair/get_desc"),
    action("leave-chair", "chair.leave", nil, 0, "/obj/stool/chair/unbuckle"),
    action("rotate-chair", "chair.rotate", nil, 0, "/obj/stool/chair/rotate"),
    action("sit-chair", "chair.sit", nil, 0, "/obj/stool/chair/buckle_in"),
  },
}

local DEFAULT_STATE = {
  direction = 1,
  occupant_id = false,
}

function Chair.dynamic_gate(_, target, action_record, actor)
  if not target.world:has_feature(target.index, Constants.FEATURE.CHAIR) then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(target.world, target.index, "chair", DEFAULT_STATE)
  if action_record.id == "sit-chair" and state.occupant_id then
    return false, Shared.rejection("occupied")
  elseif action_record.id == "leave-chair"
    and state.occupant_id ~= (actor and actor.id)
  then
    return false, Shared.rejection("invalid-target-state")
  elseif action_record.id == "dismantle-chair" and state.occupant_id then
    return false, Shared.rejection("occupied")
  end
  return true
end

Chair.handlers = {
  ["chair.dismantle"] = function(_, target)
    return target.world:set_feature(
      target.index,
      Constants.FEATURE.CHAIR,
      false
    )
  end,
  ["chair.leave"] = function(_, target, actor)
    local state = Shared.state(
      target.world,
      target.index,
      "chair",
      DEFAULT_STATE
    )
    state.occupant_id = false
    if actor then
      actor.buckled_to = false
    end
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["chair.rotate"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "chair",
      DEFAULT_STATE
    )
    state.direction = state.direction % 4 + 1
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["chair.sit"] = function(_, target, actor)
    local state = Shared.state(
      target.world,
      target.index,
      "chair",
      DEFAULT_STATE
    )
    state.occupant_id = actor.id
    actor.index = target.index
    actor.buckled_to = {
      component = "chair",
      index = target.index,
    }
    Shared.touch(target.world, target.index, false)
    return true
  end,
}

return Chair
