# Invocation: optional SDK 1.0.0 capability

[Contents](README.md) · [简体中文](../zh-CN/INVOCATIONS.md)

Check `Lychee.SDK.Invocation` before registration. Action and target data versions are independent from SDK/API **1.0.0**. An ordinary action without a parameter schema uses run(entry,context), not invocation semantics.

Built-in Blizzard settings support name search and open-and-locate only. They do not declare parameter writes, natural-language changes or direct adjustment pages. The example.volume/set-volume examples below are third-party teaching examples, not built-in actions.

## Actions and schemas

```lua
actions = {
  ["set-volume"] = {
    title = "Set volume", actionVersion = 1, absolute=true,
    conflictKey="volume", panel="controls", -- controls 必须在 views 中显式注册
    schema = {percent={type="integer", min=0, max=100, step=1, required=true}},
    run = function(invocation, context, reply)
      -- Provider 执行业务并验证结果后，才报告 succeeded。
      return {status="succeeded", changed=true}
    end,
  },
}
```

schema maps parameter names to plain rules. Every type permits required/default/unit; defaults are expanded by normalization and successful preparation, and false is a valid default. Inputs remain unchanged. Reject unknown fields, functions, metatables, cycles, secret/inaccessible values and nonfinite numbers.

| type | Type-specific rules |
| --- | --- |
| string | Required maxLength, optional minLength, in bytes |
| number | Required precision 0–6; optional min/max/step |
| integer | Optional min/max/step |
| boolean | None |
| enum | Required values: 1–32 distinct stable string IDs |
| list | Required scalar items and maxItems; optional minItems/set; no nested lists |

At most 32 parameters and 32 items/list. Each plain-data receive is bounded to depth 6, 256 nodes and 16384 logical bytes; strings ≤1024 bytes, parameter names ≤64 bytes. Strings count actual bytes and other nodes 16, not actual Lua heap. Schema, args and refs all undergo bounded validation; expanded defaults count against final capacity.

Numbers accept Lua numbers or bounded decimal strings without units/exponents. Parse units separately. 30 and 30.0 normalize equally; negative signs remain meaningful. Validate step after conversion to decimal integers at precision, anchored at min or zero. Tolerate binary representation error only: never round, clamp or substitute defaults for invalid user input. Absolute magnitude caps at one billion. List order is meaningful unless set=true, which sorts/deduplicates for equality.

## References and preparation

```lua
local invocation = {
  kind="invocation", product="retail", providerID="example.volume",
  actionID="set-volume", actionVersion=1,
  target={version=1, key={channel="master"}}, args={percent=30},
}
```

TargetRef contains a positive integer version and nonempty bounded named key. Even actions without a naturally recoverable entity need an explicit stable target; never infer identity from display text.

Invocation uses colon methods:

| Method | Result/behavior |
| --- | --- |
| ValidateSchema(schema) | Isolated schema or nil,error |
| NormalizeArgs(schema,args) | Isolated normalized args with explicit defaults, or field error |
| ParsePatterns(raw,patterns,schema?,rawOffset?) | Bounded full literal/slot parse, described below |
| NormalizeStoredRef(ref) | Validate reference only; no loading or execution |
| Equal(a,b) | Bounded complete identity equality; ignores title/icon/sourceTitle fallback and non-legacy entryID hints |
| Prepare(providerID,actionID,target,args,context,reply) | Synchronous prepared,nil,operation; asynchronous nil,{code="PENDING"},operation; optional reply(prepared,error) at most once |
| PrepareStoredRef(ref,context,reply) | Prepare concrete invocation; wrong product/version fails, other kinds report INCOMPLETE_INVOCATION, never downgrade to opening a page |
| ToInvocation(prepared) | Copy normalized concrete reference, not execution credentials |
| Release(prepared) | Release an unused credential, reporting whether released |
| Invoke(prepared,context,reply) | operation,error; reply receives terminal result |

Equality includes kind/product/provider/action and version/target and version/args. Normalization isolates nested lists/defaults/targets. Internal read-only validation may avoid extra copies of Host-owned data but preserves all access, cycle, depth, node, byte and field checks. Mutable third-party schemas are checked each time, not cached unsafely.

