# Search entries and optional catalogs

[Contents](README.md) · [简体中文](../zh-CN/CATALOG.md)

SDK/API **1.0.0**. Host indexing and caller-owned Catalog use the current shared index implementation. Public data uses named fields; internal objects and transfer credentials are not part of the protocol.

| Need | Interface | Ownership |
| --- | --- | --- |
| A small simple directory | RegisterProvider entries / handle:Update | Host indexes bounded public entries; provider owns facts |
| Bounded directory with expensive actions | Provider entryMode="documents" / readEntry | Host stores search documents; full Entries live with candidates/actions |
| Existing search engine | query / resolve | Submit current candidates only |
| Your own incremental searchable directory | SDK.CreateCatalog, default mode="entries" | Caller owns Catalog; no Host registry of all Catalogs |
| Measured savings from delayed Entry construction | Catalog mode="documents" / readEntry | Index search fields, read owned facts after matching |
| Bounded isolated data storage | Optional CompactStore | No automatic SV, business invalidation or Host database |

Do not select documents/encoding just because a directory is large. Compare recall, build cost, hot latency/allocation and post-close retention for the same queries.

## Catalog methods

`SDK.CreateCatalog({id,title?,scope?,i18n?,actions?,drags?,views?,active?,changed?,mode?,readEntry?,compact?})` returns a caller-owned directory or nil,Error. Configuration must be accessible plain data.

| Method | Contract |
| --- | --- |
| `Update({replace=records})` | Atomic replacement, exclusive with upsert/remove; failure retains old state |
| `Update({upsert=records,remove=ids})` | Atomic changes; unique IDs and no write/delete conflict |
| `Search(request)` | Synchronous copied hits or nil,Error; no actions |
| `Query(request,reply,context)` | Bounded results; documents can batch using query resources |
| `Resolve(id)` | Current Entry; a documents reader may restore an explicit ID outside the indexed directory |
| `Invalidate()` | Invalidate active queries/materialization generation; do not fetch facts |
| `GetState()` | Scalar summary; logical bytes are not heap statistics |
| `Clear()` / `Close()` | Clear search data / permanently retire; provider still owns business DB |

Default capacity is 4096. Larger documents catalogs need explicit compact limits and validation. Replies cap at 256, display at 20. changed runs after successful commit; its exception does not mean rollback. Inspect the current generation instead of blindly repeating an update.

```lua
query = function(request, reply, context)
    local ok, err = catalog:Query(request, reply, context)
    if not ok and err then context.fail(err) end
end,
resolve = function(id) return catalog:Resolve(id) end,
```

Do not return Catalog:Query's boolean as a Provider cancellation function. Output still passes public reply validation; there is no promised zero-copy bypass. Close/cancel/update/Clear/Close release active jobs and candidates.

## Documents and readers

SearchDocument permits only `id/title/aliases/keywords/description/category/scope/subtitle/subtext`, with ID and nonempty title required. No actions, Frames, callbacks or business database. Retain all previously searchable fields when optimizing.

`readEntry(id,{ref,revision,reason,resources?})` synchronously returns a current Entry or nil,Error. It must not execute actions or yield. ID must match and capabilities must belong to the Catalog. nil means genuinely missing facts; temporary failures return Error. Only bounded hits are materialized. If capacity prevents proving complete results, return `RESULT_LIMIT`.

Removing a search document does not delete its business object. Explicit restoration still asks the reader. Events, fact changes and Invalidate are provider responsibilities; Catalog does not persist or subscribe automatically.

## Ranking and failure

`SDK.Score(request,entries,scope?)`, `SDK.CreateRanker(request)` and `SDK.SortHits(request,hits,limit?)` provide matching/ranking. Rank before truncation, without bypassing business eligibility. preferredEntryID/ranking contain only this provider's ordinary-entry preferences. Target/command/invocation preference uses complete reference identity in the Host; it must not boost sibling parameter sets sharing an entryID. The Host cannot recover candidates the provider has already truncated.

`context.deadline` is an absolute `SDK.Now()` time shared across discovery/load/preparation/query. `context.fail(Error)` reports incomplete results; `reply({})` means successful zero results. Release request/context/ranker after termination; do not cache preferences across queries. Turning search off cancels search work, not owner availability, explicit saved references or necessary background communication.

## Delayed actions in the Host index

RegisterProvider accepts `entryMode="documents"` with required readEntry. Default entries mode still accepts full Entries. Both use the same handle:Update shape, with records of the selected type, at most 4096. Check `search-documents` and `query-failure` first.

```lua
local facts = { volume = { name = "Volume" } } -- Provider owns business facts
local handle = assert(Lychee:RegisterProvider({
    id = "example.settings", title = "Example", apiVersion = "1.0.0", version = "1.0.0",
    entryMode = "documents",
    entries = {{ id = "volume", title = facts.volume.name }},
    actions = { open = { title = "Open", run = function(entry)
        -- Open this Provider's own setting using entry.payload.key.
        return { ok = true }
    end } },
    readEntry = function(id, context)
        local fact = facts[id]
        if not fact then return nil end
        return { id = id, title = fact.name, payload = { key = id }, actions = { "open" } }
    end,
}))
```

The Host applies its existing matching/ranking/filtering, then reads final static candidates. It does not materialize the entire database or add another Catalog. Host readEntry receives `{ref,revision,reason}`, where reason is query or resolve. It is synchronous, read-only and non-yielding; do not scan all data or write settings. A query usually reads at most 20 static candidates, but dynamic-source completion may cause another merge/read. This is not a cache guarantee.

For invocation restoration, the Host may pass a copied validated complete ref and request entryID (or actionID if absent). It accepts refreshed display only if the returned ID and invocation action/target/parameters match. Missing/failing readers or different parameters preserve saved display fallback; restoration does not write business data or rewrite saved references.

All materialized Entries still undergo isolation, capability and scope validation. Exceptions, invalid results, generation changes and unregister reject a read. A matching document with an unreadable Entry marks search incomplete, not successful empty. The current static window does not scan indefinitely for replacements. Remove permanently invalid documents with Update; report temporary errors explicitly.

The Host weakly registers materialized identity instead of retaining all actions. Visible rows, active actions or callers can still hold Entries. Update/Invalidate make old identities stale. Explicit IDs may be restored outside the search documents and with search off, but owner stop/unregister prevents reads.

Small/simple shared-action Entries may cost less CPU. Documents exchange retained action memory for reading/validation/allocation per candidate. Do not submit the same documents to both Host and Catalog. Catalog documents begin with request.limit matches, supplement only for missing/deduplicated complete references, and inspect at most 256 full candidates. Managed queries yield at 1 ms or 256 checkpoints; pause time is excluded from fuzzy CPU budgets. A single reader/native call cannot be preempted.
