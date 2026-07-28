# Goon-compatible machine fidelity

## Purpose and compatibility boundary

Sim Station implements machinery in pure Lua; it does not execute DM, emulate
BYOND, or reproduce Goonstation's inheritance tree. For machine definitions
declaring the `goon-near-1` profile, however, observable behavior at pinned
Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78` is the compatibility contract.

The contract includes:

- defaults, states, subtypes, formulas, thresholds, processing cadence, wire
  effects, access checks, maintenance sequences, inventories, resource
  transfers, signals, faults, and hazards;
- meaningful physical, UI, silicon, radio, and datanet operations;
- validated literal map-variable overrides;
- source quirks unless an explicit reviewed ledger entry identifies an
  intentional fix.

The following engine adaptations preserve rather than weaken that contract:

- source callbacks become deterministic scheduled Lua behavior;
- source floating calculations become integer or documented fixed-point
  calculations with serialized remainders;
- unordered list/network processing receives a complete stable-ID order;
- blocking prompts and action bars become serializable commands and crew work;
- source icon/TGUI state becomes a non-authoritative presentation projection.

A balance change is not a compatibility fix. It MUST use a separately named
content/profile variant so a save, test, mod, and player can distinguish it
from `goon-near-1`.

## Authoritative decisecond schedule

One Sim Station simulation tick remains one in-world second. Machine and
physical-action timing uses an authoritative decisecond calendar inside stage
5 of that tick. The full Goon-parity target uses:

```text
one global tick = 10 machine deciseconds
event key =
  (due_ds, source_class_order, owner_entity_id, callback_id, sequence)
```

The source machine controller advances every four deciseconds. General
machine intervals are:

| Processing tier | Controller turns | Interval |
| --- | ---: | ---: |
| full | 1 | 4 ds |
| half | 2 | 8 ds |
| quarter | 4 | 16 ds |
| eighth | 8 | 32 ds |
| sixteenth | 16 | 64 ds |
| thirty-second | 32 | 128 ds |

Ordinary machinery defaults to the eighth tier, so APC, SMES, manufacturer,
and TEG generator callbacks normally run every 32 ds. The target source-class
ordering within a due decisecond is:

1. atmosphere machines, every 16 ds;
2. pipe networks, every 16 ds with a 4 ds phase offset;
3. powernet reset, every 32 ds with an 8 ds phase offset;
4. general machines in processing-bucket and stable entity order;
5. delayed machine/action effects in stable event order.

[`base_tick_spacing = 6`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/controllers/process/machines.dm#L30-L105)
normalizes lag multiplication; it does not schedule callbacks:

```text
mult_base_ds = 6 × 2^(processing_tier - 1)
mult_cap_ds  = 60 × 2^(processing_tier - 1)
mult         =
  clamp(now_ds - last_process_ds, mult_base_ds, mult_cap_ds)
  / mult_base_ds
```

At the default eighth tier, callbacks remain 32 ds apart while the multiplier
base is 48 ds and cap is 480 ds. The runtime MUST preserve those separate
values.

### Current executable ordering

The current `Machine.step_all` drains ten deciseconds per outer tick. At each
decisecond it processes:

1. due atmosphere-class machine modules in stable entity-ID order;
2. due general-class machine modules in stable entity-ID order; then
3. family-owned delayed effects in stable entity-ID order.

The simplified world atmosphere and power solvers still run at their outer-tick
cadences before this machine window. Pipe networks are not yet a decisecond
event class, and power-net reset is not yet a 32 `ds` event with the upstream
`+8 ds` phase. The pipe `+4 ds` and power-net `+8 ds` positions above are the
normative parity target and acceptance-test slots, not claims about the current
runtime. Their absence remains deferred until the relevant conservative network
models exist.

`simulation:step()` MUST drain every currently implemented due machine callback
in its ten-decisecond window. It MUST NOT skip, coalesce, or postpone one to
meet a wall-clock budget. If the core cannot keep up, simulation becomes slow
relative to real time under the existing retained-credit policy.

The full target event-ordering tuple is public replay behavior. The current
implementation scans machines in stable order. A heap or timing wheel MAY
replace that scan only when it produces the identical applicable ordering and
state hash. Sleeping machines wake only for a subscribed process, due action,
signal, topology/inventory change, or explicit command.

## Source layout and behavior ownership

Machine code is organized for local review and vibecoding: one Lua module owns
one machine family, and files are grouped by the station department that
maintains that family.

```text
src/core/machine.lua                         shared dispatcher/lifecycle
src/core/machines/init.lua                   deterministic registry
src/core/machines/shared.lua                 family-neutral helpers
src/core/machines/atmospherics/
  passive_vent.lua
  portable_scrubber.lua
  vent_pump.lua
