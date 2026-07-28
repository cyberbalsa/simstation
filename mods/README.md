# Bundled content and compatibility mods

`org.simstation.core/` is the first-party data pack. The executable foundation
discovers it with the same manifest parser, dependency resolver, registry, and
replacement rules used for user packs.

`examples/` contains release compatibility fixtures:

- `org.simstation.example.catering` adds a data-only job, items, localization,
  and a two-stage recipe;
- `org.simstation.example.av-swap` explicitly replaces one core presentation
  definition;
- `org.simstation.example.salvage-scenario` adds a data-only starting scenario;
- `org.simstation.example.smart-grid` registers trusted Lua validation,
  transform, and observer hooks with versioned state.

Validate a folder, prove folder/archive registry parity, or build a
byte-reproducible package:

```sh
python3 tools/dev.py mod validate mods/examples/org.simstation.example.catering
python3 tools/dev.py mod test mods/examples/org.simstation.example.catering
python3 tools/dev.py mod package mods/examples/org.simstation.example.catering
```

During play, put folder packs or `.simmod` files directly below the save
directory's `mods/` folder. Code entrypoints run only when `mods/trust.json`
maps the pack ID to its exact validated tree/archive SHA-256. Updating any byte
invalidates that approval.

The runtime TOML reader intentionally accepts only the closed schema-1 manifest
subset. The Python validator uses the standard-library TOML parser and is the
packaging authority. See [`docs/modding`](../docs/modding/README.md) for the
full contract and security limits.
