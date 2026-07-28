# Goon Interaction Research — station systems and map grammar

## Record

- Canonical task: `/root/goon_interaction_research`
- Display name: Goon Interaction Research
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible report
- Assignment availability: verbatim

### Assignment

> Inspect pinned local Goonstation code/maps at
> `assets/cache/goonstation` commit `1b2b250a` for interactions most relevant
> to Sim Station next vertical slice: doors/access, APC/power,
> atmos/vents/scrubbers, area/room identity, machinery,
> cargo/manufacturing, job/department placement. Trace concrete DM type
> paths/procs/vars and map placement patterns, but do not copy code or edit
> runtime. Produce actionable original-design recommendations with source
> paths and accepted/adapt/reject guidance in
> `docs/agents/goon-interaction-research.md`. Do not edit docs/agents
> README/manifest. No network. Send final report and then make no more edits.

### Observable chronology

1. Confirmed that the local Goonstation source is pinned at full commit
   `1b2b250abb5be747d55e274de0203a59cfc8da78`.
2. Traced access, door, APC, cable, atmospherics, machinery, manufacturing,
   shipping-market, job, landmark, and area implementations in the pinned DM
   source.
3. Parsed object and area placements in Cogmap2, Cogmap, Donut3, Kondaru, and
   Clarion. This was a read-only structural survey; no DMM content was copied
   into Sim Station.
4. Compared those findings with the current Sim Station core and first-party
   content definitions.
5. Produced the original-design recommendations below. No runtime or content
   files were edited by this task.

## Executive conclusion

Goonstation's most useful lesson is not a collection of individual machines.
It is the way several local systems meet at a named room boundary:

- an airlock controls passage, access, pressure isolation, and sometimes a
  door cycle;
- an APC associates a room with a power circuit, battery, and three load
  priorities;
- atmos devices transfer gas between the room and a connected pipe network;
- machinery registers with the room and consumes a named power channel;
- job access and workplace placement determine who can resolve a failure;
- cargo and manufacturing make supplies move through physical doors, staging
  areas, machines, and storage rather than appearing in an abstract pool.

Sim Station should preserve that interaction graph, while replacing
Goonstation's object inheritance, asynchronous world-time behavior, tool-click
verbs, and implicit map helpers with deterministic entities, serializable
commands, declarative content, and explicit validation.

The next useful vertical slice is therefore a **powered, pressurized cargo and
engineering loop**, not a larger collection of disconnected simulation
variables. It should let the player order raw stock, unload it at a physical
dock, haul it through an access-controlled door, reclaim and fabricate it,
power the machines through an APC, and observe work halt when power,
atmosphere, access, staffing, input, or output capacity fails.

## Research boundary and evidence

This report describes behavior and layout patterns. It does not reproduce DM
implementation code. All paths below are relative to the pinned
`assets/cache/goonstation/` snapshot.

Five station maps were sampled:

- `maps/cogmap2.dmm`
- `maps/cogmap.dmm`
- `maps/donut3.dmm`
- `maps/kondaru.dmm`
- `maps/clarion.dmm`

Every sampled DMM occupies a 300×300 coordinate canvas, but only 7,981 to
17,016 tiles were classified as station areas. Empty canvas size is therefore
not a useful target for Sim Station. The counts below are comparative evidence
for system density and placement grammar, not release fixtures or a proposal
to reproduce any one map.

| Map | Station tiles | Station area types | Airlocks | APCs | Firedoor helpers | Access helpers | Cycle helpers | Cable tiles | Atmos pipe tiles | Manufacturers | Supply consoles | Job starts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Cogmap2 | 15,256 | 142 | 473 | 136 | 429 | 296 | 59 | 4,541 | 1,248 | 31 | 3 | 118 |
| Cogmap | 12,736 | 145 | 409 | 137 | 318 | 272 | 56 | 4,392 | 703 | 26 | 2 | 105 |
| Donut3 | 17,016 | 152 | 455 | 146 | 307 | 404 | 49 | 5,011 | 109 | 24 | 4 | 114 |
| Kondaru | 12,322 | 143 | 487 | 140 | 255 | 283 | 29 | 4,092 | 473 | 28 | 4 | 128 |
| Clarion | 7,981 | 109 | 300 | 105 | 266 | 260 | 25 | 2,805 | 148 | 28 | 2 | 143 |

The striking ratios are more useful than exact totals:

- airlocks are frequent room-edge infrastructure, not exceptional set pieces;
- APC count tracks named powered areas closely;
- access, firedoor, and cycle behavior is often authored with map helpers over
  otherwise ordinary doors;
- cable networks are dense, while detailed atmos pipe density varies greatly
  between maps;
- department-specific manufacturers are distributed near their consumers;
- job landmarks are clustered inside department work and muster areas.

## 1. Room identity is the system join

### Goonstation evidence

