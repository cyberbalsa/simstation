# Contributing to Sim Station

Sim Station is deliberately structured for small, reviewable changes by
humans and coding agents. Start with the [product contract](docs/design/00-product-contract.md)
and [`AGENTS.md`](AGENTS.md); both are part of the engineering contract.

## Local loop

Install LÖVE 11.5, LuaJIT or Lua, Python 3.11+, and Git LFS. Pillow and FFmpeg
are needed only for media imports.

```sh
git lfs pull
python3 tools/dev.py info
python3 tools/dev.py test
python3 tools/dev.py run
python3 tools/dev.py audit
```

Keep authoritative code under `src/core/` free of `love.*`. Commands are the
only player-input boundary, simulation order is stable, and authoritative
numbers are integers or documented fixed-point units. Add a deterministic
test whenever core behavior changes.

## Content and mods

Add gameplay definitions through a namespaced content pack instead of placing
new balance constants in presentation code. Use a folder pack while editing:

```sh
python3 tools/dev.py mod validate path/to/your-pack
python3 tools/dev.py mod test path/to/your-pack
python3 tools/dev.py mod package path/to/your-pack
```

Data-only mods are the preferred extension mechanism. Trusted Lua packs are
powerful and intentionally require player approval. The examples in
[`mods/examples`](mods/examples) are executable compatibility fixtures.

## Graphics and audio

Never edit `assets/runtime/` by hand. Goon DMI files are immutable provenance
inputs; edit the extracted PNG/TOML fork and regenerate. Existing Ogg files
stay byte-identical unless the provenance record documents a required
conversion.

New code contributions are MIT. New documentation is CC BY 4.0. Creative
content combined with the Goon-derived distribution must follow the
[license policy](docs/legal/license-architecture.md). Do not contribute media
without a source, author, license, and permission basis.

## Pull-request checklist

- The relevant design/public contract is updated.
- Tests cover deterministic behavior and failure paths.
- `python3 tools/dev.py audit` passes.
- Generated media is reproducible and has provenance.
- No unrelated user changes or generated caches are included.
- Save/mod compatibility impact is stated.
