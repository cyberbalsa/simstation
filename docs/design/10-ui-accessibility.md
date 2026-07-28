# UI and accessibility

## Interaction, camera, tools, dashboards, and information design

### Purpose and player experience

The interface lets a director plan and understand a dense station without
turning the game into direct pawn control or an omniscient spreadsheet. Every
action previews cost and consequence; every outcome can be traced to known
causes; emergencies remain operable while paused.

### Authoritative state and units

UI state is presentation-only and excluded from simulation hashes:

- active map, camera centre/zoom, rotation fixed to north-up, and overlay stack;
- selected tile/entity/zone/blueprint/task/case/ledger object IDs;
- open windows, docking layout, sort/filter/search, expanded rows, and tutorial
  focus;
- uncommitted plan draft and undo/redo history;
- notification read/pin/snooze state;
- input bindings, UI scale, accessibility and content presentation settings.

Only committed `GameCommand`s are authoritative. A draft may contain placements,
zones, policies, budgets, schedules, production orders, or command groups. The
UI validates against its current snapshot for preview; the simulation validates
again atomically at commit.

Camera rules:

- north-up orthographic tile view;
- free pan and keyboard edge/drag pan;
- cursor-centred zoom with discrete levels from 25% to 400%;
- integer-scale nearest rendering at 100%, 200%, 300%, and 400%;
- lower zoom may aggregate icons/heatmaps but cannot hide active critical alerts;
- jump-back history records the last 16 map/position selections;
- remote maps are selected through tabs/transport links, never z-level scrolling.

Primary interaction modes:

1. inspect/select;
2. construct/demolish;
3. zone/room policy;
4. utilities;
5. work priorities;
6. logistics/production;
7. staffing/schedules;
8. emergency/security.

Right-click opens object-context information and allowed director commands, never
direct crew actions.

### Cadence and ordering

- Input samples every rendered frame.
- Draft preview queries the latest completed immutable snapshot.
- Committed commands queue for the next tick and return accepted/rejected events.
- Dashboards update from snapshots at up to 10 Hz; charts downsample older data.
- Alert aggregation runs after visible event projection each tick.
- UI animations use real time and continue while paused only where decorative.

### Player levers

The UI exposes every player authority listed in the product contract and no
others. Players can configure layouts, filters, overlays, alert rules, pause
behavior, confirmations, tool defaults, key bindings, scales, chart horizons,
and tutorial assistance.

Risky commands require a preview and confirmation when they:

- knowingly breach a pressurized boundary;
- revoke critical access or initiate lockdown;
- approve hazardous work or high-risk research;
- take debt/abandon/evacuate;
- dismiss staff or change policy with immediate legal/medical consequences; or
- overwrite a large draft selection.

The confirmation can be disabled per category except abandonment, save deletion,
or an external/destructive filesystem action.

### Autonomous behavior

The UI does not automate simulation decisions. Optional advisors inspect only
player-visible projections and propose draft policies/orders with evidence,
tradeoffs, and confidence. Accepting a proposal creates the same command as
manual input.

### Inputs, outputs, and dependencies

Inputs: render snapshots, projected knowledge, command results, events, alerts,
definitions/localization, system public queries, save/mod/content state, input,
and accessibility settings.

Outputs: draft state, commands, camera/selection, UI-only telemetry, tutorial
progress commands where authoritative, and user-facing diagnostics.

All systems expose inspectors, dashboards, overlay data, localized reason codes,
commands, and codex material through public read models.

### UI, alerts, and visibility

#### Screen layout

The default 1920×1080 layout has:

- top bar: shift clock, speed/pause, station cash, population/on-duty, primary
  objective, alert counts, and performance indicator;
- left tool rail: inspect, build, zone, utility, priorities, logistics,
  production, staffing, emergency, overlays;
- centre: station/remote-map view;
- right contextual inspector with breadcrumbs and pinned comparisons;
- bottom event/task ribbon and optional timeline;
- dockable full dashboards that pause neither the simulation nor rendering.

At smaller windows, inspectors become overlay drawers. The minimum supported
logical UI area is 1,024×640 at 100% scale; higher UI scales reduce simultaneous
panels and enable scrolling.

#### Alert model

An `AlertView` contains projected event ID, severity, category, title/body keys,
known subject/location, observed tick/source/confidence, stale state, grouping
key, recommended relevant dashboards/actions, acknowledgement, and pause rule.

Severity:

| Level | Use | Default behavior |
|---|---|---|
| info | completed work, routine report | event feed only |
| notice | emerging shortage, delayed work | badge and feed |
| warning | service failure or credible hazard | toast, sound, badge |
| critical | imminent life/station threat | toast, sound, optional auto-pause |
| emergency | mass casualty/catastrophic confirmed state | modal banner, sound, default auto-pause |

