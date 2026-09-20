# Reusable views and lifecycle

[Contents](README.md) · [简体中文](../zh-CN/VIEW_LIFECYCLE.md)

SDK/API **1.0.0**, UI Runtime **1**. See [resources](MANAGED_RESOURCES.md), [Storage](STORAGE.md), [loading](LOADING.md), [performance](PERFORMANCE.md) and [ThirdPartyFixture](../../examples/ThirdPartyFixture/ThirdPartyFixture.lua).

## Ownership and call order

The Host owns the active mount; the provider owns the controller and native controls. Every open calls create(context,initialState), which may return your cached instance. There is no cross-provider panel cache or public cache/lifecycle definition field.

| Event | Synchronous order | Provider responsibility |
| --- | --- | --- |
| First open | create → Mount(context,initialState) | Lazily create controls, bind state/events |
| Update | Update(state,context) | Update content, identities and subscriptions |
| Close/replace | Unmount(reason) → Dispose(reason) | Stop work, release business/context references, hide controls |
| Reopen | create → Mount(context,initialState) | Reuse cached structure, rebind/reanchor as required |
| Mount/Update exception or close during callback | Finish callback → Unmount → Dispose | Clean partially constructed/mounted instances |
| Owner stop/unregister | Exit current view plus provider cleanup | Both paths idempotent; do not depend on their relative order |

Turning search participation off does not unmount a business view or stop background work/submitted operations. Owner stop is SetAvailability(false). Closing the view ends its scope; cleanup must tolerate reentrancy/repeated cancellation.

Dispose ends this mount, not native Frame existence. Retain a bounded fixed control tree instead of repeatedly creating native objects and losing their only references. After unmount, controls/parent/static layout may remain; large business tables, old handles/callbacks/context/timers must not. A dormant structure may serve a later registration, but one instance must not be mounted by several Hosts at once.

## Invocation-aware views

Optional context:Prepare/Invoke/BeginEdit/Observe are available from Mount, not create, for the current provider/instance. Provider owns drafts, targets, args and controls; the Host never infers business state by reading control internals. See [Invocation](INVOCATIONS.md#provider-owned-views-and-editing).

Close cancels unsubmitted preparation, releases unused Prepared and detaches observation/UI callbacks. Submitted operations retain provider/deadline lifetime. Cancellation may be indeterminate; close is not rollback or success. Keep draft separate from confirmed state and remember success only after confirmation.

Saved references may represent an invocation, target or missing-argument command. Restore read-only before allowing execution; never substitute an old entryID/title for saved args. Persistent state goes to Storage; media belongs to your package or verified native assets.

## Reuse and failure handling

Cache at most a bounded controller set, not one per unbounded entry ID. Create controls lazily in Mount, storing each successful creation immediately so partial construction can be repaired. Mark parent/layout applied only after setters succeed. Read initial state on each mount; Unmount and Dispose share idempotent release.

```lua
local function release(panel)
    panel.active = false
    panel.generation = panel.generation + 1
    panel.context, panel.entry = nil, nil
    panel:StopSubscriptionsAndTimers()
    if panel.frame then panel.frame:Hide() end
end
```

This illustrates your own asynchronous controller: initialize generation yourself and implement StopSubscriptionsAndTimers. It is not a Host method. Invalidate first, then cancel; late replies check active/generation. Do not add timers to synchronous examples solely to follow this pattern.

- create returns a table/engine object with accessible methods; invalid instances or method-access exceptions report PANEL_ERROR.
- Mount/Update return values are not failure signals; false does not close a view. Throwing triggers cleanup. Optional methods may be absent, though the complete lifecycle is recommended.
- Synchronous reentrant mount/update returns PANEL_BUSY without queuing. A close request is accepted and cleans up after the active callback; cancelled operations return PANEL_CANCELLED. Do not retry in a loop.
- An Unmount exception still attempts Dispose and removes active Host bindings; the addon remains responsible for its cleanup.
- Both create and Mount receive initialState; Update receives state directly, not {state=...}. Do not mutate caller state or retain context. Editing context.extensionID does not change Host ownership.
- Cache the controller before partial native construction; never throw away the only references to already-created Frames.

## Acceptance

Check first open/state/parent changes and unchanged action args; 100 reopen cycles with stable Frame/Region counts; zero view events/timers after hide and owner resources after stop; independent background work survives search-off. Cover repeated cleanup, partial Mount, Update errors, late callbacks and unregister/re-register with a new handle. Count allocations, retained Lua heap and native objects separately. GC is not Frame destruction.

Repository tests: `lua tests/ui/view_lifecycle.lua` and `lua tests/ui/interaction_smoke.lua`. Native rendering/protection/event order still requires client validation.
