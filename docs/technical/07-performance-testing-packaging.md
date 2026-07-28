# Performance, testing, and desktop packaging

## Supported platform matrix

The 1.0 desktop baseline is:

| Platform | Supported package |
|---|---|
| Windows 10 22H2 and Windows 11, x86-64 | fused LÖVE executable ZIP |
| Linux x86-64, glibc 2.31-class or newer | AppImage plus portable `.love` |
| macOS 11 or newer, Intel and Apple Silicon | universal application ZIP |
| Any desktop with compatible LÖVE 11.5 | portable `.love`, best-effort |

Mobile, browser, consoles, and 32-bit desktop are not 1.0 targets. A platform
port must retain deterministic core behavior, exact save integers, the PNG/Ogg
fallback, mod-folder/ZIP semantics, and complete notices.

The reference low-end performance machine is an Intel Core i5-8250U-class
four-core CPU, Intel UHD 620-class integrated GPU, 8 GiB RAM, SATA SSD, and
1,920×1,080 display. Thermal throttling is disabled for acceptance runs; tests
use release settings after a five-minute warm-up.

## Required benchmarks

Every benchmark has an immutable seed, exact mod lock, scripted command journal,
camera path, warm-up, measurement interval, and expected state hashes:

| ID | Scenario |
|---|---|
| `boot-core` | cold title → new 192×192 station with required core bundles |
| `nominal-100` | 100 crew, ordinary shift, production/logistics/needs active |
| `disaster-100` | 100 crew, meteor breach, decompression, fire, injuries, alarms, cleanup |
| `render-zoomout` | full-station zoom with static batches, decals, utilities overlay |
| `render-dynamic` | 100 composited crew, machinery, fluids, particles, eight atlas pages |
| `remote-sector` | station plus occupied mining map and two coarse remote maps |
| `save-large` | 30-shift campaign save, validate, reload, and rebuild caches |
| `mod-stress` | 50 data packs, replacements, graphics/audio bundles, 200 hooks |

On the reference machine:

- `nominal-100` and `disaster-100` sustain 60 presented FPS at 1×, with
  95th-percentile frame work at or below 16.7 ms and 99th at or below 33.3 ms.
- At 4× they remain responsive at 30 FPS or better, 95th-percentile frame work
  at or below 33.3 ms, and input-to-visible-command-result below 100 ms.
- Simulation work averages at most 12 ms per tick and has a 95th percentile at
  most 20 ms in `disaster-100`.
- No completed ticks are dropped, combined, or reordered.
- Resident process memory is at most 1.5 GiB; decoded static audio is at most
  96 MiB and regular atlas residency is at most eight 2,048px pages.
- `boot-core` reaches an interactive title screen in 5 seconds and a playable
  core station in 12 seconds from a cold SSD cache.
- `save-large` writes in 2 seconds and loads/rebuilds derived caches in 10
  seconds.
- A 30-shift soak has no monotonic unbounded growth in objects, tasks,
  reservations, Sources, Images, event retention, or Lua heap after expected
  content stabilization.

CI records results but dedicated reference hardware is the release authority.
A regression over 10% in any median metric requires investigation; a release
gate fails only when a hard limit above is crossed or determinism changes.

## Test layers

### Pure core unit and property tests

- canonical units, rounding, IDs, stable sorts, heaps, graphs, and RNG vectors;
- command validation/atomicity and event order;
- each system transition, reservation lifecycle, and failure recovery;
- randomized insertion order and equivalent-command metamorphic tests;
- no `love.*` load path under `src/core`.

### Content and mod fixtures

- closed schemas, duplicate/unknown keys, range/unit violations, references,
  cycles, replacements, aliases, dependencies, conflicts, and load order;
- safe ZIP rules, malformed paths, compression ratios, case-fold collisions;
- each public example and every schema-version edge.

### Asset fixtures

- DMI cells/directions/frames/delays/loops/rewind/movement/hotspots and atlas
  pixel parity;
