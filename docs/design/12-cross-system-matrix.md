# Cross-system matrix

This document is the integration contract. An arrow means the destination reads
a public query or consumes an immutable event; it never mutates the source's
tables.

## Ownership and exchange

| System | Solely owns | Consumes | Publishes to |
|---|---|---|---|
| World | tiles, maps, footprints, rooms, region/topology revisions | construction commits, entity projections, doors | environment, utilities, navigation, zones, knowledge, rendering |
| Zones | intent geometry and effective policy resolution | world rooms/tiles, director commands | work, logistics, access, sanitation, service, medicine, UI |
| Construction | blueprints, stages, incorporated materials, inspections | world, items/materials, logistics, work, economy, environment, utilities | world mutations, tasks, resource consumption, ledgers, noise/dirt |
| Atmosphere/heat | gas cells, gas amount/energy, pressure/temperature derivation | world seals, machines/pipes, fire, bodies, chemistry | health, fire, paths, rooms, sensors, incidents |
| Fire | burning state, combustion progress, explosion propagation | gases/heat, materials, reagents, structures, machines | atmosphere, damage, sanitation, work, knowledge, incidents |
| Power | electrical graphs, generation/allocation/storage/faults | world connectors, fuel/cooling, machines, policy | every powered machine, meters, economy, work, knowledge |
| Other utilities | pipe/disposal/data graphs and contents/queues | world, power, machines, items/gases/reagents, access | environment, logistics, sanitation, sensors/control, knowledge |
| Crew | identity, needs, psychology, relationships, intent, personal knowledge | jobs, work, paths, health, environment, items, economy, services | labor/actions, reports, purchases, mood, staffing, incidents |
| Jobs | departments, employment, schedules, staffing/performance | crew, tasks, budgets, policy, facilities | work eligibility, access, payroll, forecasts |
| Work | order lifecycle, claims, reservations, progress | all work owners, crew/jobs, paths, items/logistics, policy | crew intents, labor/results, blockers, backlog |
| Navigation | portal/local path caches, movement/door queues | world, access, personally known hazards, occupancy | crew/bot movement, route cost/blockers, traffic |
| Items | physical items, stacks, containment, locations, ownership | interactions, materials, environment, production/cargo | logistics, work, crew, economy, security, sanitation |
| Materials | material definitions, composition rules, conservation ledger | mining/imports, processes, damage/recycling | item properties, construction/production inputs, value |
| Logistics | stock rules, haul requests, transfer/capacity reservations | items, zones, work, paths, production/cargo demand | work, consumers, inventory forecasts/discrepancies |
| Economy | accounts, ledger, budgets, quotes/orders/contracts, debt | jobs, trade, services, utilities, incidents/objectives | authorization, manifests, wages, prices, grade/progression |
| Mining | deposit/site/extraction/transport state | remote world, work, tools, environment, logistics, markets | materials/items, manifests, discoveries/hazards |
| Manufacturing | production orders, batches, machine processes | items/materials, logistics, work, utilities, economy, research | goods, waste/heat, experience, stock fulfillment |
| Food/agriculture | crop/animal growth, food composition, digestion inputs | environment, utilities, work, items, sanitation, economy | food/items, needs/health, waste, revenue, disease |
| Service | offerings, queues, comfort, service state | rooms, crew, schedules, items, utilities, economy, sanitation | needs/mood, relationships, purchases, traffic, waste |
| Sanitation | surfaces, waste flow, laundry, pests | bodies/items, services/production, utilities, disease, evidence | hazards, health, mood, work, recycling, knowledge |
| Medical | anatomy, physiology, wounds, cases, disease, cloning | environment, damage, reagents, food, sanitation, work, policy | capability, death/recovery, records, waste, staffing/incidents |
| Chemistry | mixtures, reactions, metabolism effects, provenance | containers/machines, heat, workers, definitions | medical, fire/atmosphere, food, sanitation, agriculture, production |
| Research | proposals, observations/data/insight, artifacts/genetic research | staff, samples, apparatus, utilities, budgets, safety | unlocks, prototypes, grants, hazards, knowledge |
| Automation | controller/bot state and typed control commands | sensors/data/power, work, paths, access, machines | validated actuator commands, bot labor, reports/faults |
| Security | credentials, cases, evidence/custody, authority/detention | observations, crew acts, world/access, items, records | access results, work, custody/force, reports, fines/reputation |
| Incidents | threat/RNG/cooldowns and incident hidden/stage state | scenario, public system metrics, prerequisite queries/events | validated physical commands, objectives, messages, recovery |
| Progression | scenario/objectives, score evidence, history/unlocks/reputation | all public events/queries, settlement, incident results | rewards, content eligibility, reports, recovery/end choices |
| UI/knowledge | presentation profile and projected read models; knowledge service owns observations | all public events/queries and sensor/report sources | commands, alerts, explanations; never objective state mutation |

