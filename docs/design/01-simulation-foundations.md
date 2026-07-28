# Simulation foundations

## Authoritative time

The simulation uses a fixed authoritative tick called a `tick`. One tick equals
one in-world second. `tick_id` is an unsigned 64-bit-equivalent integer represented
within Lua's exact integer range and starts at zero for a new campaign.

At 1× the scheduler processes ten ticks per real second. At 2× it processes
twenty and at 4× forty. It may render between ticks, but it may never use a larger
simulation step or skip work to catch up. If the device cannot sustain the
selected rate, the game slows wall-clock advancement and displays a performance
warning rather than changing results.

Cadence notation in these documents means:

| Notation | Interval | Typical use |
|---|---:|---|
| `1t` | 1 in-world second | movement, doors, reservations, immediate injury |
| `2t` | 2 seconds | active atmosphere and fire |
| `5t` | 5 seconds | utility control, urgent needs, hazard replanning |
| `10t` | 10 seconds | normal work planning, machine cycles |
| `30t` | 30 seconds | room environment, sanitation, social observations |
| `60t` | 1 minute | needs, wages accrual, markets, low-risk planning |
| `300t` | 5 minutes | maintenance forecast, disease progression |
| `shift` | 28,800 ticks | payroll settlement, grading, contract rotation |

Systems execute in this order within a tick:

1. validate and commit queued `GameCommand`s;
2. update topology and spatial indexes;
3. reserve/release resources and choose work;
4. perform movement, doors, and immediate interactions;
5. update utilities, atmosphere, heat, fire, and machines due this tick;
6. update items, reagents, health, needs, and sanitation due this tick;
7. update knowledge, security, incidents, economy, and progression;
8. finalize ordered `SimEvent`s;
9. compute visibility projections, alerts, and render snapshot;
10. compute the deterministic state hash when scheduled.

No scheduled system may read partially committed output from a later stage.

## Canonical units

Authoritative state avoids binary floating-point where a value affects outcomes.

| Quantity | Unit and representation |
|---|---|
| Position | integer `map_id`, tile `x`, tile `y`; optional pixel offset in 1/256 tile |
| Time | integer ticks; durations are integer ticks |
| Money | integer credits in hundredths (`cr¢`) |
| Mass | integer grams (`g`) |
| Material quantity | integer grams; indivisible parts use integer count |
| Liquid/reagent volume | integer millilitres (`mL`) |
| Gas quantity | integer millimoles (`mmol`) per species |
| Temperature | integer millikelvin (`mK`) |
| Pressure | integer pascals (`Pa`), derived from gas/temperature/volume |
| Energy | integer joules (`J`) |
| Power | integer watts (`W`) |
| Distance | integer tiles for path costs; diagonal steps cost 1,414 milli-tiles |
| Health/damage | integer milli-damage; UI normally rounds to 0.1 |
| Nutrition | integer kilojoules (`kJ`) |
| Contamination | integer micro-units per tile/item/body surface |
| Probability | integer parts per million (`ppm`) |
| Color/tint | integer RGBA channels plus fixed-point color-matrix entries |

Rounded derived UI values never feed back into the simulation. Division specifies
a rule: nonnegative quantities round down unless the owning system explicitly
uses round-to-nearest, ties to even.

## IDs and ownership

Content uses `ContentId`:

```text
<reverse-dns-pack-id>:<kind>/<name>
org.simstation.core:item/steel-sheet
org.simstation.core:job/station-engineer
```

Runtime objects receive monotonic 64-bit `EntityId`s. IDs are never reused within
a campaign. Rooms, networks, tasks, incidents, accounts, evidence, reports, and
transactions have separate monotonic IDs with type-prefixed serialized forms.

Every piece of authoritative state has one owner system. Other systems receive a
read-only query or an ordered event. Shared mutable tables are forbidden.

## Commands

A `GameCommand` is the only path from UI/mod input to authoritative state:

```text
command_id
issuer
issued_at_tick
apply_at_tick
command_type
schema_version
payload
```

Commands queued while paused use the next tick. At a boundary they order by
`apply_at_tick`, issuer class (`scenario`, `player`, `trusted_mod`, `debug`),
`command_id`, then reject or commit atomically. Rejection emits a visible reason
and never partially spends resources or changes state.

Policies, blueprints, budgets, priorities, schedules, and emergency declarations
are commands. Inspecting state, moving the camera, opening windows, and drafting
uncommitted plans are not.

## Events

A `SimEvent` is an immutable fact:

```text
event_id
tick
event_type
source_id?
target_ids[]
map_id?
position?
severity
visibility_class
payload
```

Events order by tick, owning-system order, source ID, then system-local sequence.
They drive reports, alerts, sounds, animation, achievements, incident conditions,
and observe hooks. Consumers may not alter or cancel an event after emission.

Events are facts, not automatically player knowledge. `visibility_class` and
evidence observations determine projection.

## Randomness and determinism

