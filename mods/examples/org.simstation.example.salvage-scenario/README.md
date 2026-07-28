# Salvage scenario example

This data-only mod demonstrates that a normal extension pack can add a complete
native starting station through the same `scenario_maps` contract as the core
pack.

`scenarios/last-chance.json` is a deliberately small 16×16 recovery station. It
contains two access-controlled areas, a wired generator and APCs, atmospheric
fixtures, manufacturing and cargo anchors, job-specific spawn pools, exterior
meteor targets, and a constrained starting inventory. It is directly
instantiable by `src/core/scenario.lua`; no DMM, DMI, DM path, or LÖVE object is
used at runtime.

`content/recovery.json` preserves the intended cash-poor campaign setup as
ordinary namespaced content:

- a three-shift objective to export two control assemblies; and
- a profile with seed `90210`, 8,000 starting credits, 80 abstract material
  units, 16 crew, and the allowed supply-delay/power-overload incidents.

The current vertical-slice runtime does not yet apply `objective` or
`scenario-profile` definitions. They remain explicit future-facing data rather
than unsupported keys on the strict schema-1 scenario. The playable fields
today are geometry, areas/access, power, fixtures, spawn pools, meteor targets,
and starting inventory.

Validate the folder with:

```sh
python3 tools/dev.py mod validate \
  mods/examples/org.simstation.example.salvage-scenario
```

The example is project-authored and released under CC0-1.0. Its station map does
not copy Goonstation geometry or media.
