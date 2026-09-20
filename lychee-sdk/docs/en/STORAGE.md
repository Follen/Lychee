# Addon-owned storage

[Contents](README.md) · [简体中文](../zh-CN/STORAGE.md)

`Storage.lua` is an independently embeddable SDK 1.0.0 module. Module tests do not replace addon assembly, SavedVariables timing or real-client validation.

| Data | Owner |
| --- | --- |
| Palette preferences, source overrides, pins, history, aliases and selection memory | Host, as bounded preferences/references/display fallbacks |
| Provider business settings, versions and rebuildable persistent caches | The owning addon's SV |
| Current candidates, tasks and pending data | Query scope, released at completion/cancellation |
| Frames, models, callbacks, instances and running queries | Runtime only; never SV |

Declare SV in your TOC and wait for restoration. Use `SavedVariablesPerCharacter` for character settings; account sharing must be explicit. The SDK supplies data rules, not a centralized Host business DB.

## Binding a namespace

Load the embedded Storage.lua before consumers. Its factory is `ns.LycheeSDK.Storage` in the addon's private namespace, not a global singleton. Initialize the root and readiness flag from your own saved-data lifecycle before using this example:

```lua
local addonName, ns = ...
local settings = assert(ns.LycheeSDK.Storage.Open({
    id = "example.feature",
    version = 1,
    root = function() return ExampleCharacterDB.providerSettings end,
    ready = function() return ns.savedVariablesReady == true end,
}))

local enabled, err = settings:Get("showDetails", true)
if err then return end
local ok, writeError = settings:Set("showDetails", false)
```

Open permits only id, version, root, ready and migrations. Options and migration tables must be accessible plain tables, with no unknown fields/metatables/secret values. `root` is an accessor called for each operation, not a captured initial table. It permits character restoration/import/root replacement. Until ready returns true, access fails. A missing/invalid root fails rather than overwriting data WoW has not restored. Accessors must not start business work or switch characters.

Only `root()[id]` is owned by this handle, stored as `{version=n,values={...}}`. Give each provider its own ID/schema. Get copies values/defaults without persisting defaults. Set copies input; nil deletes a key. No mutable saved-table references leak. Close detaches accessors and rejects further operations without deleting data.

Settings are not an evicting cache. Apply the [plain-data limits](MANAGED_RESOURCES.md): invalid/oversized/cyclic/inaccessible or corrupt data fails while preserving the original. Logical bytes are not heap statistics.

A handle belongs to the addon's data layer, not a query/view. Necessary business events may update settings after a page closes. Close an instance-only handle on release; reopen for a new instance. Shared data layers may survive unregister but must not retain old providers/views/queries. No periodic saving, polling or forced GC is added.

## Explicit migration

Get/Set never migrate. Older data returns `STORAGE_MIGRATION_REQUIRED`; newer data returns `STORAGE_NEWER_VERSION` and remains unwritable.

```lua
local settings = assert(ns.LycheeSDK.Storage.Open({
    id = "example.feature",
    version = 2,
    root = function() return ExampleCharacterDB.providerSettings end,
    ready = function() return ns.savedVariablesReady == true end,
    migrations = {
        [1] = function(values)
            values.showDetails = values.expanded
            values.expanded = nil
            return values
        end,
    },
}))
local ok, err = settings:Migrate()
```

Each migration operates on a copied namespace value table, returning the next values. Do not mutate SV/sibling namespaces directly. The SDK validates every sequential step and commits once after the complete chain succeeds. Missing steps, exceptions, capacity violations, handle closure, root changes or concurrent namespace replacement preserve the original. At most 32 steps run per migration. Callbacks are synchronous and cannot be preempted; keep them bounded and outside combat initialization.

`Import(values)` performs full bounded validation/copy and atomically creates an absent namespace. Existing targets return `STORAGE_EXISTS`; no merge/overwrite is inferred. Multiple Set calls are not an atomic transfer.

Moving between owners requires explicit source identity/schema checks, import evidence and retention of the source. Verify the target in a later complete session before the source owner confirms cleanup, including that the source has not changed. An existing target without evidence is not proof of migration. The SDK neither scans Host DB nor deletes another owner's data.

Reentrant same-handle calls from ready/root/migrations return `STORAGE_BUSY`. A callback that closes the handle stops further access. Root or namespace replacement reports `STALE_STORAGE`; no old-character result is written into a new root. Handle errors at initialization/edit boundaries without unbounded retries.

## Large caches and package boundaries

Large achievement-like directories use owner-specific schemas/budgets, with explicit character, language, client, version, invalidation and rebuild semantics. Do not enlarge generic settings limits or copy the full directory on each read. No persistence need means no empty DB. Loaded SV occupies Lua memory; changing the owner does not reduce total cost. True deferred loading requires a separate load unit with its latency/migration/delivery costs measured.

Lychee itself ships as one addon. Its built-in modules use distinct namespaces and own their business schemas, invalidation and migration. These namespaces are not native independently loaded SavedVariables. Third-party addons retain their own TOC, SV, code and media, and may embed Storage.lua. They must not access private Host databases/resources. No public migration-owner registry is promised.

Repository regression: [sdk_storage.lua](https://github.com/Follen/Lychee/blob/main/tests/sdk/sdk_storage.lua). It covers readiness, operation without Host, isolation, root replacement, capacity, atomic import, migration, reentrancy and future-version protection. It does not prove a player's real data has migrated.
