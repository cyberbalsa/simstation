# Medicine and chemistry

All substances, physiology, treatments, and procedures in Sim Station are
fictional simulation rules. Content definitions must not claim real-world
medical efficacy or provide real synthesis instructions.

## Anatomy, health, treatment, surgery, disease, and cloning

### Purpose and player experience

Medicine turns environmental and workplace failures into diagnosable,
treatable, capacity-limited consequences. A casualty is a persistent body and
person, not one health bar. The player supplies facilities, staff, stock,
triage/treatment policy, records, and emergency posture; doctors autonomously
diagnose and perform care.

### Authoritative state and units

A `Body` owns an anatomy graph. Nodes are body regions, limbs, organs, implants,
wounds, and internal containers; edges define attachment, blood flow, nerve/
functional dependency, and containment. Each node stores integrity/damage,
temperature, oxygenation, bleeding, infection/contamination, pain contribution,
function, missing/necrotic state, and treatment state.

Base damage channels are:

- brute: impact, crush, cut, puncture;
- burn: heat, cold, electrical, chemical;
- toxin: harmful reagent/metabolic load;
- oxygen: inadequate tissue oxygenation;
- radiation;
- cellular/genetic;
- infection/pathogen; and
- psychological trauma, owned by crew psychology but linked to medical events.

Damage uses integer milli-damage. Wounds are discrete records with type, region,
severity, bleeding rate in `mL` blood per tick remainder, contamination,
embedded-object IDs, pain, healing state, and forensic provenance.

The circulatory model stores blood volume in `mL`, oxygen capacity/saturation,
pressure/perfusion band, blood type/content tags, reagents/pathogens, and
bleeding/clotting state. Breathing consumes local gas through anatomy/equipment
and supplies blood oxygen; circulation supplies viable organs.

Pain, shock, consciousness, mobility, manipulation, senses, and death are
derived from anatomy and physiology through content-defined thresholds:

- unconsciousness disables voluntary action but permits involuntary physiology;
- critical state triggers urgent medical work and possible resuscitation;
- death requires a definition-owned irreversible condition or exceeding the
  resuscitation window, and emits one event;
- a corpse remains a physical body with anatomy, reagents, contamination,
  possessions, identity, and evidence.

A diagnosis is knowledge, not objective state. Tests/observations produce
findings with confidence, timestamp, source, and authorized record scope.

A `MedicalCase` stores patient, triage category, observed findings, suspected/
confirmed conditions, treatment plan, consent/emergency authority, assigned
facility/staff, medication/procedure orders, and outcome.

A procedure is a staged workflow with patient positioning, environment,
sterility, staff roles, skills, tools, consumables, anesthesia/pain policy,
ordered steps, interruption safety, success/failure effects, and documentation.

Disease uses pathogen instances with identity/strain, load, stages, vectors,
incubation, symptoms, immune response, treatment sensitivities, and mutation
checkpoints. Disease facts remain hidden until symptoms/tests/reports reveal
them.

Cloning consumes a valid scan/body source as defined by scenario, biomass/
reagents/energy, machine capacity, labor, and time. It produces a body linked to
the same persistent person only under the campaign's identity rule. The default
rule permits one active living instance per person; completing a clone while the
original is alive blocks unless an explicit cloning-mishap incident overrides it.
Cloning may carry scan-age memory gaps, traits, injuries, genetic errors, cost,
and morale/legal consequences.

### Cadence and ordering

- Immediate damage, bleeding, breathing, circulation, consciousness, and
  treatment interactions run at `1t`.
- Reagent metabolism and ordinary physiology run at `10t`.
- Wound healing, infection, disease symptoms, immune response, and low-frequency
  degeneration run at `300t`.
- Triage/task priority updates immediately on critical threshold and otherwise
  at `10t`.
- Procedure labor/steps progress at `1t`; machine-only stages use their declared
  cadence.
- Cloning advances at `10t` and commits identity/body creation atomically.

### Player levers

Build/zone clinics, operating rooms, pharmacies, morgues, isolation, cloning, and
triage areas; set treatment, resuscitation, consent, quarantine, organ/
prosthetic, cloning, medication-stock, privacy, billing, and mass-casualty
policies; staff/schedule/train; prioritize cases and import/produce supplies.

