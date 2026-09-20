# Managed resources, settings and caches

[Contents](README.md) · [简体中文](../zh-CN/MANAGED_RESOURCES.md)

Use `_G.Lychee`, check `Supports("1.0.0")`, and declare `apiVersion="1.0.0"`. Do not use `LycheeInternal`. Submit public records through entries/Update or query. [Performance](PERFORMANCE.md) explains the limits and measurement policy.

## Scopes

| Access | Lifetime | Automatic end |
| --- | --- | --- |
| `handle:Resources()` | Current enabled provider instance | Owner stop or unregister; re-enable gets a new scope |
| Query `context.resources` | One query | Completion, replacement, close, timeout, error, stop or unregister |
| View `context.resources` | One mount, including create/Mount/Update | Replacement, close, construction failure, stop or unregister |

Closing a page does not stop necessary provider data events. Work created outside these scopes remains the author's responsibility.

| Method | Behavior |
| --- | --- |
| `Own(key,cleanup)` | Replace the same-key registration; call cleanup(reason) at most once; return a Cancel handle |
| `After(key,seconds,callback)` | Replaceable one-shot delay, 0–3600 seconds; zero means the next timer dispatch |
| `Run(key,work,handlers)` | Bounded coroutine work; `coroutine.yield()` resumes through a one-shot timer; returns Cancel |
| `OnEvent(event,callback)` | Ordinary event subscription, callback(event,...); replace same event in this scope |
| `Cache(key,options?)` | A bounded plain-data cache; replace the same-key cache |
| `IsActive()` | Whether this scope remains valid |
| `GetDiagnostics()` | Copied counts: active, resources, providerResources, errors, limit |

Run handlers are only `complete(value)`, `error(errorValue)` and `combat()`. With a combat handler, detecting combat before a continuation ends that task and calls the handler. Without one, the SDK does not invent a combat policy. Work must yield according to its own count/time budget; synchronous Lua is not preempted and actions are not automatically retried.

A provider has at most 64 registrations across its provider/query/view scopes; a child scope itself consumes one. Keys are at most 96 bytes, independent between resource types. Closing/replacement removes the old registration before external cleanup/results. Reentrant new work survives old cleanup. Capacity failures return `nil,Error` with `RESOURCE_LIMIT`; handle them instead of silently omitting work.

Events use a lazily created shared Frame. Zero subscriptions unregister events/scripts. There is no permanent OnUpdate. High-frequency unit events still need business filtering and coalescing.

## Settings versus caches

Business settings use [Storage](STORAGE.md) with your addon-owned SV root. `Get` returns a copy/default copy without persisting defaults; `Set(key,nil)` removes a setting; failed writes preserve the old value. `Import` atomically initializes an absent namespace and rejects overwriting one. Closing a page or disabling a provider does not erase settings. The addon closes a storage handle when its data layer no longer needs it; provider unregister does not close an independently shared data layer.

`scope:Cache(key,{entries=32,bytes=32768})` provides Get, Set, Clear and GetDiagnostics. Limits are 1–128 entries and 1–65536 logical bytes. It evicts by write order; Get returns copies without changing that order. It does not eagerly allocate full capacity. An oversized single value fails without replacing old data. Ending the scope clears and invalidates the cache.

Settings/cache values are plain data: no functions, Frames/userdata, metatables, cycles, inaccessible/secret values or nonfinite numbers. Keys are strings/numbers. Copying enforces depth 6, 256 visited nodes and 16384 logical bytes per value. Settings allow 64 keys and 65536 total logical bytes per provider. Strings count actual bytes; other nodes count 16, including keys. These are protocol limits, not exact WoW heap measurements.

## Host boundaries

Identity, scope, user policy, query generation, result capacity and input isolation still apply. Catalog updates are atomic, preserve the prior directory on failure and notify only on change. Caller-owned Catalogs and Host-indexed bounded public entries/documents do not transfer business-database ownership.

Actions, state schemas, hardware clicks and secure execution use the shared executor; there is no generic secure scripting facility. Queues are bounded, late callbacks cannot commit, and partially failed view construction closes registered resources. Diagnostics are on demand, not scans of third-party memory.

See [ManagedProvider](../../examples/ManagedProvider.lua) and the repository's [resource tests](https://github.com/Follen/Lychee/blob/main/tests/sdk/sdk_resources.lua).

## ID-based data queries

You may retain stable IDs/relationships, read localized names during queries and load details/models only on demand. Compare repeated reads and total allocations as well as retained memory; a cache is not always necessary.

Use a query-owned temporary named record while scanning; copy fields only for selected candidates. A coroutine may retain its own temporary record across yields, but published results and other queries must not share it. Cancellation tests must include suspended-coroutine captures. Do not reconstruct a full database on every keystroke and call the design cheap because post-close GC drops memory.

Use query Run for scanning, OnEvent and bounded After for data waits. Subscribe before requesting data, including synchronous event completion. Reply once and reject stale queries. Views lazily create bounded reusable controls; unmount clears current records/models/bindings. Verify press→rebind→release identities.
