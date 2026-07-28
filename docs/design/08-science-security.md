# Science, automation, and security

## Research, experiments, artifacts, and genetics

### Purpose and player experience

Science exchanges staff time, facilities, samples, energy, money, and risk for
knowledge, grants, prototypes, and strategic capabilities. It must reward
building a reliable experimental institution rather than clicking through a
technology tree.

### Authoritative state and units

Research has four separate resources:

- `observations`: immutable evidence records produced by instruments,
  experiments, incidents, specimens, and field work;
- `data`: quality-scored, domain-tagged analysis units tied to observations;
- `insight`: campaign knowledge used to meet proposal milestones;
- `authorization`: legal/safety/reputation gate, not a spendable point.

A `ResearchProposal` specifies domain, prerequisites, required observation/data
tags and quality, experiment stages, facilities/staff/materials, risk class,
ethics/security rules, milestones, grant/expense schedule, unlock outputs, and
failure/novelty behavior.

An `ExperimentRun` stores proposal/stage, hypothesis variant, samples, apparatus,
staff, environment, settings, start/commit/completion ticks, risk budget,
observations, data quality, incidents, contamination, and repeat count.
Repeating an identical known setup has diminishing novelty defined by proposal.

Research unlocks content capabilities through stable unlock IDs. Unlocking never
creates a machine/item; it permits relevant production, construction, policy, or
diagnostic definitions.

Artifacts begin with hidden objective properties derived from site/incident seed.
Allowed analysis methods generate observations; activation can create effects
through declared capability components. The player sees hypotheses and evidence,
not hidden property tables.

Genetics stores a bounded set of fictional gene markers/alleles on species/
persons/plants. Tests create observations. Manipulation is a staged medical/
research procedure with consent, samples, machine, reagents, risk, and declared
effects. It does not model real genomes or expose real procedures.

### Cadence and ordering

- Experiment work and direct apparatus interactions progress at `1t`.
- Automated apparatus/process stages run at `10t`.
- Sensor observations emit at instrument cadence.
- Data analysis/planning runs at `60t`.
- Proposal/grant/repeat-novelty evaluation occurs at milestone and shift
  boundary.
- Artifact/genetic stochastic checkpoints use dedicated named streams and only
  at definition-declared stages.

### Player levers

Choose proposals and risk tolerance; allocate budget, facilities, staff, samples,
apparatus, and machine time; set safety/ethics/containment, publication, patent/
open-research, artifact storage, and genetics policies; suspend projects and
authorize high-risk stages.

The player cannot choose a hidden artifact property or guarantee an experiment
result. Experiment settings are plan parameters executed by scientists.

### Autonomous behavior

Scientists propose/plan feasible runs, reserve equipment/samples, perform
calibration, operate experiments, analyze results, repeat when novelty/quality
justifies it, report hazards, and request authorization. They refuse experiments
outside certification, safety, consent, or legal policy.

### Inputs, outputs, and dependencies

Inputs: staff/skills, labs/apparatus, samples/artifacts, mining/medicine/chemistry,
power/utilities, environment/sanitation, budgets/grants, security/access,
incidents, and policy.

Outputs: observations/data/insight, unlocks, grants/reputation, prototypes,
specimen consumption, hazards/contamination, reports, incidents, and:

- `proposal_started/milestone/completed/failed`
- `experiment_started/completed/interrupted`
- `observation_recorded`
- `research_unlock`
- `artifact_property_inferred/activated`
- `genetic_test/manipulation`
- `research_safety_breach`

### UI, alerts, and visibility

The research screen shows proposals as requirements, experimental plan, cost,
capacity, evidence quality, risk range, policy gate, and possible output classes.
It marks inferred versus confirmed knowledge. Artifacts show an evidence ledger
and competing hypotheses, never exact hidden state without sufficient analysis.

Alerts cover unsafe setup, containment/power loss, missing sample/equipment,
expired grant milestone, repeated low-novelty run, controlled artifact/genetic
access, contamination, and experiment casualty.

### Data definitions

`research_domain`, `proposal`, `milestone`, `experiment`, `apparatus`,
`observation_type`, `data_analysis`, `unlock`, `grant`, `artifact_archetype`,
`artifact_capability`, `gene_marker`, `genetic_test`, `genetic_procedure`, and
`research_policy`.

Definitions declare knowledge visibility, risk outcomes, repeat behavior,
material/energy balance, and unlock targets. Data-only artifacts compose audited
capability components; they do not embed scripts.

### Mod hooks

- `validate:experiment_plan`
- `transform:research_data_quality`
- `transform:proposal_progress`
- `transform:artifact_capability`
- `observe:research_event`
- `observe:observation_recorded`
- `observe:research_unlock`

Transforms cannot reveal hidden properties in a player-visible value without a
valid observation and cannot unlock unresolved content.