The player cannot select a diagnosis, medication, incision, or limb action for a
specific patient. They may authorize a policy-class procedure or resource limit;
qualified clinicians generate and execute the case plan.

### Autonomous behavior

Patients seek/report care according to symptoms, knowledge, schedule, access,
trust, urgency, and policy. Clinicians triage from observed findings, request
tests, form bounded differential diagnoses, create treatment/procedure orders,
reserve resources, and reassess outcomes. They refuse procedures without
authority, skill, equipment, environment, or reasonable expected benefit unless
emergency policy permits.

Rescuers stabilize/transport casualties using work orders. Dead bodies generate
notification, recovery, autopsy/investigation, morgue, cloning, memorial, or
disposal workflows according to policy.

### Inputs, outputs, and dependencies

Inputs: crew anatomy/traits, atmosphere/temperature/fire, physical impacts,
reagents/chemistry, disease, food/digestion, sanitation, radiation, tools/
medicines/organs, facilities/power, staff/work, security/evidence, economy, and
policy.

Outputs: capabilities/incapacity, needs/mood, work eligibility, diagnoses/
records/reports, treatment consumption, waste/contamination, death/cloning,
experience, bills, incidents, and:

- `damage_applied`
- `wound_created/changed`
- `health_threshold`
- `crew_incapacitated/revived`
- `medical_case_opened/closed`
- `diagnostic_finding`
- `treatment_started/completed/failed`
- `procedure_step/completed/interrupted`
- `disease_stage_changed`
- `death`
- `clone_started/completed/failed`

### UI, alerts, and visibility

The health overlay shows observed casualty state and medical coverage, never
undiscovered diagnoses. Personnel cards display authorized chart findings,
triage, current plan, facility/staff/resource blockers, and prognosis range with
confidence. Anatomy views distinguish observed/diagnosed/unknown.

Alerts cover unreported visible casualty, critical patient, no qualified
coverage, triage overflow, oxygen/blood/medicine shortage, unsafe operating room,
contagion suspicion, quarantine failure, morgue overflow, clone fault, and mass
casualty. Content settings replace gore visuals with clinical symbols while
preserving state.

### Data definitions

`species_anatomy`, `body_region`, `organ`, `limb`, `wound`, `damage_profile`,
`physiology`, `blood_type`, `condition`, `diagnostic_test`, `medical_facility`,
`treatment`, `procedure`, `procedure_step`, `prosthetic`, `organ_item`,
`pathogen`, `disease_stage`, `immune_profile`, `cloning_profile`, and
`medical_policy`.

All procedures declare stage interruption and material/reagent accounting.
Pathogens declare every transmission vector and visibility rule. Treatments
reference fictional reagent/content IDs and cannot embed real dosage
instructions in player-facing text.

### Mod hooks

- `transform:damage_application`
- `transform:physiology_step`
- `validate:medical_plan`
- `transform:treatment_effect`
- `transform:disease_progression`
- `validate:clone_completion`
- `observe:health_event`
- `observe:diagnostic_finding`
- `observe:procedure_state`
- `observe:death/clone_completed`

Player-facing observers receive only projected medical knowledge. Transforms
cannot revive/delete a person without emitting the corresponding authoritative
transition and provenance.

### Save fields

Save anatomy graph/node states, wounds, blood/circulation, physiology remainders,
reagents/pathogens, consciousness/death/resuscitation, medical cases/findings/
plans, procedure stages/reservations, disease RNG and checkpoints, medical
records/access, corpse state, clone scans/process/identity link, counters, and
scheduled future effects. Rebuild derived function/prognosis/task indexes.

### Failure and recovery

Failure includes misdiagnosis from incomplete evidence, delayed care, supply/
staff/facility shortage, interrupted procedures, medication interaction/
overdose, contamination, infection spread, permanent disability, death, and
cloning defect. Recovery includes first aid, rescue, reassessment, surgery,
prosthetics, rehabilitation, quarantine, external aid, emergency imports,
cloning, staffing changes, and policy reform.

