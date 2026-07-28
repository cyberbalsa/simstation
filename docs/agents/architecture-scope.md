# Faraday — architecture and scope

## Record

- Canonical task: `/root/architecture_scope`
- Display name: Faraday
- Last observable status: completed
- Report availability: full visible final report; Markdown links and line
  wrapping are normalized in the archive
- Assignment availability: original prompt unavailable; reconstructed from the
  task name and report

### Reconstructed assignment

Research and recommend the product scope, architecture, engine, deterministic
simulation strategy, content/mod format, save model, and roadmap for a
single-player SS13-inspired station-management game.

### Observable chronology

1. Faraday was assigned architecture and product-scope research.
2. Faraday returned the visible report preserved below.
3. The project owner later selected LÖVE 11.5, direct Goonstation derivation,
   40–100 high-fidelity crew, a single station deck, remote maps, and trusted
   code mods from day one.
4. Applicable architecture recommendations were adapted to those selections.

## Visible final report

The following preserves the full final response that remained externally
visible. Markdown links and line wrapping were normalized, so it is not
represented as a byte-for-byte transcript. Its recommendations are historical
research, not the current project contract.

> ## Recommended product and technical direction
>
> The repository is empty, so there are no inherited constraints.
>
> ### Blocking product decisions to ask first
>
> 1. **Release/IP path**
>    - **Commercial-capable original game — recommended:** use SS13/Goonstation
>      only as design inspiration; create original code, art, names, maps,
>      audio, and text.
>    - **Noncommercial Goonstation derivative:** reuse assets/code with
>      attribution and ShareAlike obligations.
>
>    Goonstation currently licenses almost all contributions as CC BY-NC-SA
>    3.0 US; only `tgui` is generally MIT. Exact tiles/code therefore conflict
>    with a commercial release. See the repository licensing statement and
>    license file. This is a scope gate, not legal advice.
>
> 2. **Player fantasy**
>    - **Station administrator — recommended:** build, zone, set policies,
>      assign jobs/priorities, inspect crew, and issue emergency orders.
>    - Administrator plus temporary crew possession.
>    - Captain/avatar-centric play.
>
>    Direct possession would substantially expand controls, combat,
>    interaction design, and AI handoff requirements.
>
> 3. **Scale versus fidelity**
>    - **100–250 deeply simulated crew — recommended:** room/zone
>      atmospherics, graph utilities, detailed jobs, health, needs, logistics,
>      and incidents.
>    - 40–100 agents with near-authentic per-tile SS13 physics and item
>      interactions.
>    - 500+ population with most citizens and services aggregated.
>
>    The recommended middle option preserves SS13-style emergent stories while
>    remaining readable and fast-forwardable.
>
> Nonblocking defaults: desktop PC first, management-only controls, campaign
> scenarios plus sandbox, data-only mods for v1, no multiplayer architecture.
>
> ## Product scope options
>
> | Direction | Strength | Main cost |
> |---|---|---|
> | **Detailed station-management sim — recommended** | Individual crew, all departments, manufacturing, utilities, economy, emergencies; strong SS13 identity | Requires selective abstraction and disciplined content scope |
> | Faithful SS13 systems sandbox | Maximum tile/item/chemistry fidelity | Difficult AI, poor fast-forward performance, huge testing matrix |
> | Space-metropolis city builder | Hundreds or thousands of residents, strong macroeconomics | Loses individual job interactions and much of SS13’s character |
>
> The recommended full-game target is roughly 200 active crew over up to four
> decks, with visitors, commuters, and background population represented
> statistically when they do not need individual agency.
>
> ## Engine choice
>
> | Option | Fit | Verdict |
> |---|---|---|
> | **Godot 4.x .NET/C#** | Strong native 2D, open MIT license, small-team workflow, pure C# headless tests, good content tooling | **Recommended for desktop-first development** |
> | Unity 6 | Mature 2D/UI/profiling; Jobs/Burst can support much larger populations | Choose only for strong existing Unity expertise or console priority; DOTS is unnecessary at the recommended scale |
> | TypeScript + PixiJS/Phaser + web UI | Excellent browser distribution and dashboard UI | Browser saves, mods, threading, and packaging complicate a full simulation |
> | Bevy/MonoGame/custom | Maximum control and potential performance | Editor, UI, asset pipeline, deployment, and accessibility work dominate development |
> | Direct BYOND/DM fork | Immediate access to existing behavior/assets | Wrong architecture for a macro-management game, difficult AI scaling, and inherited licensing/technical debt |
>
> Use the latest stable Godot 4.x release available when implementation begins,
> pin it, and update deliberately. Godot is MIT licensed and its current 2D API
> provides TileMapLayer. Use C# because the simulation is calculation-heavy and
> benefits from strong typing and ordinary .NET tests. This assumes desktop:
> current Godot 4 C# projects cannot export to web.
>
> ## Recommended architecture
>
> - Keep the authoritative simulation in a pure `.NET` library with no Godot
>   types. Godot handles presentation, audio, input, UI, and asset import only.
> - Use a hybrid data model:
>   - Dense arrays/chunks for floors, structures, utility layers, room
>     ownership, and occupancy.
>   - Stable numeric entity IDs and explicit collections for crew, machines,
>     inventories, tasks, incidents, and vehicles.
>   - Item quantities as stacks rather than one entity per sheet, reagent unit,
>     or meal.
>   - Avoid both “one Godot node per simulated object” and a generalized ECS
>     until profiling demonstrates a need.
> - Process player input as commands at tick boundaries. The core emits events
>   and immutable render snapshots; the view never mutates simulation state
>   directly.
> - Run a fixed **5 Hz authoritative tick**, independent of render rate, with
>   pause and 1×/2×/4×/8× speed. Fast-forward executes additional whole ticks
>   and never skips them.
> - Guarantee determinism for the same build, content set, seed, and command
>   stream:
>   - Stable system and entity ordering.
>   - Integer/fixed-point authoritative quantities.
>   - Seeded, serialized RNG streams.
>   - Deterministic A* tie-breaking.
>   - No wall-clock input or unordered collection iteration.
> - Use one single-writer simulation thread. Rendering receives double-buffered
>   snapshots. Parallelize only profiled bottlenecks; parallel jobs must finish
>   as a batch and merge results in stable request order. Godot itself warns
>   that engine objects have thread-safety constraints, which the pure-core
>   boundary avoids.
> - Model atmospherics as well-mixed room/zone reservoirs connected through
>   doors, vents, pipes, and breaches. Allow localized fire/smoke overlays where
>   needed. Authentic global per-tile gas diffusion is not recommended.
> - Model power, pipes, data, disposals, and logistics as topology graphs
>   rebuilt incrementally after construction changes.
> - Use a deterministic work-order system with job permissions, player
>   priorities, utility scoring, reservations, and explicit action sequences.
>   Avoid unconstrained GOAP.
> - Use hierarchical navigation: deck/room portal routes plus local tile A*,
>   cached by topology revision.
>
> Suggested scale gates:
>
> - Vertical slice: 32–40 crew, one 128×128 deck.
> - Alpha: about 100 crew, two decks.
> - Full target: 150–250 active crew, up to four 256×256 decks, with additional
>   populations abstracted.
> - Benchmark goal: smooth 60 FPS presentation and usable 8× simulation speed
>   on an agreed midrange desktop reference machine.
>
> ## Content, saves, and mods
>
> - Store authored content in JSON with JSON Schema validation and namespaced
>   stable IDs such as `simstation.core:steel_sheet`.
> - Define jobs, needs, rooms, machines, materials, recipes, research, events,
>   policies, contracts, and balance outside scenes. Compile IDs to dense
>   runtime handles after deterministic pack loading.
> - Give each content pack a manifest containing ID, version, dependencies,
>   compatibility, authors, license, and asset attribution.
> - Use build-time DMI/DMM conversion only for content the project is legally
>   entitled to distribute. Convert sprite states, directions, animation
>   frames, and map IDs into native atlases and scenario data; do not run or
>   transpile DM at runtime.
> - Support data-only mods first: new definitions, sprites, maps, recipes, jobs,
>   events, and built-in effect verbs. Defer executable or sandboxed scripting
>   mods.
> - Save only authoritative core state at a tick boundary:
>   - ZIP container.
>   - `manifest.json` with save version, game version, tick, seed, and
>     content-pack lock/hashes.
>   - MessagePack world snapshot.
>   - Optional thumbnail and diagnostic command journal.
> - Include RNG state, ID counters, active tasks/reservations, network state,
>   and content ID mapping. Never serialize Godot nodes/scenes.
> - Write saves atomically, maintain rotating autosaves, back up before
>   migration, and use explicit sequential format migrators. Missing required
>   mods should block loading with a precise diagnostic.
> - Add periodic state checksums and optional command replay for deterministic
>   regression tests and bug reproduction.
>
> ## Roadmap
>
> 1. **Foundation and risk proof**
>    - Lock IP path, player fantasy, target platform, and fidelity.
>    - Prove one 32×32 art pipeline, room detection, fixed ticks, snapshot
>      rendering, save/reload, and deterministic checksum.
>    - Benchmark a synthetic full-size grid and 200 simplified agents before
>      expanding content.
> 2. **Vertical slice: one functioning shift**
>    - One deck and 32–40 crew.
>    - Construction blueprints, room zoning, staffing, needs, task assignment,
>      inventories, hauling, basic power and atmosphere.
>    - Cargo purchasing, wages/upkeep, a short manufacturing chain, medical
>      treatment, and one breach/fire incident.
>    - Six represented departments: Command, Engineering, Cargo, Service,
>      Medical, and Security/Science in limited form.
>    - Success gate: play several shifts from construction through profitable
>      operation, survive an incident, save/load, and reproduce the run from a
>      seed.
> 3. **Systems alpha**
>    - About 100 crew and two decks.
>    - Full departmental budgets and jobs, contracts/markets, logistics,
>      maintenance, sanitation, research, health/injuries, morale, security,
>      waste, and multi-stage manufacturing.
>    - Scenario progression, event director, data-pack mods, overlays, and
>      management reports.
> 4. **Full-station feature set**
>    - 150–250 active crew and up to four decks.
>    - Advanced utilities/atmospherics, shuttles and visitors, law/prison
>      workflows, disease, social relationships, departmental politics, deeper
>      science/medicine, and broad incident chains.
>    - Multiple starts, campaign objectives, sandbox controls, and mature
>      automation/policy tools.
> 5. **1.0 hardening**
>    - Tutorial, accessibility, localization readiness, mod documentation/
>      workshop integration, save migrations, performance, balance, crash
>      recovery, and long-duration soak testing.
>
> The key recommendation is to use SS13 as a source of systemic inspiration,
> not to reproduce its multiplayer object model one-for-one. The management
> game should preserve emergent interactions while deliberately aggregating
> gases, bulk materials, background population, and routine actions.

