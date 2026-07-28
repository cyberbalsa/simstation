# Food, service, and sanitation

## Agriculture, ranching, food, and nutrition

### Purpose and player experience

Food ties agriculture, imports, logistics, cooking, personal schedules, money,
health, mood, and waste into a daily station rhythm. It should be possible to run
a basic cafeteria reliably, while exotic crops, mutations, animals, recipes, and
contamination produce SS13-like stories.

### Authoritative state and units

A plant plot stores crop/seed genotype ID, growth phase/progress, biomass in
grams, water/nutrients/reagents in `mL`, light energy, temperature, atmosphere,
health, pest/disease/contamination, pollination, yield potential, and last-care
tick.

A genotype contains bounded traits for maturation, yield, water/nutrient/light/
temperature ranges, reagent production, mutation stability, harvest method,
perennial behavior, and hazards. Mutation uses the agriculture RNG only at
declared reproductive/stress checkpoints.

An animal stores species/breed, life stage, body/health reference, hunger/thirst,
stress/tameness, products, pregnancy/reproduction state, containment, ownership,
and waste output. Animals use the same navigation/needs principles as crew but a
restricted goal/action set.

Food items store ingredients/materials, total mass, nutritional values in `kJ`
plus protein/fat/carbohydrate/fibre/electrolyte fields, reagents, temperature,
freshness, preparation/cook state, contamination/pathogens, portion count, taste
tags, dietary tags, allergens, and creator/recipe provenance.

Digestion is a body reagent/nutrition process. Eating transfers a physical
portion into the digestive container, then releases nutrition/reagents over time.
Preferences change mood and willingness but do not invent nutritional value.

### Cadence and ordering

- Eating, harvesting, watering, treatment, slaughter, and cooking interactions
  progress at `1t`.
- Growth and animal urgent needs run at `60t`.
- Digestion runs with medicine at `10t`.
- Freshness/pathogens update at `300t`, with elapsed-time catch-up.
- Crop/animal reproduction checkpoints occur at definition-owned intervals of
  at least 300 ticks.
- Meal-demand forecast updates at `300t` and schedule changes.

### Player levers

Designate growing/ranching/kitchen/dining zones; choose crops/breeds; set planting,
harvest, breeding, slaughter, feed, meal, dietary, stock, food-safety, and
pricing policies; create cooking/serving production orders; set meal breaks and
department service budgets.

The player cannot force a crew member to eat a meal or manually mutate a plant.

### Autonomous behavior

Botanists plant, tend, diagnose, harvest, and process crops. Ranchers feed, clean,
handle, treat, breed, and collect animal products. Cooks select recipes under
menu policy, expected demand, stock, equipment, skill, dietary coverage, cost,
and spoilage. Crew select reachable meals by hunger, schedule, preference,
nutrition, dietary restrictions, price, queue, knowledge, and ownership.

### Inputs, outputs, and dependencies

Inputs: seeds/animals, water/reagents, atmosphere, light/power, temperature,
labor/skills, tools/machines, logistics, economy, schedules, health/disease, and
sanitation.

Outputs: ingredients/meals, nutrition/reagents, personal purchases, mood/thoughts,
waste/manure, seeds/animal products, contamination/disease, research specimens,
and:

- `crop_planted/harvested/failed/mutated`
- `animal_born/died/product_ready`
- `food_prepared/served/spoiled`
- `meal_consumed/refused`
- `dietary_need_unmet`

### UI, alerts, and visibility

Agriculture dashboards show measured plot conditions, growth/yield range, stock
and work blockers. The menu planner shows demand by diet/schedule, portions,
nutrition, cost, freshness, kitchen capacity, queues, and waste. Individual taste
preferences are visible only when known through personnel record, prior purchase,
or report.

Alerts cover no edible stock, missing dietary coverage, crop environment failure,
animal welfare threshold, refrigeration/power loss, contamination, spoilage
surge, and meal queue exceeding schedule.

### Data definitions

`crop`, `genotype`, `seed`, `growth_stage`, `agriculture_treatment`,
`animal_species`, `breed`, `feed_profile`, `food`, `nutrition_profile`,
`cooking_recipe`, `taste`, `diet`, `allergen`, and `spoilage_profile`.

