# Machine fidelity tests agent

## Record

- Canonical task: `/root/machine_fidelity_tests`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: verbatim final report
- Assignment availability: verbatim

### Assignment

> Own test files only. Inspect the current uncommitted map importer, machine
> schema/runtime, and scenario changes. Update/add Python and Lua tests to
> cover corrected Atlas counts (92 areas, 134 selected fixtures and exact
> family census), layered/co-located fixtures, safe literal overrides including
> six SMES, machine schema validation, scheduler/action/manufacturer/wires/save-load
> behavior where current APIs make it possible. Add content/machines.json to
> test registry lists and update expected counts. Do not modify src/, tools/,
> content, docs, or generated scenario. Run your relevant tests, report
> failures that indicate runtime bugs, and list changed test files.

### Observable chronology

1. The agent inspected the concurrent importer, scenario, schema, content, and
   runtime work while taking ownership only of test files.
2. It expanded Python importer/validator coverage, pure-Lua simulation
   coverage, and the LÖVE self-test's expected first-party registry count.
3. During concurrent integration, the suite exposed a nil denial-reason bug in
   `Machine.affordances`; the docs/renderer agent independently reported the
   same failure.
4. The runtime bug was subsequently fixed outside this agent's file scope.
5. The agent completed with 20 Lua and 13 Python tests passing, core mod
   validation passing at 37 definitions, and whitespace validation passing.
6. It ran the deterministic benchmark without updating goldens and reported
   the new checkpoints required by the intentional authoritative-state change.
7. The parent reviewed the machine scheduler, wire, power, and save-state
   additions, updated both benchmark baselines to the reported deterministic
   checkpoints, and passed the required smoke and CI golden gates.

## Verbatim final report

> Test work complete.
>
> Changed test files:
>
> - `tests/run.lua`
> - `tests/test_map_import.py`
> - `tests/love_selftest.lua`
>
> Coverage added:
>
> - Atlas: 92 areas, 134 fixtures, exact 13-family census, five layered positions
> - Six SMES overrides, including two 1,000,000-charge instances
> - Safe literal-only DM overrides and unsafe metadata rejection
> - Strict machine schema validation
> - Decisecond scheduler phasing
> - NPC affordances and stable denial codes
> - Serialized `machine_action` commands
> - Manufacturer queues, power, speed, wires, pause/continue, completion rechecks, damage/repair
> - Save/load continuation and wire-color persistence
> - Immediate nanofab processing
> - Registry count updated to 37
>
> Validation:
>
> - `python3 tools/dev.py test`: 20 Lua + 13 Python tests passed
> - Core mod validation passed with 37 definitions
> - `git diff --check` passed
>
> Benchmark CI remains deterministic and passes performance/invariant gates, but expectedly needs new goldens. New checkpoints:
>
> - 120: `490191731`
> - 240: `1321902006`
> - 360: `1155396836`
> - 480: `264928516`
> - 600/final: `701363153`
>
> Old final was `1501078122`. No golden files were edited.

## Exact files and results

The agent changed only:

- `tests/run.lua`
- `tests/test_map_import.py`
- `tests/love_selftest.lua`

The later affordance fix was made in concurrent core work, not by this agent.
After that resolution, the authoritative test result remained:

```text
Lua:    20/20 passed
Python: 13/13 passed
```

Benchmark state changed intentionally because machine scheduler, fixture, wire,
and manufacturing state entered the authoritative simulation. The agent
preserved the old golden files for the parent to review and update
intentionally.

The parent subsequently completed that review and updated
`tests/fixtures/benchmark-baselines.json`. Required smoke and CI replay,
invariant, performance, memory, and golden-checkpoint gates then passed. The CI
final remains `701363153`; the reviewed smoke final is `1919457156`.

## Decision disposition

### Accepted

- Exact corrected Atlas family and layered-placement assertions.
- Safe literal override and unsafe metadata fixtures.
- Source-derived scheduler, action, production, wire, damage, and save/load
  behavior tests.
- Recording new benchmark checkpoints without mutating goldens.

### Adapted

- Tests covered only behaviors available through the current public runtime
  APIs; deferred fidelity-ledger features remain future tests.

### Rejected

- Editing runtime/content/importer code from a test-owned task.
- Silently accepting new benchmark output by rewriting goldens.

### Unresolved

- Deferred machine families and behaviors require new source-vector coverage
  when implemented.

## Sources

- Concurrent `tools/map_import.py`, `tools/mods.py`, `src/core/machine.lua`,
  `src/core/simulation.lua`, first-party machine definitions, and generated
  Atlas scenario.
- Pinned Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
