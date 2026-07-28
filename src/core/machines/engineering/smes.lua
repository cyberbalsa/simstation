local Stable = require("src.core.stable")

local Smes = {
  definition_ids = {
    "org.simstation.core:machine/goon-smes",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-smes-v1",
  },
  fixture_kinds = { "battery" },
}

local function toggle_input(_, machine)
  machine.data.chargemode = not machine.data.chargemode
  if not machine.data.chargemode then
    machine.data.charging = false
  end
  return true
end

local function toggle_output(_, machine)
  machine.data.online = not machine.data.online
  return true
end

local function set_input(_, machine, _, parameters)
  machine.data.chargelevel = Stable.clamp(parameters.value, 0, 200000)
  return true
end

local function set_output(_, machine, _, parameters)
  machine.data.output = Stable.clamp(parameters.value, 0, 200000)
  return true
end

Smes.handlers = {
  ["smes.toggle-input"] = toggle_input,
  ["smes.toggle-output"] = toggle_output,
  ["smes.set-input"] = set_input,
  ["smes.set-output"] = set_output,
}

function Smes.process(simulation, machine)
  local data = machine.data
  if machine.status.broken or not data.terminal_present then
    data.online = false
    data.charging = false
    machine.status.power_off = not data.terminal_present
    return
  end
  local surplus = math.max(
    0,
    simulation.world.power_supply_w - simulation.world.power_demand_w
  )
  if data.charging then
    local load = math.min(
      data.capacity - data.charge,
      data.chargelevel,
      surplus
    )
    data.charge = data.charge + math.max(0, load)
    data.lastexcess = surplus
  elseif data.chargemode then
    if data.chargecount > 2 then
      data.charging = true
      data.chargecount = 0
    elseif surplus >= data.chargelevel then
      data.chargecount = data.chargecount + 1
    else
      data.chargecount = 0
    end
  end
  if data.online then
    data.lastout = math.min(data.charge, data.output)
    data.charge = data.charge - data.lastout
    data.loaddemand = data.lastout
    if data.charge <= 0 then
      data.charge = 0
      data.online = false
    end
  else
    data.lastout = 0
    data.loaddemand = 0
  end
end

function Smes.refresh_state(machine)
  return machine.data.online and "online" or "offline"
end

return Smes
