# Faraday — Goon-compatible machine architecture follow-up

## Record

- Canonical task: `/root/architecture_scope`
- Display name: Faraday
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible final report
- Assignment availability: reconstructed from the user request, parent task,
  and visible final report
- Upstream revision:
  `1b2b250abb5be747d55e274de0203a59cfc8da78`
- Files changed by the agent: none

This is a later research episode by the same canonical agent archived in
[`architecture-scope.md`](architecture-scope.md). The earlier record remains
historical; this record captures the machine-fidelity follow-up.

### Assignment

The exact assignment message is no longer visible. The observable assignment
was to research an engine-native architecture capable of preserving the
observable behavior of Goonstation machinery nearly one-for-one, including
timing, power, state, interactions, wires, maintenance, NPC use, mods,
persistence, and the machine families selected from Atlas. The agent could
delegate family research but was not to edit the repository.

### Observable chronology

1. The existing `architecture_scope` agent was resumed for the machine
   fidelity decision.
2. It delegated focused research to
   `/root/architecture_scope/power_machine_research` and
   `/root/architecture_scope/atmos_prod_cargo_research`.
3. It inspected the pinned Goonstation machinery scheduler, common machinery
   gates, access semantics, and family reports.
4. It delivered the architecture report summarized below and reported no file
   changes.
5. A later exact Atlas re-parse corrected the report's preliminary
   133-machine count to 134: Atlas contains three, not two, portable
   scrubbers. The correction is recorded here without rewriting the visible
   report.

## Visible report

### Adopted compatibility boundary

Sim Station should implement Goon machinery as native, data-defined machines.
It must not execute DM or reproduce BYOND inheritance as its runtime
architecture. Upstream observable behavior is nevertheless the compatibility
contract:

- preserve defaults, states, formulas, thresholds, timing, wires, access,
  maintenance, inventories, resource transfers, signals, and failures;
- preserve subtype behavior and validated map-variable overrides;
- represent every meaningful `attack_hand`, `attackby`, UI action, `Topic`,
  drag/drop, AI action, radio command, repair, and deconstruction operation as
  a typed, serializable machine verb;
- preserve source quirks unless an explicit parity-ledger entry records a
  reviewed divergence.

Permitted execution adaptations are deterministic scheduling, fixed-point or
integer arithmetic with saved remainders, stable-ID ordering, serializable
work actions in place of blocking prompts/action bars, and presentation
projections in place of BYOND/TGUI state.

This decision supersedes the earlier recommendation in
[`goon-interaction-research.md`](goon-interaction-research.md) to omit detailed
item-on-machine verbs, wires, and tool disassembly from the management-game
model.

### Decisecond machine calendar

Goon's `MACHINE_PROC_INTERVAL` is four deciseconds. Its controller advances
one turn every four deciseconds, producing these general-machine intervals:

| Processing tier | Controller turns | Interval |
| --- | ---: | ---: |
| full | 1 | 4 ds |
| half | 2 | 8 ds |
| quarter | 4 | 16 ds |
| eighth | 8 | 32 ds |
| sixteenth | 16 | 64 ds |
| thirty-second | 32 | 128 ds |

Ordinary machinery defaults to the eighth tier, so APC, SMES, manufacturer,
and TEG generator callbacks are normally due every 32 ds. Special loops run
on the following phases:

1. atmosphere machines every 16 ds;
2. pipe networks every 16 ds, offset by 4 ds;
3. powernet reset every 32 ds, offset by 8 ds;
4. general machines after special loops on the same controller pass;
5. delayed machine and action effects.

`base_tick_spacing = 6` is not the callback schedule. It is the lag multiplier
base:

```text
base_ds = 6 × 2^(processing_tier - 1)
cap_ds  = 60 × 2^(processing_tier - 1)
mult    = clamp(now_ds - last_process_ds, base_ds, cap_ds) / base_ds
```

At the default eighth tier the callback interval is 32 ds, but the multiplier
base and cap are 48 ds and 480 ds. Normal elapsed time therefore clamps up to
`mult = 1`; this upstream distinction is deliberate compatibility behavior.

The proposed event key was:

```text
(due_ds, source_class_order, owner_entity_id, callback_id, sequence)
```

One Sim Station global tick advances ten machine deciseconds and drains every
event falling in that interval. Commands still enter only at tick boundaries.
When work exceeds the real-time budget, wall-clock presentation slows; due
authoritative callbacks are not skipped or postponed.

Persist tier, bucket, subscription, last/next due decisecond, callback
sequence, sleep state, and verb completion times. A future binary heap or
timing wheel may replace a scan without changing the ordering contract.

### Three machine layers

1. **Immutable definition.** Namespaced schema-2 content stores identity,
   source revision/type paths, flattened subtype data, processing class/tier,
   components, ports, verbs, appearance, and its fidelity ledger. Atlas map
   variables become allowlisted instance overrides.
