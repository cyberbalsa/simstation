# Mod authoring, testing, and compatibility

## Authoring layout

Use folder mods while developing:

```text
org.example.catering/
  mod.toml
  content/
    items.json
    recipes.json
  locales/
    en.json
  graphics/
    pie.png
    pie.toml
  audio/
    kitchen-timer.ogg
    audio.toml
  generated/
    graphics/
    audio/
  tests/
    registry.json
```

Do not commit generated pages without their editable source, manifest, and
provenance. Validate and package only through:

```text
python3 tools/dev.py mod validate <folder>
python3 tools/dev.py mod test <folder>
python3 tools/dev.py mod package <folder>
```

The current commands validate the folder, compare folder/archive registry
results, and write a reproducible `.simmod`; the package has no network or
post-install scripts. Automatic loose-media compilation and canonical
per-package credits remain later authoring-tool work, so media packs must
already contain their validated runtime artifacts and provenance.

## Four canonical examples

The repository must maintain these executable examples as compatibility tests:

### `org.simstation.example.catering`

Data-only definitions for one cook job, pie item, two-stage recipe, ingredients,
salary/access references, localization, sprite, and sound set. It proves a pack
can add a complete production chain without Lua.

### `org.simstation.example.av-swap`

Data-only explicit replacements for one sprite and sound set using compiled
atlas/Ogg artifacts. It proves logical replacement never depends on path or
atlas coordinates.

### `org.simstation.example.salvage-scenario`

Data-only schema-1 starting map with two areas, eight powered/utility/production
fixtures, four job spawns, starting inventory, and two breach targets. It proves
a normal pack can add a strict native scenario through `scenario_maps`.

The package separately registers a future-facing recovery profile and export
objective, preserving the intended seed, budget, crew mix, incident pool, and
control-assembly goal without putting unsupported fields on the physical map.
Those two definitions are registry data only; the current vertical slice does
not execute profile/objective behavior.

### `org.simstation.example.smart-grid`

Trusted Lua pack registering a command validator, task-score transform, event
observer, and versioned private state. It proves warning, hook ordering,
commands, save/reload, migration, errors, and replay.

Every public release runs these examples from folder and `.simmod` forms.

After installing/enabling the salvage pack, launch its physical start directly
during development:

```text
python3 tools/dev.py run --scenario \
  org.simstation.example.salvage-scenario:scenario/last-chance
```

## Data workflow

1. Choose an ID in the pack namespace and copy the latest kind schema/example.
2. Use canonical integer units; never encode outcomes in display strings.
3. Refer to other packs only through declared dependencies and public IDs.
4. Add localization for at least `en`; missing keys show the key visibly in
   developer mode and fail packaging for the pack's default locale.
5. Add fixture expectations for registry records and relevant gameplay.
6. Validate and package.

Tags are discoverability hints, not behavior unless a system schema names the
tag. A mod may not assume all definitions with an arbitrary tag are compatible.

## Graphics workflow

- Author lossless RGBA8 PNG plus TOML; never atlas-edit.
- Use explicit cell size, pivot, state, direction, frame, timing, loop, and
  hotspot metadata.
- Run the same deterministic atlas compiler as core.
- Inspect generated contact sheets/animations.
- Reference logical `SpriteId` and state from content.
- Package the generated page/index and source-derived attribution.

DMI is accepted only by the external upstream-import command for provenance or
developer conversion. Packaged/runtime DMI is rejected.

## Audio workflow

- Prefer a lossless project master for new work and emit reviewed Vorbis.
- Existing licensed Vorbis may remain the master to avoid re-encoding.
- Declare bus, static/stream, mono/stereo spatial rule, loop samples, gain,
  priority, instance/cooldown, caption, license, and attribution.
- Test through the voice/cache/acoustic runtime.
- Package only validated Ogg; tracker modules are authoring inputs, not runtime.

## Trusted-code workflow

- Depend only on the documented `api`/`HookContext`.
- Keep all authoritative values primitive and integer.
- Register handlers deterministically at entry-point load; never register in
  response to iteration or wall time.
- Store campaign state through `ctx:set_state`, with a manifest schema and
  migration fixture.
- Enqueue commands for future ticks instead of mutating queried state.
- Treat IO, network, wall clocks, threads, and renderer/audio calls as
  presentation-only and keep them outside authoritative hooks.

## Compatibility report

The title-screen mod inspector exports JSON containing:

- game build and API version;
- enabled ID/version/package hash/load order;
- dependency and hint graph;
- definitions added/replaced and final owner;
- atlas/audio bundles and decoded budgets;
- trusted entry points and exact handler order;
- state schemas/migrations;
- warnings, errors, and timing summaries.

Mod bug reports attach this file and, when relevant, a replay.

## Update compatibility

A mod update changes its SemVer and package hash. Existing campaigns remain
locked until the player explicitly chooses “test update on copy.” That flow:

1. clones the latest validated save;
2. resolves the proposed exact lock;
3. shows definitions removed/replaced/changed, aliases, state migrations, and
   estimated media budgets;
4. migrates/loads the copy;
5. runs invariant validation and optionally a 600-tick smoke simulation;
6. leaves the original lock/save untouched;
7. offers to continue only if successful.

Removing a definition referenced by a save requires an alias or documented
removal migration. Changing an ID's kind is forbidden. Removing a trusted
pack with private save state is permitted only if it declares a pure removal
migration or the user accepts abandoning a copied campaign with an explicit
list of lost state.

## Publishing checklist

- Package ID is owned/stable and not misleading.
- Version/API/dependency constraints are exact.
- Folder and `.simmod` validation/tests pass.
- All definitions/localization/references/hooks have fixtures.
- Media is compiled, bounded, credited, and licensed.
- Code class and trust needs are accurate.
- No secrets, personal paths, symlinks, native binaries, or unexpected files.
- README explains gameplay, conflicts, content settings, save impact, and
  source/license.
- SHA-256 and source repository revision are published.

There is no built-in network workshop in API 0.1. Installation is a deliberate
local file/folder action, keeping packages inspectable and campaigns pinned.
