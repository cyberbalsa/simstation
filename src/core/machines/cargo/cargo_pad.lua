local CargoPad = {
  definition_ids = {
    "org.simstation.core:machine/goon-cargo-pad",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-cargo-pad-v1",
  },
  fixture_kinds = { "cargo_pad" },
}

CargoPad.handlers = {
  ["cargo-pad.toggle"] = function(_, machine)
    machine.data.active = not machine.data.active
    return true
  end,
}

return CargoPad
