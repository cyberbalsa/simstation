# Design specification index

These documents define the complete target game and the smaller vertical slice
used to prove it. Each system specification uses the same headings so it can be
implemented, tested, serialized, and extended without rediscovering design
intent.

## Normative documents

| Document | Responsibility |
|---|---|
| [Product contract](00-product-contract.md) | Audience, fantasy, scope, player authority, campaign, tone, performance, and content boundaries |
| [Simulation foundations](01-simulation-foundations.md) | Time, units, IDs, deterministic ordering, commands, events, visibility, common data rules |
| [World and construction](02-world-construction.md) | Maps, tiles, rooms, zones, blueprints, building, demolition, and commissioning |
| [Atmosphere, fire, power, and utilities](03-environment-utilities.md) | Gas, heat, breaches, fire, electrical networks, pipes, disposal, and data networks |
| [Crew, jobs, work AI, and navigation](04-crew-work.md) | People, needs, health overview, employment, schedules, tasks, reservations, autonomy, and pathing |
| [Items, logistics, economy, mining, and manufacturing](05-industry-economy.md) | Materials, inventory, hauling, accounts, trade, extraction, recipes, and production |
| [Food, service, and sanitation](06-service-life.md) | Farming, ranching, cooking, nutrition, recreation, cleaning, waste, laundry, and pests |
| [Medicine and chemistry](07-medical-chemistry.md) | Anatomy, damage, treatment, surgery, cloning, disease, reagents, and reactions |
| [Science, automation, and security](08-science-security.md) | Research, artifacts, genetics, robotics, control logic, station AI, law, evidence, and detention |
| [Incidents and progression](09-incidents-progression.md) | Threat director, scenario objectives, shift grading, campaign unlocks, recovery, and end states |
| [UI and accessibility](10-ui-accessibility.md) | Camera, tools, dashboards, alerts, overlays, codex, input, content controls, and accessibility |
| [Content and balancing contracts](11-content-contracts.md) | Definition shapes, validation, balance ownership, localization, and content authoring rules |
| [Cross-system matrix](12-cross-system-matrix.md) | Dependency ownership, canonical events, cascade paths, and feature-stage coverage |
| [Glossary](13-glossary.md) | Canonical terms, units, state names, and prohibited ambiguities |

## Required system-specification fields

Every independently scheduled system must specify:

- purpose and player experience;
- authoritative state and units;
- cadence and ordering;
- player levers;
- autonomous behavior;
- inputs, outputs, and dependencies;
- UI, alerts, and information visibility;
- content/data definitions;
- mod hooks;
- save fields;
- failure and recovery behavior;
- vertical-slice, full-game, and deferred scope; and
- deterministic acceptance tests.

The documents below deliberately repeat these headings. That repetition is a
contract, not an editing accident.

## Feature stages

- **Proof:** engineering benchmark and test fixtures, not a balanced game.
- **Vertical slice:** one complete eight-hour shift with about 24 crew and all
  primary station loops represented.
- **1.0:** the complete non-antagonist station simulation for 40–100 crew.
- **Post-1.0:** hidden antagonists, full station-AI law politics, advanced
  programmable automation, and other explicitly deferred depth.

Content may be present before its stage, but its public hooks and save fields
must not be treated as stable until that stage begins.
