# Lighting mod contract — dynamic lighting and extension audit

## Record

- Canonical task: `/root/lighting_mod_contract`
- Display name: not supplied
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: architecture audit and archive completed; no
  production code or generated assets changed
- Report availability: normalized visible report
- Assignment availability: verbatim

### Assignment

> Audit mod/content architecture for a day-one moddable lighting contract.
> Recommend data fields/hooks for light emitters, color/radius/intensity/falloff/
> flicker, power state, emergency lights, fire, and safe validation/budgets
> without core special-casing. Also inspect existing machine/structure/light
> state for available signals. No production edits. Archive under
> docs/agents/lighting-mod-contract.md plus indexes and report recommendations
> to /root.

### Observable chronology

1. Inspected the content registry, mod manifest/loader, hook dispatcher and
   hook context.
2. Inspected the scenario schema/imported Atlas map, world state, light
   interaction profile, machine definitions, APC behavior, power allocation,
   renderer, and render snapshot.
3. Counted the imported Atlas light appearances and compared that identity to
   the compressed per-tile light feature.
4. Checked the pinned Goonstation lighting source for normal, emergency,
   signal-controlled, and independent fixture behavior.
5. Designed a data-first emitter/profile contract, normalized snapshot
   projection, bounded trusted hooks, validation limits, and a migration path
   from the current tile feature.
6. Changed only this archive and its human/machine-readable indexes.

## Visible report

### Executive recommendation

Dynamic lighting should enter the renderer through one generic,
backend-neutral `LightEmitterInstance` projection. The renderer should not
discover lights by testing `Constants.FEATURE.LIGHT`, Goon type paths,
machine kinds, APC fields, or `world.fire` itself.

Register two data content kinds:

- `light-profile` describes presentation-only color, radius, intensity,
  falloff, occlusion, and deterministic flicker.
- `light-binding` attaches a profile and an activation/power policy to a
  fixture, machine, effect, or imported-map appearance.

The base Goon profiles and bindings must travel through the same registry as a
normal mod. Fire must reference an ordinary profile and project an ordinary
emitter instance. The GPU result remains non-authoritative; if illumination
later affects NPC sight, the core must run a separate deterministic integer
solver from the same profiles and authoritative emitter state rather than
reading a Canvas or shader result.

### Smallest safe day-one contract to ship now

The initial implementation does not need the complete future entity/component
model or new trusted-code hooks. The smallest contract that is both moddable
and honest is:

1. one closed `light-profile` schema;
2. one closed, one-emitter-per-record `light-binding` schema;
3. a generic collector that projects sorted `LightEmitterInstance` records
   from registered providers and bindings;
4. a renderer that consumes only those records plus a binary tile-transmission
   projection; and
5. a normalized APC lighting-channel service result.

Do not ship a renderer-only table keyed by Goon paths or a magic default
profile ID. That would make the first implementation fast to write but would
immediately create an internal extension path unavailable to ordinary packs.

For this increment, use this exact minimal profile envelope:

```json
{
  "id": "org.simstation.goon:light-profile/tube/neutral",
  "kind": "light-profile",
  "schema": 1,
  "name_key": "org.simstation.goon.light-profile.tube.neutral",
  "color_srgb8": [242, 250, 247],
  "radius_256": 1536,
  "intensity_ppm": 1000000,
  "falloff": "smoothstep",
  "occlusion": "tile-transmission",
  "flicker": {"mode": "none"},
  "priority": 100
}
```

Allowed top-level keys are exactly `id`, `kind`, `schema`, `name_key`,
`replaces`, `color_srgb8`, `radius_256`, `intensity_ppm`, `falloff`,
`occlusion`, `flicker`, and `priority`. `replaces` follows the existing normal
replacement rule. There are no tags, shader names, asset paths, floats, alpha
field, arbitrary curves, or optional behavior fields in schema 1.

Use a single-emitter binding rather than the broader multi-slot sketch later
in this report:

```json
{
  "id": "org.simstation.goon:light-binding/atlas/tube",
  "kind": "light-binding",
  "schema": 1,
  "profile_id": "org.simstation.goon:light-profile/tube/neutral",
  "selector": {
    "kind": "source-path",
    "scenario_ids": [
      "org.simstation.core:scenario/goon-atlas"
    ],
    "path_root": "/obj/machinery/light"
  },
  "activation": {
    "mode": "normal",
    "power_channel": "lighting"
  },
  "offset_x_256": 0,
  "offset_y_256": 0,
  "level_ppm": 1000000
}
```

