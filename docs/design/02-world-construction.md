# World and construction

## World model

### Purpose and player experience

The world model supplies a stable physical substrate for every other system. A
player should be able to read the station as a plan—rooms, boundaries, access,
utilities, hazards, ownership, and traffic—while individual objects retain
SS13-like physical specificity.

The permanent station is one 192×192 plane. Remote maps are independent planes
connected by transport jobs and manifests, not adjacent coordinates or utility
links.

### Authoritative state and units

Each `MapState` contains:

- stable `map_id`, definition ID, dimensions, scenario role, and active/coarse
  simulation status;
- 16×16-tile chunks with topology, render, atmosphere, sanitation, and occupancy
  revision counters;
- monotonically increasing room and region IDs;
- transport endpoints to other maps; and
- scenario boundary rules.

Each tile stores dense layer references:

| Layer | Contents |
|---|---|
| base | space, asteroid, void, or supporting terrain |
| floor | floor assembly, plating, grating, or no floor |
| structure | wall, window, reinforced wall, or passable boundary |
| fixture | at most one anchored machine/door/furniture footprint owner |
| utility | cable, pipe, disposal, and data connectors as independent bitfields |
| surface | decals, fluid films, residue, dirt, and tracks |
| environment | atmosphere-cell reference, temperature, light, radiation |
| occupancy | sorted entity IDs and solid-footprint reservation |

The tile itself does not own items or creatures; it indexes entity IDs owned by
their systems. Multi-tile fixtures have one anchor entity and validated footprint
cells.

Topological regions are flood-filled sets for:

- passable navigation;
- sealed atmosphere;
- rooms;
- camera/sensor coverage;
- access-controlled areas; and
- utility graphs.

Each region type has its own revision. Updating a wall does not invalidate an
unrelated power graph unless the wall contains a connector.

### Cadence and ordering

- Occupancy and door passability update at `1t`, before movement.
- Tile changes commit transactionally during command/construction resolution.
- Dirty room, region, and local navigation connectivity rebuild immediately
  before a later same-tick consumer.
- Expensive aggregate room statistics refresh at `30t` or on inspection after
  pending topology is resolved.
- Occupied/viewed remote maps run every tick. Unoccupied remote maps run a
  scenario-declared coarse step every 60 ticks using aggregate processes; they
  return to full simulation before transport arrivals are committed.

### Player levers

The player can name maps/rooms, draw functional zones, assign department
ownership, set access policy, select construction style, enable overlays, and
schedule transport. They cannot paint a room as sealed, powered, clean, or safe;
those are measured consequences.

### Autonomous behavior

The world model itself does not make decisions. It validates spatial operations,
maintains connectivity, and exposes deterministic queries. Crew and machines use
those queries to navigate and act.

### Inputs, outputs, and dependencies

Inputs:

- construction and destruction commits;
- door/open-state changes;
- fixture and entity movement;
- surface deposits;
- utility connector changes;
- scenario map creation and transport events.

Outputs:

- `tile_changed`, `topology_changed`, `room_created`, `room_merged`,
  `room_split`, `zone_membership_changed`, and `map_activity_changed`;
- passability, line-of-sight, sealed-region, room, coverage, and footprint
  queries;
- dirty chunk/revision signals for environment, utilities, navigation,
  knowledge, and rendering.

The world model depends only on loaded definitions and entity footprint
projections. All physical systems depend on it.

### UI, alerts, and visibility

The default view distinguishes unknown, last-known, and current tiles. Overlays
show rooms, zones, access, structure integrity, traffic, sensor coverage,
department, and remote-map activity. Clicking a tile reports layer contents,
revision age, known environment, room membership, and blocking reason.

Topology changes that invalidate an occupied route, unseal a room, strand an
entity, or overlap a plan emit an alert or blueprint conflict.

### Data definitions

`map`, `terrain`, `floor`, `structure`, `zone_type`, `room_requirement`, and
`transport_endpoint` definitions specify:

- footprint and allowed map roles;
- passability and opacity;
- atmosphere seal and thermal properties;
- structural support and integrity;
- supported connectors;
- appearance IDs and damage appearances;
- construction/deconstruction recipe IDs; and
- tags used by rooms, tasks, incidents, and scenarios.

Scenario maps use versioned row-major tile data or a Tiled-JSON import compiled
into that representation. Runtime does not depend on Tiled.

### Mod hooks

- `validate:tile_transition`
- `observe:tile_changed`
- `observe:topology_changed`
- `transform:room_classification`
- data additions for all listed definition kinds

Hooks may reject a physical transition but may not directly rewrite a tile or
region cache.

### Save fields

Save map identity/dimensions, every non-default tile layer, integrity,
environment references, surfaces, zones, room names/ownership overrides,
transport endpoints/state, region-ID counters, revision counters, and remote-map
coarse-process state. Rebuild occupancy, flood fills, spatial indexes, and
rendering caches.

### Failure and recovery

- Invalid or overlapping footprints reject atomically.
- An entity stranded by destruction receives an emergency-displacement check to
  the nearest legal adjacent tile; if none exists it remains in place and is
  subject to the resulting environment.
- Corrupt map data blocks load and identifies map/tile/layer; it is never
  silently replaced.
- Remote-map aggregate processing clamps to physically available inputs and
  records an approximation event so returning to full simulation cannot create
  resources.
- A topology rebuild budget overrun degrades wall-clock speed, not correctness.

### Feature stages

- **Proof:** synthetic 192×192 map, chunks, walls/floors/doors, sealed rooms,
  topology revisions, remote-map fixture.
- **Vertical slice:** station plus one mining map, zones, access, camera coverage,
  transport endpoint, surfaces, and complete room queries.
- **1.0:** multiple remote-site types, derelicts, richer terrain and environmental
  fields.
- **Deferred:** stacked decks and cross-map utilities are explicitly unsupported.

### Acceptance tests

1. Build/remove every boundary orientation and compare passability, opacity,
   seal, and affected revision sets.
2. Split and merge a 10,000-tile room; room IDs and aggregate results remain
   deterministic regardless of insertion order.
3. A multi-tile fixture either claims its entire footprint or no tiles.
4. Saving and loading rebuilds identical room, region, and navigation hashes.
5. Coarse-simulate an empty mining map and verify conservation of stored
   resources and deterministic reactivation.
6. Remove a floor beneath an entity in exposed space and emit the expected
   topology/environment events without deleting the entity.

## Zones and rooms

### Purpose and player experience

Zones express director intent without overriding physical reality. Rooms are
computed physical spaces. A room can belong to several nonexclusive zones but
has one primary department and one access policy.

### Authoritative state and units

A `Zone` stores ID, zone-type content ID, ordered polygon/tile runs, priority,
department, access policy, allowed/forbidden item tags, service settings, and
enabled state. Zone types include department, stockpile, work area, medical
triage, quarantine, evacuation, restricted area, patrol, no-go, and leisure.

A `RoomRecord` stores current sealed/passable tile set, exits, floor area in
tiles, free volume in litres, department, name, fixture tags, environment
summary, cleanliness, privacy, occupancy/capacity, and requirement evaluation.

Zone overlap resolves by:

1. safety prohibition over permission;
2. explicit smaller zone over containing zone;
3. higher zone priority;
4. lower stable zone ID.

Department ownership is explicit; it does not follow majority overlap after
creation unless the player enables `auto_assign_department`.

### Cadence and ordering

Membership updates when zones or tile topology commit. Room aggregate state
updates at `30t` and immediately for safety-critical seal/exit changes.

### Player levers

Draw, resize, split, merge, rename, reprioritize, enable/disable, and assign
zone policies. Accept a suggested room classification or override its name and
department. Physical room requirements remain diagnostic, not overrideable.

### Autonomous behavior

Systems generate work and behavior from zone intent: haulers fill stockpiles,
janitors clean service areas, security patrols restricted zones, and crew seek
appropriate rooms. Invalid zones remain visible with unmet conditions rather
than disappearing.

