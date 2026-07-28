# Pixel ratio and viewport audit agent

## Record

- Canonical task: `/root/pixel_viewport_audit`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: audit completed; parent implementation reviewed and
  targeted validation passed
- Report availability: observable work record
- Assignment availability: verbatim

### User request

> make sure to match the pixel ratio and viewport

### Assignment

> Audit Sim Station's LÖVE camera/window/renderer for exact Goon 32x32 pixel
> ratio, DPI scaling, resizable viewport, integer zoom, letterboxing, scissor,
> and mouse coordinate correctness. Propose/implement focused tests or docs
> only; avoid editing src/presentation/camera.lua, renderer.lua, app.lua,
> main.lua, or conf.lua because root will implement production changes. Archive
> full work/state/conversation in docs/agents/pixel-viewport-audit.md and update
> docs/agents README + manifest. Report concrete findings and validation.

### Observable chronology

1. The agent inspected `conf.lua`, `main.lua`, the camera, app, renderer, UI,
   pure-Lua tests, LÖVE self-test, graphics catalog, and rendering/UI design
   contracts.
2. The pinned Goonstation Git object was queried without altering its sparse
   checkout. It establishes a default 15×15 view, 21×15 widescreen view, and
   32px icon-size option.
3. The generated foundation catalog was checked. All 29 selected tile, object,
   machine, and crew aliases use exact 32×32 source cells.
4. Official LÖVE documentation was checked for LÖVE 11 high-DPI coordinate
   units and scissor behavior.
5. The pre-change camera was reproduced with a pure-Lua fixture. A rendered
   world coordinate inverted with a 0.8-world-pixel error because draw code
   floored the camera while pointer conversion used its unsnapped value.
6. Findings and a concrete viewport/transform recommendation were sent to the
   parent while implementation was in progress.
7. The parent implemented an explicit 7:5 world viewport, whole-cell
   letterboxing, scissoring, discrete zoom, shared snapped draw/input
   coordinates, half-open pointer bounds, and explicit automatic DPI units.
8. The agent reviewed the live implementation. Default and minimum window
   fixtures match 28×20 and 21×15 cells respectively at native zoom.
9. A pure-Lua cross-product check covered five zoom levels, nine viewport
   combinations, and three fractional camera positions. Every effective
   transform origin was integral and every tested draw/inverse pair
   round-tripped exactly.
10. `python3 tools/dev.py test` passed 25 Lua tests and 17 Python tests,
    including the new camera contract test.
11. A terminology correction was sent to the parent: with
    `usedpiscale = true`, the transform is guaranteed to snap in DPI-scaled
    screen units. Physical backing-pixel alignment additionally depends on the
    platform DPI scale being integral.
12. `python3 tools/dev.py audit` passed after the parent added explicit
    960×540 and 1280×720 viewport assertions and corrected the camera comment.

## Visible report and findings

### Upstream reference

The pinned commit is
`1b2b250abb5be747d55e274de0203a59cfc8da78`.

| Evidence | Pinned value | Sim Station disposition |
| --- | ---: | --- |
| `/world/view` | `15x15` | Retained as the square-view reference |
| `WIDE_TILE_WIDTH` | `21` | Retained as the native wide reference |
| `SQUARE_TILE_WIDTH` | `15` | Retained as the native view height |
| Icon-size menu | Includes `32x32` | Native tile size remains 32×32 |
| Foundation media | 29 of 29 cells are 32×32 | No axis distortion required |

The 21×15 widescreen grid is 672×480 at one 32px source cell per tile and has a
7:5 aspect ratio. Goon's BYOND skin also exposes stretch and explicit icon-size
controls. Sim Station adapts that behavior for a resizable desktop simulation:
it preserves square cells and the 7:5 map-view ratio instead of reproducing a
client-side stretch mode.

The implemented block is seven by five cells. The minimum supported window
fits three blocks, exactly reproducing 21×15. Larger windows fit additional
whole blocks without resampling a partial tile:

| Window | Usable area below 48px bar | World viewport | Native cells |
| --- | --- | --- | --- |
| 960×540 | 960×492 | 672×480 at (144, 54) | 21×15 |
| 1280×720 | 1280×672 | 896×640 at (192, 64) | 28×20 |
| 1920×1080 | 1920×1032 | 1344×960 at (288, 84) | 42×30 |

This is a Sim Station viewport policy, not a claim that every Goon client
window has those dimensions.

### Coordinate-space contract

Three distinct spaces must not be mixed:

1. **World/source pixels.** A tile occupies a half-open 32×32 square.
2. **DPI-scaled screen units.** LÖVE 11.5 drawing, resize events, mouse events,
   and `love.mouse.getPosition` share these units when automatic DPI scaling is
   enabled.
3. **Backing pixels.** LÖVE maps screen units through the current display DPI
   scale.

The accepted policy keeps `highdpi = true` and explicitly sets
`usedpiscale = true`. Camera, viewport, UI, and pointer input therefore remain
in one screen coordinate system; app code must not apply an extra
`toPixels`/`fromPixels` conversion.

At native zoom, one source pixel maps to one DPI-scaled screen unit. On a
2× Retina backing surface that intentionally becomes a crisp 2×2 backing-pixel
block. A fractional backing DPI scale may use nonuniform nearest-neighbor
replication; exact one-source-pixel-to-one-backing-pixel output would require a
separate physical-pixel mode and would make UI and map content physically
smaller on high-DPI displays.

### Shared draw/input transform

For viewport origin `(vx, vy)`, integer viewport center `(cx, cy)`, camera
center `(camera_x, camera_y)`, and zoom `z`, the implementation uses a snapped
render position:

```text
render_x = round(camera_x × z) / z
render_y = round(camera_y × z) / z
screen_x = cx + (world_x - render_x) × z
screen_y = cy + (world_y - render_y) × z
world_x  = (screen_x - cx) / z + render_x
world_y  = (screen_y - cy) / z + render_y
```

Because `cx`, `cy`, `render_x × z`, and `render_y × z` are integers, the
effective world origin is an integer DPI-scaled screen unit. Draw, culling,
hover, selection, drag, blueprint placement, and cursor-centered zoom must all
derive from this same transform.

Pointer bounds are half-open:

```text
vx <= x < vx + width
vy <= y < vy + height
```

Letterbox input therefore cannot select a world tile. Middle-drag and wheel
zoom also begin only inside the world viewport.

### Pre-implementation defects

| Area | Observed behavior | Risk |
| --- | --- | --- |
| Viewport | Camera covered the whole window while UI overlaid its top 48px | World pixels and input existed behind UI |
| Letterbox/scissor | No explicit map rectangle or scissor | World pass was not bounded to a stable aspect |
| Camera snap | Draw used `floor(camera)`; inverse used raw camera | Hover/click could disagree at a tile edge |
| Odd dimensions | Center used a fractional half-unit | Integral zoom could land on half screen units |
| Zoom API | Setter accepted any value | Callers could bypass discrete pixel-art levels |
| Pointer bounds | Screen-to-tile did not know a map viewport | Side/top bars could be interpreted as world |
| DPI policy | `highdpi` was set, `usedpiscale` remained implicit | Coordinate policy depended on a default |

The reproduced inverse mismatch was:

```text
camera.x = 100.8
rendered camera x = 100
rendered world x = 32
inverse result = 32.8
```

### Post-implementation review

The following invariants were observed in the parent's implementation:

- `Constants.TILE_SIZE == 32`;
- one uniform X/Y scale is used, so cells remain square;
- normal viewports are exact multiples of 32 and exact 7:5 rectangles;
- 960×540 produces the upstream-reference 21×15 footprint;
- 1280×720 produces a larger whole-cell 28×20 footprint;
- world drawing is clipped with a scissor and the scissor is cleared before UI;
- the full window is cleared before scissoring, leaving deterministic bars;
- zoom is selected from `0.25, 0.5, 1, 2, 4`;
- 1×, 2×, and 4× are integer nearest-neighbor scales;
- 0.25× and 0.5× are documented minification/overview levels;
- draw and input use the same snapped render position;
- resize recomputes the viewport and reclamps the camera;
- mouse, wheel, and drag reject points outside the half-open viewport.

