# Sim Station

Sim Station is a documentation-first, single-player station-management
simulation built with LÖVE 11.5. You direct construction, staffing, budgets,
production, and emergency policy while autonomous crew operate a detailed,
SS13-inspired station.

The name is a development codename. The project is a noncommercial,
public-source Goonstation derivative: original engine code is MIT, while
Goonstation-derived material remains CC BY-NC-SA 3.0 US.

This checkout contains a runnable foundation and the complete design contract,
not a finished 1.0 game. The foundation proves deterministic ticks, autonomous
crew construction, per-tile atmosphere/fire, power, budgets and wages,
recoverable incidents, save/load, native Goon media, and day-one mod loading.
The implementation stages for the full station simulation are tracked in the
[production roadmap](docs/production/02-roadmap.md).

## Run

Requirements:

- LÖVE 11.5
- Python 3.11+ for development commands
- Git LFS for the full graphics and audio source checkout
- Pillow and FFmpeg only when rebuilding imported assets

```sh
python3 tools/dev.py run
python3 tools/dev.py test
python3 tools/dev.py audit
```

After cloning, run `git lfs pull` before starting the game. If media is absent
or damaged, rendering falls back to readable generated shapes and audio fails
quietly; simulation behavior remains identical.

The current executable is the deterministic foundation/proving ground. It
opens a generated station core, simulates crew, atmosphere, power, needs,
budgets, work orders, and incidents, and exposes construction and time
controls. The complete product contract and implementation roadmap live in
[docs](docs/README.md).

## Controls

- `WASD` or middle-mouse drag: move camera
- Mouse wheel: zoom
- `Space`: pause
- `1`, `2`, `4`: simulation speed
- `F`, `X`, `C`, `V`: floor, wall, cable, or door blueprint tool
- Left click/drag: issue a blueprint
- Right click or `Escape`: inspect tool
- `M`: trigger the meteor/breach recovery scenario
- `F5`: save; `F9`: load
- `F1`: help and diagnostics

## Repository policy

Large source and generated media are assigned to Git LFS. Runtime releases
contain compiled LÖVE-ready atlases and Ogg audio, not DMI parsing logic.
Attribution and source hashes are generated from asset manifests.

The upstream fork is pinned to Goonstation commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`. The current import preserves 5,868
upstream files, compiles 46,160 sprite states into 134 portable PNG atlas
pages, and catalogs 4,699 sounds. Normal startup reads only two compact
foundation catalogs, four atlas pages, and sounds as events request them.

Rebuild or verify the fork with:

```sh
python3 tools/assets.py fetch-goon
python3 tools/assets.py import-graphics-source
python3 tools/assets.py build-graphics
python3 tools/assets.py build-audio
python3 tools/assets.py build-foundation-media
python3 tools/assets.py audit
python3 tools/assets.py verify-graphics
python3 tools/assets.py verify-audio
```

## Mods

`org.simstation.core` is loaded through the same content registry as extension
packs. Folder mods live directly under the LÖVE save directory's `mods/`;
reproducible `.simmod` ZIP packages are supported as well. Data packs load
without code execution. Lua packs require an explicit trust decision.

Trusted-code approval is hash-pinned. Put a schema-1 JSON object at
`mods/trust.json` in the LÖVE save directory, mapping the pack ID to the
`tree_sha256` reported for a folder or `archive_sha256` reported for a
`.simmod`:

```json
{
  "schema": 1,
  "trusted_code": {
    "org.simstation.example.smart-grid": "8f195f0821ea63aa09e7a3cece86f8749bb07757d15666d6952017a7901a6b24"
  }
}
```

That hash approves the bundled Smart Grid example as currently shipped.
Changing any package byte changes its hash and disables its entrypoints until
the player reviews and approves the new hash.

Four compatibility examples live in [`mods/examples`](mods/examples):
data-only catering, explicit audio/visual replacement, a scenario, and trusted
Lua hooks.

```sh
python3 tools/dev.py mod validate mods/examples/org.simstation.example.catering
python3 tools/dev.py mod test mods/examples/org.simstation.example.catering
python3 tools/dev.py mod package mods/examples/org.simstation.example.catering
```

See the [modding manual](docs/modding/README.md) for IDs, dependencies,
replacement rules, hooks, state, and compatibility policy.

## Licensing

The original runtime and tools are MIT-licensed under
[`LICENSE-CODE`](LICENSE-CODE). Goon-derived source and generated media are
CC BY-NC-SA 3.0 US and make the normal game distribution noncommercial. The
complete license matrix, provenance rules, and accepted audio-rights risk are
documented in the [legal index](docs/legal/README.md). This project is not
endorsed by Goonstation, Space Station 13, BYOND, or LÖVE.

Contributions are welcome; read [`CONTRIBUTING.md`](CONTRIBUTING.md) and the
repository working agreement in [`AGENTS.md`](AGENTS.md).
