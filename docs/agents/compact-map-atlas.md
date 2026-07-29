# Compact map atlas agent

## Record

- Canonical task: `/root/compact_map_atlas`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: compact compiler, generated output, audit, and
  archive completed; one stale test expectation reported to the parent
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> Implement a dedicated compact native atlas for generated Goon DM map
> appearances so runtime does not reference 30 sparse 2048x2048 full-catalog
> pages. Work only in tools/assets.py plus generated compact atlas
> files/manifest fields and your docs/agents archive/index updates; coordinate
> around existing changes. Repack every selected sprite frame pixel-exactly
> from existing runtime atlas pages using Pillow, preserving per-sprite
> IDs/provenance/directions and rewriting selected sprite bundle/page/x/y to
> compact pages. Deterministic packing/output and hashes; target few 2048
> pages. Update build/audit to validate compact pages and no sparse original
> page references. Generate output. Save full task/work/state in
> docs/agents/compact-map-atlas.md and manifest/README. Do not touch Lua
> renderer/catalog files. Run focused checks and report files/results.

### Follow-up

> Important generator caveat from importer agent: static parser misses
> DEFINE_FLOORS macro calls, so 34 `/twotone/black` and 18
> `/twotone/darkblue` Atlas turfs resolve generic floor instead of
> `twotone_black` / `twotone_dblue`. While extending tools/assets.py, please
> either add safe DEFINE_FLOORS appearance expansion or coordinate an explicit
> profile-rule fix; verify those 52 map instances use correct source states in
> generated manifest.

### Generation follow-up

> I updated dm-appearance-profile.json: catwalk auto now selects numeric
> runtime states; wingrille helper now uses actual pinned
> `SL_windows_grilles.dmi` grille states with state_prefix/suffix. Please
> regenerate from the latest profile after your compiler work. Do not overwrite
> profile.

### Observable chronology

1. The agent restricted its production work to `tools/assets.py` and generated
   DM-appearance media. It explicitly told the parent it would not edit the
   Lua renderer or catalog.
2. It inspected the existing full atlas, new DM-appearance selection, asset
   compiler, audit, profile, map fixture tests, and archive format.
3. The initial selection contained 2,059 sprites and 10,512 frame references
   spread across 30 full-catalog pages. Its 5,937 unique source rectangles
   occupied approximately 1.49 pages before gutters.
4. It added a deterministic compact-atlas postprocess. The process collects
   selected source rectangles in sorted order, verifies each full-catalog
   source page hash and size, crops each frame as RGBA without scaling or color
   conversion, hashes and deduplicates exact pixels, and packs them with the
   existing one-pixel-gutter `AtlasPage` implementation.
5. The compiler now rewrites copied sprite records to the dedicated
   `dm_appearances` bundle and rewrites every frame's page and coordinates.
   Sprite IDs, DMI provenance, source states, directions, frame numbers,
   durations, dimensions, animation metadata, and hotspot metadata remain
   unchanged.
6. The selection manifest gained a `compact_atlas` summary and now declares
   only its two compact runtime pages. No selected sprite or page record points
   at a sparse full-catalog bundle.
7. The audit was expanded to require consecutive compact page numbers and
   paths, exact hashes and RGBA dimensions, a closed declared file set, exact
   sprite/provenance/direction schemas, valid frame bounds, accurate summary
   totals, and no sparse bundle references.
8. The audit additionally compares every unique selected compact frame
   byte-for-byte with its canonical full-atlas source rectangle.
9. The agent added a deliberately bounded `DEFINE_FLOORS` reader rather than a
   general DM preprocessor. It recognizes only literal
   `DEFINE_FLOORS(path, vars)` calls, balanced arguments, safe appearance
   properties, and the four roots defined by the pinned upstream macro.
10. Regeneration selected the corrected macro floors plus the parent's latest
    catwalk and wingrille connected-state families. The final selection has
    2,101 sprites, 10,537 frame references, 5,942 source rectangles, and two
    compact pages derived from 30 canonical source pages.
11. The generated rules now map all 34 selected
    `/turf/simulated/floor/twotone/black` instances to `twotone_black` and all
    18 selected `/turf/simulated/floor/twotone/darkblue` instances to
    `twotone_dblue`.
12. The audit pins those two map-instance counts and source states so a future
    lexical-parent fallback fails explicitly.
13. Two consecutive compiler runs produced identical manifest and PNG hashes.
14. The asset audit passed, including the full frame-by-frame compact pixel
    comparison.
15. Five of the six focused DM-appearance unit tests passed. The remaining
    test deliberately asserted the old, now-corrected
    `twotone/black -> floor` behavior. The agent reported that stale
    expectation to the parent because test files were outside its assigned
    write scope.
16. The full repository audit passed on the final shared-worktree state,
    including 26 Lua tests, 19 map-import tests, all mod validations, hydrated
    media validation, archive links, Git LFS checks, and diff checks. The stale
    focused file is not yet registered in that repository test entry point.

## Visible conversation summary

This section includes only messages externally visible to the parent. It does
not reconstruct hidden reasoning or private model state.

- Scope coordination:

  > I’m taking the compact map-atlas lane only: asset compiler, generated
  > compact pages/manifest metadata, validation, and docs/agent archive. I’ll
  > leave Lua renderer/catalog untouched and report exact outputs/checks.

- Stale-test coordination:

  > I found tests/test_dm_appearances.py currently asserts the known incorrect
  > DEFINE_FLOORS fallback (`twotone/black -> floor`). I’ll fix the compiler as
  > requested but won’t edit tests outside my lane; please have the test
  > owner/root update that assertion to `twotone_black` and add
  > `darkblue -> twotone_dblue`.

