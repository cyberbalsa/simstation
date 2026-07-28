# Agent archive and legal-policy agent

## Record

- Canonical task: `/root/agent_archive_legal`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Assignment availability: consolidated
- Report availability: consolidated visible completion report

### Assignment

Create a durable, honest archive under `docs/agents/` for every delegated
research task whose existence and output remained observable. Preserve visible
assignments and reports where available, explicitly label reconstructions, and
never invent hidden reasoning, internal model state, or missing dialogue.

Also author the mixed-license architecture and provenance policy for a
noncommercial Goonstation-derived release, including the project owner's
decision to rely initially on the Goon root license for all imported audio,
the residual risk, contribution policy, notices/SBOM requirements, and naming
constraints.

### Observable chronology

1. Created the agent archive format, template, human index, and JSON manifest.
2. Preserved the complete visible architecture report and consolidated
   graphics, rendering, and audio research whose full dialogue was no longer
   available.
3. Authored the legal index, license matrix, Goon provenance contract, audio
   rights-risk register, notices/SBOM requirements, contribution rules, and
   codename policy.
4. Distinguished the owner's accepted audio-risk choice from a legal finding.
5. Validated the archive manifest with `jq` and checked whitespace with
   `git diff --check`.

## Consolidated completion report

The agent reported that `docs/agents/**` and `docs/legal/**` were complete. The
archive included a README, template, machine-readable manifest, Faraday's full
visible report, and honestly consolidated records for Harvey, Kierkegaard, and
the audio pipeline. The legal suite documented public-source/noncommercial
classification, Goon provenance, the selected root-license audio policy,
SPDX/notices, contribution licensing, and naming. JSON and whitespace checks
passed.

## Decision disposition

### Accepted

- Only observable material is archived; hidden chain-of-thought is excluded.
- Original code is MIT while the bundled Goon-derived distribution remains
  CC BY-NC-SA 3.0 US and noncommercial.
- Root-license-only audio is accepted provisionally unless contrary evidence
  appears, with immutable provenance and a takedown path.

### Adapted

- Later agents add their own records and append the same manifest schema.
- Root `LICENSE` and `NOTICE` files provide a concise entrypoint to the
  detailed legal policy.

### Unresolved

- Legal review remains a release gate before broad public distribution.
- Historical per-file audio attribution remains ongoing work.

This is a consolidated observable record, not a reconstruction of hidden
reasoning or unavailable dialogue.