## Canonical integration events

Event names use `<domain>.<past-tense-fact>`. Payload schemas live with the owner.
The following are stable cross-system families; a consumer must not infer the
same transition by polling internal fields.

| Event family | Required core payload | Primary consumers |
|---|---|---|
| `world.tile_changed` | map/tile, old/new layer IDs, cause, revisions | environment, utilities, navigation, construction, rendering |
| `world.topology_changed` | map, region kinds, dirty bounds/revisions | rooms, atmosphere, navigation, sensor coverage |
| `construction.stage_completed` | blueprint/stage, worker(s), consumed/incorporated, footprint | world, items/materials, economy, progression |
| `atmos.threshold_crossed` | observed cell/room, metric, old/new band, objective value | health, fire, paths, sensors, incidents |
| `fire.ignited/extinguished/explosion` | source, location, fuel/effect profile, provenance | environment, damage, sanitation, security, incidents |
| `power.brownout/fault` | network, affected load IDs, allocation/cause | machines, life support, sensors, work, economy |
| `utility.fault/message_delivered` | network/device/message IDs, cause/result | automation, knowledge, work, systems owning endpoints |
| `crew.reported/refused/incapacitated/died` | person, known subject/reason/source | knowledge, jobs/work, medical, incidents, progression |
| `job.employment_changed/schedule_transition` | crew, old/new job/schedule, terms | crew, access, work, economy, UI |
| `work.lifecycle` | task, owner, state, claimant, reason/progress | crew, owner, UI, objectives |
| `navigation.entity_moved/path_failed` | entity, from/to or goal, known blocker | work, environment exposure, UI |
| `item.created/destroyed/transferred` | item/quantity, old/new location, cause | logistics, tasks, economy, security, objectives |
| `material.converted` | input/output material ledger lines, process | production, economy, progression, diagnostics |
| `logistics.stock_threshold/haul_lifecycle` | stock rule/request, amount, state/reason | production, construction, procurement, UI |
| `economy.transaction/order/payroll` | ledger/order IDs, balanced postings/state | crew, logistics, progression, UI |
| `mining.deposit/transport` | site/deposit/manifest, state/quantity | logistics, production, research, incidents |
| `production.batch/machine_fault` | order/batch/machine, products/state/reason | logistics, economy, work, objectives |
| `food.crop/meal` | plant/food/consumer, products/nutrition/state | items, health, needs, economy, sanitation |
| `service.lifecycle/comfort_threshold` | offering/request/room, outcome/band | crew, economy, staffing, progression |
| `sanitation.surface/waste/pest` | location/entities, amounts/state/provenance | health, paths, security, service, work |
| `medical.health/case/treatment/death/clone` | patient/body/case, transition, known record scope | crew/work, staffing, incidents, progression |
| `chemistry.reaction/exposure` | mixture/container/body, balanced changes, provenance | medical, fire/atmos, sanitation, security |
| `research.observation/unlock/safety` | proposal/run/evidence/unlock, visibility | content eligibility, economy, incidents, progression |
| `automation.rule/actuator/bot` | device/rule/command/task, trace/result | controlled system, security audit, work, UI |
| `security.access/case/evidence/detention` | subject/object, authority/evidence, outcome scope | doors/work, crew, medical, progression |
| `incident.lifecycle` | incident/stage, known/hidden projection key, outcome | objectives, recovery, progression, UI |
| `progression.objective/shift/unlock` | objective/score/unlock, evidence lines | economy/campaign, content registry, UI |

