local Stable = require("src.core.stable")

local Shared = {}

function Shared.array_contains(values, wanted)
  for index = 1, #(values or {}) do
    if values[index] == wanted then
      return true
    end
  end
  return false
end

function Shared.set_contains(values, wanted)
  if type(values) ~= "table" then
    return false
  end
  if values[wanted] == true then
    return true
  end
  return Shared.array_contains(values, wanted)
end

function Shared.rejection(code, details)
  local result = details and Stable.deep_copy(details) or {}
  result.code = code
  return result
end

function Shared.wire_by_key(machine, key)
  for index = 1, #(machine.wires or {}) do
    local wire = machine.wires[index]
    if wire.color == key or wire.id == key then
      return wire
    end
  end
  return nil
end

function Shared.recipe(simulation, recipe_id)
  local value = simulation.content
    and simulation.content.by_id
    and simulation.content.by_id[recipe_id]
  if value and value.kind == "recipe" then
    return value
  end
  return nil
end

function Shared.enough_inputs(simulation, selected_recipe)
  for index = 1, #(selected_recipe.inputs or {}) do
    local input = selected_recipe.inputs[index]
    if (simulation.inventory[input.id] or 0) < input.quantity then
      return false, input.id
    end
  end
  return true
end

function Shared.consume_inputs(simulation, selected_recipe)
  for index = 1, #(selected_recipe.inputs or {}) do
    local input = selected_recipe.inputs[index]
    simulation.inventory[input.id] =
      (simulation.inventory[input.id] or 0) - input.quantity
  end
end

function Shared.dispense_outputs(simulation, selected_recipe)
  for index = 1, #(selected_recipe.outputs or {}) do
    local output = selected_recipe.outputs[index]
    simulation.inventory[output.id] =
      (simulation.inventory[output.id] or 0) + output.quantity
  end
end

return Shared