### Save fields

Save proposals/milestones, experiments/stages/settings/reservations,
observations/data/insight, unlock IDs, grants, research RNG streams, artifact
hidden state and evidence separately, genetics and consent records, repeat/
novelty history, counters, and policies.

### Failure and recovery

Experiments can waste samples, produce low-quality data, contaminate areas,
damage apparatus, injure staff, activate hazards, violate policy, or lose grants.
Recovery includes containment, treatment, cleanup, repair, new samples,
recalibration, redesigned runs, imports, insurance, and lower-risk proposals.
Research failure never consumes unrelated campaign knowledge.

### Feature stages

- **Proof:** proposal → experiment → observations/data → unlock, with one failure.
- **Vertical slice:** basic engineering/medical/material proposals, grants,
  apparatus capacity, safety and production unlocks.
- **1.0:** artifacts, genetics, broad domains, richer experiments and prototypes.
- **Deferred:** telescience and hidden-antagonist research.

### Acceptance tests

1. Complete a proposal from physical sample through experiment, analysis,
   milestone, grant transaction, and produced unlock.
2. Repeat an identical experiment and verify diminishing novelty without changing
   underlying observation truth.
3. Lose containment power mid-stage and trace hazard, injury, cleanup, evidence,
   cost, and proposal recovery.
4. Analyze an artifact with two methods; only supported properties become
   inferred/confirmed and save/load preserves hidden separation.
5. Add a mod proposal/unlock/apparatus chain and validate content dependency,
   UI, production eligibility, save, and migration.

## Automation, robotics, bots, and station AI

### Purpose and player experience

Automation substitutes capital, maintenance, infrastructure, and predictable
rules for some labor. It improves scale but creates failure domains and does not
make crew or logistics irrelevant.

### Authoritative state and units

Basic automation uses declarative components:

- sensors emit typed data messages with value, timestamp, confidence, and source;
- controllers evaluate ordered condition/action rules at a bounded cadence;
- actuators accept authenticated typed commands and apply local safety/access
  validation;
- timers, counters, thresholds, selectors, and latches maintain bounded integer
  state; and
- networks provide power, data bandwidth, authentication, and latency.

A controller rule is:

```text
when <typed sensor/event predicate>
if <bounded comparisons and boolean expression>
then <one or more whitelisted command templates>
cooldown <ticks>
priority <integer>
```

No loops, recursion, dynamic code, filesystem/network access, or arbitrary table
mutation are available in data rules. Evaluation budget is 256 rule operations
per controller per due tick. Excess work defers and emits diagnostics.

Bots/robots are entities with chassis, power cell, modules/tools, cargo, access
credential, sensors/knowledge, maintenance, task capabilities, movement profile,
controller mode, and owner. They claim compatible normal work orders with a
separate eligibility profile.

The station AI in 1.0 is an operations service: it aggregates alarms, suggests
policies, coordinates approved automation, and controls authorized devices. It
does not possess omniscience; it sees its sensors/data. Competing laws, sentience
politics, and adversarial law interpretation are post-1.0.

### Cadence and ordering

- Sensors publish at their defined cadence, no faster than `1t`.
- Data messages deliver in utility order.
- Controllers evaluate after due messages at `1t` or slower definition cadence.
- Actuator commands enter the command/control validation stage for the next
  applicable tick; controllers cannot mutate same-stage input.
- Bots move/interact/work through normal `1t` systems; planning is `10t`.
- Charging/maintenance/battery state updates at `10t`.

### Player levers

Build sensors/controllers/actuators/bots/chargers; connect networks; configure
bounded rules, thresholds, cooldowns, priorities, access domains, task tags,
charging/maintenance, fail-safe, and manual/automatic mode; approve station-AI
suggestions and controller templates.

The player does not directly drive a bot. Emergency local controls still require
valid in-world device capability.

### Autonomous behavior

Controllers react deterministically to their input history and rules. Bots claim
eligible hauling, cleaning, maintenance, farming, delivery, patrol, or response
tasks; monitor battery/storage/damage; charge/unload; and report failure. The
station AI generates suggestions/reports but changes policy only after prior
delegation or player approval.

### Inputs, outputs, and dependencies

Inputs: power/data, sensors/knowledge, work orders, paths/access, machine state,
policies, items/tools, damage/maintenance, and security authorization.

Outputs: typed control commands, automated machine changes, bot labor/movement,
reports, bandwidth/power demand, faults, and:

- `sensor_message`
- `controller_rule_fired/deferred`
- `actuator_command_accepted/denied`
- `bot_task_state`
- `bot_battery_threshold`
- `automation_fault`
- `ai_suggestion`

### UI, alerts, and visibility

