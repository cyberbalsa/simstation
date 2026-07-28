# Crew, jobs, work AI, and navigation

## Crew

### Purpose and player experience

Crew are persistent people, not interchangeable labor points. Their bodies,
needs, skills, relationships, schedules, knowledge, wages, possessions, and
judgment connect every station system. The director manages an institution that
must make work attractive, possible, and safe enough for autonomous people.

### Authoritative state and units

Each `CrewMember` owns:

- identity: stable entity ID, generated/name/pronoun/localization keys, portrait
  seed, age in days, arrival record, and employment status;
- job: job ID, department, rank, shift schedule, wage, supervisor, access
  credential references, certifications, and performance record;
- capabilities: skills from 0–10, experience milli-points, traits, languages,
  movement profile, manipulation slots, and current incapacity flags;
- needs: hunger, thirst, fatigue, recreation, social, comfort, hygiene, bladder,
  and safety from 0–100,000 milli-points;
- psychology: mood from −100,000 to 100,000, active thoughts, stress, loyalty,
  risk tolerance, values, and grievance records;
- relationships: sparse per-person familiarity and affinity in milli-points,
  bounded memories, and household/social-group IDs;
- physical references: anatomy/health record, worn/held/container inventory,
  contamination, temperature exposure, and current posture;
- intent: current schedule block, goal, task/reservation IDs, path, interaction,
  interruption stack, and refusal cooldowns;
- knowledge: personal observation/report references, not a copy of objective
  world state; and
- finances: personal account ID, wage agreement, debt, owned-item IDs, and
  current spending plan.

Needs use definition-owned rates modified by activity, environment, traits,
injury, food, and schedule. Crossing thresholds adds/removes thoughts and changes
goal weighting. A zero need never immediately forces an action that is physically
impossible; it creates escalating health/mood consequences.

Traits are data-defined parameter bundles. A trait may alter known transform
points but cannot attach arbitrary code in a data-only mod.

### Cadence and ordering

- Immediate movement, interactions, exposure, and incapacity update at `1t`.
- Urgent needs and panic/safety response evaluate at `5t`.
- Normal goal/task reconsideration runs at `10t`, staggered by stable crew ID.
- Needs and routine thoughts update at `60t`.
- Relationship observations and social memories update at `30t` when an event
  provides a valid perception.
- Skill experience consolidates at task milestones; long-term performance and
  employment update at shift boundary.

A crew member also replans immediately when their task becomes invalid, route is
lost, they become unsafe/incapacitated, an emergency policy affects them, or a
higher-priority personal crisis crosses threshold.

### Player levers

Recruit/dismiss, assign job/rank/department/schedule, change wages, approve
training, set department and station policies, provide facilities/equipment,
set emergency posture, and designate preferred uniform/loadout.

The player cannot alter personality, relationships, thoughts, current goal, or
task directly. Medical/disciplinary processes may change some state through
in-world work.

### Autonomous behavior

At a decision point, a crew member selects among:

1. immediate survival or panic;
2. emergency duty permitted by role/policy;
3. essential bodily needs;
4. claimed work;
5. ordinary work within schedule;
6. personal errands and consumption;
7. recreation/social/rest; and
8. idle observation/wandering in allowed areas.

They use personal knowledge for danger and reported task facts. They may refuse
or abandon work for:

- missing access, certification, functional limbs, tool, protective equipment,
  or reachable route;
- measured/perceived hazard above their role/policy/risk limit;
- task illegality under current access/security/medical policy;
- exhausted essential need or medical incapacity;
- labor action, unpaid wages, extreme grievance, or explicit trait/value
  conflict; or
- a reservation/precondition invalidated by another event.

Every refusal carries stable reason codes, observed facts, policy version, and
reevaluation condition.

### Inputs, outputs, and dependencies

Inputs: work offers, schedules, jobs, policies, path/hazard queries, environment,
health, inventory, equipment, facilities, reports, relationships, economy,
security, and incidents.

