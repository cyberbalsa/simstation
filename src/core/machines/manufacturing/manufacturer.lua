local Stable = require("src.core.stable")
local Shared = require("src.core.machines.shared")

local Manufacturer = {
  definition_ids = {
    "org.simstation.core:machine/goon-manufacturer",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-manufacturer-v1",
  },
  fixture_kinds = { "fabricator" },
  machine_tag = "fabricator",
}

local function interrupt(machine, now_ds, reason, halt)
  local data = machine.data
  if data.mode == "working" and data.work_finish_ds > 0 then
    data.time_left_ds = math.max(0, data.work_finish_ds - now_ds)
  end
  data.work_finish_ds = 0
  data.active_power_consumption = 0
  data.paused_reason = reason or false
  data.mode = halt and "halt" or "ready"
  machine.recipe_id = data.queue[1] or false
end

local function begin(simulation, machine, new_production)
  local data = machine.data
  data.error = false
  if machine.status.no_power or machine.status.broken then
    return false, Shared.rejection(
      machine.status.broken and "broken" or "no-power"
    )
  end
  if #data.queue == 0 then
    data.mode = "ready"
    data.work_finish_ds = 0
    data.active_power_consumption = 0
    machine.recipe_id = false
    return true
  end
  local selected_recipe = Shared.recipe(simulation, data.queue[1])
  if not selected_recipe
    or selected_recipe.machine_tag ~= machine.machine_tag
  then
    table.remove(data.queue, 1)
    data.mode = "halt"
    data.error = "corrupt-blueprint"
    machine.recipe_id = false
    return false, Shared.rejection("invalid-blueprint")
  end
  local enough, missing = Shared.enough_inputs(simulation, selected_recipe)
  if not enough then
    data.mode = "halt"
    data.error = "insufficient-materials"
    data.active_power_consumption = 0
    machine.recipe_id = selected_recipe.id
    return false, Shared.rejection("missing-item", { item_id = missing })
  end

  local speed = math.max(1, math.floor(data.speed or 3))
  data.active_power_consumption = 750 * speed * speed
  if data.malfunction then
    data.active_power_consumption = data.active_power_consumption + 3000
  end
  if new_production or not data.time_left_ds or data.time_left_ds <= 0 then
    local base_ds = math.max(
      1,
      math.floor(selected_recipe.duration_ticks or 1) * 10
    )
    data.time_left_ds =
      math.max(1, math.floor((base_ds + speed - 1) / speed))
    data.original_duration_ds = data.time_left_ds
  end
  data.time_started_ds = simulation.machine_time_ds
  data.work_finish_ds = simulation.machine_time_ds + data.time_left_ds
  data.mode = "working"
  data.paused_reason = false
  machine.recipe_id = selected_recipe.id
  simulation._machine_power_dirty = true
  return true
end

local function finish(simulation, machine)
  local data = machine.data
  local selected_recipe = Shared.recipe(simulation, data.queue[1])
  if not selected_recipe then
    interrupt(machine, simulation.machine_time_ds, "invalid-blueprint", true)
    data.error = "corrupt-blueprint"
    return
  end
  local enough, missing = Shared.enough_inputs(simulation, selected_recipe)
  if not enough then
    interrupt(
      machine,
      simulation.machine_time_ds,
      "insufficient-materials",
      true
    )
    data.error = "insufficient-materials"
    simulation:_emit("manufacturing_blocked", {
      machine_id = machine.id,
      recipe_id = selected_recipe.id,
      reason = "missing-item",
      item_id = missing,
    })
    return
  end

  Shared.consume_inputs(simulation, selected_recipe)
  Shared.dispense_outputs(simulation, selected_recipe)
  if not data["repeat"] then
    table.remove(data.queue, 1)
  end
  data.time_left_ds = 0
  data.work_finish_ds = 0
  data.active_power_consumption = 0
  data.mode = "ready"
  data.error = false
  machine.recipe_id = data.queue[1] or false
  simulation.metrics.completed_tasks =
    simulation.metrics.completed_tasks + 1
  simulation:_emit("manufacturing_completed", {
    machine_id = machine.id,
    recipe_id = selected_recipe.id,
  })
  if #data.queue > 0 then
    data.next_begin_ds = simulation.machine_time_ds + 1
  end
  simulation._machine_power_dirty = true
end

