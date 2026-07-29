# Dynamic lighting runtime review

## Archive metadata

- Canonical task: `/root/lighting_runtime_review`
- Assignment evidence: **verbatim**
- Report evidence: **observable read-only audit and consolidated final report**
- Last observed status: review completed; no production code changed
- Date: 2026-07-28

## Assignment

> Audit current Sim Station renderer/world/camera/light feature and propose a
> portable LOVE2D dynamic-light implementation that works on low-end hardware.
> Focus chunk invalidation, occlusion, screen/world transforms, blend
> modes/canvas fallback, determinism, and exact integration points. No
> production edits. You may add a tests-only contract if the current API
> supports it, but coordinate first. Archive under
> docs/agents/lighting-runtime-review.md plus indexes, and message /root with
> findings.

The parent later selected and requested review of this implementation split:

> CPU occlusion-aware 1-texel-per-tile RGB light field, GPU full-world
> multiply shader sampling it with linear filtering, no full-map scene Canvas;
> small additive emitter bloom after.

## Status quo

The current renderer does not implement scene lighting. It creates one
65×65 RGBA radial image in `make_light_image`, batches one instance for each
visible active fixture, and draws the batch with
`setBlendMode("add", "alphamultiply")` in
`Renderer:_draw_light_glows`.

An active fixture currently means:

```text
world.powered[index]
and FEATURE.LIGHT
and installed is not false
and broken is not true
and on is not false
```

That is a useful source gate, but the visual result is only a very faint bloom:
the peak generated alpha is `0.075`, the falloff is `alpha²`, walls do not
occlude it, and nothing darkens unlit station pixels. Sources are scanned only
inside the renderer's four-cell map-appearance overscan. A future light with a
larger radius can therefore affect the viewport while its source is outside
that scan.

The relevant existing contracts are:

- the authoritative arrays and serialized fixture state live in
  `src/core/world.lua`;
- fixture remove, replace, and toggle handlers touch the fixture's local
  16×16 world chunk;
- walls and door transitions also touch their local chunk;
- `World:step_power` changes `world.powered` and increments only the global
  `power_revision`; it does **not** touch affected chunks;
- power is recalculated every ten simulation ticks, or once per simulated
  second;
- atmosphere increments `gas_revision`, while fire intensity can change
  without touching a render chunk;
- the renderer already draws in world coordinates inside the camera's snapped
  transform and viewport scissor; and
- `gammacorrect = false`, atlas images use nearest filtering, and supported
  zooms are `0.25`, `0.5`, `1`, `2`, and `4`.

The imported Atlas crop contains 353 semantic light cells and 354 native
`/obj/machinery/light` appearance records. The one-record difference is an
authored overlap, so runtime emission must be keyed by semantic source identity
instead of blindly emitting once per appearance record.

The APC machine has a bounded `data.lighting` channel state, but
`World:step_power` does not currently apply that channel to area light power.
Dynamic rendering can accurately follow the current authoritative
`world.powered` and fixture state, but it cannot make that deferred APC
behavior source-faithful by presentation inference.

## Decision on the CPU/GPU split

The selected split is appropriate for the portable baseline, with the shader
kept deliberately small:

1. CPU code resolves sources, integer attenuation, and opaque-tile visibility.
2. It writes one RGBA8 texel per world tile. RGB is the final multiplicative
   illumination factor and alpha is always one.
3. The light-field `Image` uses linear min/mag filtering, no mipmaps,
   `dpiscale = 1`, and clamp wrap.
4. While the existing world-space camera transform and scissor are active, the
   renderer draws that image from `(0, 0)` at scale `32, 32`.
5. A minimal pixel shader samples the image and returns
   `vec4(light.rgb, 1.0)`.
6. The draw uses `setBlendMode("multiply", "premultiplied")`.
7. Small fixture/fire emissive overlays are drawn additively **after** the
   multiply pass.

