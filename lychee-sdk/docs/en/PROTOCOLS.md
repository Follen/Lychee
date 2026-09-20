# Provider API 1.0.0 reference

[Contents](README.md) · [简体中文](../zh-CN/PROTOCOLS.md)

Public `API_VERSION="1.0.0"`; SDK release **1.0.0**; UI Runtime **1**. Use complete version strings. Unknown fields are rejected. Start with [the tutorial](GETTING_STARTED.md).

## Optional capabilities and public facade

`SDK.SupportsFeature(name,1)` returns false for unknown/unsupported features. Check client-context, discovery, provider-readiness, preparation, invocation, search-documents, compact-storage and query-failure individually. See [loading](LOADING.md), [invocations](INVOCATIONS.md) and [storage](STORAGE.md). No Host source or project manifest is required for third-party integration.

`Lychee:Supports("1.0.0")`, `IsReady()`, `RegisterReady(callback)` and `RegisterProvider(definition)` are facade methods. RegisterReady returns a cancellable subscription. Host readiness and your own SV readiness are separate. `OpenSettings()` opens Host settings. `ObservePalette(callback)` subscribes to open/close and returns Cancel; at most 64 subscriptions, cancelled by their owners when finished.

## Provider definition

| Field | Contract |
| --- | --- |
| id | Required globally unique 1–64 byte lowercase ASCII identifier, letter/digit first, then letters/digits/dots/hyphens |
| apiVersion | Required string `"1.0.0"` |
| version / title | Required integration version and user-facing title; title may be a provider-owned `{key=...}` |
| scope | Optional, default retail. Singular product and products array are mutually exclusive; array contains 1–4 unique retail/classic/titan/anniversary values. Optional interface/build/locale bounds. |
| i18n | Optional for literal text. Dictionaries require complete enUS; optional enGB/zhCN/zhTW, at most 256 keys, 96 bytes/key, 1024 bytes/value and 128 KiB combined. |
| description / icon | Optional management description/texture. Description may use own locale key. Host owns grouping/order; source/order fields are not accepted. |
| query | Optional function(request,reply,context), returning nil or cancellation function |
| resolve | Optional synchronous function(entryID,context), returning current Entry or nil |
| searchGlobal | Optional boolean, default true, independent of shortcut routes |
| searchPrefixes / searchKeywords | Each 0–8 unique literal terms, at most 48 bytes each. Trim edges and ignore ASCII case; reject interior whitespace, commas, colons, rich-text markers and cross-provider conflicts within one route type. |
| addon / resource | Cold-declared providers give their actual addon and owned resource, matching the TOC |
| prepare | Optional owned-data preparation; Host supplies deadline/cancellation |
| describe / resolveTarget / observe / targetView | Optional dynamic invocation capability/target/observation/explicit target view; preparation is read-only |
| actions / drags / views | Named capabilities owned by this provider; results may use only registered capabilities |
| onEnable / onDisable | Optional lifecycle callbacks; onEnable(handle) may return cleanup. Instances never started do not receive disable cleanup. |

Static entries are optional, up to 4096; query may coexist with them. searchable=false excludes the static directory from the generic index; searchMode controls existing static matching entry behavior. These declarations do not replace user participation preferences. The Host indexes bounded public records, not business databases.

## Handle

| Method | Behavior |
| --- | --- |
| Invalidate() | Invalidate old queries/results and notify the active UI; no directory upload |
| SetAvailability(boolean,reason?) | Owner availability, not user preference. Optional reason ≤256 bytes; invalid reason leaves state unchanged; enabling clears it. |
| GetState() | Snapshot of enabled/lifecycle/version/recent-error state |
| Resources() / GetDiagnostics() | Current enabled scope / on-demand counts |
| Text(key,...) | Own dictionary formatting: ≤16 args, string arg ≤1024 bytes, output ≤32768 bytes |
| Unregister() | Cancel queries, unmount views, release scope and retire this handle |
| Update({replace=entries}) | Validated atomic directory replacement |
| Update({upsert=entries,remove=ids}) | Validated atomic incremental update |
| Settings() | Bounded existing Host character-settings facility, not a business database |

Owner availability uses SetAvailability. User participation never calls onDisable or changes the handle's business availability; explicit restore, business views and submitted operations remain valid.

## Queries and ranking

request is plain copied data: raw, originalRaw, rawOffset, normalized, tokens, limit, generation and optional filter/session/visible/contextToken/preferredEntryID/ranking. generation is transient. Host source/category restrictions still apply. originalRaw is complete input; raw follows route removal. rawOffset is a zero-based UTF-8 byte offset supplied only when raw is the exact trailing slice of originalRaw. Never use character counts for byte spans.

ranking maps this provider's ordinary entryIDs to integers 0–38, at most 72 entries. It derives from existing pins/recents, not persisted timestamps/counts. Use `SDK.CreateRanker(request)` before truncating dynamic candidates. Confidence/evidence are separate from personalized ranking; same-query memory takes precedence, ordinary pin/recent bonus is at most 0.038. Complete target/command/invocation preferences are handled by complete identity in the Host, not by scalar entryID hints. No Host ranking can recover a candidate already truncated by the provider. See [Catalog](CATALOG.md).

Reply once with at most 256 Entries or `{entry=Entry,confidence=number,evidence?=table}` hits. confidence is 0–1. evidence must pass plain-data checks, but the Host recomputes matching evidence from the Entry/query rather than trusting caller evidence. Explicit confidence can override score, not eligibility/scope/identity. `SDK.Score(request,entries,scope?)` computes matching but does not business-filter your entries; nonmatching supplied candidates retain a 0.75 fallback. Display caps at 20.

