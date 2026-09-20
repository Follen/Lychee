# Performance requirements for SDK integrations

[Contents](README.md) · [简体中文](../zh-CN/PERFORMANCE.md)

This English guide covers SDK integration requirements. The [complete project policy](../zh-CN/PERFORMANCE.md), generated from the repository's PERFORMANCE.md, also contains built-in feature budgets, historical measurements and implementation-specific evidence. Memory figures there are comparison baselines requiring evidence-based review, not universal heap ceilings. CPU/deadline, protocol capacity, correctness and cleanup requirements remain mandatory.

## Plan cost and lifetime

Before adding resident work, record its trigger/frequency/input scale/worst combat path; creation, activation, pause, resume and end; CPU/first-use/steady/peak latency, allocations, retained data and object counts; cache limits, invalidation and ownership. Every budget needs a unit, scenario and rationale. Deferred work moves cost rather than removing it. Do not improve a number by disabling expected functionality, shrinking data or splitting attribution between addons.

Every retained object has an owner and a release condition. Include all applicable addons, loaded SV, query/index data and native objects in the relevant accounting. Report Lua heap separately from textures/engine objects and diagnostic-tool cost. Persistent growth, unbounded caches/retries, cancellation residue, idle work and data loss are failures even if a historical KiB comparison passes.

## Idle work and scheduling

Do not create optional business UI, events or timers before enable. Essential shared infrastructure must be explicitly accounted for. No permanent per-frame Lua driver for idle features. Prefer relevant filtered events; do not poll state that has events. Use fixed bounded scheduling only when there is an actual time-driven need. Mouse-follow/animation OnUpdate ends on hide/disable/interruption.

Coalesce invalidations and same-session queries; keep only current work. Every queue has a size bound, deduplication, overload behavior and end condition. Do not silently lose player actions. Each batch has count and time limits; scheduling intervals alone do not bound work. A synchronous callback/native call cannot be preempted. Check session/generation/data version/visibility before accepting late replies.

Cancellation can reenter. Invalidate/remove old registrations before calling cleanup, then recheck generation. Old cleanup must not remove new work. Clear captured large tables, callbacks and empty registrations. Subscribe before issuing requests that can complete synchronously. Passive hooks install once and short-circuit when their owner stops; do not assume a native hook can be removed.

## Controls, updates and combat

Create on first use, then reuse a bounded tree/pool. Never prebuild real upstream settings pages to create a search index. Frame:Hide is not native-object destruction. Cache applied setters only after success; failure remains retryable. Geometry/font/locale/scale changes invalidate the relevant caches. Avoid full-page refresh for one changed value.

Reused controls must rebind action identity, not just text. Test press→rebind→release, same-ID replacement, scrolling, hide/reopen and ordinary successful clicks, including secure overlays. Do not replace identity checks with mouse polling. Native secure actions still require verified hardware-click/combat behavior; ordinary callbacks cannot bypass it.

Virtualization bounds controls by visible K but may still sort/inspect metadata N. Report both and the pool high-water mark. Close releases current row/context/action references while retaining reusable controls. Use build-time assets and appropriate texture sizes; unchanged Lua heap does not prove zero rendering cost.

## Search data and caches

Avoid duplicate full catalogs in Provider/Host/index layers. Share trusted immutable internal data only while preserving public copy isolation. Every growing cache, key set, eviction queue and statistic table needs a finite bound. Record owner, key dependencies (product/locale/schema/filter/style), capacity and per-item size, invalidation, eviction, reconstruction and active-reference behavior.

Use top-K candidates where appropriate instead of allocating all hits and truncating afterward. Validate matching/ranking against an independent full-scan reference with multilingual, broad, multi-field/multiword, source-switch and incremental-update cases. Time-bounded fuzzy matching requires fixed-clock correctness tests plus separate real timing.

Do not truncate input or alter matching to fit a cache. Long input may bypass a cache while still being processed. Distinguish missing facts from temporarily unavailable data; temporary failure is not a permanent negative cache. Shared scratch must not cross callbacks/async ownership or be overwritten by reentrancy. Keep public records named, not positional arrays.

No frequent forced full GC on input/combat/timers. Measurements may control GC with settings restored afterward. A negative post-GC delta means no observed retained growth, not negative memory. Reducing temporary allocation may leave resident memory unchanged; measure both.

## Provider boundaries and persistence

Configuration is resolved at low-frequency boundaries and invalidated on change. Atomic updates preserve the old directory/index on failure; only successful commits change stamps/ledgers. Avoid full replacement for a single-record update. Reading business data still costs work even if an unchanged update is skipped.