2. **Registered behavior.** Trusted Lua registers a namespaced behavior ID.
   It reads bounded state and returns validated effects. Definitions contain
   no executable code.
3. **Authoritative instance.** A saveable entity stores stable IDs, versioned
   component state, scheduler state, connections, inventory, wires, faults,
   and process data. It never stores closures or mutable content pointers.

The component vocabulary proposed by the report covered identity, lifecycle,
status bits, condition, typed faults, power ports, energy storage, access,
wires, inventory, material/reagent/gas storage, process state, signal
endpoints, deconstruction, logical appearance, and work affordances.

Access expressions should preserve Goon's structure: outer groups are OR and
requirements within one group are AND. Credentials may come from held or worn
IDs, silicon cards, or implants. Generic action gates cover broken/power
state, incapacitation, range, required physical access, and silicon remote
use.

### Typed verbs and NPC planning

Each `MachineVerb` needs:

```text
id and source symbol
actor kinds and range/remote policy
access expression
required tools, capabilities, items, and machine states
input/target schemas
duration and interruption policy
reservations and commit point
behavior handler and outcome schema
knowledge/work tags and skill weights
```

The shared vocabulary includes inspect/diagnose, operate/configure,
load/eject, queue/cancel/reorder, panel and cover operations, wire
cut/mend/pulse, anchoring and topology work, ordered repairs, deconstruction,
reset, overload, emag, and authenticated data operations.

Stable rejection codes let UI and planners reason about failure rather than
parse text. The report called out `no-power`, `broken`, `powered-off`,
`maintenance`, `access-denied`, `remote-disabled`, `not-adjacent`,
`incapacitated`, `panel-closed`, `cover-locked`, `wrong-tool`,
`missing-item`, `inventory-full`, `occupied`, `reserved`,
`pipe-disconnected`, `cable-disconnected`, `unsafe-pressure`,
`insufficient-charge`, `cooldown`, and `invalid-mode`.

NPCs use the exact same verbs:

1. a player policy or order states an outcome;
2. the planner queries machine affordances;
3. work offers describe loading, configuring, operating, repair, diagnosis,
   or hauling;
4. an NPC claims work in stable score order;
5. actor/tool/item/machine/destination resources are reserved;
6. the NPC navigates and invokes the machine verb;
7. preconditions are checked at start, commit, and completion;
8. effects commit atomically and emit typed events;
9. follow-up hauling, cleanup, repair, or diagnosis is generated.

Remote operation requires a functioning authenticated data route. The player
does not receive an omniscient mutation path.

### Transaction and mod boundary

Behavior code should return a closed effect list for component/status changes,
scheduling, power, gas/reagent/material/inventory transfer, reservation,
output creation, damage, signals, events, work, and ledger transactions.
Energy and physical resources must balance or name an explicit source/sink.

The report recommended first-class public registration:

```lua
api:register_machine_behavior(id, descriptor, handlers)
api:register_machine_verb(id, descriptor, handler)
api:register_machine_signal(id, payload_schema)
```

Machine behavior entry points may cover initialization, processing,
affordances, verb execution, signals, power/topology/inventory changes,
deconstruction, and rebuilding. A bounded context may query immutable
definition/component/port state and construct typed effects. It may not expose
`love.*`, filesystem, network, wall clock, coroutines, raw world mutation, or
another entity's mutable tables.

Suggested typed hook points were machine-verb and recipe-start validation,
power-request transformation, and observation of status, signals, completed
verbs, faults, and outputs. Per-cell atmosphere hooks were rejected in favor
of gas-port transactions.

### Family conclusions

- **APC:** three four-state channels, a 2,500-unit cell initially at 90%,
  breaker and charge modes, cover/interface locks, cell/grid accounting,
  shedding at 0%, 15%, and 30%, recovery alerts above 75%, engineering
  access, four randomized wires, silicon/physical/data differences, and
  ordered controller/terminal repairs.
- **SMES:** separate input/output networks, delayed three-sample charging,
  unused-output reclamation, 0–200 kW controls, EMP loss, dangerous-short
  fault, and construction/deconstruction. All six Atlas units override input
  to 15 kW and output to 10 kW; two start at 1 MJ and four at 20 MJ.
- **TEG:** aligned hot and cold circulators, pressure-driven blowers,
  lubricant/reagent state, conservative heat exchange and generation,
  thermocouple efficiency/material, output history, warnings, hazards, and
  ordered leak/thermocouple maintenance.
- **Atmos:** passive vents conserve gas and use no power. Fixed pumps and
  scrubbers perform bounded pipe transfers. Portable scrubbers are powered,
  mobile machines with internal gas/reagent storage.
