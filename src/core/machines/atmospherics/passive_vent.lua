-- Passive vents intentionally have no powered "fill room" behavior. Their
-- conservative pipe/reservoir exchange is tracked as deferred in content.
return {
  definition_ids = {
    "org.simstation.core:machine/goon-passive-vent",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-passive-vent-v1",
  },
  fixture_kinds = { "vent" },
  handlers = {},
}