Automation views show physical connectivity, current/last sensor values, rule
evaluation trace, command authorization, cooldown, actuator result, and
power/data health. Bots show current task, capability, cargo, route, battery,
condition, and blockers. A simulation preview evaluates a rule against recorded
inputs without changing state.

Alerts cover rule storm/budget deferral, contradictory actions, actuator denial,
lost sensor/data/power, bot stranded, low battery, charger congestion,
maintenance, and safety interlock.

### Data definitions

`sensor`, `data_type`, `controller`, `controller_rule_template`, `actuator`,
`control_command`, `robot_chassis`, `robot_module`, `bot_profile`,
`charging_profile`, `automation_policy`, and `station_ai_service`.

Each command declares authorization, validation owner, payload schema, failure
state, and audit visibility.

### Mod hooks

- `transform:sensor_value`
- `validate:control_command`
- `observe:controller_rule_fired`
- `observe:actuator_result`
- `validate:bot_work_eligibility`
- `observe:bot_task_state`

Data mods add typed components/templates only. Trusted Lua mods may add hooks but
cannot present code as sandboxed. Advanced player-programmable hooks are not a
stable 1.0 interface.

### Save fields

Save controller rules/order/state/cooldowns, sensor histories required by rules,
queued data/control messages, authorization, bot physical/task/battery/module/
cargo/maintenance state, station-AI delegated permissions and suggestions,
counters, and policies. Rebuild connections and paths.

### Failure and recovery

Power/data loss invokes declared fail-safe. Stale/faulty sensors may cause wrong
but traceable actions. Contradictory same-tick commands resolve by safety
validation, configured priority, controller ID, rule order. Runaway rules defer/
disable under budget and alert. Bots can jam, deplete, break, lose access, spill
cargo, or require rescue/repair/recharge. Manual crew workflows remain available
for critical functions.

### Feature stages

- **Proof:** sensor → controller threshold → actuator, plus hauling bot.
- **Vertical slice:** atmos/power alarms and controls, cleaner/hauler bots,
  charging/maintenance, explainable rule trace.
- **1.0:** broad typed automation, robotics, station-AI operations assistant and
  safety interlocks.
- **Post-1.0:** AI laws/politics and deep MechComp-like programmable automation.

### Acceptance tests

1. Feed a recorded sensor stream through a controller and reproduce identical
   commands/traces after save/load.
2. Saturate rule/data budgets and verify stable priority, deferral, alert, and no
   simulation stall.
3. Cut power/data and test every fail-safe position and recovery path.
4. Give two controllers contradictory commands; authorization/safety/priority
   resolves once with audit evidence.
5. Run a bot through claim, fetch, work, low battery, charge, resume, damage, and
   repair without direct control.
6. A station-AI suggestion changes nothing until delegated rule or player command
   authorizes it.

## Security, access, law, evidence, and detention

### Purpose and player experience

Security manages access, safety, investigation, and due process using incomplete
information. It must create understandable institutional responses without
making the director omniscient or treating accusation as objective guilt.

### Authoritative state and units

Access is capability-based. A credential stores holder, issuer, access tags,
zones/doors, role/rank limits, validity interval, emergency flags, revocation,
and audit ID. A door/device validates presented credentials and local policy at
interaction time. Access tags do not imply knowledge of hidden contents.

A law/policy definition specifies prohibited/required acts, jurisdiction,
severity, evidence threshold, authorized roles/actions, emergency modifiers,
contraband tags, reporting, sentence range, and appeal/review. Objective events
may match a rule, but a case can act only on collected knowledge/evidence.

Evidence is an immutable observation with:

- evidence ID/type, subject/object/event hypotheses;
- physical source/item/tile/body/log record;
- collection tick/person/method, chain-of-custody transfers;
- integrity/contamination, confidence and possible alternative explanations;
- access/privacy scope; and
- derived findings from defined forensic processes.

A `SecurityCase` stores allegation, jurisdiction, linked reports/evidence,
persons of interest (not objective culprit), status, assigned investigator,
authorized search/warrant/arrest/detention actions, hearing/review, and outcome.

Security work includes patrol, respond, rescue support, interview, secure scene,
collect/analyze evidence, inventory audit, issue access, search, escort, arrest,
confiscate, treat, detain, release, and report. Force interactions use physical
items/anatomy and a configurable escalation policy.

Detention stores legal authority, start/review/release tick, destination,
sentence/service terms, rights/needs checks, possessions chain, and incident
history. It never disables crew physiology or removes their agency.

### Cadence and ordering

- Access validation and force/physical interactions run at `1t`.
- Alarms/reports may open/update response work immediately.
- Patrol/case planning runs at `10t`.
- Evidence degradation/contamination follows owning physical cadence.
- Detention review and welfare checks run at `60t`; sentence time advances only
  while lawful detention conditions defined by scenario are met.
- Security trends/policy metrics update at `300t` and shift boundary.

### Player levers

