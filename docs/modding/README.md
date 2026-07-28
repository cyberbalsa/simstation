# Modding specification

Mods are a first-class content path from the first playable build. The base
game itself is the ordinary first-party pack `org.simstation.core`; imported
media is `org.simstation.goon`. Anything the base pack can define, replace,
hook, localize, render, play, save, or migrate must use the same public
mechanism available to another pack.

## Supported mod classes

| Class | Can contain | Trust |
|---|---|---|
| data | JSON definitions, localization, compiled maps/scenarios, atlas and audio bundles | validated data; no code execution |
| code | everything above plus Lua entry points, hooks, commands, migration code | fully trusted arbitrary code |

“Data-only” means the loader never executes bytes from the package as Lua,
native code, shell commands, shaders, or network content. It reduces risk but
does not make malformed files harmless; all archives/media remain bounded and
validated.

Code mods are not sandboxed. Before first enable, show pack identity, version,
hash, source path, and this warning:

> This mod runs trusted Lua code. It can access game internals exposed by the
> runtime and may read or change files available to the game process, hang or
> crash the game, corrupt saves, or invoke operating-system facilities. Enable
> it only if you trust its source and publisher.

The acknowledgement is stored per exact package hash. A changed package asks
again.

## Documents

- [Package format and loading](01-package-format-and-loading.md)
- [Hooks and trusted Lua API](02-hooks-and-code-api.md)
- [Authoring, testing, and compatibility](03-authoring-and-compatibility.md)

## API lifecycle

The pre-1.0 policy is maximum experimentation:

- public API version begins at `0.1.0`;
- any pre-1.0 minor version may break code mods;
- data/save schema versions change independently;
- breaking changes must update the API version, examples, schema fixtures, and
  migration notes in the same commit;
- the loader reports exact incompatible ranges instead of attempting best
  effort;
- deprecation is encouraged but not required before 1.0;
- after 1.0, SemVer compatibility applies to the public API.

No mod API is inferred from Lua module paths or internal tables. Only
documented schemas and methods are public.

## Implemented foundation

`src/mods/resolver.lua` and `src/mods/hooks.lua` currently prove deterministic
dependency traversal, cycle detection, hook transforms, error capture, and
stable registration in tests. They do not yet parse `mod.toml`, mount
`.simmod`, solve SemVer, expose `HookContext`, or implement this public API.
Their abbreviated table/callback shapes and current priority-first ordering are
schema-0 internals and must be upgraded with compatibility fixtures before M1
exits.
