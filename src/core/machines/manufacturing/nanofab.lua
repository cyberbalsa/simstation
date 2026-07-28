local Shared = require("src.core.machines.shared")

local Nanofab = {
  definition_ids = {
    "org.simstation.core:machine/goon-nanofab",
  },
  behavior_ids = {
    "org.simstation.core:machine-behavior/goon-nanofab-v1",
  },
  fixture_kinds = { "nanofab", "refinery" },
  machine_tag = "refinery",
}

local function fabricate(simulation, machine, _, parameters)
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
  Shared.consume_inputs(simulation, selected_recipe)
  Shared.dispense_outputs(simulation, selected_recipe)
  simulation.metrics.completed_tasks =
    simulation.metrics.completed_tasks + 1
  simulation:_emit("manufacturing_completed", {
    machine_id = machine.id,
    recipe_id = selected_recipe.id,
    immediate = true,
  })
  return true
end

Nanofab.handlers = {
  ["nanofab.fabricate"] = fabricate,
}

function Nanofab.queue_recipe(simulation, machine, recipe_id)
  return fabricate(
    simulation,
    machine,
    nil,
    { recipe_id = recipe_id }
  )
end

return Nanofab