Outputs: movement/interaction intents, labor, consumption, observations/reports,
social events, injuries, mood/performance, purchases, resignations, and:

- `crew_goal_changed`
- `crew_task_claimed/abandoned`
- `crew_refused`
- `need_threshold`
- `thought_added/removed`
- `relationship_changed`
- `crew_incapacitated/died`
- `crew_reported`

### UI, alerts, and visibility

Personnel cards show authorized records and currently observable state:
employment, schedule, wage, skills/certifications, health summary, needs/mood
bands, current activity, known task, carried equipment, and recent explainable
thoughts. Private or hidden traits appear only if scenario/personnel policy says
they are recorded.

The “why” panel lists the chosen goal's score components and the top three legal
alternatives with rejection/reason codes. It never exposes facts the director
does not know; “avoiding unknown danger” appears only after the crew member
reports or is observed acting on it.

Alerts cover death, critical injury, missing essential role, repeated refusal,
unpaid wages, imminent resignation, trapped crew, and needs failures affecting a
department.

### Data definitions

`crew_archetype`, `trait`, `need`, `thought`, `skill`, `certification`,
`relationship_memory`, `schedule_block`, `uniform_profile`, and
`personal_goal` define ranges, rates, thresholds, score transforms, localization,
visibility, and allowable hooks.

Crew generation consumes a scenario-specified demographic/name pool and a
dedicated RNG stream. Definitions must bound values and declare whether they are
personnel-record, observable, reportable, or secret.

### Mod hooks

- `transform:need_rate`
- `transform:goal_score`
- `validate:crew_can_attempt_task`
- `observe:crew_goal_changed`
- `observe:crew_refused`
- `observe:crew_memory_added`
- `observe:crew_employment_changed`

Hooks may adjust scores and eligibility through documented reasons; they may not
force an action or disclose secret state through player-visible payloads.

### Save fields

Save all identity, job, capability, need, mood, thought, relationship, health
reference, inventory reference, intent, knowledge, finance, employment,
experience, memory, schedule, cooldown, and local RNG state. Paths are caches and
are rebuilt; the goal/task/reservation remains and is revalidated.

### Failure and recovery

Crew can become injured, traumatized, exhausted, trapped, unpaid, dissatisfied,
mutinous, missing, dead, or cloned with consequences. Systems provide treatment,
rest, rescue, counseling/recreation, back pay, schedule relief, protective
equipment, training, reassignment, recruitment, cloning, and memorial/replacement
routes.

Impossible intent clears to a safe idle/recovery goal with a reason. A content
error that yields no valid goal never deletes the person; it raises a diagnostic
and uses “wait and report blocked.”

### Feature stages

- **Proof:** 100 deterministic agents with movement, hunger/fatigue/safety,
  skills, one schedule, knowledge, and task choice.
- **Vertical slice:** about 24 persistent crew; core needs, mood/thoughts,
  relationships, personal money, equipment, reports, refusals, injuries and
  death.
- **1.0:** full needs, richer relationships/memories, loyalty, labor disputes,
  households, varied traits and long-term development.
- **Deferred:** hidden antagonist motives; they use reserved secret-goal fields
  post-1.0.

### Acceptance tests

1. One hundred crew receive identical generated identities, choices, and state
   hashes for a seed across repeated runs.
2. A hungry off-duty engineer chooses reachable food; closing access or removing
   food updates the reasoned alternatives without oscillation.
3. An unpaid crew member progresses through grievance, report, refusal, and
   potential resignation according to definitions; back pay enables recovery.
4. A fire responder with gear accepts a hazardous task while an untrained,
   unprotected worker refuses with exact facts and policy.
5. Hide a hazard from station sensors but expose it to a crew member; the
   director learns only after a valid report/camera observation.
6. Save/load during an interrupted task and preserve needs, intent, reservations,
   and subsequent deterministic choice.

