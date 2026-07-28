# Playable vertical slice

## Outcome

The vertical slice proves the complete station-management loop in one
approximately 48-minute shift:

```text
inspect → plan → budget/staff → build → supply → manufacture/export
        → survive breach/fire → treat/clean/repair → settle and grade
```

It is a narrow content set across every foundational system, not one deep
department disconnected from the rest. The player uses construction, zones,
department budgets, staffing, priorities, production orders, and emergency
policies. They never select a crew member and issue a direct movement/work
order.

## Starting scenario

`org.simstation.core:scenario/bootstrap-contract` starts with:

- one 192×192 station map;
- a centered 31×23 powered, pressurized structural core with four exterior
  doors, lighting, one generator, one battery, basic life support, cargo dock,
  crew arrivals, and safe temporary work areas;
- one 96×96 remote mining sector connected by a scheduled shuttle transfer;
- 24 crew, with generated names/traits and this deterministic job template:

| Department | Jobs | Count |
|---|---|---:|
| Engineering | station engineer | 4 |
| Cargo | cargo technician ×2, miner ×2 | 4 |
| Service | botanist ×2, chef, janitor | 4 |
| Medical | doctor | 3 |
| Science | scientist | 2 |
| Security | security officer | 3 |
| General | assistant/hauler | 4 |

One highest-skilled member of each department becomes its simulated acting
manager; it is not a separate command job in the slice.

Starting finances use canonical hundredth-credit units:

- station liquid balance: 5,000,000 cr¢ (50,000 credits);
- department allocations: Command 800,000; Engineering 700,000; Cargo 700,000;
  Service 500,000; Medical 600,000; Science 600,000; Security 500,000 cr¢;
- the unallocated station reserve is the difference;
- each crew member has a 50,000 cr¢ personal balance;
- starter construction inventory provides the documented core-room tutorial
  plus 20% contingency, not unlimited materials.

The fixed export contract requires one
`org.simstation.core:item/industrial-control-assembly` by shift hour six and a
minimum shipment of refined metal by hour seven. The part requires mined/imported
ore, refinery output, a manufactured circuit, and assembly-machine labor.

## Included systems

### World, work, and construction

- floor, wall, window, door/airlock, cable, basic pipe, light, vent, scrubber,
  generator/battery, refinery, fabricator, stockpile marker, bed, table, hydro
  tray, kitchen equipment, medical bed, alarm, camera, and fire equipment;
- blueprint → reserve material → haul → construct → inspect → commission;
- room detection, department zones, stockpiles, access, dirty chunks, and
  hierarchical navigation;
- offered → claimed → reserved → executing → complete/failed/cancelled tasks;
- autonomous task scoring by policy priority, qualification, distance, hazard,
  needs, tools, access, and stable ID.

### Environment and utilities

- O2, N2, CO2, plasma, N2O, and water-vapor definitions;
- per-tile integer gas, temperature, pressure, active-frontier equalization,
  breaches, doors, vents, scrubbers, fire, smoke, and exposure;
- generator, battery, cable graph, demand priorities, breakers, power loss, and
  alarms;
- one basic supply/scrub loop and room-level diagnostics.

### Crew and departments

- hunger, fatigue, morale, safety, food, sleep, recreation, wages, schedule,
  access, skill, and current task;
- basic anatomy/health: head, torso, two arms, two legs, blood, brute, burn,
  oxygen, toxin, pain, bleeding, unconsciousness, death;
- department budgets, wage policy, work priorities, emergency exceptions, and
  acting-manager reports;
- inspectable “why this task?” factors and timestamped knowledge.

### Economy, logistics, and manufacturing

- central/department append-only ledgers, personal accounts, wage accrual and
  settlement, vending purchases, requisitions, imports, exports, contract
  payment/penalty, and bailout debt;
- physical stacks, containers, hauling reservations, stockpiles, manifests,
  cargo capacity, shuttle delay, and disposal;
- iron-bearing ore, raw biomass, steel, glass, cable, circuit, control assembly,
  food ingredients, medicine, fuel, and waste;
- mine → haul → refine → intermediate recipe → final assembly → export.

### Service, medical, science, and security

- hydroponic growth for two crops, harvest, one cooked meal chain, nutrition,
  food contamination, vending, waste, tracked dirt/blood, mopping, and
  sanitation work;
