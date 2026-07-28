# Content and balancing contracts

## Content is the game

The base game is loaded as `org.simstation.core` through the same definition and
hook surfaces available to mods. Core code implements reusable mechanics;
definitions supply station-specific gases, materials, items, recipes, jobs,
thoughts, incidents, policies, sprites, sounds, and strings.

Core code may special-case only:

- canonical units and deterministic ordering;
- ownership/lifecycle invariants;
- safety/security boundaries;
- schema dispatch and migration;
- system algorithms documented in this suite; and
- engine fallbacks required to load/report invalid content.

It may not switch on a specific core item, job, material, crop, reagent, incident,
or sprite ID to create gameplay behavior.

## Package and definition layout

A content pack declares:

```toml
id = "org.simstation.core"
version = "0.1.0"
api = "0.1"
title = "Sim Station Core"
authors = ["Sim Station contributors"]
license = "CC-BY-NC-SA-3.0"
content_roots = ["content"]
locale_roots = ["locales"]
asset_manifest = "assets/manifest.json"
```

Definitions are UTF-8 JSON files. A file may contain one definition object or an
array of one kind. The path does not become the ID; moving a file does not break
saves.

Every definition begins with:

```json
{
  "id": "org.simstation.core:item/steel-sheet",
  "schema": 1,
  "name_key": "item.steel_sheet.name",
  "description_key": "item.steel_sheet.description",
  "tags": ["material-form:sheet", "material:steel"],
  "replaces": null
}
```

Rules:

- IDs are lowercase ASCII and match
  `<reverse-dns-pack-id>:<kind>/<kebab-name>`.
- IDs never encode load order, atlas coordinates, display names, or a mutable
  balance value.
- `schema` is an integer version for that definition kind.
- Unknown fields are errors unless nested beneath a schema-owned `parameters`
  object.
- References use full IDs. The core namespace has no implicit shorthand in
  serialized content.
- Data is immutable after load. Runtime state stores references to content IDs
  and the resolved content lock hash.
- `replaces` may target only a definition in a declared dependency and must
  retain kind. Load fails on implicit collision.

### Source-pinned machine definitions

Schema-2 `machine` definitions are the public contract between a physical
scenario fixture, deterministic behavior, presentation, and autonomous agents.
They declare:

- `fixture_kind` and a namespaced `behavior` contract;
- exact upstream repository, commit, type path, and reviewed source files;
- process class/tier, interval in `ds`, and callback `mult` bounds;
- power channel, idle draw, priority, state defaults, health thresholds, and
  optional four-wire harness;
- an allowlist of safe literal map overrides;
- typed actions with stable ID, handler, upstream symbol, range, duration,
  requirements, parameters, tags, and an honest `implemented` flag; and
- a fidelity profile and per-feature ledger.

Fidelity status is closed: `exact` means the observable rule and constants
match source; `deterministic-equivalent` changes implementation while retaining
the outcome; `engine-adapted` records an intentional Sim Station boundary;
`intentional-fix` identifies a cited upstream defect and tested replacement;
`deferred` exposes missing behavior instead of silently approximating it; and
`not-applicable` identifies multiplayer/round/admin behavior outside the product
contract. Runtime instances save the definition/behavior IDs, authoritative
state, process deadlines, wire mapping/effects, power/health state, and any
active action. Replacements and third-party additions pass through the same
validator and registry as the first-party definitions.

## Primitive types and expressions

Definitions use JSON null, boolean, UTF-8 string, bounded integer, array, and
object. Authoritative quantities are integers in canonical units. Decimal JSON
numbers are prohibited for authoritative fields.

Declarative conditions use a typed expression tree:

```json
{
  "all": [
    {"query": "room.pressure_pa", "op": ">=", "value": 80000},
    {"query": "machine.power_fraction_ppm", "op": ">=", "value": 900000},
    {"has_tag": {"query": "operator.certifications", "value": "chemistry-1"}}
  ]
}
```

Allowed operations are boolean `all/any/not`, integer comparison, set
membership, tag test, ID equality, and bounded arithmetic over explicitly
published query values. Conditions have no loops, function calls, clock access,
RNG, filesystem, network, mutation, or query of another system's private state.

Score/formula definitions use ordered named integer components with minimum,
maximum, multiplier in ppm, and rounding rule. Every result can produce an
explanation list.

## Tags versus capabilities

Tags classify content for search, policy, substitution, and display. A tag does
not grant behavior.

Capabilities are typed definition references validated by their owning system.
For example:

- `tool:welder` is a tag;
- an `org.simstation.core:tool-capability/welding` record with quality and fuel
  fields permits welding interactions;
