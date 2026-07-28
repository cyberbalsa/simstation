local MODULES = {
  require("src.core.machines.atmospherics.passive_vent"),
  require("src.core.machines.atmospherics.portable_scrubber"),
  require("src.core.machines.atmospherics.vent_pump"),
  require("src.core.machines.cargo.barcode_computer"),
  require("src.core.machines.cargo.cargo_pad"),
  require("src.core.machines.cargo.supply_console"),
  require("src.core.machines.engineering.apc"),
  require("src.core.machines.engineering.smes"),
  require("src.core.machines.engineering.teg_circulator"),
  require("src.core.machines.engineering.teg_generator"),
  require("src.core.machines.manufacturing.manufacturer"),
  require("src.core.machines.manufacturing.nanofab"),
  require("src.core.machines.manufacturing.reclaimer"),
}

local Registry = {
  modules = MODULES,
  by_behavior_id = {},
  by_definition_id = {},
  by_fixture_kind = {},
}

local function register_unique(target, key, module, label)
  assert(not target[key], "duplicate machine " .. label .. ": " .. key)
  target[key] = module
end

for module_index = 1, #MODULES do
  local module = MODULES[module_index]
  for index = 1, #(module.behavior_ids or {}) do
    register_unique(
      Registry.by_behavior_id,
      module.behavior_ids[index],
      module,
      "behavior ID"
    )
  end
  for index = 1, #(module.definition_ids or {}) do
    register_unique(
      Registry.by_definition_id,
      module.definition_ids[index],
      module,
      "definition ID"
    )
  end
  for index = 1, #(module.fixture_kinds or {}) do
    register_unique(
      Registry.by_fixture_kind,
      module.fixture_kinds[index],
      module,
      "fixture kind"
    )
  end
end

function Registry.for_machine(machine)
  return Registry.by_behavior_id[machine.behavior_id]
    or Registry.by_definition_id[machine.definition_id]
    or Registry.by_fixture_kind[machine.kind]
end

function Registry.for_definition(definition)
  return Registry.by_behavior_id[definition.behavior]
    or Registry.by_definition_id[definition.id]
    or Registry.by_fixture_kind[definition.fixture_kind]
end

return Registry