Doctors never intentionally choose a known dominated treatment unless a
trait/incident explicitly changes their knowledge or judgment. “No feasible
plan” is reported with missing requirements. A malformed anatomy graph or
double-active identity is a load/commit error, never silently repaired.

### Feature stages

- **Proof:** simple anatomy, four core damages, blood/oxygen, wound, treatment,
  death, rescue work.
- **Vertical slice:** limbs/organs overview, first aid, beds/scanners, basic
  medication, surgery workflow, casualty transport, corpse handling, cloning
  recovery.
- **1.0:** detailed anatomy/surgery, diseases, prosthetics/organs, blood types,
  broad diagnostics, rehabilitation and cloning mishaps.
- **Deferred:** adversarial sleeper conditions and supernatural biology.

### Acceptance tests

1. Cause decompression injury and trace atmosphere → breathing/blood oxygen →
   consciousness/damage → rescue → treatment → work availability.
2. Apply a wound with known blood volume and reconcile bleeding, surfaces,
   transfusion, clotting, and remaining circulation.
3. Run every procedure interruption point and verify patient state, consumed
   materials, reservations, contamination, and recovery work.
4. Conceal a disease during incubation; the director sees no diagnosis until a
   valid symptom/test/report.
5. Save/load during critical physiology, procedure, disease, and clone process;
   match uninterrupted outcomes and RNG.
6. Attempt a duplicate active clone; block atomically, preserve inputs according
   to pre-commit rules, and report the identity conflict.
7. Enable low-gore mode and verify all mechanical warnings, anatomy selection,
   evidence, and treatment remain legible.

## Reagents, containers, reactions, and chemistry

### Purpose and player experience

Chemistry supplies a shared, composable substance model for medicine, food,
cleaning, agriculture, industry, fire, atmosphere, contamination, and incidents.
It should produce understandable interactions without requiring the player to
micromanage individual beakers.

### Authoritative state and units

A reagent mixture is an ordered map of reagent content IDs to integer `mL`, plus
temperature in `mK`, thermal-energy remainder, pH-like fictional property if
defined, contamination/pathogen references, and provenance batches.

Every reagent defines:

- density/heat capacity and physical phase thresholds;
- color, opacity, taste/odour and visibility;
- metabolism and effects by exposure route;
- overdose, interaction, and addiction profiles where fictional content uses
  them;
- flammability/combustion and atmospheric products;
- cleaning/agriculture/industrial traits;
- container/material compatibility; and
- reaction tags.

Mixtures are perfectly mixed within one container at tile-game scale.
Transferring liquid moves each reagent proportionally with deterministic
remainders. Container maximum volume is strict; overflow becomes a surface,
another connected container, or rejected transfer according to the interaction.

A reaction definition includes reactant quantities, catalysts, allowed container
and machine capability, temperature/pressure/light ranges, stage time, rate,
products/byproducts/gases/heat, minimum batch, priority, and equilibrium/
completion rule. At a chemistry step:

1. enumerate eligible reactions by definition priority then content ID;
2. compute maximum extent from actual reactants and conditions;
3. apply bounded extent and energy changes;
4. repeat until no eligible reaction or the definition-owned iteration cap;
5. carry fractional remainders and emit a diagnostic if capped.

Reactions cannot consume and reproduce an identical net mixture without a
declared equilibrium guard.

Exposure routes are ingestion, injection, inhalation, touch, wound, and implant
release. A body owns separate internal containers where relevant. Metabolism
converts actual quantities into metabolites/effects; a status effect never
appears without reagent or an explicitly nonchemical cause.

### Cadence and ordering

- Manual/machine transfer and spills resolve at `1t`.
- Active reactions and temperature changes run at `10t`.
- Body metabolism runs at `10t` after exposure and before derived health state
  finalization.
- Surface evaporation/decomposition uses `300t` unless hazardous/volatile
  definitions activate faster processing.
- Pipe/machine chemistry follows its utility/process cadence but calls the same
  reaction solver.

### Player levers

Build/stock laboratories and pharmacies; define approved formulas, production
orders, dosage/dispensing policies, controlled-substance access, storage
compatibility, waste handling, safety thresholds, and research permissions.
Set machine recipes and batch sizes through production planning.