## Jobs, departments, schedules, and staffing

### Purpose and player experience

Jobs turn people into an accountable organization. Departments own budgets,
facilities, policies, and work domains; ranks grant authority but do not make a
crew member more physically capable.

### Authoritative state and units

The canonical departments are Command, Engineering, Cargo, Service, Medical,
Science, and Security. Broad vertical-slice jobs are assistant/hauler, station
engineer, miner, quartermaster, botanist, chef, janitor, doctor, scientist, and
security officer, with department heads assigned from the same staffing model.

A `JobDefinition` specifies:

- department, rank, supervisor role, work tags, certifications, base skill
  expectations, access profile, emergency duties, schedule templates, uniform
  profile, workstation/facility needs, and allowed policy exceptions;
- wage range in `cr¢` per shift and overtime multiplier in ppm; and
- performance measures that the job can reasonably influence.

An `EmploymentRecord` specifies crew/job/department, start/end tick, wage,
schedule ID, probation, certifications, access credential, supervisor, contract
terms, overtime authorization, and disciplinary status.

A schedule is a repeating list of nonoverlapping blocks with shift-relative
start/end ticks: work, on-call, break, meal, recreation, sleep, training, or
leave. Overlaps reject at command validation.

Staffing demand is an explainable forecast computed from work volume, coverage,
facility count, policy, incident posture, and historical throughput. It is advice,
not a hidden efficiency penalty.

### Cadence and ordering

- Schedule transitions apply at their exact tick before goal choice.
- Staffing/workload forecasts update at `300t` and relevant structural changes.
- Access follows employment/promotion changes at command boundary.
- Performance accrues from event attribution and settles at shift boundary.
- Recruitment candidates refresh at shift boundary or scenario event.

### Player levers

Create/modify schedules, set headcount targets, hire/dismiss, assign/promote,
change wage/overtime/on-call policy, authorize training, choose department head,
adjust access profiles within scenario law, and approve temporary contractors.

Dismissal and access revocation are commands with policy-defined notice and
security workflow. They are not instantaneous mind control; an on-station former
employee must leave or be escorted.

### Autonomous behavior

Crew follow schedules unless a personal crisis, emergency duty, approved
overtime, medical leave, refusal, or supervisor policy overrides it. Department
heads generate requests/reports, rebalance department priorities within delegated
limits, and escalate unresolved shortages. Supervisors do not directly command
pawns; they modify scoped task priorities and approve requests.

### Inputs, outputs, and dependencies

Inputs: crew records, task history/backlog, facilities, payroll budget, policies,
training, incidents, security/access, and reports.

Outputs: task eligibility, access, schedules, labor cost, staffing forecasts,
recruitment demand, morale effects, performance records, and
`employment_started/ended`, `job_changed`, `schedule_transition`,
`department_understaffed`, `overtime_started`, `access_profile_changed`.

### UI, alerts, and visibility

The staffing screen combines shift coverage, required certifications, expected
work demand, assigned names, wage cost, overtime, fatigue risk, and unmet
facilities. Timeline editing previews coverage and cost. Every forecast exposes
its inputs and confidence.

Alert for zero qualified coverage in life support/medical/security, unaffordable
payroll, chronic overtime, unauthorized access mismatch, and expiring
certification.

### Data definitions

`department`, `job`, `rank`, `schedule_template`, `access_profile`,
`employment_contract`, `training_course`, and `performance_metric`.

Definitions cannot grant direct control or unbounded access implicitly. Each
emergency exception and performance input is explicit.

### Mod hooks

- `validate:employment_change`
- `transform:staffing_forecast`
- `transform:wage_due`
- `observe:job_changed`
- `observe:schedule_transition`
- data additions for departments/jobs/schedules/training

### Save fields