`code/area.dm` defines `/area` and keeps far more than a display label. Relevant
state includes population and activation, fire and atmos alarms, minimap
appearance, workplace designation, equipment/light/environment power flags and
usage, security restrictions, and a list of machinery in the area. Named
station families include:

- maintenance at `code/area.dm:1957`;
- primary and secondary hallways at `code/area.dm:2246`;
- engineering at `code/area.dm:2845`;
- medical at `code/area.dm:3030`;
- security at `code/area.dm:3153`;
- quartermaster/cargo at `code/area.dm:3418`;
- science at `code/area.dm:3489`.

`code/obj/machinery.dm` adds machinery to the containing area's machine list
when initialized, moves it between area lists when relocated, reads the area's
power-channel state, and records usage back into the area. The area is thus a
queryable operational unit.

That identity is stable even when gas topology is not. Opening an airlock may
make two spaces exchange atmosphere, but it does not turn Medical into a
hallway or transfer its budget and workplace identity. Sim Station must not
collapse these concepts into one flood-fill region.

### Original Sim Station contract

Add an authoritative room entity with a stable content-independent instance
ID. A minimal room record should contain:

```text
room_id
archetype_id
name_key
department_id
sorted tile indices
sorted tags
security_zone_id
workplace_tags
power_controller_id or null
atmos_zone_id
alarm_state
occupant_ids
machine_ids
```

The following concepts must remain separate:

- **room**: administrative and operational identity;
- **atmos zone**: a dynamic connected gas compartment;
- **power circuit**: a connected electrical network;
- **security zone**: a reusable access policy;
- **department**: staffing, budget, and reporting owner.

A room may point to one of each, and multiple rooms may share a power circuit
or atmos supply network. Opening a door can merge atmos exchange without
changing any room IDs.

Room definitions should be normal mod content, for example
`org.simstation.core:room-archetype/cargo-office`. A station template should
place room instances and tile membership explicitly. Do not use a DM type path
or Lua module name as runtime identity.

### Map grammar to preserve

Across the five maps, departments repeatedly form four layers:

1. a public hallway or service-facing threshold;
2. a department lobby, office, or muster/locker space;
3. a restricted work core;
4. a rear maintenance or service route.

Maintenance has the broadest backstage contact with medical, engineering,
security, science, cargo, and civil/service areas. That redundancy is valuable
to a management game: repairs, hauling, and emergency response can route
around a blocked public entrance without making every workplace public.

Cogmap2 illustrates the pattern without being a template to copy:

| Category | Classified tiles | Approximate center | Direct category contacts |
| --- | ---: | --- | --- |
| Command | 263 | (221, 152) | civil/service, maintenance, public hall |
| Security | 947 | (165, 150) | civil/service, maintenance, public hall |
| Medical | 1,114 | (122, 191) | maintenance, science, civil/service |
| Science | 785 | (95, 194) | medical, civil/service, maintenance |
| Engineering | 1,088 | (142, 155) | maintenance, civil/service, public hall |
| Cargo | 543 | (174, 197) | civil/service, maintenance, public hall |
| Public hall | 1,324 | — | all major station categories |
| Maintenance | 2,917 | — | all major station categories |

For Sim Station's first authored map, use this grammar to create an original,
smaller station:

- one legible public spine or loop;
- engineering and cargo adjacent enough to share industrial logistics;
- medical reachable from the public spine without crossing another
  restricted department;
- security near a high-traffic junction, not buried behind command;
- science adjacent to service and maintenance but with a restricted inner lab;
- a maintenance loop with at least two connections to every critical
  department;
- a physical cargo exterior edge with inbound and outbound buffers.

The first station should favor simulation clarity over Goonstation-scale
labyrinths. A compact occupied footprint around 96×96 tiles is sufficient for
the initial loop; larger templates can remain mod content.

## 2. Doors, access, pressure boundaries, and cycles

### Goonstation evidence

`code/procs/access.dm:7-103` defines `req_access`, `allowed`, and
`check_access`. Its useful data-model feature is grouped access:

- entries in the outer collection are alternatives;
- a nested group requires every access token in that group.

This can express “Engineering **or** Command” and “Security **and** Armory”
without bespoke door code.

`code/obj/machinery/door/door_parent.dm` supplies the common state machine:
dense/opaque state, operating state and time, autoclose behavior, lock state,
damage, access checks, open/close requests, and collision-triggered opening.

`code/obj/machinery/door/airlock.dm` adds main and backup power state, welding,
bolts, safety, electrical faults, cycle identifiers, access, and power use.
Key behavior is visible in:

- power checks and loss at lines 409-459;
- local APC/powernet connection at line 464;
- collision access attempts at lines 612-620;
- manual unpowered opening at line 843;
- cycle linking at line 871;
- powered open/close transitions at lines 878-914.

Opening or closing uses power, respects operating/bolted/welded conditions, and
can close another door in a linked cycle group. Full airlock wire hacking is a
large player-character interaction system, but the high-level fault states are
valuable to a station simulator.

Mapping helpers demonstrate a strong authoring practice:

