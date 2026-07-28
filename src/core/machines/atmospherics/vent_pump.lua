local VentPump = {
  definition_ids = {
    "org.simstation.core:machine/goon-vent-pump",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-vent-pump-v1",
  },
  fixture_kinds = { "vent_pump" },
}

VentPump.handlers = {
  ["vent-pump.set-power"] = function(_, machine, _, parameters)
    machine.data.on = parameters.value
    return true
  end,
  ["vent-pump.set-direction"] = function(_, machine, _, parameters)
    machine.data.pump_direction = parameters.value
    return true
  end,
  ["vent-pump.set-external-bound"] =
    function(_, machine, _, parameters)
      machine.data.external_pressure_bound_pa = parameters.value
      return true
    end,
  ["vent-pump.set-internal-bound"] =
    function(_, machine, _, parameters)
      machine.data.internal_pressure_bound_pa = parameters.value
      return true
    end,
}

function VentPump.refresh_state(machine)
  return machine.data.on and "working" or "idle"
end

return VentPump