The campaign stores a root seed. Each domain derives named streams from
`root_seed + stable_stream_name`, including `incident`, `crew_generation`,
`medical`, `machine_failure`, `agriculture`, and `market`.

- Streams serialize complete state.
- A system uses only its named stream.
- Entity-local variation derives from stream name plus stable entity/event ID
  where possible, so iteration count changes do not perturb unrelated outcomes.
- UI, rendering, particles, and audio variants never consume simulation RNG.
- Every authoritative collection has an explicit sort before outcome-dependent
  iteration.

The simulation writes a state hash every 600 ticks and at save/shift boundaries.

## Visibility, knowledge, and reports

Objective state remains in the owning system. The knowledge service stores
observations:

```text
subject_ref
fact_type
value_or_range
observed_tick
source_type
source_ref
confidence_ppm
expires_or_stales_tick?
access_scope
```

Sources include cameras, meters, alarms, machine diagnostics, crew reports,
medical records, manifests, transaction logs, and forensic evidence.

Direct camera visibility requires an operational camera, power/data route, clear
coverage, and player authorization. Sensors publish measurements at their own
cadence and accuracy. Crew reports require perception, knowledge, willingness,
and an available communication route. Last-known information remains timestamped
and visually stale.

Mods querying state through player-facing APIs receive the same knowledge
projection unless explicitly declared as trusted simulation code.

## Priorities and policies

Priorities are integer levels:

| Level | Meaning |
|---:|---|
| 0 | disabled; do not generate ordinary work |
| 1 | low/background |
| 2 | normal |
| 3 | high |
| 4 | urgent |
| 5 | emergency; may invoke emergency policy exceptions |

Priority never guarantees action. Safety, legal policy, access, skill, needs,
equipment, reservations, and reachability remain constraints. Emergency
exceptions are individually configurable and always create an audit event.

Policies are versioned immutable snapshots. Tasks record the policy version under
which they were created and reevaluate at safe boundaries after a policy change.

## Shared lifecycle rules

Physical objects use `planned → reserved → under_construction → operational →
disabled/damaged → deconstructed/destroyed`. Work uses the lifecycle defined in
the work-AI document. Accounts are append-only ledgers with derived balances.
Knowledge is append/update by observation. Definitions are immutable after
content load.

Deletion is represented by tombstones until all current-tick references and save
migrations are resolved. Destruction emits an event, releases reservations, and
preserves ledger/evidence references.

## Common data-definition header

Every JSON definition includes:

```json
{
  "id": "org.example.pack:kind/name",
  "schema": 1,
  "name_key": "content.kind.name",
  "description_key": "content.kind.description",
  "tags": [],
  "replaces": null
}
```

Definitions reject unknown keys by default. Extensible `parameters` objects must
name their schema owner. References must resolve after deterministic mod loading.
Content values use canonical units and never embed executable Lua.

## Common mod-hook rules

Systems may expose:

- `observe:*` after an immutable event;
- `validate:*` before a command or state transition, returning allow/deny and a
  localized reason;
- `transform:*` for an explicitly documented value pipeline.

Transform handlers execute in dependency order, priority, mod ID, registration
sequence. Each receives immutable input and returns a replacement value. Hooks
cannot retain internal tables, yield, invoke UI, or consume another system's RNG.

Data mods can add definitions and explicit replacements. Trusted code mods may
register hooks after a warning and restart. A failed validator/transformer aborts
the operation; a failed observer is disabled for the session and reported.

## Common save rules

Every system saves:

- its schema version;
- monotonic ID counters;
- authoritative state not derivable from definitions or other saved state;
- scheduled future actions with absolute tick;
- active reservations and owners;
- named RNG state if owned by the system; and
- references by stable ID, never Lua table identity.

Caches, paths, render batches, UI selections, audio sources, and derived indexes
are rebuilt. Saves occur only at a completed tick boundary.

## Common specification checklist

The remaining system documents define all of the following. An implementation is
incomplete if any field is omitted:

1. purpose and experience;
2. state and units;
3. cadence and ordering;
4. player levers;
5. autonomous behavior;
6. inputs, outputs, dependencies;
7. UI, alerts, visibility;
8. data definitions;
9. mod hooks;
10. save fields;
11. failures and recovery;
12. proof/slice/1.0/deferred scope;
13. deterministic acceptance tests.

## Foundation acceptance tests

- The same seed, content lock, and command journal produce identical 600-tick
  hashes over 30 shifts across supported desktop platforms.
- Pause permits plan edits but advances no IDs, timers, RNG, needs, ledgers, or
  world state.
- 1×, 2×, and 4× produce identical state after the same number of processed
  ticks.
- Two commands targeting one resource resolve in documented order; the loser is
  rejected without partial mutation.
- A camera outage turns direct facts into timestamped last-known values without
  revealing later state.
- A UI/audio/rendering change cannot alter a simulation state hash.
- Unknown definition fields, unresolved IDs, invalid units, and duplicate IDs
  fail content loading with file, JSON path, and owning mod.
