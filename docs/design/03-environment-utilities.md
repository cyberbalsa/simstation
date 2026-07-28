# Atmosphere, fire, power, and utilities

## Atmosphere and heat

### Purpose and player experience

Atmosphere makes station architecture and life support physically meaningful.
Air is a conserved resource; doors, breaches, vents, pumps, fires, bodies, and
reactions alter it. The player manages safe ranges and infrastructure rather
than painting “oxygenated” rooms.

### Authoritative state and units

Every sealed-region atmosphere is represented by cells owned by tiles. A cell
stores:

- gas amounts by content-defined species in integer `mmol`;
- temperature in `mK`;
- volume in litres, derived from tile/fixture displacement;
- pressure in `Pa`, derived using a fixed-point ideal-gas calculation;
- smoke/particulate amounts as gas species or aerosol fields;
- active/edge flags and last-equilibrated tick; and
- thermal energy/remainder values needed for conservative integer calculations.

The base gas set is oxygen, nitrogen, carbon dioxide, plasma/toxic fuel, nitrous
oxide, and water vapour. Mods may add species with heat capacity, breathing,
combustion, visibility, toxicity, and condensation traits.

Gas transfer moves a bounded pressure-gradient-derived amount across each open
cardinal edge. Edges process in a rotating deterministic compass order based on
`tick_id mod 4` to prevent permanent directional bias. Transfer carries energy
and species proportionally with integer remainder accumulation.

Tiles exchange heat with gases, floors, structures, fixtures, items, bodies, and
space according to fixed-point conductance. Space is a zero-pressure sink and a
scenario-defined thermal boundary.

### Cadence and ordering

- Open/closed edge changes activate adjacent cells immediately.
- Active-frontier gas transfer and critical thermal exchange run at `2t`.
- Breathing, vent/pump actions, combustion, and reagent gas production enqueue
  transfers before the next atmosphere solve.
- Stable cells leave the frontier after pressure, temperature, and composition
  deltas remain under thresholds for three solves.
- Room-level summaries refresh at `5t`; displayed values retain measurement
  timestamps.
- Unoccupied remote maps use conservative room aggregates every `60t`; active
  fire, exposed space, or living occupants force full-rate simulation.

### Player levers

Build and configure pumps, vents, scrubbers, sensors, heaters, coolers, filters,
tanks, valves, and pressure zones. Set target pressure/composition/temperature,
alarm thresholds, scrub species, utility priority, and emergency vent/fill
policies. Declare evacuation or restricted areas.

The player cannot directly set cell gas or temperature outside debug/scenario
commands.

### Autonomous behavior

Atmospheric machinery responds to configured setpoints, available power, pipe
contents, control signals, throughput, and damage. Engineers receive leak,
filter, tank, sensor, and machinery work. Crew perceive breathing difficulty,
wind, heat/cold, smell-capable gases, smoke, and alarms, then seek safety or
protective equipment according to knowledge and policy.

The Goon-derived devices remain distinct machines rather than one generic
“atmos fixture.” A passive vent is an unpowered equalizer between the room and
its connected reservoir; it never synthesizes oxygen or nitrogen. A vent pump
has on/off, direction, and pressure-bound controls. A portable scrubber has
power, flow, internal contents, and selected gas-removal behavior. Their
source-pinned controllers run on the 16 `ds` machine tier and enqueue conserved
gas transfers for the atmosphere solve.

### Inputs, outputs, and dependencies

Inputs: world seals/volume, utility machines, power, pipe networks, doors, fire,
chemistry, biology, item/machine heat, and space boundaries.

Outputs: local pressure/composition/temperature, gas movement forces, heat
exchange, breathing inputs, fire oxidizer/fuel, condensation, visibility
reduction, hazard path costs, sensor readings, and events:

- `pressure_threshold_crossed`
- `temperature_threshold_crossed`
- `atmosphere_composition_hazard`
- `decompression_started/ended`
- `gas_released/removed`
- `atmos_machine_stalled`

### UI, alerts, and visibility

