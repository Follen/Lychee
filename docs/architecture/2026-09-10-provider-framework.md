# Provider framework decision

Date: 2026-09-10. Public API 2, revision 1. No old SDK adapter or SavedVariables migration.

## Decision and alternatives

Three independent design reviews compared (1) one minimal Provider registration, (2) a composable capability system, and (3) third-party-first integration. All identified the same public-boundary defect: registering searchable content required learning several unrelated Host implementation roles.

Choose one Provider definition with optional entries, query, resolve, actions, drags, views and lifecycle callbacks. Keep indexing, query sessions, validation, protected execution and view ownership inside the Host. Reuse the existing private Registry and StaticIndex; do not build a parallel index or a compatibility adapter. CommandCatalog, CapabilityBroker and IntentRouter remain private implementation modules, not public SDK prerequisites.

The more elaborate capability system's streaming, async detail and generic cross-plugin RPC are deferred. Query uses one reply, synchronous or delayed, with explicit cleanup. Dynamic history restoration is synchronous and separate from text search. These are deliberate versioned limits, not promised future APIs.

## Public operations

`Lychee:RegisterProvider(definition)` returns a handle with `Update(delta)`, `SetEnabled(boolean)`, `GetState()` and `Unregister()`. `RegisterReady` is cancellable. `Supports(2, 1)` is strict and never throws for malformed version arguments.

- `entries` declares a static catalog. `Update({replace=entries})` replaces it; `Update({upsert=entries,remove=ids})` changes it atomically. Input ownership remains with the caller; validated copies enter the Host. Unchanged indexed entries retain their compiled objects.
- `query(request, reply, context)` produces candidates through `reply(entries)` exactly once and may return `cancel(reason)`. A five-second deadline bounds waiting, not synchronous Lua execution. Input change, close, disable and unregister cancel pending work. Late replies cannot publish.
- `resolve(entryID, context)` returns the current entry or nil. History stores qualified identities, never executable payloads. Static entries resolve directly; transient query-only entries without resolve are not remembered.
- `actions[id]={title,run}` registers an ordinary callback once; entries reference action IDs. The callback receives copied entry data and context. It returns `{ok=true,close?,view?,state?}` or `{ok=false,code,message?}`.
- Entry-level Host descriptors support `secure-spell`, `drag-spell` and `open-panel`. Unknown kinds fail validation. Ordinary callbacks cannot acquire secure authority.
- `drag={type="spell",spellID,title?}` uses the Host cursor adapter. `drag={type="provider",handler,title?}` invokes a registered `drags[id].begin` only during a real drag gesture. No drag declaration means no drag.
- `views[id]={stateSchema,create}` creates a managed content view. Mount receives initial state; Update receives state directly; Unmount/Dispose release activity.
- `onEnable(handle)` optionally returns one cleanup function. The Host calls it exactly once on disable/unregister; `onDisable(reason)` is optional. Integrations own their event/timer resources and release them in cleanup. Host queries own their independent cancellation.

## Invariants and implementation sequence

1. Fix confirmed Registry lifetime, input copying, ready cancellation and capacity inconsistencies.
2. Add ProviderRuntime; validate the complete declaration before publication. Keep public handles opaque and reject retired-instance writes.
3. Integrate synchronous/delayed query completion with SearchSession. Merge and rank in the Host, honor scope/filter, and reject stale actions/results.
4. Use qualified history references and remove persisted search snapshots. Storage schema 2 starts fresh.
5. Expose declared actions and drag consistently in search and recent items; add an action menu with stale row checks.
6. Migrate built-in spells and third-party fixtures to the same public API. Publish current LuaLS types, reference and examples.
7. Run public contract tests, existing search/interaction suites, static checks and wowdoc validation. Commit, then copy only runtime files to retail and verify hashes.

## Acceptance and evidence boundary

Public-contract cases: duplicate local IDs under separate Providers; invalid batch atomicity; caller mutation isolation; reused IDs and retired handles; pending query cancellation, timeout, duplicate completion and late replies; static/dynamic deduplication and scope; ordinary errors; independent drag; information-only entries; dynamic restore; all actions reachable; stale menus; view initial state and cleanup; built-in public registration.

No new idle OnUpdate or polling. Finite query timers exist only while waiting. Static updates retain unchanged compiled entries. Offline timing and object-identity checks are reproducible but do not substitute for real WoW CPU, memory, frame-time, combat, taint or hardware-click evidence.

WoW source evidence is in `2026-09-10-framework-wowdoc.json`: wow-ui-source, retail, requestedRef latest, commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`, including timer, event cleanup, spell cursor and native menu paths/lines/excerpts.