Allowed binding keys are exactly `id`, `kind`, `schema`, `replaces`,
`profile_id`, `selector`, `activation`, `offset_x_256`, `offset_y_256`,
`level_ppm`, and optional `level_curve`. One binding creates one emitter for
each selected source; multiple emitters use multiple binding IDs. This makes
stable ordering and per-source budgets trivial.

Schema-1 selectors are a closed union:

```text
source-path:
  {kind, scenario_ids[1..64], path_root}
definition:
  {kind, definition_id}
provider:
  {kind, provider_id}
```

- `source-path` is the temporary imported-map bridge. Scenario IDs are sorted,
  unique, resolved `scenario` IDs. `path_root` is an absolute safe `/obj` type
  root, at most 1024 bytes, with no empty, `.` or `..` component. Matching is
  exact or `path_root .. "/"`; raw string prefixes are forbidden. Longest root
  wins and equal-specificity matches are a load error.
- `definition` binds a future/current stable spatial definition ID without
  inspecting its pack or kind in renderer code. The referenced definition must
  declare itself emitter-capable once typed components land.
- `provider` names a registered, versioned emitter provider such as
  `org.simstation.core:light-provider/fire-tile-v1`. Unknown providers fail
  loading. A provider yields normalized sources; it does not draw.

Schema-1 activation has exactly `mode` and `power_channel`.
`mode` is `normal`, `emergency`, `independent`, `signal`, or `always`.
`power_channel` is `lighting`, `equipment`, `environment`, or `none`.
`always` requires `none`; `normal`, `emergency`, and `signal` require a
non-`none` channel. `independent` permits `none` or `lighting`. Fire is a
registered provider plus an `always`/`none` binding and an optional
`level_curve`; there is no `if world.fire` branch in the renderer.

`level_curve` is an array of 2–16
`{"input": integer, "output_ppm": integer}` records. Inputs are strictly
increasing from 0 through at most 1,000,000; output is 0–4,000,000; evaluation
is clamped to endpoints and uses documented integer linear interpolation.
Bindings without a curve use `level_ppm` directly. Offsets are ±4096,
`level_ppm` is 0–4,000,000, and all referenced profiles/providers/scenarios
must resolve in the sealed registry.

The source-path bridge is intentionally scenario-scoped. It lets the generated
Atlas data retain all 354 appearances now, while preventing an unrelated mod
which happens to use a Goon-like string from silently acquiring a core
profile. Stable definition/entity bindings replace it later without changing
the renderer contract.

Do not add the four specialized lighting hooks in the first increment.
Existing command/tile validators and finalized-event observer already provide
a safe broad interception path. Data packs need profiles and bindings, not
Lua. Add the typed lighting hooks only with hook-specific fixtures and query
budgets; otherwise “hooks on day one” would expand the unstable API without
helping ordinary data mods.

#### APC decision for this increment

Integrate the APC lighting channel now. Without it, `activation.mode =
"normal"` is misleading, emergency activation cannot be tested, and the
player's already-implemented `set-channel` action visibly does nothing.

The bounded service gate supported by current state is:

```text
controller_operational =
  not machine.destroyed
  and not machine.status.broken
  and machine.data.operating
  and not machine.data.do_not_operate
  and not machine.data.shorted

channel_requested = machine.data.lighting > 1

area_lighting_served =
  world.area_powered[area_id]
  and controller_operational
  and channel_requested
```

The `> 1` test is source-defined: Goon APC channel values are `0=off`,
`1=auto-off`, `2=on`, and `3=auto-on`, and its `get_power_levels()` exposes
lighting power only when `lighting > 1`.

Compute a sorted/derived `area_lighting_served` projection during the power
step and advance `power_revision` when it changes. Normal bindings require it;
emergency bindings activate on its loss. Imported area light-switch state is
not currently available, so treat the switch as requested-on and clearly mark
that adaptation. APC battery discharge/reserve and complete proportional load
shedding are also outside this increment; do not pretend `cell_charge` is
already conserved. The new normalized service boundary allows those systems to
replace the adapted input later without changing content or renderer code.

This small APC integration is preferable to either extreme: ignoring an
already-functional channel control produces visibly false lighting, while
attempting full SMES/APC/cell accounting inside a graphics task would broaden
scope and create untested power behavior.

### Current architecture: usable signals

