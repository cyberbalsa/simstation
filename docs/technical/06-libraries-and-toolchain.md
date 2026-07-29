# Libraries and toolchain

## Dependency rule

Dependencies are accepted only when they are:

- materially smaller or safer than owning the equivalent;
- compatible with LuaJIT/Lua 5.1 semantics used by LÖVE 11.5;
- pure Lua for shipped runtime code;
- under an OSI-style permissive license compatible with the project;
- pinned by exact commit/hash and vendored so a build never fetches mutable
  network state; and
- wrapped behind a project-owned adapter when they touch a public contract.

Runtime behavior must not depend on LuaRocks, system Lua packages, FFI, a C
compiler, shared libraries, or network access. Vendored files retain upstream
licenses and appear in notices/SBOM.

## Approved runtime set

| Purpose | Pin | Role and boundary |
|---|---|---|
| Engine | [LÖVE 11.5](https://github.com/love2d/love/releases/tag/11.5) | Window/input/render/audio/filesystem adapter; never required by `src/core` |
| ECS | [Concord `ee3587abc13cc39cd028d806924524be3bcee966`](https://github.com/Keyslam-Group/Concord/commit/ee3587abc13cc39cd028d806924524be3bcee966) | Dynamic entity composition; project code imposes sorted authoritative iteration |
| UI | [Slab `e696052474a695b93e8d73731b464d9d208a397a`](https://github.com/flamendless/Slab/commit/e696052474a695b93e8d73731b464d9d208a397a) | Desktop management/debug UI behind a view adapter |
| JSON | [lunajson 1.2.3](https://github.com/grafi-tt/lunajson/tree/1.2.3) | Strict parse/encode; project layer rejects duplicate keys/noncanonical values |
| TOML | [tinytoml 1.0.0](https://github.com/FourierTransformer/tinytoml/tree/1.0.0) | Human-authored manifests and asset metadata |
| SemVer | [semver.lua 1.2.1](https://github.com/kikito/semver.lua/tree/v1.2.1) | Parsing/comparison primitive wrapped by the mod resolver |

The exact commits above are the integration targets recorded during the July
2026 design pass. Vendoring is still gated by a clean-room license/header
audit, tests under LÖVE 11.5, and a `vendor-lock.json` record containing source
URL, commit, tree hash, license, local modifications, and vendored file hashes.
Failure of that gate means implementing the small adapter in-project; it does
not authorize silently selecting another version.

Slab is an immediate-mode UI toolkit written in Lua and describes itself as MIT
licensed with no compiled binaries ([Slab repository](https://github.com/flamendless/Slab)).
It does not own model state, localization, input bindings, save UI layouts, or
accessibility semantics. Those remain project APIs so Slab can later be
replaced without affecting mods/saves.

## Explicit nondependencies

- No STI: Tiled JSON is imported by a small owned validator into scenario
  definitions. Runtime does not load TMX or depend on Tiled internals.
- No Jumper: navigation is owned hierarchical room/portal routing plus
  deterministic local A*, with revisioned caches.
- No bitser/binser: saves are normalized primitive data, not serialized Lua
  object graphs or architecture-dependent bytes.
- No LUIS: its extra no-AI-training term is outside the project's approved
  permissive runtime dependency policy.
- No bump/Box2D: tile occupancy and deterministic interaction do not need a
  general collision engine.
- No mandatory DDS/KTX decoder, texture-array wrapper, OpenAL extension, or
  native codec.

These choices may be revisited only with a design update, license review,
portable fallback, benchmark proving material value, and migration analysis.

## Development tools

| Tool | Purpose | Shipped? |
|---|---|---|
| Python 3.11+ | unified developer command, schemas, imports, asset compilers | no |
| Pillow | lossless DMI/PNG parsing and atlas output | no |
| FFmpeg + libopenmpt | tracker analysis/rendering and audio verification | no |
| Lua Language Server | diagnostics and project annotations | no |
| LuaCATS LÖVE definitions | editor API types for LÖVE 11.5 | no |
| StyLua | deterministic formatting | no |
| Luacheck | Lua static checks and forbidden-boundary rules | no |
| Busted | pure-Lua unit/property/fixture tests | no |
| Tiled | optional authored scenario seed maps, exported to JSON | no |
| makelove | reproducible desktop packaging | no |
| [AppleCake](https://github.com/EngineerSmith/AppleCake) | opt-in LÖVE trace profiling in developer builds | no |

Tool versions and download hashes live in the repository tool lock. Scheduled
automation uses those versions; `latest` is forbidden in release workflows.
Asset compiler containers/tool archives must pin FFmpeg, libopenmpt, Pillow,
and Python patch versions because their output bytes participate in
provenance.

## Unified developer interface

The implemented project commands are:

```text
python3 tools/dev.py doctor     report/check runtime, media, and LFS capabilities
python3 tools/dev.py info       backward-compatible JSON doctor alias
python3 tools/dev.py run        start the current game
python3 tools/dev.py test       run deterministic Lua and map-import fixtures
python3 tools/dev.py audit      mandatory local handoff gate
python3 tools/dev.py ci         fast audit and smoke benchmark
python3 tools/dev.py benchmark <scenario>
python3 tools/dev.py soak --shifts <count>
python3 tools/dev.py mod validate|test|package <folder>

python3 tools/assets.py fetch-goon
python3 tools/assets.py import-graphics-source
python3 tools/assets.py build-graphics
python3 tools/assets.py build-audio
python3 tools/assets.py build-foundation-media
python3 tools/assets.py audit
python3 tools/assets.py all

python3 tools/map_import.py inventory
python3 tools/map_import.py analyze maps/atlas.dmm --pretty
python3 tools/map_import.py compile maps/atlas.dmm <scenario options>
```

`tools/assets.py` is separate because its commands intentionally fetch and
write hundreds of megabytes; ordinary audit remains fast and non-regenerating.
`tools/map_import.py` reads DMM/TGM as immutable pinned authoring input and
emits native scenario JSON; DMM is never a runtime format.
`tools/dev.py` locates the repository from its own path and runs commands at its
root. Asset caches/staging are ignored, and neither audit mutates source.
`python3 tools/dev.py run` chooses Atlas; a developer can choose any scenario
in the resolved mod set with
`python3 tools/dev.py run --scenario <namespaced-scenario-id>`.

Before their owning milestones exit, extend `tools/dev.py` with:

```text
lint / format --check           M1
notices                         M2
package <platform|all>          M4
```

Machine-facing commands emit JSON or provide a documented JSON format option.
Command-line failures use these common exit categories:

- `0` success;
- `1` validation/test failure;
- `2` missing/mismatched tool;
- `3` invalid command/input;
- `4` legal/provenance release block.

The current `audit` runs deterministic Lua and Python map fixtures, Python
bytecode compilation, JSON/TOML parsing, content/example-mod validation,
pure-core boundary and local Markdown-link checks, workflow/toolchain pin
checks, LFS attribute checks, an LFS-aware asset catalog audit, and
`git diff --check`. It does not regenerate assets, reimport the full upstream
tree, or run the long benchmark on every handoff.

## Data/map authoring

Authoritative definitions are JSON because their canonical representation is
strict and machine-checkable. Human package/asset configuration is TOML.
Localization uses UTF-8 key/value resources with explicit fallback.

Tiled may author finite orthogonal fixture/scenario maps only:

- tile size is 32×32;
- tile layers map by documented semantic name, never numeric layer index;
- objects use stable string IDs and closed property schemas;
- infinite maps, external executable scripts, embedded base64 assets, object
  templates outside the pack, and path traversal are rejected;
- an importer emits ordinary Sim Station JSON; release runtime never reads
  Tiled JSON.

The station remains buildable/dynamic. A Tiled map is a starting seed, not an
authoritative runtime world snapshot.

## Update workflow

1. Open a dependency/tool update issue with reason, old/new immutable refs,
   licenses, changelog, and expected benefit.
2. Regenerate the vendor/tool lock in a clean temporary directory.
3. Review source diff and license/notice changes.
4. Run unit, determinism, asset, save, mod, and package tests.
5. Benchmark when the dependency affects hot paths.
6. Update notices/SBOM and public compatibility notes.
7. Merge the lock and vendored bytes in the same change.

Automated pull requests may propose updates but never auto-merge them.