The Host can bound calls and its own work, not arbitrary synchronous third-party callbacks. Errors/retries are classified and bounded, diagnostics off by default. Plain-data validation, scope, eligibility, identity and copy isolation must remain intact when optimizing allocations.

Use addon-owned Storage and explicit bounded migrations outside combat. Preserve failed/newer/unknown saved data. Search-off is not owner stop: background data, explicit refs and submitted business operations have their own lifetimes. SavedVariables still occupy memory once loaded; persistence is not unloading. Larger caches use their own explicit schema/budget rather than expanding common settings limits.

## SDK capacities

These are protocol limits, not estimates of real heap size. Logical bytes count string bytes and 16 per other node, including keys.

| Facility | Limit |
| --- | --- |
| Provider static entries/documents | 4096; at most 16 actions per Entry |
| Dynamic reply / visible results | 256 candidates / 20 displayed |
| Query | One successful reply, five-second absolute deadline across all phases; not synchronous preemption |
| Resources | 64 registrations per provider across provider/query/view scopes, child scopes included; keys ≤96 bytes |
| After | 0–3600 seconds; zero means next timer dispatch |
| Plain settings/cache/invocation value | Depth 6, 256 nodes, 16384 logical bytes |
| Settings | 64 keys / 65536 logical bytes per provider |
| Scope cache | Default 32 entries/32768 bytes; configurable up to 128/65536; FIFO by writes |
| i18n | 4 locales, 256 keys/locale, key≤96 bytes, text≤1024 bytes, combined≤128 KiB |
| Text formatting | 16 args, string arg≤1024 bytes, result≤32768 bytes |
| Routes | Prefixes and keywords each ≤8 terms, each≤48 bytes |
| Diagnostics | Most recent 32 records, read on demand |
| Prepared credentials / edit sessions | 64 each across the Host; in-flight/uncertain execution records combined≤64 |
| Invocation schema/list | 32 parameters, 32 list items; strings≤1024 bytes, parameter names≤64 bytes |
| Literal parsing | 32 patterns × 32 segments, also subject to plain-data limits |
| Recents / pins | 8 / 64 references, each collection≤65536 logical bytes |
| Aliases / query selections | Each≤128 entries and 128 KiB logical bytes |

Persistent-reference validation also covers original raw SV, not only ordinary write paths. Invalid originals remain preserved with writes suspended. Their retained heap is not falsely described as bounded by the active-list limit.

CompactStore requires explicit positive safe-integer maxEntries/maxBytes/maxRecordBytes; identity≤4096 logical bytes, record tables≤128 fields/depth8. Read [compact storage](COMPACT_STORAGE.md), [invocations](INVOCATIONS.md) and [loading](LOADING.md) for their additional semantic bounds.

## Measurement and acceptance

Separate functional and performance acceptance. A good memory curve does not prove correct actions; offline tests do not prove client behavior. Record before/after commits and hashes, client/build/locale/character, addon set, identical data/steps/duration, profiler state and tool overhead. Test cold, warm and peak scenarios; report sample count/median/max and tail percentiles only with enough samples. Alternate before/after runs where practical.

Report collected resident memory, fixed-sequence total allocations, repeated retained growth, active work after close/disable, Frame/pool peaks, timers/events/queues, CPU and result latency. Current-query first results, first interactable result and completion are distinct; an old visible result is not new-query progress. Compare complete results/order/text/evidence/action args as well as cost.

Relevant scenarios include login, idle, combat/raid/nameplates when affected, first search, rapid typing, fast open/close, scrolling, sorting/deletion, source changes, burst events and re-enable. Unavailable scenarios are explicitly unverified. Remove diagnostic tasks and restore settings afterward. Do not weaken limits or shrink test input to pass. Investigate comparison failures with original measurements and record any justified exception.

For SDK resource changes, the fixed warmed 1000-query-scope sequence checks <64 KiB retained growth, no new Frames and zero resources after owner stop. UI checks include 1000 unchanged updates (<64 KiB allocations), 1000 view mounts/updates/unmounts (<1000 KiB allocations/<16 KiB growth, one reusable Frame) and 2000 motion redirections (<512 KiB allocations, no added animation groups). These heap figures are historical review baselines; lifecycle and capacity assertions remain firm. Native engine memory is measured separately.

Use the repository's [development guide](https://github.com/Follen/Lychee/blob/main/docs/guides/DEVELOPMENT.md) for full contract/static/client validation commands. Documentation-only changes need links/facts/version checks; runtime resource/search/lifecycle changes need appropriate real-client coverage. The [complete policy](../zh-CN/PERFORMANCE.md) contains project-specific built-in budgets and evidence.
