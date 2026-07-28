local Shared = require("src.core.machines.shared")

local Apc = {
  definition_ids = {
    "org.simstation.core:machine/goon-apc",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-apc-v1",
  },
  fixture_kinds = { "apc" },
}

function Apc.initialize(_, machine, fixture)
  if (fixture.source_path or ""):find("/noaicontrol", 1, true) then
    machine.data.aidisabled = true
    machine.data.ai_hardened = true
    machine.data.noalerts = true
  end
end

function Apc.gate(_, machine, action, actor_is_remote)
  local handler = action.handler
  if handler == "apc.set-cover-lock"
    or handler == "apc.set-operating"
    or handler == "apc.set-charge-mode"
    or handler == "apc.set-channel"
  then
    if actor_is_remote then
      if machine.data.aidisabled then
        return false, Shared.rejection("remote-disabled")
      end
    elseif machine.data.locked then
      return false, Shared.rejection("interface-locked")
    end
  end
  return true
end

local function swipe_id(_, machine)
  if machine.data.opened then
    return false, Shared.rejection("cover-open")
  elseif machine.data.wiresexposed then
    return false, Shared.rejection("panel-open")
  elseif (machine.data.setup_networkapc or 1) > 1 then
    return false, Shared.rejection("remote-only-interface")
  elseif machine.data.emagged then
    return false, Shared.rejection("interface-broken")
  end
  machine.data.locked = not machine.data.locked
  return true
end

local function pry_cover(_, machine)
  if not machine.data.opened and machine.data.coverlocked then
    return false, Shared.rejection("cover-locked")
  end
  machine.data.opened = not machine.data.opened
  return true
end

local function toggle_wire_panel(_, machine)
  if machine.data.opened then
    return false, Shared.rejection("cover-open")
  elseif machine.data.emagged then
    return false, Shared.rejection("interface-broken")
  end
  machine.data.wiresexposed = not machine.data.wiresexposed
  return true
end

local function set_cover_lock(_, machine, _, parameters)
  machine.data.coverlocked = parameters.value
  return true
end

local function set_operating(_, machine, _, parameters)
  machine.data.operating = parameters.value
  return true
end

local function set_charge_mode(_, machine, _, parameters)
  machine.data.chargemode = parameters.value
  if not parameters.value then
    machine.data.charging = 0
  end
  return true
end

local function set_channel(_, machine, _, parameters)
  if (not machine.data.cell_present or machine.data.shorted)
    and parameters.value > 1
  then
    return false, Shared.rejection("insufficient-charge")
  end
  local field = parameters.channel == "environment" and "environ"
    or parameters.channel
  machine.data[field] = parameters.value
  return true
end

Apc.handlers = {
  ["apc.swipe-id"] = swipe_id,
  ["apc.pry-cover"] = pry_cover,
  ["apc.toggle-wire-panel"] = toggle_wire_panel,
  ["apc.set-cover-lock"] = set_cover_lock,
  ["apc.set-operating"] = set_operating,
  ["apc.set-charge-mode"] = set_charge_mode,
  ["apc.set-channel"] = set_channel,
}

function Apc.wire_effect(simulation, machine, wire, operation)
  local data = machine.data
  if operation == "cut" then
    if wire.id == "main-power-1" or wire.id == "main-power-2" then
      data.shorted = true
    elseif wire.id == "ai-control" then
      data.aidisabled = true
    end
  elseif operation == "mend" then
    if wire.id == "main-power-1" or wire.id == "main-power-2" then
      local first = Shared.wire_by_key(machine, "main-power-1")
      local second = Shared.wire_by_key(machine, "main-power-2")
      if first and first.intact and second and second.intact then
        data.shorted = false
        data.shorted_until_ds = 0
      end
    elseif wire.id == "ai-control" and not data.ai_hardened then
      data.aidisabled = false
      data.ai_disabled_until_ds = 0
    end
  elseif operation == "pulse" then
    if wire.id == "id-scan" then
      data.locked = false
      data.unlock_until_ds = simulation.machine_time_ds + 300
    elseif wire.id == "main-power-1" or wire.id == "main-power-2" then
      data.shorted = true
      data.shorted_until_ds = simulation.machine_time_ds + 1200
    elseif wire.id == "ai-control" then
      data.aidisabled = true
      data.ai_disabled_until_ds = simulation.machine_time_ds + 10
    end
  end
end

function Apc.process(_, machine)
  local data = machine.data
  local capacity = math.max(1, data.cell_capacity or 2500)
  local percent = math.floor((data.cell_charge or 0) * 100 / capacity)
  if percent <= 0 then
    if data.equipment == 3 then data.equipment = 1 end
    if data.lighting == 3 then data.lighting = 1 end
    if data.environ == 3 then data.environ = 1 end
  elseif percent < 15 then
    if data.equipment == 3 then data.equipment = 1 end
    if data.lighting == 3 then data.lighting = 1 end
    if data.environ == 1 then data.environ = 3 end
  elseif percent < 30 then
    if data.equipment == 3 then data.equipment = 1 end
    if data.lighting == 1 then data.lighting = 3 end
    if data.environ == 1 then data.environ = 3 end
  else
    if data.equipment == 1 then data.equipment = 3 end
    if data.lighting == 1 then data.lighting = 3 end
    if data.environ == 1 then data.environ = 3 end
  end
end

function Apc.delayed(_, machine, now_ds)
  local data = machine.data
  if data.unlock_until_ds and data.unlock_until_ds > 0
    and now_ds >= data.unlock_until_ds
  then
    data.locked = true
    data.unlock_until_ds = 0
  end
  if data.shorted_until_ds and data.shorted_until_ds > 0
    and now_ds >= data.shorted_until_ds
  then
    local first = Shared.wire_by_key(machine, "main-power-1")
    local second = Shared.wire_by_key(machine, "main-power-2")
    data.shorted = not (
      first and first.intact and second and second.intact
    )
    data.shorted_until_ds = 0
  end
  if data.ai_disabled_until_ds and data.ai_disabled_until_ds > 0
    and now_ds >= data.ai_disabled_until_ds
  then
    if not data.ai_hardened then
      data.aidisabled = false
    end
    data.ai_disabled_until_ds = 0
  end
end

return Apc