- `code/modules/mapping/helpers/access_spawn.dm` applies a functional access
  requirement to machinery on the same tile;
- `code/modules/mapping/helpers/airlock_helpers.dm` supplies bolts, welding,
  access-cycle identity, and inner/outer cycle linkage;
- `code/modules/mapping/helpers/firedoor_spawn.dm` derives a firedoor from an
  underlying ordinary door.

Appearance, access policy, and special behavior can therefore be selected
independently in the map.

### Original Sim Station contract

Promote doors from an integer tile state to entities:

```text
door_id
definition_id
tile_index
orientation
room_a_id
room_b_id
security_zone_id
access_expression
state: closed | opening | open | closing | jammed | broken
locked
bolted
welded
powered
main_power_buffer_ticks
backup_power_buffer_ticks
autoclose_ticks
cycle_group_id or null
cycle_side or null
pressure_rating_millipascals
health_millipoints
```

Access expressions should be declarative normal form:

```json
{
  "any": [
    {"all": ["engineering"]},
    {"all": ["command"]},
    {"all": ["security", "armory"]}
  ]
}
```

Sort all tokens and groups canonically when compiling content. At runtime,
resolve authorization from the agent's credentials, the task's emergency
override, and door faults. Access denial should produce a reason code, not only
a boolean, so UI, automation, and job planning can distinguish “wrong access,”
“no power,” “bolted,” “pressure interlock,” and “jammed.”

Player and agent actions enter as commands such as:

```text
request_door_transition(actor_id, door_id, desired_state)
set_door_lock(actor_id, door_id, locked)
set_door_emergency_override(actor_id, door_id, enabled)
schedule_door_repair(actor_id, door_id)
```

Opening and closing take integer ticks and energy. A door reserves its
transition before simulation of movement so two agents cannot obtain
order-dependent results by arriving in the same tick.

Cycle groups should be a reusable component rather than a special airlock
class. The invariant is simple: at most one pressure boundary in a cycle group
may be open or transitioning open. A cycle command closes the current side,
waits for closure and optional pressure equalization, then opens the requested
side. This supports cargo exterior locks, quarantine, labs, and modded vehicle
bays.

Use authoring helpers in the editor/compiler, but compile them away into
explicit entities before the simulation loads. A helper may apply
`security_zone_id`, create a fire shutter at a boundary, or link two doors;
saved games and authoritative state should never depend on an invisible
same-tile search.

### Deferred detail

Do not implement individual wire colors, electrification minigames, AI hacking,
or per-tool disassembly in the first slice. Represent their management-level
outcomes as inspectable faults and work orders:

- access controller fault;
- actuator fault;
- sensor/safety fault;
- main-power loss;
- backup-power loss;
- welded or obstructed;
- emergency bolt state.

Mods can later add detailed maintenance procedures using the same fault and
work-order contracts.

## 3. Area power, APCs, and load shedding

### Goonstation evidence

The header and `/obj/machinery/power/apc` definition in
`code/modules/power/apc.dm:11-185` describe the core arrangement: an APC is
wired to a power network, associated with an area, controls lighting,
equipment, and environment channels, and contains a local cell.

Relevant behavior includes:

- area association, cell creation, and terminal construction at line 186;
- pushing channel state to the area at line 990;
- collecting the area's channel use at line 1268;
- cell/grid accounting at line 1317;
- low-cell channel decisions at line 1433;
- the four channel modes—off, auto-off, on, auto-on—at line 1461.

The source prioritizes environment under deep battery depletion, then
lighting, then general equipment. That produces legible partial failures:
fabricators stop before life support, and lighting becomes an early warning
before atmosphere is lost.

`code/datums/powernet_data.dm` defines the powernet's cable and machine nodes,
load, availability, and excess. `code/modules/power/power_parent.dm` and
`code/modules/power/cable.dm` build and repair cable connectivity.

Goonstation also tests map invariants:

- `code/modules/unit_tests/_map_correctness/apcless_areas.dm` rejects
  accessible powered station areas with no APC;
- `code/modules/unit_tests/_map_correctness/unwired_apcs.dm` rejects an APC
  without a center cable connection.

### Original Sim Station contract

Implement power as two linked graphs:

- a **generation/distribution circuit graph** over cables, generators,
  storage, breakers, and APC inputs;
- a **room load bus** owned by each APC and divided into environment, lighting,
  and equipment channels.

Authoritative quantities should use integers:

- energy in millijoules;
- generation and draw in milliwatts;
- cell charge in millijoules;
- time in simulation ticks;
- channel thresholds in integer parts per 10,000.

Each tick:

1. sort circuits by stable circuit ID;
2. total generation, requested charge, and loads;
3. allocate according to documented priority and tie-breaking;
4. update APC cells;
5. sort APCs by ID and determine channel availability;
6. let machines observe their channel state during their own phase;
7. emit aggregated reports and deterministic events.