The existing implementation already exposes enough state for a first visual
slice, but not enough for correct power-channel or emergency behavior.

| Signal | Current location | Useful meaning | Limitation |
| --- | --- | --- | --- |
| light presence | `world.feature_mask` / `Constants.FEATURE.LIGHT` | at least one light-like source was classified on the tile | one bit loses fixture identity, subtype, color, multiplicity and profile |
| fixture state | `world.interaction_state[index].light` | `installed`, `broken`, and requested `on` | no lamp type, color, brightness, power mode, direction or stable fixture entity |
| tile power | `world.powered[index]` | cable reach or area serviced by a cable-connected APC | not a lighting-channel service result and not load-shed by actual supply |
| area power | `world.area_powered[area_id]` | at least one cable-connected APC claims the area | ignores APC operating state, lighting channel, cell state, shorting and area light switch |
| power revision | `world.power_revision` | power solve completed | no dedicated emitter/light revision |
| APC lighting data | `machine.data.lighting`, `operating`, `cell_present`, `cell_charge`, `shorted`, `terminal_present` | source-compatible inputs for a future lighting service resolver | APC behavior updates these fields, but `World:step_power()` does not consume them |
| machine service | `machine.powered`, `status.no_power`, `status.broken`, `destroyed`, `served_watts` | normalized state for machine-mounted emitters | imported light fixtures are not machine instances |
| fire | `world.fire[index]` | integer fire intensity, currently normally 0, 2 or 4 | renderer hard-codes a red rectangle; no profile, source ID or dedicated revision |
| topology/opacity inputs | structure, door state, window/grille features and interaction damage state | enough to derive a first binary transmission grid | no normalized light-transmission projection exists |
| source appearance | `scenario.map.appearances` | exact type path, direction, pixel offset, role and map order | presentation catalog is currently Atlas-specific and not a public emitter registry |

`World:step_power()` marks every serviced tile powered even when
`power_demand_w > power_supply_w`; only the aggregate `power_served_w` is
clamped. It also considers an area powered when an APC is cable-connected,
without consulting that APC machine's `data.lighting`, `operating`,
`cell_present`, `cell_charge`, `shorted`, or `terminal_present` state. The
current `world.powered[index]` is therefore a usable temporary visual signal,
not the public truth for normal or emergency lights.

There is no authoritative area light-switch field. `world.areas` currently
contains imported identity, name, department, access and source path. The
station alert list is not a closed emergency-light signal either.

Light interactions correctly touch the owning chunk when installed/broken/on
changes. Power changes advance `power_revision` without touching those chunks,
so a lighting cache must include power/emitter revisions rather than rely on
`chunk_revision` alone.

### Atlas census and why one feature bit is insufficient

The shipped Atlas scenario has:

- 354 `/obj/machinery/light` appearance records;
- 353 unique light-bearing tile indexes;
- one tile containing two separate fixtures;
- 353 cells represented by the compressed `light` feature;
- 32 distinct fixture source paths before directional light switches; and
- fixture directions distributed as 55 east, 61 north, 173 south, and 65 west.

The source paths include tubes, incandescent and harsh lamps, small/floor/
sticky variants, colored desk lamps, beacon/tripod lights, runway delay
variants, and signal-controlled traffic lights. A feature-bit-only renderer
necessarily erases at least the stacked fixture and all subtype behavior.

### Pinned Goon behavior that the contract must express

At the pinned revision, a fixture owns brightness, an inserted lamp type,
lamp status, a lamp-derived RGB color, direction/placement, and a point light.
Normal fixtures enable when both area lighting power and the area light switch
are on. Emergency fixtures invert the area lighting-power condition or react
to the bad ship alert, independent of the normal switch. Traffic lights retain
their signal-controlled requested state but still require area lighting power.
Desk lamps have an independent local switch. Runway lights are normally on and
use delay variants. Broken, burned, empty and off states disable emission.

This confirms that “powered feature equals yellow glow” is only a temporary
adaptation. Power policy belongs to the emitter-bearing fixture/effect
definition, while color/radius/falloff belongs to a reusable presentation
profile.

## Proposed public data contract

### `light-profile` schema 1

All quantities are exact JSON integers. Colors use 8-bit sRGB source values;
the presentation backend performs the documented conversion. Spatial values
use 1/256 tile units so the contract is independent of window scale while
remaining exact at the native 32-pixel tile ratio.

