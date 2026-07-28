# Runtime media agent — compact catalog and presentation integration

## Record

- Canonical task: `/root/runtime_media`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: implementation and validation completed
- Report availability: `normalized visible report`
- Assignment availability: `verbatim`

### Assignment

> Implement compact runtime media selection/catalog integration. You own
> tools/assets.py only for adding a postprocess command (coordinate carefully;
> do not alter existing compiler behavior), new src/assets/**, and
> src/presentation/renderer.lua + audio.lua. Goal: generate small foundation
> graphics/audio catalog(s) from the existing huge generated catalogs;
> lazy-load only relevant atlas pages/audio; render imported Goon
> floor/wall/doors/crew with shape fallback and consume key simulation events
> using imported sound with safe voice caps. Preserve deterministic sim
> boundary and LÖVE 11.5/LuaJIT compatibility. Run the postprocess and
> tests/LÖVE smoke. Report exact files/decisions. Do not edit docs. Save an
> honest agent record at docs/agents/runtime-media.md summarizing work, tools,
> validation, and no hidden reasoning.

### Observable chronology

1. Inspected the exhaustive graphics/audio catalog schemas, current
   SpriteBatch renderer, simulation event records, and placeholder audio
   consumer.
2. Added a postprocess that selects six pinned sprite IDs and eleven pinned
   audio IDs without changing atlas pixels, audio bytes, IDs, or packing.
3. Generated `graphics/foundation.json` (8,017 bytes) and
   `audio/foundation.json` (11,862 bytes). The graphics selection references
   four of the 134 compiled atlas pages.
4. Added catalog readers that parse only the small selections, cache Quads,
   lazily open atlas pages, and lazily create audio Source prototypes.
5. Replaced the foundation's primitive station rendering with imported Goon
   floor, riveted-wall, classic-door, and human sprites. The renderer retains
   a whole-chunk primitive fallback if selection metadata or a page cannot be
   loaded.
6. Mapped simulation events to imported sounds with global/per-alias voice
   caps, cooldowns, bus gain, and priority-based voice eviction. Audio remains
   presentation-only.
7. Validated the postprocess, catalogs, Lua syntax, mocked catalog contracts,
   full asset hashes, live LÖVE startup, actual lazy file opens, and a captured
   live frame.
8. Reported two out-of-scope observations to the lead agent: a concurrently
   changed hook-order test now fails independently of media, and help text
   still describes the old placeholder-art state.

## Visible report

### Files changed

- `tools/assets.py`
  - Added the `build-foundation-media` postprocess command.
  - Added that postprocess to the existing `all` orchestration after the
    exhaustive graphics and audio builds.
- `assets/runtime/goon/graphics/foundation.json`
  - Generated selection for floor, wall, closed/open door, and two crew body
    sprites, including only the page records those sprites use.
- `assets/runtime/goon/audio/foundation.json`
  - Generated selection for station, UI, construction, door, incident,
    medical, economy, and shift feedback.
- `src/assets/atlas_catalog.lua`
  - Version-checks the small catalog, lazy-loads pages, and caches Quads.
- `src/assets/audio_catalog.lua`
  - Version-checks the small catalog and lazy-creates clonable Sources.
- `src/presentation/renderer.lua`
  - Uses per-chunk static SpriteBatches for imported tiles and doors; draws
    imported crew sprites; keeps primitive fallback rendering.
- `src/presentation/audio.lua`
  - Consumes new event IDs, handles save-time cursor regression, and enforces a
    32-voice global cap plus per-sound caps/cooldowns/priorities.

### Runtime decisions

- The exhaustive 71 MB graphics and 4.9 MB audio catalogs remain canonical
  provenance/search indexes and are never parsed during normal startup.
- The four selected pages are loaded only when the renderer first needs their
  sprites. Audio files are opened only on the first matching event.
- Static world art stays chunk-cached and revision-driven. No LÖVE object or
  presentation state enters `src/core/`.
- A media failure disables imported static art and falls back to the existing
  readable primitive renderer instead of stopping the game.
- Sounds are listener-relative for this management view. Positional playback
  can be added when the camera/listener contract exists.

### Validation evidence

- `python3 tools/assets.py build-foundation-media`
  - 6 sprites, 4 atlas pages, 11 audio entries.
- `python3 -m py_compile tools/assets.py`
  - Passed.
- `luac -p` and `luajit -bl` over all four changed Lua modules
  - Passed.
- Mocked LuaJIT catalog/event contract
  - Passed; five resources opened lazily and four expected test voices played.
- `python3 tools/assets.py audit`
  - 5,868 upstream files, 46,160 sprites, and 4,699 audio files passed hash and
    existence checks.
- Live LÖVE smoke
  - Eight-second run produced no stderr.
  - `strace` confirmed startup opened only both foundation catalogs, the four
    referenced pages, and the station chime rather than either exhaustive
    catalog.
  - A live window capture visually confirmed imported floors, walls, doors,
    and crew.
- Core test run
  - Seven tests passed. The hook transform test expected 32 but received 36
    after `src/mods/hooks.lua` changed concurrently; none of the media-owned
    files is imported by that test.

This record contains externally observable assignment, actions, decisions,
outputs, and validation only. It does not reproduce hidden reasoning, private
model state, or unavailable dialogue.

## Decision disposition

### Accepted

- Small generated runtime selections over exhaustive immutable catalogs.
- Lazy image/audio loading and cached Quads/SpriteBatches.
- Presentation-only audio event consumption with bounded voices.
- Readable primitive fallback when imported media is unavailable.

### Adapted

- Closed and open doors share one SpriteBatch because both selected frames are
  on the same atlas page.
- Crew job identity is shown with a small color badge while preserving the
  source body pixels instead of tinting the entire sprite.

### Rejected

- Parsing the 71 MB exhaustive atlas catalog at game startup.
- Preloading all Goon audio or all 134 atlas pages.
- Allowing audio or rendering state to affect authoritative simulation.

### Unresolved

- Camera-relative positional sound awaits a public camera/listener contract.
- The stale help text and concurrent hook-order test were handed to the lead
  because they are outside this task's file ownership.

## Sources

- Pinned graphics catalog:
  `assets/runtime/goon/graphics/atlas.json`
- Pinned audio catalog:
  `assets/runtime/goon/audio/audio.json`
- Pinned source commit:
  `1b2b250abb5be747d55e274de0203a59cfc8da78`
