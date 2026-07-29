# Goonstation dynamic-lighting research

## Record

- Canonical task: `/root/goon_lighting_research`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: pinned-source research and implementation handoff
  completed; no production code changed
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> Research pinned Goonstation dynamic lighting using local
> assets/cache/goonstation git at commit 1b2b250... and existing
> docs/screenshots. Identify authoritative light emitters, colors/ranges/power
> behavior, occlusion rules, darkness/space ambient behavior, emergency/fire
> behavior, and relevant source paths/lines. Do not edit production code. Save
> a full handoff/conversation/state archive under
> docs/agents/goon-lighting-research.md and update docs/agents
> README/manifest. Send concise implementation recommendations to /root.

### Follow-up

> Please wrap the upstream findings now with concrete v1 defaults (ambient,
> radius/color/falloff, blockers, emergency behavior) and archive your report.
> Send me the key implementation recommendations immediately when ready.

## Observable chronology

1. Confirmed that the sparse Goonstation checkout is pinned to exact commit
   `1b2b250abb5be747d55e274de0203a59cfc8da78`. The checked-out worktree
   contains assets and Atlas, while source blobs remain available through the
   pinned Git tree.
2. Read the robust-light implementation, lighting defines, simple-light
   implementation, lighting planes, turf initialization, and update queue from
   pinned Git blobs.
3. Read fixture, lamp, switch, APC-area, ship-alert, fire-alarm, fire-hotspot,
   and space-starlight behavior from the same commit.
4. Counted the compiled Atlas crop and the original DMM. Atlas contains 354
   light fixtures on 353 cells, 57 light switches, and 40 fire alarms. It has
   no `/obj/machinery/light/emergency` placement.
5. Audited DMM-only fixture overrides. Twenty placed fixtures override
   `light_type`; those colors are not retained in the current scenario
   appearance records. Two green desk lamps override `switchon`.
6. Compared upstream behavior to the current Sim Station world, interaction,
   APC, map-appearance, and renderer contracts. The existing renderer adds a
   very faint 65×65 glow but does not construct or multiply by a darkness
   field.
7. Sent the parent a concise source-fidelity recommendation and archived the
   full evidence and handoff here. No production Lua, generated asset, DMM, or
   scenario file was edited by this task.

## Executive findings

Goonstation does not render ordinary station interiors with a soft global
ambient wash. A non-fullbright turf begins with RGB luminance `(0, 0, 0)`,
and the lighting plane multiplies the rendered world. The darkness lower
limit is exactly zero in the ordinary build, so an unlit interior can be pitch
black.

The primary station model is:

```text
powered fixture state
  -> bounded point-light contribution
  -> line-of-sight visibility against opacity
  -> per-turf RGB accumulation
  -> four neighbouring turf samples shape each 32x32 lighting overlay
  -> multiplicative lighting plane
  -> capped additive highlight for accumulated values above 1
```

Goon also has a separate, cheaper simple-light system. It uses authored 96×96
additive sprites for transient and moving emitters such as fires, projectiles,
equipment, and vehicle headlights. That distinction is useful for Sim
Station: stationary infrastructure should use a cached tile light field,
while fire and moving effects can use exact compiled simple-light sprites.

## Authoritative robust-light model

### State and update model

`/datum/light` stores position, direction, normalized RGB, brightness, height,
enabled state, a derived radius, and an optional attached atom. Setters strip
the previous contribution, update the light, apply the new contribution, and
refresh affected overlays. Changes can enter a queue processed every 0.1
seconds.

Relevant source:

- [`code/_lighting/RobustLight2.dm` lines 45–277](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/RobustLight2.dm#L45-L277)
- [`code/datums/controllers/process/lighting.dm` lines 1–79](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/controllers/process/lighting.dm#L1-L79)

The source constants are:

```text
quadratic scale       2.2
constant offset      -0.11
visibility threshold  2/256
radius quadratic      0.9
radius constant        0.03
maximum radius         6 tiles
darkness lower limit   0
```

They are defined in
[`_std/defines/lighting.dm` lines 31–96](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/defines/lighting.dm#L31-L96).

For squared planar distance `d2`, height `h`, and brightness `B`, the
attenuation test is:

```text
A = B * 2.2 / (d2 + h*h) - 0.11
discard if A < 2/256
```

The implementation premultiplies source color by brightness before applying
that attenuation. The effective contribution to one channel is therefore:

```text
channel contribution = source_channel * B * A
```

The derived point-light radius is:

```text
radius = min(
  round(sqrt(max(B * (2.2 - 0.9) / (0.11 + 0.03) - h*h, 0))),
  6
)
```

This radius is a hard candidate bound in addition to the attenuation
threshold.

### Accumulation and composition

Every non-fullbright turf owns robust RGB accumulation values initialized to
zero. The ordinary lighting plane is a multiply plane. Each tile overlay is
colored from the accumulated values on that tile plus its east, north, and
northeast neighbours. The authored lighting-overlay sprite turns those four
samples into a smooth per-pixel result.

When a channel rises over 1, Goon also derives:

```text
additive = clamp((luminance - 1) * 0.5, 0, 0.3)
```

That extra value renders on the additive self-illumination plane. This keeps
overlapping bright sources from flattening completely at white.

Relevant source:

- [`_std/defines/lighting.dm` lines 3–28](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/defines/lighting.dm#L3-L28)
- [`code/_lighting/RobustLight2.dm` lines 595–755](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/RobustLight2.dm#L595-L755)
- [`_std/plane.dm` lines 1–20 and 91–119](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/plane.dm#L1-L20)

The pinned graphics already imported by Sim Station include:

```text
icons/effects/lighting_overlays/floors.dmi
icons/effects/lighting_overlays/walls_supernorn.dmi
icons/effects/lighting_overlays/walls_jen.dmi
icons/effects/overlays/simplelight.dmi
```

The corresponding runtime catalog includes the exact `3x3`, `medium_center`,
`medium_dir`, `simp`, and `starlight` states.

## Occlusion rules

Point lights enumerate visible turfs within their radius using BYOND `view`,
then reject a destination if either:

```text
turf.opacity is true
turf.opaque_atom_count > 0
```

The second pass expands neighbouring samples needed by the four-corner tile
overlay. This can give an opaque surface an edge sample without allowing the
light to propagate through it. Wall families select specialized authored
lighting-overlay masks based on their connected state.

Relevant source:

- [`code/_lighting/RobustLight2.dm` lines 355–416](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/RobustLight2.dm#L355-L416)
- [`code/turf/turf_autoalign.dm` lines 7–81](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/turf_autoalign.dm#L7-L81)

Opacity is dynamic. When an opaque atom appears, disappears, opens, closes, or
moves, nearby enabled lights are stripped and reapplied within the maximum
six-tile radius. Closed base doors default to `opacity = 1`; an opened door
clears it.

- [`code/atom.dm` lines 1134–1192](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/atom.dm#L1134-L1192)
- [`code/obj/machinery/door/door_parent.dm` lines 3–24](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/door/door_parent.dm#L3-L24)

The practical Sim Station blocker contract is:

| World feature | Blocks robust light? | Notes |
| --- | --- | --- |
| standard/reinforced wall | yes | surface may receive a lit edge |
| closed opaque door/airlock | yes | opening must invalidate lighting |
| open door/airlock | no | density and opacity both clear upstream |
| ordinary window | no | transparent even when movement/gas blocking |
| grille | no | transparent and gas-permeable |
| table, chair, machine, pipe | no | not opaque by default |
| space | no | fullbright turf with separate starlight |

For a small, portable v1, symmetric shadowcasting or stable Bresenham tests
within radius 6 are sufficiently bounded. A blocker should receive the final
ray sample but stop propagation beyond itself; this approximates Goon's
special wall-mask/edge-sample result better than leaving every wall tile
completely black.

## Fixture emitters and concrete v1 defaults

The ordinary light fixture creates a point light, assigns brightness and lamp
color, sets height to 2.4, attaches it to the fixture, and enables or disables
it with fixture state:

- [`code/modules/power/lighting.dm` lines 176–229](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L176-L229)
- [`code/modules/power/lighting.dm` lines 900–965](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L900-L965)

Recommended source-faithful profiles are:

| Fixture/profile | Brightness | Height | Derived radius | RGB |
| --- | ---: | ---: | ---: | --- |
| standard tube | 1.6 | 2.4 | 3 | `(0.95, 0.95, 1.00)` |
| standard small/floor bulb | 1.2 | 2.4 | 2 | `(1.00, 1.00, 0.90)` |
| floor lamp | 1.4 | 2.4 | 3 | bulb-dependent |
| ordinary desk lamp | 1.0 | 2.4 | 2 | `(1.00, 1.00, 0.90)` |
| green desk lamp | 1.0 | 2.4 | 2 | `(0.45, 0.85, 0.25)` |
| emergency bulb | 1.0 | 2.4 | 2 | `(1.00, 0.20, 0.20)` |
| emergency exit/warning | 1.3 | 2.4 | 3 | `(1.00, 0.20, 0.20)` |
| runway/traffic light | 0.5 | 2.4 | 0 | bulb-dependent |
| portable beacon | 1.5 | 2.4 | 3 | `(1.00, 1.00, 1.00)` |
| worn fixture | 1.0 | 2.4 | 2 | lamp-dependent |
| light-switch indicator | 0.3 | 1.0 | 1 | green `(0.5,1,0.5)` or red `(1,0.5,0.5)` |

The radius-zero runway case still lights its own tile because source
attenuation remains above the threshold.

Common authored lamp colors, suitable as fixed-point mod data, are:

| Lamp | RGB |
| --- | --- |
| tube default | `(0.95, 0.95, 1.00)` |
| bulb default | `(1.00, 1.00, 0.90)` |
| warm | `(1.00, 0.844, 0.81)` |
| very warm | `(1.00, 0.67, 0.67)` |
| neutral | `(0.95, 0.98, 0.97)` |
| greenish | `(0.87, 0.98, 0.89)` |
| blueish | `(0.51, 0.66, 0.85)` |
| purpleish | `(0.42, 0.20, 0.58)` |
| cool | `(0.88, 0.904, 1.00)` |
| very cool | `(0.74, 0.74, 1.00)` |
| harsh | `(0.99, 0.899, 0.99)` |
| very harsh | `(0.99, 0.81, 0.99)` |
| emergency | `(1.00, 0.20, 0.20)` |

The complete source color table is under
[`code/modules/power/lighting.dm` lines 1375–1761](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L1375-L1761).

### Atlas census

The pinned 192×192 Atlas crop contains 354 actual light-fixture atoms on 353
cells across 32 fixture paths. Major groups are:

```text
189 /obj/machinery/light
 54 runway lights and delay variants
 30 incandescent fixtures
 24 signal-controlled traffic lights
 21 small floor lights
  8 small neutral bulbs
  7 small sticky fixtures
  7 ordinary small fixtures
  5 green desk lamps
  2 black desk lamps
  2 portable beacons
```

The DMM has twenty placed `light_type` overrides:

```text
12 tube/yellowish
 3 tube/blueish
 2 bulb/yellowish
 2 bulb/green
 1 bulb/blueish
```

Two green desk lamps explicitly set `switchon = 1`. The current compiled map
appearance records preserve type, direction, icon state, offsets, and layer,
but not `light_type` or `switchon`. A source-faithful importer should compile
those values into a validated light-profile reference rather than exposing
arbitrary DM expressions at runtime.

## Power and state behavior

### Normal fixtures

Normal fixtures follow the area's lighting channel and area light switch.
An optional direct wire can power a fixture; otherwise:

```text
active power = area.lightswitch && area.power_light
```

Broken, burned, or empty lamps force the fixture off. Removing/replacing a
lamp changes the physical lamp state and color. A burnout briefly triples
brightness for 0.2 seconds before the light switches off.

- [`code/modules/power/lighting.dm` lines 917–1004](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L917-L1004)
- [`code/modules/power/lighting.dm` lines 1171–1178 and 1325–1365](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L1171-L1178)

The area light manager charges a coarse `40 * fixture_count` units while the
area lighting channel and switch are on. Despite fixtures having individual
brightness, this source manager currently uses a placeholder brightness of 1
for billing.

### Desk lamps, traffic lights, and beacons

- Desk lamps have an independent `switchon` and require area lighting power,
  but ignore the area light switch.
- Traffic lights are dock-signal controlled, require `area.power_light`, and
  ignore the area light switch.
- A portable beacon reports power when anchored; wrenching it loose turns it
  off.

Source:

- [`code/modules/power/lighting.dm` lines 701–812](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L701-L812)

### Emergency behavior

Emergency fixtures invert normal area lighting power:

```text
emergency active = !area.power_light || shipAlertState == SHIP_ALERT_BAD
```

They do not depend on the area light switch. The bulb is frosted red,
brightness 1, color `(1, 0.2, 0.2)`, derived radius 2, and has no normal
burnout probability. Red alert explicitly updates every tracked station
emergency fixture.

- [`code/modules/power/lighting.dm` lines 494–537](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L494-L537)
- [`code/modules/power/lighting.dm` lines 1353–1365](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L1353-L1365)
- [`code/obj/machinery/shipalert.dm` lines 132–180](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/shipalert.dm#L132-L180)

Atlas has no emergency-light placement. A v1 Atlas renderer should therefore
not silently turn ordinary fixtures into red emergency lights. Emergency
fixtures remain a supported mod/scenario contract and should appear when
authored or constructed.

## Ambient darkness and space

`/area` defaults to neither force-fullbright nor ambient light. A force-
fullbright area receives one white overlay and does not construct robust
lighting overlays. An `ambient_light` area receives an additive constant-color
overlay. Ordinary station areas use neither and therefore rely on fixtures.

Source:

- [`code/_lighting/base_lighting.dm` lines 23–61](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/base_lighting.dm#L23-L61)

`/turf/space` is `fullbright = TRUE`. This does **not** mean that space should
be painted white; it means the dark lighting plane does not dim its already
dark star sprite. Each fullbright space turf also carries the colored
96×96 `starlight` additive overlay, offset by -32 pixels, so star light bleeds
roughly one tile onto a station edge.

- [`code/turf/turf.dm` lines 271–332](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/turf.dm#L271-L332)
- [`code/turf/turf.dm` lines 401–428](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/turf.dm#L401-L428)

For Atlas v1:

```text
station ambient RGB = (0, 0, 0)
space sprite         = exempt from station darkness
space edge           = exact compiled starlight sprite, additive
```

A presentation-only accessibility floor may be offered later, but it should
not alter authoritative NPC visibility or the source-fidelity default.

## Fire and alarms

Atmospheric gas fire uses the simple-light path in this pinned build. Its
visual color is derived from blackbody radiation at the hotspot temperature.
It adds a medium light with that RGB and alpha 100. Medium lights use authored
center plus four directional sprites; a directional lobe is hidden when the
immediately adjacent turf is opaque.

- [`code/modules/atmospherics/FEA_fire.dm` lines 1 and 87–147](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/FEA_fire.dm#L1-L147)
- [`code/modules/atmospherics/FEA_fire.dm` lines 340–395](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/FEA_fire.dm#L340-L395)
- [`code/_lighting/SimpleLight.dm` lines 99–227](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/SimpleLight.dm#L99-L227)

Chemical fires add a neutral `(65,65,65,100)` medium light plus a second
color-specific medium light:

```text
red      (50,  0,  0)
dark red (10,  0,  0)
blue     ( 0,  0, 50)
green    ( 0, 50,  0)
yellow   (50, 50,  0)
purple   (50,  0, 50)
black    ( 0,  0,  0)
white    (50, 50, 50)
```

The ordinary fire alarm does not replace room lighting with a global red
wash. A powered alarm panel contributes a small additive `fireon` overlay at
alpha 80. The area alert controls alarms and firelocks, while legacy
area-party-light behavior is effectively absent.

- [`code/obj/machinery/firealarm.dm` lines 33–72](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/firealarm.dm#L33-L72)
- [`code/area.dm` lines 4532–4590](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/area.dm#L4532-L4590)

## Concrete implementation handoff

### V1 fidelity defaults

Use these defaults unless mod/scenario data declares another profile:

```text
interior ambient             RGB 0,0,0
ordinary tube                RGB .95,.95,1; brightness 1.6; height 2.4; radius 3
small/floor bulb             RGB 1,1,.9; brightness 1.2; height 2.4; radius 2
opaque blockers              walls and closed opaque doors
transparent non-blockers     windows, grilles, open doors
maximum point radius         6
emergency bulb               RGB 1,.2,.2; brightness 1; height 2.4; radius 2
emergency activation         no area-light power OR station red alert
space                        darkness-exempt sprite plus additive starlight
fire                         compiled medium simple-light shape; warm/temperature RGB
```

### Simulation/presentation split

The maintainable split is:

1. Core owns serializable emitter profiles, enabled state, fixture/lamp state,
   area lighting power, opacity, and a deterministic tile-level RGB field used
   by NPC visibility.
2. Core uses integers or fixed-point values and stable index-ordered loops.
   The floating source constants should become documented integer lookup
   tables keyed by profile and squared distance.
3. Presentation turns that field into a viewport-sized light mesh/canvas,
   multiplies a world canvas by it, then adds the `>1` highlights and transient
   simple lights.
4. Opening/closing a door, constructing/dismantling a wall, changing fixture
   state, changing area power, or changing fire must increment a lighting
   revision. Static fields are cached until one of those revisions changes.

The 192×192 Atlas map, 354 fixed fixtures, and maximum radius 6 make a full
fixed-light recomputation small: only bounded local candidates are visited.
There is no need for a heavyweight physics or deferred-rendering library.

### LÖVE rendering shape

A portable implementation can:

1. render the world into a nearest-filtered canvas at the existing native
   32-pixel scale;
2. build one mesh quad per visible tile with four RGB corner samples;
3. render that mesh to a lighting canvas;
4. multiply the world canvas by the lighting canvas;
5. draw capped overbright contribution and fire/self-lit overlays additively;
6. leave space pixels out of the station multiply mask and add the compiled
   starlight sprite at boundaries.

This preserves the exact viewport and pixel ratio while doing the expensive
part on the GPU. No CPU per-screen-pixel lighting loop is necessary.

The initial wall approximation should allow a blocking cell to receive the
last ray sample, but never propagate the ray past it. Later fidelity can use
the already-imported `walls_supernorn` masks keyed by connected wall state.

### Mod contract

Light behavior must be pack-owned data rather than a core special case.
Recommended validated fields are:

```text
profile content ID
mode: point | simple | directional
color channels as integers
brightness and height as fixed point
maximum radius
power policy: area-light | independent-area | direct | emergency | signal
blocks/receives policy
simple-light sprite alias where applicable
```

Map palette/appearance data should reference a profile ID. The DMM importer
should compile safe known variables such as `light_type`, `switchon`, and
fixture subtype into that profile/state. It should not expose executable DM
expressions.

## Known gaps and cautions

- The current Atlas scenario loses twenty placed `light_type` overrides and
  two desk-lamp `switchon` overrides. Path-only defaults will still be close,
  but not fully source-exact until the importer contract is extended.
- Atlas contains no emergency fixture, so emergency behavior cannot be
  visually demonstrated there without authored content.
- Full inherited DM plane/layer and runtime overlay evaluation are still
  incomplete. Multiplying the whole current native map pass will darken
  computer screens that Goon makes locally emissive. A first pass should add a
  small explicit emissive layer for fixture overlays, fire, alarms, switches,
  and common screens.
- Goon's `view()` visibility and handcrafted wall overlay masks will not match
  a generic raycaster pixel-for-pixel at corners. Radius-6 stable LOS plus
  blocker-surface reception is the recommended v1 approximation.
- Goon updates lights asynchronously under load. Sim Station should preserve
  deterministic tick-boundary state and may update presentation immediately;
  reproducing source scheduling lag is neither useful nor desirable.

## Validation and evidence state

Research-only checks completed:

```text
git -C assets/cache/goonstation rev-parse HEAD
  1b2b250abb5be747d55e274de0203a59cfc8da78

compiled Atlas:
  354 light fixtures on 353 cells
  57 light switches
  40 fire alarms
  0 emergency-light fixtures

original Atlas DMM:
  20 placed light_type overrides
  2 placed green-desk-lamp switchon overrides
```

No production test was added because this task did not modify production code,
generated data, public schemas, or runtime assets. The repository audit was
run after indexing the concurrent lighting archives and passed:

```text
Lua                         28 passed
Python map/appearance       29 passed
mod validation              5 packs passed
asset audit                 passed
JSON/TOML/link/boundary/LFS passed
git diff --check            passed
```

## Decision disposition

### Accepted

- The parent requested concrete v1 defaults grounded in the pinned source.
- Preserve true-black station ambient, bounded robust point lights, opacity
  occlusion, emergency red inversion, fire simple lights, and fullbright space
  with starlight.

### Adapted

- Use fixed-point lookup tables instead of authoritative floating-point
  arithmetic in core.
- Use bounded stable LOS with blocker-surface reception instead of reproducing
  BYOND `view()` and every handcrafted wall-overlay edge in the first pass.
- Use a viewport mesh/canvas in LÖVE instead of one BYOND overlay object per
  turf.

### Rejected

- A global warm ambient wash for station interiors.
- Treating every normal fixture as an emergency red light during outages.
- Making transparent windows or grilles block light.
- Recomputing illumination per screen pixel on the CPU.

### Unresolved

- The exact public light-profile schema and importer representation.
- Complete machine-screen/self-illumination overlay extraction.
- Pixel-exact wall-mask parity at connected-wall corners.
- Whether authoritative NPC vision consumes RGB channels or a fixed-point
  luma projection.

## Sources

All primary sources are from Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`:

- `_std/defines/lighting.dm`
- `_std/defines/layer.dm`
- `_std/plane.dm`
- `code/_lighting/base_lighting.dm`
- `code/_lighting/RobustLight2.dm`
- `code/_lighting/SimpleLight.dm`
- `code/datums/controllers/process/lighting.dm`
- `code/modules/power/lighting.dm`
- `code/obj/machinery/lightswitch.dm`
- `code/obj/machinery/firealarm.dm`
- `code/obj/machinery/shipalert.dm`
- `code/modules/atmospherics/FEA_fire.dm`
- `code/turf/turf.dm`
- `code/turf/turf_autoalign.dm`
- `code/atom.dm`
- `code/area.dm`
- `maps/atlas.dmm`

Local Sim Station context:

- `src/core/world.lua`
- `src/core/interactions/fixtures/light.lua`
- `src/core/machines/engineering/apc.lua`
- `src/presentation/map_appearance.lua`
- `src/presentation/renderer.lua`
- `mods/org.simstation.core/scenarios/goon-atlas.json`
- `assets/runtime/goon/graphics/atlas.json`
- `docs/agents/tile-source-coverage.md`
- `docs/technical/04-rendering-and-graphics.md`
- `docs/technical/10-goon-world-interaction-fidelity.md`

## Implementation-review addendum — 2026-07-28

### Review scope

This addendum compares the landed presentation implementation and the captured
`build/visual-audit/simstation-dynamic-lighting.png` against the pinned
Goonstation sources above. Reviewed files were:

- `mods/org.simstation.core/content/lighting.json`
- `src/presentation/light_field.lua`
- `src/presentation/light_sources.lua`
- `src/presentation/lighting.lua`
- `src/presentation/renderer.lua`
- `docs/technical/04-rendering-and-graphics.md`
- `tests/run.lua`

The reviewed capture is 1280×720, reports 270 active emitters, and has SHA-256
`75943b220db3564f7d55a3b3a0f41dcbe687d10b0970772da9990b44a7722c26`.
No production code or content was changed by this review.

### Keep the landed tube constants

The ordinary tube profile itself is correctly transcribed:

```text
implemented RGB8       242,242,255  = round(.95,.95,1 × 255)
implemented brightness 1.6
implemented height     614/256      = 2.3984375, nearest fixed value to 2.4
implemented radius     768/256      = 3 tiles
implemented ambient    station 0,0,0; space 255,255,255
```

At samples admitted by the current candidate mask, the robust-light arithmetic
also matches the pinned double-brightness behavior: attenuation contains `B`,
then premultiplied source color contributes another `B`. At the source tile,
the implemented red multiplier is `0.7617`; the pinned formula is `0.7621`.
That difference is only the documented 1/1024 quantization.

Do **not** increase brightness, radius, height, or global ambient to compensate
for the visual gaps below. The major darkness errors are footprint, source
typing, composition, and missing emissive layers.

### High: the robust-light candidate footprint is too small

Pinned point lights iterate `view(src.radius, middle)`. BYOND defines a range
as extending the same number of squares in straight and diagonal directions;
`view(3)` therefore begins with a 7×7 visibility region before opacity and
attenuation checks. The implementation instead requires:

```lua
fixed_distance_squared <= radius_squared
```

That clips an unobstructed radius-3 tube from 49 candidate cells to a
29-cell Euclidean circle. All 49 square samples survive the pinned tube's
attenuation threshold in an open room. Focused comparison:

| Offset from tube | Implemented red | Pinned red if visible |
| --- | ---: | ---: |
| `(0,0)` | 0.7617 | 0.7621 |
| `(2,2)` | 0.2217 | 0.2216 |
| `(3,1)` | 0 | 0.1723 |
| `(3,2)` | 0 | 0.1180 |
| `(3,3)` | 0 | 0.0580 |

Action: for `goon-robust`, enumerate the square/Chebyshev radius exactly as
BYOND `view()` does, then apply visibility and the existing attenuation
threshold. Preserve radial bounds for explicitly radial non-Goon profiles if
that is their documented contract. Add an open-room fixture asserting the
three missing edge/corner samples above.

Primary evidence:

- [`RobustLight2.dm` lines 355–376](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/_lighting/RobustLight2.dm#L355-L376)
- [BYOND guide: `view` ranges include straight and diagonal squares](https://www.byond.com/docs/guide/chap14.html)

### High: one generic tube source is standing in for 32 fixture families

`light-provider/light-feature-v1` emits one normal tube per semantic
`FEATURE.LIGHT` cell. That loses both identity and behavior:

- 354 upstream atoms become at most 353 cell sources because one cell contains
  two lights;
- small bulbs, 30 incandescent fixtures, 54 runway lights, 24 traffic lights,
  desk lamps, sticky lights, and beacons all receive the tube profile;
- all receive `activation.mode = normal`, despite desk lamps, traffic lights,
  runway/signal lights, and beacons having distinct source rules;
- the 20 placed `light_type` overrides and two placed green-desk-lamp
  `switchon` overrides remain unavailable; and
- the 57 placed area light switches are not projected into activation state.

The capture's `lights 270` counter therefore means 270 active generic semantic
cells, not 270 source-faithful Goon fixtures. It must not be reported as
fixture coverage parity.

Action: project stable emitter records from ordered appearance atoms rather
than only the cell feature bit. Compile source-path family, `light_type`,
`switchon`, signal/direct/area policy, and area light-switch state into
validated profile/binding data. Keep the feature provider only as the generic
fallback for constructed or modded fixtures without a more specific record.

### High: upstream overbright is discarded and replaced by unoccluded bloom

The CPU field accumulates above 1 but `LightField:channel` clamps it to 1
before upload. Goon instead derives a separate per-channel additive field:

```text
clamp((accumulated_channel - 1) * 0.5, 0, 0.3)
```

The landed renderer substitutes a radial bloom for every tube whether or not
the accumulated channel exceeds 1. `draw_bloom` performs no wall/door
occlusion. The capture visibly shows pale glow spilling beyond exterior room
walls, especially around the bright upper-right room; that is a bloom
artifact, not the pinned robust-light edge behavior.

Action:

1. preserve the unclamped accumulated channels;
2. upload/draw the capped additive-overbright field after the multiply pass;
3. remove generic tube bloom, or limit the post-light pass to the exact
   compiled fixture `*-overlay` appearance; and
4. ensure any optional artistic bloom is masked by the resolved light field
   and clearly labeled as non-parity.

This will remove wall-penetrating fog without weakening the correct tube
constants.

### High: space is only fullbright at texel centers

`space_ambient_srgb8 = (255,255,255)` is the right field value, but the same
linearly filtered image is multiplied over station and space. At a
station/space boundary, filtering interpolates black or colored station
samples with white space samples. It therefore darkens part of a nominally
fullbright space tile and brightens part of a station tile. Goon omits the
robust multiply overlay from fullbright space instead.

The implementation also omits the compiled 96×96 additive `starlight` state
which upstream offsets by -32 pixels so colored space light reaches the
station edge. The captured starfield survives in open space, but the hard,
dark edge bands do not reproduce the reference's colored boundary light.

Action: add a nearest, tile-exact fullbright mask to the light shader (or an
equivalent composition mask), so space pixels select multiplier 1 without
cross-boundary interpolation. Then draw the already-imported `starlight`
appearance additively with its source offset/color.

### Medium/high: tile-center occlusion is an adaptation, and filtering leaks it

The implementation's stable supercover rule—give every opaque destination a
terminal sample and stop beyond it—is a reasonable v1 approximation, but it is
not the pinned algorithm. Upstream:

1. uses BYOND `view()` visibility;
2. rejects opaque destination turfs and turfs with opaque atoms in its primary
   pass; and
3. expands east/north/northeast samples for handcrafted floor/wall overlay
   masks.

The current one-texel linear image additionally interpolates a lit blocker
sample toward the nominally dark tile behind it. Thus a behind-wall tile
center can pass the unit test while visible pixels still receive a soft
fringe. Unoccluded source bloom extends the leak further.

Action: keep the supercover method explicitly documented as an approximation
until the imported `floors`, `walls_supernorn`, and `walls_jen` masks are used,
and add screenshot fixtures for a single wall, inside corner, outside corner,
and closed/open airlock. If the mask work is deferred, add a nearest
transmission/opacity texture so bilinear light sampling cannot cross a blocked
edge.

### Medium/high: emissive painter order is still unlike Goon

`Renderer:draw` currently draws machines, crew, and `_draw_foreground_effects`
before `_draw_light_field`. Consequently computer displays and the visible
fire rectangle are multiplied into darkness. Only the invented radial bloom
survives. The public rendering document's statement that the visible flame
remains after darkness is therefore false.

The official reference gets much of its green, blue, orange, and red character
from self-lit screens, lamp overlays, alarms, and simple lights. Their absence
is why the capture reads as a mostly neutral gray tube wash even where its
floor/turf art is correct.

Action: retain shadowed bodies/machines before multiply, but replay validated
self-illumination appearances, fixture overlays, fire sprites, alarms, and
screens afterward. Move the fire foreground draw after darkness immediately.

### Medium: the shipped fire profile is an adaptation, not source parity

The fixed orange `(255,105,35)`, radius-3 smoothstep field, hash flicker, and
generic radial bloom do not match pinned atmospheric fire. Upstream uses the
compiled `medium_center`/`medium_dir` simple-light sprites, blackbody color
from hotspot temperature, alpha 100, and only suppresses a directional lobe
when its adjacent turf is opaque.

Action: label the current fire profile as an interim approximation. For
parity, render the compiled medium simple-light states after darkness, derive
color from authoritative fire temperature, and gate the four directional
lobes by adjacent opacity.

### Documentation claims to narrow now

Until the fixes above land, replace or qualify these claims in
`docs/technical/04-rendering-and-graphics.md`:

- “source-faithful baseline” applies only to the default tube numeric profile
  and interior ambient, not its footprint, fixture census, occlusion raster,
  additive plane, space boundary, or fire;
- “walls and closed doors stop a ray after receiving its terminal sample” is
  the documented Sim Station approximation, not the pinned Goon algorithm;
- “space is full-bright” is exact only at space texel centers until a hard
  fullbright mask exists;
- “visible flame ... remain[s] after the darkness pass” is currently false;
  and
- `lights 270` is an active semantic-emitter diagnostic, not an upstream
  fixture-parity count.

### Recommended tuning order

1. Change the robust candidate footprint from Euclidean circle to BYOND's
   square `view()` range; keep the existing tube constants.
2. Remove unoccluded tube bloom and implement accumulated overbright.
3. Mask fullbright space exactly and add compiled starlight.
4. Project per-appearance fixture family/profile/activation and area-switch
   state.
5. Put fire and validated emissive appearances after multiply.
6. Only then compare captures and consider artistic tuning. Global ambient or
   intensity changes before these corrections will hide one error while
   worsening another.