## Command ownership

| Player intent | Command owner | Required validators |
|---|---|---|
| place/cancel blueprint | construction | world footprint, budget, policy, content |
| draw/change zone | zones | world bounds, zone conflict, access/policy |
| change utility setting | owning utility | device, access/control, safety, power/data if remote |
| set priority/policy | policy owner | scope, authority, schema, budget where relevant |
| hire/promote/schedule/wage | jobs | candidate/crew, contract, access, economy |
| requisition/import/export | economy/cargo | budget, quote/contract, logistics capacity |
| create production order | manufacturing | content unlock, recipe, budget, policy |
| start research proposal | research | unlock/prerequisite, budget, authorization |
| set automation rule | automation | typed expression, authority, operation budget |
| issue security authority | security | law/policy, evidence threshold, issuer role |
| declare emergency/evacuate | incident/scenario policy | issuer, scope, current declaration rules |
| accept recovery/abandon | progression | available offer, settlement/state safety |

The owning system commits its portion atomically and emits events. Validators may
deny but do not apply side effects.

## Cross-system invariants

1. **No silent creation or deletion.** Money, materials, items, gases, reagents,
   nutrition, energy, and people cross boundaries through balanced events with a
   named source/sink.
2. **No direct pawn control.** All labor reaches crew/bots through work offers,
   goals, policies, or automation.
3. **One physical location.** Every item/body/bot/machine is at exactly one world,
   containment, transport, or declared external location.
4. **One state owner.** Derived views may cache but never become authoritative.
5. **Knowledge is not truth.** Player-facing consumers use projected observations.
6. **Reservations are exclusive/accounted.** The same quantity/capacity/funds
   cannot satisfy two commitments.
7. **Physical failures persist.** Incident/objective completion does not clean,
   heal, repair, refund, or restore unless it creates a normal physical process.
8. **Save at boundary.** A save captures a completed tick with no half-committed
   transition.
9. **Stable order.** Cross-system collections/events/commands use the foundation
   ordering; mods cannot supersede tie-breaking.
10. **Presentation independence.** Graphics, audio, UI, accessibility, camera,
    and render timing never affect simulation state.

## Required cascade scenarios

### Power-loss cascade

```text
generator fuel/fault
→ power allocation and breakers
→ life support, lights, data/cameras, doors, machines, refrigeration
→ atmosphere/knowledge/access/production/food changes
→ crew safety, work routes, health, queues, spoilage
→ labor and service capacity
→ contracts, payroll forecast, welfare and shift grade
→ repair, fuel import, load shedding, manual black-start
```

No later system simulates “power outage” independently; it responds to actual
allocation/fault events.

### Hull breach and fire cascade

```text
meteor/structural damage
→ world boundary/topology change
→ gas/heat flow and decompression force
→ door/fire control, exposed crew/items/machines
→ injury, fire/combustion, smoke and contamination
→ evacuation/rescue/suppression/treatment work
→ unavailable labor and blocked production/logistics
→ construction material/component demand and medical/sanitation load
→ financial/contract/incident recovery and grading
```

### Production economy cascade

```text
contract/stock minimum
→ production order and budget authorization
→ recipe/machine/input plan
→ import or mining survey/extraction/transport
→ refining, haul, staged manufacture and quality
→ stock delivery/export
→ ledger revenue, wages/personal spending, department budget
→ maintenance/waste/heat/cleaning and next demand
```

