# Asset layout

- `upstream/goon/` contains immutable files from the pinned Goon commit and
  their blob/hash inventory: graphics/audio inputs, required notices, and the
  exact `maps/atlas.dmm` source used by the first native station.
- `source/goon/` contains Sim Station's editable PNG/TOML graphics fork and
  preserved audio masters.
- `runtime/goon/` contains generated LÖVE-ready PNG atlases, Ogg audio, and
  versioned catalogs.
- `fixtures/` contains tiny distributable test inputs.
- `cache/` and `staging/` are ignored build workspaces.

All binary paths are assigned to Git LFS. Generated output must be rebuilt with
`python3 tools/assets.py all`; never edit it manually.

The current upstream inventory contains 5,869 files. Atlas is a provenance and
authoring input, not a LÖVE runtime format. `tools/map_import.py` reads its
immutable Git blob, applies the reviewed schema-1 adapter, and writes the
generated native definition at
`mods/org.simstation.core/scenarios/goon-atlas.json`. Rebuild it with the exact
command in the [repository README](../README.md#repository-policy). Runtime
startup reads only that native JSON; it never parses DMM or executes DM.

Targeted verification is intentionally separate from regeneration:

```sh
python3 tools/assets.py audit
python3 tools/assets.py verify-graphics
python3 tools/assets.py verify-audio
```

`verify-graphics` compares all 164,558 compiled frame-direction cells against
their pinned lossless source pixels. `verify-audio` hashes every runtime file,
proves all source Ogg files remained byte-identical, and probes every tracker
conversion.

The compact foundation graphics catalog currently exposes 12 logical aliases
across eight already compiled pages: floor, wall, two door states, two crew
states, APC, generator, vent, scrubber, fabricator, and refinery. The source
DMI records, atlas coordinates, hashes, and selection rationale are preserved
in [`docs/agents/goon-fixture-assets.md`](../docs/agents/goon-fixture-assets.md).