Recipes use the manufacturing stage contract and add culinary transformations,
portioning, nutrition/reagent conservation, taste, temperature, and sanitation.

### Mod hooks

- `transform:plant_growth`
- `validate:crop_mutation`
- `transform:harvest_yield`
- `transform:food_preference_score`
- `transform:digestion`
- `observe:crop_state`
- `observe:food_prepared/consumed`
- data additions for crops, animals, food, recipes, diets, and tastes

Transforms cannot create unaccounted biomass, nutrition, or reagents.

### Save fields

Save plots/genotypes/growth inputs/remainders, agriculture RNG, animals and
reproduction, food composition/preparation/freshness/pathogens, demand/menu
plans, meal queues, digestion through medicine, known preferences, and all
production/work links.

### Failure and recovery

Crops can wither, mutate, become diseased/contaminated, or produce low yield.
Animals can escape, suffer, reproduce excessively, spread disease, or die. Food
can spoil, burn, contaminate, poison, or fail dietary needs. Recovery includes
imports, rationing, emergency meals, seed banks, cleaning, treatment, culling,
menu substitution, refrigeration repair, and external medical aid.

Starvation develops through physiology over time; the game never kills a crew
member solely because a UI meter reaches zero on one tick.

### Feature stages

- **Proof:** one crop, one cooking recipe, hunger/digestion, refrigeration.
- **Vertical slice:** hydroponics, several crops, menu/portions/diets, kitchen/
  dining, personal payment, spoilage and contamination.
- **1.0:** ranching, breeding/mutation depth, broad cooking/reagents, pests and
  foodborne disease.
- **Deferred:** ecosystem simulation outside bounded station/remote maps.

### Acceptance tests

1. Grow, harvest, cook, portion, eat, digest, and discard a crop; reconcile
   biomass, nutrition, reagents, water, energy, and waste.
2. Power down refrigeration and verify deterministic spoilage, demand,
   contamination response, and recovery.
3. Serve mixed diets to a scheduled population; the forecast and actual choices
   identify uncovered needs without forcing meals.
4. Save/load at every plant stage and during digestion; match yield and health.
5. Mutate a genotype at a declared checkpoint and verify unrelated RNG streams
   are unchanged.
6. Add a mod crop/recipe/diet and exercise production, menu, consumption, saves,
   and codex.

## Service, recreation, comfort, and personal consumption

### Purpose and player experience

Service makes the station feel inhabited and turns layout, scheduling, staffing,
prices, and amenities into morale and retention. It covers dining, vending,
bars, recreation, social spaces, bedrooms, toilets/showers, and staffed counters.

### Authoritative state and units

A `ServiceOffering` stores provider/facility, service content ID, capacity,
schedule, queue discipline, duration, required staff/stock/utilities, price,
department/owner, access/diet restrictions, privacy, quality, and current state.

A service request stores crew, offering, need/goal, arrival/queue tick,
reservation/appointment, willingness-to-pay, and completion/cancellation reason.
Queues order by emergency/appointment policy, arrival tick, then crew ID.

Comfort is computed per tile/room from furniture, privacy, crowding, noise, light,
temperature, cleanliness, decoration/variety, and personal preference. The
objective score is not directly shown without adequate surveys; crew experience
it and may report.

Recreation interactions create needs relief, thoughts, relationship observations,
item wear/consumption, noise, and possible incidents. Repeating the same activity
has definition-based satiation to encourage variety.

### Cadence and ordering

- Queue/service interactions advance at `1t`.
- Service matching and personal-goal choice use crew cadence (`10t`).
- Room comfort updates at `30t`.
- Recreation satiation and social need update at `60t`.
- Demand/capacity forecasts update at `300t`.

### Player levers

Build/furnish service zones, set hours, staffing, capacity, stock, prices, access,
department subsidy, queue policy, quiet/privacy rules, and amenity targets.
Schedules create break/leisure opportunity; they do not dictate which amenity a
person uses.

### Autonomous behavior

Providers open service when staff, stock, environment, utilities, and schedule
permit. Crew choose offerings by needs/preferences, price/funds, queue/path,
social context, quality, schedule, and knowledge. They may abandon slow queues
or choose free/rest alternatives.

