# Rendering and the complete graphics fork

## Source policy and layout

The initial import is pinned to Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`. The implemented canonical
inventory records 1,159 graphics-source files: 1,139 DMI, 17 PNG, and one each
of PSD, PDN, and XCF. The DMI subset contains 46,143 states and 164,541
frame-direction cells; the runtime compiler adds the 17 ordinary PNGs as
single-cell sprites, producing 46,160 sprite records and 164,558 logical cells.
Every source record carries its path, Git blob ID where available, byte size,
and SHA-256.

The repository has four asset layers:

```text
assets/upstream/goon/               immutable pinned DMI/PNG inputs (Git LFS)
assets/source/goon/graphics/        editable extracted PNG + TOML fork (Git LFS)
assets/runtime/goon/graphics/       generated pages/indexes (Git LFS)
assets/runtime/goon/*/provenance.json and upstream inventory
```

- Upstream bytes are never edited or silently replaced.
- Editable PNG/TOML is the preferred source for Sim Station changes.
- Generated files are never edited by hand.
- A source update is an explicit new pinned snapshot and three-way import
  review; it never tracks a moving upstream branch.
- Release packages ship generated runtime bundles, indexes, credits, and
  notices. They omit immutable/editor sources that remain available at the
  exact public repository revision.

The Goon fork is the ordinary asset pack `org.simstation.goon`, depended on by
`org.simstation.core`. A placeholder/core-free distribution can replace that
dependency without changing renderer code.

## Stable sprite mapping

Every DMI state occurrence and ordinary PNG receives a permanent `SpriteId`.
The implemented importer proposes it deterministically:

```text
org.simstation.goon:sprite/icons/turf/floors-dmi/floor--<state-hash>-o01
```

The source path/state slug is readable, the state hash distinguishes original
UTF-8 names that normalize alike, and the occurrence suffix preserves duplicate
state names in one DMI. `assets/runtime/goon/graphics/atlas.json` is the
committed mapping and becomes authoritative after the first import. A later
source rename must preserve the existing ID through an importer mapping/alias;
it must not regenerate a public ID. One sprite record is one DMI animation
state, so gameplay appearances refer to the sprite ID and direction rather
than a separate state string. Empty/default and duplicate state names remain
recoverable through `source_state`, `source_state_index`, and
`source_state_occurrence`.

## DMI ingestion

DMI is PNG with a `Description` text chunk. The compiler adapts the pinned
[Goonstation DMI parser](https://raw.githubusercontent.com/goonstation/goonstation/1b2b250abb5be747d55e274de0203a59cfc8da78/tools/dmi/__init__.py)
and independently verifies all bounds.

For DMI 4.0:

- cell width/height default to 32 and must be positive;
- `state` order is significant; state names and the empty/default state are
  retained;
- `dirs` must be 1, 4, or 8;
- `frames` must be positive;
- cells are laid out state-major, then frame-major, then direction-major;
- direction order is `SOUTH(2)`, `NORTH(1)`, `EAST(4)`, `WEST(8)`,
  `SOUTHEAST(6)`, `SOUTHWEST(10)`, `NORTHEAST(5)`, `NORTHWEST(9)`;
- one-direction states map every requested direction to their first cell;
- decimal `delay` values are BYOND deciseconds;
- `loop = 0` is unlimited and a positive loop count is retained;
- `rewind`, `movement`, and frame-effective `hotspot` records are retained.

Metadata numbers are parsed from decimal text, never through binary
floating-point. Editable TOML keeps delay strings. Runtime metadata stores
`duration_us = delay × 100000`, requiring an exact integer microsecond; inputs
with finer precision fail for review. An omitted or missing per-frame delay
means `"1"` for that frame; surplus values are ignored at runtime but retained
in provenance as a warning. A zero duration frame is omitted from playback,
not from source/index data; a clip with no positive frame fails validation.

Rewind playback visits `0..n-1` and then `n-2..1`, avoiding duplicated endpoints.
A positive loop count counts complete forward-or-rewind cycles; after the last
cycle, the final timeline frame is held. Infinite loops repeat. This is Sim
Station's runtime contract and must be compared visually against representative
BYOND reference fixtures before the importer is accepted.

The compiler validates that the PNG grid contains at least the declared cell
count, that unused grid cells are fully transparent, and that each crop is
exactly its declared dimensions. It preserves raw RGBA bytes and full canvases:
no trimming, pivot movement, rotation, rescaling, premultiplication, palette
conversion, mipmaps, or lossy compression.

BYOND documents modern DMI as full-alpha PNG and permits larger icon dimensions
([BYOND 4.0 icon notes](https://secure.byond.com/docs/notes/400.html)); those
properties are preserved rather than assuming every image is one 32px tile.

## Editable graphics format

Each imported source file has a lossless RGBA8 PNG sheet plus TOML, while each
compiled logical sprite remains one state record:

```toml
format_version = 1
source_path = "icons/turf/floors.dmi"
source_commit = "1b2b250abb5be747d55e274de0203a59cfc8da78"
source_sha256 = "..."
dmi_version = "4.0"
cell_width = 32
cell_height = 32

[[states]]
name = "floor"
dirs = 1
frames = 1
raw_delay_ds = []
delay_ds = ["1"]
loop = 0
rewind = false
movement = false
hotspots_raw = []
```

Cells remain frame-major/direction-major. Imported frames preserve their full
canvas; appearance definitions provide pixel offsets/pivots rather than
rewriting images. Hotspots remain in `hotspots_raw` as source coordinates until
a typed appearance/tool consumes them; that consumer converts BYOND's
bottom-left convention once to LÖVE's top-left convention and has a fixture.

## Deterministic atlas compiler

The implemented canonical entry points are:

```text
python3 tools/assets.py fetch-goon
python3 tools/assets.py import-graphics-source
python3 tools/assets.py build-graphics
python3 tools/assets.py audit
```

`python3 tools/assets.py all` runs the whole graphics/audio path. The pinned
commit comes from `assets/upstream/goon/upstream.lock.toml`, not a caller
override. The compiler version, Python version, Pillow version, packing
configuration, source hashes, and command are locked in `build-manifest.json`.
Packing is deterministic:

1. validate and enumerate logical sprites by generated/committed sprite ID,
   state order, frame, and canonical direction;
2. partition by pack, declared lazy bundle, sampler, and color treatment;
3. hash cell width, height, and RGBA bytes and deduplicate identical cells
   within each bundle while preserving all logical references;
4. place cells with the implemented deterministic nonrotating shelf packer in
   source order, advancing X, then row Y, then page;
5. never rotate;
6. add a one-pixel gutter that duplicates each cell's outer pixel, including
   corners;
7. write 2,048×2,048 RGBA8 PNG pages with transparent unused space, stripped
   nondeterministic timestamps, and fixed encoder settings;
8. retain any cell up to 2,048px in its bundle pages without resizing;
9. emit canonical JSON, then bundle-sharded zlib indexes for release runtime.

Cells over 2,048px fail portable validation and require an explicitly tiled
appearance definition. The implemented page names are stable
`<bundle>/atlas-NNN.png`; page and catalog hashes, rather than a name fragment,
identify bytes.

The implemented review/runtime catalog has this logical shape:

```json
{
  "format_version": 1,
  "pack_id": "org.simstation.goon",
  "source_commit": "1b2b...",
  "page_size": 2048,
  "gutter": 1,
  "bundles": {
    "core_tiles": {
      "pages": [
        {"file": "atlas-000.png", "width": 2048, "height": 2048,
         "format": "rgba8-png", "sha256": "..."}
      ],
      "sprites": [
        "org.simstation.goon:sprite/icons/turf/floors-dmi/floor--...-o01"
      ],
      "unique_frames": 7427
    }
  },
  "sprites": {
    "org.simstation.goon:sprite/icons/turf/floors-dmi/floor--...-o01": {
      "id": "org.simstation.goon:sprite/icons/turf/floors-dmi/floor--...-o01",
      "bundle": "core_tiles",
      "source_path": "icons/turf/floors.dmi",
      "source_state": "floor",
      "cell_width": 32,
      "cell_height": 32,
      "dirs": 1,
      "frames": 1,
      "delay_ds": ["1"],
      "loop": 0,
      "rewind": false,
      "movement": false,
      "directions": {
        "south": [
          {"page": 0, "x": 1, "y": 1, "w": 32, "h": 32,
           "frame": 1, "duration_ds": "1"}
        ]
      }
    }
  },
  "warnings": []
}
```

The emitted catalog contains no executable Lua. The current full catalog is the
review artifact; before M2 exits, the compiler additionally shards it by bundle
and zlib-compresses each shard for lazy runtime parsing while retaining this
canonical uncompressed JSON. A compact shard must decode exactly to the same
logical records.

## Appearance contract

An appearance is an ordered stack rather than a pre-baked combination:

```text
underlays[] → base → overlays[]
```

Each entry declares sprite, direction override, animation origin tick,
pixel offset, plane, layer, alpha, blend, tint, optional 4×5 fixed-point color
matrix, scale/rotation transform, and visibility rule. Sort by:

1. plane;
2. map-space foot Y in 1/256 tile;
3. layer;
4. stable entity ID;
5. stack index.

The renderer must not reorder across this sequence to reduce draw calls. It may
batch only contiguous entries that share page, shader, blend, and scissor.
Underlays, clothing, held items, limbs, reagents, emissives, damage, and status
effects remain compositional so mods can participate without an exponential
pre-bake.

Supported baseline blend modes are `alpha`, `add`, `multiply`, and `replace`.
Unsupported imported BYOND filters/transforms fail appearance migration or use
a documented, visually reviewed approximation; they are never silently
dropped.

## LÖVE runtime

The mandatory path is PNG → `Image` → cached `Quad` → `SpriteBatch`. LÖVE
describes SpriteBatch as the optimized many-draw path and guarantees a minimum
2,048px texture dimension
([SpriteBatch](https://love2d.org/wiki/SpriteBatch),
[graphics limits](https://love2d.org/wiki/GraphicsLimit)).

- Set nearest min/mag filtering and no mipmaps.
- Keep straight alpha and `gammacorrect = false` for byte-preserving initial
  output; any future gamma change requires golden-image review.
- Align world pixels to integers at integral zoom. Fractional zoom may move
  vertices fractionally but never changes filtering.
- Never create a whole-map Canvas: 192×192 tiles at 32px is 6,144×6,144.
- Build static floor, structure, utility, and persistent-decal SpriteBatches
  per 16×16 world chunk and atlas page.
- Rebuild a static chunk/page batch only when its saved chunk revision changes.
- Build dynamic contiguous page runs each frame for crew, items, animated
  machinery, fluids, and effects after the stable appearance sort.
- Create `Image`, `Quad`, SpriteBatch, Canvas, and Shader objects on the main
  thread only. A worker may read/compress/hash bytes and may decode transferable
  `ImageData` when the platform test permits it.

The default residency cap is eight regular 2,048px RGBA pages (128 MiB decoded
GPU pixels). Core UI/visible-map pages count against the cap and are pinned only
for the current scene. Standalone oversized pages consume their actual byte
size and may temporarily raise the cap to 160 MiB for one frame; otherwise the
loader substitutes the missing-sprite cell and logs the budget conflict.

Scenario manifests prewarm required bundles. LRU eviction operates only between
frames, never evicts a referenced page, destroys LÖVE objects on the main
thread, and is presentation-only. Array images, DDS/KTX, and GPU compression
may be profiled as optional caches but every package retains the PNG fallback
([`newImage`](https://love2d.org/wiki/love.graphics.newImage),
[`newArrayImage`](https://love2d.org/wiki/love.graphics.newArrayImage)).

## Mod graphics

Packaged mods ship compiler-produced pages and an index. Loose development mods
may contain PNG/TOML source; title-screen developer mode compiles them into the
LÖVE save-directory cache keyed by source/config/compiler hashes. Release mode
never parses DMI or repacks loose sprites. A mod cannot overwrite an atlas
coordinate; it adds or explicitly replaces logical sprite IDs.

Archive validation caps a mod page at 2,048×2,048, total declared decoded
graphics at 512 MiB, and any single image at 32 MiB compressed. The loader
checks PNG dimensions before decode, verifies every index rectangle/gutter and
hash, and rejects path traversal, duplicate archive paths, case-folded
collisions, and decompression bombs.

## Verification

- Pixel-compare every logical source cell with the atlas crop, excluding only
  its generated gutter.
- Round-trip state names, direction fallback, frame order, exact durations,
  loops, rewind, movement, and hotspots.
- Build twice in clean directories and require identical file hashes.
- Generate contact sheets and animated previews for every changed sprite.
- Test empty state names, escapes, missing/surplus/zero delays, 1/4/8 dirs,
  non-32px cells, partially filled grids, large overlays, and identical cells.
- Exercise an OpenGL 2-class/no-array/no-compression path on each platform.
- Benchmark camera pans, full zoom-out, dirty-chunk storms, 100 composited crew,
  fire/fluids, and eight-page residency pressure without batch corruption.
- Compare representative animated fixtures against BYOND capture/reference
  output before accepting the importer.

## Implemented foundation

`tools/assets.py` has fetched and compiled the complete pinned snapshot into
eight bundles and 134 atlas pages with source/runtime catalogs. A generated
16 KiB foundation selection resolves 12 logical sprites without parsing the
71 MiB exhaustive catalog. Its eight referenced pages add APC, generator,
vent, scrubber, fabricator, and refinery art to the original floor, wall,
door, and crew selection. The presentation renderer lazy-loads pages, uses
revisioned per-chunk SpriteBatches for imported static structure, and draws
authored Atlas machines with generated shapes as the missing-media fallback.

`verify-graphics` compares every one of the 164,558 compiled
frame-direction cells to its pinned source pixels, and a clean rebuild produces
identical page/catalog hashes. General page-residency eviction, full
appearance-layer composition, contact-sheet review, and broader BYOND capture
fixtures remain M2 work.

The upstream inventory, source license, modification records, and broad
contributor credit are governed by the
[provenance specification](../legal/goon-provenance.md) and pinned
[sprite attribution list](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/strings/changelog_attribution/spriters.txt).