### Inputs, outputs, and dependencies

Zones consume player commands and world topology. They output effective policy
queries, `zone_changed`, `room_requirements_changed`, and work-generation hints
to logistics, jobs, security, sanitation, medicine, service, and incidents.

### UI, alerts, and visibility

Zone drawing previews conflicts before commit. A room inspector lists every
requirement with measured/unknown status, such as “private,” “air safe,” “two
beds,” or “department access.” Unknown atmosphere is not displayed as safe.

### Data definitions

`zone_type` defines exclusivity group, priority semantics, default policy,
allowed map roles, color/pattern, room requirements, generated task tags, and
which systems may query it.

### Mod hooks

- `validate:zone_edit`
- `observe:zone_changed`
- `transform:zone_effective_policy`
- `transform:room_requirements`

### Save fields

Save zone geometry and all explicit settings, zone/room ID counters, room names,
department assignments, and auto-assignment flags. Recompute memberships and
requirement results.

### Failure and recovery

Invalid geometry is rejected with highlighted cells. A zone orphaned by
construction remains with zero effective tiles and a warning. Overlapping
exclusive policies resolve predictably and the losing rule appears in the
inspector.

### Feature stages

- **Vertical slice:** department, stockpile, work, medical, evacuation,
  restricted, and no-go zones; room validation.
- **1.0:** quarantine, patrol, leisure, privacy, service pricing, and scenario
  custom zone types.
- **Deferred:** mod-defined executable geometry logic; zones remain data-driven.

### Acceptance tests

1. Apply four overlapping zones in every creation order and receive the same
   effective policy.
2. Remove a room wall; room split/merge and all stockpile/access effects update
   before the next work choice.
3. A disabled zone generates no tasks but preserves its configuration through
   save/load.
4. A modded zone type appears in overlays, validation, saves, and work queries
   without core-code edits.

## Construction, demolition, and commissioning

### Purpose and player experience

Construction converts a director's plan into a physical, staffed process. A
blueprint reserves money and requests materials; it does not instantly create a
building. The player can understand whether work is blocked by access, support,
materials, tools, skills, environment, permits, or prerequisite stages.

### Authoritative state and units

A `Blueprint` stores:

- stable ID, definition ID, footprint, orientation, variant, and plan group;
- department, priority, desired completion tick, and safety policy;
- stage list and current stage;
- required item/material quantities, reserved quantities, and source rules;
- labor progress in work-seconds;
- estimated/committed/paid cost in `cr¢`;
- prerequisite blueprint IDs;
- validation status and blocking-reason codes; and
- creator command, created tick, and policy version.

Stages are `survey`, `prepare`, `frame`, `utility`, `seal`, `finish`, `install`,
`inspect`, and `commission`; a definition selects a subsequence. A stage may
change tile state only at its atomic completion. Materials become incorporated
then; cancelling beforehand releases them, while cancelling later generates
salvage/demolition.

Structural rules:

- ordinary floors require adjacent support or a scenario-defined support anchor;
- walls require a floor/plating unless designed for space;
- removal cannot be prohibited, but unsafe removal requires an enabled hazardous
  work policy and creates explicit decompression/collapse risk;
- a machine is operational only after its footprint, utility connectors,
  calibration, and inspection requirements pass.

### Cadence and ordering

- Placement validation occurs at command commit.
- Construction task generation and reservation reevaluate at `10t` or relevant
  change.
- Workers apply integer work-seconds at `1t`.
- Completed stage mutations commit after movement/interactions and before
  utilities/environment update.
- Cost forecasts update at `60t`; committed ledger entries happen immediately.

### Player levers

Place/move/cancel unstarted blueprints; select material/appearance variants;
group, phase, suspend, prioritize, set budget ceiling, choose allowed stockpiles,
approve hazardous work, and commission manually when policy requires.

The player cannot choose a worker or force a stage to skip tools, skill, or
inspection.

