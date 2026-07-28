# Machine research archive agent

## Record

- Canonical task: `/root/archive_machine_research`
- Display name: not available
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: documentation and follow-up archive completed;
  validation passed; transient concurrent Lua failure resolved
- Report availability: this observable work record
- Assignment availability: verbatim

### Assignment

> Archive the completed machine research agents under docs/agents as requested
> by the user. Create three durable markdown reports for architecture_scope,
> power_machine_research, and atmos_prod_cargo_research, preserving exact task
> paths/status/pinned commit/key findings/source citations and enough detail to
> resume later. Update docs/agents/README.md and docs/agents/manifest.json
> consistently. Also create docs/technical/09-goon-machine-fidelity.md and link
> it from docs/technical/README.md, documenting the adopted
> upstream-observable-behavior contract, decisecond schedule, three-layer
> machine model, typed verbs/reason codes/NPC planning, fidelity ledger, exact
> corrected Atlas census of 134 (including 3 portable scrubbers), executable
> slice versus deferred work, save/replay contract, and acceptance roadmap. Do
> not edit code/tests or other design docs. Validate JSON. Report files
> changed.

### Observable chronology

1. Retrieved the completed visible report for `/root/architecture_scope` and
   its `/root/architecture_scope/atmos_prod_cargo_research` child.
2. Asked the parent for the no-longer-listed
   `/root/architecture_scope/power_machine_research` completion report and
   received its preserved results and citations.
3. Inspected the existing archive policy, manifest, template, technical index,
   source-pinned machine definitions, runtime ledger, and generated Atlas
   fixture census.
4. Authored the three durable research records, preserving preliminary census
   claims while labeling the later exact correction from two to three portable
   scrubbers and 133 to 134 selected fixtures.
5. Authored the normative machine-fidelity technical contract and updated its
   technical index/foundation status.
6. Added all newly completed agent records to the human and machine-readable
   archive indexes.
7. Validated manifest JSON, archive-file/index correspondence, local Markdown
   links, and whitespace.
8. Ran the required repository audit. It reached the Lua suite and exposed a
   concurrent `Machine.affordances` failure at `src/core/machine.lua:644`;
   this task did not edit code or tests, and the exact failure was reported to
   the parent.
9. The parent subsequently fixed the denial-reason boolean expression. The
   shared test command then passed all 20 Lua and 13 Python tests.
10. Archived the completed `/root/machine_fidelity_tests` and
    `/root/machine_docs_renderer` assignments, reports, changed files, focused
    checks, and resolution state.
11. Re-ran `python3 tools/dev.py test` during the archive follow-up and
    independently confirmed all 20 Lua and 13 Python tests pass.

## Delivered documentation

- [`machine-fidelity-architecture.md`](machine-fidelity-architecture.md)
- [`power-machine-fidelity.md`](power-machine-fidelity.md)
- [`atmos-production-cargo-fidelity.md`](atmos-production-cargo-fidelity.md)
- [`machine-fidelity-tests.md`](machine-fidelity-tests.md)
- [`machine-docs-renderer.md`](machine-docs-renderer.md)
- [`../technical/09-goon-machine-fidelity.md`](../technical/09-goon-machine-fidelity.md)
- archive and technical README updates;
- archive manifest update;
- this work record.

No Lua, Python, JSON content definition, scenario, test, asset, or other design
document was edited by this task.

## Validation

These targeted checks passed:

```text
python3 -m json.tool docs/agents/manifest.json
archive manifest/file correspondence:
  21 indexed records
  no missing archives
  no duplicate archive paths
  no unindexed agent records
python3 tools.dev.audit_markdown_links():
  markdown links ok (66 documents)
git diff --check -- docs/agents docs/technical
python3 tools/dev.py test:
  20/20 Lua tests passed
  13/13 Python tests passed
```

The first `python3 tools/dev.py audit` attempt did not pass during concurrent
integration. Its first failing check was Lua test 14,
`machine affordances expose stable NPC action denial reasons`, with:

```text
src/core/machine.lua:644: attempt to index local 'reason' (a nil value)
```

That failure was in concurrently edited machine code outside this assignment.
The parent subsequently corrected the boolean expression. This archive
follow-up reran the shared test command successfully:

```text
Lua:    20/20 passed
Python: 13/13 passed
```

## Decision disposition

### Accepted

- Preserve visible reports and preliminary claims instead of silently
  rewriting their history.
- Record the exact source-verified census correction alongside the originals.
- Make the current implementation/deferred boundary explicit in the normative
  technical document.
- Archive this agent as required by the project's all-agent preservation
  policy.

### Adapted

- The power child response was no longer directly enumerable, so its report is
  explicitly labeled as a consolidated visible completion report supplied by
  the parent.

### Rejected

- Reconstructing unavailable private reasoning or presenting inferred
  assignment text as verbatim.
- Editing concurrent runtime code to fix an audit failure outside this task.

### Unresolved

- None recorded for this archive task. The concurrent Lua failure described
  above was fixed and the complete Lua and Python test suites pass.

## Sources

- The three archived visible research reports and citations.
- Pinned Goonstation commit
  `1b2b250abb5be747d55e274de0203a59cfc8da78`.
- Generated
  `mods/org.simstation.core/scenarios/goon-atlas.json`.
- `mods/org.simstation.core/content/machines.json`.
- `src/core/machine.lua`.