- PNG page/index bounds, gutters, deterministic packing, large frames;
- Ogg validation/copy hash, tracker rendering, audio properties, loop points,
  loudness, captions, cache and voice limits.

### Integration scenarios

- start core, build/seal/power/pressurize a room, and autonomous construction;
- mining → haul → refine → manufacture → install → export;
- payroll, department budgets, personal purchase, food, sanitation, medicine;
- breach/fire → alarm → evacuation/response → treatment → cleanup → repair;
- save/reload/replay at high-risk boundaries;
- data, media, scenario, incident, and trusted-code example mods.

### Golden determinism

Every supported OS runs the same journals from identical canonical fixture
state and compares SHA-256 checkpoints every 600 ticks. The test also:

- saves/reloads at selected checkpoints;
- runs with rendering/audio on and off;
- changes presentation FPS and window size;
- shuffles input file discovery order; and
- asserts identical final events/state.

A deliberate state-hash change updates goldens only with a reviewed
human-readable state diff and save/mod compatibility decision.

### Fuzz and fault tests

Fuzz JSON/TOML, save envelopes, ZIP central directories, atlas/audio indexes,
and public commands with strict allocation/time limits. Inject failed writes,
truncation, device loss, missing generated files, hook errors, migration
exceptions, and worker cancellation. Tests may never use untrusted mod code as
a claim of sandbox security.

## CI gates

Pull requests run:

1. `python3 tools/dev.py audit`;
2. pure tests on Linux;
3. deterministic golden subset on Windows, Linux, and macOS;
4. package smoke tests when packaging/runtime files change;
5. asset fixture builds when compiler/schema files change; and
6. documentation link/schema-example checks.

Nightly runs all integration journals, fuzz seed corpus, clean asset
determinism, long benchmark subset, save compatibility, and 30-shift soak.
Release candidates run the complete source inventory/import verification and
legal/SBOM gates.

## Package construction

Use [makelove](https://github.com/pfirsich/makelove) behind
`python3 tools/dev.py package`. A package is built from a clean source commit
and contains:

```text
main.lua, conf.lua, src/, vendor/
mods/org.simstation.core/
mods/org.simstation.goon/          generated runtime content only
LICENSES/
THIRD_PARTY_NOTICES.md
asset-credits.md
asset-provenance.json
sbom.spdx.json
build-manifest.json
```

It excludes tests, caches, raw DMI/tracker inputs, editable sources, import
reports, Git metadata, local mods, saves, and developer credentials.

The `.love` archive has `main.lua` at root, forward-slash paths, stable UTF-8
bytewise file order, normalized permissions, fixed timestamps from
`SOURCE_DATE_EPOCH`, no duplicate/case-colliding names, and deflate settings
pinned in the tool lock. Platform wrappers use unmodified official LÖVE 11.5
runtimes whose hashes and license are recorded.

## Release validation

For every platform:

- unpack and compare the packaged file list to `build-manifest.json`;
- verify SHA-256 for every file and provenance link;
- validate SPDX 2.3, notices, license texts, and generated credits;
- launch offline from a path containing spaces and non-ASCII characters;
- create, autosave, reload, and replay a fixture campaign;
- load folder and `.simmod` example mods;
- render through the baseline no-array/no-compression path;
- decode representative static/stream audio and survive no audio device;
- verify settings/save paths stay inside LÖVE's application storage;
- scan for raw sources, secrets, absolute build paths, and unexpected binaries.

Publish `.love`, platform packages, source archive, SHA-256 list, build
manifest, SBOM, and detached Sigstore/minisign-style project signature.
Platform signing/notarization is required when release credentials are
available; absence must be called out plainly and does not permit bypassing OS
security controls.

Every production URL/package is noncommercial and contains the independent
project/no-endorsement statement from the legal specification.

## Crash and privacy policy

There is no mandatory telemetry. Local logs rotate at five files of 2 MiB and
default to no personal paths in exported diagnostics. Crash bundles are created
locally and shared only by explicit user action. Benchmarks contain only
machine class, OS/runtime versions, settings, metrics, hashes, and optional
user-provided notes.
