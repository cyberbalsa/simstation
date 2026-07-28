# Technical documentation agent

## Record

- Canonical task: `/root/technical_docs`
- Display name: unavailable
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: documentation implementation completed; final audit
  rerun exposed a concurrent hook-order fixture mismatch
- Report availability: normalized visible report
- Assignment availability: verbatim

### Assignment

> Implement technical/production docs from approved plan. You own
> docs/technical/**, docs/modding/**, docs/production/** only. Cover LÖVE
> architecture, deterministic 10Hz scheduler, data/content IDs/contracts, mod
> manifests/hooks/loading/security, saves/replays/migrations, rendering and full
> Goon graphics fork, audio full import/runtime policy, library/toolchain
> evaluation, performance/testing/platform packaging, vertical slice and
> roadmap. Make specs decision-complete, include schemas/examples in Markdown
> and citations. Match implemented foundations where visible but do not edit
> code. Use apply_patch. Report files/checks.

The parent later requested:

> Good reconciliation—keep those gaps explicit and finalize. Please ensure docs
> link to the actual current commands/paths and add/update your
> docs/agents/technical-docs.md record with observable work, validation, and
> decisions before completing.

### Observable chronology

1. Inspected the repository agreement, existing design/legal/agent records,
   pure-Lua core, content ID parser, and LÖVE entry points.
2. Confirmed concurrent implementation of the full pinned media import,
   deterministic core tests, resolver/hooks, save foundation, renderer, audio
   adapter, and developer tools.
3. Wrote the technical specification covering runtime, public/data contracts,
   persistence/replay, graphics, audio, libraries/tooling, performance, tests,
   and packaging.
4. Wrote the modding specification covering package/archive format,
   dependency resolution, replacements, trust, typed hooks, authoring, example
   mods, save locks, and compatibility.
5. Wrote the production specification covering the 24-crew vertical slice,
   milestone gates, explicit exclusions, release, source updates, maintenance,
   and recovery.
6. Reconciled documentation with actual `assets/`, `tools/assets.py`,
   `tools/dev.py`, catalogs, and bootstrap code. Gaps were labeled as M1/M2
   work rather than represented as complete.
7. Ran `python3 tools/dev.py audit`; all eight Lua tests passed, Python tools
   compiled, JSON catalogs parsed, `git diff --check` passed, and the audit
   exited successfully.
8. After `src/mods/hooks.lua` changed concurrently to the documented
   dependency-phase ordering, reran audit. The unchanged hook fixture expected
   the prior order (`32`) and received the new order (`36`); this integration
   mismatch was reported to the parent without editing code/tests outside the
   assigned scope.

## Visible report

The implementation produced:

- eight files under `docs/technical/`;
- four files under `docs/modding/`;
- four files under `docs/production/`; and
- this agent record plus archive index updates.

The documents contain closed schemas and examples for commands, events,
content, saves/replays, atlas/audio catalogs, mod manifests, dependency
constraints, hook returns, and package/release artifacts.

The reconciliation recorded these observable foundation facts:

- LÖVE 11.5, 10 Hz scheduling constants, pure core, stable RNG/pathfinding,
  192×192 default world, and 16×16 chunks exist.
- The asset importer compiled 1,139 DMI plus 17 ordinary PNG files into 46,160
  sprite records and 134 pages across eight bundles.
- The audio importer produced 4,699 runtime entries, including 16 tracker
  conversions and 29 duplicate aliases.
- The bootstrap scheduler, save envelope, mod API, media mounting, audio
  runtime, and richer public command/event contracts remain staged work and are
  called out explicitly.

## Decision disposition

### Accepted

- Pure-Lua deterministic core separated from LÖVE presentation.
- One-second authoritative ticks processed at 10/20/40 Hz for 1×/2×/4×.
- Versioned closed content, command, event, snapshot, save, replay, atlas,
  audio, and mod contracts.
- Data-only packages plus explicitly trusted arbitrary Lua code mods.
- Portable PNG/Quad/SpriteBatch and Ogg static/stream baselines.
- Full pinned graphics/audio fork with immutable source, editable source,
  generated runtime, and provenance in one repository.
- A 24-crew cross-system vertical slice followed by 100-crew performance gates.

### Adapted

- Graphics and audio path examples were changed from planned `assets-src` and
  `tools/dev.py assets ...` forms to implemented `assets/...` paths and
  `tools/assets.py` commands.
- The sprite contract was adapted to the implemented one-DMI-state-per-
  `SpriteId` catalog while preserving stable IDs, source state, occurrence,
  direction, frame, and timing data.
- Current catalogs are documented as review artifacts; bundle-sharded compact
  indexes and runtime mounting remain M2 requirements.
- The current `SSTN1` save, simple resolver/hooks, generated-shape renderer, and
  event-consuming silent audio adapter are labeled bootstrap internals.

### Rejected

- Claiming unimplemented CLI commands or media runtime behavior already exists.
- Runtime DMI/tracker parsing, whole-map textures, mandatory FFI/native
  dependencies, last-wins mod overrides, and a security claim for Lua code
  mods.
- Treating current accumulator dropping, out-of-step paused command flushing,
  or schema-0 save/mod shapes as final contracts.

### Unresolved implementation work

- M1 must implement the final scheduler/command boundary, public
  command/event/content loader, mod package/API, and `SSSAVE01` migrations.
- M2 must mount/shard the atlas catalog, implement page residency/appearance
  composition, finish parity/contact-sheet verification, curate audio metadata,
  and implement voice/cache/acoustic/caption behavior.
- Tool/dependency locks, notices/SBOM generation, benchmark harness, mod CLI,
  and platform packages land at their roadmap gates.

## Sources

- [LÖVE 11.5 release](https://github.com/love2d/love/releases/tag/11.5)
- [LÖVE SpriteBatch](https://love2d.org/wiki/SpriteBatch)
- [LÖVE graphics limits](https://love2d.org/wiki/GraphicsLimit)
- [LÖVE audio formats](https://love2d.org/wiki/Audio_Formats)
- [Concord](https://github.com/Keyslam-Group/Concord)
- [Slab](https://github.com/flamendless/Slab)
- [lunajson](https://github.com/grafi-tt/lunajson)
- [tinytoml](https://github.com/FourierTransformer/tinytoml)
- [semver.lua](https://github.com/kikito/semver.lua)
- [Pinned Goonstation DMI parser](https://raw.githubusercontent.com/goonstation/goonstation/1b2b250abb5be747d55e274de0203a59cfc8da78/tools/dmi/__init__.py)
- [Pinned Goonstation license](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE)
- [Pinned Goonstation audio guidelines](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/.github/AUDIO_GUIDELINES.md)
- [FFmpeg libopenmpt documentation](https://ffmpeg.org/ffmpeg-formats.html#libopenmpt)