Do not reproduce an unordered “one big pool” update. When supply is scarce,
allocation must be stable and explainable. A reasonable first policy is:

1. life-support/environment demand;
2. emergency lighting and control;
3. normal lighting;
4. essential equipment;
5. discretionary equipment;
6. battery charging.

The first APC component should contain:

```text
apc_id
room_ids
input_circuit_id
cell_capacity_millijoules
cell_charge_millijoules
charge_mode
channel_modes
channel_priority
channel_last_demand_milliwatts
channel_last_served_milliwatts
fault_ids
```

It is acceptable for one APC to serve several small rooms in the first
template, but the association must be explicit. Do not discover it through
screen location during simulation.

### Required validation

- every occupied room that requires power has exactly one APC service
  association;
- every APC input is connected to a valid power circuit;
- every powered machine has a valid room and channel;
- no cable endpoint refers to a missing circuit node;
- the life-support channel cannot be configured below a template's declared
  safety floor without an explicit hazardous-room waiver;
- all allocation ties resolve by documented stable ID ordering.

## 4. Atmos supply, vents, scrubbers, and alarms

### Goonstation evidence

Goonstation atmos endpoints follow a clear transfer model:

- `/obj/machinery/atmospherics/unary/vent_pump` in
  `code/modules/atmospherics/machinery/unary/vent_pump.dm` moves gas between
  its pipe contents and the tile. It supports release/siphon direction,
  internal and external pressure bounds, enabled state, high-volume variants,
  and radio commands such as purge and stabilize.
- `/obj/machinery/atmospherics/unary/vent` in
  `code/modules/atmospherics/machinery/unary/vent.dm` is a passive
  equalization endpoint.
- `/obj/machinery/atmospherics/unary/vent_scrubber` in
  `code/modules/atmospherics/machinery/unary/vent_scrubber.dm` can siphon or
  selectively remove configured gases into a pipe.
- `code/modules/atmospherics/machinery/unary/unary_base.dm` and
  `code/modules/atmospherics/machinery.dm` connect endpoints, pipelines, and
  pipe networks.
- `/obj/machinery/alarm` in `code/obj/machinery/alarm.dm` uses the environment
  power channel, samples pressure, gas partial pressure, and temperature, and
  reports minor/severe/normal/no-power/broken states by area.

The map survey found a critical Goon-specific detail:

| Map | Powered vent pumps | Passive vents | Portable scrubbers | Mapped unary vent scrubbers |
| --- | ---: | ---: | ---: | ---: |
| Cogmap2 | 46 | 54 | 24 | 0 |
| Cogmap | 2 | 8 | 11 | 0 |
| Donut3 | 9 | 11 | 11 | 0 |
| Kondaru | 2 | 7 | 3 | 0 |
| Clarion | 1 | 3 | 16 | 0 |

The familiar paired permanent “vent and scrubber in every room” convention is
not supported by these Goon maps. Some maps rely heavily on prefilled
atmosphere, passive endpoints, or portable response equipment.

### Original Sim Station contract

Model an atmos device as a bounded transfer between a room/tile gas container
and a connected supply or waste reservoir:

```text
device_id
definition_id
room_id
tile_index
network_id
power_channel
mode: off | stabilize | supply | siphon | scrub
target_pressure_millipascals
transfer_limit_millimoles_per_tick
gas_filter_ids
enabled
fault_ids
```

The first pipe implementation need not simulate gas in every visible pipe
segment. Preserve placement and connectivity, but let each connected network
own a deterministic reservoir. Endpoints perform integer, capacity-bounded
transfers in sorted device order. Detailed per-segment volume, heat exchange,
and flow can be added without changing endpoint content contracts.

Atmos zones should be recomputed from gas-tight tile boundaries after all door
transitions for a tick. A stable flood-fill order and canonical zone identity
rule are required. Administrative rooms remain unchanged when zones merge.

First-slice device set:

- supply/stabilization vent;
- passive equalization vent;
- pressure/temperature/gas monitor;
- portable scrubber that generates a haul/place/operate work order;
- supply reservoir and waste reservoir;
- optional pump or valve separating two reservoirs.

Permanent selective scrubbers should be optional mod content, not a hidden
requirement of every room.

The monitor is as important as the vent. A room without observability creates
silent failures, while a monitor without environment power creates a
meaningful “unknown” state rather than reporting normal.

### Required validation

- every normally occupied pressurized room has a pressure monitor;
- every such room has a declared path to atmosphere supply, unless a
  hazardous/vacuum waiver is present;
- every endpoint refers to an existing reservoir network;
- filters reference known gas IDs;
- a room archetype may require portable response coverage instead of a
  permanent scrubber;
- all transfer capacities and alarm thresholds are integer and positive;
- opening a door between unequal pressures yields identical results after
  save/load and across Lua implementations.

## 5. Common machinery behavior

### Goonstation evidence

