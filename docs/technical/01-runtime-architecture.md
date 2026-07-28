# Runtime architecture

## Process model

Sim Station is one LÖVE 11.5 process with four ownership layers:

```text
platform/LÖVE callbacks
        │
        ▼
application adapters ── input, filesystem, renderer, audio, UI
        │ commands                    ▲ snapshots/events
        ▼                             │
pure-Lua deterministic core ── content registry and simulation systems
        │
        └── primitive save/replay state
```

The core is single-writer. Rendering and audio consume immutable projections;
they never hold authoritative tables. Worker threads may read files, hash bytes,
decode transferable image/audio data, or perform non-authoritative analysis.
Only the main thread may create or mutate LÖVE graphics and audio objects.

Required source boundaries are:

| Boundary | May depend on | Must not depend on |
|---|---|---|
| `src/core/` | Lua standard facilities and pure project modules | `love.*`, presentation, OS state, unordered outcomes |
| `src/content/` | strict parsers, schemas, pure registries | graphics/audio objects, live simulation mutation |
| `src/app/` | core facade, LÖVE adapters, presentation state | undocumented core table mutation |
| `src/render/` | `RenderSnapshot`, atlas indexes, `love.graphics` | authoritative world tables |
| `src/audio/` | `SimEvent` projection, audio manifests, `love.audio` | simulation RNG or state mutation |
| `tools/` | pinned development dependencies | being required to run a packaged release |

Concord may represent dynamic simulation entities, but authoritative systems
must iterate stable `EntityId` arrays, not library pool/hash order. Dense world
fields, utilities, and occupancy use flat row-major arrays and 16×16 chunks;
they are not modeled as one ECS entity per tile.

## Fixed scheduler

One authoritative tick represents one in-world second. At 1×, ten complete
ticks run per wall-clock second; 2× runs twenty and 4× runs forty. Thus an
eight-hour shift is 28,800 ticks and approximately 48 wall-clock minutes at 1×.

The application maintains a fractional `tick_credit`:

```lua
tick_credit = tick_credit + real_dt * 10 * selected_speed
while tick_credit >= 1 and frame_tick_budget > 0 do
  simulation:step()
  tick_credit = tick_credit - 1
end
```

- `selected_speed` is `1`, `2`, or `4`; pause accrues no credit.
- `simulation:step()` accepts no `dt` and always advances exactly one tick.
- A frame may execute at most eight ticks before yielding to presentation.
  Remaining credit is retained, never discarded or folded into a larger step.
- A platform stall over 250 ms pauses wall-clock accrual at 250 ms, retains
  already accrued credit, and shows “simulation paused after application
  stall.” This avoids hours of catch-up after suspend without changing any
  completed outcome.
- If backlog stays above two ticks for three wall-clock seconds, show a
  performance warning. The game slows relative to wall time; it never skips a
  tick.
- Speed/pause UI changes become `GameCommand`s at the next boundary so replay
  can reproduce the same command timeline. Camera and window operations remain
  presentation-only.

The current bootstrap clamps `dt`, allows up to 100 catch-up steps, discards
remaining credit at that cap, and can flush UI commands while paused. Those are
development conveniences, not the final scheduler. M1 must replace them with
the retained-credit/eight-step boundary above and ensure every authoritative
command commits only inside `simulation:step()`.

Within a tick, systems execute in this stable stage order:

1. drain, validate, and atomically commit due commands;
2. finalize topology changes and spatial indexes;
3. release and acquire reservations; plan work;
4. move actors, operate doors, and resolve immediate interactions;
5. update due utility, atmosphere, thermal, fire, and machine systems;
6. update due item, reagent, health, need, and sanitation systems;
7. update knowledge, security, incidents, economy, and progression;
8. finalize immutable events;
9. build knowledge, alert, and render projections;
10. write a scheduled deterministic state hash.

System stages are registered by core ID and have a fixed integer order in the
engine. Mods cannot insert an arbitrary stage. A documented hook runs at a
named point within its owning stage.

## Cadence

Each scheduled system declares a positive integer tick interval and phase:

```text
due(tick, interval, phase) = ((tick - phase) mod interval) == 0
```

The phase defaults to zero and is persisted when allocated dynamically. Core
cadences are:

| Cadence | Work |
|---:|---|
| 1 tick | commands, doors, movement, reservations, immediate health |
| 2 ticks | active atmosphere/fire frontier |
| 5 ticks | utility controls, urgent needs, hazard replanning |
| 10 ticks | ordinary work planning and machine cycles |
| 30 ticks | room state, sanitation, social observation |
| 60 ticks | needs, accruals, markets, low-risk planning |
| 300 ticks | maintenance forecasts and disease progression |
| 600 ticks | deterministic state checkpoint |
| 28,800 ticks | shift settlement, grade, contracts, autosave |

Work is budgeted by stable count, never elapsed milliseconds. When a subsystem
cannot finish a large deterministic job in one tick, it stores a sorted cursor
and resumes next tick. A budget change may alter latency but must not alter the
final result or stable conflict order.

## Authoritative state

All values that can change an outcome use integers or the canonical fixed-point
units in the [simulation foundations](../design/01-simulation-foundations.md).
Lua numbers must stay in the exactly represented range `[-2^53 + 1, 2^53 - 1]`.
Overflow is a fatal invariant failure in development and a campaign-safe error
in release builds.

Collections use one of these representations:

- row-major arrays for dense tile fields;
- sorted numeric-ID arrays plus ID lookup tables for objects;
- sorted tuple arrays for graph edges and reservations;
- append-only ordered ledgers for money and evidence;
- queues with explicit sequence numbers for commands/events.

`pairs()` may be used for non-authoritative diagnostics only. Any authoritative
map is converted to a sorted key list before iteration. Stable comparison must
fully break ties; the last key is always a stable ID or registration sequence.

Every object has one owner. Cross-system reads use immutable queries; writes use
commands or ordered internal transition requests. Systems commit their stage
output before the next stage reads it.

## Randomness

Campaign creation stores one root seed. The core derives independent named
Park–Miller-compatible streams by a stable project hash of
`root_seed + stream_name`; stream names are public save contracts.

```text
incident
crew_generation
market
medical
machine_failure
agriculture
```

A system may consume only its owned stream. Entity-local cosmetic or variant
choice derives a temporary seed from the stable event/entity ID, avoiding
perturbation of unrelated streams. The complete state of every consumed stream
is saved. Rendering, UI, particles, and audio never consume core RNG.

## World and remote maps

The permanent station is exactly one 192×192 tile plane by default. Each map
has a stable `MapId`, dimensions, topology revision, and row-major fields.
Mining, debris, derelicts, and expedition locations are separately loaded
single-plane maps connected by transfer edges; they are not Z-levels.

Remote maps use:

- full cadence while viewed, occupied, hazardous, or involved in an active
  transfer;
- coarse 60-tick aggregate steps otherwise;
- exact scheduled arrivals, incidents, injuries, and resource changes at their
  absolute ticks; and
- a deterministic expansion from coarse to full state using saved aggregate
  state and map-local RNG.

A coarse map may not contain an unresolved interaction requiring tile-level
ordering. Such an interaction promotes it to full cadence before resolution.

## Fault handling and observability

- A rejected command emits `core:event/command-rejected`; it does not partially
  mutate state.
- A failed invariant stops advancement before snapshot publication, keeps the
  last good autosave, writes a diagnostic bundle, and offers reload/disable-mod.
- Presentation failure disables the affected renderer/audio feature and allows
  simulation to remain paused; it cannot corrupt core state.
- Each stage exposes deterministic work counts and non-authoritative wall-time
  metrics. Profiling data is excluded from saves and state hashes.
- Diagnostic bundles include build, platform, exact mod locklist, recent
  commands/events, checkpoints, logs, and redacted settings. They never include
  arbitrary user files.

## Architectural acceptance

1. `rg 'love\\.' src/core` returns no matches.
2. A seeded command journal produces identical hashes in two fresh processes.
3. Rendering disabled, audio disabled, and headless test adapters all produce
   the same authoritative hashes.
4. Shuffling insertion order in fixture definitions does not change registry,
   schedule, pathfinding, or simulation results.
5. Save/reload at every system-stage boundary resumes at the next whole tick
   with the same result as uninterrupted execution.

The runtime is pinned initially to
[LÖVE 11.5](https://github.com/love2d/love/releases/tag/11.5). Concord's
documented pools and ordered system registration are useful implementation
mechanisms, but they do not replace Sim Station's explicit stable-order rules
([Concord](https://github.com/Keyslam-Group/Concord)).