Atmos overlays show known pressure, oxygen partial pressure, temperature, gas
composition, flow, and sensor age. Unknown tiles are hatched; last-known readings
fade and show timestamps. Room cards show targets, measured ranges, machinery
throughput, leaks inferred from balance, and time-to-target estimates.

Alarms require an operational sensor/data route or crew report. A camera alone
reveals visible wind/smoke effects but not exact pressure.

### Data definitions

`gas_species`, `atmos_machine`, `filter`, `sensor_profile`, `pressure_policy`,
`thermal_material`, and `protective_equipment` define physical coefficients,
safe thresholds, throughput, ports, power draw, audible/visible cues, and
appearance.

All physical constants use canonical integer units and bounded ranges. Gas
definitions must declare display behavior and biological/fire interactions even
when the value is `none`.

### Mod hooks

- `transform:gas_transfer_limit`
- `transform:thermal_conductance`
- `observe:gas_transferred`
- `observe:atmosphere_threshold`
- `validate:atmos_machine_setting`
- data additions for gas/machine/policy definitions

Hooks cannot create or delete conserved gas/energy without returning an explicit
source/sink reason that is recorded in the conservation ledger.

### Save fields

Save cell species amounts, energy/temperature and remainders, volume modifiers,
active/frontier state, machine settings/internal reservoirs, atmosphere RNG if
any future stochastic process owns one, and conservation-ledger totals. Rebuild
region aggregates and edges.

### Failure and recovery

- Numerical clamps produce `simulation_clamp` diagnostics and preserve a
  conservation discrepancy counter; release tests require it to remain zero.
- Destroyed tanks release their actual contents and thermal energy.
- Power or data loss leaves machinery in its definition's fail-safe state.
- Broken sensors become stale rather than showing false objective truth unless a
  fault definition explicitly emits an inaccurate measurement.
- Breaches remain recoverable through isolation, evacuation, patching, refill,
  treatment, and emergency gas imports.

### Feature stages

- **Proof:** oxygen/nitrogen/CO2, pressure, temperature, doors, breach, vent,
  scrubber, tank, breathing.
- **Vertical slice:** all base gases, pumps/valves/filters, fire coupling,
  decompression force, sensors/alarms, protective suits.
- **1.0:** aerosol/condensation depth, gas reactions, advanced thermal machinery,
  disease aerosols.
- **Deferred:** fluid-dynamic accuracy beyond tile-scale gameplay needs.

### Acceptance tests

1. Open two unequal chambers and verify total gas and thermal energy conservation
   through equilibrium.
2. Breach a pressurized room to space and compare deterministic pressure history,
   item displacement, alarms, crew harm, and final loss.
3. Cycle a door quickly and verify no double transfer or stale sealed region.
4. Cut sensor/data power: objective gas continues, displayed measurements become
   stale, and crew reports may restore partial knowledge.
5. Save/reload mid-decompression and match subsequent state hashes.
6. Add a mod gas and exercise storage, transfer, display, breathing, fire, save,
   and migration paths.

## Fire and combustion

### Purpose and player experience

Fire is a cross-system emergency, not a random damage decal. It consumes fuel and
oxidizer, produces heat/smoke/byproducts, spreads through materials, damages
equipment and bodies, creates work, and can be starved, cooled, suppressed, or
isolated.

### Authoritative state and units

A `FireCell` stores burning fuel sources, reaction rate, flame energy, ignition
tick, and source event. Combustible entities/materials store ignition
temperature, available fuel energy, burn rate, heat release, smoke/gas products,
structural damage rate, and self-extinguish threshold.

Ignition requires temperature, fuel, and oxidizer thresholds. Combustion removes
actual gas/fuel quantities, adds products and heat, then applies damage. Spread
is heat-mediated; there is no independent percentage roll for adjacent fire.

Explosion definitions convert rapid reactions/pressure vessels into a
deterministic radial impulse, heat, shrapnel, structure damage, and sound event.
Occlusion and distance use stable tile traversal.

