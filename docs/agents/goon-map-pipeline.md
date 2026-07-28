# Goon map pipeline agent

## Record

- Canonical task: `/root/goon_map_pipeline`
- Display name: not surfaced by the collaboration interface
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: implementation and local validation completed
- Assignment availability: verbatim
- Report availability: normalized visible report

### Assignment

> Continue Sim Station using the pinned local Goonstation checkout at
> assets/cache/goonstation commit 1b2b250a. Concrete bounded task: inspect
> DMM/map source structure and build a deterministic READ-ONLY inventory/analyzer
> or converter prototype under new tools/map_import.py (and new fixture/tests
> only if isolated) that can parse TGM/DMM key dictionaries, dimensions/z-levels,
> turf/area/object paths, and emit a compact JSON analysis suitable for
> selecting/importing a representative map. Do not alter existing runtime/core
> files or generated media. Preserve upstream bytes, no network. Document
> observable assignment, files, chosen grammar, limitations, commands, and
> validation in docs/agents/goon-map-pipeline.md. Do not edit docs/agents
> README/manifest; root will index it. Send a concise final report and then make
> no further edits.

## Observable chronology

1. Confirmed the local Goon checkout was at the locked commit
   `1b2b250abb5be747d55e274de0203a59cfc8da78`. It was initially sparse, so
   map discovery used the Git tree rather than assuming every blob was present
   in the working tree.
2. Inspected the full Git tree and found 570 `.dmm` files and no `.tgm`
   extension files. Every map carries Goon's `dmm2tgm.py` conversion marker,
   so the corpus is TGM-formatted DMM.
3. Inspected representative full-station maps, prefabs, Goon's
   `code/z_dmm_suite/reader.dm`, `writer.dm`, and map settings. The writer
   emits one X column per TGM coordinate block; the reader reverses textual
   rows so the first grid row maps to the highest Y coordinate.
4. Implemented a read-only parser and analyzer that reads immutable Git blobs
   through `git cat-file --batch`, checks the commit against the project
   upstream lock, and writes deterministic JSON only to stdout.
5. Added isolated TGM and conventional DMM fixtures plus six Python unit tests.
   The fixtures cover multi-character keys, classic concatenated rows, multiple
   z-levels, object overrides, Y orientation, adjacency, validation, and
   malformed input.
6. Parsed the complete 570-map corpus. All maps passed the grammar. Four maps
   carry semantic irregularities reported rather than hidden: one empty
   dictionary model used by one cell, one prefab with 44 cells lacking areas,
   and two maps with layered/multiple turf records.
7. Repeated default inventory and Cogmap analysis runs byte-for-byte to confirm
   deterministic output.

## Files added

- `tools/map_import.py`
- `tests/test_map_import.py`
- `tests/fixtures/maps/tgm_minimal.dmm`
- `tests/fixtures/maps/dmm_minimal.dmm`
- `docs/agents/goon-map-pipeline.md`

No runtime, core, generated-media, or upstream file was changed.

## Chosen grammar and analysis contract

The parser accepts:

- UTF-8 DMM text with DM whitespace, `//` comments, and `/* ... */` comments;
- fixed-width quoted model keys;
- model tuples containing `/area`, `/turf`, `/obj`, `/mob`, or other type
  paths;
- optional balanced `{ ... }` map overrides, with top-level override variable
  names recorded while values remain opaque;
- coordinate blocks of the form `(x,y,z) = {"..."}`;
- Goon TGM singleton-column payloads and conventional DMM rows containing
  concatenated fixed-width keys;
- multiple coordinate blocks and z-levels;
- the DMM/Goon Y-axis convention in which textual grid rows are reversed when
  materialized.

`inventory` defaults to direct files under `maps/`, producing a compact
comparison of the main maps. Each record includes immutable source identity,
key width, dictionary/block counts, per-z bounds, mapped cells, unique and
placed atom counts, and selection signals for station areas, department
families, non-space turfs, machinery, object density, and map fill.