### Food and labor cascade

```text
crop/import and utilities
→ kitchen logistics and cooking
→ menu stock/price/queue
→ schedule and autonomous meal choice
→ digestion, needs, mood, health
→ attendance/task choice and service demand
→ waste/cleaning and personal/vendor ledgers
```

### Medical-capacity cascade

```text
injury/disease exposure
→ perception/report/triage
→ rescue transport and case plan
→ beds/staff/tests/medicine/procedure capacity
→ treatment or deterioration/death
→ capability and staffing/backlog
→ payroll/insurance/reputation/grade
→ cleanup, rest, cloning/recruitment and policy change
```

### Security-information cascade

```text
objective act
→ witness/camera/log/physical trace (or no observation)
→ report/evidence/case knowledge
→ legal threshold and authority
→ access/search/arrest/force/detention work
→ evidence integrity, medical/welfare and possessions
→ review/release/fine/reputation/grade
```

Hidden guilt never skips the observation/evidence steps.

## Feature-stage integration matrix

`P` = proof fixture, `V` = canonical vertical slice, `1` = complete 1.0, `D` =
explicitly deferred.

| Capability | P | V | 1 | D |
|---|:---:|:---:|:---:|:---:|
| One 192×192 station deck/chunks | ✓ | ✓ | ✓ | |
| Remote mining map/transport | fixture | ✓ | ✓ | |
| Additional decks/cross-map utilities | | | | ✓ |
| Construction/zones/rooms | basic | ✓ | ✓ | |
| Atmosphere/heat/fire | basic | ✓ | ✓ | |
| Power/pipes/data/disposal | basic | ✓ | ✓ | |
| 40–100 detailed crew | benchmark | 24 | ✓ | |
| Jobs/schedules/work/pathing | basic | ✓ | ✓ | |
| Personal relationships/long-term memories | | basic | ✓ | |
| Items/materials/logistics | basic | ✓ | ✓ | |
| Station/department/personal economy | basic | ✓ | ✓ | |
| Mining/refining/manufacturing | basic | ✓ | ✓ | |
| Hydroponics/cooking/nutrition | basic | ✓ | ✓ | |
| Ranching/pests | | | ✓ | |
| Service/recreation/sanitation/laundry | basic | ✓ | ✓ | |
| Anatomy/treatment/cloning | basic | ✓ | ✓ | |
| Detailed surgery/disease/chemistry | basic | subset | ✓ | |
| Research/grants/unlocks | basic | subset | ✓ | |
| Artifacts/genetics | | | ✓ | |
| Bots/declarative automation | basic | subset | ✓ | |
| Station-AI operations assistant | | | ✓ | |
| AI-law politics/advanced programmable automation | | | | ✓ |
| Access/cases/evidence/detention | basic | subset | ✓ | |
| Hidden antagonists | | | | ✓ |
| Incident director/recoverable failure | basic | ✓ | ✓ | |
| Campaign progression/optional hard failure | basic | ✓ | ✓ | |
| Full management UI/accessibility | basic | ✓ | ✓ | |
| Data + trusted Lua mods | loader fixture | examples | stable at 1.0 | |

## Integration test gates

Before a system can move from fixture to vertical slice:

- its owned state and public events are implemented;
- every matrix dependency uses a query/event rather than internal-table access;
- a save/reload fixture exists for every lifecycle;
- player-visible knowledge is tested with sensors on and off;
- relevant conservation/ledger invariants pass;
- a data-only mod can add one definition without core changes; and
- at least one required cascade exercises it.

Before 1.0:

- all six cascade scenarios run for repeated seeds;
- 30-shift soak/replay produces deterministic hashes;
- no core definition relies on load order or hardcoded content ID;
- recovery exists for each major physical/institutional failure;
- UI explanations trace every blocker and score contribution; and
- low-end performance remains within the product contract at 4×.