The player cannot drag exact reagents between containers or inject a patient;
chemists, pharmacists, doctors, service workers, machines, and bots act through
work and policy.

### Autonomous behavior

Qualified workers select formula, equipment, source containers, protective gear,
and batch size; reserve inputs/output capacity; perform stages; label/store
products; and dispose of waste. Clinicians and other systems request chemical
products by exact ID/concentration/quality. Crew may consume recreational/
personal substances according to access, needs, traits, law, and price.

### Inputs, outputs, and dependencies

Inputs: items/containers, machines, heat/power, gases/pressure, materials,
workers/skills, recipes/research, bodies/food/plants/surfaces, sanitation,
security/access, and economy.

Outputs: mixtures/products, gases/heat/fire, body effects, cleaning/agriculture/
industry effects, contamination, evidence/contraband, waste, work, and:

- `reagent_transferred/spilled`
- `reaction_started/completed/stalled`
- `mixture_threshold`
- `exposure_occurred`
- `metabolism_effect`
- `overdose_threshold`
- `container_failed`

### UI, alerts, and visibility

Mixture contents are shown only when labeled, scanned, tested, or known from a
trusted production record. The chemistry planner shows exact known formula
requirements, hazards, equipment, temperature/pressure ranges, yield, waste, and
stage blockers. Unknown containers remain unknown, not auto-identified by
appearance.

Alerts cover incompatible storage, overpressure/temperature, uncontrolled
reaction, toxic/flammable spill, controlled-substance discrepancy, missing
antidote/medicine, unlabeled product, and waste overflow.

### Data definitions

`reagent`, `reaction`, `reaction_stage`, `exposure_profile`,
`metabolism_profile`, `status_effect`, `chemical_container`, `chemical_machine`,
`formula`, `label_policy`, and `controlled_substance_policy`.

The loader performs stoichiometric unit checks, requires bounded reaction loops,
and rejects negative quantities, duplicate products, missing exposure behavior,
or a gas/heat output without owning-system mapping.

### Mod hooks

- `validate:reagent_transfer`
- `transform:reaction_extent`
- `transform:metabolism_step`
- `transform:exposure_effect`
- `observe:reaction_state`
- `observe:reagent_exposure`
- `observe:overdose_threshold`
- data additions for all chemistry definitions

Transforms must conserve declared quantities/energy or add an explicit ledger
source/sink. A mod cannot inspect an unknown mixture through a player-facing hook.

### Save fields

Save every mixture amount/remainder/temperature/provenance, container state,
active reactions/stages, scheduled effects, body reagent containers and
metabolism, labels/knowledge, chemical machine state, reaction RNG if a
definition uses declared checkpoints, and conservation ledgers.

### Failure and recovery

Wrong ingredients, temperature, pressure, contamination, container material,
power loss, or interruption can stall, spoil, overflow, rupture, ignite, poison,
or create declared failure products. Inputs after commit are not refunded.
Recovery includes isolation, ventilation, suppression, protective cleanup,
medical treatment, alternate formula, import, relabel/test, machine repair, and
secure disposal.

### Feature stages

- **Proof:** containers, transfer, two-step reaction, heat/gas, ingestion/
  metabolism, spill.
- **Vertical slice:** basic medicines, cleaners, fuels, food/agriculture
  reagents, pharmacy production, overdose, unknown mixture and hazards.
- **1.0:** broad reactions, addictions, advanced medicine/toxins, pipe chemistry,
  controlled substances and forensic analysis.
- **Deferred:** player-authored arbitrary reaction code in data mods.

### Acceptance tests

1. Split/merge/transfer a multi-reagent mixture repeatedly and conserve each
   reagent, volume, and energy.
2. Run simultaneous eligible reactions in randomized map insertion order and
   produce identical extent/products.
3. Heat a sealed reaction until it releases gas/ruptures; reconcile reagents,
   gas, heat, fragments, surfaces, fire, and injury.
4. Dose, metabolize, overdose, treat, and excrete a fictional reagent with exact
   mass/remainder accounting.
5. Hide an unlabeled mixture from the director until a valid label/test and
   preserve that knowledge across save/load.
6. Validate a mod reaction cycle is rejected with the definitions and reaction
   path responsible.
