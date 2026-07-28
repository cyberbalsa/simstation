local Constants = require("src.core.constants")
local Shared = require("src.core.interactions.shared")

local Storage = {
  profiles = {
    "goon-crate-v1",
    "goon-storage-v1",
  },
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
    tags = { "npc", "storage", "structure" },
  }
end

local ACTIONS = {
  action(
    "close-storage",
    "storage.close",
    nil,
    0,
    "/obj/storage/proc/close"
  ),
  action(
    "inspect",
    "common.inspect",
    nil,
    0,
    "/obj/storage/get_desc"
  ),
  action(
    "open-storage",
    "storage.open",
    nil,
    0,
    "/obj/storage/proc/open"
  ),
  action(
    "pry-storage",
    "storage.pry",
    "crowbar",
    10,
    "/obj/storage/proc/pry_open"
  ),
  action(
    "weld-storage",
    "storage.weld",
    "welder",
    20,
    "/obj/storage/proc/weld_action"
  ),
}

Storage.actions = {
  ["goon-crate-v1"] = ACTIONS,
  ["goon-storage-v1"] = ACTIONS,
}

local DEFAULT_STATE = {
  locked = false,
  open = false,
  pried_open = false,
  welded = false,
}

function Storage.dynamic_gate(_, target, action_record, actor)
  local world = target.world
  if not world:has_feature(target.index, Constants.FEATURE.STORAGE)
    and not world:has_feature(target.index, Constants.FEATURE.CRATE)
  then
    return false, Shared.rejection("invalid-target-state")
  end
  local state = Shared.peek(world, target.index, "storage", DEFAULT_STATE)
  if action_record.id == "open-storage" then
    if state.open then
      return false, Shared.rejection("invalid-target-state")
    elseif state.welded then
      return false, Shared.rejection("welded")
    elseif state.locked then
      return false, Shared.rejection("access-denied")
    end
  elseif action_record.id == "close-storage" then
    if not state.open then
      return false, Shared.rejection("invalid-target-state")
    elseif state.pried_open then
      return false, Shared.rejection("invalid-target-state")
    end
  elseif action_record.id == "pry-storage" then
    if state.open then
      return false, Shared.rejection("invalid-target-state")
    elseif state.welded then
      return false, Shared.rejection("welded")
    elseif not state.locked then
      return false, Shared.rejection("invalid-target-state")
    end
  elseif action_record.id == "weld-storage" and state.open then
    return false, Shared.rejection("invalid-target-state")
  end
  if state.locked
    and action_record.id == "open-storage"
    and Shared.actor_has_access(actor, world.door_access[target.index])
  then
    return true
  end
  return true
end

Storage.handlers = {
  ["storage.close"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "storage",
      DEFAULT_STATE
    )
    state.open = false
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["storage.open"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "storage",
      DEFAULT_STATE
    )
    state.open = true
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["storage.pry"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "storage",
      DEFAULT_STATE
    )
    state.locked = false
    state.open = true
    state.pried_open = true
    Shared.touch(target.world, target.index, false)
    return true
  end,
  ["storage.weld"] = function(_, target)
    local state = Shared.state(
      target.world,
      target.index,
      "storage",
      DEFAULT_STATE
    )
    state.welded = not state.welded
    Shared.touch(target.world, target.index, false)
    return true
  end,
}

return Storage
