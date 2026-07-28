# Third-party notices, licenses, and SBOM

## Required release artifacts

Every source tag and binary release must generate and ship:

| Artifact | Purpose |
|---|---|
| `THIRD_PARTY_NOTICES.md` | Human-readable projects, authors, licenses, source links, modifications, and required notices |
| `sbom.spdx.json` | SPDX 2.3 JSON software bill of materials for code dependencies, tools whose output is shipped, and packaged content bundles |
| `asset-provenance.json` | Per-source and per-output records defined by the provenance policy |
| `asset-credits.md` | Human-readable graphics, audio, map, font, and other creative credits |
| `LICENSES/` | Canonical text for every license represented in the package |
| `build-manifest.json` | Game build, exact mod/content locklist, source revisions, compiler versions, file hashes, and links to the other artifacts |

Large asset inventories may be summarized in `THIRD_PARTY_NOTICES.md`, but the
complete per-file records must remain in `asset-provenance.json`. A human must
be able to discover the source and license without reading source code.

## Minimum notice entry

Each dependency or content source entry includes:

- name and stable package/content ID;
- version, commit, or immutable source identifier;
- homepage and exact source URL;
- authors/copyright holders as known;
- SPDX license expression and path to license text;
- whether it is modified;
- concise material-change summary;
- shipped file or bundle relationship;
- required attribution text and upstream notices;
- provenance/SBOM relationship identifiers.

Do not collapse distinct file-specific licenses into a project-wide label.

## SPDX policy

- Emit SPDX 2.3 JSON.
- Use SHA-256 checksums for shipped files and packages.
- Give each dependency and distributable content pack an SPDX package.
- Represent generated atlas and audio bundles as files related to their source
  packages with `GENERATED_FROM` or the closest valid SPDX relationship.
- Use SPDX license identifiers when available. Put non-SPDX or unusually
  scoped text in `LicenseRef-*` entries and include the complete extracted
  text.
- Mark build tools that are not distributed separately from runtime
  dependencies while still recording their versions in `build-manifest.json`.
- Record optional and development-only dependencies; clearly distinguish them
  from shipped runtime components.
- Include mod packages in a release or save-specific locklist, not in the base
  release SBOM unless they ship with that release.

## Generation and verification

1. Read only lockfiles, vendored manifests, content manifests, provenance
   records, and generated output hashes. Do not scrape licenses from mutable
   network pages during a release build.
2. Fail on an absent version, source URL, license expression, required license
   text, provenance record, or shipped-file hash.
3. Compare the final packaged file list with the SBOM and provenance outputs.
4. Fail on an unexplained packaged file or a referenced output that is absent.
5. Validate SPDX JSON against its schema.
6. Rebuild notices and the SBOM after every dependency, mod, asset, compiler,
   or pinned-upstream change.
7. Store generated artifacts with the release tag and include them inside each
   platform package.

## Runtime display

The game's Credits/Legal screen must provide:

- Sim Station's license summary and noncommercial status;
- Goonstation attribution, pinned source commit, license, and no-endorsement
  statement;
- browsable asset credits;
- code dependency notices;
- a way to open or copy the full notice and license paths from the installed
  package.

The screen must remain reachable without loading a campaign or enabling
network access.