`code/obj/machinery.dm` is the common machinery root. It maintains status,
power draw and channel, power requirements, area registration, processing,
damage/power changes, interaction entry points, and construction or
deconstruction. The important pattern is that a machine participates in
shared systems even before its domain-specific behavior runs.

For Sim Station, per-object asynchronous `process()` callbacks would make
ordering, save compatibility, and mod debugging difficult. The useful concept
is a common machine contract, not the callback implementation.

### Original Sim Station contract

Every machine instance should share:

```text
machine_id
definition_id
room_id
tile_index
orientation
operating_state
health_millipoints
power_channel
idle_draw_milliwatts
active_draw_milliwatts
input_inventory_id or null
output_inventory_id or null
queue
active_operation
fault_ids
allowed_role_tags
maintenance_recipe_id
```

Run machines in explicit deterministic phases:

1. validate and reserve input lots and output capacity;
2. request power and required utilities;
3. advance work by integer milliticks;
4. commit consumed lots;
5. emit output lots;
6. roll any seeded fault checks;
7. generate work orders and reports.

No mod callback should be able to mutate another entity arbitrarily during
iteration. Mod hooks should return commands, modifiers, validation results, or
events that the core applies at the next documented boundary. Suitable hooks
include:

- `validate_machine_start`;
- `modify_machine_demand`;
- `modify_machine_progress`;
- `on_machine_output`;
- `on_machine_fault`;
- `provide_maintenance_actions`.

Hook providers and returned effects must be sorted by pack ID, hook priority,
and stable definition ID. Save data records definition IDs and current state,
never executable closures.

Agent interaction should use work orders—operate, load, unload, inspect,
repair, clean, calibrate—rather than recreating SS13's dense set of item-on-
machine click verbs.

## 6. Manufacturing and material flow

### Goonstation evidence

`/datum/manufacture` in `code/datums/manufacturing.dm:3-68` gives a blueprint a
name, material requirements, outputs, quantity, duration, category, and
material inheritance behavior.

`code/datums/manufacturing_requirements.dm` supports more than exact item
matching. Requirements may be satisfied by a material identity, flags, or
properties and thresholds. This makes alternate resources useful without
duplicating every recipe.

`/obj/machinery/manufacturer` in
`code/obj/machinery/manufacturer.dm:25` adds:

- stored resources and recipe catalogs;
- a production queue with a finite limit;
- ready, working, and halted states;
- output capacity and output target;
- speed and repeat settings;
- separate idle and active power;
- departmental, downloaded, hidden, or drive-provided blueprints;
- material checking, removal, timed work, and output dispensing.

Its speed tradeoff is particularly suitable for a sim: faster production
costs disproportionately more power. The exact Goon formula need not be
copied, but the decision should remain.

`code/obj/machinery/manufacturer_subtypes.dm` distributes specialized
manufacturers—general, engineering, medical, robotics, science, mining,
uniform, hangar, and others—near their consumers. Surveyed maps contain 24 to
31 manufacturers. Cogmap2's 31 include seven general units plus specialized
hangar, gas, robotics, mining, uniform, medical, mechanics, science,
engineering, cargo, and personnel units.

Manufacturers accept refined material pieces rather than treating all raw ore
as immediately usable. Outputs can be staged into a container or onto a tile.
This creates a useful physical chain:

```text
raw delivery -> storage -> reclaimer/refinery -> refined stock
             -> specialized fabricator -> output buffer -> hauled consumer
```

### Original Sim Station contract

Extend the existing recipe data instead of adding machine-specific Lua.
Recipes should support:

- exact item IDs;
- material tags;
- integer material-property minima;
- substitution groups with an explicit priority policy;
- input quantity and quality;
- byproducts and waste;
- required machine tags;
- work duration and utility demand;
- output lots and output capacity;
- required operator competency;
- unlock or blueprint tags.

Inputs must be reserved at job start. Without a reservation ledger, two
machines or agents can both see the same stack and produce order-dependent
double spending. Reservations should identify exact inventory lot IDs and be
released deterministically on cancel, fault, or lost output capacity.

When several lots satisfy a property requirement, content must declare the
choice policy—for example lowest sufficient quality, lowest accounting cost,
or explicit ordered preference. Never depend on Lua table iteration.

The first slice needs only:

- one reclaimer/refinery;
- one general fabricator;
- one engineering fabricator;
- one medical fabricator;
- eight to twelve recipes that close a useful loop;
- input and output staging containers;
- haul, load, operate, unload, and deliver work orders.

Existing first-party recipes for steel, circuits, and control assemblies are a
good seed, but they should be connected to inventories, machine instances,
physical output, and department demand. Add repair parts, cable, filters, a
portable scrubber consumable, and one medical supply so engineering, cargo,
and medical all consume the chain.

Defer hidden/emergency blueprints, malicious output variants, material-
appearance inheritance, and spawning arbitrary executable object types.

## 7. Cargo economy and physical logistics

### Goonstation evidence

