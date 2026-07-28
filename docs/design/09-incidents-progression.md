# Incidents and progression

## Incident director

### Purpose and player experience

The incident director creates pressure and variety by selecting authored
systemic disturbances that interact with the current station. It is a scheduler,
not a cheating opponent. It never bypasses physical systems, spends resources
without a ledger, or chooses an event whose prerequisites are false.

Early play emphasizes environmental, technical, medical, financial, logistical,
and social incidents. Hidden antagonists are post-1.0 and use the same knowledge
boundaries as other secret state.

### Authoritative state and units

Each scenario owns one `IncidentDirectorState`:

- named RNG stream;
- current and maximum threat budget in milli-threat;
- recovery pressure, mercy debt, escalation tier, and difficulty profile;
- active incident IDs and per-category/global cooldowns;
- recent incident/category history;
- station stress metrics sampled from public system summaries;
- scheduled authored beats;
- candidate rejection history for diagnostics; and
- enabled/disabled content tags and content-setting compatibility.

An `IncidentDefinition` contains:

- category, severity/tier, threat cost, weight, minimum shift/time, cooldowns,
  concurrency group, content tags, and scenario compatibility;
- objective prerequisites expressed as bounded queries;
- fairness gates: minimum viable response, warning requirements, protected
  tutorial windows, dependency exclusions, and recovery requirements;
- target-selection strategy from stable candidate sets;
- staged timeline, telegraphs, physical spawns/commands, escalation/expiry,
  success/failure/recovery conditions, and cleanup;
- visibility rules separating objective state from observations/reports; and
- influence on grading, economy, unlocks, and follow-up incidents.

Threat budget accrues at a difficulty-defined integer rate modified by shift,
scenario, player-selected difficulty, recent recovery, and explicit campaign
conditions. It never reads save/load count, pause time, UI state, player camera,
or future command queue.

Selection at a check:

1. build candidates that pass prerequisites, cooldown, concurrency, fairness,
   content toggles, and budget;
2. compute integer weight from definition and allowed stress/context transforms;
3. sort by content ID;
4. make one weighted draw from the incident stream;
5. choose targets from a sorted eligible set using the same stream;
6. spend cost and create the incident atomically; or
7. record no-candidate and retain budget up to the cap.

No reroll occurs because the result is inconvenient.

### Cadence and ordering

- Budget accrues at `60t`.
- Candidate selection checks at `300t`, plus authored scenario beats.
- Incident stages schedule exact absolute ticks and commit through validated
  system commands/events.
- Active incidents evaluate completion/failure at their declared cadence, no
  faster than `1t`.
- Recovery pressure updates at `60t`; category/global cooldowns use absolute
  ticks.

### Player levers

Before a campaign, choose difficulty profile, content categories/toggles,
hard-failure scenarios, tutorial protection, and incident-frequency range. During
play, the player controls only station responses and may use scenario-granted
external aid. They cannot veto or reroll an already selected incident outside
debug/accessibility options that mark scoring accordingly.

### Autonomous behavior

The director selects/stages incidents. Each incident creates physical conditions,
messages, observations, work, contracts, or policy dilemmas. Crew/machines react
through normal systems. An incident may observe outcome events but cannot set
crew actions or declare a physical outcome that did not occur.

### Inputs, outputs, and dependencies

Inputs: scenario/difficulty, shift/time, station population/capacity, known and
objective prerequisite queries, recent incident/recovery state, content settings,
campaign progression, and system events.

Outputs: validated commands/spawns, external messages, objectives, reports,
physical hazards/resources, threat/cooldown state, follow-up candidates, and:

- `incident_selected`
- `incident_stage_changed`
- `incident_telegraphed`
- `incident_escalated`
- `incident_resolved/failed/expired`
- `incident_recovery_complete`
- `external_aid_offered/accepted`

### UI, alerts, and visibility

Players see only telegraphs, sensor data, reports, and discovered incident facts.
The active-incident list is a list of known emergencies/objectives; an unknown
active incident does not appear by internal name. After resolution, the shift
report may reveal director selection and hidden facts only when the scenario's
debrief policy permits.

Difficulty setup shows budget/recovery philosophy, not upcoming rolls. A
developer-only director inspector lists budget, candidates, rejection reasons,
RNG state, and scheduled stages and marks the save debug-modified.

Alerts are incident-authored observations and use ordinary visibility. A meteor
warning can arrive externally; a concealed machine defect cannot announce itself
without a sensor/report.

### Data definitions

`incident`, `incident_stage`, `incident_category`, `difficulty_profile`,
`target_selector`, `fairness_gate`, `telegraph`, `external_aid`, and
`incident_outcome`.

Prerequisite and target queries use a declarative audited query vocabulary. Data
mods cannot run Lua, inspect player camera, issue direct state writes, or read
secret content owned by another incident.

### Mod hooks