```json
{
  "id": "org.simstation.goon:light-profile/tube/neutral",
  "kind": "light-profile",
  "schema": 1,
  "name_key": "org.simstation.goon.light-profile.tube.neutral",
  "color_srgb8": [242, 250, 247],
  "radius_256": 1536,
  "intensity_ppm": 1000000,
  "falloff": "smoothstep",
  "occlusion": "tile-transmission",
  "flicker": {
    "mode": "none"
  },
  "priority": 100
}
```

Closed fields:

| Field | Contract |
| --- | --- |
| `color_srgb8` | exactly three integers, each 0–255 |
| `radius_256` | 0–4096 inclusive, or at most 16 tiles |
| `intensity_ppm` | 0–4,000,000 inclusive |
| `falloff` | `constant`, `linear`, `smoothstep`, or `quadratic` |
| `occlusion` | `none` or `tile-transmission`; arbitrary shaders/ray callbacks are forbidden |
| `flicker.mode` | `none`, `sequence`, or `stable-hash` |
| `flicker.period_ds` | 1–600 for non-`none` modes |
| `flicker.amplitude_ppm` | 0–1,000,000 for `stable-hash` |
| `flicker.samples_ppm` | 1–64 integers, each 0–2,000,000, for `sequence` |
| `priority` | 0–1000; presentation degradation only, never gameplay importance |

Flicker phase is derived from `(snapshot tick, stable emitter ID, profile ID)`.
It never advances authoritative RNG and never uses `os.clock`, render-frame
delta, unordered table order, or camera position. A sequence profile samples
an explicit integer table; stable-hash mode uses a specified integer hash and
amplitude. Mods cannot provide shader text, Lua functions, blend callbacks, or
unbounded curves.

### Full target `light-binding` schema 1

A binding keeps behavioral activation separate from the reusable visual
profile:

```json
{
  "id": "org.simstation.goon:light-binding/fixture/tube",
  "kind": "light-binding",
  "schema": 1,
  "profile_id": "org.simstation.goon:light-profile/tube/neutral",
  "slots": [
    {
      "id": "primary",
      "offset_x_256": 0,
      "offset_y_256": 0,
      "activation": {
        "mode": "normal",
        "power_channel": "lighting"
      }
    }
  ],
  "selector": {
    "definition_id": "org.simstation.goon:fixture/light/tube"
  }
}
```

The preferred selector is one exact fixture, machine, effect, item, or
structure definition ID. The minimal one-emitter binding above is the selected
schema-1 shape. The following multi-slot form is a future schema example, not
part of the smallest day-one contract. A temporary imported-map bridge may
select an exact safe source type or a source-type subtree:

```json
{
  "selector": {
    "source_pack_id": "org.simstation.goon",
    "source_type_root": "/obj/machinery/light/small/floor/harsh"
  }
}
```

That bridge is ordinary pack data and must require the source pack. Longest
exact root wins; equal-specificity conflicts are a load error. Renderer Lua
must not contain Goon paths. New native scenarios should eventually store
definition IDs/stable fixture entities directly and avoid the bridge.

Each binding has at most four named slots. Slot IDs are sorted and unique.
Offsets are bounded to ±4096 units. A slot references one profile and one
closed activation policy:

- `normal`: operational, requested on, and requested channel served;
- `emergency`: operational and emergency condition active, with its declared
  reserve/channel served;
- `independent`: operational, local switch requested, and local supply served;
- `signal`: operational, control signal active, and requested channel served;
- `always`: operational only; permitted for natural/effect sources and
  explicitly rejected for a grid-powered fixture.

These are generic policies available to every pack, not branches on a core
definition ID. An emitter source projects the normalized inputs
`operational`, `requested_on`, `control_active`, `channel_service`,
`emergency_condition`, and `level_ppm`. The renderer receives only the final
`enabled` result.

### Normalized `LightEmitterInstance`

The complete-tick render snapshot should contain a stable sorted array:

```lua
light_emitters = {
  {
    id = "light:map:station:10869:fixture:1:primary",
    source_id = "fixture:atlas-light-10869-1",
    profile_id = "org.simstation.goon:light-profile/tube/neutral",
    map_id = "org.simstation.core:scenario/goon-atlas",
    x_256 = 2781824,
    y_256 = 14336,
    enabled = true,
    level_ppm = 1000000,
    power_state = "served",
    origin_tick = 0,
    revision = 7
  }
}
```