Save department settings/head IDs, employment history, active contracts,
schedules, staffing targets, candidate pool and refresh tick, performance
accumulators, overtime, training progress, access credential links, and forecast
inputs/history.

### Failure and recovery

Vacancies create visible coverage and backlog risk rather than arbitrary machine
penalties. Recovery includes hiring, retraining, cross-department assistance,
overtime, automation, reduced scope, contractors, and emergency external service.
Invalid schedule edits reject atomically. A missing modded job blocks the save
unless migrated; crew are never silently converted.

### Feature stages

- **Proof:** three departments/jobs, schedule blocks, eligibility, access, wage.
- **Vertical slice:** all canonical departments and broad jobs, heads, hiring,
  schedules, overtime, staffing forecast, training basics.
- **1.0:** complete profession tree, contracts, performance reviews, labor
  relations and advanced certification.
- **Deferred:** adversarial role assignment and elected station government.

### Acceptance tests

1. Cover a full shift with two schedules and verify exact transitions, payroll,
   rest opportunities, and task eligibility.
2. Remove the only qualified engineer; the dashboard identifies affected work
   and recovery options without changing machine physics.
3. Promote a crew member and verify supervisor, wage, access, uniform request,
   and audit events update atomically.
4. Attempt an overlapping schedule and an unaffordable hire; each rejects with no
   partial changes.
5. A modded department/job participates in staffing, access, tasks, payroll,
   saves, and UI without switch statements in core systems.

## Work orders, reservations, and autonomous task selection

### Purpose and player experience

Work orders translate system needs and director policy into autonomous action.
The system must avoid duplicate labor, deadlocks, thrashing, invisible priority
bonuses, and unexplained idleness.

### Authoritative state and units

A `WorkOrder` contains:

- stable ID, content-defined work type, owning system, department/work tags;
- lifecycle: `offered`, `claimed`, `reserved`, `executing`, `completed`,
  `failed`, or `cancelled`;
- source/target IDs and positions, creation/deadline ticks, base priority 0–5,
  policy version, emergency flag, and parent/dependency IDs;
- required skills/certifications, tools/equipment, materials, access, crew count,
  environment predicates, and work-seconds;
- reservation IDs, claimant IDs, progress/remainder, interruptibility, and
  failure/retry reason;
- public description/visibility and knowledge facts used to offer it.

Reservations have stable ID, owner task/crew, resource/quantity, acquired/expiry
tick, state, and release reason. A resource can expose exclusive, counted, or
capacity reservations. Acquisition sorts the complete request set by resource
type and stable resource ID; failure releases the entire attempted set.

Task score, in integer milli-points, is:

```text
priority_level * 1,000,000
+ deadline_urgency (0..500,000)
+ emergency_role_fit (0..300,000)
+ skill_fit (0..200,000)
+ department_fit (0..100,000)
+ continuity_bonus (0..100,000)
+ policy_modifiers (-500,000..500,000)
- path_cost_millitiles * 100
- hazard_cost (0..2,000,000)
- need_cost (0..1,000,000)
- overtime_cost (0..300,000)
- grievance_cost (0..500,000)
```

Eligibility is checked before scoring. Highest score wins; ties use older
creation tick, lower task ID, lower crew ID. Definitions can tune bounded
components but cannot replace tie-breaking.

### Cadence and ordering

- Work owners emit/cancel/update offers before planning.
- Ordinary selection is `10t`, staggered by crew ID.
- Emergency, invalidation, completion, refusal, or interruption causes immediate
  reconsideration at the next `1t` intent phase.
- Reservation leases default to 120 ticks while claimed and renew during
  progress. Inactivity releases them at expiry.
- Work progress applies at `1t` only while every continuous predicate passes.

### Player levers

Set priority by work type, department, zone, object, blueprint, production order,
or incident; suspend sources; create policy constraints; approve hazardous work,
overtime, cross-department help, and budget/material source. The player cannot
assign a named worker.

### Autonomous behavior