At the maximum supported scenario size, 256×256, the light field is only
256 KiB in RGBA8. Atlas is 192×192, or 144 KiB. This is not the prohibited
6,144×6,144 full-map scene Canvas; it is a tiny data texture. The world-sized
quad also does not allocate world-sized render pixels. Scissoring limits its
fragment work to the visible viewport.

The shader offloads per-screen-pixel interpolation and multiplication. It
should not attempt to raymarch walls or loop over source uniforms. GPU
occlusion would introduce uniform limits, renderer-dependent precision,
source-count caps, and much higher fragment cost on low-end or mobile
hardware. The authoritative visual field remains a deterministic CPU result.

Strictly speaking, LÖVE's default image shader can already sample the scaled
light texture. Keeping a custom shader is still reasonable as a named
composition boundary and for future presentation-only tuning. Its fallback
can draw the same filtered image directly under multiply blending, producing
the same contract without a custom shader.

## LÖVE 11.5 details

The shader should use LÖVE's portable effect language without
`#pragma language glsl3`, derivatives, loops, arrays, `discard`, or
high-precision assumptions:

```glsl
vec4 effect(
  vec4 color,
  Image texture,
  vec2 texture_coords,
  vec2 screen_coords
) {
  vec3 light = Texel(texture, texture_coords).rgb;
  return vec4(light * color.rgb, 1.0);
}
```

`Texel`, rather than raw `texture2D`, is the portable LÖVE spelling across its
desktop and GLES shader targets. Compile the shader once on the main thread
inside `pcall`; never compile it in `draw`.

LÖVE 11.x supports multiply only with the `premultiplied` alpha mode. With
source alpha fixed at one, the specified blend computes:

```text
result.rgb = light.rgb * existing_scene.rgb
```

The lighting draw must save and restore the previous shader, blend mode,
alpha mode, and draw color. Restoring only `"alpha"` is fragile if a mod-owned
appearance pass later surrounds the renderer with another legal blend state.

The CPU backing store can be one reusable
`love.image.newImageData(width, height, "rgba8")`. Update the matching
`Image` with `Image:replacePixels`; a complete 256×256 upload is small enough
that the initial implementation need not depend on partial-update behavior.
Only upload after the computed field actually changes.

Do not create a Canvas for the mandatory path. If a later quality option adds
blur or bloom through a Canvas, it must:

- check supported Canvas formats before creation;
- use ordinary `rgba8`, zero MSAA, no mipmaps, and explicit DPI scale;
- remain viewport-sized or smaller, never world-scene-sized;
- recreate or redraw after window/context changes; and
- retain the non-Canvas light-image path.

## Coordinates, DPI, zoom, and filtering

Draw the light image in world coordinates while `camera:apply()` is active:

```text
image pixel (0, 0)          -> world tile (1, 1)
image texel center (x, y)   -> center of world tile (x + 1, y + 1)
image width/height          -> world width/height in tiles
draw scale                  -> TILE_SIZE, TILE_SIZE
```

This avoids screen-coordinate uniforms entirely. The existing camera handles
pan, discrete zoom, viewport offset, DPI-scaled units, and snapping for both
map art and light. Use `dpiscale = 1` for the light `Image`, matching the atlas
contract. Do not call `screen_to_world` in the shader or derive UVs from
`screen_coords`.

Set linear filtering only on the light-field image. Atlas and UI images remain
nearest-filtered. Clamp wrap prevents sampling the opposite map edge.

One-texel-per-tile linear interpolation deliberately softens the CPU samples.
It cannot preserve an infinitely sharp shadow edge within a tile: a lit opaque
wall texel can interpolate up to half a tile toward the dark side. This does
not make a tile center behind the wall visible, but it can create a narrow
soft fringe. Acceptance images must review that fringe at 0.25× through 4×.
If it becomes objectionable, the portable choices are:

- nearest-filtered light for the low quality mode;
- two or four samples per tile for the normal mode; or
- an opacity-aware sampling shader with a second small grid texture.

Do not solve it by blurring a full scene Canvas.