Queries complete at most once within five seconds. Input replacement, close, leaving search, owner stop, unregister and timeout cancel old work. Late replies return `STALE_REQUEST`. Public reply validates caller data, including Catalog output; no private zero-copy bypass is promised. `context.deadline` is absolute SDK.Now seconds shared across discovery/load/preparation/query. `context.fail(Error)` reports an incomplete source; reply({}) reports successful zero results.

## Entry

| Field | Contract |
| --- | --- |
| id | Required string, 1–128 bytes, ASCII alphanumeric first, then alphanumeric or `._:/-`; unique static ID, while dynamic candidates distinguish complete references |
| title | Required nonempty Text after localization |
| kind / kindTitle | Optional semantic kind (default entry) and user-facing type label; kind does not select behavior |
| subtitle / subtext | Optional short Text; subtitle takes priority |
| description | Optional searchable/tooltip Text |
| aliases / keywords | Optional Text, including string arrays |
| icon | Optional native texture file ID/path, otherwise neutral Host icon |
| category | Optional display string or `{id?,title?,order?,color?}`; local IDs are namespaced; color has 3–4 values in 0–1 |
| payload | Optional plain-data table for provider callbacks |
| scope | Optional client/locale eligibility |
| availability | Optional `{contextKey:string,equals:plainValue}`, checked against Host context before execution |
| actions | Optional EntryAction array, at most 16; default empty |
| primaryActionID | Optional declared action ID; default first action |
| drag | Optional explicit descriptor; otherwise dragging is disabled |
| rememberable | Optional boolean, false excludes pins/recents |
| tooltipRows | Optional ≤16 rows, ≤3 strings/row, ≤512 bytes/string |

kindTitle falls back to category title, provider title, then a generic content label; Host theme owns label color. Text may be a string, localization map, `{key="KEY"}`, or array of strings/key references/`{text,locale?,scope?}`. Scope and locale select values. Ordinary callbacks receive copied public Entries; named actions remain ID strings. Mutating a callback copy does not change published data.

## Actions and drag

Unknown kinds/extra fields are rejected. There is no arbitrary secure script or third-party protected executor.

| Descriptor | Meaning |
| --- | --- |
| `"open"` | Provider actions.open.run |
| `{id,title?,kind="invocation",invocation}` | Own valid complete Invocation reference; selected branch owns its parameters/history |
| `{id,title?,kind="open-panel",panel,state?}` | Registered view, with validated state |
| `{id,title?,kind="secure-spell",spellID}` | Positive spell ID; real hardware click required. Secondary menu selection prepares a button; history requires successful cast. |
| `{id,title?,kind="drag-spell",spellID}` | Pick up through Host cursor adapter on click |
| `drag={type="spell",spellID,title?}` | Pick up during an actual drag gesture |
| `drag={type="provider",handler,title?}` | Call own drags[handler].begin for ordinary unprotected business behavior |

Ordinary ActionResult is `{ok=true,close?:boolean,view?:viewID,state?:table}` or `{ok=false,code?:string,message?:string}`. Default keeps search open; view takes precedence over close. Failure does not enter recents. message is user-facing business text; exceptions become CALLBACK_ERROR without raw stacks. Drag results acknowledge success/failure only, not navigation/close.

Before execution, the Host checks session, row binding, provider instance, record version, availability and combat. Current product behavior closes search and rejects all actions in combat; ordinary callbacks do not bypass protected APIs.

## Restore, cancellation and views

Recents store at most eight bounded stable references. Ordinary `{providerID,entryID}` restores synchronously through resolve. target/command/invocation references preserve product/target/parameters and may restore asynchronously with the remaining deadline. Restoration is neither fuzzy search nor a write. See [Invocation](INVOCATIONS.md).

Cancellation cleanup runs at most once, including normal completion, replacement, close, timeout, errors and lifecycle changes. Clean temporary work on success too. Synchronous Lua cannot be preempted.

A view declares `{create,stateSchema}`. Open calls create(context,initialState), then Mount(context,initialState); changes call Update(state,context); exit calls Unmount(reason), then Dispose(reason). create is called for every open; the provider chooses whether to cache one instance. context has contentFrame, width, height, extensionID, panelID, session, generation, resources and Resize/SetFooter/ClearFocus/Close, valid only during that mount.

Returning false is not an exception/failure signal. Exceptions trigger cleanup. Reentrant mount/update returns PANEL_BUSY; cancelled mount returns PANEL_CANCELLED. Reuse native Frames with fresh bindings rather than treating them as garbage-collectable tables. See [view lifecycle](VIEW_LIFECYCLE.md).

## Boundaries and document mode

Reject secret/inaccessible values, cycles, metatables, ordinary-data functions, nonfinite numbers and unknown fields. Errors return nil,Error with at least code, optionally field/providerID/retryable. Helper ERROR_CODES lists declared framework codes, not all possible provider/native errors; retain a generic unknown-error path.

LycheeInternal, index objects, validation credentials, project ProviderModules and generated build assembly are private. Optional `entryMode="documents"` requires readEntry and makes entries/Update accept SearchDocument. The default remains full Entry. Readers create action descriptions without executing them; [Catalog](CATALOG.md) specifies ownership, completeness and lifecycle.
