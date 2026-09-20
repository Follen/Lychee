# Independent addon discovery, loading and preparation

[Contents](README.md) · [简体中文](../zh-CN/LOADING.md)

This contract extends SDK 1.0.0 and Provider API 1.0.0. A cold declaration lets the Host select an installed provider before its Lua files run. Registration, SavedVariables readiness, optional preparation and business invocation remain separate steps. Existing already-loaded providers without a declaration keep the original registration path.

## Runnable example

[ColdProvider](../../examples/ColdProvider/README.en.md) contains a complete independent AddOn: fallback/Mainline TOCs with the declaration, addon-owned SavedVariables, and registration through public SDK calls. Copy the whole directory as `Interface/AddOns/ColdProvider`. Its `cold:` prefix and `coldexample` keyword trigger loading; it is excluded from unscoped search by default. The example supports only its declared Retail interface range and requires separate in-game validation. Its native loading substitute test is `tests/sdk/cold_example.lua` in the source repository.

The TOC fields below are the manifest contract. The Host never runs a third-party Lua manifest to discover a cold provider. Change the directory name, package name, provider ID, routes and loaded definition together when adapting the example.

## Client and capability checks

```lua
local host = _G.Lychee
if not host or not host:Supports("1.0.0") then return end
local SDK = host.SDK
local client = SDK.GetClient() -- SDK:GetClient() and host:GetClient() also work
-- { product="retail", interface=120100, build=70000, locale="enUS" }
if not SDK.SupportsFeature("discovery", 1) then return end
```

`GetClient` returns a new snapshot. Editing it does not change Host identity, load an addon or probe arbitrary globals. `product` is `retail`, `classic`, `titan` or `anniversary`; `interface` and `build` are numbers; `locale` is the current client locale. Product support still requires an applicable native TOC and an explicitly supported interface/build range.

`SDK.SupportsFeature(name, version)` also accepts SDK colon syntax and `host:SupportsFeature(name, version)`. Version defaults to `1`. Implemented names are `client-context`, `discovery`, `provider-readiness`, `preparation`, `invocation`, `search-documents`, `compact-storage` and `query-failure`. Unknown names and unsupported versions return false. Optional services report availability only when their Host implementation is installed. `SDK.Now()` uses the same monotonic clock as Host operation deadlines.

## Static TOC declaration

Each independently loaded addon has its own native TOC, dependencies, SavedVariables and media. This example declares two providers in one addon:

```toc
## Interface: 120100
## Title: Example
## Dependencies: Lychee
## LoadOnDemand: 1
## SavedVariables: Example_LycheeDB
## X-Lychee-Protocol: 1
## X-Lychee-Package: Example_Lychee
## X-Lychee-Providers: example.gear,example.status
## X-Lychee-Provider-example.gear: title=Equipment;title.zhCN=%E8%A3%85%E5%A4%87;global=0;prefixes=gear;keywords=equipment;ranges=retail:120100:120199:1:9999999;icon=addon:Media/equipment.tga;requires=Lychee
## X-Lychee-Provider-example.status: title=Status;global=0;prefixes=status;ranges=retail:120100:120199:1:9999999;icon=file:134400;requires=Lychee
Provider.lua
```

`X-Lychee-Package` must equal the actual addon directory name. Provider IDs are unique lowercase identifiers using letters, digits, dots and hyphens; each starts with a letter or digit. `X-Lychee-Providers` is an ordered comma-separated list. Each listed ID has exactly one `X-Lychee-Provider-<id>` row.

Rows use `key=value` fields separated by semicolons. Duplicate or unknown keys fail validation. Lists are split before decoding. Encode reserved scalar bytes using uppercase `%HH`, including `%25`, `%3B`, `%3D` and `%2C` for percent, semicolon, equals and comma. Literal valid UTF-8 is accepted; malformed UTF-8, control characters, malformed percent escapes and unescaped scalar commas are rejected. No Lua expression or manifest is evaluated.

