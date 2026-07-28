# Items, materials, logistics, economy, mining, and manufacturing

## Items, stacks, containers, and ownership

### Purpose and player experience

Items are physical, locatable resources rather than abstract inventory totals.
The player manages storage and policy while crew pick up, wear, carry, use,
damage, contaminate, lose, sell, and recover individual objects.

### Authoritative state and units

An `Item` entity stores:

- content ID, entity ID, quality grade, condition in milli-points, temperature in
  `mK`, mass in `g`, volume in `mL`, material components, and custom state;
- location as exactly one of world tile, held slot, worn slot, container slot,
  machine slot, transport manifest, or abstract external market;
- stack count/quantity where allowed;
- owner kind/ID, department custody, price/acquisition transaction, and theft
  status;
- contamination/reagent references, forensic traces, damage, maintenance, and
  reservation IDs;
- interaction capabilities, tool quality, access/safety tags, and appearance
  state.

Stacking is permitted only when the definition's stack key matches exactly. The
default key includes content ID, material composition, quality, condition band,
temperature band, contamination equivalence, ownership, and custom-state hash.
Merging computes conserved totals and deterministic weighted properties. Splits
inherit provenance and allocate integer remainder to the lower resulting entity
ID.

A container specifies mass/volume capacity, slot rules, access state, sealing,
insulation, pressure handling, allowed/forbidden tags, and nested-depth limit.
Containment cycles and depth greater than eight reject.

### Cadence and ordering

- Pickup/drop/transfer/use resolve as atomic interactions at `1t`.
- Stack normalization follows all item interactions in stable location/item ID
  order.
- Temperature/contamination/wear update at owning subsystem cadence.
- Inventory summaries refresh after item events and at `30t`.

### Player levers

Define stockpiles and custody policies, minimum/maximum stocks, disposal/sale
rules, allowed item tags, locked storage, issue loadouts, quality thresholds, and
department purchase authority. The player cannot place an item directly into a
crew member's hands; they create haul/equip policies.

### Autonomous behavior

Crew reserve and retrieve tools, materials, food, medicine, clothing, and
personal purchases according to tasks, access, ownership, and need. They return,
store, discard, clean, repair, or keep items according to definitions and policy.

### Inputs, outputs, and dependencies

Inputs: manufacturing, cargo, mining, chemistry, service, construction, crew
interactions, world environment, damage, and security.

Outputs: inventory availability, equipment effects, carried mass, material
consumption, ownership/evidence, surfaces/contamination, work prerequisites, and
`item_created/destroyed`, `item_transferred`, `stack_split/merged`,
`container_opened`, `item_damaged`, `ownership_changed`.

### UI, alerts, and visibility

Inventory views aggregate known items but allow drill-down to physical locations,
condition, quality, reservations, and custody. Counts derived from manifests or
reports show confidence and timestamp. Alerts cover unavailable critical
equipment, capacity overflow, forbidden storage, deteriorating stock, and
ownership violations.

### Data definitions

`item`, `stack_profile`, `container`, `equipment_slot`, `interaction`,
`maintenance_profile`, and `ownership_policy` define physical properties,
capabilities, allowed state, appearances, sounds, and material/reagent links.

### Mod hooks

- `validate:item_transfer`
- `transform:stack_key`
- `transform:item_wear`
- `observe:item_created/destroyed`
- `observe:item_transferred`
- `observe:ownership_changed`

### Save fields

Save every item field, containment/location graph, stack quantities/remainders,
custom state, reservations, provenance, ownership, contamination, maintenance,
and item ID counter. Rebuild aggregate inventory indexes after validating exactly
one location and an acyclic containment graph.

### Failure and recovery

Full/invalid destinations reject without moving the source. Destroyed containers
spill survivable contents to their tile; exposed/fragile contents then resolve
normally. Missing items leave tasks waiting and can prompt import, production,
search, substitution, or policy change. Invalid containment blocks save load
rather than deleting goods.

### Feature stages

- **Proof:** loose item, stack, container, hand, machine slot, reservation.
- **Vertical slice:** tools, clothes, materials, food, medicine, ownership,
  condition, contamination, transport manifests.