`/datum/shipping_market` in
`code/modules/economy/shippingmarket.dm:20` owns commodities, periodic market
shifts, demand, traders, requisition contracts, supply requests and history,
crate rewards, and pending physical deliveries. `market_shift` recalculates
prices from a base and bounded fluctuation rather than recursively compounding
the previous price.

`code/datums/controllers/process/shipping_market.dm` schedules those changes.
Sim Station should use simulation ticks rather than wall-clock timing or
jitter.

`/obj/machinery/computer/supplycomp` in
`code/obj/machinery/computer/QM_supply.dm` is access-controlled and connects
orders, available packs, department supply budgets, market offers, traders,
contracts, and order history. Approval charges a department and creates a
physical shipment. Export appraises physical crate contents and settles
credits through the shipping market.

The map placement is as important as the economic datum. Cogmap2's
quartermaster office is a large threshold between station and dock operations,
with supply consoles, barcode/manifest computers, conveyors, cargo access,
fire boundaries, and dock doors. The economy has a spatial footprint.

### Original Sim Station contract

Implement cargo as a deterministic transaction state machine:

```text
requested -> approved -> charged -> in_transit -> delivered_to_dock
          -> unloaded -> stored/delivered
```

Exports use the reverse:

```text
contract_accepted -> goods_reserved -> staged -> manifested
                  -> dispatched -> inspected -> settled/rejected
```

Every transition should emit an immutable ledger entry with tick, order ID,
department, actor, quantities, and credits. An order that cannot fit in the
inbound buffer remains in transit or pending; it must not materialize in an
abstract department stockpile.

The cargo room archetype should require:

- an exterior delivery boundary;
- inbound buffer tiles or container slots;
- outbound buffer tiles or slots;
- cargo console;
- manifest/barcode work point;
- general storage;
- a public/staff threshold;
- a maintenance route;
- a clear haul path to the industrial machines.

For the first slice, support:

- catalog ordering from department budgets;
- three export commodities;
- three rotating contracts;
- one deterministic market-shift interval;
- transparent base, demand, and current price;
- seeded, bounded price modifiers;
- physical crates or pallets and manifest work.

Treat paperwork as work duration, competency, and possible seeded error rather
than recreating PIN entry and barcode user-interface minutiae. Trader dialogue
and haggling can be a later mod-facing system.

## 8. Jobs, access, and workplace placement

### Goonstation evidence

`/datum/job` in `code/datums/jobs/job_parent.dm:2` combines wages, staffing
limits, category, traits, equipment, access, supervisor relations, and spawn
behavior. Department job definitions are spread through
`code/datums/jobs/jobs_*.dm`; engineering and cargo examples are in
`code/datums/jobs/jobs_engineering.dm`.

`/obj/landmark/start/job` in `code/obj/landmark.dm:75` provides map-authored
job starts. `code/procs/jobprocs.dm` uses them for initial placement, and
`code/map.dm` can derive job limits from landmark count.

The five-map survey found strong workplace clustering:

| Job | Sampled starts | Dominant placement |
| --- | ---: | --- |
| Engineer | 44 | engineering and electrical rooms |
| Quartermaster | 17 | 16 in quartermaster offices |
| Miner | 20 | mining staff rooms and magnet areas |
| Security officer | 44 | security main, checkpoints, wing, equipment |
| Medical doctor | 51 | medbay, medical staff, and break rooms |
| Roboticist | 14 | all in robotics |
| Scientist | 45 | science lobby, chemistry, and teleporter areas |
| Botanist | 29 | 27 in hydroponics |
| Chef | 9 | predominantly kitchens |
| Bartender | 5 | predominantly bar offices |
| Janitor | 9 | janitorial office and supply areas |

The lesson is to provide a department muster/locker/break cluster adjacent to
the work core. The exact start-landmark mechanism is not suitable as staffing
capacity for a persistent single-player simulation.

### Original Sim Station contract

Extend job definitions with:

```text
access_profile_id
workplace_tags
competency_tags and integer levels
preferred_shift
required_kit_tags
emergency_role_tags
department_id
base_wage_credits
```

An agent's home workplace is selected from matching room tags in stable room ID
order, with a documented distance/capacity score. Shift start or crew creation
may place agents at muster rooms, but staffing capacity should come from:

- required service coverage;
- available workstations;
- shift schedule;
- department budget;
- queue pressure and target utilization;
- supervisor or safety requirements.

Do not set job capacity from the number of spawn points.

Access should affect task feasibility before pathfinding begins. If the only
path to a failed APC crosses a door the assigned engineer cannot open, the
planner should report `blocked_access` and either request an escort/override
or reassign the work. It should not make the agent repeatedly collide with the
door.

## 9. Room archetypes and diagnostics

Goonstation contains department-oriented map correctness tests under
`code/modules/unit_tests/_map_correctness/area_contents_check/`. For example,
the medical checks require a coherent bundle of diagnostics, treatment,
cryogenic, oxygen, fabrication, storage, vending, request, and staff support
fixtures. Robotics similarly expects operating, fabrication/reclamation,
charging, cargo-transfer, and tool support.

