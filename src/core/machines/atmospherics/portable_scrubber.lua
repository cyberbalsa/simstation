local Stable = require("src.core.stable")

local Scrubber = {
  definition_ids = {
    "org.simstation.core:machine/goon-portable-scrubber",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-portable-scrubber-v1",
  },
  fixture_kinds = { "portable_scrubber", "scrubber" },
}

Scrubber.handlers = {
  ["portable-scrubber.set-power"] =
    function(simulation, machine, _, parameters)
      machine.data.on = parameters.value
      simulation._machine_power_dirty = true
      return true
    end,
  ["portable-scrubber.set-flow"] =
    function(simulation, machine, _, parameters)
      machine.data.flow_percent =
        Stable.clamp(parameters.value, 0, 100)
      simulation._machine_power_dirty = true
      return true
    end,
}

function Scrubber.power_request(machine, request)
  if not machine.data.on then
    return 0
  end
  return request + (machine.data.flow_percent or 0) * 10
end

function Scrubber.refresh_state(machine)
  return machine.data.on and "working" or "idle"
end

return Scrubber
