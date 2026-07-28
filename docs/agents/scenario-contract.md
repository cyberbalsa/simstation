# Native scenario contract agent

## Record

- Canonical task: `/root/scenario_contract`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: contract design and implementation audit completed
- Assignment availability: verbatim
- Report availability: normalized visible report

### Assignment

> Inspect the current Sim Station docs/runtime/mod/save contracts plus pinned
> Goon maps and the new tools/map_import.py. Design the smallest maintainable
> native scenario/map contract for the current Goon-informed playable station
> milestone: palette/run encoding, namespaced IDs, areas,
> fixtures/machines/spawns, provenance, deterministic load semantics, mod
> replacements, validation limits, and save compatibility. Root has begun
> src/core/scenario.lua with simstation-map-v1, so align to actual current
> shared code and identify any contract flaws. Update only new
> docs/technical/08-native-scenarios-and-map-import.md and
> docs/agents/scenario-contract.md; do not modify existing docs/indexes/code.
> Include a JSON example and acceptance tests. Do not edit docs/agents
> README/manifest. Send final report and then make no further edits.

## Observable chronology

1. Inspected the in-progress `simstation-map-v1` validator/instantiator,
   simulation/world integration, content registry, mod loader and package
   validator, save envelope, content IDs, technical/design contracts, and
   existing scenario example.
2. Verified the local Goon checkout was at the project-pinned commit
   `1b2b250abb5be747d55e274de0203a59cfc8da78`.
3. Ran the deterministic map inventory over the 20 direct `maps/` candidates.
   All parsed without grammar errors. Compared Cogmap and Probstation area,
   adjacency, object, machinery, and department profiles.
4. Confirmed full Goon stations are generally 300×300 while the Sim Station
   milestone is 192×192 and schema 1 currently permits at most 256 per
   dimension. Chose bounded Goon-informed adaptation rather than direct
   whole-station conversion.
5. Defined a single-plane, sparse palette/run constructor with explicit
   coordinate orientation, canonical compiler output, stable nested IDs,
   reviewed fixture adapters, area/access behavior, provenance, all-or-nothing
   deterministic instantiation, complete mod replacement, and save rules.
6. Added a complete 16×16 JSON example using the exact pinned Cogmap
   commit/blob/SHA-256 as layout-reference provenance.
7. Audited current implementation gaps, particularly incomplete save
   snapshots, lack of normal app scenario selection, validator divergence,
   hard-coded job/machine vocabularies, ignored area access, unstable authored
   order, missing physical placement checks, and unbounded meteor targets.
8. Reconciled a concurrent extension that added `map_import.py compile` and the
   generated 192×192 `goon-atlas` scenario. Recorded that its stable IDs,
   collision handling, omission reporting, and path heuristics do not yet meet
   the release contract.
9. Specified twelve acceptance groups covering schema parity, expansion,
   canonical runs, determinism, physical placement, access, provenance, corpus
   analysis, mod replacement, save continuation, locks/migration, and limits.
10. Parsed both JSON examples, passed all seven map import/compiler fixture
    tests, validated the generated Atlas scenario through the Lua runtime
    validator, and completed `python3 tools/dev.py audit` successfully.

## Files added

- `docs/technical/08-native-scenarios-and-map-import.md`
- `docs/agents/scenario-contract.md`

No existing documentation index, agent manifest, runtime code, tests, tools, or
assets were changed.

## Decisions

### Accepted

- `simstation-map-v1` is a new-campaign constructor, never a serialized runtime
  world or save-load reconstruction source.
- Schema 1 remains one finite station plane and uses the scenario `ContentId`
  as its runtime map identity.
- Dense map state compiles from a default palette plus ordered 1-based
  row-major runs that may not cross rows.
- Goon maps supply measured area adjacency, department scale, circulation,
  utility, and machine-placement evidence; DM paths and override text never
  select runtime behavior implicitly.
- Scenario files are ordinary data-mod definitions, and replacement is
  complete-definition replacement under the existing direct-dependency rules.
- Exact Git commit, blob, SHA-256, source path, tool format, method, and
  omissions are preserved as deterministic provenance.
- Existing campaigns restore expanded saved state under the exact package lock
  rather than re-expanding a changed scenario.

### Adapted

- The primitive fixture-kind and department enums were retained as an explicit
  schema-1 milestone boundary because the current core supports only those
  adapters. Stable scenario/area/fixture/spawn identities and cross-content
  references remain namespaced.
- Cogmap was selected as a broad reference rather than a direct import because
  its 300×300 grid, 22,544 object placements, and full SS13 density exceed the
  current management-sim scale and schema envelope.
- The current raw `name` field is documented honestly; localization migration
  requires a versioned decision rather than pretending the general envelope is
  already implemented.

### Rejected

- Runtime DMM parsing or DM execution.
- Deriving behavior or public identity from Goon paths, DMM dictionary keys,
  coordinates, palette indices, localized names, or array position.
- Geometry patches/merges across mods.
- Silently moving invalid spawns/fixtures, dropping unsupported Goon atoms, or
  rebuilding a saved station from a replacement scenario.
- Claiming current validation and saves already satisfy the release contract.

## Evidence and commands

```text
python3 tools/map_import.py inventory --prefix maps/ --max-depth 0 --pretty
python3 tools/map_import.py analyze maps/cogmap.dmm --top 40 --pretty
python3 tools/map_import.py analyze maps/probstation.dmm --top 40 --pretty
python3 tools/map_import.py analyze maps/atlas.dmm --top 20
python3 -m unittest -v tests.test_map_import
```

Pinned Cogmap source:

```text
commit  1b2b250abb5be747d55e274de0203a59cfc8da78
path    maps/cogmap.dmm
blob    b94e5abf1673052e28fb8090ba54fa7bab189a05
sha256  dacb2f0c0617c8dcd16433ca9cf92042da2bde83f7e8268aa6880e51a9ec31f7
```

The direct-map inventory reported 20 selected, 20 parsed, and zero parser
errors. Cogmap reported 90,000 mapped cells, 14,330 non-space turf cells,
12,736 station-area cells, 22,544 object instances, and 5,048 machinery
instances. The checked-in Atlas crop compiles to 192×192 with 399 palette
entries, 2,361 runs, 84 areas, 127 selected fixtures, 86 spawn markers, and 64
meteor targets.

Validation at handoff:

- two JSON examples parsed;
- seven `tests.test_map_import` parser/compiler tests passed;
- `Scenario.validate` accepted the generated Atlas artifact;
- repository Lua/content/asset/link/LFS/workflow audit passed; and
- `git diff --check` reported no whitespace errors.

## Handoff risks

The highest-priority runtime flaw is save loss: machines, inventory, scenario
state, and content references are currently outside the snapshot/state hash and
are not restored. The application also does not yet select a registry scenario.
Those need resolution before scenario content is presented as save-safe.

The next priority is one shared closed validator. Current Python and Lua checks
accept different subsets and do not enforce stable nested IDs, physical
placement, canonical runs, or complete provenance. Making permissive behavior
part of schema 1 would create lasting mod and save ambiguity.

The generated Atlas candidate contains five coordinates with multiple
one-anchor fixtures: `(58,103)`, `(62,103)`, `(74,57)`, `(88,97)`, and
`(132,75)`. Its area/fixture IDs and job markers are also not namespaced, and
unsupported atoms are omitted without a report. These are concrete
compiler-contract failures, not merely future polish.

This record contains externally observable assignment, actions, findings,
decisions, and validation only. It does not reproduce hidden reasoning, private
model state, or unavailable dialogue.
