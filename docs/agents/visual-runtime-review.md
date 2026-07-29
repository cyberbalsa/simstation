# Native map visual runtime review

## Record

- Canonical task: `/root/visual_runtime_review`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: read-only production review completed; focused
  runtime, catalog, importer, generated-data, and upstream checks reported
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> Review new uncommitted `src/assets/dm_appearance_catalog.lua`,
> `src/presentation/map_appearance.lua`, and scenario appearance validators
> for correctness, performance, deterministic ordering, LÖVE API use, and
> dynamic visibility. Do not edit production files. Add focused tests only if
> isolated without overlapping current tests/run.lua; otherwise report exact
> issues/fixes. Inspect emerging dm-appearances.json. Archive review/state
> docs/agents and update manifest/index if safe.

### Follow-up assignment

> Before finishing, please inspect the proposed mutable-cell fallback issue in
> your archive/context and send me a concise recommendation for native Goon
> paths/states for constructed wall, floor/plating, and door. No production
> edits.

## Scope and evidence

The review did not edit production code or generated assets. It inspected the
shared worktree while the parent and the compact-atlas agent were integrating
changes, so accepted fixes and remaining issues below describe the last
observed source rather than an independent patch.

Reviewed project files included:

- `src/assets/dm_appearance_catalog.lua`
- `src/presentation/map_appearance.lua`
- `src/presentation/renderer.lua`
- `src/presentation/camera.lua`
- `src/core/scenario.lua`
- `src/core/world.lua`
- `tools/assets.py`
- `tools/map_import.py`
- `tools/mods.py`
- `tools/dev.py`
- `tests/test_dm_appearances.py`
- the generated Atlas scenario and DM-appearance selection

All upstream behavior claims below refer to the locally cached, pinned
Goonstation commit `1b2b250abb5be747d55e274de0203a59cfc8da78`.

## Accepted fixes observed during review

- The generated selection was repacked from 30 sparse source pages into two
  dedicated 2048-by-2048 runtime pages. After adding the constructed-door
  root, the final observed selection had 2,104 sprites and 1,173 rules.
- The compact generator verifies the new pixels against their canonical atlas
  rectangles and retains source provenance.
- Runtime placement now treats a BYOND atom anchor as the bottom-left of its
  32-pixel cell. It accounts for source dimensions and applies `pixel_x` and
  `pixel_y` without scaling the native art.
- Single-direction sprites retain their only valid direction. Missing
  multi-direction entries fail visibly instead of silently becoming south.
- Single-part map `icon` and `icon_state` overrides resolve together;
  per-instance overrides are not incorrectly imposed on every part of a
  multi-part helper.
- Catalog/scenario provenance is compared before the native Atlas path is
  enabled.
- Dynamic resolution errors, static unresolved records, and fallback counts
  are retained as diagnostics rather than silently discarded.
- Connected turf catwalks now project the pinned cardinal bitmask instead of
  rendering the `auto` question-mark state.
- Random plating projects to ordinary `plating`; the
  `plating_random` map-editor state is not used at runtime.
- Chunk caches and their final render-run signatures now include the global
  topology revision.
- Ordinary airlock, poddoor, blast-door, wood-door, and stall-door families
  now project open and closed states bidirectionally.
- A semantic-hole pass now supplies native Goon turf and door art when a
  simulation-created atom has no visible imported appearance.
- Imported turfs are now compatibility-gated against authoritative semantic
  families, so floor/plating/reinforced-floor and standard/reinforced-wall
  transitions can select replacement art instead of retaining a stale map
  record.
- The renderer now requests a uniform four-tile culling margin, covering the
  largest observed selected appearance extent.
- A fresh Xvfb smoke capture showed native Goon art without obvious
  question-mark placeholders in the default view. Four visible chunks took
  approximately 209 total LÖVE draw calls, down from approximately 717 before
  compact repacking.

## Remaining correctness blockers

### Dynamic replacement and state projection

Native rendering remains all-or-nothing: when the appearance catalog is
active, the renderer skips the semantic static map entirely. The final
observed semantic-hole pass prevents simulation-created turf and door atoms
from disappearing. Imported turfs are also compatibility-gated against
authoritative `wall_kind` and `turf_kind`: the classifier distinguishes space,
the engine-floor subtree, paths with a plating segment, ordinary floors, and
standard versus reinforced wall paths. This addresses the reviewed
floor-to-plating, plating-to-reinforced-floor, and wall-family replacement
defect. Those transitions still merit dedicated regressions beyond the
existing wall construction/removal coverage.

The pinned Atlas defaults for filling those gaps are:

- ordinary floor: `/turf/simulated/floor`,
  `icons/turf/floors.dmi:floor`;
- exposed plating: `/turf/simulated/floor/plating`,
  `icons/turf/floors.dmi:plating`;
- standard Atlas wall: `/turf/simulated/wall/auto/supernorn`,
  `icons/turf/walls/supernorn/smooth.dmi:norn-<mask>`;