- Latest-profile coordination:

  > Got it. I’m regenerating the compact selection from your latest profile
  > without touching the profile, then I’ll refresh deterministic hashes/counts
  > in the archive and rerun the pixel audit.

## Normalized visible work report

### Compact atlas contract

`assets/runtime/goon/graphics/dm-appearances.json` remains a
format-version-1 `goon-dm-appearance-selection`. Its selected sprite entries
now use the `dm_appearances` bundle, and its page list contains only:

- `dm_appearances/atlas-000.png`
- `dm_appearances/atlas-001.png`

The added `compact_atlas` record captures:

- bundle name;
- page size and gutter;
- canonical source-page count;
- unique source-rectangle count;
- total frame-reference count; and
- unique packed-frame count.

The canonical full `atlas.json` hash remains in the selection manifest. The
full atlas therefore remains the authoritative ID and provenance index even
though the runtime selection no longer loads its sparse pages.

### Deterministic output

Generation order is independent of Python dictionary insertion order:

- sprite IDs and direction names are sorted;
- source rectangles are represented by numeric packing tuples and sorted;
- source pages and frames are verified before copying;
- packing uses fixed 2048×2048 RGBA pages, a fixed one-pixel gutter, and the
  existing deterministic PNG recipe; and
- generated JSON uses the repository's sorted-key writer.

Observed stable SHA-256 values across consecutive generation runs:

- manifest:
  `ffdb6a7c94e32074c7222493658a6927d754d6933446110a223e6b9f6ce0750a`
- page 0:
  `0a5015ba08f3eca3c8945f6926f26cb4576fef865c5f51c6ed36082d0772be3c`
- page 1:
  `0d28039745f49d2bcc40e327dd242923fa5d9ea2a87e9c4e572df3fc28f0141d`

The PNG payloads were approximately 1.44 MB and 0.73 MB respectively at
generation time.

### Files changed by this task

- `tools/assets.py`
- `assets/runtime/goon/graphics/dm-appearances.json` (generated selection
  extended and regenerated)
- `assets/runtime/goon/graphics/dm_appearances/atlas-000.png` (generated)
- `assets/runtime/goon/graphics/dm_appearances/atlas-001.png` (generated)
- `docs/agents/compact-map-atlas.md`
- `docs/agents/README.md`
- `docs/agents/manifest.json`

No Lua renderer, Lua asset catalog, scenario, importer, mod, or general test
file was edited by this task.

### Validation observed

- `python3 -m py_compile tools/assets.py` — passed.
- Direct static-index check — `twotone/black` resolved `twotone_black`;
  `twotone/darkblue` resolved `twotone_dblue`.
- `python3 tools/assets.py build-dm-appearances` — passed twice with identical
  manifest and page hashes.
- `python3 tools/assets.py audit` — passed:
  - 5,869 pinned upstream files;
  - 1,159 graphics source files;
  - 46,160 full-catalog sprites;
  - 29 foundation sprites on 14 pages;
  - 1,172 DM appearance rules and 2,101 selected sprites on 2 compact pages;
  - 4,699 audio catalog entries and 11 foundation sounds; and
  - all selected compact frame pixels equal to the canonical atlas pixels.
- `luajit tests/run.lua` — 26 tests, 0 failures against compact page
  resolution.
- `python3 tools/dev.py audit` — passed on the final shared worktree, including
  the Lua suite, 19 Python map-import tests, five mod packs, hydrated asset
  audit, 74 Markdown documents, structured files, Git LFS attributes, and diff
  checks.
- `python3 -m unittest tests.test_dm_appearances` — five tests passed and one
  stale expected-value test failed because it still requires the deliberately
  fixed `twotone/black -> floor` fallback.
- `git check-attr` confirmed both generated compact PNGs use Git LFS.

## Decision disposition

### Accepted

- Repack selected pixels from the already compiled native atlas instead of
  adding DMI parsing to runtime.
- Preserve the full catalog as canonical provenance while loading only a
  dedicated compact runtime selection.
- Verify compact pixels against canonical source rectangles during every
  hydrated asset audit.
- Expand only the exact `DEFINE_FLOORS` data macro required for safe static
  appearance resolution.

### Adapted

- Exact pixel duplicates are eligible to share a compact atlas location. Every
  sprite direction/frame reference remains present and retains its metadata.
- Compact pages retain the project's standard 2048-pixel size and one-pixel
  replicated gutter so they use the same LÖVE sampling contract as other
  native atlases.

### Rejected

- Copying the 30 referenced full-catalog pages into a nominally separate
  directory was rejected because it would retain the startup and distribution
  cost.
- A general DM macro evaluator was rejected. The bounded literal reader does
  not execute expressions, procs, or arbitrary preprocessing.

### Unresolved

- The stale unit-test assertion must be updated outside this task's assigned
  file scope before the focused suite is fully green.
- Public asset-pipeline documentation may need a short compact-selection
  contract update by the parent documentation lane.

## Sources

- `tools/assets.py`
- `assets/runtime/goon/graphics/atlas.json`
- `assets/runtime/goon/graphics/dm-appearances.json`
- `assets/source/goon/dm-appearance-profile.json`
- pinned Goonstation
  `code/turf/floors.dm`
- pinned Goonstation
  `_std/macros/turf.dm`
- pinned Goonstation
  `maps/atlas.dmm`
