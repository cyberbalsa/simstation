# Developer automation

`tools/dev.py` is the cross-platform entry point for routine work. It resolves
the repository from its own location, so commands do not depend on the caller's
current directory.

## Environment and handoff checks

```text
python3 tools/dev.py doctor
python3 tools/dev.py doctor --format json --require runtime
python3 tools/dev.py doctor --require assets
python3 tools/dev.py audit
python3 tools/dev.py ci
```

Python 3.11+ and a LuaJIT/compatible Lua interpreter are always required.
`runtime` additionally requires LÖVE 11.5. `assets` requires Git LFS, Pillow,
FFmpeg/FFprobe, and hydrated runtime media; `full` requires everything.
`doctor` is read-only and returns `2` when a required capability is missing.

`python3 tools/dev.py run` starts the default Atlas scenario. During mod
development, launch a specific scenario that is present in the resolved pack
set with:

```text
python3 tools/dev.py run --scenario org.example.pack:scenario/start-id
```

`test` runs both the deterministic Lua suite and the DMM/native-map Python
fixture suite. `audit` adds Python compilation, JSON/TOML parsing, the pure-core
boundary check, local Markdown-link checks, pinned-workflow/toolchain
consistency, LFS attribute checks, and every bundled example-mod validator.
Its default `--assets auto` mode runs the media catalog/hash audit when all LFS
payloads are hydrated and reports an explicit skip for pointer-only CI
checkouts. Use `--assets required` for a media handoff.

## Goon map research and native scenarios

`tools/map_import.py` reads maps from immutable Git blobs at the commit in
`assets/upstream/goon/upstream.lock.toml`. It does not execute DM or require a
dense checkout. Default JSON is compact and deterministically ordered;
`--pretty` changes whitespace only.

```text
python3 tools/map_import.py inventory
python3 tools/map_import.py inventory --prefix '' --max-depth -1 --pretty
python3 tools/map_import.py analyze maps/atlas.dmm --top 25 --pretty
python3 tools/map_import.py compile maps/atlas.dmm \
  --scenario-id org.simstation.core:scenario/goon-atlas \
  --name "NCS Atlas — Sim Station" \
  --crop 61 61 252 252 --power-supply-w 750000 \
  --pretty --output mods/org.simstation.core/scenarios/goon-atlas.json
```

`inventory` parsed all 570 maps in the pinned tree and reports structural
irregularities separately from grammar failures. `compile` applies
`goon-type-path-adapter-v1`, emits `simstation-map-v1`, and records exact
commit/blob/byte hashes, crop orientation, unsupported paths, collisions, and
placement omissions in the definition. Reviewed turf/object paths and native
turf, wall, and feature classes are retained in the palette; compilation fails
before writing if more than 2,048 palette records would be required. The normal
game reads only the emitted native JSON. Use `--allow-unpinned` solely for
deliberate research; output from an unpinned revision is not a release
candidate.

## Determinism and performance

```text
python3 tools/dev.py benchmark smoke
python3 tools/dev.py benchmark ci --output build/benchmarks/ci.json
python3 tools/dev.py benchmark nominal-100
python3 tools/dev.py benchmark disaster-100
python3 tools/dev.py soak --shifts 1
python3 tools/dev.py soak --shifts 30
```

The Lua harness has no LÖVE or media dependency. Every invocation runs a
fresh simulation and an identical replay, compares checkpoint hashes, audits
authoritative invariants, measures retained Lua memory, and emits one JSON
report on stdout. Command traces go to stderr, so stdout can be piped directly
to a JSON consumer. `--output` writes the same report to a file.

| Scenario | World / crew | Default ticks | Routine gate |
|---|---:|---:|---|
| `smoke` | 48×48 / 24 | 240 | replay plus cross-platform golden hashes |
| `ci` | 192×192 / 100 | 600 | golden hashes, ≥40 ticks/s, p95 ≤25 ms |
| `nominal-100` | 192×192 / 100 | 1,800 | replay, ≥40 ticks/s, p95 ≤25 ms |
| `disaster-100` | 192×192 / 100 | 1,800 | replay, breach load, performance |
| `soak` | 192×192 / 100 | 28,800 per shift | replay, performance, bounded state |

The 40-tick/s portable gate proves the simulation can supply the 4× scheduler.
The stricter 12 ms mean / 20 ms p95 release budget remains a reference-machine
acceptance test and is included in each report. Timing uses process CPU time;
nightly artifacts are trend evidence, not a substitute for the reference
machine.

Golden fixtures live in
[`tests/fixtures/benchmark-baselines.json`](../tests/fixtures/benchmark-baselines.json).
An intentional authoritative-state change must update them only after the
human-readable state and compatibility impact are reviewed. Never rebaseline
merely to make a divergence pass.

## Automation layout

- `nightly-soak.yml` runs one complete shift by default. Manual dispatch can
  select 30 shifts for the M3/release soak.
- Pull requests and pushes do not run GitHub-hosted CI. Authors run
  `python3 tools/dev.py audit` locally before handoff.
- The nightly workflow skips LFS downloads and preserves JSON benchmark
  artifacts.
- Action revisions and runtime versions are pinned in `toolchain.json`;
  Dependabot opens reviewable action-update pull requests.

A release can claim a platform only when its required validation evidence was
recorded separately from the pull-request workflow.
