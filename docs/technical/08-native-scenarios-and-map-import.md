# Native scenarios and Goon-informed map import

## Status and scope

`simstation-map-v1` is the smallest native starting-map contract for the
current playable-station milestone. It is:

- one finite, orthogonal station plane;
- an ordinary `scenario` definition owned and replaced through the mod
  registry;
- a sparse, row-major seed expanded into a new authoritative `World`;
- independent of DMM, DM inheritance, Tiled, atlas coordinates, and LÖVE
  objects; and
- used only when starting a campaign, never as a substitute for saved world
  state.

This format deliberately covers the physical substrate already implemented:
space/floor, native floor/plating/reinforced-floor class, standard/reinforced
walls, empty/wall/door structure, reviewed tile features, cable presence,
initial pressure, areas, a bounded set of fixture adapters linked to namespaced
machine definitions, crew spawn markers, and meteor targets. A feature records
source presence and the movement/gas distinction already modeled; it does not
claim full upstream behavior. Pipe/disposal topology, multi-tile footprints,
remote planes, item placement, and dynamic decoration state require later
versioned contracts. Existing fields must not be silently reinterpreted.

The current implementation is in `src/core/scenario.lua`. Package validation
begins in `tools/mods.py`, and `src/mods/loader.lua` loads files selected by a
pack's `scenario_maps` manifest field. The first-party Atlas scenario is the
normal application start and round-trips through the current save format. The
full release contract below remains stricter than the implemented milestone;
the differences are listed under
[Implementation audit](#implementation-audit).

## How Goon maps inform this format

The immutable source is the Goonstation tree at commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`. `tools/map_import.py` reads map
bytes from Git blobs at that exact commit. It never edits the checkout or
executes DM.

The pinned corpus contains 570 `.dmm` files, all using Goon's TGM-style
dictionary/coordinate representation. The 20 direct files under `maps/` parse
cleanly. Most full stations are 300×300 and therefore cannot be copied directly
into the 192×192 milestone station. For example, `maps/cogmap.dmm` contains:

- 90,000 mapped cells, of which 14,330 use non-space turf;
- 12,736 station-area cells across 25 first-level area families;
- 22,544 placed objects, including 5,048 machinery placements; and
- broad primary/secondary hallways, maintenance belts, department rooms,
  utility routes, and service/logistics connections.

Those measurements make Cogmap useful layout evidence, not a runtime template.
The first checked-in candidate instead uses a 192×192 crop of the smaller
`maps/atlas.dmm`. Its generated
`org.simstation.core:scenario/goon-atlas` contains 1,596 palette entries, 4,443
runs, 92 areas, 134 selected fixtures, 85 spawn markers, and 64 sampled meteor
targets. Atlas still supplies broad department coverage while its full source
has 7,436 object placements rather than Cogmap's 22,544.

The selected source rectangle is `(61,61)` through `(252,252)` on Z level 1.
It contains 7,433 object placements: 5,028 are represented by the current
tile/feature/door/cable/fixture/spawn adapters and 2,405 are recorded as
unsupported. Exact reviewed source paths remain in sorted `source_turfs` and
`source_objects` lists. The compiled palette is 452 records below the 2,048
record limit.
The source-preserving machine pass retains every selected machine adapter,
including multiple machine atoms on one source tile, with no fixture-collision
or invalid-anchor omission. One duplicate spawn is still recorded explicitly
in generated provenance.

The Sim Station layout should retain legible department clusters, circulation
loops, maintenance access, airlock boundaries, utility routing, and
machine-to-workflow proximity while being rebuilt or cropped for 24 autonomous
workers and management-scale readability.

The analyzer records type paths, override names, and only override values that
its non-executing literal reader can prove are strings, booleans, or exact
integers. The `compile` command applies the versioned
`goon-type-path-adapter-v1` profile to a bounded crop. It currently recognizes
a reviewed set of turf classes, walls, doors/windows/grilles, furniture,
lights, storage, lattices/catwalks, decals/signs, atmosphere and disposal
pipes, cables, areas, job landmarks, and fixture path families. A fixture
preserves safe values in
`source_overrides`; its referenced machine definition separately allowlists
which names may initialize authoritative state. DM expressions remain opaque
and cannot become behavior. Decorative or unsupported atoms are either mapped
by a reviewed rule, recorded in a deterministic omission report, or block a
release candidate; silently dropping them is not the final contract.

### Coordinate conversion

Goon DMM coordinates are 1-based with positive Y pointing north. In a TGM
coordinate block the first textual row represents the highest Y. Native Sim
Station coordinates are 1-based with `(1,1)` at the top left, positive X to
the right, and positive Y downward. For a selected Goon rectangle:

```text
native_x = goon_x - selected_min_x + 1
native_y = selected_max_y - goon_y + 1
```

Only one selected Goon Z level may feed one `simstation-map-v1` definition.
Cropping, rotation, or reconstruction is an authored decision recorded in
provenance, not an implicit parser option.

## Package and definition envelope

A pack declares native scenarios separately from ordinary content:

```toml
scenario_maps = ["scenarios/*.json"]
```

Each selected JSON document uses the same registry envelope as other content:

```json
{
  "schema": 1,
  "definitions": [
    {
      "id": "org.example.station:scenario/goon-informed-proof",
      "kind": "scenario",
      "schema": 1,
      "name": "Goon-informed Proof Station",
      "map": {
        "format": "simstation-map-v1",
        "width": 16,
        "height": 16,
        "default_palette": 1,
        "palette": [],
        "runs": []
      }
    }
  ]
}
```

The document schema, scenario schema, and map format are independently
versioned. Schema 1 currently uses the required author-facing `name` string;
moving to localization keys requires a scenario-schema revision or an explicit
backward-compatible optional field.

The scenario `id` is a normal `ContentId` and must use the owning pack's
namespace unless the complete definition is an approved replacement.
Cross-definition references, including starting inventory item IDs and spawn
job IDs, are full namespaced `ContentId`s.

Nested authored instances also need stable, namespaced identities. They use the
`ContentId` lexical form but are scenario-local records, not independently
registered definitions:

```text
org.example.station:scenario-area/goon-informed-proof/engineering
org.example.station:scenario-fixture/goon-informed-proof/generator-01
org.example.station:scenario-spawn/goon-informed-proof/engineering-01
```

Palette indices, array positions, localized names, Goon paths, and coordinates
are never identities. Primitive wire tokens such as `floor`, `wall`, and
`engineering` are closed schema enums rather than public IDs.

Schema 1 has exactly one map, so the runtime `world.map_id` is the scenario
`ContentId`. A distinct map ID and remote maps belong in a later scenario
schema; adding an ignored `map.id` now would create two competing identities.

## Complete JSON example

This compact fixture is valid at the structural level and demonstrates every
schema-1 section. The layout is intentionally synthetic while its provenance
records Cogmap as research input.

```json
{
  "schema": 1,
  "definitions": [
    {
      "id": "org.example.station:scenario/goon-informed-proof",
      "kind": "scenario",
      "schema": 1,
      "name": "Goon-informed Proof Station",
      "provenance": {
        "schema": 1,
        "method": "goon-informed-reconstruction",
        "sources": [
          {
            "repository": "goonstation/goonstation",
            "commit": "1b2b250abb5be747d55e274de0203a59cfc8da78",
            "path": "maps/cogmap.dmm",
            "git_blob": "b94e5abf1673052e28fb8090ba54fa7bab189a05",
            "sha256": "dacb2f0c0617c8dcd16433ca9cf92042da2bde83f7e8268aa6880e51a9ec31f7",
            "role": "layout-reference"
          }
        ],
        "tool": {
          "path": "tools/map_import.py",
          "format_version": 1
        },
        "notes": "Rebuilt at milestone scale; no DM override values imported."
      },
      "areas": [
        {
          "id": 1,
          "key": "org.example.station:scenario-area/goon-informed-proof/engineering",
          "name": "Engineering",
          "department": "engineering",
          "access": "public",
          "source_path": "/area/station/engine"
        },
        {
          "id": 2,
          "key": "org.example.station:scenario-area/goon-informed-proof/cargo",
          "name": "Cargo",
          "department": "cargo",
          "access": "public",
          "source_path": "/area/station/quartermaster"
        }
      ],
      "map": {
        "format": "simstation-map-v1",
        "width": 16,
        "height": 16,
        "default_palette": 1,
        "palette": [
          {
            "key": "space",
            "tile": "space",
            "turf_kind": "space"
          },
          {
            "key": "engineering-floor",
            "tile": "floor",
            "turf_kind": "floor",
            "structure": "empty",
            "cable": true,
            "pressurized": true,
            "area": 1,
            "source_turfs": ["/turf/simulated/floor"]
          },
          {
            "key": "hull-wall",
            "tile": "floor",
            "structure": "wall",
            "wall_kind": "standard",
            "cable": false,
            "pressurized": false,
            "area": 0,
            "source_turfs": ["/turf/simulated/wall/auto"]
          },
          {
            "key": "public-airlock",
            "tile": "floor",
            "turf_kind": "plating",
            "structure": "door_closed",
            "cable": true,
            "pressurized": true,
            "area": 1,
            "access": "public",
            "source_objects": ["/obj/machinery/door/airlock"]
          },
          {
            "key": "cargo-floor",
            "tile": "floor",
            "turf_kind": "floor",
            "structure": "empty",
            "cable": true,
            "pressurized": true,
            "area": 2
          }
        ],
        "runs": [
          [68, 4, 3],
          [72, 1, 4],
          [73, 5, 3],
          [84, 1, 3],
          [85, 4, 2],
          [89, 4, 5],
          [93, 1, 3],
          [100, 1, 3],
          [101, 4, 2],
          [105, 4, 5],
          [109, 1, 3],
          [116, 1, 3],
          [117, 4, 2],
          [121, 4, 5],
          [125, 1, 3],
          [132, 1, 3],
          [133, 4, 2],
          [137, 4, 5],
          [141, 1, 3],
          [148, 1, 3],
          [149, 4, 2],
          [153, 4, 5],
          [157, 1, 3],
          [164, 1, 3],
          [165, 4, 2],
          [169, 4, 5],
          [173, 1, 3],
          [180, 10, 3]
        ]
      },
      "fixtures": [
        {
          "id": "org.example.station:scenario-fixture/goon-informed-proof/apc-01",
          "kind": "apc",
          "x": 5,
          "y": 6,
          "department": "engineering",
          "source_path": "/obj/machinery/power/apc"
        },
        {
          "id": "org.example.station:scenario-fixture/goon-informed-proof/generator-01",
          "kind": "generator",
          "x": 6,
          "y": 7,
          "department": "engineering",
          "source_path": "/obj/machinery/power/generator"
        },
        {
          "id": "org.example.station:scenario-fixture/goon-informed-proof/refinery-01",
          "kind": "refinery",
          "x": 7,
          "y": 9,
          "department": "engineering"
        },
        {
          "id": "org.example.station:scenario-fixture/goon-informed-proof/cargo-pad-01",
          "kind": "cargo_pad",
          "x": 10,
          "y": 9,
          "department": "cargo"
        }
      ],
      "spawns": [
        {
          "id": "org.example.station:scenario-spawn/goon-informed-proof/engineering-01",
          "x": 6,
          "y": 8,
          "job": "org.simstation.core:job/engineer",
          "department": "engineering"
        },
        {
          "id": "org.example.station:scenario-spawn/goon-informed-proof/cargo-01",
          "x": 10,
          "y": 8,
          "job": "org.simstation.core:job/cargo-technician",
          "department": "cargo"
        }
      ],
      "meteor_targets": [
        {
          "x": 4,
          "y": 8
        }
      ],
      "power_supply_w": 250000,
      "starting_inventory": {
        "org.simstation.core:item/cable-coil": 30,
        "org.simstation.core:item/iron-ore": 20,
        "org.simstation.core:item/steel-sheet": 40
      }
    }
  ]
}
```

## Palette and run encoding

The map expands to `width * height` cells. Native coordinates and linear
indices relate as follows:

```text
index = (y - 1) * width + x
x = ((index - 1) mod width) + 1
y = floor((index - 1) / width) + 1
```

`default_palette` fills every cell first. Runs then replace cells. Each run is
`[start_index, length, palette_index]`, using 1-based integers. Runs:

- sort by increasing `start_index`;
- never overlap or cross a row boundary;
- have positive length no greater than `width`;
- refer to an existing palette entry; and
- remain within `width * height`.

Compiler output is canonical: omit runs equal to the default, merge adjacent
same-palette cells within a row, and emit palette entries in raw UTF-8 key
order. Runtime validation may accept an older noncanonical schema-1 file, but
packaging must rewrite or reject it so generated diffs stay reviewable.

Palette entries are closed records:

| Field | Required | Meaning/default |
|---|---:|---|
| `key` | yes | unique diagnostic key, maximum 240 bytes |
| `tile` | yes | `space` or `floor` |
| `turf_kind` | no | `space`, `plating`, `floor`, or `reinforced_floor`; defaults from `tile` and must agree with it |
| `structure` | no | `empty`, `wall`, `door_closed`, or `door_open`; default `empty` |
| `wall_kind` | no | `standard` or `reinforced`; legal only for `structure = wall`, whose runtime default is `standard` |
| `features` | no | sorted unique subset of `window`, `grille`, `table`, `chair`, `light`, `storage`, `crate`, `lattice`, `catwalk`, `pipe`, `disposal`, `sign`, and `decal` |
| `cable` | no | cable occupies this cell; default `false` |
| `pressurized` | no | seed standard O2/N2 and temperature on a non-wall floor; default `false` |
| `area` | no | contiguous numeric area ID, or `0` for none; default `0` |
| `access` | no | required credential for a door; default is owning area access, then `public` |
| `source_turfs` | no | sorted unique absolute `/turf` type paths retained as provenance |
| `source_objects` | no | sorted unique reviewed `/obj` type paths retained as provenance |

Palette data is an initial condition, not a frozen tile classification.
Construction, damage, doors, atmosphere, and utilities mutate the expanded
world. Palette keys, runs, and source-path lists do not enter a save. Native
turf/wall/feature values do enter the expanded world and its snapshots.

Feature compatibility is closed. A `window` must share a wall or door boundary;
this permits source-faithful shutter-plus-window layers. A `crate` also carries
`storage`. Grilles, tables, storage objects, and crates block actor/spawn
occupancy while allowing a source-layered machine fixture to retain the same
coordinate as dense furniture.

### Ordered native appearances

`map.appearances` is an optional, sorted presentation-provenance array. It does
not replace the palette's authoritative simulation semantics. Each record
names one source turf or object at a linear `index` and has an `order` unique
within that cell. The closed record fields are:

| Field | Required | Meaning |
|---|---:|---|
| `index` | yes | 1-based in-bounds cell index |
| `order` | yes | positive source painter order, unique at that index |
| `role` | yes | `turf` or `object` |
| `source_path` | yes | safe absolute DM type path under the matching `/turf` or `/obj` root |
| `direction` | no | one of the eight canonical BYOND directions |
| `icon_override` | no | safe relative `icons/*.dmi` path retained from a literal map override |
| `icon_state_override` | no | bounded literal map state |
| `resolved_icon_state` | no | deterministic importer-resolved runtime state, such as a space variant |
| `pixel_x`, `pixel_y` | no | signed source offsets in whole pixels |
| `layer_milli` | no | literal layer multiplied by 1,000 and stored as an integer |

Records sort by `(index, order)`, may not duplicate that pair, and are capped at
one million per map. The importer masks comments before reading override blocks
and accepts only the closed scalar visual subset above; arbitrary DM
expressions, paths outside `icons/*.dmi`, booleans posing as numeric offsets,
unknown keys, and executable source are rejected.

The core Atlas scenario carries 43,813 records: one turf for every cell plus
6,949 source objects. Its compact runtime catalog activates only when the
scenario provenance matches the catalog's pinned commit, map path, Git blob,
SHA-256, crop, and dimensions. A scenario with matching-looking type strings
but different provenance therefore uses the ordinary semantic renderer instead
of silently borrowing Atlas art rules.

Appearance records describe the authored initial atoms. When authoritative
runtime state changes, the native renderer first hides records incompatible
with the current space/floor/plating/engine-floor, standard/reinforced-wall, or
door state. Connected masks and open/closed families are recomputed from the
world. If construction or dismantling leaves no compatible native record, the
Atlas catalog supplies a reviewed Goon semantic default. These replacements are
presentation fallbacks; saves continue to serialize authoritative tile,
structure, feature, and interaction state rather than imported DM paths.

## Areas

`areas` is an array with contiguous `id` values equal to 1-based array
positions. The world stores those compact integers per tile. Each record has:

- a unique namespaced `key` stable across edits and replacements;
- current schema-1 display `name`;
- one closed department token: `cargo`, `command`, `engineering`, `general`,
  `medical`, `science`, `security`, or `service`;
- an access credential, defaulting to `public`; and
- optional `source_path` for Goon traceability only.

An area is an authored operations/power/access label. It is not proof that a
room is sealed, safe, reachable, powered, or breathable. Runtime room and
network systems derive those facts from physical state.

Goon `/area` paths may suggest boundaries and department ownership, but a
reviewed conversion owns the mapping. The raw path never selects a Sim Station
department or access rule at runtime.

## Fixtures, machines, and spawns

Schema 1 fixture kinds are the finite physical adapters already supported by
the milestone:

```text
apc barcode_computer battery cargo_pad circulator fabricator generator generic
nanofab portable_scrubber reclaimer refinery scrubber supply_console vent
vent_pump
```

Every fixture has a unique namespaced `id`, in-bounds `x`/`y`, one kind,
optional display `name`, optional department token, and optional Goon
`source_path`. A machine fixture may carry a namespaced `definition_id` and safe
scalar `source_overrides`; the generated Atlas fixture set carries explicit
definitions. Fixtures sort by ID before runtime entity allocation. Multiple
independently addressable fixtures may share a tile when the source map layers
multiple atoms there; no fixture is flattened or discarded. Every anchor must
be a floor without a wall or closed door and satisfy kind-specific
preconditions. Dense furniture still blocks actors and spawn points, but it
does not invalidate a wall-mounted or over-table fixture recorded on the same
source turf:

- generators and APCs must touch the authored cable graph;
- an APC must occupy a nonzero area;
- vents and scrubbers must occupy a gas cell; and
- production/cargo machines must be reachable from a spawn or fail validation
  with a coordinate and fixture ID.

These checks protect authored starts; later damage may break any of those
conditions. The raw source path is diagnostic provenance and never selects the
fixture kind. `definition_id` resolves through the ordinary replacement-aware
content registry. Only definition-declared `map_override_fields` can copy a
preserved literal into initial machine state.

The closed physical kind list remains a milestone rendering/placement
constraint, not the behavior API. Schema-2 `machine` definitions already let
any pack provide source-pinned state, cadence, power, wires, typed actions, and
a per-feature fidelity ledger for those adapters. A new footprint or physical
adapter still requires a later scenario schema rather than teaching only the
core pack a special path.

Spawn records are ordered pools, not crew entities. Each has a unique
namespaced `id`, an in-bounds passable coordinate, optional namespaced `job`
reference, and a department token. At campaign start, candidates sort by ID.
Placement chooses exact job, then department, then `general`, round-robin
within the selected pool. A scenario authoring error is not silently repaired
to a distant tile; any nearest-passable fallback is reserved for an explicitly
versioned recovery/migration path.

Schema 1 does not define the roster or crew count. Those remain scenario/start
options until a namespaced roster-template contract is added.

`meteor_targets` is a sorted, duplicate-free list of in-bounds wall/floor
coordinates reviewed as plausible exterior impact sites. Selection from the
list uses only the incident RNG stream and stable list order.

## Provenance

Every Goon-informed scenario records a closed `provenance` object:

- `schema = 1`;
- `method`, such as `goon-informed-reconstruction` or
  `reviewed-path-conversion`;
- the applicable source `license` expression for a direct conversion;
- one or more sources with repository, exact 40-hex commit, repository-relative
  path, Git blob OID, SHA-256, and role;
- importer path, output format version, and named adapter profile;
- a `crop` record when conversion selects source coordinates, including bounds,
  Z level, and native-axis transformation;
- an `omissions` record containing total included/omitted object counts,
  unsupported-path counts, bounded top-path evidence, placement rejections,
  fixture-collision decisions, and duplicate-spawn decisions; and
- an optional bounded note explaining reconstruction and deliberate omissions.

No absolute host paths, timestamps, branch names, mutable URLs, or unpinned
revisions enter generated data. Per-area/fixture `source_path` values supplement
but do not replace the source record. Provenance and required attribution stay
with a replacement scenario even when its physical map is substantially
adapted.

For the checked-in Atlas start, the source record is:

```text
path    maps/atlas.dmm
commit  1b2b250abb5be747d55e274de0203a59cfc8da78
blob    a774a5beaa5fe849495de1eabe2173dca59ddfdd
sha256  694305dc6a227824572b49f4ecb58accb62ef5892a94132420d19f94520d8909
crop    x=61..252, y=61..252, z=1; source Y flipped
```

## Deterministic load semantics

Starting a new campaign performs one transaction:

1. Resolve the exact package lock and deterministic mod order.
2. Parse all scenario documents as data, apply declared complete replacements,
   resolve references against the final registry, and seal it.
3. Select one exact scenario `ContentId`; never fall back to a similarly named
   scenario.
4. Deep-copy and validate the closed scenario, provenance, area, map, fixture,
   spawn, target, and inventory schemas before allocating world state.
5. Fill the world with `default_palette`, then apply canonical runs in order.
6. Resolve area access and validate all physical anchors against the expanded
   map.
7. Sort stable instance IDs bytewise and allocate fixture entities in that
   order. Build generator/APC indexes in numeric tile order.
8. Seed inventory by sorted item `ContentId`, place crew from sorted spawn
   pools, rebuild power once, and emit the initial event.
9. Publish the simulation only if every step succeeded.

No authoritative step uses `pairs`, filesystem discovery order, localized
text, Goon dictionary keys, or JSON object member order. A failure reports
pack, source file, definition ID, JSON path, and coordinate where relevant,
and leaves no partially started campaign.

## Mods and replacements

A normal data mod can add a scenario through `scenario_maps` and uses the same
validator/registry path as the first-party pack. There is no core-only map
directory or loader branch.

A mod replaces a scenario only by replacing its exact `ContentId` under the
ordinary rules:

- directly require the current owner;
- list the ID in manifest `replaces`;
- set the replacement definition's `replaces` to that same ID; and
- provide the entire scenario definition.

Schema 1 has no palette, run, area, or fixture patch/merge behavior. Complete
replacement avoids load-order-dependent geometry. Two unrelated replacements
are a hard conflict. A new scenario uses the adding pack's namespace.

Nested stable IDs should be retained when an intended fixture/area/spawn is
still conceptually the same. Removing or changing one matters only to new
campaigns unless an explicit save migration refers to it.

## Validation limits

The implemented envelope and the playable-station budget are distinct:

| Resource | Schema-1 hard limit | Milestone authored target |
|---|---:|---:|
| width or height | 16–256 | 192×192 station |
| station cells | currently implied maximum 65,536 | at most 36,864 |
| palette entries | 1–2,048 | small enough for review |
| runs | 200,000 | canonical, normally far below cell count |
| areas | 1,024 | department/room-scale labels |
| fixtures | 8,192 | independently addressable anchors; source layers may share a tile |
| spawns | 1,024 | a small set of pools |
| meteor targets | 0–1,024 | exterior candidates only |
| ordinary string | 240 bytes | concise stable identifiers |
| `source_path` | 1,024 bytes | repository-relative DM path |
| `power_supply_w` | 0–1,000,000,000 | scenario-balanced |
| one inventory quantity | 0–1,000,000,000 | scenario-balanced |

All numbers are finite exact integers; JSON booleans are not integers. Arrays
must be dense. Object keys are closed. Namespaced references must parse and
resolve with the expected content kind after replacements. The mod package
limits still apply: at most 20,000 files, 512 MiB per entry, and 2 GiB expanded
total, but those archive ceilings are not suitable map-authoring targets.

## Save compatibility

The native scenario is a constructor, not a save-time dependency for expanded
geometry. At a completed tick boundary the save stores:

- exact mod ID/version/package hashes and the selected scenario ID;
- scenario schema and map format used at campaign creation;
- expanded authoritative world arrays, area records, map identity, and network
  state;
- fixture/machine entities and their stable scenario fixture IDs;
- inventory, crew, spawn results, incident targets/state, and scenario state;
- all counters, RNG streams, commands, events, and mod state required for
  deterministic continuation.

Loading validates the exact mod lock and migrations, then restores the saved
world. It does not re-expand current palette/runs or respawn fixtures. Editing
or replacing a scenario therefore affects new campaigns only. An update flow
may migrate a copy of a save, but never silently rebuilds its station from a
new definition.

The current `SSTN1` package lock prevents a different exact package set from
loading, and its header exposes scenario ID/schema/map format for diagnostics.
Any semantic change to map fields increments the map format; save-schema
migration is separate from scenario-definition migration.

## Implementation audit

The Atlas milestone now implements the save-safe vertical slice that was
missing from the first contract draft:

1. The normal application load seals the ordinary mod registry, builds
   `RuntimeContent`, selects the exact first-party Atlas `ContentId`, and passes
   that definition through `Scenario.instantiate`.
2. Scenario expansion creates the 192×192 world, area/access records, stable
   fixture entities, job-aware spawn pools, starting inventory, generator/APC
   indexes, and reviewed meteor targets. Area/fixture/spawn IDs must share the
   scenario's owning pack and `<scenario-name>/...` path prefix; fixtures and
   spawns are sorted before authoritative allocation.
3. Doors inherit area access unless a palette door overrides it. Powered crew
   with matching credentials may open them; open doors close on a deterministic
   timer. APCs and generators validate against areas/cables, atmosphere devices
   require gas cells, fixtures require non-boundary floor anchors, and spawns
   require actor-passable anchors. Dense feature occupancy participates in the
   latter without discarding source-layered machine fixtures. Lattice and
   catwalk features provide a walkable surface over legacy `tile=space`
   without becoming atmosphere cells; an intact colocated grille still blocks
   actors while remaining gas-permeable.
4. Atlas begins with 134 adapted machines: 81 APCs, six SMES units, one TEG
   generator, two TEG circulators, three passive vents, one vent pump, three
   portable scrubbers, 20 manufacturers, seven portable reclaimers, two
   nanofabs, five cargo pads, two supply consoles, and one barcode computer.
   Each fixture resolves a source-pinned schema-2 machine definition instead of
   receiving behavior from a core-only kind table.
5. Machines, inventory, scenario identity/provenance, authored incident
   targets, and expanded world/area/power state enter snapshots and state
   hashes. Save headers expose scenario ID/schema/map format. An integration
   test manufactures, saves, restores, compares state, and continues.
6. The Python package validator enforces a closed scenario/map/area/palette/
   fixture/spawn/target envelope, namespaced kinds, canonical run ordering,
   semantic palette uniqueness, owning-scenario nested identities, hard limits,
   department metadata, and core physical anchors. The Lua validator
   independently enforces the closed scenario/map/area/palette/fixture/spawn/
   target envelope, canonical runs, semantic palette uniqueness, exterior
   targets, nested identity, and the runtime safety boundary.
7. The compiler pins commit/blob/SHA-256, flips source Y explicitly, emits
   canonical palette runs and namespaced nested IDs, preserves safe literal
   overrides and reviewed source paths without executing DM, and records
   unsupported objects, placement omissions, fixture collisions, and duplicate
   spawns. It rejects output above 2,048 palette records; Atlas uses 1,596.
   Empty placement and collision lists prove that the selected Atlas machine
   set is no longer lossy. All 570 pinned maps parse; four source irregularities
   remain visible in the inventory report instead of being normalized silently.

The following remain release-contract work rather than hidden permissive
behavior:

1. Python and Lua validation are not yet field-for-field equivalent for the
   complete provenance tree, every string/array limit, and diagnostics.
   Cross-pack job/item references are syntax-checked during Python package
   validation and resolved only after the Lua registry is sealed. A shared
   negative-fixture matrix is still required to prove both phases reject the
   same malformed physical maps.
2. Production/cargo fixtures are not validated as reachable from a spawn.
   Runtime crew placement retains a nearest-passable recovery fallback even
   though the checked-in scenario's authored spawns already pass validation.
3. Physical fixture kinds remain a closed schema-1 adapter list. Machine
   behavior, source identity, cadence, power, state, wires, action requirements,
   and fidelity status are namespaced schema-2 definitions available to every
   pack. New physical footprints and utility connectors still require a
   versioned scenario extension.
4. `goon-type-path-adapter-v1` is deterministic and its omissions are explicit,
   but several mappings still derive department/access from reviewed path
   families. Every newly accepted path family or override interpretation needs
   a focused fixture and review.
5. The application defaults to Atlas and can launch any loaded definition with
   `python3 tools/dev.py run --scenario <ContentId>`, so data packs use the
   same start path as core. A title-screen scenario picker and richer
   start-options API do not yet exist.
6. Schema 1 still uses a raw `name`; a localized `name_key` decision remains a
   versioned compatibility change.
7. The current save test proves stateful continuation, but the full acceptance
   matrix still needs explicit instrumentation proving restore never reads or
   re-expands scenario geometry, third-party scenario/replacement starts,
   exact-limit fixtures, and malformed-field parity.

## Acceptance tests

The full schema-1 release gate is complete when all of the following are
automated. The Atlas vertical slice currently covers expansion, pinned
provenance/orientation fixtures, full-corpus parsing, core physical placement,
normal application startup, manufacturing state, and save continuation; the
implementation audit above identifies the remaining matrix.

1. **Envelope parity:** the example above passes folder and `.simmod`
   validation and both Python/Lua validators. For every field, unknown key,
   missing requirement, wrong type, boolean-as-integer, bad ID, and unresolved
   reference fixtures fail with equivalent paths.
2. **Expansion:** a golden test expands the example to the expected 16×16
   tile/structure/cable/area/gas arrays. Index/coordinate round-trips cover all
   four corners and every row boundary.
3. **Run safety:** reject zero/negative lengths, row crossing, overlap,
   out-of-order starts, out-of-range palettes, default-valued runs, adjacent
   mergeable runs, duplicate palette keys, and duplicate semantic palette
   records.
4. **Determinism:** shuffled JSON object keys, package discovery order, and
   fixture/spawn input order produce the same final stable order, initial state
   hash, and 600-tick continuation. Noncanonical generated input is rejected,
   not normalized differently at runtime.
5. **Physical placement:** retain two layered source fixtures on one tile in
   stable ID order; reject a fixture/spawn in space or a wall, an APC outside
   an area, an unconnected generator/APC, duplicate stable IDs, and duplicate
   or non-hull meteor targets. Diagnostics name ID and coordinate.
6. **Areas/access:** area IDs are contiguous, keys unique/namespaced, unknown
   departments fail, doors inherit area access, an explicit door override
   wins, and access on a non-door fails.
7. **Goon provenance:** the tool refuses an unpinned commit by default; Cogmap
   produces the recorded commit/blob/SHA-256; TGM fixture tests prove Y
   orientation; safe scalar overrides round-trip; expressions, unknown paths,
   and non-allowlisted overrides cannot become runtime behavior.
8. **Corpus robustness:** all 570 pinned maps parse or produce a stable,
   reviewed exception report. Analysis reruns are byte-identical.
9. **Mod behavior:** a third-party pack adds and starts a scenario without core
   changes. A valid complete replacement wins deterministically; undeclared,
   indirect, wrong-kind, and competing replacements fail.
10. **Save round-trip:** save a scenario after fixtures have state and inventory
    changes, load it, compare full state hashes, and continue 600 ticks
    identically. Assert the loader never reads or re-expands the scenario map
    during restore.
11. **Lock compatibility:** changing any scenario/package byte rejects the old
    save under its exact lock. A migration runs only on an explicit copied-save
    update and leaves the original untouched.
12. **Limits:** exact-boundary fixtures pass and one-over fixtures fail for
    dimensions, cell budget, palette, runs, areas, fixtures, spawns, targets,
    strings, power, and inventory quantities without unbounded allocation.
