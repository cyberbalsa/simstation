# Tile interaction fidelity tests agent

## Record

- Canonical task: `/root/machine_fidelity_tests`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed test task; reported compatibility blocker
  subsequently resolved by parent integration
- Report availability: observable work record
- Assignment availability: verbatim

### Assignment

> Focus only on tests for the next Goon interaction/tile fidelity slice. Audit
> existing Lua/Python coverage, then add tests (`tests/run.lua` and/or
> `test_map_import.py`, `love_selftest` only if needed) for data-driven
> turf/structure interactions, stable NPC affordances/denial codes,
> adjacency/tool/access gates, construction/damage state transitions, and
> representative tile/object import coverage. Coordinate by writing tests
> against clean, documented interfaces where possible; avoid production Lua
> edits. Save this turn's full work/state/findings to
> `docs/agents/tile-interaction-tests.md` and update `docs/agents`
> README/manifest. Run targeted tests and report expected initial failures
> versus passes.

### Observable chronology

1. The agent audited the pure-Lua suite, Python map-import fixture suite,
   existing machine affordance tests, scenario contract, and concurrent world
   representation work.
2. The parent fixed the bounded public interaction interface as
   `affordances(sim, target, actor)`,
   `can_action(sim, target, action_id, actor, params)`, and
   `perform(sim, target, action_id, actor, params)`, with a serialized
   `tile_action` command and stable denial codes.
3. Test-first Lua coverage was added for schema-2 structure interaction
   profiles, sorted NPC affordances, stable denial reasons, adjacency, tools,
   occupancy, access, power, floor construction, wall damage/repair/removal,
   topology/chunk revisions, and save restoration.
4. Test-first Python coverage was added for native turf, wall, window, grille,
   table, chair, light, storage, crate, and airlock classification and source
   provenance.
5. A source-path review corrected the representative grille from the legacy
   `/obj/grille` family to Atlas' actual `/obj/mesh/grille/steel`. The parent
   requested an Atlas-real compound wingrille case plus a small direct-window
   classifier case; both are covered.
6. The initial Lua run retained all 21 pre-existing passes and produced exactly
   three expected new failures: schema/profile data had not landed,
   `src.core.interaction` did not yet exist, and `tile_action` was not yet a
   recognized command.
7. The initial representative Python test failed at the first missing native
   `floor` classification, before reaching later classifications. This was the
   expected importer red baseline.
8. The agent alerted the parent and documentation owner that a concurrent
   technical draft used a different argument order/request shape from the
   locked executable interface.
9. Subsequent runs exposed three production integration defects: an available
   affordance indexed a nil rejection reason, the command handler read legacy
   `x`/`y` fields instead of the documented target, and a registered sibling
   turf action returned `unknown-action` rather than
   `invalid-target-state`. The parent corrected all three outside this agent's
   test-owned scope.
10. The parent expanded the closed floor and airlock action vocabularies. The
    tests were updated to require the complete sorted sets and to prove that a
    known sibling action remains visible to NPCs with a stable denial reason.
11. Strict Python validation was added for every shipped structure definition,
    including rejection of an action with missing source-symbol provenance.
12. Final validation passed with 24 Lua tests and 17 Python tests.
13. The required project audit reran both green suites and all later
    documentation, workflow, core-boundary, and LFS checks, but stopped on a
    concurrent compatibility issue: the new strict structure validator rejects
    the legacy AV-swap replacement's `sprite` field. The agent reported this
    production/example migration blocker to the parent and did not edit that
    out-of-scope content.
14. After the agent completed, the parent migrated AV-swap to the schema-2
    visual-alias contract. The final project audit then passed. A separate
    parent-owned viewport assertion increased the Lua suite total to 25;
    the 24 interaction-era tests and all 17 Python tests remain green.

## Observable work record

### Implementation test files

- `tests/run.lua`
- `tests/test_map_import.py`

No production Lua, importer, content, generated scenario, or LÖVE self-test
file was edited by this agent. The LÖVE self-test did not need a contract
change for this slice.

The required archive changes are:

- `docs/agents/tile-interaction-tests.md`
- `docs/agents/README.md`
- `docs/agents/manifest.json`

### Locked executable assertions

The Lua tests use tile targets shaped as:

```lua
{ kind = "tile", index = tile_index }
```

They assert these stable action IDs in the bounded slice:

```text
close-door
dismantle-wall
inspect
open-door
place-floor
pry-door
pry-floor
reinforce-floor
remove-floor-reinforcement
repair-wall
toggle-door-panel
weld-door
```

They exercise these stable rejection codes:

```text
unknown-action
outside-map
unsupported
not-adjacent
wrong-tool
occupied
invalid-target-state
unpowered
access-denied
```