| Field | Meaning |
| --- | --- |
| `title` | Required English fallback title. |
| `title.enGB`, `title.zhCN`, `title.zhTW` | Optional localized titles. |
| `description` and the same locale suffixes | Optional localized description. |
| `global` | Required `0` or `1`; participation in unscoped search. |
| `prefixes` | Optional comma-separated normalized routes, such as `gear,status`. |
| `keywords` | Optional comma-separated exact routing words. |
| `ranges` | Required comma-separated `product:minInterface:maxInterface:minBuild:maxBuild`. All bounds are inclusive integers. Overlapping rectangles for one product are rejected. |
| `icon` | Optional `addon:relative/path`, `file:positiveFileID` or `atlas:atlasName`. |
| `requires`, `optional` | Optional comma-separated native addon names. Required dependencies must exist and be enabled; native TOC dependency rules still apply. |
| `purpose` | Optional short package-provided purpose description. |

When `global=0`, at least one prefix or keyword is required. An unsupported product or range is not selected. Conflicting provider IDs or routes invalidate both declarations; enumeration order never chooses a winner. Malformed declarations fail closed, including attempts to register their known IDs through the undeclared legacy path.

Localized title and description resolve through exact locale, then language family (`zhCN` for Chinese, `enUS` otherwise), then English.

The parser is bounded: provider lists, row size, fields, terms, dependencies and ranges have explicit limits. The authoritative limits and scan/preparation scheduling budgets are in [PERFORMANCE.md](PERFORMANCE.md). The Host scans native metadata on demand and yields between batches. Loading does not begin before that scan completes.

## Packaging the declaration

The TOC above is the normative input for this branch. Maintain it in the third-party addon's own build system, preserving its verified native suffix, interface, dependency list and file order. A Host package name is never a substitute for your own media or SavedVariables owner. Do not depend on Lychee's internal client manifest or build tools. Validate the declaration against the runtime contract and test actual cold loading on each claimed client.

## Registration and owned resources

The loaded definition names its addon. Its title, description when declared, routes and resource must match the selected declaration. Its current-product scope may narrow the cold interface/build range, and must still contain the running client. A new declared provider cannot register with a missing or different addon name.

```lua
local addon = ...
local host, SDK = _G.Lychee, _G.Lychee.SDK
host:RegisterReady(function()
    SDK.WhenSavedVariablesReady(addon, function()
        local client = SDK.GetClient()
        local chinese = client.locale == "zhCN" or client.locale == "zhTW"
        local title = chinese and "装备" or "Equipment"
        local handle, err = host:RegisterProvider({
            id = "example.gear", addon = addon,
            apiVersion = "1.0.0", version = "1.0.0",
            title = title, i18n = { enUS = {}, zhCN = {} },
            scope = { products = { client.product },
                minInterface = 120100, maxInterface = 120199,
                minBuild = 1, maxBuild = 9999999 },
            searchGlobal = false,
            searchPrefixes = { "gear" }, searchKeywords = { "equipment" },
            resource = { kind = "addon", path = "Media/equipment.tga" },
            prepare = function(context, reply)
                -- Only bounded preparation of this addon's own data belongs here.
                return { status = "ready" }
            end,
            query = function(request, reply) reply({}) end,
        })
        if not handle then geterrorhandler()(err.code) end
    end)
end)
```

The second provider registers independently in the same addon. Waiting for one requested provider does not require an unrelated sibling to register successfully.

The hot resource forms are `{kind="addon", path="Media/equipment.tga"}`, `{kind="file", id=134400}` and `{kind="atlas", name="atlasName"}`. Addon paths are relative to the declaring package, use forward slashes and cannot traverse directories, name another package or use absolute paths. A separately supplied legacy `icon` must equal the resource's resolved texture value. Package media must ship with that package; it must not depend on the Host's private media directory. See [STORAGE.md](STORAGE.md) for addon-owned storage.

## Loading and readiness

The Host first selects participating providers using the query route and user policy. It merges requested providers by addon, attaches waiters before calling native loading, waits for the addon's SavedVariables readiness and observes successful provider registration. Native disabled addons are never automatically enabled. Missing or disabled dependencies, invalid declarations, failed native loading and missing registration produce terminal failures.

The Host shares one absolute search deadline across discovery, loading, provider preparation and query execution. Adding a later waiter does not restart an earlier request's deadline. Cancellation removes that subscriber; another subscriber can continue using shared work. The native synchronous `LoadAddOn` call cannot be interrupted, and cancelling does not unload Lua already loaded by WoW.

