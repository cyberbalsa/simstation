# Atlas DM appearance import audit

## Assignment

This archive preserves the state and decisions from the
`/root/machine_fidelity_tests` agent's Atlas appearance-import task on
2026-07-28.

The user asked that Sim Station continue from local pinned Goonstation assets
and code, with machine behavior and NPC interactions eventually matching
upstream closely. The parent agent narrowed this parallel task to:

- audit Atlas DMM/DMI state resolution against the semantic palette and
  existing 29-sprite foundation selection;
- identify concrete wrong floor, wall, window, door, machine, and furniture
  mappings;
- implement importer and generated asset-metadata fixes without touching the
  renderer;
- retain the work and conversation state under `docs/agents`.

The parent accepted the runtime path
`assets/runtime/goon/graphics/dm-appearances.json`, the sparse scenario field
`map.appearances`, and ordering by linear cell `index` then source atom
`order`. It also required compact page records with `bundle`, `page`,
`runtime_path`, `width`, `height`, and `sha256`.

## Upstream evidence

All evidence came from the locally cached pinned Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`; no moving branch or remote source
was used.

Representative source facts:

- `code/turf/turf.dm:272-332` assigns `icons/turf/space.dmi`, starts at
  `placeholder`, and deterministically replaces ordinary space with states
  `1` through `25` from source `x`, `y`, and `z`.
- `code/turf/floors.dm` and the airless/unsimulated mirrors assign hundreds of
  distinct states rather than one generic `floor` sprite.
- `code/turf/turf_autoalign.dm:355-434` uses
  `icons/turf/walls/supernorn/smooth.dmi`, `mapwall`/`mapwall_r` in the editor,
  and runtime `norn-*`/`norn-R-*` connection masks.
- `code/modules/mapping/helpers/wingrille_spawner.dm:90-148` replaces each
  Atlas auto helper with a grille and a full auto window; reinforced helpers
  select reinforced window types.
- `code/obj/window.dm:767-1000` drives auto windows through `W-*` or `R-*`
  connection states in `icons/obj/window_pyro.dmi`.
- `code/obj/machinery/door/airlock_pyro.dm` maps department airlocks to
  distinct states in `icons/obj/doors/SL_doors.dmi`.
- `code/obj/machinery/door/poddoor.dm` defines `pdoor1` as closed and
  `pdoor0` as open.
- `code/modules/power/apc.dm:36-160` defines the `apc0` base plus fixed
  north/east/south/west directions and pixel offsets.
- `code/obj/machinery/manufacturer_subtypes.dm` assigns separate
  `fab-engineering`, `fab-mining`, `fab-med`, `fab-robotics`, and other
  department states.
- `code/obj/table.dm` and `code/obj/stool.dm` assign distinct connected table
  sheets and chair colors/styles.

## Atlas census and concrete errors

The representative crop is source X/Y `61..252`, Z `1`, producing a
192-by-192 native map.

The previous renderer-facing selection flattened:

- 3,662 floor cells spanning 104 floor paths into a handful of floor aliases;
- 1,073 walls into old generic wall/reinforced-wall sprites rather than
  Supernorn sprites and connection masks;
- 378 auto wingrille helpers into one old window sprite, omitting their
  generated grille plus auto-window composition;
- 279 doors across 27 paths into classic generic door states, including
  map-authored open poddoors treated as closed;
- 134 adapted machine fixtures into generic APC, fabricator, generator,
  refinery, vent, and scrubber aliases;
- 155 tables, 73 chairs, 100 storage objects, and 354 lights into one state
  per broad semantic feature.

Examples now selected from the actual upstream declaration are:

| Atlas source type | Imported source DMI/state |
| --- | --- |
| `/turf/simulated/floor/black` | `icons/turf/floors.dmi:dark` |
| `/turf/simulated/floor/white` | `icons/turf/floors.dmi:white` |
| `/turf/simulated/wall/auto/supernorn` | `icons/turf/walls/supernorn/smooth.dmi:mapwall`, plus `norn-*` |
| `/turf/simulated/wall/auto/reinforced/supernorn` | same DMI, `mapwall_r`, plus `norn-R-*` |
| `/obj/machinery/door/airlock/pyro/engineering/alt` | `icons/obj/doors/SL_doors.dmi:eng2_closed` |
| `/obj/machinery/power/smes` | `icons/obj/power.dmi:smes` |
| `/obj/machinery/manufacturer/mining` | `icons/obj/manufacturer.dmi:fab-mining` |
| `/obj/stool/chair/office/purple` | `icons/obj/furniture/chairs.dmi:office_chair_purple` |
| `/obj/storage/closet/fire` | `icons/obj/storage/locker.dmi:fire` |
| `/obj/table/wood/round/auto` | `icons/obj/furniture/table_wood_round.dmi:0`, plus masks |

## Implemented contracts

### Map importer

`tools/map_import.py` now retains a separate data-only visual override subset:

- single-quoted `icons/*.dmi` resource literals become `icon_override`;
- string `icon_state` becomes `icon_state_override`;
- BYOND directions `1,2,4,5,6,8,9,10` become stable direction names;
- integer `pixel_x`/`pixel_y` remain integers;
- numeric `layer` becomes integer thousandths in `layer_milli`.

This never evaluates a DM expression.

`collect_appearances` emits source-ordered turf and visible-object records.
Areas, landmarks, effects, overlays, and editor-only mapping helpers are
excluded; wingrille helpers remain because runtime expands them into visible
objects. Ordinary `/turf/space` records receive the pinned deterministic
runtime state. Poddoors with authored `density = 0` or a known open state now
produce semantic `door_open` cells rather than `door_closed`.

The committed Atlas scenario contains:

- 43,813 appearances: 36,864 turf and 6,949 object records;
- 32,100 resolved ordinary-space records spanning all states `1..25`;
- 51 authored `pdoor0` appearance overrides;
- 43 semantic open-door cells and 226 closed-door cells;
- the unchanged 1,596 palette records and 4,443 runs.

### Compact runtime selection

The editable profile is
[`dm-appearance-profile.json`](../../assets/source/goon/dm-appearance-profile.json).
`tools/assets.py build-dm-appearances`:

1. parses retained Atlas type paths and safe per-instance state overrides;
2. statically indexes literal `icon`, `icon_state`, direction, pixel offsets,
   and `parent_type` from the exact pinned DM blobs;
3. recognizes nested relative DM subtype declarations such as APC directions
   and chair colors;
4. resolves only Atlas-referenced types and reviewed runtime state families
   against the exhaustive generated atlas;
5. selects only referenced sprite records and page metadata;
6. emits explicit mapped/fallback diagnostics.

The generated
[`dm-appearances.json`](../../assets/runtime/goon/graphics/dm-appearances.json)
is about 4.2 MiB versus the roughly 71 MiB exhaustive `atlas.json`. It contains:

- 1,172 exact type rules;
- 2,059 selected sprite-state records;
- 30 lazy-load page records;
- 43,802 mapped instances out of 43,813;
- 11 fallback instances across eight unrelated prop paths.

Connected families include Supernorn `norn-*`/`norn-R-*`, auto-window
`W-*`/`R-*`, grille states, and numeric auto-table masks. Machine/door rules
also retain reviewed dynamic state families so simulation state can select
more than the initial sprite later.

Wingrille rules are multi-part and carry `state_prefix` values (`grille-`,
`W-`, or `R-`) so one computed neighbor mask can resolve independently for
each generated part.

## Known bounded gaps

The static index handles absolute and indentation-nested type declarations but
does not yet expand `DEFINE_FLOORS(...)` preprocessor calls. Consequently, the
34 `/turf/simulated/floor/twotone/black` and 18
`/turf/simulated/floor/twotone/darkblue` cells currently inherit the lexical
`floor` default in the generated rule instead of `twotone_black` and
`twotone_dblue`. This was reported to the parent when production edits were
frozen for the parallel compact-map generator work. The next generator pass
should either expand the reviewed floor macros or add explicit profile rules.

The eight reported fallback paths are two raw ice materials, two creamers, two
cryo cells, one decorative plant, one cup, one mug, one tarot deck, and one toy
sword. Several point to icon states absent under the statically inherited DMI;
they remain explicit diagnostics rather than silent substitutions.

Runtime animation/state-machine parity is not claimed by this appearance
import. Rules marked `runtime-state-deferred`, `runtime-random-deferred`, or
`connected-state-deferred` deliberately expose needed sprite states while the
authoritative simulation and renderer choose them later.

## Validation state

Completed before the production freeze:

```text
python3 -m py_compile tools/assets.py tools/map_import.py
python3 tools/assets.py build-dm-appearances
  DM appearances complete: 1,172 rules, 2,059 sprites, 30 pages,
  43,802/43,813 instances mapped
python3 tools/map_import.py compile maps/atlas.dmm ...
  output bytes: 10,720,503
python3 -m unittest tests.test_map_import
  Ran 19 tests ... OK
```

Focused tests live in `tests/test_dm_appearances.py`. Their final rerun passed:

```text
python3 -m unittest tests.test_dm_appearances tests.test_map_import
  Ran 25 tests ... OK
```

The full repository audit also passed after the production freeze:

```text
python3 tools/dev.py audit
  26 Lua tests, 0 failures
  19 Python map-import tests, OK
  asset, mod, boundary, format, link, workflow, and Git LFS audits passed
```

The focused run emits harmless Python `ResourceWarning` messages for
unclosed `git cat-file` subprocess pipe handles in `_git_dm_sources()`. This
does not affect output or test results, but a later generator edit should
close those handles explicitly.

## Conversation handoff

The parent explicitly accepted:

- `map.appearances` and `resolved_icon_state`;
- normalized direction names rather than raw BYOND numbers;
- integer `layer_milli`;
- longest-path rule resolution;
- compact selected sprites/pages rather than runtime parsing of full
  `atlas.json`;
- full connected-state selection so the renderer can compute masks.

The final coordination request was to freeze production edits, especially
`tools/assets.py`, so the `compact_map_atlas` agent could extend the generator
safely. No renderer files were edited by this agent.

## Follow-up: map-editor placeholder regressions

### Assignment and scope

After the compact generator landed, the parent assigned a tests-and-docs-only
follow-up:

> Add regressions against the latest generated DM appearance manifest,
> profile, and scenario for random plating, auto catwalks, wingrille helpers,
> and the corrected twotone floors. Do not edit the generator, profile,
> scenario, or Lua production.

The parent subsequently requested that `tests.test_dm_appearances` become part
of the normal `tools/dev.py test` and audit path. The runtime-review agent
clarified that map/editor provenance must remain visible in the generated
rule, while `MapAppearance` must project editor-only states before catalog
resolution.

No generator, profile, scenario, asset, or Lua production file was changed by
this follow-up.

### Superseded archive state

The compact-atlas pass resolved the earlier bounded macro gap and repacked the
runtime selection. The current generated selection has:

- 1,172 rules and 2,101 sprite states;
- 10,537 frame references representing 5,942 unique source rectangles;
- two compact `2048x2048` pages rather than 30 sparse full-catalog pages;
- exact `twotone_black` and `twotone_dblue` rules for all 52 affected Atlas
  instances; and
- the same 43,802 mapped and 11 explicitly unresolved appearance instances.

The earlier “Known bounded gaps” and 2,059-sprite/30-page figures above record
the pre-compact state and are no longer current.

### Regression contracts

`tests/test_dm_appearances.py` now pins all four reviewed boundaries:

1. `/turf/simulated/floor/plating/random` retains
   `plating_random` as upstream map-editor provenance and remains marked
   `runtime-random-deferred`, while the selected catalog must contain ordinary
   `icons/turf/floors.dmi:plating`. All 341 Atlas instances must remain free
   of authored state overrides.
2. `/turf/simulated/floor/airless/plating/catwalk/auto` retains `auto` as its
   map-time placeholder, but its reviewed profile and generated catalog must
   include cardinal masks `0`, `1`, `2`, `4`, `8`, and `15`. All 227 Atlas
   instances remain available for runtime connection-mask projection.
3. Every auto wingrille helper variant must use
   `icons/obj/SL_windows_grilles.dmi:grille1-0`, the `grille` state prefix and
   `-0` suffix, in both the editable profile and generated manifest. The
   legacy `icons/obj/grille.dmi` helper mapping is explicitly rejected.
4. The generated rules, bounded static index, and scenario counts must agree
   on 34 `twotone_black` and 18 `twotone_dblue` Atlas turfs.

`tests/run.lua` adds a runtime projection test using the real compact
manifest/catalog with mocked LÖVE image handles. It constructs an ordinary
random-plating record and a four-way auto-catwalk record, rebuilds their
appearance chunk, and requires resolved states `plating` and `15`. A rendered
`plating_random` or `auto` state, or any dynamic fallback, fails the test.

`tools/dev.py test` now runs both `tests.test_map_import` and
`tests.test_dm_appearances`, making these generated-data contracts part of
the standard local and audit entry point.

### Follow-up validation

```text
python3 -m unittest -v tests.test_dm_appearances
  Ran 9 tests ... OK

luajit tests/run.lua
  27 tests, 0 failures

python3 tools/dev.py test
  27 Lua tests, 0 failures
  28 Python tests, OK

python3 tools/dev.py audit
  27 Lua tests, 0 failures
  28 Python tests, OK
  1,172 DM rules, 2,101 sprites, 2 compact pages
  asset, mod, boundary, format, link, workflow, and Git LFS audits passed
```

The compact-generated manifest, pages, profile, and Atlas scenario were
treated as read-only fixtures throughout this follow-up. The earlier
`git cat-file` `ResourceWarning` was not present in these final focused or
full-audit runs.

## Follow-up: dynamic native visual regressions

### Assignment and scope

The parent assigned a second tests-and-docs-only follow-up after dynamic
appearance projection and synthetic native-state rendering landed:

> Add focused tests for bidirectional Goon door states, native wall/floor/door
> rendering after simulation construction changes, and the renderer's
> four-tile camera margin. Do not edit production, profiles, generators, or
> assets.

Only `tests/run.lua`, `tests/test_dm_appearances.py`, and this agent archive
were changed for the follow-up.

### Door projection contract

The Python compact-catalog fixture now requires both terminal states for five
representative real rules:

| Goon path | Native DMI | Closed | Open |
| --- | --- | --- | --- |
| `/obj/machinery/door/airlock/pyro` | `SL_doors.dmi` | `door_closed` | `door_open` |
| `/obj/machinery/door/poddoor/pyro` | `SL_doors.dmi` | `pdoor1` | `pdoor0` |
| `/obj/machinery/door/poddoor/blast/pyro` | `SL_doors.dmi` | `bdoorsingle1` | `bdoorsingle0` |
| `/obj/machinery/door/unpowered/wood/pyro` | `SL_doors.dmi` | `wood1` | `wood0` |
| `/obj/machinery/door/unpowered/wood/stall` | `door_stall.dmi` | `door1` | `door0` |

The Lua regression resolves all ten directions through the real compact
catalog. Each closed simulation door is given an authored open state, while
each open simulation door starts from the rule's closed default. The resolved
drawable is checked at its source cell, so merely retaining one open and one
closed sprite without actually projecting them would fail. Every family must
project in both directions with zero dynamic fallbacks and zero unresolved
records.

### Simulation-created native states

A second real-catalog fixture begins with two ordinary imported floor records
in one chunk:

1. The first floor becomes a standard wall. Its imported floor becomes hidden
   and the chunk must resolve
   `icons/turf/walls/supernorn/smooth.dmi:norn-0`.
2. Removing that wall must expose the original native
   `icons/turf/floors.dmi:floor` again.
3. The second empty floor becomes a constructed closed door and must add
   `icons/obj/doors/SL_doors.dmi:door_closed` over the native floor.
4. Opening the constructed door must replace that state with `door_open`.

The same fixture also pins semantic replacement of authored map atoms:

- changing an authored ordinary floor's `turf_kind` to plating must hide
  `floor` and synthesize `icons/turf/floors.dmi:plating`;
- changing it again to reinforced floor must hide both obsolete states and
  synthesize `icons/turf/floors.dmi:engine`; and
- changing an authored standard Supernorn wall's `wall_kind` to reinforced
  must hide `norn-0` and synthesize the reinforced `norn-R-0` family.

Every rebuild requires zero dynamic fallbacks and zero unresolved records.
This prevents post-import construction from reverting to colored rectangles
or silently retaining an obsolete initial-map atom.

### Camera overscan contract

A renderer-interface test calls `Renderer.draw` with a recording camera and
lightweight drawing stubs. It requires the renderer to call
`visible_tile_bounds(world, 4)` and verifies that the returned bounds are
passed unchanged to the native map renderer. This pins the four-cell overscan
needed for tall Goon sprites at every viewport edge without depending on a
graphical test runner.

### Focused validation

```text
python3 -m unittest -v tests.test_dm_appearances
  Ran 10 tests ... OK

luajit tests/run.lua
  28 tests, 0 failures

python3 tools/dev.py audit
  28 Lua tests, 0 failures
  29 Python tests, OK
  1,173 DM rules, 2,104 sprites, 2 compact pages
  asset, mod, boundary, format, link, workflow, and Git LFS audits passed
```

The real compact manifest was used as a read-only fixture; no generated file
was rewritten. These 1,173-rule/2,104-sprite counts supersede the earlier
chronological selection figures after the concurrent runtime-state coverage
pass.