- `transform:threat_accrual`
- `validate:incident_candidate`
- `transform:incident_weight`
- `transform:incident_target_score`
- `observe:incident_lifecycle`
- `observe:incident_outcome_event`

Hooks must be deterministic, bounded, and diagnostic. Player-facing observe hooks
receive only known stages/facts.

### Save fields

Save complete director state, budget/remainders, RNG, cooldowns/history,
stress/recovery metrics, every active incident/stage/target/schedule/hidden state,
external-aid offers, candidate diagnostic summary, and incident ID counter.
Never regenerate or reroll an active/scheduled incident on load.

### Failure and recovery

An incident definition that becomes invalid after selection enters `faulted`,
stops future stages, preserves already committed physical effects, refunds only
unspent threat cost by explicit rule, and emits a mod diagnostic. It never rolls
a replacement in the same check.

Fairness is enforced through prerequisites and recovery pacing, not outcome
protection. A response can fail. Normal campaign aftermath always has at least
one authored recovery path—repair, treatment, bailout, emergency supplies,
evacuation, contractors, salvage, or station abandonment—unless the selected
scenario declares hard failure.

### Feature stages

- **Proof:** threat budget, weighted deterministic selection, staged power fault
  and meteor/breach, cooldown/recovery.
- **Vertical slice:** environmental, technical, medical, financial, logistical,
  and social incidents; emergency aid; no hidden antagonists.
- **1.0:** broad incident library, conditional chains, expedition/artifact and
  campaign events, difficulty profiles.
- **Post-1.0:** hidden antagonists, sabotage, deception, and adversarial goals.

### Acceptance tests

1. Run identical seed/state/checks and receive identical candidate rejection,
   selection, target, stage, and outcome events.
2. Save immediately before/after selection and prove no reroll or double budget
   spend.
3. Make all candidates fail fairness; budget caps predictably and no impossible
   event fires.
4. Cause a meteor breach and trace its physical cascade through environment,
   health, labor, production, economy, recovery, and grading.
5. Resolve a disaster poorly; director recovery pressure prevents an unfair
   overlapping major event but does not undo consequences.
6. Disable gore/substance tags and validate all selected incidents have complete
   alternate presentation without changing mechanical severity.
7. Load a save missing an active incident definition and block it with a precise
   migration/mod requirement.

## Scenarios, objectives, shift grading, and campaign progression

### Purpose and player experience

Progression gives the persistent station direction without reducing systemic
play to a fixed mission script. Scenarios establish constraints and recovery/end
rules. Objectives encourage different institutions. Shift grading summarizes
observable results and unlocks options without erasing a damaged station.

### Authoritative state and units

A `ScenarioDefinition` specifies:

- starting station map/core, remote-site pool, crew roster/generation rules,
  items, accounts/budgets/debt, research/unlocks, market/contracts, and policies;
- allowed population range, recruitment, external services, and map boundaries;
- incident difficulty/content, tutorial sequence, and hidden information;
- objective pool and required primary objectives;
- recovery aids, hard-failure conditions, abandonment rules, and debrief policy;
- campaign compatibility and completion rewards.

A normal campaign starts with a small powered, pressurized core containing basic
life support, beds, food, medical supplies, tools, cargo link, and enough
qualified staff to operate safely under default policy. It is viable but lacks
capacity and redundancy for long-term objectives.

An objective is a stateful contract:

- stable ID/type, issuer, start/deadline, prerequisites;
- measurable conditions queried from owning systems;
- progress/outcome evidence, optional secrecy;
- rewards/costs/reputation/unlocks;
- failure, cancellation, partial-credit, and recovery behavior.

Objectives never poll rendered/UI values. They consume authoritative events and
queries.

Shift score uses seven categories, each 0–100,000:

| Category | Examples |
|---|---|
| safety | preventable deaths/injuries, hazard exposure, response/recovery |
| welfare | needs, mood, rest, pay, access to care/services, retention |
| finance | liquidity, sustainable cash flow, debt, budget adherence |
| operations | life-support uptime, maintenance, logistics and production |
| service | food, cleanliness, medical coverage, objective delivery |
| science | safe research, useful output, grant performance |
| security | response, due process, evidence quality, custody welfare |

Scenario weights sum to 1,000,000 ppm. The overall grade is weighted integer
score, with bands S/A/B/C/D/E set by difficulty. Each line is calculated from
event/ledger/state evidence and exposes its formula. No hidden-antagonist result
affects a grade before that result is valid debrief knowledge.

Campaign progression stores:

- completed scenarios/objectives and best grades;
- reputation by external faction/domain;
- unlocked scenario starts, construction/recipe/research options, cosmetic
  themes, and policy templates;
- station history, crew history/memorial, debt and persistent consequences;
- optional meta-assist settings earned or selected.

Unlocks expand choices, not raw universal productivity. All critical recovery
tools remain available through base content or external aid.

### Cadence and ordering