- `machine-capability:smelt` selects a typed smelting capability;
- `access:medical` is validated by security's access system.

No system treats a string tag as permission to mutate state.

## Provenance and authored variants

Every definition that references imported Goon content records source provenance
through the asset/audio manifest. A gameplay definition refers only to a stable
Sim Station `SpriteId`/`AudioCue` and never to a DMI path, upstream icon state,
atlas page, or raw sound filename.

Presentation variants include:

- normal, high-contrast, and symbolic sprites;
- animation/static alternatives;
- normal/low-gore/low-fluid variants;
- caption keys and gameplay-audio category;
- palette roles and noncolor overlay patterns.

Missing critical alternatives fail release validation. Development mode may use
an engine placeholder with a diagnostic.

## Localization and terminology

All player-visible text uses localization keys. English is the source locale.
Definitions may not assemble sentences from translated fragments except
number/unit formatting.

Localization supports named parameters and plural forms. A reason code maps to a
short label, full explanation, suggested actions, and codex link. Tooltips use
plain language first and may show SS13/fandom terminology as an alias.

The [glossary](13-glossary.md) is canonical. A new system term requires a glossary
entry and must not reuse an existing term with a different meaning.

## Validation phases

Content loading is transactional:

1. **Discover:** mount deterministic pack order and enumerate files.
2. **Parse:** strict TOML/JSON syntax, UTF-8, size/depth limits.
3. **Schema:** type, range, required/unknown keys, units.
4. **Resolve:** IDs, dependencies, replacements, localization, assets/audio.
5. **Graph:** recipe/stage/objective/research/task dependency cycles and
   reachability.
6. **Invariant:** conservation, bounded formulas, lifecycle, visibility,
   accessibility, saveability.
7. **Index:** construct immutable sorted indexes.
8. **Hash:** produce definition and complete content-lock hashes.
9. **Commit:** replace the active registry only if all required content passes.

Diagnostics contain severity, pack, file, JSON path, definition ID, rule, actual
value, expected constraint, and related IDs. Release builds treat warnings from
core content as errors.

Hard validation includes:

- every reference resolves to the expected kind;
- dependency graphs have no undeclared cycle;
- resources/reagents/materials/energy balance or name explicit sources/sinks;
- task/process/procedure stages define interruption and commit semantics;
- integer formulas prove bounded under declared input ranges;
- visibility does not map secret state directly to player-facing output;
- every stateful definition declares save schema and removal migration policy;
- every gameplay sound has caption metadata;
- every critical sprite uses noncolor semantic metadata;
- every incident has prerequisites, fairness, recovery, and content-toggle
  behavior; and
- every item/entity has a valid physical location/footprint representation.

## Balance ownership and change policy

Each tunable value has one owning definition and an optional design target. Other
definitions reference it rather than copy it. Examples:

| Value | Owner |
|---|---|
| crew need decay | `need` |
| task score bounds | `work_type` plus fixed core score contract |
| steel physical properties | `material/steel` |
| recipe quantities/time | `recipe` |
| machine draw/throughput | `machine` |
| wage range | `job` and `wage_policy` |
| market volatility | `market` |
| gas safety threshold | `gas_species`/`sensor_profile` |
| disease rate | `pathogen` |
| incident cost/weight | `incident` |
| grading weights | `scenario` |

Balance changes require:

1. a stated player-facing goal;
2. affected systems/cascades;
3. before/after fixture metrics;
4. deterministic replay comparison;
5. save/content-hash consequence; and
6. changelog entry when mod-visible.

No adaptive difficulty secretly changes physical constants, wages, needs, recipe
yield, or task speed. Difficulty operates through scenario resources, incident
budget/fairness, market/contracts, and disclosed score thresholds.

## Canonical vertical-slice content

The first playable scenario is `org.simstation.core:scenario/first-contract`.
It lasts one ordinary eight-hour shift and persists into a second shift after
grading.

### Starting station

The 192×192 map starts mostly empty. A compact core of roughly 2,000 usable floor
tiles contains:

- command office, data/camera core, and communications;
- one modest generator, one battery/substation, fuel, breakers, and lighting;
- life-support room with pumps, scrubber, tanks, sensors, and distribution;
- cargo dock, import/export pad, secure warehouse, and fabrication/refining bay;
- kitchen, walk-in refrigeration, dining room, small hydroponics room, toilets,
  showers, laundry, and waste/disposal;
- clinic with triage beds, scanner, basic operating area, pharmacy cabinet,
  morgue slot, and basic cloning machine;