### Cadence and ordering

- Ignition/combustion runs after gas transfer at `2t`.
- Immediate extinguishing interactions enqueue cooling/removal before the next
  combustion step.
- Damage and secondary ignition events finalize before health/machine updates.
- Fire work and alerts reevaluate at `5t`.

### Player levers

Set alarm thresholds, sprinkler/suppression policy, fire-door zones, emergency
access, evacuation, equipment stock targets, and fire-response priority. Remotely
close an automated fire door only through an operational authorized controller;
otherwise crew perform it.

### Autonomous behavior

Fire alarms and visible flames create suppression, rescue, isolation, evacuation,
medical, repair, and investigation work. Qualified crew assess routes, equipment,
protective gear, pressure, and policy. Untrained crew normally evacuate rather
than fight.

### Inputs, outputs, and dependencies

Consumes gases, material fuel, heat, suppression reagents, structure state,
machine faults, and crew/item locations. Produces gases, heat, light, damage,
contamination, debris, knowledge observations, work orders, insurance/security
evidence, and `fire_ignited`, `fire_spread`, `fire_extinguished`,
`flashover`, and `explosion` events.

### UI, alerts, and visibility

Visible fire is directly observable through cameras; heat/smoke may be sensor- or
report-derived. The fire overlay distinguishes confirmed flame, alarm zone, heat
risk, smoke, and predicted spread as an explicitly labeled inference.

### Data definitions

`combustible_profile`, `ignition_source`, `suppression_agent`, `fire_alarm`,
`fire_door`, and `explosion_profile` own all rates, products, thresholds, damage,
and safety tags.

### Mod hooks

- `validate:ignite`
- `transform:combustion_step`
- `transform:explosion_effect`
- `observe:fire_ignited`
- `observe:fire_extinguished`
- `observe:explosion`

A transformed combustion step must balance fuel, gases, and energy against named
sources/sinks.

### Save fields

Save burning source IDs, remaining fuel, flame energy, ignition provenance,
suppression state, alarm/fire-door state, and pending explosion wave. Do not save
visual particles.

### Failure and recovery

False alarms and failed sensors are possible and visible as source quality.
Suppression can cause cold, pressure, toxicity, slip, or electrical hazards.
Extinguished materials may reignite until below threshold. A fully destroyed
area remains recoverable through rescue, cleanup, salvage, rebuild, and financial
aid.

### Feature stages

- **Proof:** one solid fuel, one gas fuel, ignition, spread, extinguisher, heat
  and smoke.
- **Vertical slice:** alarms, fire doors, sprinklers, suits, explosions,
  structure/machine/body damage, response work.
- **1.0:** reagent fires, electrical arcs, flashover, varied suppression and
  forensic origin.
- **Deferred:** continuous-fluid flame simulation.

### Acceptance tests

1. Ignite a known sealed-room inventory and balance fuel, gases, heat, smoke,
   damage, and remaining material.
2. Remove oxygen below threshold and observe extinguishing without a random roll.
3. Test water/suppression against electrical and reagent fires, including
   secondary hazards.
4. Trigger identical explosions with different wall layouts and verify stable
   occlusion, damage, and evidence.
5. Lose alarm power during fire; direct observations and crew reports still work
   while remote alarm knowledge does not.

## Electrical power

### Purpose and player experience

Power turns layout, generation, storage, redundancy, maintenance, and load
priority into operational tradeoffs. Failures cascade visibly into life support,
lighting, cameras, doors, production, medicine, and morale.

### Authoritative state and units

Power connectors form incrementally rebuilt graphs. A `PowerNetwork` stores
connected source, storage, breaker, and load IDs; voltage class; generated,
requested, allocated, lost, and stored energy; topology revision; and fault
state.

Machines declare integer watts by mode. Allocation for each network:

1. apply active protection/fault isolation;
2. accept available generation;
3. charge/discharge storage within rate/reserve policy;
4. allocate to loads by emergency tier, configured priority, department policy,
   stable machine ID;
