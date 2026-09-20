# Client and build variants

[Contents](README.md) · [简体中文](../zh-CN/CLIENT_VARIANTS.md)

This is an implementation convention for Provider API **1.0.0**, using Scope and optional client-context, feature and discovery services. [Performance](PERFORMANCE.md) applies to every implementation.

## Scope is not implementation selection

Products and interface/build bounds filter availability; they do not select business code. One stable provider ID may use different entries, data sources, events, queries, actions and views on different clients. Split providers only for independently meaningful features, not merely different native APIs.

The provider owns its adapter layer. The Host receives one ordinary descriptor and applies the same validation/search/action/lifetime rules. Use `SDK.GetClient()`, never `LycheeInternal`. There is no RegisterVariant API.

1. Keep product, numeric Interface and numeric build distinct. Do not infer client identity from locale, localized names or lexicographic version comparison.
2. Prefer native flavor TOCs loading only the appropriate adapters. Share common code; select a local callback at initialization for small differences rather than creating empty adapter files.
3. Select once before registration using inclusive numeric ranges and required capabilities. Existence alone is not proof of semantics. Distinguish delayed readiness from permanent unavailability; use bounded event-driven retries, not polling/permanent negative caches.
4. Within declared support, require exactly one implementation. Zero matches is unavailable with a diagnostic; overlap is configuration failure. Never choose by declaration order or silently fall back to another client.
5. The submitted scope describes the selected implementation accurately. Different client ranges belong in their respective descriptors; a documentation/test matrix describes their union.
6. Register each ID once. Do not submit several identical IDs or unimplemented variants/implementations fields.
7. Do not poll client identity. A justified runtime switch cancels/releases/unregisters the old instance before creating the new one, rejecting late callbacks.

```text
MyAddon_Mainline.toc -> Shared.lua + RetailAdapter.lua + Register.lua
MyAddon_Mists.toc    -> Shared.lua + MistsAdapter.lua  + Register.lua
MyAddon_Wrath.toc    -> Shared.lua + TitanAdapter.lua  + Register.lua
MyAddon_TBC.toc      -> Shared.lua + AnniversaryAdapter.lua + Register.lua
```

This is an illustrative addon layout. In the example below host means `_G.Lychee`, not the `Lychee.SDK` utility table. SelectAdapter and CreateDefinition belong to your addon:

```lua
local function RegisterForClient(host, client, SelectAdapter)
    if not host or not host:Supports("1.0.0") then
        return nil, { code = "UNSUPPORTED_API" }
    end
    -- SelectAdapter verifies product, numeric ranges and capabilities.
    -- It must reject both no match and overlapping matches.
    local adapter, err = SelectAdapter(client)
    if not adapter then return nil, err end

    -- This factory builds only declarations and closures. No UI/events/timers.
    local definition = adapter:CreateDefinition(client)
    definition.id = "my-addon.equipment" -- same business identity in all clients
    definition.apiVersion="1.0.0"
    -- definition contains this adapter's version, title, scope, i18n,
    -- query, actions/views and onEnable cleanup as needed.
    return host:RegisterProvider(definition)
end
```

For example, native equipment sets and addon-owned sets may need different data/actions. Their shared label does not prove identical IDs, payloads or permissions, or justify expanding supported clients.

## Identity, localization and lifetime

All adapters emit the same public Entry/Action/View contract, without game-category branches in the Host. Reuse entry IDs only for the same business object; namespace unrelated numeric IDs such as native-set:7 versus addon-set:7. Resolve against current facts and capabilities; unmappable old references remain unresolved instead of selecting a similar object.

Shared caches/configuration distinguish product and adapter schema, plus locale/character/interface/build where meaning depends on them. Increment data schema when payload meaning changes. Secure actions still use supported secure descriptors, never ordinary callbacks to bypass protection.

Register the selected provider's own i18n. Share keys only where meaning matches, assemble selected resources before registration, and supply referenced keys in enUS. Do not merge into Host dictionaries or rebuild them on hot paths. Use handle:Text for localized ActionResult.message.

Loading adapters, selecting a branch and CreateDefinition create declarations/callbacks only: no UI, directory scans or subscriptions. Start work in onEnable. Unselected implementations have no events/timers/business UI. Its cleanup releases tasks/subscriptions/references idempotently, without duplicating cleanup in onDisable.

## Validation matrix

Verify every claimed product × range independently: min/max/adjacent boundaries, unknown clients, missing required APIs, zero/overlapping matches, exactly one registration, no work from unused adapters, correct entries/actions, deleted objects, saved references, cancellation/re-enable and secure actions. Verify Chinese/English resources and product/schema isolation. Record versioned wowdoc evidence and distinguish offline from in-game results.

Built-in PlayerSpells selects modern/older spellbook APIs; GameMenus selects client-specific entries. These examples do not establish compatibility for another provider. Lychee's client manifest is private project assembly, not an SDK dependency.

## Client snapshot and discovery

`Lychee:GetClient()` or `Lychee.SDK.GetClient()` returns an isolated `{product,interface,build,locale}` table. build is numeric, unknown product remains unknown, and unreadable builds are not fabricated as supported. The existing `SDK.RuntimeIdentity:Current()` has its own string-build shape.

Cold ranges and loaded Scope must agree. Loaded bounds may narrow, not expand, cold declarations and must contain the current client. Feature checks validate Host contracts, not game API semantics.

| product | Native TOC suffix | Declared/checked Interface |
| --- | --- | --- |
| retail | Mainline | 120100 |
| classic | Mists | 50504 |
| titan | Wrath | 38002 |
| anniversary | TBC | 20506 |

These are declaration/build ranges, not a claim that every client has passed real-game acceptance. Chinese/English builds of one product share protocol and stable IDs.
