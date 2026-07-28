# Machine documentation and renderer agent

## Record

- Canonical task: `/root/machine_docs_renderer`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: verbatim final report
- Assignment availability: verbatim

### Assignment

> Own src/presentation renderer files and existing docs/design, docs/modding,
> docs/technical/08-native-scenarios-and-map-import.md plus root README
> references; do not touch src/core, tools, tests, content, docs/agents,
> docs/technical/09 or docs/technical/README. Inspect current changes. Add
> renderer aliases/fallbacks so all new machine fixture kinds (APC, SMES
> battery, cargo pad, supply console, barcode computer, fabricator, nanofab,
> reclaimer, portable scrubber, vent pump, passive vent, circulator, generator)
> visibly render using existing assets. Update relevant docs/counts from lossy
> 84/121 to exact selected Atlas 92/134, explain layered fixtures/literal
> overrides, and minimally synchronize design/modding docs with source-pinned
> machine schema, decisecond scheduler, typed NPC machine verbs, fidelity
> ledger/hooks. Mark old abstraction recommendation as superseded only if that
> file is in your allowed set; otherwise leave it. Run any focused checks.
> Report files changed.

### Observable chronology

1. The agent inspected the newly imported fixture kinds, existing media
   aliases, public documentation, and its explicitly bounded edit set.
2. It added presentation aliases/fallbacks for all 13 selected machine
   families using existing generated assets; no generated asset was edited.
3. It synchronized root, design, modding, and native-scenario documentation
   with the corrected Atlas counts and public machine contracts.
4. Its focused renderer syntax, Markdown link, core boundary, scenario count,
   and whitespace checks passed.
5. A full audit during concurrent integration reached 18 of 19 passing Lua
   tests and exposed a nil denial-reason expression in
   `Machine.affordances`.
6. The agent reported the exact issue to the parent. It was subsequently fixed
   outside this agent's ownership, after which all 20 Lua and 13 Python tests
   passed.
7. The user then required one Lua module per machine sorted by department.
   In a follow-up, the agent documented the implemented dispatcher/registry
   boundaries, exact department tree, family ownership rule, and current
   scheduler ordering versus deferred pipe/powernet phases.

## Follow-up assignment

> User has now required one Lua module per machine, sorted by department.
> Inspect the new
> `src/core/machines/{engineering,atmospherics,cargo,manufacturing}/` layout
> and update `docs/technical/09-goon-machine-fidelity.md` (and README only if
> useful) to make this a maintainability contract:
> `src/core/machine.lua` is the shared dispatcher; each family owns its
> handlers/process/power/failure logic in one department-sorted module;
> registry is deterministic; shared helpers contain no family behavior. Do not
> touch code/tests/agents manifest. Also correct any stale claim that the
> runtime already implements pipe-network/powernet event classes if needed by
> clearly distinguishing current executable ordering from target. Validate
> links/diff and report.

## Verbatim follow-up final report

> Updated `docs/technical/09-goon-machine-fidelity.md` with:
>
> - One department-sorted module per machine family.
> - Explicit dispatcher, deterministic registry, and family-neutral helper
>   boundaries.
> - Legacy-shim restrictions and module ownership rules.
> - A matching acceptance gate.
> - Clear current scheduler ordering versus deferred pipe-network `+4 ds` and
>   power-net-reset `+8 ds` target events.
>
> Markdown links and whitespace/diff checks pass.

## Verbatim final report

> Completed the renderer/documentation slice.
>
> Changed:
>
> - `src/presentation/renderer.lua`
> - `README.md`
> - `docs/design/{01,02,03,04,05,11,13}*.md`
> - All four `docs/modding` documents
> - `docs/technical/08-native-scenarios-and-map-import.md`
>
> Key updates:
>
> - Added visible asset aliases/fallbacks for all 13 imported machine kinds.
> - Updated Atlas to 92 areas, 134 fixtures, 408 palette entries, and 2,405 runs.
> - Documented layered fixtures and safe literal overrides.
> - Added decisecond scheduling, typed NPC affordances/reasons, schema-2 machines, fidelity statuses, hooks, and mod authoring guidance.
> - Removed stale 84/121 and one-fixture-per-tile assumptions.
>
> Checks passed: renderer Lua syntax, Markdown links, core boundary, Atlas count assertion, and `git diff --check`.
>
> The full audit initially reached 18/19 passing Lua tests, then failed in concurrent core work at `Machine.affordances` due to the nil-reason boolean idiom. I reported the exact fix to the parent.

## Exact files and results

The agent changed:

- `src/presentation/renderer.lua`
- `README.md`
- `docs/design/01-simulation-foundations.md`
- `docs/design/02-world-construction.md`
- `docs/design/03-environment-utilities.md`
- `docs/design/04-crew-work.md`
- `docs/design/05-industry-economy.md`
- `docs/design/11-content-contracts.md`
- `docs/design/13-glossary.md`
- `docs/modding/README.md`
- `docs/modding/01-package-format-and-loading.md`
- `docs/modding/02-hooks-and-code-api.md`
- `docs/modding/03-authoring-and-compatibility.md`
- `docs/technical/08-native-scenarios-and-map-import.md`
- `docs/technical/09-goon-machine-fidelity.md` (follow-up)

The transient audit failure belonged to concurrently edited core code. After
the parent fixed the denial-reason expression, the shared suite passed:

```text
Lua:    20/20 passed
Python: 13/13 passed
```

The renderer uses existing asset IDs and fallbacks. It did not modify compiled
atlases, source PNG/TOML, provenance, or upstream DMI inputs.

## Decision disposition

### Accepted

- Every selected imported machine kind must remain visible even when it lacks
  a dedicated sprite.
- Public design/modding contracts describe schema-2 definitions, decisecond
  processing, typed affordances/reasons, fidelity status, layered fixtures,
  and safe literal overrides.
- Every supported family owns one department-sorted Lua module; the shared
  dispatcher, deterministic registry, and family-neutral helpers remain
  separate review boundaries.
- The corrected Atlas presentation/documentation baseline is 92 areas,
  134 fixtures, 408 palette entries, and 2,405 runs.

### Adapted

- Existing asset aliases and generic fallback sprites support the first
  machine milestone; dedicated source-derived sprite states can be added
  through the ordinary asset compiler later.

### Rejected

- Runtime DMI use or hand-editing generated media.
- Leaving stale 84-area/121-fixture or one-fixture-per-tile claims in public
  documentation.
- Editing authoritative core behavior from a presentation/docs-owned task.

### Unresolved

- Dedicated visual state coverage for every upstream machine overlay,
  maintenance state, fault, wire panel, and animation remains future asset and
  presentation work.

## Sources

- First-party generated media aliases and
  `src/presentation/renderer.lua`.
- Corrected generated Atlas scenario and machine definition schema.
- [`../technical/09-goon-machine-fidelity.md`](../technical/09-goon-machine-fidelity.md).
- Pinned Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