`analyze` adds ranked path counts, department sizes, per-area bounds and object
placements, cardinal area adjacencies, and override-variable frequencies. All
ranked sections use count-descending/path-ascending order, coordinate
materialization is stable, JSON keys are sorted, and no wall-clock fields are
emitted.

Structural validation reports overlapping cell writes, unknown/unused keys,
and cells with missing or multiple turf/area atoms. Parser failures and
structural warnings are distinct: inventory exits nonzero for grammar failures
but preserves valid analysis for unusual source models.

## Representative-map evidence

The default inventory found 20 direct `maps/` candidates. `maps/cogmap.dmm` is
a useful first import/reference candidate because it is a conventional,
space-based station with broad department coverage while being smaller than
the densest maps:

- one 300×300 z-level and 90,000 mapped cells;
- key width 3, 7,254 dictionary models, and 300 TGM coordinate blocks;
- 12,736 station-area cells across 25 first-level department families;
- 14,330 non-space turf placements;
- 22,544 object placements, including 5,048 machinery placements;
- 156 unique area paths, 122 unique turf paths, and 1,613 unique object paths;
- no unknown keys, overlaps, unused models, or missing/multiple turf/area
  records.

Cogmap2 and Donut3 are denser follow-up references. The analyzer intentionally
reports measurements instead of assigning a subjective score, so a future
import decision can weigh scope, topology, and content density explicitly.

## Commands

```text
python3 tools/map_import.py inventory
python3 tools/map_import.py inventory --prefix maps/ --max-depth 1 --pretty
python3 tools/map_import.py inventory --prefix '' --max-depth -1
python3 tools/map_import.py analyze maps/cogmap.dmm --top 25 --pretty
python3 -m unittest -v tests.test_map_import
python3 -m py_compile tools/map_import.py tests/test_map_import.py
```

The default output is compact JSON. `--pretty` changes whitespace only.
`--allow-unpinned` exists for deliberate future research; without it, the tool
refuses a Git revision that differs from the upstream lock.

## Validation evidence

- Six fixture tests passed.
- Python bytecode compilation passed.
- Black formatting checks passed.
- Default inventory parsed all 20 direct station-map candidates.
- Full inventory parsed all 570 tracked maps in about seven seconds with zero
  grammar failures.
- Full-corpus structural reporting identified four source irregularities
  without crashing or silently normalizing them.
- Cogmap analysis completed with clean structural validation.
- Two default inventories compared byte-for-byte.
- Two Cogmap analyses compared byte-for-byte.

## Limitations

- This is an analyzer, not a runtime map converter. It does not write imported
  maps or mutate the upstream checkout.
- DM expressions and override values are preserved as opaque syntax; the tool
  does not execute DM, resolve inheritance, evaluate macros, or infer behavior
  from implementation code.
- Area profiles and adjacency choose the first area atom when a source cell has
  multiple areas, and object placement uses every `/obj` atom. Multiple
  turf/area records remain visible as validation issues.
- Adjacency counts cardinal shared tile edges. They are not a traversability
  graph and do not yet account for door state, access control, windows,
  vertical travel, pipes, cables, or disposal networks.
- JSON ranked sections are intentionally capped by `--top`; aggregate totals
  remain complete.
- Source must be available in the local Git object database. A sparse working
  tree is supported, but a partial clone that has not fetched the requested
  blob is not.
- Maps must be valid UTF-8. Every file in the pinned corpus satisfied this
  constraint.

## Source references

- Pinned map: `assets/cache/goonstation/maps/cogmap.dmm`
- Git-only/sparse maps: `assets/cache/goonstation/assets/maps/`
- Goon reader: `assets/cache/goonstation/code/z_dmm_suite/reader.dm`
- Goon writer: `assets/cache/goonstation/code/z_dmm_suite/writer.dm`
- Goon map settings: `assets/cache/goonstation/code/map.dm`
- Project source lock: `assets/upstream/goon/upstream.lock.toml`

This record contains externally observable assignment, work, decisions,
outputs, and validation only. It does not contain hidden reasoning, private
model state, or unavailable dialogue.
