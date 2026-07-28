local Passive = {
  profiles = {
    "goon-catwalk-v1",
    "goon-decal-v1",
    "goon-disposal-v1",
    "goon-lattice-v1",
    "goon-pipe-v1",
    "goon-sign-v1",
    "goon-space-v1",
  },
  actions = {},
  handlers = {},
}

for index = 1, #Passive.profiles do
  Passive.actions[Passive.profiles[index]] = {
    {
      id = "inspect",
      handler = "common.inspect",
      implemented = true,
      range = "adjacent",
      duration_ds = 0,
      requires = {},
      parameters = {},
      source_symbol = "/atom/proc/get_desc",
      tags = { "npc", "world" },
    },
  }
end

return Passive
