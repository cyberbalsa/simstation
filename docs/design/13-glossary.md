# Glossary

Canonical terms are singular where possible. Code, schemas, UI, localization, and
documentation use these meanings.

## Time, world, and state

| Term | Meaning |
|---|---|
| tick | One authoritative in-world second. Never means a rendered frame. |
| decisecond (`ds`) | One tenth of an in-world second, used by the ordered machine subcalendar. |
| real second | Wall-clock second. At 1× it schedules ten ticks. |
| shift | 28,800 ticks/eight in-world hours; about 48 real minutes at 1×. |
| campaign | Persistent history spanning shifts and possibly replacement stations. |
| scenario | Definition of starting state, constraints, objectives, incidents, recovery and end rules. |
| station deck | The one permanent 192×192 station map. Do not call it level or z-level. |
| remote map | Separate single-plane mining/derelict/expedition site linked by transport. |
| tile | Integer simulation cell. It is logically represented by 32×32 source art but has no pixel state. |
| chunk | 16×16 tile partition used for dirty tracking and spatial work. |
| layer | One typed world slot such as floor, structure, fixture, utility, or surface. Not a station deck. |
| room | Computed physical space resulting from topology. |
| zone | Player-authored intent/policy geometry; it does not guarantee room conditions. |
| region | Computed connected set for one topology purpose, such as passability or atmosphere. |
| revision | Monotonic counter identifying a changed cache dependency. |
| authoritative | State that determines simulation outcomes and is saved/hashed. |
| derived | Recomputable value or cache that does not independently determine truth. |
| snapshot | Immutable completed-tick projection consumed by presentation. |

## Commands, events, knowledge, and content

| Term | Meaning |
|---|---|
| `GameCommand` | Serializable intent validated and applied atomically at a tick boundary. |
| `SimEvent` | Immutable ordered fact produced by an authoritative transition. |
| observation | Timestamped measurement/perception/report-derived fact with source and confidence. |
| objective truth | Actual authoritative state, which may be unknown to the player. |
| direct | Currently visible through valid camera/sensor coverage. |
| measured | Sensor reading with source, timestamp, accuracy/fault behavior. |
| reported | Claim communicated by crew/external source and potentially incomplete. |
| inferred | Explicit estimate derived from known observations. |
| unknown | Not available to the player; never displayed as a precise value. |
| last-known | Prior observation retained with age/staleness. |
| definition | Immutable JSON content record loaded from a pack. |
| content pack | Versioned mod/base-content unit with manifest, definitions, assets, locales, and optional trusted code. |
| content ID | Stable namespaced `<pack>:<kind>/<name>` identifier. |
| entity ID | Monotonic campaign-local identity for a physical/person/machine object. |
| content lock | Exact ordered pack versions/hashes required by a save/replay. |
| data mod | Declarative content only; validated and unable to execute Lua. |
| code mod | Explicitly trusted arbitrary Lua extension; not sandboxed. |
| hook | Ordered observe, validate/cancel, or transform/reduce extension point. |
| reason code | Stable localized explanation identifier used by validation and AI. |
| machine affordance | Definition-declared typed action projected for one machine/actor with availability and blocker. |
| fidelity ledger | Per-feature record of exact/equivalent/adapted/fixed/deferred/not-applicable upstream behavior. |

## Work and organization

| Term | Meaning |
|---|---|
| director | The player role. Not a possessed on-station pawn. |
| crew | Persistent autonomous person employed or present on the station. |
| department | Organizational owner of budget, policy, work domain, facilities, and jobs. |
| job | Role definition governing work eligibility, wage range, access profile, and duties. |
| rank | Authority/supervision relationship; not a skill multiplier. |
| schedule | Ordered work/rest/service availability blocks for a crew member. |
| goal | Crew-selected current purpose, including work, need, emergency, or leisure. |
| work order | System-owned offered unit of autonomous labor with explicit prerequisites and lifecycle. |
| task | Preferred UI shorthand for a work order. Never a direct player assignment. |
| claimant | Crew or bot that currently owns an offered work order. |
| reservation | Stable exclusive/counted/capacity claim preventing double allocation. |
| priority | Director/policy urgency level 0–5. It never overrides eligibility or physics by itself. |
| policy | Versioned rule snapshot controlling institutional behavior. |
| emergency order | High-priority policy/zone declaration that changes eligible responses; not direct pawn control. |
| blocker | Stable reason a task/plan/action cannot currently progress. |
| refusal | Crew decision not to attempt/continue work for a recorded reason. |
| staffing forecast | Explainable estimate of workload/coverage, not a hidden efficiency modifier. |

## Physical systems and resources

| Term | Meaning |
|---|---|
| atmosphere cell | Tile-owned gas amounts, volume and thermal-energy state. |
| sealed region | Currently gas-connected cell set bounded from another region/space. |
| utility network | Connected graph of one typed channel: power, gas pipe, liquid, disposal, or data. |
| power allocation | Deterministic distribution of available watts to loads; not “electricity units.” |
| fail-safe | Definition-declared device state on loss of power/data/control. |
| item | Physical entity at exactly one world/containment/transport/external location. |
| stack | Mergeable physical items with an identical declared stack key. |
| container | Item/machine/body storage with capacity, access, and compatibility. |
| material | Physical composition component measured in grams. |
| material form | Item form such as ore, sheet, rod, cable, powder, or part. |
| quality | Bounded 0–100,000 production attribute with declared property effects. |
| reagent | Fictional liquid/chemical component measured in millilitres. |
| mixture | Ordered reagent amounts plus temperature/provenance in one container. |
| surface deposit | Dirt/fluid/residue/pathogen/evidence-bearing quantity on a physical surface. |
| provenance | Source and transformation history for an item, material, mixture, evidence record, or asset. |
| conservation ledger | Diagnostic accounting of a physical quantity by named source/sink. |
| commit point | Stage boundary after which reserved inputs are physically consumed/incorporated. |

