# Technical specification

These documents are normative for the runtime, tools, persisted data, and
release artifacts. They describe the intended 1.0 architecture; where the
bootstrap implementation is smaller, the bootstrap is a conforming subset and
must grow toward these contracts without breaking their boundaries.

## Reading order

1. [Runtime architecture](01-runtime-architecture.md)
2. [Public contracts and content data](02-public-contracts-and-content.md)
3. [Persistence, migrations, and replay](03-persistence-and-replay.md)
4. [Rendering and the graphics fork](04-rendering-and-graphics.md)
5. [Audio import and runtime](05-audio.md)
6. [Libraries and toolchain](06-libraries-and-toolchain.md)
7. [Performance, testing, and packaging](07-performance-testing-packaging.md)
8. [Native scenarios and Goon-informed map import](08-native-scenarios-and-map-import.md)
9. [Goon-compatible machine fidelity](09-goon-machine-fidelity.md)

Mod authors should then read the [modding specification](../modding/README.md).
Milestones and release gates live in the
[production specification](../production/README.md).

## Normative language

`MUST`, `MUST NOT`, `SHOULD`, and `MAY` have their ordinary requirements
meaning. A change to a public command, event, definition, save, asset index,
audio manifest, mod hook, or package format requires:

- a schema-version decision;
- an updated document and fixture;
- backward-compatibility or migration behavior;
- deterministic tests where authoritative state is affected; and
- a changelog entry visible to mod authors.

## Architecture invariants

- `src/core/` is pure Lua and has no reference to `love.*`, graphics, audio,
  wall-clock time, or mutable UI state.
- Player and trusted-mod actions reach the core only as serializable commands
  committed at tick boundaries.
- Authoritative outcomes use stable ordering, integer or documented
  fixed-point units, and serialized named random streams.
- The base game is the ordinary first-party mod `org.simstation.core`.
- DMI and tracker modules are immutable source/provenance formats, never
  release-runtime formats.
- Generated assets are reproducible outputs and are never edited manually.
- A portable PNG/Ogg path is mandatory; FFI, native plugins, GPU compression,
  and texture arrays are never required.

## Foundation status

The current executable establishes LÖVE 11.5, a pure-Lua simulation, fixed
constants for a 10 Hz scheduler, serial command queuing, stable pathfinding
tie-breaks, named deterministic RNG instances, and 16×16 dirty chunks. Its
normal start expands the first-party 192×192 native Atlas scenario into
authoritative world arrays, 92 operational areas, 134 machine fixtures, 85 job
spawn markers, and 64 reviewed breach targets.

Area-powered access doors, source-pinned machine definitions and controls, a
bounded manufacturing loop, starting inventory, scenario-aware incidents,
state hashing, and save/load continuation form the deterministic vertical
slice. Gas/pipe, full powernet, physical production/cargo, maintenance, and
NPC parity remain explicit deferred work rather than magic fixture effects.
The broader command/event/save and station-system contracts in these documents
remain the 1.0 target; native-start gaps are tracked in the
[scenario contract](08-native-scenarios-and-map-import.md#implementation-audit)
and [machine-fidelity contract](09-goon-machine-fidelity.md#current-executable-slice).
