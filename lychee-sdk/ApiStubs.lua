---@meta
-- Editor-only API 2 declarations. Do not list this file in an AddOn TOC.

---@class LycheeError
---@field code string
---@field field? string
---@field providerID? string
---@field retryable? boolean
---@field message? string

---@class LycheeScope
---@field product? string
---@field locale? string
---@field minInterface? integer
---@field maxInterface? integer
---@field minBuild? integer
---@field maxBuild? integer

---@class LycheeLocalizedText
---@field text string
---@field locale? string
---@field scope? LycheeScope

---@alias LycheeText string|string[]|table<string,string>|LycheeLocalizedText[]
---@alias LycheeContext table<string,any> Plain-data snapshot; never a Host frame.

---@class LycheeSpellAction
---@field id string
---@field title? LycheeText
---@field kind 'secure-spell'|'drag-spell'
---@field spellID integer

---@class LycheeItemAction
---@field id string
---@field title? LycheeText
---@field kind 'secure-item'
---@field itemID integer

---@class LycheeViewAction
---@field id string
---@field title? LycheeText
---@field kind 'open-panel'
---@field panel string
---@field state? table

---@alias LycheeEntryAction string|LycheeSpellAction|LycheeItemAction|LycheeViewAction

---@class LycheeSpellDrag
---@field type 'spell'
---@field spellID integer
---@field title? string

---@class LycheeProviderDrag
---@field type 'provider'
---@field handler string
---@field title? string

---@class LycheeCategory
---@field id? string Provider-local category ID.
---@field title? LycheeText
---@field order? integer
---@field color? number[] RGB or RGBA in [0,1].

---@class LycheeEntry
---@field id string Stable Provider-local identity.
---@field title LycheeText
---@field kind? string Display semantics only; default entry.
---@field kindTitle? LycheeText
---@field subtitle? LycheeText
---@field subtext? LycheeText
---@field description? LycheeText
---@field aliases? LycheeText
---@field keywords? LycheeText
---@field icon? integer|string
---@field category? string|LycheeCategory
---@field payload? table Plain data; functions, frames, cycles and secret values are rejected.
---@field scope? LycheeScope
---@field availability? {contextKey:string,equals:any}
---@field actions? LycheeEntryAction[] Maximum 16; omitted means informational.
---@field primaryActionID? string Defaults to first action.
---@field drag? LycheeSpellDrag|LycheeProviderDrag Omitted means no dragging.

---@class LycheeActionResult
---@field ok boolean
---@field close? boolean Defaults to false.
---@field view? string A view declared by this Provider.
---@field state? table
---@field code? string Failure code when ok=false.
---@field message? string User-readable business failure.

---@class LycheeProviderAction
---@field title string
---@field run fun(entry:LycheeEntry,context:LycheeContext):LycheeActionResult

---@class LycheeDragHandler
---@field title string
---@field begin fun(entry:LycheeEntry,context:LycheeContext):LycheeActionResult

---@class LycheeQueryRequest
---@field raw string
---@field normalized string
---@field tokens string[]
---@field limit integer
---@field generation integer Request lifetime only; do not persist.
---@field contextToken? any
---@field session? integer
---@field visible? boolean
---@field filter? {sourceID?:string,categoryID?:string}

---@alias LycheeReply fun(entries:LycheeEntry[]):boolean?,LycheeError? Single completion, at most 256 entries.
---@alias LycheeCancel fun(reason:string)
---@alias LycheeSchema string|table<string,any>

---@class LycheeViewContext
---@field contentFrame table WoW content container owned by the Host.
---@field width number
---@field height number
---@field extensionID string
---@field panelID string
---@field session integer
---@field generation integer

---@class LycheeView
---@field Mount fun(self:LycheeView,context:LycheeViewContext,initialState:table)
---@field Update? fun(self:LycheeView,state:table,context:LycheeViewContext)
---@field Unmount? fun(self:LycheeView,reason:string)
---@field Dispose? fun(self:LycheeView,reason:string)

---@class LycheeViewFactory
---@field stateSchema table
---@field create fun(context:LycheeViewContext,initialState:table):LycheeView

---@class LycheeProviderDefinition
---@field id string Globally unique; lower-case ASCII letters/numbers/dots/hyphens.
---@field apiVersion 2
---@field minApiRevision? integer Default 1.
---@field version string Integration version.
---@field title string|table<string,string> Localized maps require default.
---@field entries? LycheeEntry[] Maximum 4096; entries or query is required.
---@field query? fun(request:LycheeQueryRequest,reply:LycheeReply,context:LycheeContext):LycheeCancel?
---@field resolve? fun(entryID:string,context:LycheeContext):LycheeEntry?
---@field actions? table<string,LycheeProviderAction>
---@field drags? table<string,LycheeDragHandler>
---@field views? table<string,LycheeViewFactory>
---@field scope? LycheeScope
---@field onEnable? fun(handle:LycheeProviderHandle):LycheeCancel?
---@field onDisable? fun(reason:string)

---@class LycheeProviderUpdate
---@field replace? LycheeEntry[] Mutually exclusive with upsert/remove.
---@field upsert? LycheeEntry[]
---@field remove? string[]

---@class LycheeProviderState
---@field enabled boolean
---@field lifecycle string
---@field revision integer
---@field lastError? LycheeError

---@class LycheeProviderHandle
---@field id string
---@field Update fun(self:LycheeProviderHandle,delta:LycheeProviderUpdate):boolean?,LycheeError?
---@field GetState fun(self:LycheeProviderHandle):LycheeProviderState?,LycheeError?
---@field SetEnabled fun(self:LycheeProviderHandle,enabled:boolean):boolean?,LycheeError?
---@field Unregister fun(self:LycheeProviderHandle):boolean?,LycheeError?

---@class LycheeReadySubscription
---@field Cancel fun(self:LycheeReadySubscription):boolean

---@class LycheeFacade
---@field API_VERSION 2
---@field API_REVISION 1
---@field Supports fun(self:LycheeFacade,apiVersion:integer,minRevision?:integer):boolean
---@field IsReady fun(self:LycheeFacade):boolean
---@field RegisterReady fun(self:LycheeFacade,callback:fun(info:{apiVersion:integer,apiRevision:integer})):LycheeReadySubscription?,LycheeError?
---@field RegisterProvider fun(self:LycheeFacade,definition:LycheeProviderDefinition):LycheeProviderHandle?,LycheeError?

---@type LycheeFacade
Lychee = {}
