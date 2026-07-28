# Goonstation provenance and import policy

## Canonical source

| Field | Value |
|---|---|
| Repository | `https://github.com/goonstation/goonstation` |
| Initial pinned commit | `1b2b250abb5be747d55e274de0203a59cfc8da78` |
| Root license | [CC BY-NC-SA 3.0 US](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE) |
| README license statement | [Pinned README](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/README.md#license) |
| Graphics root | [`icons/`](https://github.com/goonstation/goonstation/tree/1b2b250abb5be747d55e274de0203a59cfc8da78/icons) |
| Audio root | [`sound/`](https://github.com/goonstation/goonstation/tree/1b2b250abb5be747d55e274de0203a59cfc8da78/sound) |
| Current map source | [`maps/atlas.dmm`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/maps/atlas.dmm) |
| Broad sprite credits | [`spriters.txt`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/strings/changelog_attribution/spriters.txt) |
| Audio sourcing guidance | [Pinned audio guidelines](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/.github/AUDIO_GUIDELINES.md) |

Imports must use this exact immutable commit, never a moving branch or release
label. A source update is a new reviewed import, not an in-place mutation of
the recorded snapshot.

## Current native-map derivative

The first-party
[`goon-atlas` scenario](../../mods/org.simstation.core/scenarios/goon-atlas.json)
is a direct adapted map derivative under the same Goon root license:

| Field | Recorded value |
|---|---|
| Source path | `maps/atlas.dmm` |
| Commit | `1b2b250abb5be747d55e274de0203a59cfc8da78` |
| Git blob | `a774a5beaa5fe849495de1eabe2173dca59ddfdd` |
| Source SHA-256 | `694305dc6a227824572b49f4ecb58accb62ef5892a94132420d19f94520d8909` |
| Source crop | X 61–252, Y 61–252, Z 1 |
| Coordinate change | Source Y is flipped to native top-left/downward Y |
| Converter | `tools/map_import.py`, format 1, `goon-type-path-adapter-v1` |
| Output | `simstation-map-v1`, 192×192 |
| License | `CC-BY-NC-SA-3.0-US` |

The conversion maps reviewed turf, structure, area, cable, fixture, and job
landmark families into a smaller native behavior vocabulary. It does not
execute DM or evaluate map override expressions. The generated definition
records 2,721 included and 4,712 omitted object instances, the top unsupported
paths, four lower-priority fixture collisions, two invalid APC placements, and
one duplicate spawn. That omission record is attribution/review evidence, not
a claim that omitted Goon behavior was reproduced.

The immutable source bytes are included under
`assets/upstream/goon/maps/atlas.dmm` and in the 5,869-file upstream inventory.
The runtime reads only the native JSON. Any source-commit update, crop change,
adapter change, or omission-policy change requires regenerating and reviewing
both scenario provenance and notices.

## Required per-asset record

Every imported source and every generated derivative must resolve to one
record with these fields:

| Field | Meaning |
|---|---|
| `asset_id` | Stable namespaced Sim Station identifier |
| `kind` | `graphics`, `audio`, `map`, `data`, `font`, or another registered kind |
| `source_repository` | Canonical upstream repository URL |
| `source_commit` | Full immutable commit hash |
| `source_path` | Exact case-sensitive repository path |
| `source_blob_id` | Upstream Git blob identifier when available |
| `source_sha256` | SHA-256 of imported bytes |
| `license_expression` | SPDX expression or documented non-SPDX license reference |
| `rights_basis` | Evidence category, such as `goon-root-license` or `file-specific-license` |
| `authors` | Known authors/contributors without invented identities |
| `attribution` | Text and links required in credits |
| `evidence` | File notices, commit/PR links, tags, or other supporting records |
| `modifications` | Ordered, human-readable change declarations |
| `tool` / `tool_version` | Converter identity and pinned version |
| `command` | Reproducible invocation with machine-specific paths removed |
| `outputs` | Output path, media properties, and SHA-256 |
| `review_status` | `accepted`, `needs-review`, `incompatible`, `replaced`, or `omitted` |
| `review_notes` | Evidence-backed explanation of the status |

Do not infer a person from a filename or claim authorship not supported by
evidence. An unknown author is recorded as unknown while retaining the
Goonstation project attribution.

## Immutable source and editable fork

- Immutable upstream DMI and audio inputs are stored byte-for-byte through Git
  LFS.
- Sim Station's editable graphics fork uses lossless PNG sheets plus TOML
  metadata. Original compressed audio is retained; non-destructive runtime
  gain and classification live in metadata.
- Pinned DMM remains immutable. Native scenario JSON is the reviewed map fork;
  DMM and DM code are never runtime formats.
- Generated atlases, indexes, tracker renders, contact sheets, and reports are
  reproducible outputs. Contributors must not hand-edit them.
- Build-cache keys include source SHA-256, converter version, conversion
  configuration, and relevant tool versions.
- A generated artifact is stale if any cache-key component changes.

## Change declarations

At minimum, record:

- DMI extraction and metadata normalization;
- atlas packing, cell deduplication, or gutter extrusion;
- recoloring, redrawing, compositing, scaling, or state renaming;
- audio decoding, mixing, trimming, channel conversion, resampling, tracker
  rendering, or gain metadata;
- logical aliases and storage deduplication;
- content replacement or omission and its reason.

“Converted” alone is not a sufficient modification notice.

## Update procedure

1. Select and record a full upstream commit after reviewing its root and
   file-specific license changes.
2. Fetch into a temporary import workspace and verify the commit identity.
3. Produce source inventories and compare them with the previous import by
   path, blob ID, byte hash, media type, and file notice.
4. Regenerate graphics contact sheets, DMI semantic reports, audio properties,
   duplicate groups, loudness reports, and attribution candidates.
5. Preserve local fork edits as explicit transformations; never overwrite them
   silently with new upstream bytes.
6. Re-run file-specific rights checks and mark conflicts.
7. Review changed visual cells and audio outputs.
8. Regenerate all derived artifacts, notices, and the SPDX SBOM.
9. Require deterministic output hashes from two clean builds.
10. Record the update in release notes with old/new commit IDs and material
    changes.

Automatic tracking of Goonstation `master` is prohibited. Imports are manual,
pinned, reviewable batches.

## Removal and takedown

When credible rights information contradicts the recorded basis:

1. mark the asset `needs-review` immediately;
2. prevent new release builds from including it;
3. preserve the evidence and affected release list;
4. replace, omit, or obtain permission;
5. regenerate aliases, atlases/audio bundles, notices, provenance, and SBOM;
6. publish a corrective release when prior packages are affected.

Do not erase provenance history when removing content. The record should state
that the asset was omitted and why, without continuing to distribute the
disputed bytes.
