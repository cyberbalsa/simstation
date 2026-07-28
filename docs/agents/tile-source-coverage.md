# Tile and structure source coverage

## Record

- Canonical task: `/root/archive_machine_research`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: source audit, importer implementation, generated
  Atlas update, documentation, and focused validation completed
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> Audit pinned Goonstation source for tile/turf/structure coverage versus Sim
> Station. Identify exact upstream files/symbols for floors, walls, windows,
> doors/airlocks, grilles, tables, chairs, lights, decals, pipes, disposal,
> common fixtures. Implement safe source-pinned importer/catalog improvements
> if isolated to tools/map_import.py + generated content/tests; otherwise gap
> matrix. Do not edit core interaction Lua. Save complete report incl
> commands/findings/decisions to docs/agents/tile-source-coverage.md, update
> docs/agents README/manifest, preserve unrelated files, validate.

The parent subsequently fixed the palette vocabulary: legacy `tile` and
`structure` remain; optional native fields are `turf_kind`, `wall_kind`,
sorted-unique `features`, `source_turfs`, and `source_objects`. The closed
feature vocabulary is:

```text
window grille table chair light storage crate lattice catwalk pipe disposal
sign decal
```

The parent also confirmed that dense furniture blocks NPC/spawn occupancy but
must not invalidate an upstream machine fixture sharing that source turf.

## Observable chronology

1. Inspected the existing DMM compiler, scenario palette validator, generated
   Atlas definition, tests, and concurrent parent changes without modifying
   core interaction Lua.
2. Parsed the exact Atlas crop and counted every source atom and requested
   family. Tested full source-object retention and found it would require 2,254
   palette records, above the 2,048 runtime limit.
3. Audited primary DM definitions from pinned commit
   `1b2b250abb5be747d55e274de0203a59cfc8da78`.
4. Added boundary-safe DM inheritance checks and reviewed classifications to
   `tools/map_import.py`, retaining exact source paths only for converted
   geometry/features. The resulting Atlas palette uses 1,596 records.
5. Corrected two lossy legacy rules: all `/obj/machinery/door` descendants now
   become doors, including six wooden/unpowered placements, while grilles no
   longer become gas-impermeable walls.
6. Extended the Python scenario validator with closed native metadata,
   compatibility checks, source-list bounds, and dense-feature spawn
   passability. Added a separate fixture-anchor predicate for valid
   source-layered machines.
7. Added representative, path-boundary, schema-negative, layered-fixture, and
   exact generated-Atlas tests.
8. Regenerated Atlas only through the compiler and updated the native scenario
   contract and tool documentation.
9. After the agent completed, the parent promoted lattice and catwalk presence
   into actor-passable surfaces over legacy space tiles while keeping them
   outside the atmosphere grid. A focused Lua fixture also proves that an
   intact colocated grille restores movement blocking without blocking gas.

## Pinned source and coverage matrix

