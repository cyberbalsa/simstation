# Goon-compatible world interaction and tile fidelity

## Purpose and compatibility boundary

This document is the normative contract for physical station interaction in
Sim Station. It covers turfs, boundaries, construction objects, furniture,
lights, damage, and the commands through which autonomous crew use them. The
machine-specific companion is
[Goon-compatible machine fidelity](09-goon-machine-fidelity.md); common
rendering rules remain in
[Rendering and the complete graphics fork](04-rendering-and-graphics.md).

The behavioral reference is the immutable Goonstation tree at commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`. A definition that declares the
`goon-world-near-1` profile promises the observable behavior of that revision,
not merely a similar sprite or result. The promise includes:

- target and handler precedence;
- hand, held-item, tool, intent, access, power, and adjacency gates;
- intermediate construction and maintenance states;
- action durations, interruption conditions, material inputs, salvage, and
  hazards;
- movement, projectile, gas, opacity, and topology effects;
- damage types, resistance, failure products, and repair;
- directions, connected variants, animation states, overlays, and source
  appearance relationships; and
- source quirks unless a reviewed fidelity-ledger entry names an intentional
  adaptation.

Sim Station does not execute DM, emulate BYOND, or give the director control of
an individual crew member. Source clicks become serializable, deterministic
physical actions selected and performed by crew. This is an engine adaptation,
not permission to erase tool chains or replace physical products with an
abstract progress bar.

The following status terms are mandatory in definitions, tests, and this
document's implementation ledger:

| Status | Meaning |
| --- | --- |
| **exact** | Source data or an observable result is reproduced without a known semantic difference. |
| **adapted** | The engine representation differs, but the declared result and ordering are preserved, or a bounded smaller behavior is identified precisely. |
| **deferred** | The behavior is not executable and no definition may claim it as compatible. |

“Close,” “supported,” and “Goon-like” are not fidelity statuses. A balance
variant uses a different profile or definition ID; it does not silently change
`goon-world-near-1`.

## Pinned source map

The principal source entry points are:

| Concern | Pinned source |
| --- | --- |
| Mob click precedence | [`code/modules/interface/mob_input.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/interface/mob_input.dm#L5-L101), [`code/mob/living.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/mob/living.dm#L380-L580) |
| Target and item wrappers | [`code/atom.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/atom.dm#L875-L915), [`code/obj/item.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/item.dm#L1091-L1110) |
| Turf state and directional blockers | [`code/turf/turf.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/turf.dm#L1-L207) |
| Floors and plating | [`code/turf/floors.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/floors.dm#L2119-L2512) |
| Walls and reinforced walls | [`code/turf/walls.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/turf/walls.dm#L4-L493) |
| Girders | [`code/obj/structure.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/structure.dm#L1-L344) |
| Doors and airlocks | [`door_parent.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/door/door_parent.dm#L4-L720), [`airlock.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/door/airlock.dm#L10-L926) |
| Directional window doors | [`code/obj/machinery/door/window.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/door/window.dm#L9-L257) |
| Windows | [`code/obj/window.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/window.dm#L4-L655) |
| Grilles | [`code/obj/mesh.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/mesh.dm#L1-L493) |
| Tables and parts | [`code/obj/table.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/table.dm#L4-L430), [`table_rack_parts.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/item/table_rack_parts.dm#L8-L292) |
| Lights, bulbs, and fixture parts | [`code/modules/power/lighting.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L8-L180), [`lighting.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/power/lighting.dm#L181-L1365) |
| Source planes and layers | [`_std/plane.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/plane.dm#L1-L31), [`_std/defines/layer.dm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/_std/defines/layer.dm#L1-L95) |

Line references are evidence for this pin. When the upstream pin changes, the
source files, derived definitions, ledger entries, and fixtures MUST be
reviewed together.

## One interaction path for UI and autonomous crew

### Serializable command boundary

Player UI, AI planning, incidents, and trusted mods do not call a world
mutation directly. They submit the same command at a tick boundary:

```lua
{
  kind = "tile_action",
  payload = {
    actor_id = 17,
    target = { kind = "tile", index = 9134 },
    action_id = "pry-floor",
    parameters = {},
  },
}
```

The bounded executable surface is `src.core.interaction`:

```lua
Interaction.affordances(simulation, target, actor)
Interaction.can_action(simulation, target, action_id, actor, parameters)
Interaction.perform(simulation, target, action_id, actor, parameters)
```

`affordances` and `can_action` MUST be pure queries. `perform` MUST run only
while the command queue is being committed. The current tile target is a
versioned subset, and its actor inventory currently supplies tool capability
IDs. The complete contract adds an explicit held-item ID to the serial command;
it does not change this argument order. Independently addressable fixtures will
require explicit `entity` and directional `edge` targets; an implementation
MUST NOT overload a tile index to mean whichever object happens to draw on top.

The minimum command-boundary acceptance slice has these stable action IDs:

```text
inspect
pry-floor
place-floor
open-door
dismantle-wall
repair-wall
```

Registered fallback profiles also expose bounded adapted verbs for reinforced
floor, airlock maintenance, windows, grilles, tables, chairs, lights, and
storage. Each such verb MUST appear in a schema-validated definition and
fidelity ledger before a release treats it as a compatibility promise; the
presence of a Lua handler alone is not an exact claim.

The minimum stable rejection codes are:

```text
unknown-action
outside-map
not-adjacent
wrong-tool
access-denied
unpowered
invalid-target-state
occupied
unsupported
```

The extended dispatcher also reserves `actor-missing`, `incapacitated`,
`invalid-parameters`, `unknown-parameter`, `invalid-parameter`, `welded`,
`bolted`, and `destroyed` for profile-specific gates. All of these strings are
save, replay, UI, AI, and mod-facing data. New codes require documentation and
fixtures; changing the meaning of an existing code requires a schema
migration.

### Source dispatch precedence

Goon's living-click path establishes behavior that must survive the engine
adaptation:

1. A targeted ability may consume the click.
2. Examine and point modes precede ordinary interaction.
3. Restrained or incapacitated actors are rejected.
4. Clicking the equipped item invokes its self-use handler.
5. Control-click handles pulling.
6. Reach and click-delay gates are evaluated.
7. An empty-hand reachable action calls the target's hand handler.
8. A reachable held-item action calls the target's item handler first.
9. If the held item still exists and remains equipped, its after-action handler
   runs; an item's pixel action may consume that phase.

The source wrappers also send component signals before the overridable
`attack_hand`, `attackby`, and `afterattack` handlers. Sim Station represents
these as bounded hook phases, not DM inheritance:

```text
validate command
→ resolve actor, item, target, intent, and reach
→ pre-target hooks
→ target-side hand or held-item handler
→ optional item-side after-action handler
→ validate effects and commit one transaction
→ observation hooks and events
```

A target-side handler returns an explicit continuation disposition. The item
phase runs only when the source behavior would reach it and the actor still
holds a valid item. Deleting, consuming, dropping, replacing, or unequipping
the item suppresses the item phase. A handler may not infer this from a Lua
return value that was never part of its descriptor.

Raw mouse position, UI mode, draw order, and LÖVE callbacks are
non-authoritative. Presentation converts them into a target and action request;
NPC planning begins from the same affordance records.

### Deterministic target resolution

A tile is an ordered spatial index, not one polymorphic object. The target
resolver uses declared interaction roles and stable entity IDs:

1. explicit entity or edge ID, when the command schema supports it;
2. an action's declared compatible component role;
3. stable entity ID among equally eligible components;
4. the floor assembly; then
5. the base turf.

Presentation plane, layer, alpha, and cursor hit order MUST NOT select an
authoritative target. When a UI click is ambiguous, it presents the ordered
eligible targets or chooses a documented semantic default before the command
is queued. Lua table iteration and renderer batch order are forbidden
tie-breakers.

### Affordances are the NPC vocabulary

An affordance is a fact about a specific actor, target, held item, and observed
world state. The target contract is:

```text
id                    stable namespaced verb ID
target                stable tile, edge, or entity reference
available             boolean
reason                stable rejection code or false
source_phase          hand, target-item, item-after, or explicit-verb
source_symbol         pinned source proc/type evidence
intent                source intent, if behavior depends on it
required_tools        sorted capability IDs
required_items        sorted item/quantity/material predicates
duration_ds           exact integer deciseconds
interrupts            sorted interruption flags
reservations          sorted target/item/work-position claims
hazards               known shock, burn, pressure, crush, or injury facts
effects_preview       bounded, knowledge-filtered result categories
fidelity              exact, adapted, or deferred
```

The executable slice may expose fewer fields, but it MUST preserve stable
ordering and the rejection code. Missing information is not permission for an
NPC to bypass it.

Each semantic family has a closed action vocabulary across its related states.
A floor becoming plating, a door opening, or a grille becoming ruined changes
an action's `available` flag and reason; it does not make a known action become
`unknown-action`. This lets an NPC understand which prerequisite or state
transition would enable the verb without hard-coding profile internals.

An NPC uses this contract to:

1. inspect available and denied actions;
2. choose work based on skills, policy, risk, materials, and route;
3. reserve the target, work position, tool, and consumables;
4. move adjacent and equip the required tool;
5. issue the ordinary serial command;
6. remain on a scheduled action until completion or interruption; and
7. react to the same result event and physical products as any other actor.

Tool requirements are capabilities such as `prying`, `screwing`, `snipping`,
`wrenching`, `welding`, or `pulsing`, never hard-coded Lua class paths. A modded
tool can satisfy the same capability through the ordinary content contract.

### Timed work and interruption

Every physical duration is stored in integer deciseconds. A scheduled action
contains its actor, target, item, start and due deciseconds, interrupt flags,
reservation IDs, source verb, and stable sequence. Movement, incapacitation,
loss of the item, target replacement, range loss, or another declared source
interrupt cancels before mutation. Completion revalidates all predicates.

Materials are reserved at start and incorporated only at the source-equivalent
commit point. Cancellation releases unincorporated materials. There is no
partial wall, table, or window created merely because an action timer was
partly complete.

The director's blueprint stages in
[World and construction](../design/02-world-construction.md) group and schedule
work. For a `goon-world-near-1` object, they MUST expand to the concrete source
tool/state graph below. “Frame” or “seal” is not a shortcut past a girder,
fastener, or material-producing step.

## Authoritative world representation

### Layered spatial model

The target model keeps these concepts independent:

| Semantic layer | Authoritative contents |
| --- | --- |
| base | space or supporting terrain |
| floor assembly | exposed plating, finished floor, reinforced floor, damage/burn state, hidden contents |
| boundary | wall, reinforced wall, airlock, directional window door, or edge blocker |
| anchored fixtures | stable IDs for windows, grilles, tables, lights, storage, and machines |
| utilities | cable, pipe, disposal, and data connectors |
| loose contents | items, debris, salvage, and occupants in stable ID order |
| surface/environment | decals, fluid, atmosphere, temperature, light, and hazards |

The current `World` maintains legacy `tile`/`structure` arrays plus
`turf_kind`, `wall_kind`, `feature_mask`, structure integrity, and
`interaction_state`. These fields are useful migration scaffolding. A feature
bit records spatial presence only; it cannot represent two windows' identities,
directions, materials, health, or separate actions. Behavior-rich fixtures
therefore become stable entities instead of accumulating parallel per-tile
special-case arrays.

Every authoritative quantity is an integer or documented fixed-point value.
Nested component keys and entity IDs are sorted before resolution, hashing,
save, or replay.

### Directional boundaries

Source windows and window doors can occupy one edge of a tile. A full window
blocks the whole tile; a cardinal window blocks only crossings and gas exchange
through its declared direction. Movement, gas, projectile, visibility, and
fluid rules are separate predicates even when they usually agree.

An edge component contains:

```text
entity_id
anchor_tile
direction
full_tile
blocks_movement
blocks_gas
blocks_fluid
blocks_projectiles
opacity
health_profile_id
appearance_state
```

The opposite side of an edge resolves to the same boundary identity. Changing
direction, density, or existence dirties both affected tiles' topology. A
directional window must never be flattened into a wall merely to make the gas
solver convenient.

### Atomic topology changes

Completing an interaction applies one validated effect transaction:

1. consume or create physical items;
2. update object/turf state;
3. update movement, gas, fluid, opacity, and support edges;
4. increment the affected topology and render revisions;
5. invalidate path, room, atmos, and sensor caches; and
6. emit ordered result, damage, topology, and work events.

A same-tick consumer observes either the complete old state or complete new
state. It never sees a removed wall with the old gas seal or a closed sprite
with open-door passability in authoritative state.

## Source physical state graphs

### Floors, plating, and hidden contents

The source floor is not a boolean. Relevant state includes `intact`, `broken`,
`burnt`, `reinforced`, material, appearance, and hidden underfloor contents.
The target-side held-item precedence is:

1. prying tool;
2. pen/writing;
3. welder or wrench removing floor reinforcement;
4. rods reinforcing exposed plating;
5. floor tile placement or quick replacement;
6. metal/crystal sheet construction;
7. cable placement, only on exposed plating;
8. grab, growth, and generic material attack.

The baseline source graph is:

| From | Action | Duration/input | To/products |
| --- | --- | --- | --- |
| intact ordinary floor | pry | immediate | plating; one matching floor tile unless burnt/broken |
| exposed plating | place floor tile | immediate; one tile | finished floor with tile material |
| intact finished floor | quick replace with tile while a pry tool is available | target pry phase then placement | replacement floor; no accidental hiding of contents |
| exposed plating | reinforce | 30 ds; two rods | reinforced/engine floor |
| reinforced floor | loosen reinforcement | 30 ds; wrench or usable welder | plating plus two matching rods |
| exposed plating | place cable | cable-coil rules | underfloor cable |
| floor with two metal sheets | build girder | 30 ds; two sheets | anchored girder |
| floor with two crystal sheets | build full window | 30 ds; two sheets | full window, optionally reinforced |

Removing plating reveals hidden contents. Replacing a normal floor may hide
tiny, unanchored items; quick replacement and a tile containing a table do not.
These are source behaviors, not decorative details.

The current floor profiles are an adapted bounded slice. They expose pry,
place, reinforce, and remove-reinforcement verbs, tool gates, and duration
metadata, but their handlers apply state immediately and do not yet consume or
produce physical tiles and rods. Broken/burnt variants, hiding, cable and sheet
precedence, scheduled interruption, and exact held-item semantics remain
deferred until represented and tested.

### Walls and girders

An ordinary source wall is opaque, dense, gas-impermeable, has base health 100,
and weld-deconstructs in 100 ds after consuming five welder units. Clean
deconstruction produces a material-matched anchored girder and two matching
sheets before replacing the wall turf with floor. Damage devastation may
instead produce displaced/no girder and scrap.

A girder is an independently targetable dense structure. Its baseline actions
are all 30 ds before training modifiers:

| Girder state | Tool/input | Result |
| --- | --- | --- |
| anchored ordinary | wrench | one matching sheet; girder removed |
| anchored ordinary | crowbar | displaced girder |
| displaced ordinary | wrench on valid floor | anchored girder |
| anchored ordinary | two reinforced sheets | reinforced girder |
| reinforced state 2 | screwdriver | reinforced state 1 |
| reinforced state 1 | wirecutters | ordinary girder |
| any anchored girder | two sheets | ordinary or reinforced wall, material preserved |
| displaced girder | one sheet | false wall |
| displaced girder | screwdriver | one matching sheet |

Engineer training halves girder action time, carpenter training divides it by
1.5, and the source engineering bot completes it in 1 ds. Such modifiers belong
to actor capability data, not a special NPC bypass.

A reinforced wall has base health 300 and this ordered deconstruction chain:

| State | Tool | Duration | Next state/product |
| ---: | --- | ---: | --- |
| 0 | wirecutters | immediate | 1; rods |
| 1 | screwdriver | 40 ds | 2 |
| 2 | welder | 60 ds | 3 |
| 3 | crowbar | 100 ds | 4 |
| 4 | wrench | 40 ds | 5 |
| 5 | welder | 100 ds | 6; rods |
| 6 | crowbar | 100 ds | dismantled wall |

One matching sheet repairs any partial reinforced-wall state in 100 ds.
Intermediate states have distinct appearances. An implementation that accepts
one welder action and deletes a reinforced wall is adapted, not exact.

### Airlocks and window doors

The common source door is an anchored, dense, normally opaque object with
operating, locked, electrified, panel, health, autoclose, and crush state.
Opening changes opacity and density during an operation; closing claims density
before completion, checks or crushes occupants according to safety, updates
nearby gas tiles, and may reopen after a crush.

Airlocks add:

```text
welded
main and backup power loss
wire states and color mapping
ID scanner state and required access
door bolts
safety wire
electrification
AI-control and hacking state
panel-open overlay
network/cycle identity
```

The baseline interaction precedence includes:

- empty hand can shock first, opens the wire UI when the panel is open and a
  suitable tool is equipped, knocks on a closed access-denied door on help
  intent, otherwise attempts the common access toggle;
- a T-ray scanner reports abnormal, absent, or regular electrical response;
- a welder on a closed, nonoperating airlock spends one unit and runs 20 ds,
  toggling welded state; it also repairs integrity;
- a screwdriver runs 10 ds and toggles the maintenance panel;
- snipping, pulsing, and signaler tools use the open panel UI path;
- a crowbar manually opens only an unpowered, unbolted, unwelded,
  nonoperating airlock, or manually closes an eligible open one;
- normal opening requires power, an intact open-door wire, no weld, no bolt,
  and no operation already in progress; and
- access denial precedes ordinary damage, while a sufficiently forceful held
  item can damage a closed door. Chopping tools apply the source multiplier.

The source common door has base health 400; the airlock subtype has 600. Damage
can spark, shock an attacker below an integrity threshold, or rarely open a
badly damaged airlock. Explosion severity, projectile damage type, material
armor, deletion, and debris remain part of its damage profile.

Directional window doors block only their declared edge. Their open animation
releases density after 8 ds, they attempt autoclose after 50 ds, and closing
claims density immediately before a 10 ds operating period.

The current tile door and airlock profile are adapted: they preserve
deterministic power/access denial, open/closed passability, pry, panel, welded
state, and simple autoclose. The profile's durations are descriptive; the
current command handler does not schedule interruptible work. The source
operation, wire harness, shock, bolt manipulation, crush/safety, damage,
directional, and overlay graph remain deferred. Its 30-tick autoclose is not
the source common 15-second delay and must not be reported as exact.

### Windows

A source window is a dense, anchored, gas-impermeable fixture. Cardinal
directions occupy one edge; a non-cardinal direction represents a full-tile
window. Material and optional reinforcement determine health and blunt,
slashing, piercing, corrosive, and temperature resistance.

Window assembly state is:

| State | Meaning | Source actions |
| ---: | --- | --- |
| 2 | window fastened to frame | screwdriver, 10 ds → state 1 |
| 1 | window in frame, not fastened | screwdriver, 10 ds → state 2; crowbar, 10 ds → state 0 |
| 0 anchored | empty frame fastened to floor | crowbar, 10 ds → state 1; screwdriver, 10 ds → unanchored |
| 0 unanchored | loose frame | screwdriver, 10 ds → anchored; crowbar rotates; wrench, 50 ds → sheets |

Training can halve the 10 ds assembly work. Wrench disassembly returns one
material sheet for a cardinal window and two for a full window, retaining
reinforcement. One matching sheet repairs damage in 40 ds, or 20 ds with
relevant training.

Damage at zero shatters the fixture, updates topology, and normally creates a
matching shard plus reinforcement rods. Explosion, meteor, projectile,
reagent, thrown-object, heat, and material damage are separate inputs. A full
window and an edge window therefore share construction logic without sharing
crossing geometry.

Windows are currently adapted only as a single per-tile feature state. A
bounded profile can knock, pry, toggle anchoring, repair, and dismantle that
feature, but it does not reproduce the source assembly graph or physical
products. Imported Atlas window cells are still flattened into wall topology,
which takes target precedence over the feature profile. Such a cell is
therefore a navigation/atmosphere approximation, not an independently
interactive source window.

### Grilles

The pinned source type is `/obj/mesh/grille`, including
`/obj/mesh/grille/steel`; it is not `/obj/grille`. Map adapters and fixtures
MUST recognize the real path. A grille:

- is initially anchored, dense, conductive, and gas/fluid permeable;
- has material-derived health and resistances, with a base health of 30;
- blocks ordinary movement while allowing projectile hit/pass behavior
  according to projectile type and a source probability;
- connects visually to neighboring walls, doors, windows, and grilles;
- can connect electrically to a cable stub on its floor;
- may shock hand interaction, tool interaction, or an actor crossing it;
- becomes a non-dense ruined grille at zero health before some subsequent
  damage paths delete it; and
- distinguishes cut, corroded, melted, and damage-percentage appearances.

The baseline tool/material graph is:

| Action | Input/duration | Result |
| --- | --- | --- |
| build | two rods, 15 ds | grille of the rods' material |
| repair ruined grille | one rod, immediate self-use at tile | full health and density |
| cut | wirecutters | ruined/cut grille |
| toggle anchoring | screwdriver | anchored/unanchored, grip updated |
| add full window | two crystal sheets | full window on the same tile |
| test | pulsing tool or T-ray scanner | reports connected current |

The native scenario preserves real grille source paths and classifies their
presence. A bounded adapted profile can cut an intact grille to a ruined state
and repair it, but it does not consume rods or model anchoring, damage types,
current, or shock. A co-located wingrille is still flattened behind wall target
precedence. Presence/provenance is therefore not a claim that the source
interaction graph is exact.

### Tables

A source table is a dense anchored fixture with surface placement, possible
drawer storage, material, auto-connected appearance, and a construction-parts
product. Movement blocks ordinary actors but permits table-pass objects and
movement from one dense table to another. Held-item target precedence handles
grabs, furnishing, tool work, bottles, keys, surface placement, and generic
attack in that order.

Table parts demonstrate why the item-side after-action phase matters:
attacking a valid adjacent turf with the held parts begins a 50 ds build action.
It consumes the parts on completion and creates the material-matched table.
Building under the actor is rejected. Ordinary table disassembly requires a
wrench on harm intent, runs 50 ds, and yields matching parts.

A reinforced table begins strong:

```text
strong --welder, 50 ds--> weak --wrench, 50 ds--> parts
weak   --welder, 50 ds--> strong
```

Engineer or carpenter training halves these actions. Auto tables derive
cardinal base and diagonal corner overlays from compatible neighbors. Drawers,
surface items, locks, and occupants remain separate entities; they cannot be
encoded as one table tile enum.

Tables currently have an adapted per-tile feature plus flip and
wrench-dismantle handlers. They do not provide physical parts, item placement,
storage, traversal, grab/slam precedence, material, reinforcement, scheduled
work, or connected appearance semantics.

### Lights

A source light fixture has a fixture body plus an inserted lamp item. Its
authoritative state includes:

```text
fixture type and install type
direction and wall/floor placement
lamp type and removable flag
lamp status: OK, burned, broken, or empty
on/off state
brightness and color
area/light-channel power
break and burnout probability
rigged state where applicable
```

The baseline physical graph is:

| Action | Gate/input | Result |
| --- | --- | --- |
| craft fixture parts | two sheets | tube, bulb, or floor fixture parts |
| attach parts | valid wall/window or floor; 40 ds | directed fixture; lamp state copied |
| remove lamp by hand | removable; heat protection if on | physical lamp item |
| insert matching lamp | correct fitting | old lamp returned, new lamp installed |
| uninstall empty fixture | screwdriver, power off, 20 ds | fixture-parts item |
| put item in powered empty socket | conductive item | possible electrocution |
| strike lamp | item-force probability | broken lamp, possible shock/sparks |

Power and the area's light switch determine normal on/off state. Emergency
lights invert their response to area light power. Broken, burned, empty, off,
and on states have distinct appearance; an enabled light also supplies an
overlay/emission.

Wall fixtures derive direction and pixel offset from their supporting wall.
Floor lights render on the floor plane; ordinary wall lights render above the
shadowed world. The current adapted per-tile profile stores only
installed/broken/on state and provides remove, replace, and toggle verbs. It
does not model the physical lamp, source hand/tool precedence, independent
power consumption, direction, hazards, appearance, or emitted light. A
wall-mounted light is also hidden by the current wall-first tile target
resolver.

## Damage, destruction, and breaches

### Typed damage

One universal structure-health subtraction is insufficient for source parity.
The target damage event is:

```text
event_id
due_ds
source_entity_id or incident_id
target_entity_id, tile, or edge
damage_kind
integer magnitude
material/penetration context
impact direction
named RNG stream and draw sequence
```

The full profile distinguishes at least blunt, slashing, piercing, heat,
corrosive, explosive, projectile, and meteor context. Each component maps
those inputs through its source resistance and failure graph. The current
`damage_structure(index, amount, type)` API accepts a smaller adapted
`brute`/`burn`/`corrosive`/`explosive` set. `brute` must not silently stand in
for all future blunt, slashing, and piercing behavior.

Every source `prob`, `pick`, or `rand` that affects state uses a serialized
named RNG stream in Sim Station. Stable event and target order determines draw
order. Random debris or damage appearance is not allowed to depend on entity
allocation order, renderer visibility, or Lua iteration.

### Failure products and conservation

Destroying an object invokes its own failure handler. Examples include:

- an ordinary clean wall becoming a girder plus two sheets;
- a devastated wall producing a damaged/displaced girder or scrap;
- a window yielding glass shard and reinforcement rods;
- a grille becoming ruined before later deletion or dropping rods;
- a table becoming table parts;
- a lamp breaking while the fixture remains; and
- a door being deleted with its damage/debris effects.

Items retain material and reinforcement when the source does. A generic
“structure becomes empty” transition is adapted and cannot claim exact salvage
or economy behavior.

### A breach is a derived condition

A breach is not a tile action or object kind. It is the observed consequence
of a topology transaction that opens a pressurized compartment to space or
another unsafe atmosphere. It may result from:

- a floor becoming space;
- a wall, door, or full window being destroyed;
- a directional boundary opening or shattering; or
- construction removing the last sealed boundary.

After the physical transaction, the atmosphere/room systems derive the new
connection and emit `compartment_breached` with the responsible transition.
The current meteor shortcut removes a structure while leaving the floor; it is
an adapted incident proof, not Goon-equivalent turf destruction.

Repair restores only state for which the physical object and material still
exist. It does not erase a breach alert before the compartment is actually
sealed and re-evaluated.

## Rendering fidelity

### Source-native media, not runtime DMI

The complete graphics fork already preserves every pinned DMI state, direction,
frame, delay, and source identity in native PNG/catalog data. DMI remains an
immutable provenance input and is never loaded by LÖVE. Exact source pixels do
not by themselves make an appearance exact: the runtime must select the right
state, direction, frame, overlays, offsets, and order.

Every interactive component projects a non-authoritative appearance record:

```text
semantic component and stable entity ID
sprite ID
direction
animation origin decisecond
variant/connection mask
plane and layer role
pixel offset
underlays and ordered overlays
tint, alpha, material appearance, and blend
damage/maintenance/operating visibility predicates
```

Authoritative state never stores an atlas page, quad, batch index, or LÖVE
object.

### Directions and connected variants

The asset compiler's canonical DMI direction order remains
south, north, east, west, southeast, southwest, northeast, northwest. A
one-direction state may fall back to its first cell only when the imported
metadata declares one direction. A four- or eight-direction state may not be
rendered permanently south.

Connected wall, grille, and table variants derive from a stable cardinal or
eight-neighbor mask after topology commits. Content maps each semantic mask to
an imported SpriteId and overlay stack. The renderer does not concatenate an
unvalidated source icon-state string or inspect neighboring Lua tables.

Required state coverage includes:

- finished, plating, reinforced, broken, burnt, and material floor variants;
- ordinary/reinforced wall connections and every reinforced deconstruction
  state;
- door open, closed, locked, opening, closing, deny, panel, and weld layers;
- cardinal/full windows, reinforcement, material, and damage;
- connected/intact and cut/corroded/melted grille states;
- connected table bases and corner overlays;
- light on, off, empty, burned, broken, and emission overlays; and
- physical construction products and debris.

Missing semantic states use the visible missing-sprite diagnostic and a
fidelity-ledger entry. They are never replaced silently with an unrelated
fixture.

### Plane and layer relationships

Goon separates floor, wall, ordinary-object, no-shadow, lighting, and
above-lighting planes, then uses finer layers such as plating, cable, grille,
door, storage, and effects. Sim Station normalizes these into its appearance
sort while preserving their meaningful relationships:

```text
space/underfloor
→ plating/floor
→ underfloor utilities
→ decals/fluids
→ grille and low floor fixtures
→ walls and directional boundaries
→ doors, furniture, storage, items, and crew
→ wall lights and nonshadow fixtures
→ lighting/emission
→ gameplay effects and UI
```

Within the general rule from the rendering specification, appearance entries
sort by plane, map-space foot Y, layer, stable entity ID, and stack index.
Underlays and overlays retain their declared order. Batching may combine only
contiguous entries and never changes this order.

The presentation hit test may use the same appearance bounds to offer a
convenient target list, but the final serial command names the semantic target.
Changing a sprite layer cannot change which object an NPC repairs.

### Current presentation slice

The foundation graphics selection publishes 29 logical aliases. Every selected
frame cell is a pinned 32×32 source cell. Twenty aliases serve the portable
semantic fallback world, two serve crew, six serve the current machine-family
fallback set, and `floor_white` is retained as a catalog-only floor reserve.
The static fallback aliases cover:

- floor, plating, and reinforced floor;
- ordinary and reinforced wall plus open and closed door;
- window and grille;
- table and chair;
- light;
- storage and crate;
- lattice and catwalk;
- pipe and disposal; and
- sign and decal.

The pinned Atlas scenario no longer flattens its authored cells into those 20
aliases. Its separate compact selection resolves 43,813 ordered source
appearances through 1,173 type rules and 2,104 selected sprite states on two
runtime pages. Exact map direction and literal visual overrides are retained;
connected wall, window, grille, table, and catwalk states and door open/closed
families are projected from authoritative runtime topology. The foundation
aliases remain the fallback for scenarios without a matching native catalog.

Floor, wall, and door state aliases come from the ordinary structure
definition's `sprites` map, so a data mod can replace them without a renderer
branch. Feature aliases currently use the first-party foundation defaults.
The selected source pixels and catalog provenance are exact; which one is
chosen is the adapted semantic projection described below.

Static media are cached per 16×16 dirty chunk. Within each fixed painter group,
aliases on the same atlas image/page share one static `SpriteBatch`; distinct
pages remain distinct batches. The groups are drawn in this order:

```text
plating/floor/reinforced floor
→ cable
→ decal
→ lattice
→ catwalk
→ pipe
→ disposal
→ wall/reinforced wall/closed door/open door
→ grille
→ window
→ table
→ chair
→ storage/crate
→ light
→ sign
```

Only mutually exclusive tile states share a painter group. Overlapping
components retain separate groups, so page batching cannot cross their
required order. This does not authorize a future entity, effect, underlay, or
overlay to cross its required appearance order merely to reduce draw calls.

The renderer selects native floor and wall variants from `turf_kind` and
`wall_kind`, and selects the feature aliases from authoritative presence and
the bounded intact state. An intact imported window replaces the coarse wall
sprite; an intact grille is drawn before it. Crate suppresses generic storage,
and sign suppresses the generic decal at the same tile. Missing required media
falls back to the deterministic primitive renderer so an incomplete catalog
does not make the station unplayable.

The current static path still requests south, frame 1 for every alias. It does
not yet select source direction, connected mask, material variant, animation,
damage/maintenance overlay, broken/cut appearance, or light emission. Those
remain adapted or deferred even though the selected base pixels are exact.

LÖVE uses its shared DPI-scaled coordinate space (`usedpiscale = true`), atlas
images use `dpiscale = 1` and nearest filtering, and the authoritative tile
size remains the source cell's 32 units. At 1× and DPI scale 1, one source
pixel is one backing pixel; integral platform DPI scales replicate each source
pixel by that integer factor. Camera zoom is restricted to `0.25`, `0.5`, `1`,
`2`, or `4`; camera translation is rounded in DPI-scaled screen-unit space
before converting back to world coordinates. Rendering and mouse-to-world
conversion use the same snapped position, preventing pan shimmer or hit-test
drift at the supported zooms.

The world viewport is centered below the 48-unit top bar, is scissored, and
keeps the upstream `21×15` or `7:5` field ratio in whole `7×5` tile blocks.
The minimum `960×540` window uses `(144, 54, 672, 480)`, exactly `21×15`
32-unit cells. The default `1280×720` window uses `(192, 64, 896, 640)`, or
`28×20` cells. Resize recomputes that rectangle and reclamps the camera.
Visible bounds, hover, selection, blueprinting, wheel zoom, and right-drag
initiation all use the same viewport; bars therefore cannot expose or target
map pixels hidden outside it.

## Content, mods, saves, and hooks

### Flattened definitions

World content flattens the relevant source inheritance into ordinary
namespaced definitions. A target definition contains:

```text
id, kind, schema, behavior
source repository/commit/type/files/symbols
footprint and directional-edge rules
movement/gas/fluid/projectile/opacity properties
state defaults and transitions
integrity/material/damage profile
actions, durations, capabilities, inputs, outputs, and interrupts
appearance states
map override allowlist
goon-world-near-1 fidelity ledger
```

Definitions contain no DM expression or executable Lua. A literal DMM override
may initialize only an allowlisted, typed field. A DM path remains provenance,
not runtime identity or a behavior selector.

### Registered behavior

The executable trusted-mod context currently exposes read-only
`tile_actions(map_id, x, y, actor_id)` and `query_tile(map_id, x, y)`. A
serialized command passes
`org.simstation.core:hook/tile/action/validate` before `perform`, and successful
execution emits `tile_action_completed`. The validation hook may reject but
MUST NOT mutate the request or bypass the ordinary gate path. These are an
adapted query/validation surface, not yet a behavior-registration API.

Trusted pure Lua may register a bounded namespaced world behavior and verb.
The public API is expected to parallel the machine API:

```lua
api:register_world_behavior(id, descriptor, handlers)
api:register_world_verb(id, descriptor, handler)
api:register_damage_profile(id, descriptor, handler)
```

Handlers receive immutable queries and return validated effects. They do not
receive raw world tables, LÖVE, the filesystem, network, wall clock, or an
unseeded random generator. Base content registers through the same API and
load order as any ordinary trusted mod.

Hook phases are namespaced and ordered:

```text
validate:world_action
transform:world_affordances
observe:world_action_started
observe:world_action_interrupted
observe:world_action_completed
observe:structure_damaged
observe:topology_changed
```

Validation may reject; transformation may alter only its documented bounded
record; observation may not mutate the completed transaction. Complete hook
ordering and schemas belong in the
[modding specification](../modding/README.md) before these hooks become public.

### Fidelity ledger

Every source-profile definition includes one unique record per feature:

```json
{
  "feature": "reinforced-wall-deconstruction",
  "status": "deferred",
  "source": {
    "commit": "1b2b250abb5be747d55e274de0203a59cfc8da78",
    "file": "code/turf/walls.dm",
    "lines": "338-488"
  },
  "note": "Current slice has one adapted dismantle action."
}
```

A mod replacement carries its own ledger. It may intentionally offer a simpler
profile, but it cannot inherit an exact claim for behavior it replaced.

### Save and replay state

Save:

- definition and behavior IDs;
- stable entity/edge IDs and anchor/direction;
- floor, wall, fixture, material, health, maintenance, and damage state;
- door power/access/wire/weld/bolt/operation/autoclose state when implemented;
- hidden contents and construction products as entity IDs;
- active action due decisecond, interrupts, reservations, actor, item, and
  sequence;
- named RNG state; and
- topology and render revisions needed by public continuation behavior.

Rebuild presentation batches, spatial acceleration, affordance caches, and
derived room/atmos/path regions. Save migration from legacy tile/structure
arrays must be deterministic and must not invent exact window, grille,
material, or direction state that the old save never stored.

## Implementation fidelity ledger

This table distinguishes the executable repository from the complete target.

| Feature | Status | Current truth and next boundary |
| --- | --- | --- |
| Upstream source revision | **exact** | Code, map, graphics, and provenance use commit `1b2b250abb5be747d55e274de0203a59cfc8da78`. |
| Graphics extraction | **exact** | Pinned DMI pixels, state metadata, directions, frames, and delays are preserved in the native catalog. |
| Foundation native pixels | **exact** | The catalog exposes 29 selected aliases backed by pinned 32×32 frame cells: 20 static-world aliases, two crew, six machine fallbacks, and `floor_white`. This claim covers pixels and provenance, not complete state selection. |
| World state scaffolding | **adapted** | `turf_kind`, `wall_kind`, feature presence, integrity, and interaction-state arrays persist beside the legacy tile model. Rich fixtures do not yet have full entity state. |
| Serializable world action boundary | **adapted** | `tile_action` and `src.core.interaction` expose a deterministic bounded verb path shared with NPC tests. Entity/edge targets and target/item phases remain target work. |
| Floor ↔ plating and reinforcement | **adapted** | Profiles expose pry, place, reinforce, and remove-reinforcement transitions with bounded tool and duration metadata. Handlers mutate immediately; physical tile/rod products, broken/burnt state, hiding, cable and sheet precedence, interruption, and exact source tool semantics remain deferred. |
| Ordinary wall dismantle/repair | **adapted** | A welder action, integrity, and wall-to-empty transition form the bounded slice. Source duration/fuel, girder/sheet products, materials, and devastated outcomes are not exact. |
| Reinforced wall repair | **adapted** | A reinforced kind, higher integrity, and bounded sheet-gated repair profile are executable. Exact material consumption and partial-repair behavior are not. |
| Reinforced wall deconstruction | **deferred** | The seven-state source tool sequence, intermediate appearances, interruptions, and products are not executable. |
| General structure damage | **adapted** | Integer integrity and a small damage-kind set are deterministic. Per-object resistance, source random effects, debris, salvage, and breach derivation are deferred. |
| Door access and maintenance | **adapted** | Tile airlock profiles preserve access/power denial, passability, open/close, pry, panel, weld, and simple autoclose state. Descriptive durations are not scheduled work; exact operation timing, damage, wires, shock, bolts, hacking, safety/crush, and direction are deferred. |
| Windows | **adapted** | A native feature and bounded anchored/pane/health profile expose knock, pry, fastener, repair, and dismantle verbs before the coarse wall profile. Intact windows block movement and gas; dismantling the final adapted frame releases the synthetic full-tile boundary. Edge direction, exact assembly graph, material products, typed damage, and stateful appearance remain deferred. |
| Directional window doors | **deferred** | Source edge identity, direction, operation timing, access, density release, and appearance are not executable. |
| Grilles | **adapted** | The importer recognizes the real `/obj/mesh/grille` hierarchy. Intact grilles block actors without blocking gas; a bounded intact/ruined cut-and-repair profile persists state. Atlas grille and wingrille visuals now select connected native states. Construction, anchoring, rods, current, shock, typed damage, and full window assembly state remain deferred. |
| Tables | **adapted** | Presence, dense actor traversal, and bounded flip and wrench-dismantle state are executable. Table-passing, item placement, grabs/slams, physical parts, reinforcement, materials, tool precedence, and connected variants remain deferred. |
| Lights | **adapted** | Presence plus bounded installed/broken/on state and remove/replace/toggle verbs are executable. Separate lamp identity, source hand/tool precedence, area switching, burns, shock, parts, direction, fixture appearance, and emitted light remain deferred. |
| Lattices and catwalks | **adapted** | Imported lattice/catwalk presence provides an actor-passable surface over legacy space tiles without creating a gas cell. Native Atlas auto-catwalk visuals select their cardinal mask. Their inspect affordance is public; construction, dismantling, grip/slip behavior, and damage remain deferred. |
| Click/hand/held-item/after-action phases | **deferred** | Machine verbs and bounded tile actions prove typed commands, but the general target-first/item-second dispatch is not yet public runtime behavior. |
| NPC physical affordances | **adapted** | Stable sorted availability, denial codes, requirements, source symbols, and duration metadata cover bounded turf and fixture verbs. Descriptors do not yet schedule duration; independent entity/edge targets, reservations, hazards, products, knowledge filtering, and complete source phases remain target work. |
| Trusted-mod tile surface | **adapted** | Context queries expose tile state and actor-specific actions, and a serial `tile_action` reaches a validation hook. World behavior registration, effect validation, transform/observation phases, independent targets, and full hook schemas remain deferred. |
| Native static appearance selection | **adapted** | The pinned Atlas crop carries 43,813 ordered source records. A provenance-gated compact catalog resolves exact type/icon state, map direction, offsets, oversized icon bounds, connected families, door state, and construction replacement defaults for 43,802 instances; 11 item/decorative instances remain explicit fallbacks. Animation timing, complete inherited DM plane/layer, material/damage/maintenance overlays, emitted lighting, and pack-owned catalog registration remain deferred. |
| Static batching | **adapted** | Each dirty 16×16 native chunk preserves the stable appearance sort and batches only contiguous commands sharing one of two compact atlas pages. Local and topology revisions invalidate connected state; a four-cell source margin retains oversized sprites. The portable semantic fallback still uses fixed painter groups. |
| Pixel and viewport mapping | **adapted** | DPI-scaled LÖVE coordinates, 32-unit source cells, nearest filtering, discrete `0.25/0.5/1/2/4` zoom, screen-unit camera snapping, a centered scissored `7:5` viewport made from whole `7×5` tile blocks, and shared resize/mouse transforms provide a deterministic portable presentation. The minimum window exactly exposes the upstream `21×15` field. This is an engine contract, not an upstream appearance-completeness claim. |
| Breach behavior | **adapted** | The meteor incident removes a structure and starts local fire. Source-specific turf/object damage, floor-to-space, products, and derived compartment events are deferred. |

No row marked adapted may be summarized as full Goon world-interaction
compatibility.

### Reviewed replay baseline change

This milestone intentionally changes authoritative hashes: native turf/wall
kinds, feature masks, structure integrity, interaction state, and the
source-preserving Atlas palette now enter snapshots. Deterministic replay and
save/load continuation were green before rebaselining. The reviewed smoke
checkpoints at ticks `60/120/180/240` are
`149539931/1808848090/143400338/1872503369`; the 100-crew CI checkpoints at
ticks `120/240/360/480/600` are
`1824715698/2098401554/1047093298/1592151463/216252628`.

## Acceptance gates

`goon-world-near-1` cannot be declared complete until all applicable gates
pass:

1. A held item reaches the target-side handler before its item-side
   after-action handler; consumption, deletion, or unequipping suppresses the
   latter in deterministic fixtures.
2. UI and NPC requests for the same actor/target/item produce byte-identical
   actions, results, events, and save hashes.
3. Every denial code is stable, knowledge-filtered, and available without
   mutating state.
4. Floor pry, replace, reinforce, remove reinforcement, hide/reveal, cable,
   girder, and full-window paths preserve source precedence and material counts.
5. Ordinary and reinforced wall/girder graphs reproduce every intermediate
   state, duration, interrupt, product, material, and trained-actor modifier.
6. Airlock fixtures cover access, power, panel, wire, weld, bolt, shock,
   operation, autoclose, safety/crush, damage, and linked-cycle fixtures.
7. Cardinal and full windows block movement and gas on the correct edges,
   retain assembly states/material, and update both adjacent topology cells.
8. A real `/obj/mesh/grille` map fixture imports, connects, conducts, shocks,
   ruins, repairs, and layers with a window without either identity being lost.
9. Tables build from and dismantle to parts, preserve material, place items,
   traverse according to flags, and select connected variants deterministically.
10. Lights install in every supported direction, carry physical lamps, follow
    area power/switch state, break/burn/empty safely, and render emission
    separately from fixture state.
11. Damage fixtures cover every supported type, source probability, RNG draw
    order, debris product, repair, topology update, and resource-conservation
    invariant.
12. Save/load during every timed and intermediate state continues with the
    same due decisecond, reservations, affordances, RNG, result, and state hash.
13. Golden images cover cardinal/full edges, connected masks, damage and
    maintenance states, door animations/overlays, and light emission at
    representative zooms.
14. A mod adds a tool capability, world verb, fixture definition, behavior,
    appearance, save state, and ledger without editing first-party core paths.
15. Stress tests randomize definition insertion and entity allocation while
    retaining identical target resolution, action order, topology, and replay
    hashes.

Focused source fixtures accompany each promoted feature. A broad visual smoke
test cannot substitute for state, timing, product, or ordering assertions.
