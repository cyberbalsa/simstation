# Product contract

## Identity and design pillars

“Sim Station” is the development codename for a single-player station-management
game inspired by the systems and visual language of Goonstation/SS13. A release
name must be selected before public store pages because another station-building
game already uses SimStation.

The game has five non-negotiable pillars:

1. **Indirect authority.** The player changes conditions, priorities, staffing,
   budgets, policies, and emergency posture. Crew decide how to carry out work.
2. **Legible systemic causality.** Disasters emerge from ordinary rules. The UI
   lets a player reconstruct why a result occurred without granting
   out-of-world omniscience.
3. **Detailed people in a working institution.** Forty to one hundred named crew
   have bodies, jobs, needs, relationships, possessions, wages, knowledge, and
   personal reactions to station policy.
4. **Serious rules, absurd outcomes.** The simulation is internally consistent;
   humor comes from combinations, personalities, bureaucracy, and physical
   consequences rather than arbitrary joke buttons.
5. **Mod-first source availability.** The base game uses the same public content
   and hook interfaces as mods. Desktop portability and maintainability take
   priority over engine-specific cleverness.

## Player fantasy and authority

The player is the station director operating through a command-and-control
interface. They may:

- lay construction, demolition, and furnishing blueprints;
- define rooms, stockpiles, access zones, evacuation areas, and departmental
  ownership;
- recruit, dismiss, schedule, promote, and assign jobs;
- set department and station budgets, wages, procurement limits, export goals,
  and service pricing;
- publish work priorities, standing orders, safety policies, access policies,
  arrest policies, medical rules, and research risk tolerances;
- configure production orders, logistics routes, utility priorities, automation,
  sensors, alarms, and maintenance thresholds;
- inspect any state that the station has measured, recorded, or received as a
  report;
- issue emergency declarations, evacuation orders, quarantines, lockdowns, and
  requests for external aid; and
- pause or run the simulation at 1×, 2×, or 4×.

The player may not:

- select a crew member and issue a movement or action order;
- possess a crew member, fire a weapon through them, or directly operate a
  machine that requires an in-world operator;
- read secret motives, unreported crimes, undiscovered diseases, or unseen map
  state;
- create resources without a scenario rule, bailout, or explicit debug mode; or
- bypass permissions by using a director-only supernatural interaction.

Emergency orders remain indirect. For example, marking a fire response zone
raises eligible emergency tasks and changes access/safety policy; it does not
teleport firefighters or force an incapacitated engineer to respond.

## Audience and onboarding

The primary audience includes both management-sim newcomers and experienced SS13
players. Familiar jargon is retained only where it is useful and is always
defined in the codex.

The first campaign teaches one system at a time through:

- a small, stable starting core;
- contextual objectives with no time limit while paused;
- “why” explanations on tasks, refusals, alerts, and ledger entries;
- overlay legends and inspectable formulas;
- suggested policies that can be accepted or edited; and
- a searchable codex populated from the same definitions used by the
  simulation.

Advanced players can disable tutorial goals, reduce explanatory pauses, expose
raw values, and start from higher-risk scenarios.

## World and scale

- The station has exactly one permanent 192×192 tile deck.
- Tiles are logically 32×32 pixels, though simulation coordinates are independent
  of rendering.
- Mining zones, debris fields, derelicts, and expedition sites are separate
  single-plane remote maps linked by transport. They are not stacked station
  levels and cannot carry station utility networks across map boundaries.
- The intended mature population is 40–100 crew. The vertical slice uses about
  24 so every important profession is observable.
- A normal campaign starts with a small powered, pressurized, furnished core,
  basic supplies, a modest staff, and limited cash. Expansion is required but
  the opening is not a survival countdown.

## Time and campaign structure

An in-world shift lasts eight hours, or 28,800 simulation seconds. At 1× the
engine advances ten simulation seconds per real second, so an uninterrupted
shift lasts about 48 real minutes.

- The authoritative tick is one in-world second.
- 1× processes 10 ticks per real second, 2× processes 20, and 4× processes 40.
- Pause processes no simulation ticks but permits camera, inspection, planning,
  budgeting, and queued commands.
- Commands are applied at the next tick boundary in deterministic order.
- A campaign persists across shifts. Crew age slowly, retain memories and
  injuries, draw wages, build relationships, and carry possessions subject to
  station policy.
- Shift boundaries produce payroll, financial statements, performance grades,
  contract updates, staffing decisions, maintenance forecasts, and autosaves;
  they do not reset the physical station.

## Core gameplay loop

The primary loop is:

1. **Inspect:** read objectives, reports, demand forecasts, staffing, stores,
   utilities, and risks.
2. **Plan:** place blueprints, zones, schedules, policies, budgets, requisitions,
   production orders, and maintenance thresholds.
