# Atlas documentation polish agent

## Record

- Canonical task: `/root/atlas_docs_polish`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: documentation implementation and validation completed
- Assignment availability: verbatim
- Report availability: normalized visible report

### Assignment

> Polish project documentation for the implemented Atlas native-scenario
> milestone. Inspect current files first. Update README/docs indexes, technical
> scenario contract status/numbers, assets/tools/modding/legal provenance docs
> as appropriate. Add all completed agent reports (including yours) to
> docs/agents/README.md and docs/agents/manifest.json, preserving existing
> historical agent reports rather than rewriting their findings. Save your own
> work/state/chronology in docs/agents/atlas-docs-polish.md and index it. Do not
> edit Lua/Python source or generated scenario assets. Run link/docs validation
> you can find, and report exact files/results.

## Observable chronology

1. Inspected the dirty shared worktree, existing documentation indexes, legal
   policy, agent archive, current Atlas JSON, source lock/inventory, runtime
   scenario/save/mod paths, importer CLI, and all newly delivered agent
   records before editing.
2. Measured the final checked-in Atlas artifact rather than retaining
   intermediate compiler counts: 192×192, 390 palette entries, 2,345 runs,
   84 areas, 121 fixtures, 85 spawns, and 64 meteor targets.
3. Reconciled the top-level, technical, asset, tool, modding, and provenance
   documentation with native Atlas startup, manufacturing/save continuation,
   12 machine/tile/crew sprite aliases, the 5,869-file upstream inventory, and
   the exact pinned map crop/blob/hash/omission record.
4. Replaced the scenario contract's historical fifteen-item implementation
   audit with an explicit completed vertical-slice list and a narrower
   release-contract backlog. The original `scenario-contract.md` agent report
   remains unchanged as historical evidence of the pre-fix state.
5. Coordinated with the native-scenario-example agent so its new report and
   migrated salvage pack could be documented without concurrent index edits.
6. Documented the root agent's new
   `python3 tools/dev.py run --scenario <namespaced-id>` path for any loaded
   native scenario.
7. While reading that implementation, reported an unknown-scenario startup
   ordering bug and missing fallback mod lock to the root agent. The root
   confirmed both were fixed; this documentation task did not edit Lua.
8. Added every newly completed report to both the human and JSON agent indexes
   and added this record without changing historical reports.
9. Ran the documentation/link/structured-file checks and repository handoff
   audit recorded below.

## Normalized visible report

The update makes the current boundary explicit:

- Atlas is the default 24-crew native start, while any loaded scenario is
  launchable by exact `ContentId`.
- DMM is pinned authoring/provenance input only. Runtime consumes generated
  `simstation-map-v1` JSON and never executes DM.
- The checked-in derivative records exact source identity, crop orientation,
  included/omitted object counts, fixture collision choices, rejected APC
  placements, and a duplicate spawn.
- The current vertical slice is save-safe for machine, inventory, scenario,
  power, manufacturing, incident-target, and expanded-world state.
- Python/Lua validator parity, generic machine kinds, a graphical start picker,
  localized scenario names, operational reachability checks, and the complete
  negative fixture matrix remain release work.
- The salvage example now teaches the same strict native scenario path in a
  compact CC0-authored map. Its separately registered profile/objective records
  are described honestly as future-facing data.

## Files changed by this task

- `README.md`
- `NOTICE`
- `assets/README.md`
- `tools/README.md`
- `docs/README.md`
- `docs/technical/README.md`
- `docs/technical/04-rendering-and-graphics.md`
- `docs/technical/06-libraries-and-toolchain.md`
- `docs/technical/08-native-scenarios-and-map-import.md`
- `docs/modding/README.md`
- `docs/modding/01-package-format-and-loading.md`
- `docs/modding/03-authoring-and-compatibility.md`
- `docs/legal/goon-provenance.md`
- `docs/agents/README.md`
- `docs/agents/manifest.json`
- `docs/agents/atlas-docs-polish.md`

No Lua/Python source, test, upstream input, generated media, or generated
scenario artifact was edited by this task.

## Decision disposition

### Accepted

- Treat the generated Atlas artifact and current tests as implementation
  evidence, while keeping the larger technical contract normative.
- Describe direct map reuse as CC BY-NC-SA and noncommercial alongside the
  existing Goon media boundary.
- Keep omission/collision data visible and avoid claiming unsupported Goon
  objects or behavior were reproduced.
- Preserve earlier agent reports as time-specific research instead of
  retroactively correcting their now-resolved warnings.

### Adapted

- “Scenario selection” currently means an exact command-line content ID, not a
  title-screen browser.
- The salvage objective/profile remain useful schema examples but are not
  described as active campaign logic.

### Unresolved

- Full validator parity and the remaining acceptance matrix are tracked in the
  scenario contract.
- The direct Goon derivative still prevents an OSI-open-source commercial
  distribution; the project remains public-source and noncommercial under the
  documented mixed-license policy.

## Validation evidence

Completed successfully:

```text
python3 tools/dev.py audit
```

This ran the deterministic Lua suite, Python map-import fixtures, Python
compilation, structured JSON/TOML parsing, pure-core boundary check, local
Markdown-link validation, workflow/toolchain pins, LFS attributes, all bundled
mod validators, hydrated asset catalog/hash audit, and `git diff --check`.
Observed totals were 14 Lua tests, nine Python map tests, 59 linked Markdown
documents, five validated packs, 5,869 pinned upstream files, 46,160 graphics
records, 12 foundation sprite aliases/eight pages, 4,699 audio records, and 11
foundation sounds. All passed.

Focused documentation/archive checks also passed:

```text
jq empty docs/agents/manifest.json
python3 tools/dev.py audit --assets skip
git diff --check
```

The JSON archive contains 15 unique canonical tasks and 15 unique report
paths; a filesystem/manifest comparison found no missing or extra agent
report. This record contains externally observable work and validation only.
It does not reproduce hidden reasoning, private model state, or unavailable
dialogue.