- small science lab;
- security office, evidence storage, armory cabinet, and two-cell brig;
- shared dormitory, lockers, recreation room, maintenance corridors, emergency
  equipment, and construction access to exterior expansion.

The core begins sealed, powered, breathable, clean, and supplied. It has only one
major path for power and air distribution, insufficient redundancy, limited
production, and insufficient room/facility capacity for growth.

### Starting roster

Exactly 24 crew:

| Department | Jobs | Count |
|---|---|---:|
| Command | station director's on-station liaison/department coordinator | 1 |
| Engineering | chief engineer, 3 station engineers | 4 |
| Cargo | quartermaster, 2 miners, cargo technician/hauler | 4 |
| Service | 2 botanists, chef, 2 janitors | 5 |
| Medical | medical director/doctor, 2 doctors | 3 |
| Science | research director/scientist, scientist | 2 |
| Security | head of security/officer, 2 officers | 3 |
| General | 2 assistants cross-qualified for basic hauling | 2 |

Heads perform ordinary work within their skill set while managing department
requests. Every critical system has at least two potentially trainable operators,
but only one highly skilled head may exist.

### Starting economy and stocks

All figures are initial balancing constants, not simulation primitives:

- station cash: 180,000 credits;
- reserve: 40,000; department operating allocations total 90,000;
- forecast base payroll: approximately 42,000 per shift;
- base upkeep/fuel/import consumption: approximately 28,000 per shift;
- food/medical/life-support emergency stock: one shift at normal consumption;
- construction stock: enough for one 12×12 expansion room and its basic
  utilities, not every objective;
- generator fuel: 1.5 shifts at ordinary starting load;
- personal opening funds: 1,500 credits per crew member;
- bailout: up to 100,000 credits at 5% per-shift interest, plus reputation cost.

Exact content tables may tune individual prices/wages but must maintain:

- at least 1.5 shifts of payroll runway if the player earns no export income;
- positive cash flow when the canonical contract is fulfilled efficiently;
- recovery from one major breach/fire without forced campaign loss; and
- meaningful tradeoff between imports and local mining/manufacturing.

### Required shift arc

The scenario requires the institution to:

1. commission one sealed, powered expansion room;
2. maintain essential job coverage and pay all wages;
3. keep an edible meal available for every declared diet;
4. survey/mine or import raw material;
5. refine it and manufacture a specified replacement component;
6. export a contract quantity/quality of station product;
7. experience one seeded meteor breach followed by a plausible fire;
8. detect/evacuate/isolate/suppress, treat casualties, clean, and repair;
9. finish with a powered breathable core and no untreated critical casualty; and
10. receive a complete category grade and continue to shift two.

Incident timing is chosen from a seeded window after the expansion and production
loops are available; it is not hardcoded to a wall-clock minute.

## Content budgets

To protect low-end performance and mod diagnostics, one loaded scenario defaults
to:

| Resource | Soft budget | Hard validation/runtime limit |
|---|---:|---:|
| station tiles | 36,864 | 36,864 |
| remote map tiles loaded | 16,384 | 65,536 total |
| crew | 100 | 256 |
| active physical entities | 20,000 | 65,535 |
| item containment depth | 4 | 8 |
| gases in one mixture | 8 typical | 32 |
| reagents in one mixture | 16 typical | 64 |
| active work offers | 2,000 | 10,000 |
| active incidents | 3 | 16 |
| controller operations/tick/controller | 64 | 256 |
| relationship memories/crew | 32 | 128 |
| path candidates considered/plan | 64 | 512 |

Crossing a soft budget appears in profiling/content validation. Hard limits reject
creation or defer bounded work with a visible diagnostic; they never wrap,
truncate a save silently, or delete existing state.

## Mod/content acceptance tests

1. Load core as an ordinary first-party pack and prove no core definition relies
   on filesystem/load order or a switch statement.
2. Load data packs in randomized discovery order and produce one identical
   topological order, registry, and content hash.
3. Reject implicit ID collision, incompatible replacement, unresolved reference,
   unknown key, fractional authoritative number, unbounded formula, and
   undeclared resource source.
4. Hot-reload a valid data-only development pack transactionally; an invalid
   revision leaves the old registry active.
5. Validate every vertical-slice definition has localization, sprite/audio
   semantics, codex/reason links, save lifecycle, and accessibility variants.
6. Execute the canonical scenario through the required shift arc with all
   content fixture IDs resolved.
7. Cross every soft budget in profiling and each hard limit in a fixture; receive
   bounded behavior and actionable diagnostics.
