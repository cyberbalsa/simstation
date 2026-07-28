# Persistence, migrations, and replay

## Bootstrap transition

The current foundation writes an internal `SSTN1\n` envelope with a decimal
newline-terminated header length, JSON header, and zlib JSON payload. That
format is schema-0 bootstrap data, not the public save contract below. M1 must
retain a read-only importer for it, back up the source, and write `SSSAVE01`
only after a successful load/validation. New public releases must not emit
`SSTN1`.

## Save envelope

A campaign save is one `.sssave` binary envelope:

| Offset | Size | Value |
|---:|---:|---|
| 0 | 8 | ASCII `SSSAVE01` |
| 8 | 4 | little-endian unsigned header-byte count |
| 12 | header count | UTF-8 canonical JSON header |
| remaining | variable | zlib-compressed UTF-8 canonical JSON payload |

The header is deliberately uncompressed so the title screen can diagnose a
save without loading mods:

```json
{
  "format": "simstation-save",
  "schema": 1,
  "game_build": "0.1.0+g0123456",
  "created_utc": "2026-07-28T20:15:00Z",
  "saved_tick": 28800,
  "station_id": "station:1",
  "station_name": "NSS Bootstrap",
  "root_seed": "1337",
  "registry_sha256": "0123456789abcdef...",
  "mods": [
    {
      "id": "org.simstation.core",
      "version": "0.1.0",
      "package_sha256": "abcdef..."
    }
  ],
  "asset_index_versions": {"graphics": 1, "audio": 1},
  "payload_encoding": "canonical-json+zlib",
  "payload_compressed_bytes": 1234567,
  "payload_uncompressed_bytes": 7654321,
  "payload_sha256": "fedcba..."
}
```

`created_utc` is informational and excluded from simulation state hashes.
`payload_sha256` hashes the compressed bytes actually stored. The loader checks
magic, bounded header length, valid UTF-8/JSON, supported schema, compressed
size, decompressed size, and hash before parsing payload state.

The initial limits are 4 MiB header, 512 MiB compressed payload, and 2 GiB
decompressed payload. Limits are checked before allocation and decompression.

## Save payload

The payload is a closed object:

```json
{
  "schema": 1,
  "campaign": {
    "tick": 28800,
    "shift_index": 2,
    "seconds_in_shift": 0,
    "next_ids": {"entity": "1043", "task": "92", "event": "8822"}
  },
  "rng": {
    "crew_generation": {"schema": 1, "state": 1934421},
    "incident": {"schema": 1, "state": 775511}
  },
  "systems": {
    "world": {"schema": 1, "state": {}},
    "crew": {"schema": 1, "state": {}},
    "work": {"schema": 1, "state": {}},
    "economy": {"schema": 1, "state": {}}
  },
  "scheduled_commands": [],
  "active_mod_state": {}
}
```

Each owner saves only authoritative state that cannot be derived from loaded
definitions or another owner. It saves absolute future ticks, reservations,
monotonic counters, tombstones still referenced, and named RNG state.

Never save:

- Lua functions, metatables, userdata, or table identity;
- `Image`, `Quad`, `Canvas`, `Source`, SpriteBatch, shader, or UI objects;
- cached routes, room graphs, spatial indexes, render batches, audio pools, or
  profiling measurements;
- localized strings that can be recovered from keys; or
- wall-clock timestamps as an outcome input.

Dense integer arrays use JSON arrays in schema 1. A later binary field encoding
requires a new save schema and a canonical reference decoder.

## Canonical encoding

The encoder:

- emits UTF-8 JSON with object keys sorted by raw UTF-8 byte order;
- preserves schema-defined array order;
- emits decimal integers only, with no exponent or leading plus/zeros;
- escapes control characters and quotes, but otherwise preserves normalized
  UTF-8;
- rejects NaN, infinity, sparse arrays, mixed array/object tables, cycles,
  functions, and userdata;
- represents IDs as strings and absent optionals by omission, not ambiguous
  Lua `nil` array holes; and
- emits one trailing newline.

Compression uses `love.data.compress("string", "zlib", payload, 6)` in the
filesystem adapter. Pure-Lua tests use a fixture compressor/decompressor; the
core itself neither compresses nor calls LÖVE.

## Write and recovery protocol

For slot `campaign-01`:

1. serialize and hash a complete snapshot after the current tick commits;
2. write `campaign-01.tmp` in the same save directory;
3. reopen, validate the entire envelope, and compare hashes;
4. rotate `campaign-01.bak2` out, rename `.bak1` to `.bak2`, and current save
   to `.bak1`;
5. rename the verified temporary file to `.sssave`;
6. update slot metadata only after the final rename succeeds.

If the platform adapter cannot guarantee atomic replacement, it must use a
small two-generation journal and select the newest fully validated generation
at startup. An interrupted write never deletes the last validated generation.
Autosave occurs at each shift boundary and every 3,000 ticks, with at least ten
in-world minutes between successful autosaves. Manual saves do not reset the
autosave schedule.

## Load sequence

1. Read and validate the header without enabling code mods.
2. Resolve the exact mod IDs, versions, hashes, and content registry hash.
3. Refuse normal load if a required mod is missing/different; present exact
   differences and links to the configured local package path.
4. Allow a copy-only “recovery attempt” only when every missing pack declares
   complete aliases/removal migrations and no unknown state owner remains.
5. Back up the original before migration.
6. Decompress and strictly parse the payload.
7. Apply engine-envelope migrations, then system migrations in stable system
   ID order, then declared mod-state migrations in resolved mod order.
8. Validate every reference, counter, unit, reservation, RNG stream, and
   invariant.
9. Rebuild derived indexes/caches and publish the first snapshot.
10. Advance only after the player confirms a migrated-save summary.

Loading never mutates the original file. A migrated campaign writes a new
generation on the next save.

## Migration contract

A migration is a pure function:

```text
migrate(owner_id, from_schema, primitive_state, registry_view)
  -> next_schema, primitive_state, report[]
```

- Migrations advance exactly one version; the loader chains them.
- They receive immutable definition/alias queries, no simulation, RNG, IO,
  clocks, UI, or LÖVE objects.
- Core migrations are registered in fixed owner-ID order.
- Data-only mods may provide declarative field operations and ID aliases.
- Lua migrations are trusted code and execute with the same warning status as
  a trusted code mod.
- A migration must be deterministic, idempotent when guarded by its input
  version, and preserve unknown state only where its schema explicitly permits
  extension data.
- Failure reports owner, version edge, JSON Pointer, and original error, then
  leaves the source untouched.

An ID alias has `old`, `new`, `introduced_in`, and optional `remove_after_api`.
Aliases are acyclic, one-to-one at resolution, and cannot change content kind.

## Replay format

A `.ssreplay` uses the same envelope with magic `SSREPL01`. Its payload contains:

```json
{
  "schema": 1,
  "initial": {
    "mode": "embedded-save",
    "save_envelope_base64": "..."
  },
  "commands": [
    {"tick": 1241, "command": {}}
  ],
  "checkpoints": [
    {"tick": 1800, "state_sha256": "..."}
  ],
  "observed_events": []
}
```

Release bug replays embed a save so they are self-contained. Benchmark replays
may reference a repository fixture by SHA-256. Commands are canonical public
`GameCommand`s ordered exactly as committed. Checkpoints occur every 600 ticks
and at save/shift boundaries. `observed_events` is optional diagnostic data and
is never replay input.

Replay requires the exact game build and mod lock by default. A developer may
run a mismatched replay in comparison mode, but the output is labeled
noncanonical and the first divergent checkpoint is reported.

## State hash

The deterministic hash includes:

- campaign tick/shift and all monotonic counters;
- named RNG states;
- normalized enabled authoritative definitions;
- every system's canonical saved state;
- pending future commands and reservations.

It excludes presentation, localization text, logs, event-ring eviction,
wall-clock metadata, filesystem paths, audio/graphics availability, and
profiling. SHA-256 is the interchange hash. A faster internal rolling hash may
be used per tick only if the 600-tick checkpoint recomputes canonical SHA-256.

## Acceptance

- Golden save fixtures load for every supported schema.
- A save at tick `N`, reload, and continuation matches an uninterrupted run.
- Byte-identical state produces byte-identical payload and state hash on all
  desktop targets.
- Truncation at every envelope byte either selects a prior generation or
  returns a bounded diagnostic; it never crashes or overwrites a backup.
- Zip/decompression bombs, invalid UTF-8, duplicate JSON keys, inexact numbers,
  bad hashes, unknown state owners, and dangling IDs are rejected.
- Every migration edge has before/after golden fixtures and a second-run
  idempotence test.
- Replay reports the exact first divergent tick/checkpoint and owning state
  path where available.