Repeated events aggregate by type/region/source and retain count/timeline. An
alert never reveals a location/subject more precise than its source observation.
Click focuses the last-known location and opens the explanation.

#### Overlays

Canonical overlays are atmosphere pressure/oxygen/temperature/gas, fire/smoke,
power, pipes, data, disposal, rooms/zones, access/security, cameras/sensors,
navigation/traffic, work/tasks, stock/logistics, cleanliness/contamination,
medical/triage, comfort/noise, agriculture, mining, and construction integrity.

At most three semantic overlays can combine. The UI supplies a legend, data age,
source/coverage, scale, unknown pattern, and conflict blending. Critical
selection/path/blueprint visuals render above overlays.

#### Explainability

Every task, policy, alert, transaction, production step, room validation, route,
medical case, security case, objective, and score line provides:

- current state;
- known inputs and their source/timestamp;
- governing definition/policy version;
- ordered rule/score contributions;
- dependency/blocking chain;
- recent related events; and
- permitted director levers.

Raw IDs and fixed-point values are available in an advanced/debug details panel,
not required for ordinary play.

### Data definitions

`ui_view`, `dashboard`, `inspector_section`, `overlay`, `alert_rule`,
`reason_code`, `advisor`, `tutorial_step`, `codex_page`, `chart_metric`,
`confirmation_category`, and `input_action`.

Definitions refer only to public read-model fields and command templates. A data
mod cannot add an unrestricted expression or arbitrary renderer call.

### Mod hooks

- `observe:ui_command_result`
- `transform:alert_projection`
- `transform:inspector_sections`
- `transform:codex_index`
- `observe:selection_changed` (presentation only)

Mods register namespaced dashboards/overlays/inspector sections through declared
schemas. Trusted code UI extensions are clearly labeled and cannot receive
objective hidden state unless also installed as trusted simulation code.

### Save fields

Campaign saves contain no ordinary UI layout. A separate profile stores
bindings, UI scale, accessibility/content settings, window layout, alert rules,
tutorial preference, and optional recent searches. A per-save presentation sidecar
may store camera, pinned panels, read alerts, and map tab; loss/corruption of it
does not affect simulation.

Authoritative tutorial/objective progress and player-issued policies live in the
campaign save through their owners.

### Failure and recovery

Stale snapshots display age and never masquerade as current. A command rejected
after draft preview keeps the draft, highlights changed prerequisites, and
spends nothing. Missing localization falls back to content ID and logs a
diagnostic. A faulty mod panel is disabled without stopping simulation unless it
also caused a state-critical trusted hook failure.

If rendering falls behind, the UI reduces particles/chart sampling/animation and
shows performance state; it does not drop simulation ticks. If simulation falls
behind selected speed, wall-clock advancement slows and the player can lower
speed.

### Feature stages

- **Proof:** camera/zoom, select/inspect, speed, command draft/result, core
  overlays, performance HUD and debug explanations.
- **Vertical slice:** complete tools and dashboards for every slice system,
  alert grouping/auto-pause, codex/tutorial, shift report.
- **1.0:** full docking/custom layouts, advisors, histories, advanced filters,
  remote-map and campaign interfaces.
- **Deferred:** mobile/touch-first interface and direct crew-control scheme.

### Acceptance tests

1. Complete the canonical vertical-slice shift using UI commands only; no debug
   or direct entity action is required.
2. Draft a large build, let state change, commit, and receive atomic rejection
   with preserved editable draft.
3. Cut camera/data/sensor access and verify overlays, inspectors, alerts, and
   advisor suggestions all obey the same knowledge projection.
4. Generate 1,000 similar alerts and verify deterministic grouping, bounded UI
   work, retained timeline, and no critical alert loss.
5. At 1,024×640 and 200% UI scale, reach every command and read every confirmation
   without clipped controls.
6. Navigate the complete UI with keyboard only, including map focus, tool
   operation, inspectors, tables, mod manager, and shift report.
7. Disable a faulty mod panel and continue/safely save the simulation.

## Accessibility and presentation safety

### Purpose and player experience

Accessibility is a system-wide contract, not a post-process. Mechanically
important state must be perceivable without relying on one color, sound, motion,
fine pointer gesture, rapid response, gore image, or domain-specific jargon.

### Authoritative state and units

Accessibility state is profile-only presentation configuration:

- UI scale and font scale;
- color-vision palette and contrast theme;
- reduced motion, screen shake, flashes, particles, and camera movement;
- subtitle/caption detail and directional sound indicators;
- alert sound/visual/haptic-equivalent configuration;
- key bindings, toggle/hold behavior, drag alternatives, repeat rate;
- pause-on-alert and planning assistance;
- gore, fluid, drug/substance, crude-language, and death-detail settings; and
- reading level: concise, standard, or expanded explanation.

