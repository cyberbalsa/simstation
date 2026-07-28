# Asset layout

- `upstream/goon/` contains immutable files from the pinned Goon commit and
  their blob/hash inventory.
- `source/goon/` contains Sim Station's editable PNG/TOML graphics fork and
  preserved audio masters.
- `runtime/goon/` contains generated LÖVE-ready PNG atlases, Ogg audio, and
  versioned catalogs.
- `fixtures/` contains tiny distributable test inputs.
- `cache/` and `staging/` are ignored build workspaces.

All binary paths are assigned to Git LFS. Generated output must be rebuilt with
`python3 tools/assets.py all`; never edit it manually.

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
