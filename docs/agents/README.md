# Agent research archive

This directory preserves the externally observable work used to develop Sim
Station's design. It exists so later contributors can recover the evidence,
trade-offs, and decisions behind the design without relying on a chat session.

## What is archived

Each agent record contains:

- the assignment, reconstructed only when the original assignment text is not
  available;
- the last observable status and the chronology that can be supported by the
  planning record;
- a verbatim final report when one remains available;
- otherwise, the consolidated findings that were visible to the lead agent;
- sources cited by the work;
- which recommendations were accepted, adapted, rejected, or left unresolved.

The machine-readable index is [`manifest.json`](manifest.json). The human
records are:

- [`architecture-scope.md`](architecture-scope.md) — Faraday /
  `architecture_scope`
- [`machine-fidelity-architecture.md`](machine-fidelity-architecture.md) —
  Faraday / resumed `architecture_scope` machine-fidelity episode
- [`power-machine-fidelity.md`](power-machine-fidelity.md) —
  `architecture_scope/power_machine_research`
- [`atmos-production-cargo-fidelity.md`](atmos-production-cargo-fidelity.md) —
  `architecture_scope/atmos_prod_cargo_research`
- [`machine-research-archive.md`](machine-research-archive.md) —
  `archive_machine_research`
- [`tile-source-coverage.md`](tile-source-coverage.md) —
  resumed `archive_machine_research` tile/source coverage episode
- [`machine-fidelity-tests.md`](machine-fidelity-tests.md) —
  `machine_fidelity_tests`
- [`tile-interaction-tests.md`](tile-interaction-tests.md) —
  resumed `machine_fidelity_tests` tile-interaction episode
- [`machine-docs-renderer.md`](machine-docs-renderer.md) —
  `machine_docs_renderer`
- [`tile-interaction-docs.md`](tile-interaction-docs.md) —
  resumed `machine_docs_renderer` world-interaction fidelity episode
- [`pixel-viewport-audit.md`](pixel-viewport-audit.md) —
  `pixel_viewport_audit`
- [`goon-graphics-pipeline.md`](goon-graphics-pipeline.md) — Harvey /
  `goon_graphics_pipeline`
- [`love-render-assets.md`](love-render-assets.md) — Kierkegaard /
  `love_render_assets`
- [`goon-audio-pipeline.md`](goon-audio-pipeline.md) —
  `goon_audio_pipeline`
- [`agent-archive-legal.md`](agent-archive-legal.md) —
  `agent_archive_legal`
- [`design-docs.md`](design-docs.md) — Mendel / `design_docs`
- [`technical-docs.md`](technical-docs.md) — `technical_docs`
- [`runtime-media.md`](runtime-media.md) — `runtime_media`
- [`maintainability-ci.md`](maintainability-ci.md) —
  `maintainability_ci`
- [`goon-map-pipeline.md`](goon-map-pipeline.md) —
  `goon_map_pipeline`
- [`goon-interaction-research.md`](goon-interaction-research.md) —
  `goon_interaction_research`
- [`scenario-contract.md`](scenario-contract.md) —
  `scenario_contract`
- [`goon-fixture-assets.md`](goon-fixture-assets.md) —
  `fixture_asset_pack`
- [`native-scenario-example.md`](native-scenario-example.md) —
  `native_scenario_example`
- [`atlas-docs-polish.md`](atlas-docs-polish.md) —
  `atlas_docs_polish`

Use [`TEMPLATE.md`](TEMPLATE.md) for future records.

## Evidence labels

- **Verbatim** means the text was available as a visible agent response and is
  reproduced without intentionally changing its meaning.
- **Consolidated** means the full response was no longer available, but its
  findings were retained in the lead agent's planning record.
- **Decision** means the project owner accepted or selected the policy.
- **Reconstruction** means wording was inferred from the task name, subsequent
  questions, or the approved plan. It is not represented as a transcript.

## Limitations

This archive cannot contain hidden chain-of-thought, private model state,
internal sampling traces, or messages that were not exposed to the lead agent.
Those materials are neither available nor appropriate to reconstruct.
Chronology is therefore event-ordered rather than timestamp-exact where the
interface did not expose timestamps. Missing dialogue is called out rather than
invented.

Future agents should be archived while their visible output is still
available. Record their canonical task name, assignment, status changes,
visible reports, sources, and the decisions their work affected. Do not claim
to preserve private reasoning.