These settings never alter simulation state, RNG, timing, difficulty, score, or
mod compatibility. Scenario content filters selected before start may exclude an
incident/content definition; presentation toggles during play only replace its
representation.

### Cadence and ordering

Settings apply immediately to presentation. Input-binding conflicts validate
before commit. Content-filter compatibility validates at scenario start and mod
load. Captions and directional indicators consume projected audio/event cues at
render cadence.

### Player levers

Every listed setting is independently controllable with preview and reset.
Presets—default, high contrast, low motion, audio-light, keyboard-only, low-gore,
and simplified reading—apply a visible group of ordinary settings and remain
editable.

### Autonomous behavior

The presentation layer chooses definition-supplied alternatives:

- color plus icon/pattern/label;
- sound plus caption/directional marker;
- animation plus static state indicator;
- gore/fluid image plus clinical/symbolic image;
- jargon label plus codex-linked plain-language description.

It never infers an alternative by hiding the object/effect.

### Inputs, outputs, and dependencies

Inputs: event/alert/audio/render projections, UI definitions, localization,
content metadata, input devices, and user profile.

Outputs: selected visual/audio/string variants, layout/scaling, captions,
directional indicators, pause presentation commands, and validation diagnostics.

Every content-producing system must provide semantic state independent of
appearance/sound.

### UI, alerts, and visibility

- Color encodes no unique state; overlays use pattern/shape/icon and text legend.
- Focus order is deterministic and visible. Modal focus is trapped and restored.
- All buttons have labels/tooltips accessible without hover.
- Tables have keyboard navigation, sortable header state, and row summaries.
- Drag operations have start/end keyboard or click alternatives.
- Time-sensitive decisions permit pause except explicit scenario rules disclosed
  before start; ordinary UI animation never imposes a deadline.
- Captions identify cue class, localized text, known direction/distance band, and
  source if knowledge permits.
- Text contrast targets WCAG 2.2 AA (4.5:1 normal, 3:1 large/UI graphics).
- UI supports 100–200% scale without loss; fonts are not embedded in raster art.
- Flashing never exceeds three flashes per second in default or reduced-flash
  modes; a static alternative always exists.

### Data definitions

All visual/audio/content definitions include:

- semantic state and category;
- normal and high-contrast palette role;
- icon/pattern fallback;
- motion/static variants where animated;
- caption key and urgency for gameplay audio;
- gore/fluid/substance/language/death-detail classification;
- alternate sprite/string/audio behavior for each applicable classification;
- codex terminology link.

Validation fails release content that communicates a critical state through
color, audio, animation, or mature imagery alone.

### Mod hooks

- `validate:accessibility_metadata`
- `transform:presentation_variant`
- `observe:accessibility_setting_changed` (profile/presentation only)

Mods must provide the same metadata. A mod may declare itself incompatible with
a pre-game content filter, but runtime mechanical content may not disappear
because a presentation alternative is missing; the engine uses symbolic
fallbacks and reports the mod.

### Save fields

Save profile settings, bindings, per-mod accessibility acknowledgements, and
preset provenance outside campaign state. Campaign header records scenario
content-filter choices because they affect loaded content; presentation toggles
do not.

### Failure and recovery

Missing alternatives use engine-provided high-contrast placeholder/icon, generic
caption, and raw localized description. Invalid bindings retain the prior
mapping. Unsupported device input falls back to keyboard/mouse and reports it.
No accessibility failure may corrupt or alter campaign state.

### Feature stages

- **Proof:** scalable UI, remapping, color-independent overlay, reduced motion,
  captions and symbolic gore fallback.
- **Vertical slice:** keyboard-only operation, all content toggles, alert
  alternatives, high contrast, screen-shake/flash controls, plain-language codex.
- **1.0:** complete audit of every definition, narrator/screen-reader-friendly
  semantic export where platform support permits, more presets and controller
  support.
- **Deferred:** mobile accessibility and platform-native APIs unavailable in
  LÖVE without portable support.

### Acceptance tests

1. Automated content validation proves every critical appearance/audio cue has
   required semantic alternatives.
2. Complete canonical emergency response with game audio muted and no color
   distinctions.
3. Complete all player-authorized operations keyboard-only with no pointer drag.
4. Toggle gore, fluids, substances, language, motion, flashes, and captions
   mid-incident; state hash and mechanical alerts remain identical.
5. Snapshot every dashboard at supported UI/font scales and minimum resolution
   for clipping/focus-order review.
6. Install an incomplete mod and verify symbolic/caption fallbacks plus precise
   validation warnings, with no hidden hazard.