All upstream references below are at commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`.
“Presence” means Sim Station retains a native feature and exact reviewed
source path, not that it executes the cited DM behavior.

| Family | Exact upstream source/symbol | Upstream behavior established | Atlas crop | Sim Station result |
|---|---|---|---:|---|
| floor | `code/turf/floors.dm:7`, `/turf/simulated/floor` | Steel floor parent; pryable; burn/break state and hidden underfloor contents | 3,691 non-space, non-wall turfs; 107 paths | `tile=floor`; exact `source_turfs`; ordinary paths use `turf_kind=floor` |
| plating | `code/turf/floors.dm:179`, `/turf/simulated/floor/plating` | Exposed plating family and step material | 1,060 cells; 5 paths | `turf_kind=plating` |
| reinforced floor | `code/turf/floors.dm:1222`, `/turf/simulated/floor/engine` | Reinforced, non-burning/non-breaking engine floor | 266 cells; 3 paths | `turf_kind=reinforced_floor`; subtype path retained |
| wall | `code/turf/walls.dm:4`, `/turf/simulated/wall` | Dense, opaque, gas-impermeable wall; base health 100 | 1,073 cells; 4 paths | `structure=wall`, `wall_kind=standard` unless reinforced; exact path retained |
| reinforced wall | `code/turf/turf_autoalign.dm:91`, `/turf/simulated/wall/auto/reinforced` | Health 300, explosion resistance 7, multi-tool dismantling sequence | 699 cells; 3 paths | `wall_kind=reinforced`; dynamic sequence remains deferred |
| window | `code/obj/window.dm:4`, `/obj/window` | Dense, anchored, gas-impermeable, directional/full-tile blocking, health and reinforcement | No direct `/obj/window`; 378 helper cells | `window` presence plus wall boundary; direction, material, and health subtype are not yet authoritative |
| window/grille helper | `code/modules/mapping/helpers/wingrille_spawner.dm:1`, `/obj/mapping_helper/wingrille_spawn`; auto variants at lines 90 and 127 | Spawns `/obj/mesh/grille/steel` and directional/full window variants | 378 placements; 4 paths | Both `grille` and `window`; exact helper subtype retained |
| grille | `code/obj/mesh.dm:274`, `/obj/mesh/grille` | Dense to movement, but holes pass fluids/gases; broken steel subtype becomes non-dense | 7 explicit steel grilles plus 378 helpers | Canonical `/obj/mesh/grille` and legacy `/obj/grille` accepted; `grille` blocks movement but not gas. Broken-state interpretation remains deferred |
| door | `code/obj/machinery/door/door_parent.dm:4`, `/obj/machinery/door` | Closed parent is dense/fluid-dense; operation, access, crush, damage, open/close and gas crossing | 279 atoms on 269 cells; 27 paths | Every descendant is a door, exact subtype retained, access adapted; initial state is conservatively closed |
| airlock | `code/obj/machinery/door/airlock.dm:10`, `/obj/machinery/door/airlock` | Health 600, autoclose, power, access, panel/wires, welding and cycling state | Most of the 279 door atoms | Geometry/access only; schema-2 machine work owns later behavioral fidelity |
| firedoor | `code/obj/machinery/door/firedoor.dm:7`; `code/modules/mapping/helpers/firedoor_spawn.dm:1` | Firedoor defaults open/non-dense; helper layers a pyro firedoor over a normal door | 115 helper placements | Helper remains an explicit omission; co-located main door is retained. Executing helper setup and alarm layering is deferred |
| table | `code/obj/table.dm:11`, `/obj/table` | Dense, anchored furniture; smoothing, drawers, wrenching and material behavior | 155 cells; 10 paths | Dense `table` presence and exact path; behavior deferred |
| chair | `code/obj/stool.dm:575`, `/obj/stool/chair` | Securing, folding, buckling, sitting/climbing, comfort and scooting | 74 atoms on 72 cells; 23 paths | Non-dense `chair` presence and exact path; behavior deferred |
| light | `code/modules/power/lighting.dm:181`, `/obj/machinery/light` | Area membership, power channel, lamp state, brightness, dismantling and wall autoposition | 354 atoms on 353 cells; 32 paths | `light` presence and exact path; no light network or lamp state yet |
| decal/sign | `code/obj/decal.dm:1`, `/obj/decal`; `code/obj/decal/poster.dm:2` and nested `wallsign` at line 30 | Non-structural plane objects; posters/signs and randomized display variants | 413 decal atoms on 334 cells; 62 sign atoms on 35 cells | `decal` and `sign` presence with exact path; no random DM setup or authored visual state execution |
| atmosphere pipe | `code/modules/atmospherics/machinery/pipe.dm:21`, `/obj/machinery/atmospherics/pipe`; `code/modules/atmospherics/pipe_network.dm:3`, `/datum/pipe_network` | Directional networks, gas reconciliation, pressure fatigue, rupture/leak and welding repair | 124 cells; 8 paths | `pipe` presence and exact subtype; connectivity, gas volume and rupture are deferred |
| disposal | `code/modules/disposals/disposal.dm:16`, `/obj/disposalholder`; line 201, `/obj/disposalpipe`; `code/modules/disposals/disposal_chute.dm:19`, `/obj/machinery/disposal` | Virtual holders transport items and gas through directional underfloor pipes; powered chutes charge and flush | 494 converted objects on 464 cells, 32 paths, plus 1 endpoint landmark | `disposal` presence/path; underfloor segments stay passable. Directional routing, chute density/state, mail tags and transport are deferred |
| lattice | `code/obj/lattice.dm:2`, `/obj/lattice` | Non-dense, provides grip in vacuum; converts to catwalk/floor | 289 cells; 2 paths | `lattice` presence/path; parent integration makes it walkable over legacy space without creating gas; construction remains deferred |
| catwalk | `code/obj/mesh.dm:499`, `/obj/mesh/catwalk`; catwalk turf paths under `code/turf/floors_airless.dm` | Walkable/dismantlable mesh surface over floor or converted space | 319 atoms on 318 cells, plus catwalk turf paths | `catwalk` from object or turf path; underlying turf class retained; parent integration supplies space traversal |
| storage/crates | `code/obj/storage/large_storage_parent.dm:14`, `/obj/storage`; `code/obj/storage/crates.dm:1`, `/obj/storage/crate` | Dense containers with open/lock/weld/contents state; crate variants are short storage | 100 cells; 26 crate cells | Dense `storage`; crate paths add `crate`; exact path retained |
| common omitted fixtures | `code/obj/rack.dm:3`; `code/modules/camera/camera.dm:1`; `code/obj/railing.dm:1`; `code/obj/machinery/firealarm.dm:5` | Dense racks/railings, camera networks, and area fire-alarm/firelock control | 31 racks, 92 cameras, 24 railings on 20 cells, 40 fire alarms | Catalogued in deterministic omissions, not promoted to the closed feature vocabulary |

Window blinds are deliberately not treated as windows:
`/obj/window_blinds` is a sibling path, not a subtype of `/obj/window`.
All 41 Atlas blind placements already share a real wingrille helper cell.
Likewise `/obj/machinery/door_control` is not a descendant of
`/obj/machinery/door`.

## Atlas source and generated census

The selected crop is exactly 192×192 = 36,864 cells:

```text
source atoms: 81,182
  turfs:      36,864
  areas:      36,864
  objects:     7,433
  mobs:           21