Facade wrappers are `Lychee:PrepareInvocation(...)` and `Lychee:InvokeInvocation(...)`. Explicit preparation can cold-load, ensure readiness and restore/describe targets even with search participation off. Neither SDK nor provider preparation may run a business write.

Prepared is an opaque single-use credential, bound to provider registration/enabled lifetime, character, target identity, action/version and capability description. At most 64 active credentials across the Host, otherwise RESOURCE_LIMIT. Fields supplied by callers cannot forge authorization. Invoke consumes once; reprepare after failure/change. Never persist or resubmit Prepared.

## Target restoration and dynamic capabilities

```lua
resolveTarget = function(ref, context, reply)
  return {status="ready", target=ref, identity="stable-target-instance"}
end
describe = function(target, actionID, context, reply)
  return {available=true, revision=1} -- 可带当前 schema、不可用 code
end
```

Callbacks may return plain data synchronously or reply(data) asynchronously and return cancel(reason). Duplicate/stale/timed-out replies are ignored. Target statuses are ready, notReady, temporarilyUnavailable, deleted and incompatible; no same-name substitution. describe permits only available, revision, schema and code; revision/identity are bounded strings or finite numbers. Missing dynamic callbacks use the static declaration and target reference.

Invoke restores/describes/validates again, comparing the prepared identities. Changes in target/schema/capability return CAPABILITY_CHANGED rather than replacing the user's args.

## Completion and cancellation

Parameterized run(invocation,context,reply) receives an isolated invocation and bounded plain context. It may return a result or a cancellation function and later reply. Result fields are status, code, value, changed and optional message. message is provider-localized footer feedback ≤1024 bytes, neither a success predicate nor persisted history. If a native setting still needs Apply, say so; do not call prefill an applied change. The Host supplies generic status/action feedback when message is absent.

- pending means waiting; terminal statuses are succeeded, failed, cancelled and indeterminate, consumed at most once.
- A confirmed success carries a temporary SDK operationID and normalized invocation for Host history.
- operation:GetState() returns isolated state; Cancel is idempotent. Before dispatch it can cancel; after dispatch it reports cancelled only when the business cancel function explicitly confirms true (no later effect), otherwise indeterminate.
- One five-second deadline covers load/readiness/preparation; context.deadline can shorten it using SDK.Now's clock. Invoke re-preparation inherits its outer deadline. Slow synchronous callbacks cannot be interrupted, but overdue success is rejected when they return.
- Exceptions/invalid results after dispatch cannot prove that no write happened: report indeterminate and never automatically retry.
- Navigation failure after business success does not undo the successful operation. Stale UI/characters/late replies cannot reopen views or duplicate history.

Operations use provider resource capacity, one active deadline, and release cancel/context/reply captures at termination. Holding an obsolete reply cannot retain the discarded operation graph; explicitly held operations can still expose copied state. No idle Frame/driver is added; diagnostics cap at 32. Combat/character-end and owner scope closure terminate operations; turning search off does not.

execution="secure" returns SECURE_ACTION_REQUIRED from ordinary Invoke and never calls ordinary run. Prepared does not bypass hardware-click protection.

## Stored references

All new kinds include kind, product, providerID and optional bounded title/icon/sourceTitle fallback.

| kind | Identity |
| --- | --- |
| legacy-entry | entryID, ordinary object opening |
| target | target |
| command | actionID/actionVersion, optional target; missing arguments use the provider's panel |
| invocation | actionID/actionVersion/target/complete normalized args |

Valid data is not proof of current executability. Concrete replay still uses PrepareStoredRef/Invoke. Preserve unknown-version/corrupt saved originals, never derive business identity from display fallback.

## Entries, menu branches and history

An Entry may carry one of invocation, command or targetRef, and optional invocationError={code,field?,span?}. span uses full original input UTF-8 byte positions {start,finish}; invalid/unknown/noninteger/out-of-range fields fail. Actions must be declared explicitly. Missing/invalid args should produce a command plus an explicit argument-entry view action, never silently default the invalid value. An ordinary panel action can open a panel without executing the row's invocation.