- **1.0:** full equipment layers, forensic traces, pressure containers, repair
  depth, personal possessions.
- **Deferred:** arbitrary nested storage deeper than eight.

### Acceptance tests

1. Split/merge stacks with odd mass/temperature values repeatedly and conserve
   all authoritative quantities.
2. Race two transfers into a final container slot; one commits and one rejects
   without duplication.
3. Destroy nested containers and verify deterministic spill, damage, evidence,
   and ownership.
4. Save/load every location kind and compare containment/inventory hashes.
5. Add a mod item with custom data schema and exercise stack, storage,
   manufacture, save, and UI paths.

## Materials

### Purpose and player experience

Materials give mining, refining, construction, manufacturing, damage, salvage,
and recycling a common physical vocabulary. A machine part is not merely
“steel-colored”; its composition drives mass, durability, value, conductivity,
flammability, and reclamation.

### Authoritative state and units

A material composition is an ordered map of material content IDs to integer
grams. Sum equals item/component mass unless a definition explicitly includes
non-material payload mass.

Each material defines density, hardness, tensile strength, thermal/electrical
conductivity, heat capacity, ignition/melting/boiling points, opacity, corrosion,
radiation response, market base value, processing tags, and contamination/
recycling behavior in canonical units.

Quality is an integer grade 0–100,000. Production derives it from input quality,
machine condition, operator skill, recipe difficulty, environment, and process
control through a recipe-defined bounded formula. Quality modifies only
definition-declared properties.

Material forms—ore, chunk, powder, sheet, rod, cable, cloth, glass, fluid, part—
are items with conversion recipes. No generic conversion is implied.

### Cadence and ordering

Material effects are queried at interaction time. Thermal phase/corrosion changes
run with environment or chemistry cadence. Aggregate conservation ledgers update
with every material creation, conversion, destruction, export, or map-boundary
transfer.

### Player levers

Set allowed substitutions, minimum quality, preferred/restricted materials,
salvage/recycle policy, refinement quotas, and strategic reserves.

### Autonomous behavior

Production and construction planners choose exact allowed inputs using policy,
quality, availability, distance, cost, and reservations. Crew do not substitute
an undeclared material merely because it shares a tag.

### Inputs, outputs, and dependencies

Inputs: mined/imported goods, recipes, heat/chemistry, wear/damage, and recycling.
Outputs: item physical properties, recipe eligibility, construction strength,
tool capability, market value, waste/byproducts, and conservation diagnostics.

### UI, alerts, and visibility

Material dashboards show known stocks by form, committed/reserved/free amounts,
quality, source, destination demand, and conversion graph. Inspectors list the
effective property calculation and substitutions.

### Data definitions

`material`, `material_form`, `material_substitution_group`, `quality_formula`,
and `phase_transition` own physical properties, units, tags, colors, and
conversion constraints.

### Mod hooks

- `transform:material_property`
- `validate:material_substitution`
- `transform:production_quality`
- `observe:material_converted`

Hooks cannot create negative mass or unrecorded source/sink.

### Save fields

Composition lives with physical entities. Save conservation-ledger totals,
material process batches, phase/corrosion state, and quality provenance. Definitions
are content-locked, not duplicated.

### Failure and recovery

Invalid/zero-mass compositions reject content. Lost material is represented as
export, disposal, vapour, surface, or destroyed-unrecoverable with a reason;
there is no silent deletion. Low-quality materials produce declared performance
and can be reworked, downgraded, recycled, or sold.

### Feature stages

- **Proof:** ore → refined material → sheet → part with mass conservation.
- **Vertical slice:** several ores/materials/forms, substitution, quality,
  salvage and waste.
- **1.0:** broad Goon-inspired materials, phase/corrosion and exotic traits.
- **Deferred:** molecular-scale material simulation.

### Acceptance tests

1. Execute a multi-step refine/build/destroy/recycle loop and balance grams by
   material and named loss.
2. Produce the same recipe at skill/condition extremes and verify bounded,
   explainable quality.
3. Attempt forbidden substitution; planning reports it without consuming input.
4. Change a material through a mod replacement and require save migration when
   its semantics/hash differ.