NPC affordances must remain sorted, unique, retain unavailable actions, and
surface the same string denial reason as `can_action`.

### State-transition assertions

- A crowbar removes a floor tile while the legacy gas/path tile remains floor;
  native turf state changes from floor to plating.
- A floor-tile item restores plating to floor.
- Positive integer brute damage lowers a wall's health and touches its chunk.
- A welder repairs a damaged standard wall; repair then becomes invalid.
- Invalid zero damage does not touch authoritative state.
- A welder dismantles a standard wall, changes native wall kind to none,
  restores passability, and advances topology revision.
- Snapshot restoration preserves the state hash, native turf/wall semantics,
  and the public sorted `World:feature_ids(index)` projection.
- A serialized airlock action rejects unpowered and unauthorized actors before
  opening for an adjacent actor with the required access.

### Representative import assertions

The synthetic fixture uses source families that are representative of the
pinned Goonstation/Atlas map:

- `/turf/simulated/floor`
- `/turf/simulated/floor/plating`
- standard and reinforced `/turf/simulated/wall` variants
- `/obj/mapping_helper/wingrille_spawn/auto/reinforced`
- `/obj/mesh/grille/steel`
- `/obj/window/reinforced`
- `/obj/table/reinforced`
- `/obj/stool/chair`
- `/obj/machinery/light`
- `/obj/storage/closet`
- `/obj/storage/crate`
- `/obj/machinery/door/airlock/pyro/security`

The wingrille must classify as both `window` and `grille`. A closet maps to the
native `storage` feature while retaining exact closet source provenance.
Feature and preserved source arrays must be sorted and unique. The airlock is
represented by native closed-door structure state rather than an invented
feature bit.

### Initial test results

The first integration baseline was:

```text
luajit tests/run.lua
21 existing tests passed
3 expected new tests failed
```

The three failures were narrowly attributable to production work not yet
present:

```text
structure definition schema expected 2, actual nil
module src.core.interaction not found
unknown command: tile_action
```

The targeted Python result was:

```text
1 test run, 1 expected failure
cell 1 lost native classes {'floor'}: set()
```

The host's plain `lua` executable is Lua 5.5 and exposes an unrelated existing
`toml_subset.lua` compatibility error. Project validation correctly prefers
LuaJIT, matching CI and LÖVE's Lua 5.1 semantics.

### Final integration results

The initial red tests became green without weakening the locked denial or
state-transition assertions. Final results were:

```text
luajit tests/run.lua
24 tests, 0 failures

python3 -m unittest tests.test_map_import
17 tests, 0 failures

python3 tools/dev.py test
passed (same 24 Lua and 17 Python tests)

python3 tools/dev.py audit
test phases passed; later mod validation stopped on the legacy AV-swap
structure replacement (`unknown structure keys: sprite`)
```

The final Python suite includes deterministic regeneration equality for the
committed Atlas scenario, native DM type-boundary cases, strict native palette
metadata checks, and strict structure action/source validation.

Post-handoff integration resolved that audit stop by migrating the AV-swap
replacement to schema 2. The final audit passes; the historical output above
is retained because it records the agent's actual handoff state.

## Decision disposition

### Accepted

- Public interaction tests use the parent's locked target/action API.
- Native semantic fields coexist with legacy tile/structure fields.
- Public feature assertions use sorted semantic IDs, not numeric bit masks.
- Atlas-real wingrille and grille paths are fixture evidence.
- Closet classification is `storage` plus source provenance.
- Registered sibling-state verbs remain NPC-visible and return
  `invalid-target-state`; `unknown-action` is reserved for nonexistent IDs.
- Every shipped structure action has registered behavior and source-symbol
  provenance under strict schema validation.

### Adapted

- The current engine slice tests deterministic equivalent outcomes and bounded
  interaction profiles; deeper Goon multi-stage construction remains outside
  this executable milestone.
- Airlock identity is asserted through source provenance and closed-door
  structure state because no `airlock` feature bit exists.

### Rejected

- Treating `/obj/grille/...` as the only representative upstream grille path.
- Assuming actor inventory beyond the public `actor.tools` array.
- Editing production files from the test-owned task.

### Unresolved

- Multi-stage reinforced-wall, girder, window, grille, furniture, lighting,
  and closet behavior needs later source-vector tests as those profiles become
  executable.

## Sources

- Pinned Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- Forked `assets/upstream/goon/maps/atlas.dmm`.
- Concurrent `src/core/constants.lua`, `src/core/world.lua`,
  `src/core/scenario.lua`, interaction modules, and first-party structure
  definitions.
- Existing `tests/run.lua`, `tests/test_map_import.py`, machine affordance
  fixtures, and native scenario fixtures.
