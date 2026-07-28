# Native scenario example — salvage scenario migration

## Record

- Canonical task: `/root/native_scenario_example`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible report
- Assignment availability: verbatim

### Assignment

> Inspect mods/examples/org.simstation.example.salvage-scenario and migrate it
> into a small, strictly valid simstation-map-v1 scenario_map example compatible
> with current tools/mods.py and src/core/scenario.lua. Preserve any useful
> non-scenario content. Update its manifest/readme/locales as needed, add focused
> validation/test coverage if appropriate, and archive your assignment,
> decisions, changed files, and validation in
> docs/agents/native-scenario-example.md. Also ask the docs-polish agent via
> message if possible to ensure your report is indexed; if not, update
> docs/agents indexes yourself carefully. Avoid editing core Atlas/runtime
> source.

## Observable chronology

1. Inspected the existing example, the strict Python package/scenario
   validator, Lua scenario validator and instantiator, mod registry and loader,
   core jobs/items/incidents, scenario contract, and canonical mod examples.
2. Identified that the old file was ordinary `content`, not a
   `scenario_maps` resource, and that it placed unsupported campaign settings
   (`seed`, budgets, crew count, objectives, and incident allowlist) directly
   on a schema-less scenario definition.
3. Designed a 16×16 synthetic station at the schema minimum: two
   access-controlled department areas, an external engineering airlock,
   internal cargo airlock, continuous cable network, generator and two APCs,
   atmospherics, fabrication/refining/export fixtures, four job spawn markers,
   and two exposed hull meteor targets.
4. Migrated the geometry/start state into
   `scenarios/last-chance.json`, selected by the manifest's `scenario_maps`
   field.
5. Preserved the export condition and original seed, economy, material, crew,
   and incident settings as namespaced `objective` and `scenario-profile`
   content in `content/recovery.json`. The README explicitly says those
   future-facing kinds are registered but not yet applied by the vertical
   slice.
6. Added English display strings and a package README documenting the exact
   supported/runtime boundary and project-authored CC0 provenance.
7. Added a focused deterministic Lua test that resolves the core dependency
   and example pack together, builds runtime content, instantiates the native
   scenario, verifies its physical counts and powered areas, and confirms the
   preserved profile values.
8. Asked the concurrent documentation-polish agent to index this record rather
   than editing the shared agent indexes concurrently.
9. Validated the folder through the strict Python package tool and ran the full
   deterministic Lua test suite.

## Delivered example

The native scenario has:

| Contract element | Example value |
| --- | --- |
| Map | 16×16, sparse row-major runs, six semantic palette entries |
| Areas | Engineering Workshop and Salvage Bay |
| Access | Engineering exterior airlock and cargo divider airlock |
| Power | One 110 kW generator, two wired APCs, continuous cable path |
| Fixtures | 2 APCs, generator, vent, scrubber, refinery, fabricator, cargo pad |
| Spawns | 2 engineers and 2 cargo technicians |
| Incidents | 2 sorted exterior wall meteor targets |
| Inventory | Cable, circuits, iron ore, and steel |

The geometry is deliberately authored as a compact teaching fixture rather than
copied from Goonstation. It demonstrates the same native contract used by the
larger Atlas derivative without adding upstream licensing or generated-media
weight to an API example.

## Decision disposition

### Accepted

- A normal data mod uses `scenario_maps` for strict physical scenario
  definitions and `content` for other namespaced definitions.
- The example starts at the minimum valid dimension so its palette, runs, and
  physical invariants remain easy to inspect.
- Fixture and spawn IDs are sorted stable, namespaced identities rather than
  coordinates or array positions.
- Python package validation and Lua instantiation both cover the example.
- The package version advances from `0.1.0` to `0.2.0` because the old scenario
  shape is replaced by a native map contract.

### Adapted

- The old abstract `material_units = 80` setting remains in the future-facing
  profile, while a small concrete starting inventory supplies the playable
  native scenario.
- The original export objective and incident allowlist remain ordinary
  registry content because schema 1 intentionally has no objective, budget,
  roster, or incident fields.
- The scenario's human-readable `name` remains inline because that is the
  current schema-1 requirement; supporting content uses localization keys.

### Rejected

- Retaining unsupported keys on a scenario that the strict validator rejects.
- Describing the objective/profile records as active gameplay before systems
  consume them.
- Copying Goonstation map geometry or media into a small mod API fixture.
- Adding a special loader path for first-party versus extension scenarios.

### Unresolved

- A later public schema must define and validate executable
  `scenario-profile`/`objective` behavior before those records affect a
  campaign.
- Scenario schema evolution must decide how roster templates, budgets,
  incident pools, localization, and objective links compose with the physical
  starting map.

## Files changed

- `mods/examples/org.simstation.example.salvage-scenario/mod.toml`
- `mods/examples/org.simstation.example.salvage-scenario/README.md`
- `mods/examples/org.simstation.example.salvage-scenario/content/recovery.json`
- `mods/examples/org.simstation.example.salvage-scenario/locales/en.json`
- `mods/examples/org.simstation.example.salvage-scenario/scenarios/last-chance.json`
- `mods/examples/org.simstation.example.salvage-scenario/content/scenario.json`
  (removed)
- `tests/run.lua`
- `docs/agents/native-scenario-example.md`

No core Atlas scenario, importer, runtime simulation, renderer, or generated
asset source was edited by this task.

## Validation evidence

Completed successfully:

```text
python3 tools/dev.py mod validate \
  mods/examples/org.simstation.example.salvage-scenario

ok: data pack org.simstation.example.salvage-scenario 0.2.0
3 definitions
content/recovery.json selected as ordinary content
scenarios/last-chance.json selected as a scenario map
tree SHA-256:
00ce22f25653d685cf71f1eb668c81000eb909d15933b142f6b987776b6eb79b
```

Packaging the folder to a temporary `.simmod` and validating the archive also
passed. The archive reported the same
`00ce22f25653d685cf71f1eb668c81000eb909d15933b142f6b987776b6eb79b`
canonical tree SHA-256 as the folder.

```text
luajit tests/run.lua

ok 10 - salvage example loads and instantiates as a native scenario
14 tests, 0 failures, 11.488s
```

The focused test proves the Python validator's accepted artifact is also
accepted by `src/core/scenario.lua`, expands to 16×16 with two areas, eight
fixtures, four spawns, and two meteor targets, starts both APC-served areas
powered, and retains the profile seed/credits/crew/objective reference through
the shared registry.

The required repository-wide audit also passed:

```text
python3 tools/dev.py audit

14 deterministic Lua tests passed
8 Python map/import fixture tests passed
5 folder mods validated
asset/provenance audit passed
whitespace, JSON, TOML, core boundary, Markdown links,
workflow pins, and Git LFS attributes passed
```

## Sources

- `tools/mods.py`
- `src/core/scenario.lua`
- `src/mods/loader.lua`
- `src/content/registry.lua`
- `src/content/runtime.lua`
- `mods/org.simstation.core/content/jobs.json`
- `mods/org.simstation.core/content/materials.json`
- `mods/org.simstation.core/content/incidents.json`
- `docs/technical/08-native-scenarios-and-map-import.md`

This record contains externally observable assignment, actions, decisions,
changed files, and validation only. It does not reproduce hidden reasoning,
private model state, or unavailable dialogue.
