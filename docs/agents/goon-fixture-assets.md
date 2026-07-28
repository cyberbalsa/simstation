# Goon fixture assets — foundation media aliases

## Record

- Canonical task: `/root/fixture_asset_pack`
- Display name: Goon Fixture Assets
- Parent task: `/root`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible report
- Assignment availability: verbatim

### Assignment

> Implement the bounded fixture-art subtask for this milestone. Inspect
> AGENTS.md and existing foundation asset pipeline/runtime atlas manifests.
> Reuse already fetched/pinned Goonstation DMI source sprites to add native
> LÖVE aliases for representative APC, generator, vent, scrubber,
> manufacturer/fabricator, and refinery machines. Modify only tools/assets.py
> plus generated foundation asset outputs/manifests that command owns,
> relevant asset tests if essential, and write a full work/state report to
> docs/agents/goon-fixture-assets.md. Do not edit Lua runtime, map importer,
> global docs indexes, or source lock. Preserve provenance/determinism and run
> focused validations. Report exact aliases/paths and license/provenance
> considerations. Other agents share workspace; avoid unrelated files.

## Observable chronology

1. Read the repository working agreement, `tools/assets.py`, the exhaustive
   compiled atlas catalog, and the existing foundation media selection.
2. Resolved candidate IDs against the 46,160-record pinned atlas instead of
   constructing IDs from memory.
3. Checked the pinned DM definitions for permanent vent pumps, permanent vent
   scrubbers, the thermoelectric generator, general manufacturer, and refining
   nanofabricator. This selected map-facing machinery states rather than
   similarly named portable/decorative sprites.
4. Added six aliases to `FOUNDATION_SPRITES`.
5. Strengthened the asset audit so an old or mismatched foundation alias set is
   rejected even when the exhaustive atlas itself is unchanged.
6. Regenerated `assets/runtime/goon/graphics/foundation.json` with the existing
   deterministic postprocessor. No atlas page, upstream source, source fork,
   audio file, lock file, or Lua file was changed.
7. Ran focused syntax, generation, provenance, catalog, and hash validation.

## Selected aliases