- reinforced Atlas wall:
  `/turf/simulated/wall/auto/reinforced/supernorn`, state
  `norn-R-<mask>` in the same DMI; and
- default Atlas airlock: `/obj/machinery/door/airlock/pyro`,
  `icons/obj/doors/SL_doors.dmi:door_closed` or `door_open`.

The `mapwall` and `mapwall_r` wall states are editor placeholders, not runtime
fallbacks. The generated selection already contained both door sprites but
initially lacked a rule for the exact `/airlock/pyro` root because the source
crop did not instantiate it. The final profile now supplies that explicit
rule.

Goon has two valid floor-construction endpoints. Its base RCD creates a full
`floor`, while manual construction with a floor tile immediately calls
`to_plating()` and displays `plating`. Sim Station's current floor blueprint
sets authoritative `TURF.FLOOR`, so `floor` is consistent unless the public
blueprint contract is intentionally changed to represent the manual first
stage.

Goon also preserves a floor's covered icon state when constructing a wall and
restores it when that wall is removed. Sim Station should keep an existing
native floor record hidden beneath a constructed wall and reveal it later.
The semantic floor/plating default is needed only when no underfloor record
exists, such as a map-authored wall.

These choices belong in pack-owned mutable appearance defaults, not Goon path
conditionals in the renderer. A synthetic fallback should be emitted only
when current world semantics have no compatible native turf or door record.
Door orientation must be stored with the authoritative blueprint; pinned Goon
uses the builder's facing. The current north/south-boundary inference is a
reasonable emergency visual fallback, not parity.

Door projection is now bidirectional for the reviewed families. Door identity
is still not authoritative, however. If a map-authored departmental door is
destroyed and a generic door is later built at the same cell, the old imported
door record becomes visible again merely because the semantic structure is a
door. The robust solution is authoritative, pack-resolved appearance identity
and generation for mutable structures, including direction. Compatibility
gating by door type is only possible after that identity exists.

Several authoritative interaction states invalidate only a chunk and never
change the selected source state. Examples include rotated chairs, open or
welded storage, removed/toggled/broken lights, damaged tables and grilles, and
machine powered/broken/destroyed states. `covers_machine` suppresses the
semantic machine sprite solely because a matching static source path exists,
even when the machine state needs different art or the machine is destroyed.

The catalog always selects animation frame one. It retains duration metadata
but has no deterministic animation clock or state-machine contract.

### Painter ordering

The generated rules currently contain no inherited `layer_milli` or plane
metadata. Only a small number of direct DMM instance overrides provide a
layer. The runtime consequently substitutes broad turf/object defaults and a
three-value plane heuristic for upstream initial appearance ordering.

The entire native static map is drawn before semantic machines and crew.
Static, machine, crew, and foreground appearances cannot therefore be
interleaved by their resolved plane, layer, screen foot position, and stable
tie-breakers. This is especially visible for tall furniture and machines.
The long-term contract should put all appearance-bearing entities into one
stable painter stream, or expose reviewed foreground passes with equivalent
metadata.

### Connected-family parity

The runtime connection predicate remains semantic and coarse rather than
type-family exact:

- pinned grilles connect to reviewed wall, grille, door, and window types, not
  merely adjacent semantic grille features;
- auto-table types use their own `smooth_list` families and add diagonal
  corner overlay images in `code/obj/table.dm`; the runtime joins every table
  feature and emits only the cardinal base state;
- Supernorn walls have type-specific connect lists and overlay behavior; and
- window helper parts and ordinary/reinforced wall families do not all share
  one generic boundary predicate.

The grille state spelling now matches upstream: a healthy steel grille is
`grille<normalized-cardinal-mask>-0`. The generated helper metadata
`state_prefix = "grille"` and `state_suffix = "-0"` is correct.

### Cache invalidation and culling

Every topology edit currently forces every subsequently visible chunk to
rebuild. Neighbor-aware per-chunk invalidation would avoid this global cost
while retaining correct cross-chunk connected states.

Actual Atlas appearances extend:

- 64 pixels left and right;
- 128 pixels above; and
- 30 pixels below their anchor.

The largest observed case is a 160-by-160 Christmas tree with
`pixel_x = -64`. The new uniform margin of four is safe for the current
selection. A catalog-derived asymmetric extent remains preferable if future
packs can exceed that bound.

### First-party mod parity

`DmAppearanceCatalog.new()` hardcodes
`assets/runtime/goon/graphics/dm-appearances.json` and its asset root, while
`MapAppearance.new()` recognizes one exact Atlas map/crop provenance record.
The public scenario validators nevertheless accept `map.appearances` for
every pack. A normal mod has no registration path for its own catalog and
cannot exercise the first-party rendering capability. This violates the
repository rule that base content must not receive an extension path that a
normal mod cannot use.

Catalog selection should be an ordinary pack-owned content declaration with a
stable ID, declared assets, provenance, and dependency/override rules. A
scenario should reference that ID rather than a hardcoded filesystem path.