## Logistics and stock control

### Purpose and player experience

Logistics connects demand to real stored goods and available hauling labor.
Shortages should emerge from purchasing, production, placement, access, capacity,
and traffic—not from invisible global inventories.

### Authoritative state and units

A `StockRule` stores zone/container target, accepted item/material tags,
minimum/target/maximum quantities, quality/condition limits, department
ownership, source priority, destination priority, and overflow behavior.

A `HaulRequest` stores source/destination/item or filter, quantity, owner,
priority, reservation, carrier constraints, route, deadline, and lifecycle.

Supply availability distinguishes:

- on hand and free;
- reserved for a specific task/order;
- inbound via an active haul/import/production order;
- inaccessible or unknown;
- quarantined/forbidden; and
- forecast from a process, which is never reservable before produced.

An item can have at most one transfer reservation. Capacity is reserved at the
destination before pickup. A haul commits item location only on pickup/drop
interaction boundaries.

### Cadence and ordering

- Demand changes create/update haul requests immediately.
- Request coalescing and source matching run at `10t`.
- Haulers select work through normal work AI.
- Inventory forecast and stock compliance aggregate at `30t`.
- Long-term reorder forecasts update at `300t`.

### Player levers

Draw stockpiles, set min/target/max and filters, assign custody, link preferred
sources, set haul priorities, forbid areas/items, choose carts/containers, and
configure automatic requisition or production suggestions. Auto-buy requires an
explicit budget and price ceiling.

### Autonomous behavior

The matcher chooses a deterministic source by eligibility, expiry/condition
policy, distance, quality fit, ownership, and stable item ID. It groups compatible
goods up to carrier capacity without changing task priority. Haulers fetch
containers/equipment and report unreachable/full/forbidden destinations.

### Inputs, outputs, and dependencies

Inputs: stock rules, physical items/containers, work AI, paths/access, production
orders, cargo manifests, reservations, ownership, perishable state, and budgets.

Outputs: haul work, inventory forecasts, reservations, procurement/production
suggestions, fulfilled material requests, and `stock_below_minimum`,
`haul_created/completed/failed`, `destination_full`, `inventory_discrepancy`.

### UI, alerts, and visibility

The logistics dashboard traces demand → reservation → source → haul → consumer.
It shows free/committed/inbound quantities and physical bottlenecks. Counts rely
on scans/manifests/reports, so theft or sensor loss may create discrepancies.

### Data definitions

`stock_rule_template`, `haul_profile`, `carrier`, `source_selection_policy`,
`inventory_sensor`, and `reorder_policy`.

### Mod hooks

- `validate:stock_accepts_item`
- `transform:source_score`
- `observe:stock_threshold`
- `observe:haul_lifecycle`
- `validate:auto_requisition`

### Save fields

Save stock rules, haul requests, reservations, destination capacity claims,
inventory observations/discrepancies, reorder state, and counters. Rebuild
physical item indexes and revalidate locations.

### Failure and recovery

Missing/destroyed goods invalidate reservations and reopen demand. A full
destination leaves cargo with the hauler/source under safe fallback policy.
Repeated unreachable tasks back off and alert. Inventory discrepancies trigger
recount/search/security work; they do not materialize replacement stock.

### Feature stages

- **Proof:** stockpile, source match, capacity reservation, autonomous haul.
- **Vertical slice:** min/max stocks, carts/containers, production/import links,
  departmental custody, perishables.
- **1.0:** sophisticated routing, cross-docking, inventory scans, personal
  deliveries and secure/temperature-controlled storage.
- **Deferred:** direct player dragging of items.

### Acceptance tests

1. Fulfill competing construction/medical demands from limited stock according
   to reservation and priority, with no double allocation.
2. Fill the destination after pickup and verify safe fallback without item loss.
3. Lose knowledge of one store and verify forecasts become uncertain while
   objective items remain.
4. Save/load all haul phases and match item location/reservation outcomes.
5. Coalesce hundreds of requests without changing which high-priority demand is
   fulfilled first.

## Economy, budgets, payroll, and trade

