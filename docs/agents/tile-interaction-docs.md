# Tile interaction fidelity documentation agent

## Record

- Canonical task: `/root/machine_docs_renderer`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible work report
- Assignment availability: verbatim

### Assignment

> New bounded task: research and document a source-pinned Goonstation
> interaction/tile fidelity contract. Cover turf/structure interaction
> precedence, hand/tool verbs, construction/deconstruction, damage/breach,
> doors/windows/grilles/tables/lights, click/attack/afterattack semantics, NPC
> affordance representation, rendering layers/directions/variants, and what is
> exact/adapted/deferred. Inspect current repo and upstream source. Write/update
> `docs/technical/10-goon-world-interaction-fidelity.md` plus indices. Save a
> full agent report/state/conversation summary at
> `docs/agents/tile-interaction-docs.md` and update docs/agents README/manifest
> entries for your report. Do not edit core Lua or tests. Validate links/diff.

## Renderer follow-up assignment

> Renderer expansion has landed. Please update tech10's presentation ledger
> from the old floor/wall-only statement to the exact current state: 29
> foundation sprite aliases; native plating/reinforced floor+wall,
> windows/grilles, table/chair, light, storage/crate, lattice/catwalk,
> pipe/disposal, sign/decal; chunk/page SpriteBatch grouping; 32px source
> cells; physical-pixel `usedpiscale=false`; discrete 0.25/0.5/1/2/4 zoom with
> display-pixel camera snapping; top-bar-excluded scissored viewport and
> resize/mouse mapping. Record this follow-up in your existing
> docs/agents/tile-interaction-docs.md and validate docs. Do not edit
> production code.

### Observable chronology

1. The agent announced that it was tracing pinned Goon click dispatch,
   construction state machines, and appearance contracts against the current
   importer, world model, and renderer.
2. It inspected the repository's scenario, map import, world-state,
   presentation, asset-catalog, machine-fidelity, modding, and test contracts.
3. It read the relevant files from the immutable Goonstation checkout at
   commit `1b2b250abb5be747d55e274de0203a59cfc8da78`.
4. It reported the source dispatch order and coordinated with the test-owned
   sibling task so the document would use the same public tile target, action
   IDs, and denial codes as the executable tests.
5. It found and reported a concrete importer hazard: Goon grilles use
   `/obj/mesh/grille`, including `/obj/mesh/grille/steel` in Atlas, rather than
   the synthetic `/obj/grille` path used by an early fixture.
6. The test-owned sibling supplied the locked public interface:
   `affordances(simulation, target, actor)`,
   `can_action(simulation, target, action_id, actor, parameters)`, and
   `perform(simulation, target, action_id, actor, parameters)`. The agent
   reconciled the normative document to that argument order.
7. The first full audit exposed two concurrent integration gaps: first-party
   structure definitions were still schema 1, and the floor-to-plating
   transition dropped a known verb instead of returning
   `invalid-target-state`. The agent sent both exact failures to the parent.
8. The parent confirmed that related floor and wall profiles would expose a
   deterministic family action vocabulary with dynamic state gates. The agent
   made that a normative NPC-affordance rule.
9. The agent wrote the world-interaction fidelity contract, linked it from the
   root and technical documentation indexes, and created this archive record.
10. It made no core, presentation, tool, content, test, generated-asset, or
   upstream-source edits.
11. After the parent completed the schema and family-vocabulary integration,
   the full audit passed. The exact results are recorded below.
12. The parent assigned a documentation-only follow-up after the renderer
    expansion landed.
13. The agent verified the 29 aliases and 14 referenced pages directly from
    the generated foundation catalog, including that every selected source
    frame cell is 32×32.
14. It inspected the landed renderer, camera, application, UI viewport, and
    physical-pixel window configuration, then replaced the stale
    floor/wall-only implementation ledger.
15. It recorded the fixed painter groups, per-page static batching, native
    feature selection, discrete zoom and camera snapping, scissored 48-pixel
    top-bar exclusion, resize behavior, and shared mouse mapping.
16. It again changed documentation only and ran the follow-up validation
    recorded below.
17. The parent took ownership of the stale root README, technical rendering
    specification, and viewport documentation, and asked the agent to finalize
    this archive and manifest entry.
18. During final integration, the parent replaced the interim
    `usedpiscale=false` full-width viewport with shared DPI-scaled coordinates
    and a centered `7:5` viewport in whole `7×5` tile blocks. The minimum
    window now reproduces Goon's `21×15`, `672×480` reference field. This
    post-report correction supersedes the follow-up assignment's interim
    physical-pixel wording without altering the historical quoted assignment.
19. The parent also separated every potentially overlapping static component
    into its own painter group. Only mutually exclusive state alternatives
    share a group, so page batching cannot reorder a grille/window,
    furniture/sign, or infrastructure overlap.