5. account for transmission and conversion loss;
6. update brownout, trip, and thermal/fault state.

Loads receive an integer fraction in ppm and definitions determine behavior under
brownout. Allocation never depends on iteration order.

### Cadence and ordering

- Connector/breaker topology commits before the due solve.
- Source-pinned APC, SMES, and TEG callbacks run on their declared machine
  subcalendar. Ordinary power machinery uses 32 `ds`; the power-net reset
  event retains its `+8 ds` phase.
- Broader generation, storage, allocation, and protection aggregation may run
  at `5t` only where that batching is not observable to a machine interaction.
- Fast faults/arcs created by interactions are applied immediately and force a
  solve that tick.
- Energy meters and cost attribution aggregate at `60t`.

### Player levers

Build generation/storage/distribution, set load priority and emergency tier,
reserve battery percentage, generator targets, breaker policy, department energy
budgets, maintenance thresholds, and automated load shedding. Authorized remote
breakers require power/data/control; manual breakers require crew work.

### Autonomous behavior

Generators follow setpoints and fuel/cooling availability. Protection trips under
defined faults. Engineers inspect, refuel, repair, reset, and upgrade networks.
Machines enter deterministic brownout/fail-safe modes. Crew report dark or failed
areas.

Goon-derived APCs preserve cell, channel, cover/lock, wire, charging, and
operating state; SMES units preserve stored charge plus independent input and
output controls. TEG output remains coupled to the two circulators and their
pressure/temperature state. Feature-level fidelity ledgers distinguish exact
behavior from deterministic engine adaptations and work still deferred.

### Inputs, outputs, and dependencies

Inputs: world connectors, generators/fuel, atmosphere/heat/cooling, machines,
policies, damage, maintenance, and automation signals.

Outputs: allocated power, storage state, heat/loss, fuel consumption, equipment
wear, lighting/camera/data availability, financial usage, tasks, and
`power_network_changed`, `brownout_started/ended`, `breaker_tripped`,
`power_fault`, `battery_threshold`.

### UI, alerts, and visibility

The power overlay shows known networks, flow direction, capacity, demand,
priority, storage runway, breakers, and faults. Network dashboards provide
supply/demand histories and “why unpowered” chains. Readings require working
meters/data; visible darkness and stopped machines can still be reported.

### Data definitions

`power_connector`, `generator`, `storage`, `transformer`, `breaker`,
`power_profile`, and `load_priority_policy` define voltage class, capacities,
efficiencies, failure curves, ports, modes, fuels, sounds, and alerts.

### Mod hooks

- `transform:power_generation`
- `transform:power_demand`
- `transform:power_allocation`
- `validate:breaker_command`
- `observe:power_fault`
- `observe:brownout`

Transform totals must remain nonnegative and energy-accounted.

### Save fields

Save connector/machine modes, breaker states, stored energy, generator fuel and
phase, fault/wear state, network ID counter, policies, meters, and accounting
remainders. Rebuild graphs and validate components after load.

### Failure and recovery

Overload trips protection or heats/damages inadequately protected equipment.
Disconnected components form new networks. A dead station can recover through
local batteries, manual generators, emergency cells, external supplies, and
repair; controls that require power cannot bootstrap themselves.

### Feature stages

- **Proof:** cables, one generator, one battery, prioritized loads, breaker.
- **Vertical slice:** fuel/solar generation, storage, substations, brownouts,
  faults, power meters, life-support and machine coupling.
- **1.0:** multiple voltage classes, conversion, advanced generators, energy
  pricing and sophisticated protection.
- **Deferred:** analog waveform simulation.

### Acceptance tests

1. Allocate insufficient supply across tiers and verify stable winners and
   proportional/definition-specific brownout.
2. Split/merge a loaded network and conserve stored energy while updating every
   consumer in the same solve.
3. Black-start from a dead grid using a manual/emergency source.
4. Trip a breaker under an arc, extinguish/repair/reset it, and trace resulting
   camera, atmos, production, and alert changes.
5. Save/reload with fractional efficiency remainders and match meter totals.