## Production, services, and economy

| Term | Meaning |
|---|---|
| stock rule | Desired allowed contents and min/target/max for a physical destination. |
| haul request | Logistics-owned source-to-destination transfer work. |
| production order | Requested product/quantity/quality expanded into recipe stages and reservations. |
| recipe | Ordered finite stage graph converting physical inputs to outputs/byproducts. |
| batch | One in-progress execution of a recipe for a bounded quantity. |
| service offering | Staffed or automated facility capacity that satisfies a need/action, possibly for a price. |
| account | Ledger participant; its balance derives from postings. |
| ledger | Append-only double-entry financial record. |
| transaction | Balanced set of debit/credit postings tied to a physical/contractual cause. |
| budget | Authorization envelope, not a separate pile of money. |
| commitment | Reserved budget/resource capacity not yet physically spent/consumed. |
| quote | Market price and terms locked only until an expiry tick. |
| order | External import/export lifecycle; use production order for internal manufacturing. |
| contract | External delivery/performance agreement with terms, deadline and settlement. |
| arrears | Earned but unpaid wages retained as a station obligation. |
| bailout | Explicit external credit/recovery resource with debt/reputation terms. |

## People, medicine, science, and security

| Term | Meaning |
|---|---|
| need | Bounded physiological/social desire influencing goals and health. |
| thought | Time-bounded explainable mood modifier created by an event/state. |
| trait | Persistent data-defined modifier/visibility field; not automatically public knowledge. |
| anatomy graph | Body regions, limbs, organs, implants, wounds and functional relationships. |
| condition | Objective medical state or diagnosis candidate. Do not use status ambiguously. |
| finding | Observed medical fact with confidence/source. |
| medical case | Triage, known findings, plan, authority, resources and outcome for one patient. |
| procedure | Staged staffed medical workflow with interruption semantics. |
| pathogen | Disease-causing simulated entity/strain with transmission and progression. |
| clone | Newly produced physical body linked under the campaign identity rule. |
| observation (research) | Immutable experimental evidence; uses the same knowledge principle. |
| data (research) | Quality/domain-tagged analysis output derived from observations. |
| insight | Campaign research knowledge satisfying proposal milestones. |
| unlock | Stable permission making content eligible; it never spawns the content. |
| artifact | Seeded object with initially hidden capability properties. |
| controller | Bounded declarative automation device evaluating typed rules. |
| bot | Autonomous machine claiming compatible normal work; never directly driven. |
| station AI | 1.0 operations/suggestion service using station sensors/data. AI-law politics are deferred. |
| credential | Issued access capability with scope, validity and audit. |
| report | Communicated assertion/observation; not proof of objective truth. |
| evidence | Physical/log/observation record with integrity, confidence and chain of custody. |
| security case | Allegation, evidence, authority, actions and outcome; not a hidden guilt record. |
| authority | Time/scope-bounded permission for a security action such as search or detention. |
| detention | Physical lawful custody with welfare, review, possessions and release state. |

## Incidents, progression, and presentation

| Term | Meaning |
|---|---|
| incident | Authored staged disturbance selected under prerequisites/fairness and executed through normal systems. |
| threat budget | Director-owned milli-threat resource used only to select incidents. |
| recovery pressure | Incident-pacing state that reduces unfair overlap after damage; not outcome protection. |
| telegraph | In-world warning/observation generated by an incident. |
| objective | Stateful scenario/contract condition consuming authoritative events/queries. |
| grade | Weighted shift outcome score with itemized evidence. |
| recovery option | Authored aid/debt/evacuation/repair/abandonment choice after failure. |
| hard failure | Scenario-declared terminal condition enabled before play. |
| abandonment | Leaving a station while preserving scenario-defined campaign history/consequences. |
| alert | Player-facing projection of a known event/condition. Not every event becomes an alert. |
| overlay | Map visualization of known semantic state and data age. |
| inspector | Read-only contextual projection plus valid director commands. |
| codex | Searchable definitions/rules generated from content and authored explanations. |
| content filter | Pre-game exclusion of tagged content definitions; recorded in campaign header. |
| presentation toggle | Runtime substitution of visuals/audio/strings without mechanics changes. |

## Terms to avoid

- Do not use **turn** for a tick or shift.
- Do not use **inventory** to imply a global item pool; say inventory report,
  physical stock, or container contents.
- Do not use **mana**, **points**, or **units** where a canonical physical/financial
  unit exists.
- Do not use **AI** alone. Say crew work AI, incident director, station AI,
  navigation, controller, or bot behavior.
- Do not use **level**, **floor**, or **z-level** for a remote map or station
  expansion. A floor is a tile assembly; the station has one deck.
- Do not use **task assignment** for direct player control. Say priority, policy,
  work offer, claimant, or job eligibility.
- Do not use **known** without naming who knows and the observation source.
- Do not use **crime** as a synonym for objective act. Law/policy, evidence, and
  case state are distinct.
- Do not use **open source** without qualification for the bundled Goon-derived
  distribution; use public-source/source-available and state the noncommercial
  ShareAlike terms.