## Generator and validation risks

- The bounded DM declaration parser processes source files in sorted Git path
  order rather than pinned `.dme` inclusion order. Reopened types can
  therefore receive the wrong last assignment.
- A non-literal child assignment is ignored rather than recorded as an
  inheritance barrier. A later static lookup can incorrectly inherit a
  parent's literal even though the child overrides that property dynamically.
- The static parser strips `//` without respecting quoted strings.
- Literal upstream plane values and layer expressions/macros are not resolved,
  explaining the absence of rule-level painter metadata.
- Lua and Python scenario validation now agree on role/type roots, safe DMI
  paths, integer offsets, and fixed-point layers. The importer also uses
  `type(value) is int`, so DM booleans are no longer accepted as offsets or
  directions.
- The generated coverage remains explicit: 43,802 of 43,813 Atlas appearance
  instances map, with 11 fallback instances across eight prop paths.

## Test and runtime observations

- `luajit -b src/assets/dm_appearance_catalog.lua ...` — passed.
- `luajit -b src/presentation/map_appearance.lua ...` — passed.
- Xvfb/LÖVE smoke launch for 14 seconds — passed without logged runtime
  errors; the captured frame showed approximately 209 draw calls.
- `python3 -m unittest -v tests.test_dm_appearances` — four tests passed and
  two stale assertions failed during the initial review:
  - the test expected old wingrille metadata
    `("grille-0", "grille-")` instead of upstream-correct
    `("grille1-0", "grille")` plus suffix `"-0"`; and
  - the test expected the old inherited `floor` fallback instead of the
    corrected `twotone_black` macro expansion.
- The test owner corrected those expectations, expanded the module to nine
  focused tests, and registered it in `tools/dev.py test`. A subsequent direct
  run passed all nine tests.
- A later required `python3 tools/dev.py audit` run passed all 27 Lua tests.
  During its Python phase, 27 of 28 tests passed and the catalog profile-hash
  assertion caught a newer, concurrently edited profile that had not yet been
  regenerated. This was reported immediately to the parent. The parent then
  regenerated the selection.
- The final `python3 tools/dev.py audit` passed: 28 Lua tests, 29 focused
  Python tests, mod validation, asset/provenance checks, JSON/TOML checks,
  core-boundary checks, documentation links, workflow pins, and Git LFS
  attributes.

Recommended focused regressions are:

- connected catwalk selection never resolves the `auto` placeholder;
- random plating never resolves `plating_random`;
- open and closed transitions for ordinary airlocks and poddoors;
- wall/floor/space replacement after supported construction/destruction,
  including floor-to-plating, plating-to-reinforced-floor, and standard-to-
  reinforced-wall transitions;
- destroy and reconstruct a different door family at the same map cell;
- a topology edit across a visible chunk boundary changes render batches;
- a four-tile-tall sprite whose anchor is outside the viewport still renders
  the portion inside it;
- connected table corner overlays and type-family isolation; and
- destroyed or state-changing machines are not covered by stale static art.

## Visible coordination summary

This section contains only findings and messages made externally visible to
the parent; it does not reconstruct hidden reasoning.

- Requested a compact dedicated runtime selection because the original
  30-page reference set caused unnecessary residency and SpriteBatch runs.
- Reported the catwalk `auto` question-mark root cause and the pinned
  cardinal-mask update behavior.
- Reported the hardcoded base-only catalog path, missing painter metadata,
  static/dynamic coverage gap, coarse connection families, topology cache
  issue, and incomplete diagnostics.
- Quantified the current culling extents and recommended catalog-derived
  margins.
- Reported the bidirectional door/poddoor and replacement-turf defects.
- Reported pack-owned mutable defaults for floor, plating, Atlas Supernorn
  walls, reinforced walls, and the default directional pyro airlock, including
  the full-floor versus manual-plating construction distinction.
- Reported both stale focused-test expectations and the missing test-runner
  registration.
- Confirmed after regeneration that the compact native default view no longer
  showed obvious question-mark placeholders and used approximately 209 total
  draws.

## Sources

- pinned `code/atom.dm` connection direction bit flags
- pinned `code/turf/turf_autoalign.dm`
- pinned `code/turf/floors_airless.dm`
- pinned `code/turf/floors.dm`
- pinned `code/turf/turf.dm`
- pinned `code/obj/mesh.dm`
- pinned `code/obj/table.dm`
- pinned `code/obj/item/building_materials.dm`
- pinned `code/obj/item/rcd/rcd.dm`
- pinned `code/map.dm`
- pinned `code/procs/access.dm`
- pinned `code/obj/machinery/door/airlock.dm`
- pinned `code/obj/machinery/door/airlock_pyro.dm`
- pinned `code/obj/machinery/door/poddoor.dm`
- generated `assets/runtime/goon/graphics/dm-appearances.json`
- generated `mods/org.simstation.core/scenarios/goon-atlas.json`