One wording caveat remains important: snapping to a whole DPI-scaled screen
unit is not universally the same as snapping to a physical backing pixel. The
implementation is exact for DPI 1 and produces integer replication at common
integral high-DPI scales such as 2.

### Targeted validation

The direct viewport calculation produced:

```text
1280x720  -> x=192 y=64 w=896  h=640  ratio=1.4
960x540   -> x=144 y=54 w=672  h=480  ratio=1.4
961x541   -> x=144 y=54 w=672  h=480  ratio=1.4
1920x1080 -> x=288 y=84 w=1344 h=960  ratio=1.4
1024x768  -> x=64  y=88 w=896  h=640  ratio=1.4
800x600   -> x=64  y=84 w=672  h=480  ratio=1.4
```

For every normal case, width is divisible by 224, height is divisible by 160,
and both are divisible by 32.

The draw/inverse property fixture covered:

```text
zoom:      0.25, 0.5, 1, 2, 4
viewports: 9 width/height combinations
cameras:   3 fractional positions
points:    world origin, tile boundary, and fractional world point
result:    0 alignment or inverse failures
```

The project test result was:

```text
python3 tools/dev.py test
Lua:    25 tests, 0 failures
Python: 17 tests, 0 failures

python3 tools/dev.py audit
result: audit passed
```

### Recommended permanent assertions

The pure-Lua suite should keep these presentation-contract fixtures:

- 960×540 resolves to a 672×480, 21×15 viewport;
- 1280×720 resolves to an 896×640, 28×20 viewport;
- every normal viewport satisfies `width * 5 == height * 7`;
- viewport dimensions are multiples of 32;
- each supported zoom produces an integral effective transform origin;
- world-to-screen-to-world round-trips through the snapped transform;
- left/top edges are included and right/bottom edges are excluded;
- points in every letterbox bar yield no tile;
- cursor-centered zoom keeps the cursor world point within the documented snap
  tolerance;
- resize retains the world center unless clamping is required;
- LÖVE smoke coverage verifies that the world scissor is cleared before UI.

Golden-image coverage should include odd window dimensions, DPI 1 and 2 where
CI runners permit them, native 1×, integer 2×/4×, both overview zooms, and a
cursor exactly on each viewport edge.

## Observable coordination

### Initial parent handoff

The agent sent this implementation summary to the parent:

> Pixel/viewport audit findings: pinned Goon source explicitly uses 32px icons
> and `/world view = "15x15"`; its normal widescreen client sets `21x15`
> (`_std/defines/client.dm`: WIDE_TILE_WIDTH=21, SQUARE_TILE_WIDTH=15), so the
> upstream native map viewport reference is 672x480 at 32px/tile (7:5).
> Current Sim Station has TILE_SIZE=32 and every 29 foundation alias now
> resolves to an exact 32x32 cell. Current presentation has no map viewport
> rect/scissor/letterbox (camera covers whole window while 48px UI overlays
> it), and render/input transforms disagree because Camera.apply floors x/y
> but screen_to_world uses unsnapped x/y. Odd viewport dimensions also create
> half-pixel offsets at integral zoom. Recommend a dedicated viewport
> `{x,y,w,h}` snapped to whole screen units, 21x15 minimum/reference aspect if
> matching Goon, black letterbox remainder, scissor during world pass, and one
> shared reversible snapped transform for draw/culling/mouse. Keep highdpi=true
> + usedpiscale=true (LÖVE 11.5 graphics/mouse/resize all use matching
> DPI-scaled units); define 1x as 32 logical units and accept integer
> backing-pixel replication at DPI scale. Enforce zoom set
> {.25,.5,1,2,3,4} or existing {.25,.5,1,2,4}, with exact integral mapping at
> >=1. I’m writing full audit/archive and proposed test matrix now.