### Purpose and player experience

The economy gives the station and its inhabitants separate incentives. Station
and department budgets govern investment and procurement; personal wages and
spending affect welfare, retention, and internal service demand.

### Authoritative state and units

Money uses integer hundredths of a credit (`cr¢`). Every balance derives from an
append-only double-entry ledger; balance is never directly mutated.

Account types:

- station operating, capital, reserve, debt, insurance, and escrow;
- one operating account per department;
- one personal account per crew member;
- vendor/market/external agency accounts; and
- scenario grant/contract accounts.

A `Transaction` stores stable ID/tick, debit postings, credit postings, reason
content ID, source event/command, department, contract/order IDs, visibility,
and audit metadata. Sum of postings is zero.

Budgets are authorization envelopes by account/category/period with limit,
committed, spent, approver, and overdraft rule. Reservations commit authorization
but are not ledger transactions until purchase/payable conditions occur.

Wages accrue per worked/scheduled definition and settle at shift end, including
overtime, hazard pay, bonuses, deductions permitted by scenario policy, and
arrears. Personal spending occurs at physical vendors/services, transferring
personal funds to owning accounts and consuming actual stock/service capacity.

Markets quote imports/exports by content ID, quality, quantity band, delivery
window, reputation, incident modifiers, and deterministic market stream. A quote
locks price only through its expiry tick. Orders move through
`draft → authorized → submitted → in_transit → delivered/failed/cancelled`.

### Cadence and ordering

- Budget validation/reservation occurs with the initiating command/order.
- Purchases, sales, fees, and personal transactions post at their physical or
  contractual completion tick.
- Wage/utility/maintenance accrual updates at `60t`.
- Market quotes update at `300t`; existing quotes remain until expiry.
- Payroll, interest, grants, fines, contract settlement, statements, and budget
  rollover occur in defined shift-boundary order.

Shift settlement order is: close physical transactions → accrue final wages/
upkeep → contract export acceptance → grants/fines/insurance → payroll →
interest/debt → department allocations → grade/report.

### Player levers

Allocate department budgets, set category limits and approvers, wages, overtime,
hazard pay, vending/service pricing, procurement price ceilings, import/export
orders, contracts, insurance, debt repayment, emergency credit, and reserve
targets.

The player cannot spend personal accounts or fabricate a sale; purchases are
crew choices at real vendors.

### Autonomous behavior

Departments issue requisitions within delegated limits. Crew form spending
intent from needs, preference, price, funds, schedule, stock, and route. Vendors
transact if operational and supplied. External markets deliver/accept according
to contracts and transport capacity.

### Inputs, outputs, and dependencies

Inputs: jobs/time worked, personal needs, vendors/services, inventory,
manufacturing/mining, cargo transport, energy/upkeep, incidents, security fines,
research grants, contracts, reputation, and policies.

Outputs: authorization, prices, orders, transport manifests, wages, personal
consumption demand, morale/grievances, debt/recovery, department constraints,
shift grade, and:

- `transaction_posted`
- `budget_threshold`
- `purchase_authorized/denied`
- `payroll_settled/shortfall`
- `market_quote_changed`
- `order_state_changed`
- `contract_fulfilled/failed`
- `insolvency_warning`

### UI, alerts, and visibility

Ledgers show balance, available/committed funds, budgets, cash flow, forecast,
transaction drill-down, and source physical event. Department/personal aggregate
views respect privacy policy; a director sees payroll and station-vendor
transactions but not arbitrary external personal purchases unless scenario law
allows it.

Alerts cover forecast payroll shortfall, exceeded category, expiring quote,
late delivery, contract risk, department insolvency, suspicious discrepancies,
and debt conditions.

### Data definitions

`account_type`, `budget_category`, `transaction_reason`, `wage_policy`,
`vendor_profile`, `market`, `contract`, `grant`, `insurance_policy`,
`bailout`, and `pricing_policy`.

### Mod hooks

- `validate:budget_authorization`
- `transform:market_quote`
- `transform:wage_due`
- `transform:shift_settlement`
- `observe:transaction_posted`
- `observe:order_state_changed`
- `observe:payroll_shortfall`