## Decision disposition

### Accepted

- Separate an authoritative simulation core from presentation and platform
  adapters.
- Apply player commands only at fixed tick boundaries.
- Use deterministic ordering, serialized RNG streams, fixed-point or integer
  authoritative values, and replay checksums.
- Use dense/chunked tile storage alongside stable entity IDs.
- Incrementally rebuild utility topology graphs.
- Use deterministic work orders, reservations, and hierarchical navigation.
- Use namespaced content IDs, validated data, atomic saves, migrations, mod
  locklists, and command journals.
- Convert DMI content at build time rather than interpreting DM at runtime.

### Adapted

- Godot/.NET became LÖVE 11.5 and pure Lua with `love.*` confined to adapters.
- The 5 Hz simulation became a fixed 10 Hz scheduler with subsystem cadences.
- A 100–250-person multi-deck design became 40–100 highly detailed crew on one
  192×192 station deck with separate remote maps.
- Room-reservoir atmosphere became near-SS13 per-tile mixtures with sparse
  active-frontier processing.
- The suggested ZIP/MessagePack save became normalized JSON compressed through
  `love.data.compress`.
- A custom explicit entity model became dense tile arrays plus Concord-managed
  entities.

### Rejected or superseded

- The commercial-capable original-assets path was rejected in favor of a
  direct, noncommercial Goonstation-derived project.
- Data-only mods as the initial ceiling were superseded by data mods plus
  explicitly trusted Lua code mods from day one.
- 8× speed, four station decks, and 150–250 active crew are outside the current
  product contract.

## Sources cited in the visible report

- [Goonstation repository](https://github.com/goonstation/goonstation)
- [Pinned Goonstation license used by this project](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE)
- [Godot license](https://godotengine.org/license/)
- [Godot TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
- [Godot C# platform limitations](https://docs.godotengine.org/en/stable/tutorials/scripting_c_sharp/c_sharp_basics.html)
- [Godot thread-safety guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)