compiled palette: 1,596 / 2,048
compiled runs:    4,443
areas:               92
fixtures:            134
spawns:               85
```

Compiled cell classifications:

| Classification | Cells |
|---|---:|
| source space | 32,100 |
| ordinary floor | 2,365 |
| plating | 1,060 |
| reinforced floor | 266 |
| wall turf (native floor kind intentionally omitted) | 1,073 |
| standard/reinforced/window wall structure total | 1,407 |
| closed door | 269 |

Feature cell counts are exact and fixture-tested:

```text
catwalk 318  chair 72   crate 26     decal 334
disposal 464 grille 385 lattice 289  light 353
pipe 124     sign 35    storage 100  table 155
window 378
```

The palette contains 112 unique source turf paths and 263 unique reviewed
source object paths. Retaining every object, including items and decorative
atoms with no converted meaning, would require 2,254 palette records and was
rejected. Selective reviewed provenance retains the information needed to
extend each implemented class while staying 452 records below the cap.

## Implemented contracts

`tools/map_import.py` now:

- performs exact-or-descendant DM path checks, preventing sibling-prefix
  mistakes;
- classifies space, plating, floor, reinforced floor, standard wall and
  reinforced wall;
- emits sorted unique closed features;
- preserves sorted unique source turf paths and reviewed source object paths;
- recognizes all door descendants, direct windows, wingrille helpers,
  canonical and legacy grilles, furniture, lights, storage, lattice/catwalk,
  pipes, disposal, signs and decals;
- keeps grille gas behavior distinct from windows/walls;
- retains valid window-plus-door and fixture-plus-furniture source layers; and
- rejects compilation above 2,048 palette entries before writing output.

`tools/mods.py` now validates the same closed palette vocabulary, source path
roots and ordering, wall/turf compatibility, window boundary compatibility,
crate/storage dependency, and dense actor/spawn passability. Fixture anchors
use a separate predicate because Atlas has 17 legitimate dense-furniture
layers: 16 APCs and one cargo pad.

## Decision disposition

### Accepted

- Preserve exact reviewed upstream paths in native palette records.
- Treat `/obj/mesh/grille` as canonical and retain `/obj/grille` only for
  legacy-compatible mods.
- Keep grille movement density without making it gas-impermeable.
- Recognize every `/obj/machinery/door` descendant, recovering six Atlas
  wooden/unpowered doors missed by the earlier airlock/poddoor-only rule.
- Keep source-layered windows behind shutters and machines on furniture.
- Enforce the palette cap in the compiler as well as the validators.

### Adapted

- A window normally maps to `structure=wall`, but it may coexist with
  `door_closed`/`door_open` when a shutter and wingrille helper share a cell.
- Dense features reject actor/spawn anchors; machine fixtures use the older
  non-boundary floor rule so upstream wall-mounted/over-table placement is not
  relocated or discarded.
- Full provenance is selective rather than every-object: converted tile
  semantics stay exact while fixture/spawn records continue to own their own
  source paths.

### Rejected

- Prefix matching that makes `/obj/window_blinds` a window or
  `/obj/machinery/door_control` a door.
- Treating a grille as a wall, which incorrectly blocks atmosphere.
- Executing DM helper code during import.
- Loading DMI or DMM as a runtime format.
- Relocating or omitting layered machine fixtures merely to make their source
  cell actor-passable.
- Retaining all object paths in each cell and exceeding the palette limit.

### Unresolved

- Directional/full-window geometry, reinforcement/material health and broken
  grille state need explicit versioned data.
- Firedoor helpers, alarms and stacked door state need a layered structure
  contract.
- Table/chair/storage/light interactions remain feature presence only.
- Atmosphere pipes and disposal pipes need stable directional topology,
  per-network state and deterministic update algorithms.
- Lattice-to-catwalk/floor construction, grip/slip behavior, damage, and
  connected variants are not yet implemented; basic traversal over
  `tile=space` was resolved in parent integration.
- Racks, cameras, railings, fire alarms and many other common fixtures remain
  deterministic omissions pending feature or machine contracts.

## Commands and validation

Primary evidence and implementation checks used:

```text
git -C assets/cache/goonstation grep -n <symbol> \
  1b2b250abb5be747d55e274de0203a59cfc8da78 -- code
