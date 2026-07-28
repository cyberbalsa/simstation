# Roadmap and milestone gates

## M0 — Decision-complete documentation

Deliver product, system, technical, modding, production, legal, and agent
research documents. Build the system dependency matrix and glossary.

Exit:

- every planned domain has state, units, cadence, player controls, interfaces,
  visibility, failure/recovery, save/mod rules, and tests;
- cross-system inputs/outputs each have one owner;
- graphics/audio imports, rights risk, and release classification are explicit;
- no unresolved implementation choice blocks M1.

## M1 — Deterministic foundation

Deliver the LÖVE scaffold, pure-Lua core facade, scheduler, stable IDs/RNG,
command/event contracts, canonical serializer/hash, save envelope, registry,
data-only mod loader, minimal UI adapter, and headless tests.

Exit:

- seeded command fixture matches hashes across all desktop targets;
- base content travels through the ordinary mod loader;
- save/reload/replay and one schema migration pass;
- public examples are fixtures;
- `audit` is the mandatory CI/handoff gate.

The existing bootstrap is an early M1 subset. Its abbreviated public shapes
must be upgraded before M1 exit.

## M2 — Complete media fork and presentation proof

Import the pinned full graphics/audio corpora, create editable mappings,
provenance, asset compilers, compiled bundles, renderer, audio manager, and
credits/legal UI.

Exit:

- canonical importer inventories reconcile source counts;
- all DMI cells pixel/semantic-verify and deterministic atlas hashes reproduce;
- all audio validates/decodes, Ogg copies retain hashes, tracker conversions
  reproduce, and rights blockers are resolved under policy;
- 16×16 dirty batches, composited dynamic appearances, lazy eight-page
  residency, 96 MiB audio cache, 64-voice policy, captions, and device-loss
  recovery pass;
- no runtime DMI or tracker dependency.

## M3 — 100-crew technical simulation proof

Implement minimal dense atmosphere/fire, power, room graph, hierarchical
navigation, work/reservations, crew movement/needs, snapshot renderer, remote
map coarse scheduling, and profiler/benchmark harness with synthetic content.

Exit:

- 192×192/100-crew nominal and disaster benchmarks meet 1×/4× targets;
- topology/atmos/power dirty invalidation is bounded and deterministic;
- headless, rendered, and audio-enabled runs share hashes;
- 30-shift synthetic soak has no unbounded growth.

This is a technical proof, not player-facing content polish.

## M4 — Playable vertical slice

Implement the complete [bootstrap contract](01-vertical-slice.md), including
economy, jobs, logistics, manufacturing, food, medical, research, security,
incidents, recovery, dashboards, tutorial, saves, and four example mods.

Exit:

- acceptance shift and recovery variants pass;
- all system contracts and accessibility requirements are implemented;
- new-player and veteran playtests confirm the full loop is legible;
- packages install and run offline on the supported matrix.

## M5 — Systems alpha

Expand depth while retaining one station plane:

- chemistry/reactions and deeper medicine/anatomy/surgery;
- diseases, cloning/prosthetics, genetics;
- agriculture/ranching/cooking/sanitation;
- material quality, multi-stage manufacturing, markets/contracts;
- evidence/forensics/security law;
- artifacts, robotics/bots, station AI and declarative automation;
- advanced utility machinery/pipes and remote expeditions.

Exit:

- every planned 1.0 system is feature-complete with placeholder-balanced
  content;
- cross-system cascade and recovery test suite passes;
- 40–100 crew campaigns sustain 30 shifts;
- no save/mod API blocker remains unversioned.

Hidden antagonists and unrestricted automation remain disabled.

## M6 — Content beta

Expand jobs, items, recipes, machines, incidents, scenarios, remote sectors,
research, events, audio usage, appearance composition, tutorials, codex, and
content/accessibility settings. Tune economy, staffing, threat, and recovery.

Exit:

- no placeholder UI/content in the normal campaign;
- all imported media used or intentionally classified as library-only;
- onboarding and advanced overlays pass usability tests;
- performance, memory, save size, and package size meet budgets;
- only fixes, balance, content, and documented compatibility work remain.

## M7 — Hidden-antagonist update

After ordinary incidents and security knowledge are stable, add optional hidden
antagonists:

- secret motives/objectives and opportunity-based autonomous behavior;
- evidence/witness/report discovery without director omniscience;
- security investigation and containment;
- storyteller constraints preventing unwinnable or repetitive assignments;
- scenario/content toggle independent from gore/substance settings.

Exit:

- turning antagonists off produces no hidden residual behavior;
- deterministic secret-state tests prove knowledge boundaries;
- player can diagnose through evidence without meta UI leakage;
- ordinary station simulation remains the primary game.

This may ship after 1.0 if it threatens core stability; its interfaces are
reserved but not required for the initial vertical slice.

## M8 — 1.0 hardening

Freeze public API 1.0; finalize migrations, mod authoring docs, compatibility
fixtures, translations, accessibility, performance, packaging, provenance,
credits, naming clearance, security/fuzzing, and recovery support.

Exit:

- all release gates pass on exact artifacts;
- saves from the supported pre-release window migrate on copies;
- API/data/asset/audio schemas and example mods are stable;
- 30-shift campaign and full benchmark suite pass;
- public product name has clearance; “Sim Station” remains only if approved;
- no critical/high defect, rights blocker, or unexplained packaged file remains.

## Explicit 1.0 exclusions

- multiplayer/network simulation;
- direct crew possession or pawn-by-pawn orders;
- multiple station decks/Z-levels;
- mobile, browser, console, or 32-bit packages;
- required native/FFI plugins or mandatory GPU-specific assets;
- automatic mod downloads/workshop;
- automatic Goonstation synchronization;
- commercial distribution of the Goon-derived package.

An excluded feature requires a revised product/technical plan; it cannot enter
through an incidental implementation change.