Transforms return balanced postings or bounded price/wage values with reason
lines. They cannot alter prior ledger entries.

### Save fields

Save account IDs, every ledger posting, budget envelopes/reservations, accrual
remainders, wage agreements/arrears, quotes/expiry, market RNG, orders/manifests,
contracts, grants, insurance, debt terms, reputation, transaction counters, and
settlement state. Derived balances and reports rebuild and must reconcile.

### Failure and recovery

Unaffordable commands reject or remain awaiting authorization; they never create
negative balances unless an explicit overdraft/debt policy permits it. Payroll
shortfall creates proportional or contract-priority arrears according to
scenario law, grievances, and recovery choices. Normal campaigns offer bailout
credit, emergency supply, downsizing, asset sales, contract renegotiation, and
evacuation/restart; insolvency is pressure, not immediate deletion.

Ledger imbalance is a fatal simulation diagnostic and blocks saving that tick.
An external delivery failure follows contract refund/penalty rules.

### Feature stages

- **Proof:** station/department/personal accounts, balanced ledger, purchase,
  wage, import/export.
- **Vertical slice:** budgets, payroll, vending, requisitions, markets,
  contracts, export income, bailout debt, shift statement.
- **1.0:** insurance, grants, fines, reputation, richer services/pricing and
  economic scenarios.
- **Deferred:** speculative securities and multiplayer trade.

### Acceptance tests

1. Run a full shift and reconcile every account/posting to zero-sum, including
   payroll, vending, imports, exports, interest, and grants.
2. Reserve the same department funds for two purchases; deterministic
   authorization prevents overspend.
3. Make payroll unaffordable and verify arrears, personal balances, grievances,
   reports, and bailout options.
4. Buy food personally: actual stock, crew funds, vendor/department account,
   need, and tax/fee postings all update once.
5. Save during an in-transit order and settle identically to uninterrupted play.
6. Inspect a transaction and trace it to command, order, physical goods, and
   source event.

## Mining and remote extraction

### Purpose and player experience

Mining supplies raw material while consuming labor, transport, equipment, time,
and risk. Remote maps make expedition planning meaningful without adding station
decks.

### Authoritative state and units

A mining-site definition creates a single-plane map with seeded deposits,
terrain, hazards, salvage, transport endpoints, and finite resource quantities.
Deposit tiles store composition in grams, hardness, accessibility, stability,
temperature/atmosphere, radiation or exotic traits, and discovered state.

Extraction is staged work: survey → clear/access → extract → collect → load →
transport. It consumes tool wear/power/fuel and produces physical ore, waste,
dust, noise, heat, instability, and possible hazards.

Transport has capacity in mass/volume/passengers, departure/arrival tick,
manifest, fuel/energy, route condition, and docking endpoints. Crossing a map
boundary occurs only at a scheduled atomic departure/arrival.

### Cadence and ordering

- Survey and extraction labor progress at `1t`.
- Site hazard/environment updates at full map cadence while occupied.
- Transport schedules update at `1t`.
- Deposit/production forecasts update at `300t`.
- Empty stable sites use `60t` coarse steps; active hazard or living crew
  prevents coarse simulation.

### Player levers

Select sites, survey areas, designate extraction/avoidance zones, set material
quotas and priorities, schedule crews/transports, choose equipment/stock targets,
and set hazard/abort policy. The player does not click individual rock actions or
drive a miner.

### Autonomous behavior

Miners select eligible deposits based on quota, knowledge, value, risk, route,
equipment, and transport capacity. They stage supplies, extract, haul to the
endpoint, abort/report hazards under policy, and return according to schedule/
needs.

### Inputs, outputs, and dependencies

Inputs: scenario generation, work/jobs, navigation, tools, power/fuel, remote
environment, transport, logistics quotas, materials and market value.

Outputs: ore/salvage/waste, equipment wear, injuries, discoveries, transport
manifests, research/security events, map depletion, and
`deposit_discovered/depleted`, `extraction_completed`, `site_hazard`,
`transport_departed/arrived/failed`.

### UI, alerts, and visibility