git -C assets/cache/goonstation show \
  1b2b250abb5be747d55e274de0203a59cfc8da78:<path>
python3 tools/map_import.py compile maps/atlas.dmm \
  --scenario-id org.simstation.core:scenario/goon-atlas \
  --name 'NCS Atlas — Sim Station' \
  --crop 61 61 252 252 --z 1 --power-supply-w 750000 \
  --pretty --output mods/org.simstation.core/scenarios/goon-atlas.json
python3 -m unittest tests.test_map_import -v
python3 tools/dev.py audit
```

The focused Python suite passed 16/16 tests before handoff. The final generated
scenario SHA-256 reported by the compiler was
`269c0e5df69fe4a67892166783f541d6815f57e92b648bde97f640ae58afe04c`.
Manifest JSON and `git diff --check` passed. The required full audit reached
the concurrent Lua suite: 23/24 tests passed, with test 13,
`structure definitions own closed sorted interaction profiles`, failing at
`tests/run.lua:500` because expected structure schema `2` was `nil`. This task
did not edit structure definitions or that runtime contract; all subsequent
tile, machine and native-Atlas tests passed, including Atlas manufacture and
save/restore.

## Sources

- Pinned Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- `maps/atlas.dmm` from its locked Git blob.
- The exact upstream files and symbols in the coverage matrix.
- `tools/map_import.py`, `tools/mods.py`, and `tests/test_map_import.py`.
- Generated `mods/org.simstation.core/scenarios/goon-atlas.json`.
- `docs/technical/08-native-scenarios-and-map-import.md`.
