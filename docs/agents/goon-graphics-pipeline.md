# Harvey — Goonstation graphics pipeline

## Record

- Canonical task: `/root/goon_graphics_pipeline`
- Display name: Harvey
- Last observable status: findings incorporated into the approved plan; the
  exact terminal runtime status is no longer visible
- Report availability: consolidated findings only
- Assignment availability: reconstructed from the user request and planning
  record

No full transcript or final response remains available. The material below is
the consolidated research visible to the lead agent; it is not a verbatim
agent transcript.

### Reconstructed assignment

Audit the pinned Goonstation graphics tree and DMI format, identify licensing
and provenance requirements, and design a deterministic compiler that turns
the graphics fork into fast, portable LÖVE-native assets.

### Observable chronology

1. The project owner requested that Goonstation graphics be forked and
   re-tiled into a native LÖVE format for performance.
2. Harvey was assigned the Goon graphics audit and conversion-pipeline design.
3. The planning record retained the inventory, DMI semantics, atlas design,
   and provenance recommendations below.
4. The project owner approved a complete pinned graphics fork, build-time
   conversion, Git LFS storage, and no base-game runtime DMI loading.

## Consolidated findings

### Source inventory

- The source snapshot is pinned to Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- A preliminary recursive-tree query counted 1,159 files under `icons/`,
  including 1,138 `.dmi` and 17 `.png` files, totaling about 86.6 MB.
- Harvey's later consolidated whole-source audit reported 1,139 DMI files
  totaling 90,095,857 bytes, 46,143 icon states, and 164,541 direction/frame
  cells. The decoded cells occupy about 1.97 GiB as RGBA.
- Of the reported states, 31,744 use one direction, 13,770 use four directions,
  and 629 use eight directions. The audit found 7,490 animated states, 522
  rewind states, 152 movement states, and 101 hotspot records.
- The preliminary query and the whole-source audit differ by one DMI because
  the preliminary query was scoped to `icons/`. The importer must nevertheless
  regenerate and preserve its own canonical inventory before accepting these
  counts as a release invariant.
- Major source groups included `obj`, `mob`, `misc`, `effects`, `turf`,
  `cursors`, and `ui`.
- The broad sprite-contributor attribution list is stored at
  `strings/changelog_attribution/spriters.txt` in the pinned tree.

### DMI semantics

- DMI files are PNG files with an embedded `Description` text chunk.
- A sampled `icons/turf/floors.dmi` was a 1,408×1,376 RGBA PNG with 32×32 cells.
- Metadata defines ordered state names, cell width/height, directions, frame
  count, per-frame decimal delays, loops, rewind, movement, and hotspots.
- States may use 1, 4, or 8 directions and multiple animation frames.
- Appearance semantics also depend on runtime composition: overlays,
  underlays, pixel offsets, layers/planes, alpha, blend, transforms, and color
  matrices cannot be recovered from DMI cells alone.
- Trimming or repivoting frames would break alignment and must not be done.

### Proposed compiler

- Preserve the pinned DMI files as immutable provenance inputs.
- Convert them to editable lossless PNG plus TOML metadata for ongoing fork
  work.
- Implement the build-time converter in Python 3 with Pillow, adapting and
  testing against Goonstation's pinned DMI parser behavior.
- Compile deterministic, non-rotated 2,048×2,048 RGBA8 PNG atlas pages with a
  one-pixel duplicated-edge gutter.
- Preserve complete canvas dimensions, pivots, default/empty states, direction
  ordering, frame ordering, timing, loops, rewind, movement, and hotspots.
- Deduplicate byte-identical cells without removing logical sprite IDs.
- Put frames larger than 256px on standalone lazy-loaded pages.
- Emit reviewable provenance JSON and a compact versioned runtime index.
- Group pages into lazy bundles rather than loading the full decoded corpus.
- Keep appearance composition declarative at runtime instead of baking every
  possible clothing, held-item, reagent, and tint combination.
- Define explicit tests for missing/extra delay values, zero-duration frames,
  decimal delays, finite loops, rewind, movement, and hotspots.

## Decision disposition

### Accepted

- Fork the complete pinned graphics source and retain it in Git LFS.
- Compile all shipped base graphics before runtime.
- Use lossless PNG atlases, stable sprite IDs, cached Quads, and SpriteBatches.
- Preserve all DMI animation and direction semantics.
- Keep raw source, editable fork, generated runtime artifacts, provenance,
  compiler version, and output hashes in one repository.
- Make source updates explicit, pinned, diffable import jobs.

### Adapted

- “Native LÖVE format” was defined as LÖVE's portable PNG/Image/Quad/
  SpriteBatch path, not a proprietary container.
- Runtime appearance data was expanded beyond atlas metadata to represent
  Goon-style compositing rules.
- Large source volume led to lazy bundles and a bounded page residency policy.

### Rejected

- Runtime base-game DMI parsing.
- Lossy texture conversion, frame trimming, rotation, rescaling, or mandatory
  GPU-specific compression.
- Baking the entire map into one texture or Canvas.
- Loading the complete decoded source corpus into memory.

### Unresolved verification

- Reconcile the 1,138-versus-1,139 DMI count during the first pinned import.
- Pixel-compare every emitted atlas cell against the original source.
- Confirm exact direction ordering and edge cases against the pinned parser,
  rather than relying on memory or a generic PNG reader.

## Sources

- [Pinned Goonstation tree](https://github.com/goonstation/goonstation/tree/1b2b250abb5be747d55e274de0203a59cfc8da78/icons)
- [Pinned Goonstation license](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE)
- [Pinned DMI parser](https://raw.githubusercontent.com/goonstation/goonstation/1b2b250abb5be747d55e274de0203a59cfc8da78/tools/dmi/__init__.py)
- [Pinned sprite attribution list](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/strings/changelog_attribution/spriters.txt)
- [BYOND reference](https://www.byond.com/docs/ref/info.html)
- [BYOND 4.0 notes](https://secure.byond.com/docs/notes/400.html)
- [BYOND forum explanation of DMI Description metadata](https://www.byond.com/forum/post/1121073)