Define access profiles/zones, emergency access/lockdown, contraband, patrol/
response priorities, search/arrest/evidence thresholds, use-of-force, brig
capacity/sentencing ranges, privacy/records, armory, warrants/review, and
department staffing/budget. Review case evidence and authorize actions allowed
to the director by scenario.

The player cannot mark a person objectively guilty, expose hidden motive, order a
specific officer to attack, or bypass physical custody/medical needs.

### Autonomous behavior

Crew obey/access/request doors based on credentials and goals. Witnesses perceive,
remember, report, conceal, or misidentify according to view, senses, knowledge,
trust, policy, and traits. Officers respond, assess, de-escalate, investigate,
request authority, perform allowed actions, preserve custody, and release/review.
They can make mistakes based on incomplete evidence; the objective simulation
does not retroactively justify them.

### Inputs, outputs, and dependencies

Inputs: world zones/doors/cameras/data, crew/actions/relationships, items/
ownership/contraband, surfaces/forensics, medical state/consent, jobs/authority,
automation, economy/transactions, incidents, and knowledge/reports.

Outputs: access decisions, alarms/work, cases/evidence/warrants, confiscation,
force/injury, detention/release, mood/trust/reputation, fines/insurance, incident
conditions, and:

- `access_granted/denied/overridden`
- `security_alarm`
- `report_filed`
- `case_opened/updated/closed`
- `evidence_collected/analyzed/contaminated`
- `authority_issued/revoked`
- `force_used`
- `arrest/detention/release`
- `contraband_found`

### UI, alerts, and visibility

The security interface is a case/evidence board, not a hidden-trait list. It
shows reports, observations, timelines, map/camera records, chain of custody,
confidence, alternative explanations, legal thresholds, authorization, active
response, detention welfare, and appeal/review.

Direct camera feeds require operational coverage/data. Logs can be missing,
forged only through a declared future/content capability, or stale. Alerts cover
verified/unverified alarms, access breach, violence, missing person, evidence
tamper, armory/contraband, unlawful/overlong detention, medical emergency in
custody, and insufficient response.

### Data definitions

`access_tag`, `access_profile`, `credential`, `security_policy`, `law`,
`offense`, `contraband_rule`, `evidence_type`, `forensic_method`,
`case_template`, `authority`, `response_profile`, `force_policy`,
`detention_policy`, and `sentence`.

Every policy action declares required knowledge/evidence, authority role,
physical work type, and audit event. Data-only definitions cannot assert secret
guilt.

### Mod hooks

- `validate:access_attempt`
- `transform:witness_observation`
- `validate:case_authority`
- `transform:evidence_finding`
- `observe:security_event`
- `observe:evidence_changed`
- `observe:detention_state`

Hooks receive objective state only when registered by trusted simulation code.
Player-facing hooks receive projected evidence. No hook may identify a culprit
solely from the hidden incident/antagonist state.

### Save fields

Save credentials/revocations, policies, access audit, reports, cases/status/
assignments, evidence and physical links/chain/integrity, authorities/warrants,
response tasks, confiscated-property custody, detention records/reviews/
possessions, force events, security RNG if any defined identification uncertainty,
and counters.

### Failure and recovery

Security can miss, misinterpret, contaminate, overreact, arrive late, lose access,
run out of capacity, injure people, or detain wrongly. Recovery includes medical
care, review/appeal, release, evidence recollection, audit, policy/training
change, compensation, repairs, staffing, and external assistance.

Destroyed evidence remains destroyed but its custody record persists. An expired
authority stops new actions and creates release/review work. If brig capacity or
welfare fails, policy requires alternate supervised release/evacuation rather
than deleting detainees.

### Feature stages

- **Proof:** credentials/doors, alarm/report, evidence item, case and escort.
- **Vertical slice:** access zones, cameras/logs, patrol/response, contraband,
  basic investigation/arrest/brig, custody and medical welfare.
- **1.0:** detailed forensics, warrants/reviews, force policy, privacy, chain of
  custody, sophisticated cases.
- **Post-1.0:** hidden antagonists and associated deception/sabotage capabilities.

### Acceptance tests

1. Commit an unseen prohibited act: no case/culprit knowledge appears until a
   witness, camera, sensor, audit, or forensic observation exists.
2. Compare camera-visible, witness-only, and unobserved events; cases contain only
   valid evidence and confidence.
3. Revoke access during an active task; next interaction denies, task replans,
   and audit/report match policy.
4. Collect, transfer, analyze, contaminate, clean, and destroy evidence while
   preserving chain-of-custody and knowledge history.
5. Detain a medically needy crew member and verify time, food, atmosphere,
   treatment, possessions, review, and release remain physical workflows.
6. Save/load an open investigation without changing hidden truth, evidence,
   findings, or subsequent autonomous decisions.
