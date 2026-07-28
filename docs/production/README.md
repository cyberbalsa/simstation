# Production specification

Production is milestone-gated, documentation-first, and benchmark-driven. A
milestone is complete only when its player outcome, public contracts, tests,
performance evidence, provenance, and handoff material are complete. A broad
prototype that bypasses those gates does not advance the roadmap.

## Documents

- [Playable vertical slice](01-vertical-slice.md)
- [Roadmap and milestone gates](02-roadmap.md)
- [Change, release, and maintenance process](03-release-and-maintenance.md)

## Definition of done

Every behavior change must include, as applicable:

- updated player/system design;
- authoritative state owner, units, cadence, ordering, visibility, and failure
  recovery;
- command/event/data/hook/save contracts and migration decision;
- core deterministic tests plus content/media fixtures;
- UI, localization, accessibility, and explainability;
- measured performance impact on a representative scenario;
- provenance/license/notices changes;
- updated example mod or compatibility note; and
- `python3 tools/dev.py audit` passing.

Generated assets are never the sole reviewed representation of a creative
change. Review the editable source and generated visual/audio report together.

## Branch and version policy

- `main` is releasable and protected by audit/CI.
- Work uses focused branches and reviewable commits.
- Game versions use SemVer. Before 1.0, minor versions are milestone releases.
- Save, content, asset, audio, and mod API schemas are versioned independently.
- Release tags are signed `vMAJOR.MINOR.PATCH`.
- No automatic upstream Goon sync, dependency merge, mod upgrade, save rewrite,
  or generated-asset overwrite is permitted.