Eligible crew query a bounded spatial/task index, evaluate top candidates, claim
one, acquire reservations, gather equipment/materials, navigate, perform stages,
and finalize or report failure. Multi-crew work reserves roles and starts only
when its definition's quorum/time-window rule passes.

Crew retain a valid current task unless a new candidate exceeds it by a 150,000
milli-point hysteresis or a survival/emergency rule interrupts it.

### Inputs, outputs, and dependencies

All labor-using systems own and publish work orders. Work AI consumes crew,
jobs/schedules, path/hazards, access, inventory, logistics, policies, knowledge,
and reservations. It outputs claims, movement/interactions, labor, resource
locks, progress, reasoned failures, backlog metrics, and lifecycle events.

### UI, alerts, and visibility

The work dashboard groups offers by source, department, reason, age, priority,
eligibility count, reserved resources, and known blocker. A crew “why” view
shows exact score components for facts visible to management.

Alert for emergency tasks with no eligible worker, reservation deadlock
diagnostics, critical backlog age, repeated retries, missing definition
requirements, and excessive task churn.

### Data definitions

`work_type`, `work_stage`, `reservation_kind`, `priority_policy`, and
`interruption_policy` define requirements, score bounds, stage interactions,
work sounds/appearances, progress, products, retry rules, and localized reasons.

### Mod hooks

- `validate:work_eligibility`
- `transform:work_score_component`
- `validate:reservation_request`
- `observe:work_lifecycle`
- `observe:reservation_released`

There is no “force crew to take task” hook. Trusted mods can create work through
the same schema and ownership rules.

### Save fields

Save all orders, lifecycle/progress, dependencies, claims, reservations/leases,
retry state, task/ reservation counters, policy versions, and work-owner links.
Rebuild candidate indexes and paths; revalidate claims without advancing time.

### Failure and recovery

Atomic reservation prevents partial hold deadlocks. Invalid targets cancel and
release. Temporarily missing paths/tools/materials keep an offer with a blocker
and exponential retry capped at 300 ticks. A failed work interaction records
consumed resources and products transactionally. Orphan tasks on content
migration block migration or use an explicit owner-supplied migrator.

### Feature stages

- **Proof:** work lifecycle, exclusive/count reservations, scoring, one-stage
  interactions, blockers.
- **Vertical slice:** multi-stage construction/haul/operate/repair/clean/treat/
  suppress tasks, emergency interruption, multi-crew rescue.
- **1.0:** supervisor delegation, training, complex surgery/research/security
  workflows, labor action.
- **Deferred:** direct assignments and black-box utility AI are prohibited.

### Acceptance tests

1. Offer identical tasks in randomized container order; claim order and result
   remain identical.
2. Two tasks request the same tool/material set in opposite logical order; no
   deadlock or partial reservation occurs.
3. Increase zone priority and observe selection after hysteresis without
   per-tick thrashing.
4. Interrupt a job for fire response, preserve safe stage progress, then resume
   or release every reservation per definition.
5. Make all workers ineligible and verify one stable reason per worker plus a
   no-eligible-worker alert.
6. Save/load every lifecycle state and match the uninterrupted execution.

## Navigation, access, and hazard routing

### Purpose and player experience

Navigation makes layout, doors, congestion, access, and hazards consequential
without spending most CPU time on global tile A*. A blocked route must have a
specific, inspectable cause.

### Authoritative state and units

Navigation has two levels:

- a room/region portal graph, with nodes for connected passable regions and
  edges for doors, airlocks, transport points, and narrow transitions;
- deterministic local A* within affected regions/chunks.

Local cardinal movement costs 1,000 milli-tiles; diagonal movement costs 1,414
only when both adjacent cardinal cells permit corner passage. Added costs include
door interaction, congestion reservation, access action, suit encumbrance, and
personally known hazards.