Required fields are stable ID, source ID, profile ID, map ID, integer anchor,
final enabled state, integer level multiplier, normalized power state,
animation/flicker origin tick, and revision. Optional bounded per-instance
color/radius overrides are useful for chemistry, alerts, and damage, but the
definition profile remains the default.

Sort by stable emitter ID before publishing. The renderer may spatially index
the array and degrade over-budget presentation by `(priority descending,
stable emitter ID ascending)`. Camera-dependent culling is presentation-only
and cannot affect saves, simulation, NPC decisions, or replay hashes.

### Occlusion/transmission projection

Every spatial structure/component definition should be able to declare:

```json
{
  "lighting": {
    "transmission_ppm": 0
  }
}
```

The snapshot builder projects one integer `light_transmission_ppm` per tile
after stable composition of all occupants. Open doors project 1,000,000;
opaque walls/closed doors project 0; windows may project a bounded intermediate
value. Destroyed or removed components stop contributing. Composition uses
sorted stable component IDs and integer multiplication with a documented
rounding rule.

This removes structure-kind checks from the renderer and lets modded walls,
windows, shutters, smoke, force fields, and effects participate through the
same data contract. The first renderer may quantize any nonzero value to
transparent and zero to opaque, but the snapshot field should not need to
change when colored/partial transmission is implemented.

### Power and emergency state

Add a core-owned, normalized lighting-service result per area/source:

```text
channel_service = served | unserved | reserve | independent | unknown
emergency_condition = false | true
```

The resolver, not the renderer, combines:

- cable/network connectivity;
- available supply and deterministic load shedding;
- APC operating, shorted, terminal, cell and lighting-channel state;
- area light-switch state;
- local battery/reserve state;
- signal/control state; and
- closed, content-defined alert conditions.

The first visual implementation may adapt existing `world.powered[index]` into
`served/unserved`, but it should do so behind this projection interface and
record the limitation. Emergency lights must not simply use
`not world.powered[index]` in renderer code because the current boolean is not
a lighting-channel result and provides no reserve source.

### Fire and other natural sources

Fire uses exactly the same contract:

```json
{
  "profile_id": "org.simstation.core:light-profile/effect/fire",
  "activation": {"mode": "always"},
  "level_curve": [
    {"input": 0, "output_ppm": 0},
    {"input": 1, "output_ppm": 450000},
    {"input": 4, "output_ppm": 1200000},
    {"input": 16, "output_ppm": 2000000}
  ]
}
```

The authoritative fire system projects one stable emitter per burning tile,
maps its bounded integer intensity through a validated piecewise-linear
integer curve, and supplies an origin tick. The renderer never tests
`world.fire` specially. Plasma reactions, handheld lamps, machinery, glowing
items, bioluminescence, alerts, lightning and mod effects can then use the same
instance/profile path.

Curves have 2–16 points, strictly increasing integer inputs, bounded integer
outputs and an explicit clamp outside the endpoints. They are evaluated only
when the authoritative source revision changes; declarative flicker handles
frame-to-frame variation.

## Recommended hooks

Data-only profiles, bindings and references cover ordinary mods. Trusted Lua
gets typed hooks, not renderer access:

| Hook ID | Kind | Cadence and mutable surface |
| --- | --- | --- |
| `org.simstation.core:hook/light/setting/validate` | validate | once before a typed toggle/dimmer/color/power-policy command; may reject only |
| `org.simstation.core:hook/light/state/changed` | observe | once after a committed state or service transition; receives immutable old/new normalized state and may enqueue next-tick commands |
| `org.simstation.core:hook/lighting/emitter/project` | transform | once per dirty source during snapshot projection; may change only profile ID, enabled, level, bounded color/radius override, origin tick and priority |
| `org.simstation.core:hook/lighting/ambient/project` | transform | once per dirty area/map ambient record, not once per tile or pixel |

Do not expose:

- per-pixel, per-ray, per-shadow-edge, per-cell-per-frame, or draw callbacks;
- `Canvas`, `Shader`, `Image`, `Quad`, camera, filesystem, clock or network
  objects;
- arbitrary GLSL or blend equations;
- mutation of source position, source identity, occluder topology or
  authoritative power through a presentation transform; or
- frame-rate-dependent hook invocation.

The emitter transform receives a closed primitive record and a restricted
query context. It cannot add an unbounded emitter list. New emitters enter
through definitions, scenario/entity instances, commands, or a separately
bounded candidate-list contract. Hook output is schema-validated after every
handler. A visual transform failure disables that handler, records a
diagnostic and retains the prior valid candidate; it should not corrupt the
simulation transaction.