Space should not inherit the station's near-black ambient by accident.
The CPU field should assign an explicit high ambient to space and a tunable
low ambient to constructed station tiles. Otherwise the multiply pass erases
the starfield that the reference keeps visible.

## CPU light-field contract

Keep the calculation outside `src/core/`; it is presentation state and must
never enter hashes, saves, commands, or NPC decisions. A useful split is:

- `src/presentation/light_field.lua`: pure Lua source gating, spatial index,
  fixed-point attenuation, line of sight, and dirty-region calculation;
- `src/presentation/lighting.lua`: LÖVE `ImageData`, `Image`, Shader, blend
  state, draw, and fallback resources.

Use row-major tile indices and stable source IDs. Avoid `pairs` in source
resolution. Recommended channel units are integers from 0 through 1024:

```text
field = ambient + sum(each visible source contribution)
field = clamp(field, 0, 1024)
ImageData channel = field / 1024
```

Accumulate all source contributions before clamping. Precompute integer
attenuation lookup tables by radius and squared distance. This makes the CPU
field independent of source insertion order and avoids GPU-dependent
visibility math.

For the baseline:

- walls and closed doors are opaque;
- the opaque target tile receives light but stops propagation behind itself;
- open doors, windows, grilles, tables, and normal machines are transparent;
- diagonal passage between two touching opaque cardinal neighbors is blocked;
- ordinary source tiles emit in all directions after their own tile;
- source radius is capped and validated, recommended maximum 12 tiles; and
- semantic `FEATURE.LIGHT` gets one data-owned default profile when no more
  specific validated profile exists.

A bounded supercover/Bresenham line from source center to target center is
simple to fixture-test and inexpensive at these radii. A symmetric shadowcast
is also acceptable, but its octant and corner rules must be frozen by tests.

Fire should enter the same source list with a stable tile-derived ID and an
intensity-derived profile. The flame sprite itself belongs after the darkness
pass. Moving flashlights and emissive entities can later enter as a sorted
dynamic-source list; they should not require a new renderer architecture.

## Invalidation

Do not bind light cache validity to the global `topology_revision`.
MapAppearance currently does so for connected art, but one door would then
force every light chunk to rebuild.

Maintain these presentation-side observations:

- last seen `world.chunk_revision[]`;
- an opacity signature per changed source chunk;
- a semantic light-source signature per changed source chunk;
- last seen `power_revision` plus each known source's active bit;
- last seen `gas_revision` plus known fire source intensity; and
- source buckets by 16×16 chunk, sorted by stable source ID.

On a local world-chunk revision:

1. rescan its 256 cells in row-major order;
2. compare opacity and source signatures;
3. if a source changed, dirty output chunks intersecting its old and new
   radius;
4. if an occluder changed, dirty the changed area inflated by twice the maximum
   source radius; and
5. ignore unrelated visual changes when both signatures are unchanged.

The twice-radius rule is important. An occluder can be one radius away from a
source while the affected target is another radius beyond that source.

When `power_revision` changes, scan only the known semantic light sources and
compare active bits. A stable electrical network increments the revision once
per simulated second but should produce no light rebuild or texture upload.
An actual source transition dirties only its radius.

When a new fire is created, the breach's local chunk revision discovers it.
Once known, `gas_revision` can compare those fire indices without scanning the
whole world. Any future system that creates fire without touching its tile
must be corrected at that authoritative mutation point.

For every dirty output chunk, recompute its cells from ambient plus sources in
the spatial buckets intersecting the maximum radius. Occlusion reads current
world structure directly. After all dirty chunks are complete, one full small
texture upload is acceptable. Initial construction dirties every chunk.

Suggested counters are `active_sources`, `dirty_light_chunks`,
`rebuilt_light_chunks`, `field_uploads`, `shader_path`, and
`light_compute_ms`; expose them only in renderer diagnostics.

## Exact renderer integration

In `Renderer.new`:

1. create the reusable white image before the returned table;
2. construct the lighting presentation object with `world`, `content`, and
   any reusable primitive resource;