Each menu action may carry its own concrete reference:

```lua
actions = {
  {id="enable", title="Enable", kind="invocation", invocation={
    kind="invocation", product="retail", providerID="example.settings",
    actionID="set-enabled", actionVersion=1,
    target={version=1,key={setting="notifications"}}, args={enabled=true},
  }},
  {id="disable", title="Disable", kind="invocation", invocation={
    kind="invocation", product="retail", providerID="example.settings",
    actionID="set-enabled", actionVersion=1,
    target={version=1,key={setting="notifications"}}, args={enabled=false},
  }},
},
primaryActionID = "enable",
```

Descriptor id is unique within the Entry and need not equal the referenced actionID. The reference must belong to the publishing provider, name a registered matching-version action and pass its schema. command/incomplete/foreign references or extra fields fail. The Host copies and validates on receive, then prepares again on user execution. History stores the selected branch, not the default branch's parameters.

A row invocation can coexist with menu invocations: default execution uses the row reference; each menu uses its own. An input error blocks default execution but not an explicitly different ordinary panel/navigation action.

action.panel names a registered view. Restoring command opens it with state equal to saved target.key or an empty table; absent panel gives TARGET_VIEW_UNAVAILABLE. Restoring concrete invocation prepares read-only, preserves execution/optional panel actions and never writes on restoration. Pending stays pending; failures do not fall back to entryID.

Target pins require explicit targetView and resolveTarget. They open only that view with `{target=normalizedTarget}`, whose stateSchema must accept the shape, for example `{target={version="integer",key={channel="string"}}}`. The Host never picks the first view or matches a display name.

Ordinary saved `{providerID,entryID,...}` remains resolve(entryID). Complete parameter identity separates 30 from 50. Ordinary preferences may become preferredEntryID/ranking hints; concrete reference preferences stay complete and do not boost sibling args. Exact invocation aliases restore parameters only on a complete match. Parse business input from request.raw, never normalized text that may discard a minus sign.

Only confirmed succeeded invocations enter history. Pending/failed/cancelled/indeterminate do not. Recents cap at 8/65536 logical bytes; pins at 64/65536. Corrupt originals remain preserved and unwritten. Direct SDK Invoke reports results; Host search/ViewContext records history. Successful Prepare is not business completion.

Different targets/actions/args remain distinct; repeating one invocation updates recency. Ordinary secondary actions retain a bounded actionID; if that action disappears, restoration is unavailable instead of using the default. Records lacking action information retain their ordinary default semantics. History labels identify current source category and actual primary action; provider owns titles/parameter text.

Aliases and query selections each cap at 128 entries/128 KiB logical bytes, preserving complete references. Validate the whole candidate set before writing; capacity failure preserves old data. Oversized saved data enters PERSONALIZATION_LIMIT recovery state without truncating references.

## Provider-owned views and editing

These colon methods start at Mount, not create, and bind to the current provider registration/mount:

- context:Prepare(actionID,target,args,reply): same preparation return contract; close cancels unsubmitted preparation and releases unused credentials.
- context:Invoke(prepared,reply): operation,error. Close detaches UI listeners; submitted operations keep provider/deadline lifetime and can record confirmed current-character success.
- context:BeginEdit(actionID,target,options): edit,error. options are mode="single" or "latest", interval 0–1, onState(state). Default single; latest requires absolute=true.
- context:Observe(target,publish): mount-scoped observation. Provider observe(target,{resources=scope},publish) returns a cancel function or Cancel handle. Old publish returns false after closure.

Observed data is strictly `{stateRevision=number|string,values=plainTable,correlation=number|string?}` under the same limits. It reports state, not authorization; the provider interprets write correlation.

edit supports Push(args), Finish(), Cancel(reason), GetState(). State has status/draft/lastApplied/pending/code. Keep draft separate from confirmed value. At most one preparation/execution plus one replace-latest queued value; first may submit immediately, later values throttle by interval. Finish submits the final queue and records history once after confirmation. Cancel discards unsubmitted values/preparation/throttle; already submitted work finishes boundedly and its final confirmed value may be remembered. Close detaches editing UI immediately.

