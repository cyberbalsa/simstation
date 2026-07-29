# Public contracts and content data

## Version policy

Every serialized contract contains a positive integer `schema`. Schemas are
versioned independently by kind. Before 1.0, schemas and mod APIs may break, but
the change must increment the affected version, update fixtures/examples, and
publish a migration or an explicit incompatibility message. Silent reinterpretation
of an existing field is forbidden.

Unknown object keys are rejected unless the schema marks a specific
`parameters`/`extensions` object as open. Missing optional values receive only
the documented default. JSON numbers must be finite integers in Lua's exact
range; fixed-point values remain integers.

## Identifiers

`ContentId` has this exact form:

```text
<pack-id>:<kind>/<name>
org.simstation.core:item/steel-sheet
org.example.catering:recipe/food/pie-blueberry
```

- `pack-id` is lower-case reverse DNS, at least two labels; labels contain
  ASCII letters, digits, or `-`, and start with a letter or digit.
- `kind` begins with `a-z` and then contains `a-z`, digits, `_`, or `-`.
- `name` begins with lower-case ASCII or a digit and then contains lower-case
  ASCII, digits, `_`, `-`, or `/`; empty segments and `//` are invalid.
- IDs are case-sensitive by definition but uppercase is invalid.
- A public ID is never derived from file path, load order, array index, atlas
  location, localized name, or branding.