### Inputs, outputs, and dependencies

Inputs: rooms/zones, crew needs/relationships/schedules, jobs, facilities/items,
food/reagents, sanitation, power/utilities, economy, access/security.

Outputs: need/mood/thought changes, relationships, purchases/revenue, item/stock
consumption, queues/traffic, noise/waste, service work, and
`service_opened/closed`, `service_requested/completed/abandoned`,
`comfort_threshold`, `amenity_shortage`.

### UI, alerts, and visibility

The service dashboard shows open hours, staffing/stock, queue, throughput,
revenue/subsidy, demand by time, known satisfaction, and blockers. Comfort and
noise overlays show measured/inferred state. Crew feedback is a report, not
omniscient preference data.

Alerts cover no toilets/water, excessive meal/recreation queues, inaccessible
sleeping space, service closed during scheduled demand, sustained low comfort,
and unaffordable essential service.

### Data definitions

`service`, `service_facility`, `recreation_activity`, `comfort_source`,
`room_amenity`, `queue_policy`, `price_policy`, and `service_schedule`.

### Mod hooks

- `transform:service_choice_score`
- `validate:service_start`
- `transform:service_outcome`
- `observe:service_lifecycle`
- `observe:comfort_threshold`

### Save fields

Save offerings/settings, queues/appointments, active interactions/progress,
capacity reservations, service histories, satiation, demand forecasts, pricing/
subsidy, and comfort source state. Recompute room comfort aggregates.

### Failure and recovery

Unavailable services increase unmet need and complaints, not hidden debuffs.
Queue interruption releases reservations/refunds according to service stage.
Essential sanitation/sleep services can be made free/subsidized or supplied by
emergency fixtures. Damaged leisure/service areas can recover through repair,
temporary facilities, schedule changes, and imports.

### Feature stages

- **Proof:** one staffed service queue and one passive recreation facility.
- **Vertical slice:** dining, vending, bar/recreation, beds, toilets/showers,
  comfort/noise, prices and personal spending.
- **1.0:** broad recreation, service jobs, privacy, social groups, events and
  richer feedback.
- **Deferred:** romance simulation as a required progression mechanic.

### Acceptance tests

1. Run a meal-break queue with insufficient capacity; stable queue order,
   abandon decisions, schedule impact, and demand report match.
2. Change price/subsidy and observe personal spending choices without altering
   physical stock or needs directly.
3. Damage power/water to a service and trace closure, reports, work, temporary
   alternative, and reopening.
4. Save/load an active paid service and ensure it charges/completes/refunds at
   most once.
5. Make an attractive room dirty/noisy/crowded and verify each comfort component
   and crew response is explainable.

## Sanitation, waste, laundry, and pests

### Purpose and player experience

Sanitation converts everyday station activity into visible maintenance pressure.
Dirt, fluids, trash, waste, contaminated clothing, blocked disposal, and pests
affect safety, disease, morale, machinery, evidence, and public performance.

### Authoritative state and units

Each tile surface stores sparse `SurfaceDeposit`s by content ID with amount in
micro-units, wetness, temperature, reagent/pathogen/evidence links, color/
appearance, slipperiness, odour, flammability, spread profile, and creation
provenance.

Items, clothing, bodies, and fixtures have analogous contamination surfaces.
Transfer occurs through contacts using definition-owned coefficients and integer
remainders.

Waste exists as physical items, fluids, gases, or pipe/disposal contents. There
is no generic deleted “trash” amount. Waste policy assigns sorting categories,
destinations, recycling, biohazard, secure destruction, composting, or export.

Cleaning work specifies surface, acceptable agent/tool, amount removable,
reaction/byproduct, captured waste destination, and sanitation target. Cleaning
does not automatically destroy forensic evidence; it degrades or transfers it
according to evidence rules.

Laundry batches reserve clothing, washer capacity, water/detergent/power, process
time, output storage, and contamination compatibility.

Pest populations may be individual entities above a visibility threshold and
aggregate nests below it. They consume food/waste, reproduce at checkpoints,
spread contamination/disease, avoid hazards, and generate signs/observations.

