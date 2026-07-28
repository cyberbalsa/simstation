# Kierkegaard — LÖVE rendering and native assets

## Record

- Canonical task: `/root/love_render_assets`
- Display name: Kierkegaard
- Last observable status: findings incorporated into the approved plan; the
  exact terminal runtime status is no longer visible
- Report availability: consolidated findings only
- Assignment availability: reconstructed from the user request and planning
  record

No full transcript or final response remains available. The material below is
the consolidated research visible to the lead agent; it is not a verbatim
agent transcript.

### Reconstructed assignment

Determine the fastest portable graphics representation and rendering path for
a LÖVE 11.5 tile-based station simulation, including atlas formats, texture
limits, batching, filtering, chunk invalidation, and graceful fallbacks.

### Observable chronology

1. The project owner proposed converting Goonstation graphics to a format
   native to LÖVE for speed.
2. Kierkegaard researched LÖVE 11.5 texture and batching facilities.
3. The findings below were consolidated into the graphics-fork plan.
4. The project owner approved PNG atlases and SpriteBatch rendering as the
   mandatory portable path.

## Consolidated findings

- Pin LÖVE 11.5 as the initial runtime.
- LÖVE natively decodes PNG into `Image` objects. Cached `Quad` objects select
  atlas regions, and `SpriteBatch` is the primary high-throughput rendering
  path.
- A 2,048×2,048 page is a safe project baseline because LÖVE documents at least
  that texture size; runtime capability queries can permit optional larger
  pages, but shipped base content must not require them.
- A 192×192 map of 32px tiles spans 6,144×6,144 pixels. It cannot be represented
  as a single portable Canvas or texture.
- Cache static floor, wall, structure, and decal batches by visible world chunk
  and atlas page using 16×16-tile chunks. Rebuild a batch only when its source
  chunk becomes dirty.
- Keep crew, items, animated machines, fluids, and effects dynamic.
- For overlap-sensitive appearances, sort by plane, screen Y, and stable entity
  ID, then submit contiguous atlas-page runs without changing visual order.
- Pixel art should use nearest filtering, straight alpha, no mipmaps, and
  integer-aligned rendering where possible.
- Texture arrays and DDS/KTX compressed textures may be profiled as optional
  optimizations, but they must not become compatibility requirements.
- A page residency budget and lazy bundle loading are necessary because the
  complete decoded Goonstation corpus would be far larger than its compressed
  source.
- Create LÖVE `Image` and other graphics objects on the main thread. Worker
  threads may read/decode bytes into transferable data, but must not create or
  mutate graphics resources.
- Packaged mods should ship prebuilt atlas pages and indexes. Development mods
  may invoke the same external compiler/cache path, but production loading
  should not repack arbitrary loose sprites during a frame.

## Decision disposition

### Accepted

- PNG → `Image` → cached `Quad` → `SpriteBatch` is the mandatory baseline.
- Use 2,048×2,048 atlas pages, 16×16 chunk-local dirty rebuilds, nearest
  filtering, and no mipmaps.
- Keep render state derived from immutable simulation snapshots.
- Preserve a portable fallback when optional GPU features are unsupported.

### Adapted

- The native format is a versioned bundle consisting of lossless PNG pages plus
  compact atlas metadata, not one special binary texture format.
- Static and dynamic content use separate batching strategies.
- Full-corpus import is paired with lazy runtime residency.

### Rejected

- A whole-map texture or Canvas.
- A runtime requirement for array textures, DDS, KTX, FFI, native decoders, or
  platform-specific compression.
- Rebuilding every tile every frame.
- Reordering sprites merely to reduce draw calls when that changes visual
  overlap.
- Creating LÖVE graphics resources on worker threads.

## Sources

- [LÖVE 11.5 release](https://github.com/love2d/love/releases/tag/11.5)
- [LÖVE `love.graphics.newImage`](https://love2d.org/wiki/love.graphics.newImage)
- [LÖVE `Quad`](https://love2d.org/wiki/Quad)
- [LÖVE `SpriteBatch`](https://love2d.org/wiki/SpriteBatch)
- [LÖVE graphics limits](https://love2d.org/wiki/GraphicsLimit)
- [LÖVE array images](https://love2d.org/wiki/love.graphics.newArrayImage)
- [LÖVE `Image:setFilter`](https://love2d.org/wiki/Image:setFilter)
