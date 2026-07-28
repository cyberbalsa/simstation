local Stable = require("src.core.stable")

local Circulator = {
  definition_ids = {
    "org.simstation.core:machine/goon-teg-circulator",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-teg-circulator-v1",
  },
  fixture_kinds = { "circulator" },
}

Circulator.handlers = {
  ["circulator.toggle-override"] = function(_, machine)
    machine.data.pressure_override = not machine.data.pressure_override
    return true
  end,
  ["circulator.set-pressure"] = function(_, machine, _, parameters)
    machine.data.target_pressure_pa =
      Stable.clamp(parameters.value, 75000, 100000000)
    return true
  end,
}

return Circulator
