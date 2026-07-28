# Mod package format and loading

## Locations and discovery

The loader discovers:

- folders directly below the LÖVE save-directory `mods/`;
- files ending exactly `.simmod` directly below that directory; and
- bundled packs below the read-only game `mods/`.

It does not recurse discovery directories, follow symlinks outside a folder
pack, fetch URLs, or scan arbitrary user paths. Bundled packs and user packs
with the same ID are an error unless developer mode explicitly selects one;
there is no silent shadowing.

A `.simmod` is a ZIP file with `mod.toml` at its root. It mounts privately at an
opaque internal mount such as `__mods/<session-token>/<pack-id>`, never at the
game root and never over another pack.

## Archive safety

Before mount, reject:

- absolute paths, drive prefixes, NULs, backslashes, `.`/`..` components,
  empty components, symlinks, hardlinks, devices, encrypted entries, nested
  archives presented as packages, or duplicate paths;
- two names equal under Unicode NFC plus ASCII case-folding;
- more than 20,000 entries, a path over 240 UTF-8 bytes, an entry over 512 MiB
  uncompressed, total expansion over 2 GiB, or compression ratio over 200:1;
- executable/native library extensions in data-only packs;
- undeclared root entries; and
- a ZIP whose central directory sizes/CRC do not match extracted bytes.

Media-specific limits may be lower. Extraction/mount is read-only. Generated
caches live under a hash-keyed save-directory cache, never inside the package.

## Manifest schema 1

```toml
schema = 1
id = "org.example.catering"
version = "0.2.0"
name = "Catering Expansion"
description = "Adds recipes, jobs, and a kitchen incident."
authors = ["Example Author"]
license = "CC-BY-NC-SA-3.0-US"
homepage = "https://example.invalid/catering"
api = "^0.1.0"
class = "data"
load_priority = 0

content = ["content/**/*.json"]
localization = ["locales/*.json"]
atlas_indexes = ["generated/graphics/*.atlas.json.z"]
audio_manifests = ["generated/audio/*.audio.json.z"]
scenario_maps = ["generated/maps/*.json"]

[[dependencies]]
id = "org.simstation.core"
version = ">=0.1.0,<0.2.0"

[[optional_dependencies]]
id = "org.example.farming"
version = "^1.2.0"

[[conflicts]]
id = "org.example.old-kitchen"
version = "*"

load_after = ["org.example.farming"]
load_before = []
replaces = ["org.simstation.core:recipe/food/fruit-salad"]
```

Code packs additionally declare:

```toml
class = "code"
entrypoints = ["lua/init.lua"]

[state]
schema = 1
```

All manifest keys are closed. Paths use `/`, are relative, cannot contain
wildcard `**` outside the final configured content roots, and must resolve to
files inside the pack. Globs expand by raw UTF-8 bytewise path order.

### Identity and version

- `id` follows the lower-case reverse-DNS pack rule and must equal the namespace
  of every new public definition unless the definition is an explicit
  replacement.
- `version` and game `api` use strict SemVer 2.0 without a leading `v`.
- `class` cannot be changed by an update without a fresh trust prompt.
- `load_priority` is an integer from −1,000 through 1,000; lower loads earlier.
- `license`, source, authors, and notices must satisfy the legal policy.

Constraint grammar supports:

```text
*                         any
=1.2.3                    exact
^1.2.3                    >=1.2.3,<2.0.0
^0.2.3                    >=0.2.3,<0.3.0
^0.0.3                    =0.0.3
>=1.2.0,<2.0.0            comma-separated AND comparisons
>1.0.0,<=1.4.2            comparisons
```

Whitespace around comma is allowed. OR, hyphen ranges, `~`, wildcards inside a
version, and implicit bare versions are rejected. Prereleases satisfy only a
constraint containing an explicit prerelease comparator.

The resolver uses the pinned [semver.lua](https://github.com/kikito/semver.lua)
for primitive comparison behind this project-owned grammar.

## Dependency and load resolution

1. Parse all manifests and group candidates by ID.
2. Select an exact enabled package version/hash from user configuration; there
   is no automatic “highest compatible” change for an existing campaign.
3. Add directed edges dependency → dependent for required dependencies.
4. If an optional dependency is enabled and compatible, add the same edge;
   otherwise omit it without error.
5. Add `load_after` target → pack and pack → `load_before` target when both
   targets are enabled.
6. Fail on a missing required dependency, incompatible API/version, declared
   conflict, self-edge, or any graph cycle. Report the shortest stable cycle.
7. Kahn-sort ready packs by `load_priority`, then raw UTF-8 pack ID, then
   package SHA-256.

Hints never override a dependency or conflict. User interface ordering has no
effect. The resulting exact ID/version/hash order is the mod lock saved in
campaigns and replays.

## Package hash

For `.simmod`, `package_sha256` hashes the exact archive bytes. For a folder,
hash a canonical stream of every included normalized path and file:

```text
uint64-le(path byte length) || path bytes ||
uint64-le(file byte length) || file bytes
```

Files sort by normalized raw UTF-8 path. Ignore only documented editor/cache
names (`.git/`, `.cache/`, OS thumbnail files); any other file affects the
folder hash even if no manifest glob references it. This prevents unseen code
changes from retaining trust.

## Replacement and conflict behavior

A new definition normally uses the pack's own namespace. To replace another
pack's exact `ContentId`, all are required:

- a direct required dependency on the current owner;
- the target ID in manifest `replaces`;
- definition `replaces` equal to its own target ID;
- same content kind and compatible schema.

Replacement chains follow load order and are recorded in the registry report.
Two unrelated packs replacing the same current ID are a hard conflict, not a
last-wins outcome. Patch/merge semantics are not supported in schema 1; copy
and explicitly replace the complete definition.

Files, sprite atlas coordinates, audio paths, localization resources, and Lua
modules cannot be overwritten by path collision across packs. Logical IDs and
documented replacement are the only override mechanism.

## Load failure UX

The title screen shows one structured report grouped by package:

- manifest/schema/path error;
- dependency/conflict/cycle;
- content ID/replacement/reference error;
- asset/audio/index validation error;
- trusted code registration error; or
- save lock mismatch.

The failed candidate set is not partially enabled. “Disable failing pack and
dependents” creates a proposed configuration and lists affected campaigns; it
does not rewrite a save.

## Acceptance

- Folder and ZIP copies of the same file tree load the same registry, though
  their package hashes use their documented representations.
- Discovery and ZIP entry order permutations produce the same load order/hash.
- Fixtures cover all constraint forms, prereleases, optional dependencies,
  hints, conflicts, cycles, duplicate IDs, replacement chains, and diamonds.
- Archive fuzzing proves bounded memory/time and rejects traversal,
  case-collisions, symlinks, duplicate entries, and bombs.
- `org.simstation.core` passes the identical loader and replacement rules.