All sources come from Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`. Atlas pages and coordinates are
recorded here only as audit evidence; runtime code should resolve the alias
through `foundation.json`.

| Alias | Generated sprite ID | Pinned DMI and state | Source SHA-256 | Atlas evidence |
| --- | --- | --- | --- | --- |
| `apc` | `org.simstation.goon:sprite/icons/obj/power-dmi/apc0--afcf739cd9-o01` | `icons/obj/power.dmi`, `apc0` | `dd790234dfab468300fe96ecfc4e88898fedd366f4b701c18aaccb069adb7ba7` | `specialty` page 53; four directions |
| `generator` | `org.simstation.goon:sprite/icons/obj/power-dmi/teg--7c8224529a-o01` | `icons/obj/power.dmi`, `teg` | `dd790234dfab468300fe96ecfc4e88898fedd366f4b701c18aaccb069adb7ba7` | `specialty` page 53; south |
| `vent` | `org.simstation.goon:sprite/icons/obj/atmospherics/vent_pump-dmi/out-map--60b67c84ae-o01` | `icons/obj/atmospherics/vent_pump.dmi`, `out-map` | `95cd3421f7966f4a43fa1887293bc4181b562386d3d3c67fb6d83bc309854b35` | `specialty` page 45; four directions |
| `scrubber` | `org.simstation.goon:sprite/icons/obj/atmospherics/vent_scrubber-dmi/on-map--a3645389b9-o01` | `icons/obj/atmospherics/vent_scrubber.dmi`, `on-map` | `07763391b66cf080cdb82a0ce3a9e31891b34a3944678ffed9fc8160acaade9c` | `specialty` page 45; four directions |
| `fabricator` | `org.simstation.goon:sprite/icons/obj/manufacturer-dmi/fab-general--cf2f46a0d3-o01` | `icons/obj/manufacturer.dmi`, `fab-general` | `2eac0861868f8256c25b7fe5188742b3f2c3500ff0d25dd76d85a3b765693d1a` | `specialty` page 52; south |
| `refinery` | `org.simstation.goon:sprite/icons/obj/crafting-dmi/fab2-on--e654caa777-o01` | `icons/obj/crafting.dmi`, `fab2-on` | `c0ad888d26f13702fa15e01d17c659755c93356ddea24a844ab5c5b1dfd7881c` | `specialty` page 47; south |

### Selection rationale

- `apc0` is the directional base APC appearance used by the area-power
  machinery family.
- `teg` is Goonstation's thermoelectric station generator appearance. It is a
  clearer station-generation reference than the small local-generator
  `ggen0` state.
- `out-map` is the initial map appearance declared by
  `/obj/machinery/atmospherics/unary/vent_pump`.
- `on-map` is the initial map appearance declared by
  `/obj/machinery/atmospherics/unary/vent_scrubber`.
- `fab-general` is the general manufacturer base appearance and maps cleanly
  to Sim Station's shorter `fabricator` fixture vocabulary.
- `fab2-on` is the powered appearance of the nanofabricator family used by the
  refining subtype.

The vent and scrubber choices intentionally do not use `vent1` and
`scrubber:1` from `icons/obj/atmospherics/atmos.dmi`; those records depict
different/portable atmos equipment and do not match the permanent unary
machines being adapted.

## Generated selection

`build-foundation-media` now emits 12 sprite aliases across eight already
compiled pages:

- `core_tiles` pages 0 and 1;
- `crew` page 5;
- `machines` page 0;
- `specialty` pages 45, 47, 52, and 53.

The four added specialty PNG pages were already tracked Git LFS objects and
were not regenerated or modified by this task. The compact
`foundation.json` remains ordinary reviewable JSON. Its post-generation
SHA-256 is
`acca42ef132e85055dca350ce565f029a92765c98adfc818311bcd7c751a2bb7`.
Its `full_catalog_sha256` remains
`a97a12921de56ad3a40ddc8ae2330af6cb50a2a17cb39122c87009661e7a55df`.

## Provenance and license boundary

These are direct selections of Goonstation pixel art, not newly authored
Sim Station graphics. Their immutable source files remain under
`assets/upstream/goon/`; editable/source and compiled catalogs retain the
source path, commit, source SHA-256, original DMI state, and generated stable
ID. `assets/runtime/goon/graphics/provenance.json` identifies the repository,
commit, generator, catalog digest, and `CC-BY-NC-SA-3.0-US` license.

Accordingly, distributing these aliases and their atlas pages remains inside
the project's Goon-derived, attribution-required, noncommercial,
share-alike asset boundary. The aliases do not relicense the pixels as MIT.
Any future replacement with original art should receive a new content ID and
provenance record rather than silently reusing these IDs.

## Files changed by this task

- `tools/assets.py`
  - six new deterministic foundation aliases;
  - audit checks for exact alias names and target sprite IDs.
- `assets/runtime/goon/graphics/foundation.json`
  - regenerated selection containing the six records and four additional
    existing specialty-page references.
- `docs/agents/goon-fixture-assets.md`
  - this state and provenance report.

No tests were added because no asset format or parser contract changed. The
existing generator plus the new exact-alias audit directly exercise this
selection change.

## Validation evidence

Completed successfully:

```text
python3 -m py_compile tools/assets.py
python3 tools/assets.py build-foundation-media
  foundation media complete: 12 sprites, 8 atlas pages, 11 audio entries
python3 tools/assets.py audit
  upstream inventory ok: 5,868 files
  graphics source fork ok: 1,159 files
  graphics catalog ok: 46,160 sprites
  foundation graphics ok: 12 sprites, 8 pages
  audio catalog ok: 4,699 files
  foundation audio ok: 11 sounds
```

`git lfs ls-files` also confirmed that specialty pages 45, 47, 52, and 53 are
tracked LFS objects with hashes matching their atlas records.

The required repository-wide `python3 tools/dev.py audit` also passed:
12 deterministic Lua tests, Python compilation, five mod validations, asset
audit, whitespace/JSON/TOML checks, core-boundary checks, Markdown links,
workflow pins, and Git LFS configuration were all clean.

## Handoff state

The LÖVE presentation layer can now request the six short aliases from the
existing foundation graphics loader. Directional APC, vent, and scrubber
records expose the standard `south`, `north`, `east`, and `west` directions;
generator, fabricator, and refinery expose `south`. Runtime integration was
deliberately left to the parent task.

The worktree also contained concurrent scenario/core/map-import changes owned
by other agents. They were observed but neither edited nor validated by this
task.
