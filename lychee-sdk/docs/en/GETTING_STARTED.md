# Getting started with Lychee SDK 1.0.0

[Contents](README.md) · [简体中文](../zh-CN/GETTING_STARTED.md)

The runtime entry point is `_G.Lychee`. The SDK is a development package, not another game AddOn. Start with [the protocol](PROTOCOLS.md), [performance requirements](PERFORMANCE.md) and [catalog choices](CATALOG.md).

## Choose an integration path

| Need | Start here |
| --- | --- |
| A few entries from an already loaded addon | The minimal registration below and [ThirdPartyFixture](../../examples/ThirdPartyFixture/ThirdPartyFixture.lua). No Catalog or discovery declaration is needed. |
| An independent addon loaded only when requested | Install [ColdProvider](../../examples/ColdProvider/README.en.md) and follow the [TOC contract](LOADING.md). |
| Parameterized actions or a provider-owned search directory | [Invocation](INVOCATIONS.md) and [Catalog](CATALOG.md) are independent, optional capabilities. |

Implement ordinary entries and actions first. Add preparation only when your data actually requires it; cold loading does not require an artificial asynchronous layer.

## Minimal registration

A dedicated extension declares `Dependencies: Lychee` in its own TOC. An existing addon offering optional integration can use `OptionalDeps` and continue working without Lychee. Own your code, SavedVariables, media and licenses.

```lua
local api = _G.Lychee
if not api or not api:Supports("1.0.0") then return end
api:RegisterReady(function()
    local handle, err = api:RegisterProvider({
        id="example.settings", apiVersion="1.0.0", version="1.0.0",
        title="Example", scope={products={"retail"}}, i18n={enUS={}},
        entries={{id="settings",title="Example settings",actions={"open"}}},
        actions={open={title="Open",run=function()
            print("Example opened") -- 换成已验证的普通业务动作。
            return {ok=true,close=true}
        end}},
    })
    if not handle then error(err.code) end
end)
```

Replace the print call with your verified ordinary action. This provider needs no query, preparation, invocation or storage encoding. The Host validates and indexes bounded public entries; business facts remain yours. Publish changes with `handle:Update`. Never read `LycheeInternal`.

If you already have a query layer, implement `query/resolve` and return ordinary entries or scored hits. A query returns nil or a cancellation function: **do not return `reply(...)`**, whose boolean result is not a cancellation function. Reply successfully at most once; report failure with `context.fail`, not an empty success.

## Loading, readiness and clients

Cold discovery uses versioned `X-Lychee-*` native TOC metadata and `LoadOnDemand`; the Host does not execute a Lua manifest. One addon may register several providers. Loaded package identity, scope, routes and resources must match the declaration. Disabled native addons are never automatically enabled. Already loaded providers may register without discovery metadata.

Check that `SDK.SupportsFeature` exists and that each optional feature you need is available. `Supports("1.0.0")` checks the API version only. `SDK.GetClient()` returns an isolated `{product,interface,build,locale}` snapshot. Select a verified implementation; broadening `products` alone does not establish compatibility. See [client variants](CLIENT_VARIANTS.md).

Wait for both `RegisterReady` and your own `SDK.WhenSavedVariablesReady`; either may call back synchronously. Discovery, loading, saved-data readiness, preparation and query share one absolute deadline. Optional provider `prepare` prepares owned data without executing business actions or publishing results. Invocation preparation is a separate read-only operation.

## Data and search ownership

Ordinary entries permit bounded Host indexing, not transfer of your business database. A custom query submits only current candidates. Use `CreateCatalog` only if you need your own searchable directory. Each result carries only the data needed for its current display and action.

Ordinary references restore through `resolve(entryID,context)`. Target, command and invocation references preserve their complete identity, versions and normalized parameters. Restoration may wait asynchronously but never searches for a replacement by display name or executes a write. Pins, recents and aliases store bounded references. Set `rememberable=false` for one-time entries. See [stored references](INVOCATIONS.md#stored-references).

`searchGlobal` defaults to true. Prefixes and keywords each accept up to eight terms, including empty arrays. `example:text` scopes a query; the exact keyword `example` requests an empty query from that provider. With global search off, retain at least one route. Users can override routes or turn search participation off. That excludes search routes but does not disable explicit saved references, background business work or committed operations, and does not call `onDisable`.

## Lifetimes and storage

The addon owns necessary data events. Query work belongs to query resources; page subscriptions belong to view resources. Submitted invocations belong to provider operation resources. Closing a page detaches its UI, not an already performed business change. See [runtime lifetimes](RUNTIME_LIFECYCLE.md).

Declare your own SV and bind [Storage](STORAGE.md) only after it is ready. Use `SavedVariablesPerCharacter` for character settings. Closing a view does not delete settings. Handle Settings is a bounded Host character-preference facility, not a third-party database.

| Data | Suitable interface |
| --- | --- |
| A few simple entries | `Provider.entries` and `handle:Update` |
| Your own incrementally searchable directory | Catalog entries, `Update/Query/Resolve` |
| Expensive Entry construction with measured savings | Optional documents and `readEntry`, with cold/hot latency and allocation comparisons |
| An existing search/data layer | Custom query/resolve, preserving ranking, deadlines, cancellation and failure contracts |

Check `search-documents` and `query-failure` before using their optional contracts; check `compact-storage` separately. A reader returns nil only for a genuinely absent fact, and nil,Error for a temporary failure. Do not return the boolean from `Catalog:Query` as a Provider cancellation function. Inspect synchronous errors and forward them through `context.fail`.

## Integration coverage

Send raw definitions directly to the public API when testing required fields, unknown fields and invalid versions. Do not make a test wrapper silently repair them. Cover rapid query cancellation, late replies, owner stop/re-enable, explicit invocation with search off, stale action identities, isolation, retry and cleanup.

Storage tests cover readiness, root replacement, character isolation, migration failure and future schema preservation. View tests cover Mount failure, rebind between press/release, close/reopen and bounded reuse. Native substitutes supply external inputs, not SDK algorithms. Offline success does not prove combat safety, hardware clicks or rendering in a real client.