3. remove `light_image` and `light_batch` ownership after the new path lands.

In `Renderer:draw`, retain the current map bounds for authored sprite
overscan, but let the lighting object use its world-wide source buckets rather
than the visible source scan. The painter order should become:

```text
native/fallback static world
diagnostic world overlays
machines
crew and other shadowed dynamic atoms
RGB light-field multiply pass
small additive fixture/fire emissives
foreground fire sprites
selection and hover cursor
camera finish
UI
```

This keeps crew and machines dark in an unlit room while fixture lamps, fire,
and the interaction cursor remain legible. The current
`_draw_light_glows` should become a bounded emissive-bloom pass or be removed;
it must no longer be the lighting model.

On load, `App` already constructs a new Renderer for the loaded world, which
naturally rebuilds the presentation-only field. Resize and camera movement
need no field invalidation because the texture is world-aligned.

## Portable fallback ladder

1. **Normal:** CPU RGB field, minimal LÖVE 1 shader, linear light texture,
   multiply-premultiplied composition.
2. **No custom shader:** draw the same filtered RGB `Image` directly with
   multiply-premultiplied blending. The default image shader already samples
   it.
3. **Emergency/low:** if shader or RGB multiply setup fails, use a one-pixel
   white SpriteBatch colored black with per-tile alpha
   `1 - luminance`. Ordinary alpha blending then gives an achromatic darkness
   field; small additive emitter bloom may remain.
4. **Off/accessibility:** skip scene darkness and retain emissive state cues.

Shader creation failure must be nonfatal and reported once. The chosen normal
shader uses no optional GLSL3 feature. Canvas support is irrelevant to all
four mandatory outcomes.

## Tests required before acceptance

### Pure field fixtures

- powered, installed, unbroken, on light emits; each gate independently
  disables it;
- absent interaction state uses the documented default;
- two native appearance records on one semantic light cell emit once;
- wall and closed door tiles receive light and block the tile behind;
- opening the same door exposes the tile behind;
- windows and grilles transmit;
- two touching blockers prevent diagonal leakage;
- rotations/reflections of one room produce rotated/reflected integer fields;
- source insertion order does not change bytes;
- RGB sums and saturation match exact integer expectations;
- radius boundary and falloff table are exact;
- space and station ambient differ as specified; and
- save/load derives byte-identical fields from the same snapshot.

### Invalidation fixtures

- a light at a chunk edge dirties the neighboring output chunk;
- a changed occluder dirties the full twice-radius dependency region;
- a distant door leaves unrelated light chunks valid;
- an unchanged `power_revision` transition performs zero recomputes/uploads;
- a real area power loss dirties only affected-source regions;
- fixture toggle/remove/replace invalidates through local chunk state;
- fire intensity follows `gas_revision`; and
- camera pan, zoom, and resize perform zero CPU field rebuilds.

### LÖVE/runtime fixtures

- validate and compile the shader under the normal desktop path and
  `LOVE_GRAPHICS_USE_OPENGLES=1`;
- force shader construction failure and verify the direct-image fallback;
- assert no full-map Canvas is created;
- sample a 2×2 synthetic RGB field at tile centers and boundaries to lock UV
  orientation, clamp behavior, and linear interpolation;
- capture the same room at 0.25×, 0.5×, 1×, 2×, and 4×;
- pan by sub-tile amounts and verify light/art alignment;
- verify multiply uses `premultiplied`, and shader/blend/color are restored;
- verify atlas filters remain nearest after the light image becomes linear;
- compare light on/off, closed/open door, power loss, wall breach, and fire
  goldens; and
- ensure the self-test path succeeds on the non-shader fallback.

### Performance checks

Record, rather than hard-fail on host wall-clock variance:

- Atlas initial field build with 353 semantic sources;
- stable one-second power revisions with no active change;
- one door open/close storm at a chunk edge;
- whole-station outage and restore;
- several simultaneous fires; and
- full-map 0.25× composition.