## Visible conversation summary

This section preserves only externally visible coordination. It does not
reconstruct hidden reasoning or private model state.

- Initial progress update, normalized from the visible message: the agent was
  tracing pinned Goon click/attack dispatch and the physical floor, wall, door,
  window, grille, table, and light state machines against the current importer,
  world, and renderer, then turning the result into an
  exact/adapted/deferred contract and archive.

- The agent sent the parent consolidated source-precedence findings and noted
  that the current implementation had a coarse tile/structure model while the
  source required independent floor, edge, fixture, and construction state.

- The agent asked the test-owned sibling to keep the executable target and
  denial surface stable. The sibling replied with the public interface and
  bounded action set:

  ```text
  src.core.interaction
  affordances(simulation, target, actor)
  can_action(simulation, target, action_id, actor, parameters)
  perform(simulation, target, action_id, actor, parameters)

  target = { kind = "tile", index = ... }
  actions = inspect, pry-floor, place-floor, open-door,
            dismantle-wall, repair-wall
  ```

  The sibling also identified the bounded rejection set:
  `unknown-action`, `outside-map`, `not-adjacent`, `wrong-tool`,
  `access-denied`, `unpowered`, `invalid-target-state`, `occupied`, and
  `unsupported`.

- Importer correction sent to the parent and sibling, normalized from the
  visible message: the source pass exposed a concrete importer trap because
  actual Goon grilles are `/obj/mesh/grille`, not `/obj/grille`; Atlas includes
  `/obj/mesh/grille/steel`, so classification and fixtures need the real path
  before grille behavior can claim source fidelity.

- API-reconciliation update:

  > I’ve got the executable interaction API now. I’m reconciling the fidelity
  > contract to that exact call shape, then I’ll finish the
  > documentation/archive indexes and run the full audit.

- The agent reported the first audit's two failures to the parent: missing
  schema-2 structure profiles and loss of the known `pry-floor` action after a
  floor became plating.

- Parent contract confirmation:

  > Public direction is confirmed: related floor/wall profiles will expose a
  > deterministic family action vocabulary, with dynamic gates returning
  > `invalid-target-state` for known but inapplicable verbs. Please reflect
  > that contract and finish your docs/archive; renderer aliases are being
  > expanded now.

- Renderer follow-up assignment: the parent supplied the exact landed
  presentation facts listed in the quoted follow-up assignment above.

- Follow-up progress update:

  > The renderer expansion is in. I’m updating the fidelity ledger to the
  > exact 29-alias, multi-page SpriteBatch and pixel-stable camera contract,
  > then I’ll append this follow-up to the agent archive and rerun
  > documentation validation.

- The agent separately alerted the parent that the root README and technical
  rendering specification still reported the earlier 12-alias foundation,
  outside this follow-up's tech10/archive edit scope.

- Parent handoff:

  > Thanks. Please finalize your archive/manifest updates now; I’ll update
  > README and technical/04 plus viewport docs locally.

## Normalized visible work report

The agent produced
[Goon-compatible world interaction and tile fidelity](../technical/10-goon-world-interaction-fidelity.md),
a normative source-pinned contract with three deliberately separate claims:

- **exact** means a source datum or observable result is reproduced without a
  known semantic difference;
- **adapted** means the engine representation differs while an explicitly
  bounded result and ordering are preserved; and
- **deferred** means the behavior is not executable and no definition may
  claim compatibility for it.

The contract prevents the project from treating a correct sprite or a single
successful verb as full Goon compatibility. It binds any future
`goon-world-near-1` claim to handler order, prerequisites, intermediate state,
duration, interruption, products, topology, hazards, damage, and appearance.

### Click, target, and held-item dispatch

The pinned living-click path was recorded in source order:

1. targeted abilities may consume the click;
2. examine and point precede ordinary interaction;
3. restrained and incapacitated actors are rejected;
4. clicking the equipped item invokes self-use;
5. control-click handles pulling;
6. reach and click delay are checked;
7. empty-hand interaction calls the target hand handler;
8. held-item interaction calls the target item handler first; and
9. the item's after-action phase runs only if the item still exists and
   remains equipped, unless its pixel action consumes that phase.

Goon's component signals wrap target `Attackhand`, target `Attackby`, and item
`AfterAttack`. The document translates that behavior into deterministic,
bounded hook phases without requiring DM inheritance or BYOND emulation.

Draw order is expressly non-authoritative. A serial command identifies a
semantic tile, edge, or entity target; stable role and entity ordering resolve
ambiguity. This keeps UI clicks and NPC plans on the same path.

### NPC affordance contract

The complete target affordance contains a stable action ID, semantic target,
availability and denial code, source phase and symbol, intent, sorted tool and
item predicates, integer-decisecond duration, interruption flags,
reservations, hazards, effects preview, and fidelity status.