The remote-site view shows only surveyed/camera/reported facts. Planning lists
known yield ranges, hazards, crew/equipment, manifest capacity, return schedule,
and station demand. Alerts cover stranded crew, missed transport, depleted quota
material, tool/supply shortage, and detected site hazard.

### Data definitions

`mining_site`, `deposit`, `terrain`, `survey_method`, `extraction_method`,
`site_hazard`, `transport_vehicle`, and `transport_schedule`.

### Mod hooks

- `transform:site_generation`
- `validate:extraction_attempt`
- `transform:extraction_yield`
- `observe:deposit_discovered/depleted`
- `observe:transport_state`

Yield transforms balance deposit mass to products/waste and cannot mine
undiscovered/nonexistent mass.

### Save fields

Save seed/generated tile/deposit deltas, survey knowledge, deposit quantities,
extraction tasks, hazards, physical items/crew through owning systems, transport
state/manifests, site RNG, coarse-sim state, quotas, and depletion history.

### Failure and recovery

Hazards may injure, trap, destroy equipment, block paths, or damage transport.
Recovery includes abort, rescue expedition, remote shelter, resupply, alternate
site/imports, repairs, and evacuation. Transport never silently drops manifest
contents; destruction resolves items/passengers at a defined site/event.

### Feature stages

- **Proof:** one seeded site, ore deposit, extraction, shuttle manifest.
- **Vertical slice:** several materials, survey, hazards, quotas, transport and
  ore return.
- **1.0:** derelicts, salvage, debris fields, richer hazards and expeditions.
- **Deferred:** direct vehicle piloting, multi-plane sites, telescience.

### Acceptance tests

1. Extract a finite deposit and reconcile initial deposit mass to ore, waste,
   dust, and remaining mass.
2. Depart at the exact boundary while a haul is incomplete; only manifested
   items travel.
3. Lose the return transport and produce deterministic stranded/rescue state
   without deleting crew or cargo.
4. Coarse-sim and full-sim an eligible empty site over equal time and match
   aggregate resources/hazards within declared exact rules.
5. Save/load in transit and preserve arrival tick, manifest, occupants, and
   subsequent state.

## Manufacturing and production planning

### Purpose and player experience

Manufacturing converts extracted/imported resources into the parts, equipment,
food, medicine, and goods that keep the station working. Production is a chain of
physical machines, recipes, logistics, labor, power, quality, and waste.

### Authoritative state and units

A `Recipe` is a finite ordered stage graph. Each stage specifies:

- accepted exact items/material groups and quantities;
- catalysts/tools, machine capabilities, operator skill/certification;
- environment ranges, power/energy, time/work-seconds, and process settings;
- deterministic products/byproducts/waste, mass/energy accounting, quality
  formula, failure products, and interruption rule.

A `ProductionOrder` stores product ID/quantity or target-stock link, recipe
choice, department/budget, priority, quality/material constraints, batch size,
allowed machines/sources, deadline, current/inbound/reserved quantities,
stage/batch records, and lifecycle.

Machine state stores capabilities, slots/contents, queue, process phase/progress,
settings, power/utility demand, condition/wear, cleanliness/contamination,
temperature, operator reservation, and fault.

Inputs are consumed only at a stage's declared `commit_point`. Before that,
interruption releases them; after it, the stage resumes or produces declared
failure/salvage. Outputs appear atomically into reserved output capacity.

### Cadence and ordering

- Planner expands orders and reserves capacity/material at `10t` and relevant
  change.
- Production planning and non-source-native automation may advance at `10t`;
  each source-pinned device advances on its declared `ds` process tier and
  completion deadline.
- Power/environment predicates are sampled each process tick.
- Machine wear/maintenance forecasts update at `60t`.
- Stock-linked orders reevaluate at `30t` with hysteresis: start below minimum,
  stop only at target.

### Player levers

Create quotas/batches, choose recipe/material/quality, prioritize, set machine
queues and allowed sources, configure stock-linked production, reserve strategic
capacity, approve overtime/hazard, and set waste/byproduct destinations.

The player cannot manually advance a stage or place inputs into a machine; work
and logistics do so.