### Autonomous behavior

The construction system emits scoped work orders. Eligible crew select them via
work AI, reserve tools/materials, haul supplies, perform stages, and request
inspection. Workers stop or refuse under unsafe pressure, fire, access, or policy
conditions unless their role and emergency rules allow it.

### Inputs, outputs, and dependencies

Inputs include world topology, material inventory, logistics reservations,
department budget authorization, crew labor/skills, tools, utility availability,
environment safety, and access.

Outputs include material consumption/salvage, ledger commitments, construction
tasks, tile/fixture transitions, topology dirtiness, noise/dust/contamination,
experience, and:

- `blueprint_created`
- `blueprint_blocked`
- `construction_stage_started/completed`
- `inspection_failed/passed`
- `fixture_commissioned`
- `blueprint_cancelled`

### UI, alerts, and visibility

Planning mode provides a ghost, footprint, seal/access/utility effects, known
hazards, required quantities, work estimate, budget source, and conflicts.
Blueprints use states: valid, missing prerequisite, waiting supplies, waiting
worker, unsafe, suspended, and complete.

Alert when an urgent blueprint is blocked for 60 ticks, a plan would open a
pressurized room, costs exceed ceiling, reserved materials vanish, or an
inspection fails. Exact hidden hazards remain unknown; the UI says
“unverified environment” when appropriate.

### Data definitions

`buildable` definitions contain footprint, allowed orientations, stage recipes,
labor/skill/tool requirements, consumed and salvaged materials, tile/fixture
transitions, utility connectors, safety predicates, inspection predicates,
noise/contamination, appearance variants, and deconstruction plan.

Definitions must be finite and acyclic. The loader rejects stage dependencies
that reference a later stage or recipes with no obtainable inputs in the
validated content graph unless marked scenario-only.

### Mod hooks

- `validate:blueprint_place`
- `validate:construction_stage`
- `transform:construction_labor`
- `transform:construction_materials`
- `observe:blueprint_blocked`
- `observe:construction_stage_completed`
- `observe:fixture_commissioned`

Transform results may reduce/increase work or material requirements but cannot
make a completed stage consume a negative amount.

### Save fields

Save every blueprint field, stage progress, reservations by stable reservation
ID, incorporated materials, cost records, prerequisite graph, inspection
results, and pending atomic transitions. Revalidate cached reasons after load;
never reroll or refund automatically.

### Failure and recovery

- Lost reservations return a blueprint to waiting without duplicating resources.
- Destroyed partial work produces definition-based salvage and debris.
- Unreachable or unsafe plans remain suspended with reasons.
- A worker interrupted mid-tick commits no partial material transition; accrued
  integer labor remains.
- Budget cancellation releases unspent authorization, not already purchased or
  incorporated goods.
- Decommissioning isolates utilities before dismantling when policy and access
  permit; emergency demolition can bypass this with recorded risk.

### Feature stages

- **Proof:** floors, walls, doors, cables, pipes, one machine, placement/stages,
  material reservations, dirty topology.
- **Vertical slice:** complete station shell/interior expansion, utilities,
  furniture, machines, demolition, inspection, salvage, safety warnings.
- **1.0:** material/quality variants, structural damage repair, sophisticated
  staging and contractors.
- **Deferred:** direct freeform pixel construction and multi-deck supports.

### Acceptance tests

1. Construct a sealed powered room from blueprint through commission using only
   autonomous work; verify material, labor, money, and topology conservation.
2. Cancel at every stage and compare released, incorporated, and salvaged
   quantities to definition rules.
3. Reserve the final steel stack for two plans; only one receives it and neither
   duplicates it after save/load.
4. Remove an exterior wall under hazardous-work policy and verify that the
   atmosphere update sees the breach in the same tick after the stage commits.
5. Disable hazardous work and verify an unsafe demolition remains visible,
   blocked, and explainable rather than disappearing.
6. Commission a machine with a disconnected power port; inspection fails with a
   stable reason and succeeds after an autonomous cable build.