Registered core kinds include `item`, `material`, `machine`, `recipe`, `job`,
`department`, `task`, `policy`, `gas`, `reagent`, `reaction`, `disease`,
`plant`, `animal`, `room`, `zone`, `incident`, `scenario`, `research`,
`access`, `sprite`, `audio`, `sound-set`, `music`, `ui`, `command`, `event`,
`hook`, `light-profile`, `light-binding`, and `lighting-settings`. The
implemented lighting kinds are presentation-only closed schemas documented in
[rendering and graphics](04-rendering-and-graphics.md#dynamic-lighting). Mods
may register a new kind only through a future API revision; schema 1 rejects
unknown kinds.

Runtime domains use monotonic IDs serialized as decimal strings:

```text
ent:1042
task:91
room:17
net:power:8
txn:550
event:8821
```

Counters are never reused during a campaign. Deletion leaves a tombstone until
all references, migrations, and current-tick consumers are resolved.

## Definition envelope

Every JSON definition has this closed header:

```json
{
  "id": "org.example.catering:item/blueberry-pie",
  "schema": 1,
  "name_key": "org.example.catering.item.blueberry-pie.name",
  "description_key": "org.example.catering.item.blueberry-pie.description",
  "tags": ["food", "dessert"],
  "replaces": null,
  "data": {
    "mass_g": 650,
    "sprite": "org.example.catering:sprite/item/blueberry-pie"
  }
}
```

`replaces` is either `null` or the exact same ID. A definition may replace an
ID only when its pack directly depends on the current owner and its manifest
declares that ID under `replaces`. The replacing definition keeps the original
ID; introducing a new ID and redirecting references uses an explicit alias
migration instead.

Each kind owns a closed `data` schema and canonical units. References resolve
after all definitions load. Validation reports JSON Pointer, source pack/path,
expected type/range, and actual value.

## Content loading transaction

Content loading is all-or-nothing:

1. discover candidate folders and `.simmod` files without executing Lua;
2. read and validate manifests and archive safety limits;
3. solve required dependencies and conflicts;
4. compute deterministic pack order;
5. parse localization, definitions, atlas indexes, and audio manifests;
6. validate closed schemas and normalized IDs;
7. apply declared replacements;
8. resolve references and detect cycles forbidden by each schema;
9. compute the canonical registry hash;
10. register trusted code entry points and hooks;
11. publish one immutable registry.

Failure leaves the prior registry active. A campaign cannot swap its
authoritative registry while running. Data-only development reload is allowed
only from the title screen or paused editor: build a candidate registry,
validate it, and replace the old registry atomically. Existing campaigns then
require restart/reload so instances can be migrated coherently.

The base content pack passes through precisely these stages. Loader branches
for `org.simstation.core` are forbidden except that a fresh install enables it
by default.

## Canonical registry hash

For each enabled pack in resolved order, canonicalize:

- normalized manifest fields that affect runtime;
- every definition sorted by `ContentId`;
- localization fallback keys;
- atlas/audio index version and content hashes;
- trusted entry-point hashes; and
- declared aliases/replacements.

Canonical JSON uses UTF-8, sorted object keys by byte value, array order as
declared, no insignificant whitespace, decimal integers only, JSON escapes for
control characters, and one trailing newline. SHA-256 of the concatenated
length-prefixed records is `registry_sha256`. Source paths, timestamps, UI-only
description text, and author display order do not affect authoritative hashes
unless a schema explicitly says otherwise.

## GameCommand

The public schema is:

```json
{
  "schema": 1,
  "command_id": "cmd:player:0000000000000042",
  "issuer": {"class": "player", "id": "local"},
  "issued_at_tick": 1240,
  "apply_at_tick": 1241,
  "type": "org.simstation.core:command/place-blueprint",
  "payload": {
    "map_id": "map:station",
    "x": 92,
    "y": 74,
    "blueprint": "org.simstation.core:machine/interior-wall"
  }
}
```

- Issuer class is `scenario`, `player`, `trusted_mod`, or `debug`.
- `apply_at_tick` must be the next uncommitted tick or a documented future
  scheduling command. Backdating is rejected.
- Commands order by apply tick, issuer-class order above, bytewise issuer ID,
  then monotonic command ID.
- Validation and commit are one transaction. The response is either
  `accepted`, or a localized error key plus nonlocalized diagnostic fields.
- Payloads contain JSON primitives only. Table identity, functions, userdata,
  NaN/infinity, LÖVE objects, and path references are invalid.

The bootstrap queue's `sequence/kind/payload/issuer` shape is internal until it
is upgraded to this schema.

## SimEvent

The public schema is:

```json
{
  "schema": 1,
  "event_id": "event:8821",
  "tick": 1241,
  "type": "org.simstation.core:event/blueprint-placed",
  "source_id": "ent:1042",
  "target_ids": ["task:91"],
  "map_id": "map:station",
  "position": {"x": 92, "y": 74},
  "severity": 1,
  "visibility": "sensor",
  "payload": {"blueprint": "org.simstation.core:machine/interior-wall"}
}
```

Events order by tick, owning-stage order, bytewise source ID (empty first), and
owner-local sequence. They are immutable after finalization. `visibility` is
`public`, `sensor`, `camera`, `report`, `record`, or `secret`; it tells the
knowledge system how a fact may become visible, not whether the player knows it.

The event retention ring is a presentation cache only. Events required for an
active incident, report, evidence chain, ledger, save, or replay are stored by
their owning subsystem.

## RenderSnapshot

The core emits a read-only projection after each complete tick:

```lua
{
  schema = 1,
  tick = 1241,
  maps = {
    {
      id = "map:station",
      topology_revision = 52,
      chunk_revisions = { 1, 1, 7 },
      static_appearances = { ... },
      dynamic_appearances = { ... },
    },
  },
  visible_alerts = { ... },
  knowledge_revision = 19,
  dashboard_revision = 24,
}
```

An appearance contains a logical sprite ID (one sprite record represents one
animation state), direction, animation origin tick, offsets in 1/256 tile,
plane, layer, alpha, fixed-point tint/color matrix, blend mode, and ordered
underlay/base/overlay entries. It never contains an atlas page, Quad, Image, or
other backend object.

The presentation may interpolate positions between the last two snapshots.
Picking and UI inspection use the latest complete snapshot; interpolation never
feeds back into commands as an authoritative coordinate without snapping to a
valid map tile.

## AudioCue

Audio is projected from visible events:

```json
{
  "schema": 1,
  "cue_id": "org.simstation.core:sound-set/alarm/fire",
  "event_id": "event:8821",
  "tick": 1241,
  "bus": "alarms",
  "map_id": "map:station",
  "position": {"x": 92, "y": 74},
  "priority": 90,
  "gain_mdb": 0,
  "pitch_ppm": 1000000,
  "caption_key": "audio.alarm.fire"
}
```

The audio adapter deterministically chooses variants from `event_id` and the
sound-set definition. Playback, stealing, culling, listener state, and device
loss do not create core events or alter the simulation.

## Compatibility acceptance

- Every example above is a fixture that parses and round-trips canonically.
- A definition with an unknown key, bad unit, unresolved reference, illegal
  replacement, duplicate ID, or inexact integer fails with its source pointer.
- Base content and a byte-identical third-party copy produce identical loader
  behavior except for manifest identity constraints.
- Commands serialized before enqueue and after dequeue are bytewise canonical
  equivalents.
- Presentation tests prove snapshots contain no mutable core table and no
  `love.*` object.

JSON is handled by the strict pure-Lua
[lunajson](https://github.com/grafi-tt/lunajson); TOML is reserved for
human-authored manifests and asset metadata and parsed with
[tinytoml](https://github.com/FourierTransformer/tinytoml).