- triage, bandaging, burn care, oxygen support, basic medicine, bed capacity,
  casualty report, corpse handling, and a deliberately unreliable emergency
  clone service;
- one material-efficiency research project fueled by sample analysis and
  experiment work; unsafe operation can create a contained hazard;
- access violations, alarm reports, witnessed assault/theft fixture, evidence
  record, arrest task, brig timer, and release. No hidden antagonist is
  required.

### Incidents and recovery

- seeded director candidates: equipment fault, supply delay, illness, power
  overload, social dispute, small fire, meteor strike/breach, market movement;
- threat budget, prerequisites, cooldowns, recovery window, and no unavoidable
  stacked catastrophe;
- emergency resupply, bailout debt, evacuation, casualty replacement next
  shift, and repair contracts keep default failure recoverable.

## Player UI

The slice ships:

- pan/zoom, pause/1×/2×/4×, build and zone palettes;
- department dashboard, station/department/personal ledgers;
- staffing/schedule/wage and work-priority policies;
- stock, requisition, production, research, contract, and shuttle panels;
- power, atmos, temperature, fire, sanitation, access, camera, and task
  overlays;
- crew/room/machine/item inspectors with last-known timestamps;
- alerts and incident timeline with configurable pause-on-alert;
- searchable codex and contextual tutorial;
- scalable UI, full remapping, captions, color-independent overlay patterns,
  and content toggles.

Unavailable information remains visibly unknown/stale rather than exposing
secret objective state.

## Scripted acceptance shift

The canonical journal guides these goals while leaving crew autonomous:

1. At shift start, zone Engineering/Cargo/Service/Medical areas and approve
   department allocations.
2. Blueprint and commission a sealed fabrication room with powered refinery,
   fabricator, vent, scrubber, light, alarm, and stockpile.
3. Send miners to the remote sector by policy and schedule, return ore, refine
   metal, build a circuit, and manufacture the control assembly.
4. Grow/harvest food, cook and distribute a meal, settle personal vending
   purchases, and prevent severe hunger.
5. Complete the efficiency research project and apply its documented recipe
   modifier.
6. Export the assembly and refined metal within the contract windows.
7. At fixed test tick 10,800, a seeded meteor breaches an occupied outer room
   and starts one fire.
8. Alarms/cameras/reports reveal the event according to actual infrastructure.
   The player declares emergency priorities and evacuation but gives no pawn
   orders.
9. Crew isolate power/air, rescue and treat casualties, extinguish fire, clean
   blood/debris, patch the hull, repressurize, and recommission the room.
10. At tick 28,800, settle wages/contracts/upkeep, rotate records, autosave, and
    calculate grade.

Passing state:

- contract delivered;
- station remains powered with no uncontrolled fire or open occupied breach;
- all accessible occupied rooms remain above documented survivable pressure;
- at least 20 of 24 crew survive and no untreated critical casualty remains;
- no crew has severe hunger and required wages are paid or explicitly carried
  as recoverable debt;
- emergency room is repaired, clean, and operational;
- ledger balances reconcile to zero-sum transactions plus declared external
  sources/sinks;
- grade is C or better;
- save/reload and replay match golden state hashes.

The scenario remains playable after missing the contract, casualties, or
insolvency. Bailout/resupply/debt/evacuation paths are separately tested and
award a lower grade rather than ending the campaign.

## Content budget

The vertical slice may contain more imported graphics/audio, but simulation
content is capped to approximately:

- 24 job/access/schedule templates;
- 80 construction/machine/furniture definitions;
- 120 items/material forms;
- 35 recipes/reactions;
- 20 needs/moods/traits;
- 12 treatments/conditions;
- eight incidents;
- four research nodes;
- one station and one mining scenario.

Adding breadth beyond the cap requires replacing rather than postponing a gate.

## Completion gate

- The scripted acceptance shift and recovery variants pass deterministically on
  all desktop targets.
- `nominal-100` and `disaster-100` technical proofs meet the separate
  performance limits even though the authored slice starts with 24 crew.
- Base, data example, AV replacement, scenario, and trusted-code example packs
  load from folders and `.simmod`.
- All used graphics/audio resolve to compiled assets with provenance and
  credits; no runtime DMI/tracker parsing occurs.
- New-player tutorial completion and veteran playtest reports have no
  progression-blocking usability issue.
- Every included system has player controls, failure recovery, save fields,
  hooks/data extension, and automated tests.
