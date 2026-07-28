# Power machine fidelity research

## Record

- Canonical task: `/root/architecture_scope/power_machine_research`
- Display name: not available
- Parent task: `/root/architecture_scope`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: consolidated visible completion report
- Assignment availability: reconstructed from the parent task and delivered
  report
- Upstream revision:
  `1b2b250abb5be747d55e274de0203a59cfc8da78`
- Files changed by the agent: none

### Assignment

The exact assignment message is no longer visible. The observable scope was a
read-only source-fidelity investigation of Goonstation's machine scheduler and
Atlas power families: APC, SMES, TEG generator, and circulators. The expected
output covered map presence and overrides, defaults, processing cadence,
power/energy accounting, controls, wires, faults, maintenance, hazards, NPC
verbs, deterministic adaptations, and source citations.

### Observable chronology

1. The agent was spawned by `/root/architecture_scope`.
2. It researched the pinned scheduler, Atlas placements, APC, SMES, and TEG
   sources.
3. It delivered its findings to the parent.
4. It completed without changing files or sparse-checkout state.

## Consolidated visible report

### Atlas power census and importer findings

- Atlas contains 81 APCs.
- It contains six base SMES units.
- The TEG is one aligned triad: hot circulator at source coordinate
  `(123,180)`, generator at `(124,180)`, and cold circulator at `(125,180)`.
- Every Atlas SMES overrides `chargelevel` to 15,000 and `output` to 10,000.
  Two start with charge 1,000,000; four inherit the 20,000,000 default.
- The earlier compiled scenario dropped one co-located SMES and both
  circulators. The importer therefore needs layered fixtures rather than a
  one-anchored-machine-per-tile adapter.

### Scheduling

The general power machines effectively process every 3.2 seconds: the common
machine controller runs every 4 ds and ordinary machinery is in the eighth
bucketed tier, yielding 32 ds callbacks. Circulator maintenance runs every
16 ds while the generator performs TEG gas transfer and generation on its
32 ds cadence.

`base_tick_spacing` is multiplier normalization, not callback cadence. The
runtime must save the process tier, bucket, due decisecond, and multiplier
remainder/inputs separately.

### APC contract

The APC is an area power controller, internal cell, access-controlled control
surface, wire panel, and repairable fault-bearing machine rather than a
generic static battery.

Required state and behavior include:

- a 2,500-unit internal cell at 90% by default;
- equipment, lighting, and environment channels, each using source four-state
  values rather than a boolean;
- breaker/operating state, charge mode, interface lock, cover lock, open
  cover, exposed wires, terminal presence, controller repair state, and
  terminal repair state;
- internal-cell-first settlement and later reimbursement from the grid;
- automatic charge-dependent shedding: loss at 0%, equipment shedding below
  15%, lighting shedding below 30%, and channel restoration as charge
  recovers;
- recovery/low-power alert behavior, including recovery above 75%;
- engineering access and distinct physical-human, silicon-remote, and wired
  datanet operations;
- a campaign-wide randomized mapping of four logical wires: ID scan, main
  power 1, main power 2, and AI control;
- temporary pulse effects with authoritative decisecond expiry;
- ordered controller and terminal repair/deconstruction sequences;
- EMP, shock, overload-lighting, explosion, and battery hazards.

The four-state channel, settlement, and wire behavior must remain visible to
NPC diagnosis and planning. A planner needs semantic actions for inspection,
authentication, cover/panel operations, breaker/charge/channel controls,
cell/terminal work, individual wire cut/mend/pulse operations, and each
ordered repair step.

### SMES contract

The SMES has distinct input and output power networks and stored energy. Its
important source behavior includes:

- default capacity 100,000,000, default stored charge 20,000,000, and default
  30,000 input/output targets before map overrides;
- separately controllable charge/input and output/online modes;
- integer controls from 0 through 200,000;
- delayed activation after three qualifying supply samples rather than
  instant charging;
- unused-output reclamation using previous-cycle load accounting;
- loss of online state when empty or disconnected;
- EMP charge loss and the dangerous-short fault;
- terminal, cable/network, and staged construction/deconstruction/repair
  behavior.

The Atlas instance overrides listed above are authoritative data, not a new
subtype or post-spawn patch.

### TEG and circulator contract

The TEG consists of the generator and two directional circulators connected to
separate hot and cold gas loops. Required state includes:

- role/direction and validated alignment links for both circulators;
- each circulator's inlet/outlet gas state, target/override pressure,
  pressure-driven blower demand, flow history, warning state, lubricant and
  reagent contents, leak state, and maintenance process;
- generator thermocouple material and efficiency, hot/cold linkage, energy
  and output history, warning/grump state, and hazard state;
- conservative heat exchange between the two gas streams;
- generated output derived from transferred thermal energy and thermocouple
  efficiency, with integer/fixed-point remainders saved rather than silently
  rounded away;
- ordered circulator leak and generator thermocouple service sequences;
- pressure, temperature, reagent, low-lubricant, high-output, and damaged-part
  warnings/hazards.

The report recommended generic reagent reaction hooks for later unusual TEG
effects instead of hard-coding every source gag into the power solver.

### Proposed native composition

The power implementation should compose:

- `PowerPort`, producer/consumer roles, network identity, current/previous
  demand, and stable settlement order;
- `EnergyStorage` for SMES/APC capacity, charge, rates, modes, and
  fixed-point remainders;
- APC area-channel state, `WirePanel`, access, controller/terminal faults, and
  ordered repair plans;
- `GasPort`, circulator state, reagent/lubricant reservoirs, TEG core, and
  thermocouple state;
- serializable machine verbs and typed deterministic events.

Observable source behavior is preserved, while unordered processing and
bookkeeping bugs are not copied accidentally. Any deliberate bug fix must be
identified in a fidelity ledger.

## Decision disposition

### Accepted

- The exact Atlas power census and six SMES overrides.
- Layered fixtures and explicit TEG triad relationships.
- 32 ds general power-machine cadence and 16 ds circulator maintenance.
- Rich APC channel/cell/access/wire/repair behavior.
- Distinct SMES input/output networks and delayed accounting.
- Gas-linked, pressure-driven TEG composition with maintained parts and
  hazards.

### Adapted

- BYOND powernet callbacks become deterministic event phases and stable
  settlement.
- Floating energy/heat calculations become integer or documented fixed-point
  operations with serialized remainders.
- Source interactions become typed actions usable by crew and silicon
  planners.

### Rejected

- Treating APC, SMES, or TEG as fixed-watt decorative fixtures.
- Flattening co-located machines.
- A single undifferentiated battery abstraction for APC and SMES.

### Unresolved

- Exact network settlement and unused-output reimbursement implementation.
- Full TEG heat/power equation vectors and reagent/hazard parity.
- Ordered repair, construction, deconstruction, EMP, shock, and explosion
  execution.
- Source-bug disposition after focused test-vector review.

## Sources

- [Machine scheduler](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/controllers/process/machines.dm#L30-L105)
- [APC state and defaults](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L36-L89)
- [APC controls and interactions](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L639-L970)
- [APC wires](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L1131-L1244)
- [APC accounting and shedding](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/apc.dm#L1262-L1477)
- [SMES definition and construction](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/smes.dm#L21-L86)
- [SMES processing](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/smes.dm#L212-L315)
- [TEG circulator](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/TEG.dm#L54-L418)
- [TEG heat and generation equation](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/TEG.dm#L840-L943)
- [TEG maintenance](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/TEG.dm#L1235-L1490)