Sim Station should generalize this into mod-defined room-archetype
requirements, not copy the exact objects or counts. A requirement can express:

```text
at_least 1 machine tagged "medical-diagnostic"
at_least 1 machine tagged "medical-treatment"
exactly 1 powered environment monitor
at_least 1 inventory tagged "medical-supplies"
reachable_from room tag "public-hall" through patient-permitted doors
served_by power channel "equipment"
served_by atmos supply network
```

The compiler/editor should report all violations at once with room ID, rule
ID, and candidate fixes. Requirements are content definitions, so a mod can
replace or extend a department without changing core code.

Recommended first-party archetypes:

- public hall;
- maintenance corridor;
- cargo office;
- cargo dock;
- cargo warehouse;
- engineering workshop;
- electrical/APC service room;
- medical reception/treatment;
- science lobby/lab;
- security lobby/office;
- command office;
- airlock vestibule.

## 10. Proposed next vertical slice

### Player-visible loop

1. The station begins with a generator, cable circuit, engineering APC, cargo
   APC, pressurized cargo/engineering rooms, access-controlled doors, a cargo
   dock, storage, reclaimer, and fabricator.
2. The player orders raw material against the cargo budget.
3. A shipment arrives in the dock buffer.
4. A cargo technician unloads, manifests, and hauls it to storage.
5. An engineer or cargo technician loads the reclaimer.
6. Refined stock is moved to the fabricator and reserved for a selected
   recipe.
7. Production consumes equipment-channel power over time and emits a physical
   output lot.
8. Loss of generation drains APC cells; equipment sheds before environment.
9. A stopped vent causes a monitor alarm; an engineer must restore power or
   deploy a portable scrubber/atmos device.
10. A door access, pressure-cycle, or output-buffer failure visibly blocks the
    chain and produces a specific report.
11. A completed item is delivered to a requesting department or staged for
    export, closing the budget/material loop.

### Implementation order

1. **Room schema and authored station template**
   - stable room entities and tile membership;
   - explicit department, workplace, security, power, and atmos references;
   - original compact layout using the public/front, work-core, restricted,
     and maintenance/back pattern.
2. **Door/access entities**
   - timed transitions, reason-coded denial, security expressions;
   - gas boundary changes;
   - optional two-door pressure cycle.
3. **Circuit and APC**
   - cable graph, generator, APC cell, three room channels;
   - integer demand allocation and deterministic load shedding.
4. **Atmos endpoints and monitoring**
   - network reservoirs, stabilization vent, monitor, portable scrubber;
   - room-versus-atmos-zone separation.
5. **Inventories, machinery, and reservations**
   - lot IDs, input reservations, output capacity, common machine phases;
   - reclaimer plus general/engineering fabricators.
6. **Cargo ledger and shipments**
   - request/approve/charge/deliver/haul;
   - manifest and export settlement.
7. **Job/work planner integration**
   - workplace selection, competencies, access-aware feasibility;
   - operate/haul/repair/inspect work orders.
8. **Room and template validation**
   - archetype cardinalities, reachability, utility service, deterministic
     fixtures, and save/load replay.

Each step should ship with pure-core deterministic tests before adding
presentation. The LÖVE layer should consume snapshots and events only.

### Acceptance scenario

A headless fixture should run the full loop twice from the same seed and
command log, once uninterrupted and once with a save/load at mid-production.
Both runs must finish with identical:

- world hash;
- room, door, APC, atmos, inventory, machine, order, and agent state;
- department budgets and ledger;
- emitted event order;
- material lot lineage.

Additional fixtures should prove:

- access denial does not consume door transition power;
- a cycle never opens both pressure boundaries;
- environment remains served after equipment shedding at a configured low-cell
  threshold;
- an unpowered monitor reports unknown/no-power, not safe;
- two machines cannot reserve the same material lot;
- a full dock or output buffer blocks delivery without deleting goods;
- an inaccessible repair order is reported and reassigned deterministically;
- mod-defined room requirements and machinery hooks sort consistently.

## Decision disposition

### Accepted

- Named rooms as operational joins for machinery, power, alarms, occupation,
  access, and reports.
- Explicit administrative rooms separate from dynamic atmos zones and power
  circuits.
- Public thresholds, restricted work cores, and redundant rear maintenance
  access.
- Access expressions with OR alternatives and AND groups.
- Timed, powered doors with inspectable lock, bolt, jam, and pressure-cycle
  state.
- Area-local power controllers with cells and environment, lighting, and
  equipment channels.
- Environment-first load shedding and visible partial failures.
- Atmos devices as bounded tile/room-to-network transfers.
- Pressure, gas, and temperature monitoring as powered infrastructure.
- Portable scrubbers as physical response equipment.
- Common machine state, inventories, finite queues, power demand, output
  capacity, and faults.