## Pipes, disposal, and data/control

### Purpose and player experience

Utility networks move gas, liquid, waste, items, measurements, and control
authority through visible infrastructure. They share graph mechanics but never
share contents or silently transmit through one another.

### Authoritative state and units

Each connector belongs to exactly one network kind and channel/color. Graph nodes
are ports, junctions, valves/routers, storage, and endpoints.

- Gas pipes store species in `mmol`, volume in litres, energy/temperature, and
  pressure.
- Liquid pipes store ordered miscible mixture batches in `mL`, temperature, and
  contamination.
- Disposal networks store discrete carrier/item IDs, direction, velocity stage,
  and jam state.
- Data networks store connectivity, bandwidth tokens per tick, queued messages,
  authentication domain, latency, and compromised/fault state.

Data messages are deterministic records, not arbitrary Lua calls. Priority order
is alarm, emergency control, command, sensor, then routine telemetry, with stable
sender/message IDs.

### Cadence and ordering

- Graph changes rebuild before use.
- Pumps/valves and gas/liquid transfer run at `5t`.
- Disposal carriers advance at `1t`.
- Data/control queues deliver at `1t`; telemetry originates at sensor cadence.
- Jams, leaks, and authentication changes trigger immediate work/knowledge
  updates.

### Player levers

Lay networks, choose channels, configure pumps/valves/filters/routes, set storage
targets, disposal destinations, data domains, controller authorization, message
priorities, and maintenance thresholds.

### Autonomous behavior

Machines follow configuration and fail-safe definitions. Engineers, janitors,
and technicians respond to leaks, clogs, address conflicts, sensor outages, and
control failures. Bots use data networks only if their definition requires it.

### Inputs, outputs, and dependencies

Inputs: world connectors, power, machine configuration, items/reagents/gases,
damage, access/security, sensors, automation.

Outputs: resource transfer, room releases/leaks, deliveries, waste movement,
sensor/control availability, tasks, and `utility_network_changed`,
`pipe_leak`, `disposal_jam`, `message_dropped`, `control_denied`.

### UI, alerts, and visibility

Separate overlays avoid visual ambiguity. Inspectors show route, channel,
contents/traffic if measured, capacity, blockages, and upstream reason. Data
outages deliberately affect other dashboards' freshness.

### Data definitions

`utility_connector`, `pipe_machine`, `disposal_machine`, `data_device`,
`message_type`, `controller`, and `network_policy` define channel compatibility,
capacity, transfer rules, power, failure, access, and fail-safe state.

### Mod hooks

- `validate:utility_connection`
- `transform:utility_transfer`
- `validate:control_message`
- `observe:utility_fault`
- `observe:data_message_delivered`

### Save fields

Save port/channel configuration, pipe contents/energy, valves/pumps, disposal
carriers/jams, queued data messages, device addresses/authentication, faults,
remainders, network ID counters, and policies. Rebuild graph membership.

### Failure and recovery

Leaks release actual contents. Full outputs cause backpressure or jams rather
than deleting material. Data congestion delays/drops by documented queue rules.
Power loss invokes each device's open/closed/hold fail-safe. Manual local
operation remains possible only where definitions provide it.

### Feature stages

- **Proof:** gas pipe, pump, valve, sensor/data link.
- **Vertical slice:** atmos distribution, waste/disposal path, camera/alarm/control
  data, leaks and jams.
- **1.0:** liquids, chemistry piping, routers, compromised devices, richer
  disposal routing.
- **Deferred:** arbitrary player scripting; advanced automation is post-1.0.

### Acceptance tests

1. Split gas/liquid networks and conserve contents/energy exactly.
2. Fill an output, observe deterministic backpressure, clear it, and resume
   without lost or duplicated items.
3. Saturate a data network and verify priority delivery and stable dropped
   messages.
4. Cut power/data to a remote valve and verify its defined fail-safe and
   player-information consequences.
5. Save/load carriers in transit and messages queued; arrivals match the
   uninterrupted run.