src/core/machines/cargo/
  barcode_computer.lua
  cargo_pad.lua
  supply_console.lua
src/core/machines/engineering/
  apc.lua
  smes.lua
  teg_circulator.lua
  teg_generator.lua
src/core/machines/manufacturing/
  manufacturer.lua
  nanofab.lua
  reclaimer.lua
```

This layout is a maintainability contract:

- `src/core/machine.lua` owns definition/instance validation, creation and
  legacy upgrade, generic action and parameter gates, common panel/wire verbs,
  power dispatch, the stable decisecond traversal, damage dispatch, save-safe
  state, and event emission. It routes to a family module; it does not own a
  family's control transitions, process formula, power adjustment, fault,
  damage threshold, production lifecycle, or failure behavior.
- The dispatcher's current `LEGACY_*` fixture tables are a bounded migration
  bridge for kind-only scenarios and old saves. They may identify canonical
  definitions/behaviors and fallback initialization metadata, but MUST NOT gain
  new active family handlers, process branches, fault rules, or formulas.
- Each machine family has exactly one department-sorted module. That module
  declares its behavior IDs, definition IDs, and compatibility fixture kinds,
  then owns all family handlers and any `initialize`, `gate`, `wire_effect`,
  `power_request`, `is_connected`, `refresh_state`, `process`, `delayed`,
  `damage`, or `queue_recipe` behavior it implements. Compatibility fixture
  aliases may resolve to the same family module; they do not justify a second
  behavior implementation.
- `src/core/machines/init.lua` contains one explicit, byte-stable module list,
  ordered by department and filename. Registration rejects duplicate behavior,
  definition, or fixture-kind ownership. Runtime lookup prefers behavior ID,
  then definition ID, then the compatibility fixture kind. Filesystem
  enumeration, unordered discovery, or load-order-dependent replacement is
  forbidden in authoritative registration.
- `src/core/machines/shared.lua` contains only family-neutral primitives such
  as stable set/array tests, structured rejection construction, wire lookup,
  and conservative recipe inventory helpers. It MUST NOT branch on a machine
  family, contain a family source constant/formula, register an action handler,
  or mutate family lifecycle state.
- A new supported machine adds its schema-2 definition, exactly one family
  module, one explicit registry entry, source/fidelity evidence, and focused
  deterministic tests. Family behavior is not appended to the dispatcher or
  hidden in a broad department “misc machines” module.

All of these modules remain pure authoritative Lua and MUST NOT reference
`love.*`, presentation state, wall time, filesystem discovery, or networking.
This internal registry is not yet the bounded public behavior-registration API
described below.

## Three-layer machine model

### Immutable definition

A machine is ordinary namespaced mod content with schema 2:

```json
{
  "id": "org.simstation.core:machine/goon-apc",
  "kind": "machine",
  "schema": 2,
  "fixture_kind": "apc",
  "behavior": "org.simstation.core:machine-behavior/goon-apc-v1",
  "source": {
    "repository": "goonstation/goonstation",
    "commit": "1b2b250abb5be747d55e274de0203a59cfc8da78",
    "type_path": "/obj/machinery/power/apc",
    "files": ["code/modules/power/apc.dm"]
  },
  "process": {
    "class": "general",
    "tier": 4,
    "interval_ds": 32,
    "mult_base_ds": 48,
    "mult_cap_ds": 480
  },
  "power": {
    "requires_power": false,
    "channel": "none",
    "idle_w": 0,
    "priority": 1
  },
  "state_defaults": {},
  "map_override_fields": [],
  "wires": [],
  "actions": [],
  "fidelity": {
    "profile": "goon-near-1",
    "ledger": []
  }
}
```

Preparation flattens relevant DM inheritance into data. Runtime content MUST
NOT retain or evaluate a DM expression. A scenario instance may override only
fields named in `map_override_fields`, and each override MUST be a validated
JSON string, boolean, or exactly represented integer.

Definitions declare behavior IDs, action schemas, source symbols, and fidelity
status. They MUST NOT embed executable code. Base content uses the same schema
and registry path available to any normal mod.

### Registered behavior

Trusted pure Lua associates a namespaced behavior ID with bounded handlers.
A complete public API is expected to expose:

```lua
api:register_machine_behavior(id, descriptor, handlers)
api:register_machine_verb(id, descriptor, handler)
api:register_machine_signal(id, payload_schema)
```

Behavior entry points MAY include initialization, process, affordance query,
verb execution, signal receipt, power/topology/inventory changes,
deconstruction, and rebuild.

A future `MachineContext` MUST expose immutable definition/component/port
queries and constructors for validated effects. It MUST NOT expose `love.*`,
filesystem, network, wall clock, coroutine scheduling, raw world tables, or
arbitrary cross-entity mutation.

Valid effects include component/status changes, callback scheduling,
power/gas/reagent/material/inventory transfers, reservation changes, output
creation, damage, signals, events, work offers, and ledger transactions.
Energy and physical/economic resources MUST balance or name an explicit
source/sink.

### Authoritative instance

Each placed machine is schema-2 save state with:

- stable entity and scenario-fixture IDs;
- definition and behavior IDs;
- source type path and retained literal map overrides;
- tile, area/department, tags, and logical appearance state;
- lifecycle/status/health/fault state;
- power contract, requested and served watts, and connection state;
- processing class, tier, bucket, interval, multiplier range, subscription,
  process count, and last/next due decisecond;
- machine-specific data, wires, inventories, queues, reservations,
  remainders, ports, and links;
- in-progress action and completion state.

Instances contain no closures and no pointer to a mutable definition table.
Presentation reads a snapshot projection and does not mutate this state.

## Machine verbs and rejection reasons

Every meaningful upstream hand/item/UI/AI/radio/data/wire/maintenance action is
a typed `MachineVerb`. An action definition declares:

```text
id and pinned source symbol
registered handler
implemented flag
actor kinds
range: none | adjacent | remote-or-adjacent | authenticated remote
access expression
required capabilities, tools, items, and machine states
input/target parameter schema
duration_ds and interruption rules
resource reservations and commit point
result event schema
knowledge, work, and skill tags
```

Physical, silicon, director policy, UI, console, and NPC systems MUST invoke
the same verb gate. A command may identify the actor, machine, action, and
JSON-safe parameters; it may not mutate machine state directly.

The result is either a committed action or a stable structured rejection.
The current vocabulary includes:

```text
unknown-action        not-implemented       unregistered-handler
actor-missing         incapacitated         not-adjacent
remote-disabled       access-denied         wrong-tool
destroyed             broken                no-power
panel-closed          panel-open            cover-locked
cover-open            interface-locked      interface-broken
invalid-mode          invalid-parameter     invalid-blueprint
invalid-wire          wire-already-cut      wire-not-cut
wire-cut              queue-full            missing-item
insufficient-charge
```

Family behaviors MAY add documented codes such as `inventory-full`,
`occupied`, `reserved`, `pipe-disconnected`, `cable-disconnected`,
`unsafe-pressure`, and `cooldown`. Codes and structured details are public
automation/UI contracts. Human-facing text is presentation content, not
planner state.

### NPC planning contract

Machine complexity becomes usable NPC complexity through affordance queries:

1. a player policy/order describes a desired outcome;
2. the planner queries sorted machine verbs and their rejection reasons;
3. available verbs become configure, operate, load, unload, haul, inspect,
   diagnose, repair, or sabotage work;
4. an NPC claims work with a fully stable score/tie-break order;
5. actor, tool, item, machine, route, and destination are reserved;
6. the NPC navigates and invokes the same verb as a player-controlled actor;
7. preconditions are checked at reservation, start, commit, and completion;
8. effects commit atomically and emit typed events;
9. interruption or rejection creates explicit recovery, acquisition,
   diagnosis, cleanup, or follow-up work.

An NPC may use `wrong-tool`, `missing-item`, `not-adjacent`, `access-denied`,
`no-power`, or a topology rejection as an actionable subgoal. Silicon and
authenticated controllers may use remote verbs only through functioning
machine/data routes. The director never receives an omniscient bypass.

## Fidelity ledger

Every machine definition carries a machine-readable ledger. Each row names one
testable behavior and its pinned source:

| Status | Contract |
| --- | --- |
| `exact` | Defaults, branches, formula, timing, and observable outcome match |
| `deterministic-equivalent` | Semantics match; ordering/RNG scheduling is stable |
| `engine-adapted` | UI, action, callback, or sleep mechanism changed; outcome preserved |
| `intentional-fix` | A confirmed source defect is deliberately not reproduced |
| `deferred` | The source feature is absent from this milestone |
| `not-applicable` | Admin, round, or multiplayer behavior is outside this product |

An `intentional-fix` entry MUST contain a precise source citation, rationale,
observable replacement behavior, and regression test. A `deferred` row MUST
remain visible to mods, documentation, and acceptance tracking. An
unimplemented action must reject with `not-implemented`; it cannot silently
succeed as flavor.

Fidelity status belongs to the exact definition/behavior version and enters
the content lock. Changing an observable exact behavior requires a new
compatible version or documented migration.

## Corrected Atlas machine baseline

The pinned Atlas crop currently imports 92 areas and this exact selected set:

| Definition family | Fixture kind | Count |
| --- | --- | ---: |
| APC | `apc` | 81 |
| SMES | `battery` | 6 |
| TEG generator | `generator` | 1 |
| TEG circulator | `circulator` | 2 |
| passive vent | `vent` | 3 |
| tox-lab vent pump | `vent_pump` | 1 |
| portable scrubber | `portable_scrubber` | 3 |
| manufacturer | `fabricator` | 20 |
| portable reclaimer | `reclaimer` | 7 |
| nanofab | `nanofab` | 2 |
| cargo pad | `cargo_pad` | 5 |
| supply console | `supply_console` | 2 |
| QM barcode computer | `barcode_computer` | 1 |
| **Total** |  | **134** |

The preliminary research census was 133 because it found only two portable
scrubbers. The exact importer/source re-parse found three. The corrected 134
count is the normative fixture assertion.

All six SMES set input to 15,000 and output to 10,000 through retained map
overrides; two start with charge 1,000,000 and four with 20,000,000. The TEG
triad retains its two circulators and generator. The importer preserves
multiple compatible fixtures on a tile instead of flattening a collision.

Each selected fixture MUST retain a namespaced `definition_id`, exact source
type path, direction, stable fixture ID, and allowlisted literal overrides.
Omitting a selected source object is a fixture validation failure. DMM remains
immutable authoring/provenance input; runtime reads only the generated native
scenario.

## Current executable slice

The 2026-07-28 milestone establishes the contract as a deliberately incomplete
but executable vertical slice:

- strict machine schema-2 validation and 13 source-pinned first-party
  definitions;
- one department-sorted Lua module per imported machine family, selected by a
  deterministic behavior/definition/fixture registry behind the shared
  dispatcher;
- corrected 134-fixture Atlas import, layered placement, non-station area
  retention, and safe literal SMES overrides;
- authoritative schema-2 instances with definition/behavior/source IDs,
  status, health, power, scheduler, state, wire, fault, and fixture identity;
- deterministic shared wire-color permutation and serializable wire state;
- a decisecond subcalendar with atmosphere-before-general ordering and stable
  machine traversal;
- typed affordance queries, action execution, parameter validation, structured
  rejection reasons, adjacency, access, tool, panel, power, and remote gates;
- APC controls and deterministic wire effects, including timed pulses and
  charge-threshold channel transitions;
- manufacturer queue controls, queue/output cap, speed/repeat/pause/continue,
  source power formula, completion recheck/consumption, power interruption,
  wire behavior, health thresholds, and deterministic malfunction stream;
- nanofab immediate production path;
- SMES control/default/map-override state and an initial storage cycle;
- portable scrubber, vent-pump, circulator, and cargo-pad controls;
- legacy instance upgrade defaults for existing saves/scenarios.

The definition ledger, not this prose list, is authoritative for each
feature's exact status. Until the full acceptance suite passes, an
`engine-adapted` or `deterministic-equivalent` label is not a claim of complete
family parity.

## Explicitly deferred work

The current ledgers identify these source behaviors as absent:

- APC cell/grid accounting and ordered controller/terminal repair;
- SMES two-network accounting, failure, construction, and repair;
- TEG pressure/flow/lubricant simulation, conservative heat-to-power equation,
  thermocouple maintenance, and hazards;
- passive-vent, vent-pump, and portable-scrubber pipe/gas/reagent conservation;
- manufacturer physical material entities, manudrives, banking, Rockbox,
  blueprint and full subtype catalogs;
- reclaimer physical sequential composition recovery and fractional material
  remainder;
- nanofab physical slot binding and material/property inheritance;
- supply-console market, budget, trader, purchase, shipment, and export
  ledger;
- barcode print duration, labels, account association, and sell-area
  appraisal;
- cargo transporter cell expenditure and physical freight movement;
- complete machine signals/radio/data routes, deconstruction/rebuilding,
  access credential sources, EMP/emag, fault/hazard, and ordered repair
  systems;
- bounded public behavior/verb registration and transactional mod effects;
- verb-derived multi-step NPC acquisition, navigation, diagnosis, and
  recovery planning.

Passive atmosphere behavior is deferred rather than approximated with gas
creation/deletion. Cargo pads remain zero-power receivers. Atlas cargo remains
edge-fling freight; Nadir transception is a separate future machine family.

## Save, load, hash, and replay contract

Machine state is committed only at the outer tick boundary after all due
decisecond effects complete. A save includes:

- global `machine_time_ds`, event/callback sequence, and source-class phase;
- definition/behavior IDs, schema versions, parity profile, exact mod/content
  lock, and scenario fixture/source identity;
- lifecycle, status, health, faults, machine-specific data, and fixed-point
  remainders;
- process class, tier, bucket, interval, multiplier base/cap, subscription,
  process count, and last/next due decisecond;
- global wire permutation, each wire's logical/color/intact state, and pulse
  expiry;
- power port/network identity, requested/served watts, stored energy,
  prior-cycle accounting, channel modes, and connection state;
- inventories, gas/reagent/material contents, queues, reservations, committed
  inputs, output targets, and blocked reason;
- in-progress verbs with actor, tool/item, target, start, commit, and end
  deciseconds;
- topology revision and stable endpoint links;
- machine RNG stream state.

Heaps, timing wheels, lookup maps, and graph indexes are derived. Loading
reconstructs them in stable ID order and MUST NOT consume authoritative RNG.
Legacy instances are migrated deterministically to schema 2; a migration may
fill absent defaults but may not reinterpret an explicit saved value.

State hashes include all machine fields capable of changing outcomes,
including scheduler phase, queues, wires, inventories, statuses,
reservations, ports, remainders, and RNG. They exclude presentation aliases,
sprites, UI expansion state, particles, sounds, and profiling counters.

A save/load in the middle of production, a timed wire pulse, a fault repair,
or an NPC verb must continue identically to an uninterrupted run. Replay
checks the same outer-tick hashes; the decisecond calendar is fully represented
inside each checkpoint.

## Acceptance roadmap

### Gate 1 — fixture and definition contract

1. Import pinned Atlas and assert all 92 areas, all 134 selected fixtures,
   subtypes, directions, source paths, co-location, TEG triad, and six SMES
   override sets.
2. Reject an unknown machine definition, unsafe/nonliteral override, duplicate
   action/wire identifier, invalid cadence, and unsupported ledger status.
3. Randomize definition and fixture insertion order and require identical
   registry, instance, and initial state hashes.
4. Require every supported definition/behavior to resolve to exactly one
   department-sorted family module; reject duplicate registry ownership and
   fail review if family handlers or formulas enter the dispatcher/shared
   helpers.

### Gate 2 — scheduler and verbs

1. Assert every source tier interval, bucket phase, special-loop phase, and
   atmosphere/general/delayed same-decisecond ordering.
2. Exercise every implemented verb success and every declared rejection,
   including human/silicon, adjacent/remote, access, tool, panel, power, and
   parameter distinctions.
3. Save/load across process due times, timed wire pulses, and in-progress
   actions.

### Gate 3 — family source vectors

Use pinned source-vector tests for defaults, control transitions, thresholds,
durations, formulas, faults, wires, and maintenance. Golden microstations
cover:

- generator → SMES → APC → environment/equipment/lighting channels;
- TEG hot/cold loops, pressure work, heat conservation, and output;
- passive vent and bounded pump gas conservation;
- portable scrubber storage, filter behavior, reagents, and power;
- physical material load → manufacturer completion → output;
- reclaimer sequential fractional recovery;
- nanofab slot binding and material inheritance;
- barcode → shipment → haul/launch → appraisal/settlement.

Every gas, reagent, material, energy, and currency transfer must conserve its
quantity or record a typed source/sink and any fixed-point remainder.

### Gate 4 — planner and recovery

Run end-to-end NPC cases that acquire access/tools/items, navigate, operate the
exact verbs in order, recover from interruption, diagnose source-style faults,
and clean up physical output. Silicon cases must prove remote routing and
physical-access limits rather than bypass them.

### Gate 5 — scale and parity release

1. Soak corrected Atlas with 40 and 100 NPCs.
2. Run a synthetic 5,048-machine station with most machines sleeping.
3. Require identical hashes after shuffled insertion, save/reload, headless
   execution, and multiple supported Lua/LÖVE targets.
4. Require a pinned citation and regression test for every intentional
   divergence.
5. Publish family parity only when its ledger has no undocumented behavior and
   all non-deferred rows pass.

## Primary evidence

- [Goon machine constants and tiers](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/machinery.dm#L8-L62)
- [Goon machine controller](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/controllers/process/machines.dm#L30-L105)
- [Common machinery lifecycle and interaction gates](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery.dm#L10-L213)
- [APC](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L36-L1477)
- [SMES](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/smes.dm#L21-L388)
- [TEG and circulators](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/TEG.dm#L54-L1490)
- [Manufacturer](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer.dm#L1-L1613)
- [Atmosphere, production, and cargo research archive](../agents/atmos-production-cargo-fidelity.md)
- [Power-machine research archive](../agents/power-machine-fidelity.md)
- [Architecture research archive](../agents/machine-fidelity-architecture.md)