A path record caches map/topology/hazard revisions, portal route, local segments,
goal tolerance, and path owner. Paths are nonauthoritative; the next movement
intent and position are authoritative.

Crew reserve the destination tile for the next step only. Doors provide bounded
queues ordered by emergency priority, arrival tick, then entity ID. Entities may
swap adjacent positions only when neither tile is a door/hazard transition and
both movement profiles permit it.

### Cadence and ordering

- Topology/access revisions invalidate affected paths immediately.
- Movement intent resolves at `1t` after reservations, in stable entity ID order
  with door queues applied first.
- Normal path requests are budgeted but must complete before the requesting crew
  commits movement; a budget overrun delays intent rather than using a bad path.
- Hazard costs refresh at `5t` or on a critical local event.
- Traffic heatmaps aggregate at `30t` and do not affect authoritative decisions
  except through an explicitly configured congestion policy.

### Player levers

Change physical layout, zones, access policy, door behavior, one-way/avoidance
routes, evacuation destinations, no-go areas, hazard tolerances by role, and
transport schedules. The player may not draw a path for an individual.

### Autonomous behavior

Crew choose the least-cost known legal route that meets their movement and
equipment profile. They may request access, wait for a door, fetch protection,
choose a longer safe route, report blockage, abandon the task, or in an emergency
use a policy-authorized override.

### Inputs, outputs, and dependencies

Inputs: world topology, doors, access credentials/policies, zone rules, known
atmos/fire/contamination/security hazards, occupancy, movement profiles, and
transport availability.

Outputs: routes, path costs, reachability/blocker reasons, movement intents,
door/access requests, congestion, and `path_failed`, `route_hazard_changed`,
`door_queue_blocked`, `entity_moved`, `crew_trapped`.

### UI, alerts, and visibility

Selecting a task or crew can show the planned route and costs using only known
state. The navigation overlay shows regions, portals, congestion, accessibility,
and known hazards. A failure lists the first blocking portal/tile and whether it
is physical, access, scheduled transport, hazard, or congestion.

### Data definitions

`movement_profile`, `door_profile`, `portal_type`, `hazard_routing_policy`,
`access_action`, and `transport_route` define traversability, cost, interaction,
equipment requirements, fail-safe state, and authorization.

### Mod hooks

- `validate:tile_traversal`
- `transform:path_edge_cost`
- `observe:path_failed`
- `observe:entity_moved`
- `observe:access_override_used`

Hooks must return bounded integer costs and stable reason codes.

### Save fields

Save positions, movement progress/intent, door queues, transport state, access
requests, and trapped-state timestamps. Rebuild graphs, paths, spatial indexes,
and traffic history unless a scenario explicitly persists the latter.

### Failure and recovery

No path keeps the goal/task blocked with its reason. Moving hazards invalidate
routes. Locked or unpowered doors use physical fail-safe and permitted manual
interactions. Stuck detection after 30 ticks without progress triggers replan;
three equivalent failures create a report and longer retry, not teleportation.
Rescue/breach/repair/evacuation can restore reachability.

### Feature stages

- **Proof:** hierarchical routing, doors, deterministic local A*, 100 agents,
  dirty invalidation.
- **Vertical slice:** access, hazards, protective profiles, door queues,
  transport to mining, evacuation.
- **1.0:** stretchers, dragging, vehicles/carts, crowd behavior, patrol routes,
  more disability profiles.
- **Deferred:** multi-deck route graph.

### Acceptance tests

1. Compare path result and cost across randomized neighbor/container orders.
2. Change one wall and prove only affected cached regions invalidate.
3. Route protected and unprotected crew past vacuum/fire; choices match personal
   knowledge, gear, role, and policy.
4. Send 100 crew through two doors and verify bounded queues, no overlap, no
   starvation, and stable order.
5. Cut a transport route while a remote task is claimed; task releases/reports
   and no crew teleports.
6. Save/load mid-door queue and preserve subsequent positions and arrival order.
