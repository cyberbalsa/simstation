# Goonstation audio rights risk

## Selected policy

The project owner selected the following policy for the complete pinned
Goonstation audio import:

- treat the pinned Goonstation root license and README statement as sufficient
  initial authority to import an audio file;
- set its default provenance basis to `goon-root-license`;
- do not quarantine a file solely because historical source attribution has
  not yet been found;
- preserve all stronger attribution and license evidence that is discovered;
- block release of a file when explicit evidence shows an incompatible license
  or restriction.

This is a conscious risk acceptance, not a finding that every file has a
perfect chain of title.

## Why residual risk exists

The pinned root
[`LICENSE`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE)
applies CC BY-NC-SA 3.0 US to the work, and the pinned
[`README`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/README.md#license)
says all Goonstation contributions use that license except `tgui`, which is
generally MIT unless otherwise specified.

However, Goonstation's pinned
[`AUDIO_GUIDELINES.md`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/.github/AUDIO_GUIDELINES.md)
explicitly discusses sourcing effects from services such as Freesound and tells
contributors to inspect and satisfy the original license. That creates a
plausible risk that some repository files originated under separate
attribution or use conditions that need to be carried forward.

A repository-level license statement is useful evidence, but it cannot cure a
third-party rights problem if a contributor lacked authority to relicense the
source. Only a qualified legal review can assess that risk conclusively.

## Required mitigations

- Retain every upstream audio file byte-for-byte with its pinned path, commit,
  blob ID, and SHA-256.
- Search adjacent files, Git history, commit messages, pull requests, tags,
  comments, and existing attribution for stronger evidence.
- Preserve source URLs, authors, titles, and license text whenever found.
- Generate a report of files whose only evidence is the root license, but do
  not automatically exclude them under the selected policy.
- Never erase or replace a file-specific notice with the root-license default.
- Treat “unknown historical author” differently from “explicit incompatible
  license.” The former is accepted risk; the latter is a release blocker.
- Maintain a contact and takedown process and the removal procedure defined in
  [`goon-provenance.md`](goon-provenance.md).
- Obtain legal review before a broadly promoted release or any change to the
  noncommercial model.

## Release decision table

| Evidence | Status | Release action |
|---|---|---|
| Root license only; no contrary evidence | Accepted risk | Include with Goonstation project attribution and `rights_basis = goon-root-license` |
| File-specific compatible license/attribution | Accepted | Include and preserve both the specific notice and applicable Goonstation notice |
| Missing historical author, no contrary evidence | Accepted risk | Include; state author is unknown and continue provenance research |
| Ambiguous note suggesting a conflicting source | Needs review | Hold the file until the ambiguity is resolved |
| Explicit incompatible or non-redistributable source | Incompatible | Exclude, replace, or obtain permission |
| Rights complaint with credible identifying detail | Needs review | Block from the next release while investigating |

## Risk register

| ID | Risk | Impact | Mitigation | Acceptance owner |
|---|---|---|---|---|
| AUDIO-01 | An upstream sample was contributed without authority to relicense it | Takedown, replacement work, reputational or legal exposure | Immutable provenance, historical research, release manifest, takedown path | Project owner |
| AUDIO-02 | Required attribution is omitted | License breach and contributor harm | Generated per-file credits and release validation | Release maintainer |
| AUDIO-03 | Conversion loses source/license linkage | Inability to prove or correct provenance | Content-addressed source/output records and deterministic converter logs | Asset-pipeline maintainer |
| AUDIO-04 | A commercial distributor treats the package as commercially usable | Violation of project policy and potential license breach | Prominent noncommercial notices in package, store metadata, and download page | Release maintainer |

The project owner may tighten this policy at any time. Relaxing it requires
documented legal review and an updated approved policy.
