# Optional caller-owned compact storage

[Contents](README.md) · [简体中文](../zh-CN/COMPACT_STORAGE.md)

SDK/API **1.0.0**. Ordinary providers do not need this module. Documents, compact storage and custom search are independently optional. See [Catalog](CATALOG.md) for search and [Storage](STORAGE.md) for settings persistence.

## Integration

For a SDK Catalog, specify `compact={maxEntries,maxBytes,maxRecordBytes,identity}` with `mode="documents"`. Check `search-documents` and `compact-storage`. The caller owns both instances; there is no Host-wide database registry.

For storage without the Host search engine, embed CompactStore.lua and load it before your code:

```text
vendor/CompactStore.lua
MyProvider.lua
```

```lua
local addonName, ns = ...
local Store = ns.LycheeSDK.CompactStore
local store, err = Store.Create({
    maxEntries = 1000,
    maxBytes = 512 * 1024,
    maxRecordBytes = 4096,
    identity = { schema=1, product="retail", locale="enUS", revision="my-data-1" },
})
if not store then return end -- 实际插件应把err显示或记录到自己的诊断
assert(store:Update({replace={{id="example",title="Example",aliases={"demo"}}}}))
local record = store:Read("example")
```

The numeric budgets are examples, not universal recommendations. Measure actual build/read/update/close costs. Encoding is private; public records remain named tables, and business references store stable IDs, not offsets/internal indices.

## Inputs and limits

maxEntries, maxBytes and maxRecordBytes are required positive finite safe integers. Logical bytes count string bytes and 16 per other node, including keys; they are neither compressed length nor actual Lua heap. Caller-supplied identity is a plain bounded table of at most 4096 logical bytes, typically schema/product/locale/data version. The SDK copies it but does not infer whether it remains current.

Records are plain named tables with IDs of 1–128 bytes: ASCII letter/digit first, then letters/digits or `._:/-`. Reject secret/inaccessible values, metatables, cycles, functions, nonfinite numbers and excessive structures. At most 128 fields per table, with nesting bounded to depth 8. Capacity errors retain the previous generation; no text truncation, silent deletion or automatic business eviction.

## Methods

| Method | Contract |
| --- | --- |
| `Update({replace=records})` | Atomic replacement; do not combine with upsert/remove. An empty array clears; false is invalid. |
| `Update({upsert=records,remove=ids})` | Atomic change; reject duplicate IDs and write/delete conflicts. A no-op preserves generation. |
| `Read(id,out?,revision?)` | Isolated named record, nil if absent. On success replace out contents; input errors leave out unchanged. |
| `Iterate(revision?)` | Iterator yielding stable IDs, unspecified order. Actual changes, Clear and Close invalidate unfinished old iterators. |
| `GetState()` | Isolated revision/entries/bytes/capacities/identity summary, not all data. |
| `Clear()` | Clear records and invalidate old readers; later updates allowed. Does not erase external business facts/SV. |
| `Close()` | Permanently retire and detach records/identity; idempotent. |

Update succeeds with true and reports whether it changed in its third return value; failure is nil,Error. Exhausted or already-invalidated iterators subsequently return nil. After Close, Read/Update/Iterate/GetState report `RESOURCE_CLOSED`; Clear/Close remain idempotent. Stale readers report `STALE_RESULT`. Inspect the iterator's second return value manually to distinguish failure from exhaustion:

```lua
local state = assert(store:GetState())
local nextID, err = store:Iterate(state.revision)
if not nextID then return end
while true do
    local id, why = nextID()
    if why then break end -- 记录诊断或按新代重试
    if not id then break end
    local value, readError = store:Read(id, nil, state.revision)
    if readError then break end
    -- 处理value；不把它反写内部数据，更新使用Update。
end
```

## Ownership

The store does not scan business APIs, subscribe to events, create timers, persist SV, prewarm or register itself globally. Its creator determines Update/Clear/Close. Do not retain query requests, reply functions, Frames or prepared credentials in persistent caches.

Persistence is your own TOC/SV/schema responsibility. Separate generated facts/rebuildable caches from user choices. Identity changes create a new instance; hand over and close the old one rather than mutating identity. Loaded SV remains resident. Internal base/delta/merge thresholds and encoding layouts are not public fields.

CompactStore stores data, not a search index. Catalog supplies matching, ranking and Entry construction. Measure their combined retention, query allocations and latency, not just compressed strings. Offline results are not client performance acceptance.