Provider, conflictKey (default actionID) and normalized target determine one execution sequence. All public Invoke entry points reject overlap with active editing/in-flight work using OPERATION_BUSY. Sharing the conflictKey prevents another non-idempotent action from bypassing it. Internal edit submissions alone use their occupied sequence; public callers cannot forge that permission.

Non-idempotent actions cannot use latest. An indeterminate dispatch preserves a bounded conflict record and rejects retry with OPERATION_UNCERTAIN, including during a reentrant cancel callback before confirmation. Conflict recovery currently ends with provider instance/enabled lifetime; no automatic reconciliation, undo or replay exists. At most 64 edit sessions and 64 combined in-flight/uncertain records, reserving an uncertainty slot before dispatch. Existing resource limits remain.

## Bounded literal patterns

```lua
local parsed = Lychee.SDK.Invocation:ParsePatterns(request.raw, {
  {"volume ", {slot="percent"}, "%"},
  {"音量", {slot="percent"}, "%"},
  {"音量百分之", {slot="percent"}},
}, {percent={type="integer",min=0,max=100,required=true}}, request.rawOffset)
```

At most 32 patterns × 32 segments, also subject to depth 6/256 nodes/16 KiB/1024-byte strings. Segments are nonempty literals or exactly {slot="name"}. Reject adjacent/repeated/unknown slots. No regex/tokenization/target enumeration/backtracking. Literal bytes/case match exactly; providers choose localized patterns. A slot ends at the first following literal delimiter; ambiguous free text needs a provider-defined grammar.

Result is `{status,raw,args?,spans?,rawOffset?,originalSpans?,code?,field?}`, with status notMatched/incomplete/invalid/ambiguous/ready. Match the entire input. Spans are one-based inclusive UTF-8 byte ranges; an empty slot has finish=start-1. Preserve numeric text before normalization. Invalid negatives/precision produce errors, not clamp/default. Different complete args from multiple patterns mean ambiguous. Parsing is pure: no loading/actions; the provider resolves business targets.

Optional rawOffset is integer 0–1024 with rawOffset+#raw≤1024. Supplied offsets produce originalSpans by adding the offset to both boundaries, including ready/invalid/incomplete. Omission preserves raw-relative output. Query exposes rawOffset only for an exact originalRaw trailing slice; never reconstruct it from normalization/character count. The parser validates numeric bounds, not the caller's originalRaw.

Put the relevant originalSpans field into invocationError.span. Default submit remains nonexecuting, focuses/selects the original invalid bytes, or places the insertion point for an empty span. Palette validates binding/session/generation/full input before and after consumption; it rejects out-of-range or split UTF-8 positions. Without a span, retain the error without guessing; explicit alternate panel actions remain usable.

Native evidence: wow-ui-source / retail / 12.1.0, commit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`; SimpleEditBoxAPIDocumentation.lua lines 435–443 defines HighlightText(start,stop), default start=0; Blizzard_AutoComplete/AutoComplete.lua lines 409–410 uses strlen byte offsets. Convert to HighlightText(start-1,finish) and SetCursorPosition(start-1), not character indices. Parser tests cover offsets/Unicode/negative/empty slots; there is no dedicated invocation_input UI test, so complete IME/selection rendering acceptance is not claimed.

The SDK does not provide general NLP, auto-generated argument forms, action/target migrations or generic conflict reconciliation. Providers own vocabulary/patterns, input languages and panels. Built-in Blizzard settings do not consume these patterns. Test full matching, negative/relative intent, multiple targets/numbers and parsing without side effects.

Repository tests: `lua tests/sdk/invocations.lua` and `lua tests/sdk/invocation_flow.lua`. They cover isolation, normalization, credentials, dynamic capabilities, cancellation/reentrancy, real query→execution→history/restore flow, panels, observation and editing. Offline logic is not real-client business/combat/rendering acceptance.
