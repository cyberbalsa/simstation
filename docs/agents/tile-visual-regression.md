# Tile visual regression agent

## Record

- Canonical task: `/root/machine_docs_renderer`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: implementation and full repository audit completed
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> New task: build a bounded visual regression/coverage slice for Goon tile
> fidelity. Inspect current tests and local upstream assets/maps; add tests
> that catch fallback/placeholder tile misuse, missing DMI state/direction
> resolution, and layer ordering for a representative station room. You may
> edit tests and docs/agents only (plus tiny fixtures under tests/fixtures if
> needed), not production renderer/importer files. Archive your work/state in
> docs/agents and report failures that reveal root causes.

### Observable chronology

1. The agent inspected the existing Lua and Python test runners, renderer
   painter groups, atlas resolver, native world feature model, generated
   foundation catalog, and DMI compiler helpers.
2. It confirmed that `tools/dev.py test` runs `tests/run.lua` and the existing
   `tests.test_map_import` module, so it extended those suites instead of
   adding an undiscovered test module.
3. It confirmed that CI may retain media as Git LFS pointer files. The metadata
   and renderer-order contract therefore remains runnable without LÖVE,
   Pillow, or hydrated PNG data; only the byte-level DMI comparison skips when
   its payloads are pointers.
4. It announced that the test would verify semantic source-derived aliases and
   painter groups rather than relying on a screenshot that merely changed.
5. It created a seven-cell, 16×16 representative room fixture covering all 20
   static renderer aliases plus the procedural cable layer.
6. It added suppression/overlap cases for sign versus decal, crate versus
   storage, and window plus grille versus the underlying wall.
7. It added a display-independent LÖVE graphics mock and exercised the real
   `Renderer` and `AtlasCatalog` modules. The test validates exact alias
   identity, source metadata, every declared direction, one-direction fallback
   semantics, unique atlas cells, native-media activation, and per-cell draw
   order.
8. It added Python provenance checks for the pinned source commit, source DMI
   path/state/occurrence, direction set, cell size, frame size, unique sprite
   IDs, and representative-room coverage.
9. It added an optional hydrated-media check that compares every represented
   direction byte-for-byte between its pinned upstream DMI cell and compiled
   atlas cell. It also pins a SHA-256 digest for each south-facing room sprite.
10. The initial Lua suite passed 26 tests with zero failures. The initial
    Python suite passed 19 tests, including all hydrated source-pixel
    comparisons. No production root-cause failure was exposed by this slice.
11. The agent changed no production renderer, importer, asset compiler, core,
    or generated asset file.
12. `python3 tools/dev.py audit` passed after the archive and indexes were
    added. It reran both suites, validated all five mod packs, checked 72
    Markdown documents, audited the hydrated 46,160-sprite catalog and
    foundation media, and reported no diff-format violations.
13. After a concurrent renderer edit appeared in the shared worktree, the
    agent reran all 26 Lua tests and both visual-fidelity Python tests against
    that latest state; all passed.

## Visible conversation summary

This section includes only messages externally visible to the parent/user. It
does not reconstruct hidden reasoning or private model state.

- Initial progress update:

  > I’m scoping this as a deterministic contract test, not a screenshot that
  > only says “pixels changed.” I’ll verify real source-derived aliases and
  > DMI directions, then exercise a representative layered room against the
  > renderer’s declared painter groups so placeholder substitution and
  > ordering regressions fail with specific causes.

- Fixture/test update:

  > The fixture now covers every static room alias once, including deliberate
  > overlaps: cable under decals, grille under window, and suppression cases
  > for crate/storage, sign/decal, and window/wall. I’m wiring it through the
  > real atlas resolver with a lightweight graphics mock so the normal CLI
  > suite can catch ordering errors without requiring a display or hydrated
  > PNGs.

- Targeted validation update:

  > Both layers pass on the hydrated checkout. The stronger pixel test
  > compared every represented direction—not just the south-facing
  > thumbnail—against the pinned upstream DMI cell, so no source-state,
  > direction-slot, or atlas-copy mismatch surfaced. Next I’m checking the
  > LFS-only behavior and repository audit, then I’ll archive the exact
  > contract and results for later agents.

## Normalized visible work report

### Coverage contract

The fixture at `tests/fixtures/visual-room.json` pins:

- Goonstation commit `1b2b250abb5be747d55e274de0203a59cfc8da78`;
- the complete current static-room alias set;
- source DMI path, state, duplicate-state occurrence, and direction set for
  each alias;
