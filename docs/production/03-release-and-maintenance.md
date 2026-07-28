# Change, release, and maintenance process

## Work intake

Every nontrivial change starts with an issue or design note identifying:

- player outcome and system owner;
- affected commands/events/data/hooks/saves/assets/audio;
- deterministic ordering and units;
- mod/save compatibility;
- tests and benchmark scenario;
- licensing/provenance impact;
- rollout or migration.

Bug diagnosis does not authorize unrelated refactoring. Generated-file diffs
must be separated from source/tool changes enough for reviewers to inspect
both.

## Pull request gates

A pull request is ready when:

1. corresponding normative docs are updated;
2. editable sources and provenance accompany media changes;
3. public schemas/fixtures/examples and compatibility notes are updated;
4. deterministic and failure/recovery tests cover behavior;
5. generated artifacts are fresh and reproducible;
6. author has run `python3 tools/dev.py audit`;
7. CI passes the required platform/asset/package jobs;
8. reviewer confirms license/notices/SBOM impact; and
9. performance evidence accompanies a hot-path or budget change.

Reviewers reject hidden runtime downloads, unpinned dependencies, raw DMI or
tracker runtime use, unordered authoritative iteration, floats affecting
outcomes, direct UI mutation of core state, base-pack special cases, and
hand-edited generated media.

## Release channels

| Channel | Version | Compatibility promise |
|---|---|---|
| nightly | `0.x.y-nightly.YYYYMMDD+sha` | diagnostic only; exact hash required |
| preview | `0.x.y-alpha.N` / `beta.N` | documented save/mod breakage allowed |
| candidate | `0.x.y-rc.N` | only release-blocking fixes |
| stable | `x.y.z` | published schema/API/migration policy |

Pre-1.0 campaigns remain pinned to their exact build/mod lock unless migrated
on a copy. Stable release artifacts are immutable; a correction receives a new
version.

## Release candidate procedure

1. Freeze source revision and `SOURCE_DATE_EPOCH`.
2. Resolve/vendored dependency and tool locks offline.
3. Verify Git LFS objects and exact pinned Goon snapshot.
4. Run full clean graphics/audio inventories, build, parity, decode, and
   deterministic-output verification.
5. Run audit, all-platform golden tests, benchmark suite, fuzz corpus, save
   migrations, example mods, and 30-shift soak.
6. Generate notices, licenses, asset credits/provenance, SPDX 2.3 SBOM, and
   build manifest.
7. Build all packages in clean workers without mutable network inputs.
8. Unpack and validate packaged files/hashes; perform fresh-machine smoke tests.
9. Sign artifacts and publish a release candidate with known issues and exact
   source link.
10. Hold at least seven days for a 1.0 candidate (48 hours for a patch), then
    promote the exact tested hashes or produce a new candidate.

Promotion never rebuilds. The published stable files must be byte-identical to
the approved candidate.

## Release-blocking severity

- Critical: data loss, arbitrary package traversal/execution from data-only
  content, unrecoverable campaign corruption, rights violation, or inability to
  start. Blocks immediately.
- High: deterministic divergence, common crash, progression blocker, missing
  required attribution, hard performance failure, or broken migration. Blocks.
- Medium: recoverable system/UI defect with workaround. Must be documented and
  triaged; may block based on reach.
- Low: polish/content issue without material behavior impact. May defer.

No open critical/high issue is allowed in stable.

## Save and mod support

- Each stable release documents which prior stable save schemas it migrates.
- At minimum, 1.x supports every earlier 1.x save by sequential migration.
- Never overwrite an original before migration validation.
- A patch release cannot intentionally break an API range or content schema.
- Removed public IDs receive aliases/migrations for the documented support
  window.
- Example mods and golden saves from every supported API/schema remain in CI.

Before 1.0, breakage is permitted only when explicit in release notes and
reported precisely by the loader.

## Goon source updates

Upstream updates are optional batches, not schedule requirements:

1. select a full immutable commit;
2. audit root/file license changes;
3. import to a temporary candidate snapshot;
4. diff paths, blobs, media semantics, attribution, and rights evidence;
5. preserve local mappings/edits explicitly;
6. review graphics contact sheets and audio analysis;
7. reproduce generated hashes twice;
8. update provenance/notices/SBOM and release notes.

An upstream change never silently renames public `ContentId`s or overwrites the
editable fork. Explicit incompatible rights evidence blocks the affected
release under the legal policy.

## Dependency and tool maintenance

Review proposed updates monthly or for relevant security fixes. Updates are
manual and require immutable source/license diff, tests, output reproducibility
for compilers, benchmark when hot-path relevant, and notices/SBOM regeneration.
The game remains buildable from its vendored runtime and pinned tool archive if
an upstream repository disappears.

## Takedown and emergency patch

For credible asset/license or security reports:

1. acknowledge privately and preserve evidence;
2. identify source/output hashes and affected releases;
3. mark disputed content `needs-review` or vulnerable package path blocked;
4. remove/replace in a new candidate without erasing provenance history;
5. regenerate bundles, aliases, notices, SBOM, tests, and hashes;
6. publish a corrective release/advisory and exact affected versions;
7. never remotely modify an installed game or save.

Security contact and takedown contact live in repository metadata and release
notices.

## User support and diagnostics

Support requests begin with the exported compatibility report and, when
possible, a replay/diagnostic bundle. The game never uploads automatically.
Maintain:

- troubleshooting for missing LFS/runtime/media/audio-device issues;
- safe backup/recovery/migration instructions;
- mod conflict and exact-lock reporting;
- known platform/package limitations;
- deterministic divergence triage by first checkpoint.

## Project health

At least quarterly, run:

- dependency/tool/license review;
- clean-source reproducibility build;
- supported-save migration matrix;
- example-mod compatibility;
- performance/memory trend comparison;
- broken documentation/source links;
- provenance and generated-credit completeness;
- issue/roadmap review against explicit exclusions.

Maintenance work has the same documentation/test requirements as new features.