## Validation and runtime budgets

### Load-time validation

- Reject unknown fields; never silently clamp authored content.
- Require exact integers and resolved content references.
- Require profiles, bindings, slots, selector rules and curve points to be
  sorted and unique where order is not semantic.
- Cap a pack at 4096 light profiles and 8192 bindings.
- Cap each binding at four emitters and each curve/sequence at the limits
  above.
- Verify selector ownership/dependency and reject equal-specificity ambiguity.
- Estimate scenario emitter count and maximum influence before starting it.
- Validate folder and `.simmod` forms to the same canonical registry.
- Include profiles, bindings and their referenced atlas records in the
  registry hash/mod lock.

The current architecture needs one prerequisite: validation must be dispatched
by content kind in both the runtime loader and `tools/mods.py`. At present,
`Registry:add_pack()` checks IDs, ownership and replacement but does not run a
closed kind schema. The Python tool has strict special cases for scenario,
machine and structure, while runtime `Machine.validate_definition()` is
substantially narrower and other kinds pass without a schema validator. Adding
lighting only to the Python validator would create a false safety boundary.
Use one schema source or paired fixture-tested validators and reject unknown
kinds as the public documentation promises.

The scenario schema also hard-codes feature names and fixture kinds. A normal
mod cannot add a new spatial emitter component without either replacing a
scenario palette or entering a hard-coded list. The target should be a generic
scenario entity/component record with an exact definition ID; the temporary
`light-binding` imported-path adapter is a migration bridge, not the permanent
entity model.

### Runtime presentation budgets

Recommended portable defaults for an OpenGL 2/LÖVE fallback:

- at most 8192 emitter instances per map;
- at most eight emitters anchored to one tile;
- at most 1024 enabled emitters intersecting one viewport before degradation;
- profile radius no greater than 16 tiles;
- total visible influence budget of 262,144 tile/source intersections;
- at most 64 flicker samples and no runtime allocation per sample;
- one viewport-sized light accumulation surface plus one bounded scratch
  surface, never a whole 192×192-map Canvas; and
- no more than one logged budget diagnostic per pack/profile/revision.

Exceeding a runtime viewport budget is not a simulation error. Keep the
highest-priority emitters in deterministic stable-ID order, render the rest as
unlit, and expose the omitted count in diagnostics. Invalid instance values
from save migration or trusted code are clamped at the projection boundary,
the hook/profile is diagnosed, and authoritative state continues.

These budgets must be benchmarked rather than treated as immutable magic
numbers. The public schema maxima may stay fixed while platform quality presets
lower the presentation budget. A quality preset changes softness/resolution or
the number of rendered low-priority sources; it never changes enabled state,
stable ordering, or authoritative illumination.

## Suggested implementation order

1. Add closed `light-profile` and `light-binding` validators to the shared
   content validation path, with folder/archive/runtime parity tests.
2. Add the normalized emitter and tile-transmission arrays to
   `RenderSnapshot`; place all current feature/fire adaptation in one collector
   outside `renderer.lua`.
3. Ship Goon fixture/fire profiles and exact imported-path bindings as ordinary
   base/asset-pack data. Preserve all 354 Atlas sources rather than only the
   353 feature cells.
4. Implement the portable darkness/light-composition renderer against only
   emitter/profile/transmission records.
5. Add a lighting-service resolver that consumes APC channel, switch, reserve
   and supply state; replace the temporary `world.powered` adapter without
   changing renderer code.
6. Add normal, emergency, independent and signal fixture tests, then migrate
   lights to stable spatial entities/components.
7. Add typed hooks only after data-only profiles and bindings cover the base
   game.

## Required tests

- profile and binding boundary values, unknown keys and bad references;
- identical acceptance and canonical output for folder and `.simmod`;
- base content loaded through the ordinary mod path, with no Goon/core ID
  branch in the renderer;
- two emitters on one tile remain two stable instances;
- normal switch/channel loss, APC disabled/short/cell loss, and deterministic
  recovery;
- emergency light turns on for declared service loss/alert only when reserve
  is available;
- traffic/signal and desk/independent policies;
- broken, burned, empty, removed and manually off fixtures emit nothing;
- fire intensity curve and deterministic flicker across save/load and replay;
- wall, open/closed door, window and destroyed-structure transmission;
- power/emitter revision invalidates visible lighting without rebuilding
  unrelated native sprite chunks;