- Objective conditions update from events and at their declared query cadence.
- Forecast UI updates at `300t`.
- Shift settlement follows the exact economic order, then closes objective
  windows, computes category evidence/scores, applies rewards/reputation/
  unlocks, writes history, and autosaves.
- Campaign end/hard failure evaluates only after all same-tick rescue/recovery
  transitions and objective outcomes.

### Player levers

Choose scenario, difficulty, seed visibility, optional objectives, content
settings, hard-failure option where available, and initial policy templates.
During play, accept/decline offered contracts/objectives and choose recovery aid,
evacuation, abandonment, or continued operation.

The player cannot edit score weights or conditions after campaign start without
debug-modifying the save.

### Autonomous behavior

External agencies offer contracts, aid, candidates, grants, and consequences
according to definitions. Department heads surface suggested objectives and
recovery plans. Crew react to success, failure, casualties, debt, station
conditions, and memorials.

### Inputs, outputs, and dependencies

Inputs: all system events/queries, economy settlement, incidents, crew history,
contracts, scenario state, difficulty, and settings.

Outputs: objective state, rewards/penalties, accounts/reputation, unlocks,
candidate/site/contract pools, shift grade/report, recovery/abandonment/end
state, and:

- `objective_offered/accepted/updated/completed/failed`
- `shift_ending/settled/graded`
- `campaign_unlock`
- `reputation_changed`
- `recovery_option_offered/chosen`
- `station_abandoned`
- `scenario_completed/failed`

### UI, alerts, and visibility

The objectives panel shows conditions, known progress, deadline, reward, failure,
and partial credit. Unknown conditions display as unknown or inferred, never
objective truth. The shift preview estimates category ranges and names risks
without guaranteeing future outcomes.

The shift report contains:

- station timeline and incident/recovery summaries;
- category scores with every contribution and source event;
- income/expense/payroll/debt statement;
- casualties, health, welfare, staffing and retention;
- production, logistics, service, research, and security outcomes;
- objective/contract results;
- unlocked choices and next-shift forecasts; and
- buttons to continue, choose aid, evacuate, or abandon when applicable.

### Data definitions

`scenario`, `campaign`, `objective`, `objective_condition`, `score_category`,
`grade_band`, `reputation`, `unlock`, `recovery_option`, `hard_failure`,
`tutorial_sequence`, and `debrief_policy`.

Condition/query vocabulary is declarative and owned by system public queries.
Definitions must specify empty-population, missing-data, partial-shift, and debug
behavior.

### Mod hooks

- `validate:objective_offer`
- `transform:objective_progress`
- `transform:score_category`
- `validate:recovery_option`
- `observe:objective_state`
- `observe:shift_grade`
- `observe:campaign_unlock`

Score transforms return itemized contributions and cannot inspect UI/player
camera. Mods replacing scenarios own migration of active scenario/objectives.

### Save fields

Save scenario/campaign IDs and versions, starting seed/content lock, objective
states/evidence/deadlines, score accumulators, campaign history, reputation,
unlocks, tutorial progress, difficulty/content settings, recovery offers/choice,
hard-failure state, shift number/start tick, and settlement checkpoint. Shift
settlement is idempotent by checkpoint and transaction IDs.

### Failure and recovery

Normal campaigns convert insolvency, evacuation, severe casualty, and station
loss into consequences and choices. External aid has explicit costs/debt/
reputation. Abandonment preserves allowed campaign history, unlocks, reputation,
surviving crew, and debt according to scenario, then starts a new station.

Hard failure occurs only if enabled and a declared condition is observed after
the recovery grace rule. It ends the scenario, preserves a final save/report,
and never deletes prior saves.

A shift report or settlement failure blocks transition and keeps a recoverable
pre-settlement save; idempotency prevents double payroll/rewards.

### Feature stages

- **Proof:** scenario start, one objective, category scoring, settlement,
  continue/reload.
- **Vertical slice:** normal small core, one full eight-hour objective/contract
  arc, seven-category grade, bailout/resupply/evacuation/repair recovery.
- **1.0:** varied scenarios/difficulties/campaigns, reputation, unlocks,
  abandonment and optional hard failure.
- **Deferred:** multiplayer rankings and always-online progression.

### Acceptance tests

1. Complete the canonical vertical-slice shift: expand, staff, mine/import,
   refine/manufacture, pay/feed, export, survive breach/fire, treat, clean,
   repair, and receive traceable grade.
2. Compute a report twice and after save/load; settlement transactions, rewards,
   unlocks, and grade occur exactly once.
3. Make station state unknown to sensors at shift end; grading uses objective
   truth where policy permits but the player-facing line labels unavailable
   evidence rather than leaking detail.
4. Enter insolvency and choose each recovery route; funds/resources/debt/
   reputation/station state match definitions.
5. Trigger optional hard failure with it disabled and enabled; only the enabled
   scenario ends, and both retain final saves.
6. Add a mod scenario/objective/score category and exercise start, progress,
   report, save, content-lock mismatch, and explicit migration.