- Material property/tag requirements and specialized departmental
  fabricators.
- Reclaimer-to-stock-to-fabricator-to-output logistics.
- Cargo requests, approvals, budget charges, physical deliveries, manifests,
  exports, and immutable ledger entries.
- Jobs with wages, competencies, access, workplace tags, and physical muster
  areas.
- Mod-defined room archetype validation.

### Adapted

- Goonstation areas become explicit room entities rather than inherited DM
  singleton types.
- Mapping helpers become editor/compiler conveniences that emit explicit saved
  entities.
- Powernets become deterministic circuit allocation followed by room-channel
  service.
- Detailed pipe machinery begins as connected network reservoirs with
  endpoint transfers.
- Door wire interactions become management-level faults and work orders.
- Manufacturer material selection becomes a declared stable policy with lot
  reservations.
- Random market motion becomes seeded, tick-scheduled, bounded, and
  transparent.
- Player-character machine verbs become serializable work orders.
- Job landmarks inspire muster placement but do not determine staffing
  capacity.
- Comparative layouts inspire an original compact station rather than
  shipping a raw Goonstation DMM as the default scenario.

### Rejected or deferred

- Executing or translating Goonstation DM runtime code.
- Treating a DM type path as a Sim Station entity ID or public contract.
- Implicit same-tile searches during authoritative simulation.
- Unordered per-object process callbacks.
- Full airlock wire hacking, shocks, AI hacking, and tool-by-tool disassembly
  in the first slice.
- Assuming every room needs a permanent unary vent scrubber.
- Detailed gas state in every pipe segment before the endpoint/network model
  is proven.
- Hidden, malicious, or arbitrary object-spawning manufacturer blueprints in
  the first slice.
- Full trader dialogue, haggling, PIN, and barcode minigames.
- Staffing limits based on the number of map spawn landmarks.
- Reproducing one Goonstation map's geometry, scale, object list, or quirks as
  Sim Station's architecture.

### Unresolved

- Exact first-station dimensions and department count should be selected after
  pathfinding and visible-screen-density profiling.
- Decide whether emergency lighting is a lighting sub-priority or a separate
  APC channel before freezing the power save schema.
- Decide whether initial pipe visuals must reflect exact connectivity or may
  be decorative over network edges in the first slice.
- Select the first eight to twelve production recipes based on the incidents
  and maintenance items implemented by the parent task.
- Review any shipped map-derived data and media against the project's legal
  provenance policy before release.

## Source index

All sources below are from pinned Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`.

### Access and doors

- `code/procs/access.dm`
- `code/obj/machinery/door/door_parent.dm`
- `code/obj/machinery/door/airlock.dm`
- `code/modules/mapping/helpers/access_spawn.dm`
- `code/modules/mapping/helpers/airlock_helpers.dm`
- `code/modules/mapping/helpers/firedoor_spawn.dm`

### Power and areas

- `code/area.dm`
- `code/obj/machinery.dm`
- `code/modules/power/apc.dm`
- `code/modules/power/power_parent.dm`
- `code/modules/power/cable.dm`
- `code/datums/powernet_data.dm`
- `code/procs/gamehelpers.dm`
- `code/modules/unit_tests/_map_correctness/apcless_areas.dm`
- `code/modules/unit_tests/_map_correctness/unwired_apcs.dm`

### Atmospherics

- `code/modules/atmospherics/machinery.dm`
- `code/modules/atmospherics/machinery/unary/unary_base.dm`
- `code/modules/atmospherics/machinery/unary/vent.dm`
- `code/modules/atmospherics/machinery/unary/vent_pump.dm`
- `code/modules/atmospherics/machinery/unary/vent_scrubber.dm`
- `code/obj/machinery/alarm.dm`

### Manufacturing and cargo

- `code/datums/manufacturing.dm`
- `code/datums/manufacturing_requirements.dm`
- `code/obj/machinery/manufacturer.dm`
- `code/obj/machinery/manufacturer_subtypes.dm`
- `code/modules/economy/shippingmarket.dm`
- `code/modules/economy/supply_packs.dm`
- `code/datums/controllers/process/shipping_market.dm`
- `code/obj/machinery/computer/QM_supply.dm`

### Jobs, layout, and validation

- `code/datums/jobs/job_parent.dm`
- `code/datums/jobs/jobs_engineering.dm`
- `code/datums/jobs/jobs_command.dm`
- `code/datums/jobs/jobs_medical.dm`
- `code/datums/jobs/jobs_science.dm`
- `code/datums/jobs/jobs_security.dm`
- `code/datums/jobs/jobs_civilian.dm`
- `code/obj/landmark.dm`
- `code/procs/jobprocs.dm`
- `code/map.dm`
- `code/modules/unit_tests/_map_correctness/area_contents_check/`
- `maps/cogmap2.dmm`
- `maps/cogmap.dmm`
- `maps/donut3.dmm`
- `maps/kondaru.dmm`
- `maps/clarion.dmm`