Addon discovery and loading are Host internals, not provider-facing directory APIs. Use `RegisterReady` and `WhenSavedVariablesReady` for registration. The latter returns a cancellation handle and may call back synchronously if SavedVariables are already ready.

## Provider preparation

The optional `prepare(context, reply)` callback prepares provider-owned data without publishing search results or performing a user-requested business action. It may return `{status="ready"}` or `{status="failed", code="REASON"}` synchronously. For asynchronous work it returns a cancellation function, then calls `reply` once with one of those records. Returning nil and replying later is also supported. Exceptions and invalid records fail the preparation.

`context` contains `product`, `interface`, numeric `build`, `locale`, `publicscope`, `deadline` and `resources`. `publicscope` is the bounded public scope string selected by the requester, commonly `search` or `restore`. Resources are a child of the provider's existing resource scope. Completion, cancellation, owner stop and revision invalidation close this child; successful preparation retains only a ready credential, never the child scope or business data. The addon owns any reusable prepared data and its own invalidation policy.

Work is shared only for the same provider instance, revision, locale and scope. Each subscriber has its own absolute deadline. While work is shared, `context.deadline` reflects the latest live subscriber deadline; it is not permission to extend another subscriber's deadline. Providers without `prepare` complete synchronously without creating a preparation timer.

For already registered providers, the optional public service is:

```lua
local token, err = SDK.Preparation:Ensure(
    { "example.gear" }, { scope = "search", intent = "query" },
    SDK.Now() + 5,
    function(result)
        if result.ready["example.gear"] then
            -- Preparation finished; this callback does not contain search data.
        else
            local reason = result.failed["example.gear"]
        end
    end)
-- Later, if this requester no longer needs it: token:Cancel()
```

The request context is a plain table containing only optional `scope` and `intent`; provider ID arrays, deadlines and callback results are checked before use. Metatables, secret/inaccessible values and unknown result fields are rejected. A provider result contains only `status` and optional `code` (at most 96 bytes).

The callback runs only at the request's terminal state and may run synchronously. A cancelled subscriber receives no callback. Invalid arguments or exhausted request capacity return `nil, error`. Accepted requests report per-provider failures in `result.failed`, including `PROVIDER_UNAVAILABLE`, `SEARCH_DISABLED`, `RESOURCE_LIMIT`, `PREPARATION_TIMEOUT`, `INVALID_PREPARATION`, `PREPARATION_ERROR` and `STALE_PREPARATION`. This service does not discover or load cold providers. `intent` is `query`, `visible` or `prewarm`; visible explicit-reference restoration remains available when participation in search is off.

Opening the palette restores only the stable pinned/recent references actually visible in its viewport. Scrolling or expanding supplies new visible demand. The Host loads, prepares and restores each owner independently under the same viewport deadline, so a slow owner does not hold back ready cards from another owner. This does not bypass preparation. Search publishes available current-query results progressively; pending sources do not hold a global completion barrier. It then optionally prepares already-loaded participating providers at lower priority. A real query can join this work and takes priority. Closing the palette removes its unfinished preparation and restoration subscriptions. Provider background work and independently owned business views keep their own lifetimes. Concrete business preparation and execution use the separate [Invocation contract](INVOCATIONS.md).

Visible saved references show a read-only restoration state while pending or unavailable. The Host keeps only a bounded scalar category for each current visible reference: pending, disabled addon, missing provider, deleted target, incompatible version, timeout, unavailable dependency, temporarily unavailable, or other failure. The original saved reference and display fallback remain intact; arbitrary Provider error payloads are not retained or shown as UI text. An unchanged viewport does not automatically retry a terminal failure. Reopening or new visible demand can retry, and closing/changing the session clears its transient status. Loading, provider preparation and target restoration still share that demand's original deadline.

## Search preferences before loading

Opening the source settings page discovers valid metadata without evaluating the independent addon. Its search participation and routing overrides can be edited while cold; these role preferences remain authoritative after registration. A cold declaration has no runtime version yet. Registration invalidates an already-open declaration editor so a stale click cannot modify the new instance. Hiding settings cancels its pending discovery subscription. Excluding a source affects search only, not its background business lifecycle or explicit saved references.