### Autonomous behavior

The planner selects a deterministic feasible recipe and machine chain by policy,
available/inbound resources, capacity, quality, distance, cost, power, and
deadline. It creates haul, operate, maintenance, and cleanup work. Machines run
autonomously only where their definitions allow.

Goon-derived production devices keep their upstream distinctions. A
manufacturer has a 20-entry queue and 20-item output cap, ready/working/halt
modes, repeat and pause controls, normal speeds 1–3 (hacked 5, damaged 8), and
draws 200 W idle plus `750 × speed²` W while active. Required material is
rechecked and consumed at completion. Its four globally color-randomized wires,
damage thresholds, and repair state are machine behavior, not recipe metadata.
A nanofab performs its source-style immediate fabrication action and has no
manufacturer queue. A portable reclaimer is an unpowered physical processor
whose sequential, composition-aware material recovery must not be replaced by
an abstract refinery conversion. Deferred material banking, subtype catalogs,
slot binding, and composition remainder work remains visible in each
definition's fidelity ledger.

### Inputs, outputs, and dependencies

Inputs: materials/items, logistics, work/skills, machines, power/utilities,
environment, economy/budget, research unlocks, sanitation, and stock demand.

Outputs: goods, parts, reagents, byproducts/waste, heat/contamination, resource/
capacity reservations, experience, costs, wear, and
`production_order_state`, `batch_started/completed/failed`,
`machine_starved/blocked/faulted`, `quality_below_target`.

### UI, alerts, and visibility

The production planner displays the dependency graph, free/reserved/inbound
inputs, machine capacity, estimated labor/power/cost, output destination, quality
drivers, waste, and critical path. Every stalled node provides one or more stable
blockers.

Alerts cover critical-stock order blocked, output full, missing recipe/machine,
quality failure, hazardous process condition, maintenance overdue, and demand
loop/cycle.

### Data definitions

`recipe`, `recipe_stage`, `machine`, `machine_capability`, `process_profile`,
`quality_formula`, `production_policy`, and `maintenance_profile`.

The loader rejects cycles without an explicit external input, negative or
unbalanced quantities, missing commit/interruption semantics, unbounded queue,
and recipes whose products collide with inputs ambiguously.

### Mod hooks

- `validate:production_order`
- `transform:production_plan_score`
- `validate:process_stage_start`
- `transform:process_output`
- `transform:production_quality`
- `observe:batch_state`
- `observe:machine_fault`

Output transforms must provide a balanced material/reagent/energy account.

### Save fields

Save orders, expanded plans, batches/stages, reservations, machine queues/slots/
settings/progress/remainders/condition, committed inputs, output capacity, recipe
version/hash, counters, and planner backoff. Rebuild feasibility indexes and
forecasts.

### Failure and recovery

Missing input/capacity/power/labor blocks with reason. Machine damage pauses or
applies recipe-defined failure at a safe boundary. Output blockage prevents
completion and consumption beyond commit semantics. Recovery includes alternate
recipe/material/machine, imports, repairs, cleanup, salvage, lower quality, and
changed priorities.

### Feature stages

- **Proof:** ore refinery and parts fabricator with two-stage recipe, capacity,
  power and quality.
- **Vertical slice:** refining, sheets/parts/tools, station machine components,
  food and basic medical production, stock-linked orders, waste and repairs.
- **1.0:** chemistry/pharmacy, robotics, research prototypes, broad materials,
  sophisticated assembly/disassembly.
- **Deferred:** unrestricted player code in production machines.

### Acceptance tests

1. Complete a multi-machine recipe and reconcile inputs, outputs, byproducts,
   labor, energy, money, and quality.
2. Interrupt before and after each commit point; verify release/resume/failure
   semantics and no duplication.
3. Fill output capacity mid-batch; the machine blocks safely and resumes after a
   haul.
4. Compete for one machine/input across orders; priority and reservations resolve
   deterministically.
5. Remove recipe content from a save and require a declared migration rather than
   silently changing the in-progress batch.
6. Produce the replacement part needed after a breach/fire and trace mining or
   import through repair completion and station grade.