The stable-power case must do no field rebuild and no texture upload. Normal
rendering adds one full-world light draw plus the bounded emissive batch.
The maximum texture upload is 256 KiB, and only occurs after field changes.

## Mod and public-contract note

The engine should expose validated data, not arbitrary shader injection, for
day-one lighting:

```text
profile ID
radius_tiles
RGB fixed-point color
integer intensity
named falloff
occlusion class
emissive sprite/appearance ID
```

The generic semantic light profile must be available to every pack. Goon
fixture-family tuning belongs in first-party pack data, not string checks in
`src/presentation/lighting.lua`. Adding a new public profile field requires
scenario/content validation, fixture tests, and the corresponding technical
contract update.

## Sources

- Local renderer:
  [`src/presentation/renderer.lua`](../../src/presentation/renderer.lua)
- Camera and shared transform:
  [`src/presentation/camera.lua`](../../src/presentation/camera.lua)
- World revisions and power:
  [`src/core/world.lua`](../../src/core/world.lua)
- Current fixture state:
  [`src/core/interactions/fixtures/light.lua`](../../src/core/interactions/fixtures/light.lua)
- Graphics contract:
  [`docs/technical/04-rendering-and-graphics.md`](../technical/04-rendering-and-graphics.md)
- Goon interaction fidelity ledger:
  [`docs/technical/10-goon-world-interaction-fidelity.md`](../technical/10-goon-world-interaction-fidelity.md)
- LÖVE blend mode:
  <https://love2d.org/wiki/love.graphics.setBlendMode>
- LÖVE blend equations:
  <https://love2d.org/wiki/BlendMode_Formulas>
- LÖVE Shader:
  <https://love2d.org/wiki/Shader>
- LÖVE `setShader` effect signature:
  <https://love2d.org/wiki/love.graphics.setShader>
- LÖVE `Image:replacePixels`:
  <https://love2d.org/wiki/%28Image%29%3AreplacePixels>
- GLES shader validation:
  <https://love2d.org/wiki/GLES_Shader_Testing_in_Desktop>

## Handoff

No production or test code was changed by this review. The selected
CPU-visibility/GPU-composition split is recommended, subject to the explicit
non-shader fallback, power/source diffing, twice-radius occluder invalidation,
and zoom/filter golden tests above.

## Implementation-review addendum

### Review scope and verified behavior

The implementation was reviewed after `light_field.lua`, `light_sources.lua`,
`lighting_content.lua`, `lighting.lua`, renderer integration, content data,
Lua fixtures, and the LÖVE self-test landed in the shared worktree.
No production code was edited by this review.

Verified:

- the normal shader compiles and the self-test passes on the installed desktop
  LÖVE 11.5 renderer;
- the same self-test passes with
  `LOVE_GRAPHICS_USE_OPENGLES=1`;
- the normal draw uses one 192×192 RGBA8 image, no Canvas, world-space
  `32,32` scale, `multiply` plus `premultiplied`, and restores shader, blend,
  and color state;
- a nil shader naturally selects LÖVE's default-image shader, so the runtime
  direct-image fallback is structurally valid;
- the light texture alone uses linear filtering while atlas defaults remain
  nearest;
- fixture/APC/fire collection is stable-sorted and capped before the bloom
  SpriteBatch is filled;
- wall, closed-door, transparent-window, and closed-diagonal fixtures pass;
- a stable `power_revision` produces no field rebuild or texture upload; and
- Atlas self-test output reported 270 active emitters and an initial field
  build of approximately 2.9 ms on this host.

Commands:

```text
xvfb-run -a love . --self-test
LOVE_GRAPHICS_USE_OPENGLES=1 xvfb-run -a love . --self-test
```

### Actionable findings

#### High: tile ambient changes do not invalidate the field

`fill_ambient` branches on `world.tile[index]`, but `Lighting:update` retains a
field when the emitter signature and `LightField.opacity_signature` match.
The opacity signature covers only walls and closed doors.