- **Manufacturer:** 20-item queue/output caps, ready/working/halted modes,
  speed limits, `200 + 750 × speed²` watts, physical inputs, recipes, drives,
  blueprints, banks, Rockbox, four wires, PNET, damage, completion recheck and
  consumption, and material inheritance.
- **Reclaimer/nanofab:** the portable reclaimer is unpowered, sequential,
  composition-aware recycling with persistent fractional remainder. The
  nanofab binds physical stacks to typed slots and immediately creates
  material-inheriting output; upstream's apparent queue is not implemented.
- **Cargo:** Atlas uses physical edge-fling freight, supply consoles, market
  and ledger, barcodes, sell regions, and simple cargo-pad receivers. Pads
  themselves are unpowered; the paired transporter consumes 25 cell units and
  takes three seconds. Nadir transception is a separate deferred system.

### Corrected selected Atlas census

The visible report estimated 133 fixtures because both the architecture and
atmosphere surveys counted two portable scrubbers. The subsequent exact
source re-parse found a third and established this selected-family baseline:

| Family | Count |
| --- | ---: |
| APC | 81 |
| SMES | 6 |
| TEG generator | 1 |
| TEG circulator | 2 |
| passive vent | 3 |
| tox-lab vent pump | 1 |
| portable scrubber | 3 |
| manufacturer | 20 |
| portable reclaimer | 7 |
| nanofab | 2 |
| cargo pad | 5 |
| supply console | 2 |
| QM barcode computer | 1 |
| **Total** | **134** |

The importer must retain layered/co-located fixtures, source type paths,
allowlisted literal overrides, portable machinery, TEG relationships, and
physical cargo endpoints. A selected object silently omitted by adaptation is
a fixture validation failure.

### Fidelity and persistence

Each behavior needs a machine-readable ledger:

| Status | Meaning |
| --- | --- |
| `exact` | Same defaults, branches, formula, timing, and outcomes |
| `deterministic-equivalent` | Same semantics with stable order/RNG timing |
| `engine-adapted` | Execution or UI mechanism changed, outcome preserved |
| `intentional-fix` | Reviewed upstream defect not reproduced |
| `deferred` | Source feature absent from this milestone |
| `not-applicable` | Multiplayer/admin/round behavior outside the product |

Balance changes must be separate profiles, not silent parity changes.
Intentional-fix candidates require source citations and regression tests.

Save and replay state includes definition/behavior/schema IDs, components and
integer remainders, scheduler phase, wire permutation and pulse expiry,
inventories/reservations/queues, resources, power accounting, in-progress
verbs, topology revisions, machine RNG streams, parity profile, and exact
content/mod lock. Derived heaps and graph indexes are rebuilt in stable-ID
order.

## Decision disposition

### Accepted

- Upstream observable behavior is the machine compatibility contract.
- Deterministic decisecond scheduling lives inside the existing global tick.
- Machine definitions, behavior IDs, and authoritative instances are separate.
- Typed verbs and stable rejection reasons are the common player, UI, mod, and
  NPC interface.
- Fidelity status is machine-readable rather than implied.
- The corrected selected Atlas baseline is 134 fixtures.

### Adapted

- Initial bootstrap execution may scan a stable machine list; the event key
  defines the later heap/timing-wheel implementation.
- Source UI and asynchronous action mechanisms become serializable commands
  and work actions.
- Source floating calculations become documented integer/fixed-point
  calculations with saved remainders.

### Rejected

- Executing DM or modeling its inheritance directly.
- Omniscient director-only machine mutation.
- Generic powered vents that synthesize atmosphere.
- Treating cargo pads as powered grid loads or Atlas freight as transception.
- Collapsing manufacturers, reclaimers, and nanofabs into one generic machine.

### Unresolved

- Full transactional behavior registration and bounded mod API.
- Complete powernet, pipe, gas, reagent, market, freight, repair, and
  deconstruction parity.
- Reviewed disposition of suspected upstream bugs.
- Expansion beyond the selected 134 fixtures toward all Atlas machinery.

## Sources

- [Machine constants and processing tiers](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/machinery.dm#L8-L62)
- [Machine controller order and cadence](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/controllers/process/machines.dm#L30-L105)
- [Common machinery lifecycle and interaction gates](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery.dm#L10-L213)
- [Access-expression semantics](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/procs/access.dm#L1-L104)
- [Equipment fault component](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/components/equipment_fault.dm#L5-L168)
- [APC implementation](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L36-L1477)
- [SMES implementation](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/smes.dm#L21-L388)
- [TEG implementation](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/TEG.dm#L54-L1490)
- Family-specific atmosphere, production, and cargo citations are preserved in
  [`atmos-production-cargo-fidelity.md`](atmos-production-cargo-fidelity.md).