3. **Commit:** approve spending and let autonomous crews reserve materials,
   perform work, and operate services.
4. **Observe:** follow physical flows, task queues, needs, ledgers, sensors, and
   social consequences.
5. **Respond:** change priorities, isolate hazards, ration resources, authorize
   overtime, call aid, evacuate, or accept losses.
6. **Recover:** treat people, clean contamination, repair infrastructure,
   investigate causes, repay debt, and revise policy.
7. **Evaluate:** receive a shift report, fulfill contracts, unlock options, and
   begin the next shift with the same station and crew.

No subsystem is allowed to terminate at “the player clicks the machine.” Every
input must become work, logistics, policy, or an autonomous machine action.

## Information and uncertainty

The simulation stores objective truth, but the player interface projects only
what the station could know.

Information has one of five visibility states:

| State | Meaning |
|---|---|
| `direct` | Currently visible to an operational camera or approved direct sensor |
| `measured` | Reported by a sensor with a timestamp, accuracy, and possible fault |
| `reported` | Asserted by a crew member or external message and may be incomplete |
| `inferred` | Computed from known observations and explicitly labeled as an estimate |
| `unknown` | Not shown or replaced with a question/last-known state |

Physical state such as pressure, temperature, fire, machine faults, and visible
injury becomes available through cameras, sensors, alarms, or crew reports.
Private traits are visible only if part of an authorized personnel record.
Secret motives, concealed contraband, unreported crimes, and future incident
rolls remain hidden. Debug omniscience is restricted to developer mode and marks
the save as debug-modified.

## Tone and content controls

The default tone allows mature cartoon gore, surgery, drugs, alcohol, cloning
failures, bodily fluids, death, and crude humor. It excludes sexual violence,
real-world hate propaganda, and content whose only purpose is cruelty toward a
protected group.

Independent settings control:

- gore detail and dismemberment visuals;
- blood and other bodily-fluid decals;
- drug names and substance references;
- crude language;
- flashing effects, screen shake, and high-contrast alarms; and
- death and medical-event notification detail.

Settings change presentation, strings, and optional cosmetic effects, never
simulation balance. A low-gore setting still conveys bleeding and contamination
with readable symbols.

## Success, failure, and recovery

The game evaluates station outcomes on safety, crew welfare, financial
sustainability, service delivery, contract performance, research, security, and
recovery. It does not have one universal win state.

By default, catastrophic situations create recovery choices:

- emergency credit with interest and future budget pressure;
- emergency supply drops with limited selection;
- external rescue or partial evacuation;
- temporary contractors;
- insurance payouts subject to evidence and deductible;
- salvage and reconstruction; or
- abandoning the current station and carrying campaign reputation/unlocks into a
  new scenario.

Hard-failure scenarios may end on total population loss, unrecoverable insolvency,
or an objective-specific condition, but must declare that behavior before play.
Normal campaigns never silently delete a station.

## Platform, performance, and maintainability

- Desktop targets are Windows, Linux, and macOS using LÖVE 11.5 and pure Lua
  runtime dependencies.
- The reference floor is a 2020-era low-end quad-core CPU, integrated GPU, and
  8 GiB RAM.
- A 192×192 station with 100 crew must render at 60 FPS at 1× and remain
  responsive at 30 FPS or better at 4× under the standard disaster benchmark.
- Determinism, clear schemas, small modules, content-driven definitions, and
  end-to-end tests take priority over premature micro-optimization.
- Multiplayer, mobile, browser, consoles, a second station deck, and mandatory
  FFI/native libraries are outside the 1.0 architecture.

## Feature boundaries

The vertical slice contains construction, atmosphere, power, life support,
mining/imports, refining/manufacturing, jobs, wages, food, exports, fire/breach
response, treatment, cleaning, repair, and shift grading.

The full 1.0 simulation adds detailed surgery/anatomy, chemistry, diseases,
ranching, artifacts, genetics, advanced forensics, richer robotics, and broad
campaign/scenario content.

Hidden antagonists, station-AI law politics, deep programmable automation,
telescience, and similarly adversarial or highly programmable systems are
post-1.0. Interfaces reserve their needs, but 1.0 does not balance around them.

## Product acceptance scenarios

1. A new player completes one shift using suggestions and can explain why a
   workshop stalled, why a crew member refused a task, and why a room lost air.
2. An experienced SS13 player can inspect atmosphere, access, anatomy, reagents,
   logistics, and utility networks without the systems being cosmetically
   simplified.
3. A meteor breach causes a traceable chain through pressure, fire risk,
   injuries, labor availability, production delay, finances, and morale.
4. The player recovers from the chain using policies and priorities without
   directly moving or commanding a pawn.
5. A private crime remains unknown until a camera, witness, sensor, inventory
   check, or forensic process creates evidence.
6. Content toggles preserve every mechanically relevant warning and status.