local function queue_product(simulation, machine, _, parameters)
  local selected_recipe = Shared.recipe(simulation, parameters.recipe_id)
  if not selected_recipe
    or selected_recipe.machine_tag ~= machine.machine_tag
  then
    return false, Shared.rejection("invalid-blueprint")
  end
  local enough, missing = Shared.enough_inputs(simulation, selected_recipe)
  if not enough then
    return false, Shared.rejection("missing-item", { item_id = missing })
  end
  if #machine.data.queue >= 20 then
    return false, Shared.rejection("queue-full", { maximum = 20 })
  end
  machine.data.queue[#machine.data.queue + 1] = selected_recipe.id
  machine.recipe_id = machine.data.queue[1]
  if machine.data.mode == "ready" and #machine.data.queue == 1 then
    local started, start_error = begin(simulation, machine, true)
    if not started then
      return false, start_error
    end
  end
  simulation:_emit("manufacturing_queued", {
    machine_id = machine.id,
    recipe_id = selected_recipe.id,
    queue_length = #machine.data.queue,
  })
  return true
end

local function set_speed(_, machine, _, parameters)
  local maximum = machine.data.hacked and 5 or 3
  machine.data.speed = Stable.clamp(parameters.value, 1, maximum)
  return true
end

local function toggle_repeat(_, machine)
  machine.data["repeat"] = not machine.data["repeat"]
  return true
end

local function pause(simulation, machine)
  interrupt(machine, simulation.machine_time_ds, "operator-paused", true)
  simulation._machine_power_dirty = true
  return true
end

local function continue_work(simulation, machine)
  -- Upstream calls begin_work(new_production=TRUE) here, resetting duration.
  return begin(simulation, machine, true)
end

local function clear_queue(simulation, machine)
  machine.data.queue = {}
  interrupt(machine, simulation.machine_time_ds, "queue-cleared", false)
  machine.recipe_id = false
  simulation._machine_power_dirty = true
  return true
end

local function remove_queue_entry(simulation, machine, _, parameters)
  local index = parameters.index
  if index > #machine.data.queue then
    return false, Shared.rejection(
      "invalid-parameter",
      { parameter = "index" }
    )
  end
  local removed_current = index == 1
  table.remove(machine.data.queue, index)
  if #machine.data.queue == 0 then
    interrupt(machine, simulation.machine_time_ds, "queue-empty", false)
    machine.recipe_id = false
  elseif removed_current then
    interrupt(
      machine,
      simulation.machine_time_ds,
      "queue-entry-removed",
      false
    )
    begin(simulation, machine, true)
  else
    machine.recipe_id = machine.data.queue[1]
  end
  simulation._machine_power_dirty = true
  return true
end

Manufacturer.handlers = {
  ["manufacturer.queue-product"] = queue_product,
  ["manufacturer.set-speed"] = set_speed,
  ["manufacturer.toggle-repeat"] = toggle_repeat,
  ["manufacturer.pause"] = pause,
  ["manufacturer.continue"] = continue_work,
  ["manufacturer.clear"] = clear_queue,
  ["manufacturer.remove"] = remove_queue_entry,
}

function Manufacturer.gate(_, machine, action)
  if action.handler == "manufacturer.queue-product"
    and #(machine.data.queue or {}) >= 20
  then
    return false, Shared.rejection("queue-full", { maximum = 20 })
  end
  return true
end

function Manufacturer.wire_effect(simulation, machine, wire, operation)
  local data = machine.data
  if operation == "cut" then
    if wire.id == "extend" then
      data.hacked = false
    elseif wire.id == "shock" then
      data.time_left_electrified = 0
    elseif wire.id == "malfunction" then
      data.malfunction = true
    elseif wire.id == "power" then
      data.power_wire_cut = true
    end
  elseif operation == "mend" then
    if wire.id == "shock" then
      data.time_left_electrified = 0
    elseif wire.id == "malfunction" then
      data.malfunction = false
    elseif wire.id == "power" then
      data.power_wire_cut = false
    end
  elseif operation == "pulse" then
    if wire.id == "extend" then
      data.hacked = not data.hacked
    elseif wire.id == "shock" then
      data.time_left_electrified = 30
    elseif wire.id == "malfunction" then
      data.malfunction = not data.malfunction
    end
  end
  simulation._machine_power_dirty = true
end

function Manufacturer.power_request(machine, request)
  if machine.data.power_wire_cut
    or (machine.data.dismantle_stage or 0) >= 3
  then
    return 0
  elseif machine.data.mode == "working" then
    return request + (machine.data.active_power_consumption or 0)
  end
  return request
end

function Manufacturer.is_connected(_, machine)
  return not machine.data.power_wire_cut
    and (machine.data.dismantle_stage or 0) < 3
end

function Manufacturer.refresh_state(machine)
  return machine.data.mode or "ready"
end

function Manufacturer.process(_, machine)
  if (machine.data.time_left_electrified or 0) > 0 then
    machine.data.time_left_electrified =
      machine.data.time_left_electrified - 1
  end
end

function Manufacturer.delayed(simulation, machine, now_ds)
  local data = machine.data
  if data.mode == "working"
    and (machine.status.no_power or machine.status.broken)
  then
    interrupt(
      machine,
      now_ds,
      machine.status.broken and "broken" or "no-power",
      false
    )
    simulation._machine_power_dirty = true
  elseif data.mode == "working"
    and data.work_finish_ds > 0
    and now_ds >= data.work_finish_ds
  then
    finish(simulation, machine)
  elseif data.next_begin_ds and data.next_begin_ds > 0
    and now_ds >= data.next_begin_ds
  then
    data.next_begin_ds = 0
    begin(simulation, machine, true)
  end
end

function Manufacturer.damage(simulation, machine, amount)
  if amount > 0 then
    if machine.health <= 70
      and not machine.data.malfunction
      and simulation.rngs.machines:chance(33, 100)
    then
      machine.data.malfunction = true
    end
    if machine.health <= 25 then
      machine.status.broken = true
      interrupt(machine, simulation.machine_time_ds, "broken", false)
    end
  elseif machine.health >= 60 then
    machine.status.broken = false
  end
end

return Manufacturer
