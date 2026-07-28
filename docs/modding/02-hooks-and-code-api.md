# Hooks and trusted Lua API

## Registration

A code entry point is loaded once at title-screen content initialization and
returns a registration function:

```lua
return function(api)
  api:register_observer(
    "org.simstation.core:hook/event/task-completed",
    { priority = 0, name = "record-kitchen-task" },
    function(ctx, event)
      ctx:log("debug", "observed " .. event.event_id)
    end
  )
end
```

Entry points execute in resolved pack order and listed manifest order. Within
one entry point, registration sequence is monotonic. A public registration
name is required and unique within the pack so diagnostics remain stable.

The `api` object exposes only documented methods. Requiring project-internal
modules, retaining internal tables, monkey-patching global modules, or
depending on `package.loaded` paths is unsupported even though trusted code may
be technically able to do so.

## Handler order

The loader assigns each pack a dependency phase: zero for packs with no enabled
dependencies, otherwise one plus the maximum dependency phase. Handlers for one
hook order by:

1. dependency phase, ascending;
2. integer handler priority `[-1000,1000]`, ascending;
3. pack ID, raw UTF-8 byte order;
4. entry-point index;
5. registration sequence.

Thus dependencies always see values before dependents; priority orders peers
and handlers within a pack. The complete handler order appears in the mod
diagnostics screen and replay header.

## Hook kinds

### Observe

Observe hooks run after an immutable event or completed transition:

```lua
function(ctx, event) -> nil
```

They cannot change/cancel the fact. They may log, update their own primitive mod
state, or enqueue a documented command for the next uncommitted tick. Enqueued
commands cannot reenter the current hook/tick.

An observer error is caught with `xpcall`, recorded with pack/hook/handler and
traceback, and disables that handler for the rest of the session. The disable
decision is deterministic for the same handler error and is recorded in
replays/saves while active. Other observers continue.

### Validate/cancel

Validators run before a documented command or state transition:

```lua
function(ctx, proposal)
  return true
  -- or:
  return false, "org.example.mod.reason.not-allowed", { field = "value" }
end
```

Inputs are immutable views. Validators run in handler order and stop at the
first denial. Reasons are localization keys owned by the returning pack;
details contain primitives and must pass the hook's closed diagnostic schema.
`nil`, malformed returns, mutation attempts, yields, or errors abort the
proposal as a hook failure, pause simulation before commit, and offer
disable-mod/reload. No partial state is applied.

### Transform/reduce

Transform hooks form an explicitly typed pipeline:

```lua
function(ctx, immutable_value, immutable_subject)
  return replacement_value
end
```

The output of each handler is schema-validated and frozen before the next.
Transform hooks may change only fields named by that hook contract and may not
create an ID owned by another pack. An error or invalid result aborts the
owning operation before commit and pauses as above.

Reducers are transforms whose values are project-defined accumulators (for
example, a list of incident candidates). The hook document specifies identity,
combination rule, maximum output size, and stable final sort. Mods cannot define
new authoritative reducer semantics in API 0.1.

## HookContext API 0.1

All returned objects are read-only proxies or deep primitive copies:

```lua
ctx:tick()                                  -- exact integer tick
ctx:pack_id()                               -- caller pack
ctx:query(kind, stable_id)                  -- documented knowledge-safe view
ctx:query_tile(map_id, x, y, projection)    -- documented tile projection
ctx:definitions(kind, tag)                  -- sorted ContentId array
ctx:definition(content_id)                  -- immutable definition view
ctx:machine_actions(machine_id, actor_id)   -- sorted typed affordance copies
ctx:enqueue(command_type, payload)          -- next tick, trusted issuer
ctx:get_state()                             -- caller's primitive state copy
ctx:set_state(next_state)                   -- schema-check caller state
ctx:event_variant(event_id, namespace, n)   -- deterministic integer 1..n
ctx:log(level, message, fields)              -- non-authoritative diagnostics
```

`query` is limited by the hook:

- UI/presentation hooks receive the player knowledge projection.
- Simulation hooks receive only the owning system's documented facade.
- A trusted declaration does not grant a universal mutable world reference.

There is no clock, filesystem, network, coroutine/yield, renderer/audio object,
or another system's RNG in `HookContext`. `event_variant` hashes inputs and does
not consume RNG. A mod needing filesystem/UI work does it in an explicitly
presentation-only entry point, never during authoritative hooks.

`get_state`/`set_state` address only:

```json
{
  "pack": "org.example.automation",
  "schema": 1,
  "value": {}
}
```

Values are JSON primitives under 8 MiB per pack and are committed with the
current operation. Functions, metatables, cycles, userdata, cross-pack
references outside declared ID fields, and inexact numbers are rejected.

## Initial hook registry

System design documents may add typed hooks. API 0.1 reserves:

| Hook ID | Kind | Purpose |
|---|---|---|
| `org.simstation.core:hook/command/validate` | validate | validate a documented command proposal |
| `org.simstation.core:hook/machine/action/validate` | validate | validate one typed machine action at command commit |
| `org.simstation.core:hook/task/candidates` | transform | filter/annotate candidate task IDs before core stable scoring |
| `org.simstation.core:hook/task/score` | transform | integer bounded score adjustment |
| `org.simstation.core:hook/recipe/validate-start` | validate | validate a production start |
| `org.simstation.core:hook/economy/transaction` | validate | validate a proposed ledger transaction |
| `org.simstation.core:hook/incident/candidates` | transform | contribute/filter eligible incident IDs |
| `org.simstation.core:hook/event/finalized` | observe | observe a player-visible or authorized event |
| `org.simstation.core:hook/shift/settled` | observe | observe immutable shift results |

The generic command/event hooks still expose a discriminated closed union, not
arbitrary core tables. High-volume tile/atmosphere inner loops deliberately
have no per-cell Lua hooks; data-driven gas/reaction definitions and coarse
transition hooks preserve performance.

`machine_actions` returns the same definition-declared verbs used by crew AI and
the inspector: stable action ID, range, duration, parameter schema, source
symbol, tags, availability, and a stable denial reason. It never returns a live
machine table. A `machine/action/validate` proposal identifies the machine,
actor, action, and validated primitive parameters; handlers may allow or deny
it, but cannot replace the action handler or bypass access, adjacency, tool,
power, panel, health, or parameter checks.

Every hook-specific contract defines cadence, input schema, mutable output
fields, visibility, maximum collection sizes, and error criticality before
shipping.

## Error and performance policy

All callbacks use `xpcall` with a project traceback. Wall-clock timings and call
counts are collected for diagnostics, but wall time never changes authoritative
order or automatically disables a correct handler. Default warnings are:

- over 2 ms for an authoritative handler call;
- over 10 ms accumulated by one pack in a tick;
- over 100,000 calls per shift for a non-high-volume hook.

Repeated warnings suggest disabling the pack but do not act automatically.
Errors follow the hook-kind rules above. Infinite loops cannot be made safe in
a trusted Lua process; the trust warning is the boundary.

Hook handlers may not yield. Coroutines, `love.thread`, and asynchronous
callbacks cannot participate in authoritative transactions.

## Presentation extensions

API 0.1 does not allow mods to execute arbitrary drawing inside the world
renderer or replace UI internals. Data packs may provide sprites, audio,
localization, codex pages, alerts, overlay palettes, and declarative inspector
fields. Later APIs may add bounded presentation panels with separate
nondeterministic contexts.

## Acceptance

- Fixture handlers prove exact phase/priority/ID/sequence order.
- Validator denial and transformer error leave before-state byte-identical.
- An observer error disables only itself and reproduces under replay.
- Attempts to mutate input/proxy, retain a live table, yield, use another RNG,
  enqueue for the current tick, or exceed state schema fail clearly.
- Rendering/audio enabled or disabled has no effect on authoritative hook
  output.
- Base content hooks use the same registration methods and diagnostics.