- budget overflow chooses the same stable subset every run;
- lighting quality/rendering disabled has no effect on state hash; and
- if gameplay illumination is added, its core integer result never samples a
  GPU surface.

## Decision disposition

### Accepted

- None recorded by the parent at archive time.

### Adapted

- None recorded by the parent at archive time.

### Rejected

- None recorded by the parent at archive time.

### Unresolved

- Whether the first implementation keeps the compressed tile-feature bridge
  for one milestone or immediately creates stable fixture entities.
- Exact portable runtime influence budget after profiling the chosen renderer.
- Whether partial transmission ships with the first binary-occlusion slice or
  remains a forward-compatible snapshot field.
- The final schema revision strategy for existing machine/structure
  definitions that need emitter/transmission components.

## Sources

- `src/core/world.lua`
- `src/core/interactions/fixtures/light.lua`
- `src/core/machine.lua`
- `src/core/machines/engineering/apc.lua`
- `src/core/simulation.lua`
- `src/core/scenario.lua`
- `src/presentation/renderer.lua`
- `src/presentation/map_appearance.lua`
- `src/content/registry.lua`
- `src/content/runtime.lua`
- `src/mods/loader.lua`
- `src/mods/hooks.lua`
- `src/mods/context.lua`
- `tools/mods.py`
- `mods/org.simstation.core/content/machines.json`
- `mods/org.simstation.core/scenarios/goon-atlas.json`
- `docs/technical/02-public-contracts-and-content.md`
- `docs/technical/04-rendering-and-graphics.md`
- `docs/technical/10-goon-world-interaction-fidelity.md`
- `docs/modding/02-hooks-and-code-api.md`
- [Pinned Goonstation lighting source](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm)

## Implementation-review addendum — 2026-07-28

This addendum reviews the first implementation in
`src/presentation/lighting_content.lua`,
`src/presentation/light_sources.lua`,
`mods/org.simstation.core/content/lighting.json`, and `tools/mods.py`. It is
limited to actionable content-contract, replacement, APC, and mod-safety
findings.

### P0 — validate in the runtime loading transaction

`tools/mods.py` validates the three lighting schemas, but
`src/mods/loader.lua` sends decoded documents directly to
`Registry:add_pack()`. The registry checks IDs, ownership, and replacement
declarations only. A package containing an out-of-range profile therefore
loads and seals successfully; `LightingContent.resolve()` detects it only
after `RuntimeContent` has been published.

`LightingContent.resolve()` then drops invalid records and injects embedded
copies of the core settings, profiles, and bindings. This has three unsafe
effects:

- it contradicts the documented all-or-nothing content transaction;
- an invalid mod replacement silently turns back into core behavior even
  though the registry reports the mod as the new owner; and
- the duplicated `org.simstation.core` defaults are a base-pack special case
  which an ordinary mod cannot use.

Move lighting shape validation and reference resolution into the candidate
runtime registry transaction, before `Registry:seal()`. Reject the candidate
and retain the previous registry on failure. `LightingContent.resolve()` should
consume an already-validated contract; an embedded contract may remain only
for explicit no-content tests or bootstrap failure, not as per-definition
hybrid recovery.

Add fixtures proving that folder, `.simmod`, and runtime loading accept and
reject the same records. Add lighting-specific replacement tests for:

- a valid settings replacement;
- a valid profile replacement used by an existing binding;
- a valid binding replacement that targets a new profile;
- an invalid replacement leaving the previous registry active; and
- replacement reference resolution occurring after ownership changes.

### P0 — finish bounding work before collecting sources

A concurrent follow-up added a 128-binding runtime truncation, identical
selector caching, and a deterministic `max_work_units` gate before field
construction. Those are useful partial bounds, but the collector still
materializes every source and candidate emitter before either the emitter or
work-unit budget is applied. Each distinct provider binding scans every world
tile, each definition binding scans every machine, and each source-path
binding scans every map appearance. A data mod can still allocate and sort a
large candidate set on every observed tick.

Pre-index scenario appearances and machines, collect each built-in provider
once per revision, and stream priority-ordered candidates into a bounded
selection structure instead of building the full cross product. Enforce pack
and resolved-registry profile/binding/source limits in the loader as well as
the presentation fallback.

