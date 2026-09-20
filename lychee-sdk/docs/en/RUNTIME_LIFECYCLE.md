# Runtime lifetimes

[Contents](README.md) · [简体中文](../zh-CN/RUNTIME_LIFECYCLE.md)

SDK/API **1.0.0**, UI Runtime **1**. [Performance requirements](PERFORMANCE.md) govern capacity and cost.

Search participation is a user preference. Turning it off cancels source queries and optional search preparation; it does not call `onDisable`, stop necessary background work, unmount independent business views, block explicit saved references or cancel committed operations. Owner stop means `SetAvailability(false)`; unregister means `Unregister()`.

| Phase | May retain | Must release or avoid |
| --- | --- | --- |
| Addon not loaded | Bounded cold metadata | No business Lua/UI for discovery; never enable a disabled addon |
| Loaded, provider not enabled | Code, finite declarations, own SV, explicitly required addon services | No UI or full business index merely for search registration |
| Provider enabled | Necessary events and a deliberately bounded owned directory | Previous temporary query candidates and stale jobs |
| Preparation | Current data work and live subscriber deadlines | Release when no subscribers, failed, stopped or stale; success retains only a readiness credential in the Host |
| Query | Current work, waits and bounded candidates | Complete, replace, close, timeout and owner stop all clean up; reject late replies |
| Mounted view | Current model/row bindings and view scope | Unmount detaches business references; fixed controls may be reused |
| Submitted invocation | Bounded identity, arguments and operation resources | Release at terminal state/deadline; closing the view detaches listeners, not confirmed business effects |
| Owner stop/unregister | User settings and explicitly persistent business data | Jobs, events, active directory references and old action identities |

The Host can index bounded public entries/documents, but owns no provider business DB or provider Catalog registry. Catalog is optional and caller-owned. Your TOC and [Storage](STORAGE.md) determine data lifetime. Loaded SV consumes memory; it is not a disk database queried on demand.

[Resources](MANAGED_RESOURCES.md) manages only registered work. It cannot interrupt synchronous Lua or control timers created outside the SDK. Loaded Lua cannot be unloaded, and WoW Frames are not disposable Lua tables. Measure cold load, first use, repeated allocation, collected retention and activity after close separately.

Prepare directory changes before atomic commit; failures retain the old state, notifications happen after commit. Remove a resource registration before external cleanup so reentrant new work cannot be removed by old cleanup. Check identities for stale results, page saves and asynchronous completions.

Discovery, load, SV, preparation and query share a deadline. The home page restores only visible bounded references, then may prepare already loaded participating providers at lower priority. Close removes these subscriptions without claiming to unload Lua. See [loading](LOADING.md), [views](VIEW_LIFECYCLE.md) and [invocations](INVOCATIONS.md). A cancelled dispatched action can be indeterminate; never retry or count it as success automatically.
