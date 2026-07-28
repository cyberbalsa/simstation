local MODULES = {
  require("src.core.interactions.fixtures.light"),
  require("src.core.interactions.furniture.chair"),
  require("src.core.interactions.furniture.table"),
  require("src.core.interactions.infrastructure.passive"),
  require("src.core.interactions.storage.container"),
  require("src.core.interactions.structures.airlock"),
  require("src.core.interactions.structures.grille"),
  require("src.core.interactions.structures.window"),
  require("src.core.interactions.turfs.floor"),
  require("src.core.interactions.turfs.wall"),
}

local Registry = {
  modules = MODULES,
  by_profile = {},
  handlers = {},
}

for module_index = 1, #MODULES do
  local module = MODULES[module_index]
  for profile_index = 1, #(module.profiles or {}) do
    local profile = module.profiles[profile_index]
    assert(not Registry.by_profile[profile],
      "duplicate interaction profile: " .. profile)
    Registry.by_profile[profile] = module
  end
  for handler_id, handler in pairs(module.handlers or {}) do
    assert(not Registry.handlers[handler_id],
      "duplicate interaction handler: " .. handler_id)
    Registry.handlers[handler_id] = handler
  end
end

function Registry.for_profile(profile)
  return Registry.by_profile[profile]
end

function Registry.fallback_actions(profile)
  local module = Registry.for_profile(profile)
  return module and module.actions and module.actions[profile] or {}
end

function Registry.handler(handler_id)
  return Registry.handlers[handler_id]
end

return Registry