The current executable subset is explicitly smaller. NPCs must still receive
unavailable actions with stable reasons, rather than bypassing a prerequisite
that the UI would enforce. Tools are expressed as capabilities, allowing
modded tools to satisfy the same contract.

Timed work reserves its actor, target, work position, held item, and materials.
Completion revalidates prerequisites; interruption releases materials not yet
incorporated. Intermediate objects and salvage remain physical authoritative
entities rather than abstract construction progress.

### Turf, structure, and topology model

The contract distinguishes:

- base turf and floor assembly;
- full-tile structures;
- directional edges;
- independently stateful fixtures and furniture;
- contents; and
- derived movement, gas, fluid, projectile, visibility, and light fields.

Topology changes are atomic across every affected cell and edge. One tile can
retain a grille and a window as distinct objects. A breach is a derived result
of a new path from pressurized station atmosphere to an unsafe reservoir, not
an unconditional synonym for destroying any structure.

### Source state graphs recorded

The following source behavior was captured for future executable fixtures:

- **Floors and plating:** pry priority, broken/burnt tile behavior, floor-tile
  replacement, reinforced-floor rod and removal paths, exposed-plating cable
  constraints, sheet-to-girder/window construction, hidden-item reveal and
  hide behavior, and source explosion outcomes.
- **Ordinary walls and girders:** a ten-second welder deconstruction path,
  fuel and salvage, girder displacement/anchoring, two-sheet wall
  construction, false-wall path, skill modifiers, and source damage outcomes.
- **Reinforced walls:** the complete ordered tool sequence
  wirecutters → screwdriver → welder → crowbar → wrench → welder → crowbar,
  including intermediate states, durations, rod products, and partial repair.
- **Doors and airlocks:** operation and autoclose timing, density/opacity
  transitions, occupant safety and crushing, access, power, bolts, weld,
  panel, wires, electrification, hacking tools, welder behavior, crowbar
  constraints, and directional window-door timing.
- **Windows:** cardinal-edge versus full-tile identity, three assembly states,
  anchoring and rotation, one- or two-sheet recovery, retained reinforcement,
  repair material/timing, damage types, and shard/rod products.
- **Grilles:** the real `/obj/mesh/grille` identity, gas/fluid permeability,
  movement blocking, conductivity and shock, intact/ruined state, rods,
  wirecutter and screwdriver paths, window construction, and connected
  appearance.
- **Tables:** density and table-passing rules, connected cardinal and diagonal
  variants, item placement, grab/slam and tool precedence, parts construction,
  ordinary/reinforced dismantling, and source skill timing.
- **Lights:** distinct fixture and lamp objects, OK/burned/broken/empty/on
  states, power and area switching, wall/floor orientation, parts attachment
  and removal, bulb replacement, burns and shock, fixture/emission planes, and
  direction-dependent offsets.

### Damage, randomness, and rendering

Damage is component-specific and typed. Per-object resistance, failure
products, debris, salvage, and construction conservation cannot be flattened
into one universal health bar. Source probability, `pick`, and `rand` behavior
must use documented named deterministic random streams with fixture-tested
draw order.

The renderer must consume authoritative semantic appearance keys including
state, direction, connection mask, material, damage, frame, and overlays. It
preserves source plane/layer relationships and uses stable IDs to break equal
appearance ties. DMI remains immutable provenance; the native compiler
preserves exact pixels, icon-state, direction, frame, delay, and hotspot
metadata.

The landed foundation selection contains 29 aliases on 14 referenced pages,
all backed by 32×32 pinned frame cells. The static renderer now selects native
plating/reinforced floor and wall, window/grille, table/chair, light,
storage/crate, lattice/catwalk, pipe/disposal, and sign/decal appearances in
fixed painter groups. Within a group and dirty chunk, aliases sharing an atlas
page share one static `SpriteBatch`.

DPI-scaled coordinate output (`usedpiscale = true`), nearest filtering,
discrete `0.25/0.5/1/2/4` zoom, screen-unit camera snapping, and a centered
scissored `7:5` viewport keep draw and mouse transforms aligned through resize.
The minimum `960×540` window gives the world exactly `672×480` units, or the
upstream `21×15` field of 32-unit cells. Direction, connected variants,
damage/maintenance overlays, animation, and light emission remain outside the
current source-complete state selection.

### Mod and save boundaries

First-party world behavior must use the same namespaced, validated registration
path as trusted mods. The proposed world behavior, verb, damage, and hook
contracts remain non-public until the modding document defines their exact
schema and order.

Saves retain definition/behavior IDs, semantic targets and directions,
intermediate construction and fixture state, health/material/damage state,
door maintenance/power state, physical products, scheduled work,
reservations, named random state, and revisions needed for deterministic
continuation. Presentation batches and derived spatial caches are rebuilt.