### Cadence and ordering

- Spills/contact/cleaning/disposal movement resolve at `1t`.
- Surface spread, slip state, and drain interaction run at `10t`.
- Cleanliness and odour summaries update at `30t`.
- Pathogen/pest/waste decomposition runs at `300t`.
- Laundry and automated sanitation machines use manufacturing cadence.

### Player levers

Set cleanliness targets and priority by zone; define waste sorting/disposal,
biohazard, evidence-preservation, laundry, spill response, pest-control, and
recycling policies; provide staff, stockpiles, bins, drains, disposals, cleaning
tools/agents, washers, and protective gear.

### Autonomous behavior

Janitors and service staff create/select cleaning, empty-bin, waste-haul,
laundry, unclog, and pest-response work based on thresholds and policy. Crew
create waste, avoid/report severe contamination, use bins when reachable, track
deposits, and change clothing/hygiene behavior.

### Inputs, outputs, and dependencies

Inputs: crew/animals, food/service, medicine/chemistry, items, world surfaces,
water/power/disposal, fire, production waste, disease, security evidence, and
policies.

Outputs: contamination/pathogen transfer, slip/fire/odour hazards, mood/comfort,
cleaning/laundry/waste work, recycled/composted/export goods, evidence change,
pests, and:

- `surface_deposited/removed`
- `spill_threshold`
- `slip_occurred`
- `waste_container_full`
- `disposal_jam`
- `laundry_batch_state`
- `pest_sign_detected/outbreak`
- `sanitation_target_failed`

### UI, alerts, and visibility

Sanitation overlays show known cleanliness, wet/slip risk, biohazard, waste,
odour reports, and pest signs. Inspectors identify deposit source only where
evidence supports it. Dashboards show cleaning backlog, supplies, staff,
zone targets, waste flow, laundry queue, pest confidence, and recurring sources.

Alerts cover biohazard spill, critical-area cleanliness failure, disposal jam/
overflow, clean-clothing shortage, pest outbreak, unavailable cleaning agent,
and cross-contamination.

### Data definitions

`surface_deposit`, `cleaning_agent`, `cleaning_tool`, `sanitation_target`,
`waste_category`, `disposal_policy`, `laundry_process`, `pest_species`,
`pest_control`, and `pathogen_surface_profile`.

### Mod hooks

- `transform:surface_transfer`
- `validate:cleaning_interaction`
- `transform:cleaning_result`
- `observe:surface_changed`
- `observe:waste_processed`
- `observe:pest_state`

Transforms preserve reagent/pathogen/material amounts or record a defined sink.

### Save fields

Save deposits and remainders, item/body contamination through owners, waste
entities/contents, sanitation targets, active work, laundry batches, disposal
state, pest entities/nests/RNG, pathogen state, evidence links, and historical
source metrics.

### Failure and recovery

Spills may spread, ignite, infect, cause slips, obscure evidence, or damage
equipment. Wrong cleaners can react dangerously or spread contamination.
Overflow/jams retain physical waste. Recovery includes isolation, protective
cleanup, alternate storage, manual hauling, repair, laundering, pest treatment,
recycling/export, and medical response.

### Feature stages

- **Proof:** dirt/fluid deposit, tracking, cleaning, bin/waste haul.
- **Vertical slice:** blood/chemical spills, wet floors, cleanliness/mood,
  disposal jams, basic laundry and contamination.
- **1.0:** pests, disease surfaces, advanced waste/recycling, forensic cleaning,
  broad bodily fluids.
- **Deferred:** city-scale sewer/ecology simulation.

### Acceptance tests

1. Spill a known reagent, track it through footsteps/tools/cleaning, and account
   for every transferred/removed amount.
2. Use correct and incorrect cleaning agents and verify deterministic hazard/
   reaction outcomes.
3. Fill/jam disposal and confirm no waste disappears; clear and process it.
4. Clean a crime scene and preserve/degrade evidence exactly by policy and
   method, without revealing the crime automatically.
5. Save/load a laundry batch, active spill, and pest nest; match subsequent
   products, contamination, and RNG.
6. Apply low-fluid/gore presentation settings; mechanical hazard, UI symbols,
   and alerts remain intact.