- a raw-RGBA SHA-256 digest of each south-facing compiled cell;
- a seven-cell room arrangement and exact expected painter order; and
- the complete set of aliases that arrangement must draw.

The fixture deliberately uses densely layered cells. A renderer that silently
uses primitive fallback, remaps a known tile to another atlas alias, reuses a
placeholder cell, drops a component, changes suppression rules, or moves a
component across painter groups now fails with an alias- or cell-specific
message.

### Runtime-facing test

The Lua test loads the real presentation modules under a minimal in-memory
graphics API. It therefore exercises production catalog parsing, page
resolution, quad lookup, direction fallback, group creation, static chunk
building, feature suppression, and final `media_batches` ordering without
opening a window.

This is intentionally a semantic draw-list test rather than a screenshot
hash. It reports the exact alias, direction, or room cell that drifted and
continues to run on minimal CI hosts.

### Source-pixel test

The hydrated Python test reads the immutable upstream DMIs through the asset
compiler's parser. For each selected state it resolves the recorded duplicate
occurrence and one-based source-state index, then compares all represented
direction cells with the packed runtime atlas bytes.

When Pillow is absent or required payloads are Git LFS pointers, only this
pixel-level test skips. The metadata, alias-coverage, resolver, suppression,
and painter-order tests remain active.

### Files owned by this task

- `tests/fixtures/visual-room.json`
- `tests/run.lua` (one added visual-room test)
- `tests/test_map_import.py` (two added visual provenance tests)
- `docs/agents/tile-visual-regression.md`
- `docs/agents/README.md` (archive index entry)
- `docs/agents/manifest.json` (machine-readable archive entry)

### Validation observed before archive finalization

- `luajit tests/run.lua` — 26 tests, 0 failures.
- `python3 -m unittest -v tests.test_map_import` — 19 tests, all passed.
- Hydrated DMI-to-atlas comparison — all selected directions passed.
- `python3 -m json.tool tests/fixtures/visual-room.json` — passed.
- `git diff --check -- tests/run.lua tests/test_map_import.py
  tests/fixtures/visual-room.json` — passed.
- `python3 tools/dev.py audit` — passed, including 26 Lua tests, 19 Python
  tests, structured files, core boundary, links, workflow pins, Git LFS
  attributes, five mod packs, hydrated media, and full-worktree diff checks.
- Post-audit shared-renderer rerun — 26 Lua tests and both visual-fidelity
  Python tests passed.

## Decision disposition

### Accepted

- Use an exact semantic draw-list oracle for layer and suppression behavior.
- Pin raw source-derived pixels separately so visual provenance is still
  checked without making failure diagnostics depend on a full screenshot.
- Keep the mandatory contract runnable in Git LFS-only CI.

### Adapted

- “Representative station room” is a compact synthetic 16×16 chunk with seven
  populated cells. This keeps the test deterministic and exhaustive for the
  current static tile vocabulary while using real Goon source selections.

### Rejected

- A whole-window screenshot hash was not used because UI/camera changes would
  obscure the tile-layer root cause and require a display in the mandatory
  suite.

### Unresolved

- Dynamic connected-state variants, damaged appearances, animation frames,
  and lighting overlays remain outside the current 20-alias static-room
  selection and need future fixture slices as those runtime contracts land.

## Sources

- `assets/runtime/goon/graphics/foundation.json`
- `assets/upstream/goon/icons/obj/atmospherics/pipes/pipe.dmi`
- `assets/upstream/goon/icons/obj/decals/wallsigns.dmi`
- `assets/upstream/goon/icons/obj/disposal.dmi`
- `assets/upstream/goon/icons/obj/doors/Doorclassic.dmi`
- `assets/upstream/goon/icons/obj/furniture/chairs.dmi`
- `assets/upstream/goon/icons/obj/furniture/table.dmi`
- `assets/upstream/goon/icons/obj/grille.dmi`
- `assets/upstream/goon/icons/obj/hazard_stripes.dmi`
- `assets/upstream/goon/icons/obj/lighting.dmi`
- `assets/upstream/goon/icons/obj/storage/crate.dmi`
- `assets/upstream/goon/icons/obj/storage/locker.dmi`
- `assets/upstream/goon/icons/obj/structures.dmi`
- `assets/upstream/goon/icons/obj/window.dmi`
- `assets/upstream/goon/icons/turf/floors.dmi`
- `assets/upstream/goon/icons/turf/walls.dmi`
- `src/assets/atlas_catalog.lua`
- `src/presentation/renderer.lua`
- `tools/assets.py`
