# Repository working agreement

Sim Station separates deterministic simulation from LÖVE presentation.

- `src/core/` must remain pure Lua and must not reference `love.*`.
- Player actions enter the core only as serializable commands at tick
  boundaries.
- Do not use unordered table iteration in authoritative logic. Sort stable IDs.
- Authoritative quantities use integers or documented fixed-point units.
- Content IDs use `<reverse-dns-pack>:<kind>/<name>`.
- Base content is a first-party mod; never special-case an extension path that
  a normal mod cannot use.
- Generated assets are never edited by hand. Edit PNG/TOML source, then run
  the asset compiler.
- DMI is an immutable upstream/provenance input, never a runtime format.
- Existing Ogg files are copied byte-for-byte unless validation requires a
  documented conversion.
- Add deterministic tests for every core behavior and fixture tests for every
  data or asset format change.
- Update the corresponding design document when changing a public contract.

Use `python3 tools/dev.py audit` before handing work off.
