# Maintainability and CI agent

## Record

- Canonical task: `/root/maintainability_ci`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: implementation and local validation completed
- Assignment availability: verbatim
- Report availability: normalized visible report

### Assignment

> Implement maintainability/test automation now that runtime foundation
> exists. Own .github/**, new benchmark/CI helper files, and may extend
> tools/dev.py/tests/run.lua only after inspecting current shared state (do not
> overwrite recent mod/media work). Add a cross-platform-friendly GitHub
> Actions CI (LuaJIT/Python; media may be absent due LFS), a deterministic
> headless simulation benchmark/soak command with machine-readable output and
> realistic pass gates, and developer doctor/audit improvements. Run local
> checks. Save observable assignment/work/results in
> docs/agents/maintainability-ci.md and update docs/agents indexes/manifest. Do
> not edit design/technical/modding/production docs or media compiler.

### Observable chronology

1. Inspected the existing developer entry point, Lua tests, deterministic
   simulation, performance contract, production gates, mod validator, LFS
   rules, and current agent archive before editing.
2. Confirmed the current GitHub Actions Lua setup syntax and Windows MSVC
   prerequisite, then resolved immutable action revisions for the workflow
   lock.
3. Added a cross-platform push/PR matrix, Linux 100-crew gate, scheduled/manual
   soak, action-update configuration, and a checked workflow/toolchain lock.
4. Implemented a pure-Lua benchmark harness with scripted commands, warm-up,
   checkpoint replay, golden hashes, authoritative invariants, bounded
   percentile instrumentation, retained-state/memory checks, portable
   performance gates, and JSON-only stdout.
5. Extended `tools/dev.py` with read-only text/JSON doctor reports, required
   capability groups, LFS-aware asset-audit policy, structure/link/core
   boundary/workflow/LFS/mod checks, benchmark/soak commands, and a combined
   fast CI command. Added the developer command contract in `tools/README.md`.
6. Deferred archive edits while the parent updated other agent records, then
   re-read the index and manifest immediately before appending this record.
7. Rebuilt both golden fixtures after the parent reported an intentional
   authoritative snapshot change adding mod state and hooks. No stale hash was
   retained.
8. Waited through the parent's intentional clean graphics/audio rebuilds
   before the required-media audit, avoiding a false failure against transient
   generated output.
9. Ran fast, failure-path, plain-Lua, full-media, and complete-shift checks and
   reported the results below.

## Normalized visible implementation report

Implemented:

- `.github/workflows/ci.yml`: Linux/Windows/Intel-macOS LuaJIT golden replay,
  an Apple-Silicon plain-Lua portability lane, and the 192×192/100-crew Linux
  gate, all without LFS downloads;
- `.github/workflows/nightly-soak.yml`: one complete shift by schedule, with
  manual multi-shift selection including the 30-shift M3/release profile;
- `.github/dependabot.yml` and `tools/toolchain.json`: reviewable updates and
  immutable action/runtime pins;
- `tools/benchmark.lua` and
  `tests/fixtures/benchmark-baselines.json`: deterministic machine-readable
  benchmark/soak runner and reviewed smoke/CI checkpoints;
- expanded `tools/dev.py`: `doctor`, stronger `audit`, `benchmark`, `soak`, and
  `ci` interfaces that work without LÖVE or hydrated media where appropriate;
- `tools/README.md`: developer-facing usage, gates, artifact, and golden-update
  policy.

Observed validation:

- 12 deterministic Lua tests passed.
- Full `doctor --require full` passed Python, LuaJIT, LÖVE 11.5, Git LFS,
  FFmpeg/FFprobe, Pillow, and 134-page/4,699-file hydrated media checks.
- Full `audit --assets required` passed structure, links, pure-core boundary,
  action pins, LFS attributes, five mod packs, the 5,868-file upstream
  inventory, 46,160-sprite graphics catalog, and 4,699-file audio catalog.
- Smoke golden final hash `1661846301` passed under both LuaJIT and a local
  plain-Lua 5.5 benchmark probe. The hosted plain-Lua lane uses 5.1.5 to match
  the complete LÖVE/LuaJIT source dialect.
- The 192×192/100-crew CI gate ended at hash `943234082`, replayed identically,
  and sustained about 208–221 ticks per CPU second locally against a 40
  ticks/second gate.
- A complete 28,800-tick shift plus replay ended at hash `1813138303`,
  sustained 214.12 ticks per CPU second, retained 335.23 KiB, kept 24 alerts
  and 329 bounded events, and passed every gate. The JSON report was preserved
  under the ignored `build/benchmarks/` directory.
- Workflow YAML parsing, Python bytecode compilation, Black formatting,
  LuaJIT bytecode compilation, failure-gate exit behavior, and
  `git diff --check` passed.

The CI workflows themselves were not executed on GitHub-hosted Windows/macOS
runners from this local session. Their first hosted run remains the evidence
gate for those runner images.

## Decision disposition

### Accepted

- Routine CI must not require hundreds of megabytes of LFS media.
- Golden deterministic replay runs on all three desktop operating systems.
- The portable headless 4× gate is 40 simulation ticks per CPU second with a
  25 ms p95 ceiling; reports also carry the stricter reference-machine budget.
- Benchmark stdout is machine-readable JSON; command traces use stderr.
- Action revisions and tool versions are explicit and audited.

### Adapted

- The scheduled foundation soak is one complete shift so it fits routine
  nightly cost. The same command supports `--shifts 30` for the M3/release
  requirement rather than pretending the current foundation has already
  reached that milestone.
- Full asset validation runs automatically only for a completely hydrated
  checkout and is explicitly required for media handoff; pointer-only CI
  reports a skip instead of failing unrelated core changes.

### Rejected

- Silently regenerating golden hashes after an authoritative-state change.
- Treating GitHub-hosted timing as release-reference hardware evidence.
- Loading LÖVE, graphics, or audio in the headless benchmark.

### Unresolved

- The first real GitHub-hosted run must confirm the pinned LuaJIT builder on
  current Windows and macOS runner images.
- A 30-shift soak remains an M3/release execution gate; only the command and
  manual workflow path are implemented at this foundation stage.

## Sources

- [Project performance/testing contract](../technical/07-performance-testing-packaging.md)
- [Project release/maintenance process](../production/03-release-and-maintenance.md)
- [leafo/gh-actions-lua documentation](https://github.com/leafo/gh-actions-lua)
- [GitHub Actions checkout](https://github.com/actions/checkout)
- [GitHub Actions setup-python](https://github.com/actions/setup-python)
- [GitHub-hosted runner architecture reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

This record contains externally observable assignment, coordination, output,
and validation only. It does not contain hidden reasoning, private model state,
or unavailable dialogue.