A focused mock-LÖVE reproduction built an all-space field, changed one tile to
`FLOOR`, called `world:touch`, and updated lighting on the same tick. Update
returned `false`, and the changed tile retained the space channel value
`1024` instead of station ambient `0`.

Add tile/ambient classification to the transmission signature and test both
space→floor and floor→space transitions.

#### High: same-tick APC changes can remain stale while paused

The fast early-out compares tick, chunk revisions, `power_revision`, and
`gas_revision`. It does not compare machine state. APC handlers mutate
`machine.data.lighting`, `operating`, `shorted`, and related state without
necessarily changing any of those observations.

A focused reproduction built one powered fixture controlled by one APC,
changed `data.lighting` from `3` to `1` without advancing the tick, and called
update again. Update returned `false` and retained the old emitter. Since
commands are allowed while paused, this can persist indefinitely.

Include a stable machine lighting/service signature in the early-out, or add a
dedicated authoritative machine presentation revision. Cover a paused
`apc.set-channel`, operating toggle, and shorted-wire transition.

#### Medium: fire foreground is drawn before darkness

Renderer order currently is:

```text
crew → foreground fire → light multiply → bloom → cursor
```

The public rendering document says the visible flame remains after darkness.
Move the fire foreground pass after the multiply pass. Its bloom may remain
before or after the flame as long as both are post-lighting and the cursor
remains last.

#### Medium: valid source offsets are not honored by bounds or occlusion

Bindings accept fixed-point offsets from `-4096` through `4096`.
`LightSources.collect` applies them to `x_256/y_256`, but `add_emitter` centers
its candidate rectangle and line-of-sight origin on the unshifted
`tile_x/tile_y`. An offset which crosses a tile can therefore omit cells
inside the true radius and cast occlusion from the wrong origin.

Bloom culling has the same issue and additionally uses a fixed two-tile
margin even though valid bloom radii reach 16 tiles.

Derive the emission-origin tile and candidate bounds from `x_256/y_256`, or
restrict offsets to remain within the source tile. Cull bloom using the
shifted fixed-point center plus its configured radius. Add positive,
negative, fractional, and cross-chunk offset fixtures.

#### Medium: validated aggregate work can stall low-end hardware

The individual limits permit 4,096 emitters at radius 32. That is roughly
17 million candidate cells before supercover traversal, and worst-case
line-of-sight work reaches hundreds of millions of tile steps in one rebuild.
Multiple source-path bindings can also rescan all 43,813 Atlas appearances
each observed tick before emitter truncation.

Add an aggregate candidate/LOS budget based on priority and stable ID. Reject
or deterministically truncate data that exceeds it. Pre-index scenario
source-path selectors once per renderer rather than once per update.

#### Low/medium: stable ticks still rescan the full world

Tick is part of the initial early-out, so every changed simulation tick
rescans the fixture provider, the fire provider, and the full opacity
signature even when chunk, power, gas, and machine lighting state did not
change. At 4× speed this is up to 40 full observations per second.

Use tick only when an active profile reaches a new flicker phase. Recompute
opacity only when relevant chunk revisions changed. Pre-index fixture cells
and update their index from changed chunks.

#### Low/medium: self-test requires the optional shader path

`compile_shader` correctly catches compilation failure and the draw path works
with `shader == nil`, but `tests/love_selftest.lua` asserts that the shader
exists. Consequently, a platform intended to use the documented fallback
fails the release self-test, and the fallback itself is never exercised.

Keep normal desktop/GLES shader compilation as a named capability test, but
also force `shader = nil` and verify direct-image draw, multiply mode, state
restoration, UV orientation, and no Canvas allocation. The product self-test
should accept the documented fallback tier.

### Acceptance disposition

The basic LÖVE 11.5 composition is correct and both tested shader backends
pass. The ambient and same-tick APC invalidation defects should be fixed before
the feature is called dynamically correct. Fire ordering and offset handling
should be fixed before visual/mod-contract acceptance. Aggregate work
budgeting is required before treating the current schema maxima as safe for
untrusted or broadly distributed mods.
