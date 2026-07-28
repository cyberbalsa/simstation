# Sim Station documentation

Sim Station is a single-player station-management simulation built with LÖVE. The
player acts as an off-station director: they shape the station through
construction, zoning, budgets, staffing, policies, priorities, and emergency
orders while autonomous crew perform the work.

The documentation is normative. When prose, prototypes, and code disagree, the
versioned contracts in this directory win until an explicit design change updates
both the relevant document and its acceptance tests.

## Document map

- [Design index](design/README.md) — product contract, shared rules, systems, and
  acceptance criteria.
- [Technical index](technical/README.md) — runtime architecture, persistence,
  rendering, audio, libraries, performance, and packaging.
- [Modding index](modding/README.md) — package format, loading, hooks, trusted
  Lua, authoring, and compatibility policy.
- [Production index](production/README.md) — vertical slice, roadmap, release,
  and maintenance gates.
- [Agent archive](agents/README.md) — durable records of delegated work and
  decisions.
- [Legal index](legal/README.md) — licensing, attribution, provenance, and
  release policy.

## Reading order

1. Read the [product contract](design/00-product-contract.md).
2. Read [simulation foundations](design/01-simulation-foundations.md) for the
   units, time model, command/event contracts, information rules, and common
   system template.
3. Read the system documents relevant to the feature being changed.
4. Check the [cross-system matrix](design/12-cross-system-matrix.md) before
   changing a public event, resource, or ownership boundary.
5. Use the [glossary](design/13-glossary.md) for canonical terminology.

## Change rule

A system change is complete only when it updates:

1. player-visible behavior;
2. authoritative state and units;
3. cadence and deterministic ordering;
4. data schemas and mod hooks;
5. save/migration requirements;
6. cross-system inputs and outputs;
7. failure and recovery behavior; and
8. automated acceptance scenarios.

No design may give the player direct control over a crew member, expose hidden
motives without an in-world observation, introduce a second station deck, or
make a native/FFI dependency mandatory without first revising the product
contract.