### Post-implementation review

The agent sent this validation and terminology note:

> Reviewed the landed viewport implementation: default 1280x720 resolves to
> x=192,y=64,w=896,h=640 (28x20 cells); minimum 960x540 resolves to
> x=144,y=54,w=672,h=480 (exact upstream 21x15). All normal viewport sizes are
> exact 7:5 and 32-unit multiples, draw/inverse transforms share the same
> snapped render position, half-open viewport rejection is correct, and a
> cross-product property check over 5 zooms/9 viewport sizes/3 camera positions
> had 0 failures. One wording nit: Camera.render_position currently says
> “display-pixel/physical pixel”; with usedpiscale=true it strictly snaps to
> integer DPI-scaled screen units. On normal DPI=1 and integral Retina DPI this
> is physical-pixel aligned, but fractional DPI isn’t guaranteed. Recommend
> wording “DPI-scaled screen-unit space” / “integer backing-pixel replication
> where DPI scale is integral” to keep the contract honest. Also worth adding
> Ui.world_viewport assertions (1280→896x640; 960→672x480;
> `w*5==h*7`, dimensions divisible by 32) to the Lua test.

## Decision disposition

### Accepted

- Preserve exact square 32×32 foundation cells.
- Use 21×15/672×480 as the minimum native widescreen reference.
- Expand larger windows in whole seven-by-five-cell blocks.
- Keep a 7:5 map viewport, deterministic letterbox bars, and world scissor.
- Use one snapped transform for rendering, culling, and pointer conversion.
- Keep explicit automatic DPI-scaled units and nearest-neighbor filtering.
- Keep discrete overview and integer zoom levels.

### Adapted

- Sim Station exposes more whole cells on larger windows rather than freezing
  every session to Goon's 21×15 footprint.
- Native scale is defined in logical screen units. Common integral-DPI displays
  replicate source pixels cleanly in the backing buffer.
- Goon's client stretch/icon-size controls are not reproduced; preserving
  square, undistorted source cells is the stronger art-fidelity contract.

### Rejected

- Independently stretching X and Y to fill an arbitrary window.
- Letting map rendering continue under the top UI or letterbox bars.
- Applying a second DPI conversion to mouse coordinates.
- Using one camera position for drawing and another for hit testing.
- Treating fractional overview zoom as lossless one-to-one pixel output.

### Unresolved

- Golden screenshots at DPI 2 are still desirable when CI can provide a
  deterministic high-DPI surface.
- A dedicated physical-pixel 1× mode could be offered later, but should not
  silently replace DPI-aware logical native scale.
- The tiny-window fallback preserves 7:5 approximately because the configured
  desktop minimum cannot fit; mobile/windowless ports should decide whether to
  hide UI, lower its scale, or use a different layout before relying on it.

## Files and ownership

This agent added or updated only:

- `docs/agents/pixel-viewport-audit.md`
- `docs/agents/README.md`
- `docs/agents/manifest.json`

The parent owned all production presentation, window configuration, public
technical documentation, and executable-test edits.

## Sources

- Pinned Goonstation
  [`code/world/world.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/world/world.dm).
- Pinned Goonstation
  [`_std/defines/client.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/defines/client.dm).
- Pinned Goonstation
  [`code/client.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/client.dm).
- Pinned Goonstation
  [`interface/skin.dmf`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/interface/skin.dmf).
- LÖVE
  [`love.graphics.getDPIScale`](https://love2d.org/wiki/love.graphics.getDPIScale).
- LÖVE
  [`conf.lua`](https://love2d.org/wiki/conf.lua).
- LÖVE
  [`love.graphics.setScissor`](https://love2d.org/wiki/love.graphics.setScissor).
- Generated `assets/runtime/goon/graphics/foundation.json`.
- Sim Station camera, renderer, UI, app, configuration, and tests as observed
  on 2026-07-28.