The follow-up also made `max_work_units` a required field while retaining
`lighting-settings` schema 1. Either make the field optional with a documented
schema-1 default or increment/migrate the settings schema; adding a required
field silently invalidates existing schema-1 replacements. Keep the Lua,
Python, core JSON, docs, and replacement fixtures in parity.

Add a stress fixture which reaches every public maximum and proves bounded
candidate allocation, bounded line traversal, and stable priority-based
degradation.

### P1 — resolve all references and source-path ambiguity

The Python validator syntax-checks `profile_id`, scenario IDs, and definition
IDs but does not resolve them. Runtime resolution checks only `profile_id`;
unknown profiles cause bindings to be dropped, while unknown scenarios and
definitions silently produce no sources.

Source-path bindings also do not implement the documented specificity rule.
Every matching binding emits, so overlapping roots stack lights instead of the
longest root winning, and equal-specificity conflicts are never rejected.

During candidate-registry validation:

- resolve every profile, scenario, definition, and provider reference;
- require a definition selector to target a spatial emitter-capable contract;
- detect intersecting scenario/root selectors and reject equal-specificity
  ambiguity; and
- normalize a source-path appearance to exactly one longest-root binding.

Cover typoed references, missing optional dependencies, exact-root boundaries,
longest-root selection, and equal-root conflicts in both validators.

### P1 — preserve fixture identity and interaction state together

The shipped station binding uses `light-feature-v1`. Atlas has 354
`/obj/machinery/light` appearances on 353 feature cells, so this provider
collapses the stacked fixture and applies one tube profile to 32 distinct
source paths. A source-path selector preserves all appearance identities, but
its collector currently sets every match enabled and ignores the installed,
broken, and switched-on interaction state.

Do not switch the base JSON to source-path alone. First add a normalized
fixture-source projection which preserves appearance `(index, order)`, subtype,
direction, pixel offset, and shared/per-instance interaction state. Then bind
Goon subtypes to data-owned profiles and add a regression asserting 354 stable
Atlas fixture sources, including two distinct IDs on the stacked tile.

### P1 — harden APC and activation semantics

The bounded APC gate correctly uses grid reach, controller state, shorting,
and channel values greater than 1, but four edges remain unsafe:

- APC channel values are read with
  `(machine.data[field] or 3) > 1`. `false` becomes the powered default, while
  a nonnumeric truthy value can crash presentation collection. Validate APC
  state fields or normalize exact integer values `0..3` and fail closed with a
  diagnostic.
- In an area containing an APC, `source_powered()` returns area service before
  consulting a definition-selected source machine. A machine with
  `machine.powered == false` or `status.power_off == true` can therefore emit
  in `normal` mode. Machine-mounted sources must also honor their normalized
  machine power/off state.
- `emergency` activates solely when normal service is absent; no reserve or
  independent supply is required. Either add a normalized reserve-available
  source signal or reject emergency bindings until that signal exists.
- `independent` accepts every channel but runtime ignores the channel. Require
  `none` for the implemented free-standing behavior, or implement and document
  the promised reserve/channel semantics before accepting other combinations.

Add tests for disconnected, destroyed, broken, disabled, shorted, malformed,
manually powered-off, and multiple-controller cases, plus emergency behavior
with and without reserve.

### P2 — make lexical validators identical

Lua accepts a source-path ending in `/.` or `/..`, while `tools/mods.py`
rejects it, because the Lua checks find only interior `/./` and `/../`
substrings. The Python `scenario_ids != sorted(set(scenario_ids))` expression
can also raise raw `TypeError` for mixed or unhashable JSON values instead of a
bounded `ModError`.

The shared Python `CONTENT_ID` grammar additionally differs from
`src/content/id.lua`: it rejects `_` in kinds and accepts a trailing `/` in a
name. Definition selectors therefore do not have tool/runtime parity.

Use shared conformance fixtures for content IDs and safe BYOND type roots.
Validate element types before sorting/deduplicating scenario IDs, reject every
empty, `.` or `..` root component in both implementations, and convert all
invalid input into structured validation errors.

### P2 — make provider extensibility honest

Both validators and `light_sources.lua` hard-code two provider IDs. There is no
provider registry despite the documentation calling providers registered and
versioned. Either document schema 1 as a closed built-in-provider allowlist, or
add a trusted presentation-provider registry with bounded normalized output,
stable IDs, deterministic ordering, and per-provider diagnostics. Do not let a
data-only pack name executable provider code.