## Exact files and results

The agent changed documentation only:

- `docs/README.md`
- `docs/technical/README.md`
- `docs/technical/10-goon-world-interaction-fidelity.md`
- `docs/agents/README.md`
- `docs/agents/manifest.json`
- `docs/agents/tile-interaction-docs.md`

Validation at first delivery:

```text
Lua simulation tests:  24/24 passed
Python importer tests: 16/16 passed
Core mod validation:   passed, 37 definitions
Asset audit:           passed, 46,160 sprites and 4,699 audio files
Markdown local links: passed, 70 documents
Agent manifest JSON:  passed
git diff --check:     passed
tools/dev.py audit:  passed
```

Follow-up documentation validation:

```text
Foundation aliases/pages: 29 aliases, 14 pages; all frame cells 32×32
Asset audit:               passed, 29 foundation sprites on 14 pages
Markdown local links:      passed, 70 documents
Agent manifest JSON:       passed
git diff --check:          passed
```

## Agent state at handoff

- Source research for the assigned floor, wall, girder, door, window,
  window-door, grille, table, light, damage, click-dispatch, and appearance
  scopes is complete for the pinned commit.
- The normative contract and documentation index changes are complete.
- The renderer implementation ledger has been reconciled to the landed
  29-alias presentation and the parent integration correction above records
  the final DPI-scaled, centered `7:5` viewport contract.
- No code or test file was edited by this agent.
- Runtime implementation remains owned by the parent and test sibling. The
  ledger must be rechecked whenever their public behavior changes.
- The most important source/data correction was incorporated in the concurrent
  importer and tests: real grille fixtures use `/obj/mesh/grille`, not a
  fabricated `/obj/grille` hierarchy.
- The next fidelity implementation should promote one complete source state
  graph at a time, with deterministic state/product/save fixtures, instead of
  marking a whole fixture family exact after implementing one verb.

## Decision disposition

### Accepted

- The immutable compatibility pin is
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- UI and NPCs use the same serial action, target, affordance, denial, and
  completion path.
- Source handler order, construction state, products, topology, hazards, and
  appearance are all part of a fidelity claim.
- The three statuses are exact, adapted, and deferred; broad “Goon-like”
  wording is not a compatibility claim.
- Real Goon grille paths begin with `/obj/mesh/grille`.
- DMI remains immutable input; runtime rendering uses compiled native assets.

### Adapted

- Direct BYOND clicks become deterministic serial actions at tick boundaries.
- Current actor tool IDs stand in for a fully stateful explicit held-item
  target until inventory entities are public.
- The bounded tile target and feature-mask world scaffolding may support early
  vertical-slice behavior, but do not represent independently addressable
  directional structures exactly.
- The source plane/layer model is translated into an authoritative appearance
  sort and portable LÖVE draw path.

### Rejected

- Selecting an authoritative target from sprite draw order.
- Calling a tile “the window” or “the grille” when both may coexist.
- Treating destruction as an unconditional breach event.
- Flattening all construction into one build or dismantle progress bar.
- Claiming a family exact from imported type presence, correct pixels, or one
  simplified action.
- Runtime DM parsing or hand-editing generated asset outputs.

### Unresolved

- Exact schemas for public world-behavior, verb, damage, and hook
  registration.
- Independent entity/edge targets and explicit held-item inventory entities.
- Full source timing, interruptions, hazards, physical products, typed damage,
  wires, and animation for each fixture family.
- Golden appearance coverage for every direction, connection mask, damage
  state, maintenance overlay, and animation.
- Legal/content review for every redistributed upstream audio and graphics
  artifact remains governed by the separate provenance and legal contracts.

## Sources

- Pinned upstream Goonstation checkout:
  `assets/cache/goonstation` at
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- Goonstation `code/modules/interface/mob_input.dm`,
  `code/mob/living.dm`, `code/atom.dm`, and `code/obj/item.dm`.
- Goonstation `code/turf/turf.dm`, `code/turf/floors.dm`, and
  `code/turf/walls.dm`.
- Goonstation `code/obj/structure.dm`, `code/obj/window.dm`,
  `code/obj/mesh.dm`, `code/obj/table.dm`, and
  `code/obj/item/table_rack_parts.dm`.
- Goonstation `code/obj/machinery/door/door_parent.dm`,
  `code/obj/machinery/door/airlock.dm`, and
  `code/obj/machinery/door/window.dm`.
- Goonstation `code/modules/power/lighting.dm`, `_std/plane.dm`, and
  `_std/defines/layer.dm`.
- Current repository scenario/map importer, world model, interaction tests,
  asset compiler/catalog, renderer, machine-fidelity contract, and modding
  documents, all inspected without modification outside this documentation
  slice.
