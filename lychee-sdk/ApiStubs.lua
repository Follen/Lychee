---@meta
---@class LycheeUIView
---@field Update fun(self:LycheeUIView,props:table):boolean,string?
---@field SetState fun(self:LycheeUIView,key:string,value:any):boolean,string?
---@field Get fun(self:LycheeUIView,key:string):any
---@field GetComponent fun(self:LycheeUIView,key:string):any
---@field Release fun(self:LycheeUIView,reason?:string):boolean,string?
---@field Own fun(self:LycheeUIView,key:string,cancel:fun(reason:string)):boolean,string?

---@class LycheeUIDefinition
---@field type 'Fragment'|'Surface'|'Text'|'Icon'|'Button'|'Toggle'|'Input'|'Native'
---@field key? string
---@field props? table Static properties; definition is immutable after Create.
---@field bind? table<string,string|fun(props:table,state:table):any>
---@field on? table<string,fun(props:table,state:table,view:LycheeUIView,frame:any,...)>
---@field children? LycheeUIDefinition[]
---@field create? fun(parent:any):table Native adapter factory.
---@field update? fun(props:table,state:table,view:LycheeUIView)
---@field release? fun(reason:string,view:LycheeUIView)
-- Editor-only API 3 / revision 1 declarations. Do not list this file in an AddOn TOC.

---@class LycheeError
---@field code string
---@field field? string
---@field providerID? string
---@field retryable? boolean
---@field message? string

---@alias LycheeProduct 'retail'|'classic'|'titan'|'anniversary'

---@class LycheeLocaleKey
---@field key string Provider-owned i18n key; no additional fields.

---@class LycheeLocaleResources
---@field enUS table<string,string> Required complete baseline, at most 256 keys.
---@field zhCN? table<string,string> Chinese translations; missing keys fall back to enUS.
---@field zhTW? table<string,string> Missing keys fall back to zhCN then enUS.
---@field enGB? table<string,string> Missing keys fall back to enUS.

---@class LycheeScope
---@field product? string Single-product entry restriction; Provider registration requires products.
---@field products? LycheeProduct[] Required for API 3; 1..4 unique products.
---@field locale? string
---@field minInterface? integer
---@field maxInterface? integer
---@field minBuild? integer
---@field maxBuild? integer

---@class LycheeLocalizedText
---@field text string
---@field locale? string
---@field scope? LycheeScope

---@alias LycheeText string|table<string,string>|LycheeLocaleKey|(string|LycheeLocaleKey|LycheeLocalizedText)[]
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
---@field title? string|LycheeLocaleKey

---@class LycheeProviderDrag
---@field type 'provider'
---@field handler string
---@field title? string|LycheeLocaleKey

---@class LycheeCategory
---@field id? string Provider-local category ID.
---@field title? LycheeText
---@field order? integer
---@field color? number[] RGB or RGBA in [0,1].

---@class LycheeEntry
---@field rememberable? boolean False prevents pin/history storage.
---@field tooltipRows? string[][] At most 16 rows, 3 columns each, 512 bytes per string.
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
---@field title string|LycheeLocaleKey
---@field run fun(entry:LycheeEntry,context:LycheeContext):LycheeActionResult

---@class LycheeDragHandler
---@field title string|LycheeLocaleKey
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
---@field preferredEntryID? string

---@alias LycheeReply fun(hits:LycheeQueryHit[]):boolean?,LycheeError? Single completion, at most 256 entries.
---@alias LycheeCancel fun(reason:string)
---@alias LycheeSchema string|table<string,any>

---@class LycheeViewContext
---Current mount only: clear references on Unmount; do not mutate Host identity fields.
---Context/state are not promised to be immutable or deep-copied on every mount.
---@field resources? LycheeResources  current mount lifetime.
---@field contentFrame table WoW content container owned by the Host.
---@field Resize fun(self:LycheeViewContext,height:number):boolean
---@field SetFooter fun(self:LycheeViewContext,value:string):boolean
---@field ClearFocus fun(self:LycheeViewContext):boolean
---@field Close fun(self:LycheeViewContext):boolean
---@field width number
---@field height number
---@field extensionID string
---@field panelID string
---@field session integer
---@field generation integer

---@class LycheeView
---Provider owns reuse: create runs on every open and may return one cached instance.
---False callback returns are not failure signals; thrown errors trigger cleanup.
---Every close/replace/error invokes Unmount then Dispose; both must be idempotent and tolerate partial Mount.
---Stop events/timers, invalidate late callbacks, clear context/business references; fixed UI may be retained.
---Synchronous lifecycle reentry into mount/update returns PANEL_BUSY. A close request cancels after the callback returns.
---@field Mount fun(self:LycheeView,context:LycheeViewContext,initialState:table)
---@field Update? fun(self:LycheeView,state:table,context:LycheeViewContext)
---@field Unmount? fun(self:LycheeView,reason:string)
---@field Dispose? fun(self:LycheeView,reason:string)

---@class LycheeViewFactory
---Fields are create/stateSchema; no automatic Host cache or lifecycle flag.
---@field stateSchema table
---@field create fun(context:LycheeViewContext,initialState:table):LycheeView

---@class LycheeProviderDefinition
---@field source? {id:string,title:LycheeText}
---@field description? LycheeText
---@field icon? integer|string
---@field order? number
---@field id string Globally unique; lower-case ASCII letters/numbers/dots/hyphens.
---@field apiVersion 3
---@field searchGlobal? boolean Ordinary search, default true; false requires at least one prefix/keyword.
---@field searchPrefixes? string[] 0..8 unique literal prefixes, at most 48 bytes each.
---@field searchKeywords? string[] 0..8 unique literal triggers; maps to an empty source query.
---@field minApiRevision? integer Minimum API 3 revision; current 1.
---@field version string Integration version.
---@field title string|table<string,string>|LycheeLocaleKey Legacy localized maps require default.
---@field i18n LycheeLocaleResources Required for API 3. Key <=96 bytes, value <=1024 bytes, total <=128 KiB.
---@field query fun(request:LycheeQueryRequest,reply:LycheeReply,context:LycheeQueryContext):LycheeCancel?
---@field resolve? fun(entryID:string,context:LycheeContext):LycheeEntry?
---@field actions? table<string,LycheeProviderAction>
---@field drags? table<string,LycheeDragHandler>
---@field views? table<string,LycheeViewFactory>
---@field scope LycheeScope
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
---@field Resources fun(self:LycheeProviderHandle):LycheeResources?,LycheeError?
---@field GetDiagnostics fun(self:LycheeProviderHandle):LycheeResourceDiagnostics?,LycheeError?
---@field Text fun(self:LycheeProviderHandle,key:string,...:string|number):string?,LycheeError? Up to 16 arguments; strings <=1024 bytes, output <=32768 bytes.
---@field Invalidate fun(self:LycheeProviderHandle):boolean?,LycheeError? Invalidate current results after business data changes.
---@field GetState fun(self:LycheeProviderHandle):LycheeProviderState?,LycheeError?
---@field SetAvailability fun(self:LycheeProviderHandle,available:boolean,reason?:string):boolean?,LycheeError? Does not change the user's preference.
---@field Unregister fun(self:LycheeProviderHandle):boolean?,LycheeError?

---@class LycheeReadySubscription
---@field Cancel fun(self:LycheeReadySubscription):boolean

---@class LycheeFacade
---@field SDK LycheeSDK
---@field UI LycheeUIRuntime
---@field OpenSettings fun(self:LycheeFacade):boolean,string?
---@field ObservePalette fun(self:LycheeFacade,callback:fun(visible:boolean)):LycheeReadySubscription?,LycheeError?
---@field API_VERSION 3
---@field API_REVISION 1
---@field Supports fun(self:LycheeFacade,apiVersion:integer,minRevision?:integer):boolean
---@field IsReady fun(self:LycheeFacade):boolean
---@field RegisterReady fun(self:LycheeFacade,callback:fun(info:{apiVersion:integer,apiRevision:integer})):LycheeReadySubscription?,LycheeError?
---@field RegisterProvider fun(self:LycheeFacade,definition:LycheeProviderDefinition):LycheeProviderHandle?,LycheeError?

---@type LycheeFacade
Lychee = {}

---@class LycheeUIRuntime
---@field RuntimeVersion 1
---@field Create fun(self:LycheeUIRuntime,parent:any,definition:LycheeUIDefinition):LycheeUIView?,string?
---@field AsView fun(self:LycheeUIRuntime,definition:LycheeUIDefinition,stateSchema?:table):table

---@class LycheeQueryContext: table
---@field resources? LycheeResources  closed at query completion/cancellation/error.

---@class LycheeResourceToken
---@field Cancel fun(self:LycheeResourceToken,reason?:string):boolean

---@class LycheeResourceDiagnostics
---@field active boolean
---@field resources integer Direct registrations in this scope.
---@field providerResources integer Aggregate registrations across scopes.
---@field errors integer Callback failures in this scope.
---@field limit integer

---@class LycheeTaskHandlers
---@field complete? fun(value:any)
---@field error? fun(errorValue:any)
---@field combat? fun() End task before resuming in combat, only when declared.

---@class LycheeResources
---@field Own fun(self:LycheeResources,key:string,cleanup:fun(reason:string)):LycheeResourceToken?,LycheeError?
---@field After fun(self:LycheeResources,key:string,seconds:number,callback:fun()):LycheeResourceToken?,LycheeError?
---@field Run fun(self:LycheeResources,key:string,work:fun():any,handlers?:LycheeTaskHandlers):LycheeResourceToken?,LycheeError?
---@field OnEvent fun(self:LycheeResources,event:string,callback:fun(event:string,...)):LycheeResourceToken?,LycheeError?
---@field Cache fun(self:LycheeResources,key:string,options?:{entries?:integer,bytes?:integer}):LycheeCache?,LycheeError?
---@field IsActive fun(self:LycheeResources):boolean
---@field GetDiagnostics fun(self:LycheeResources):LycheeResourceDiagnostics

---@class LycheeSettings
---@field Get fun(self:LycheeSettings,key:string,default?:any):any,LycheeError?
---@field Set fun(self:LycheeSettings,key:string,value:any):boolean?,LycheeError?
---@field Import fun(self:LycheeSettings,values:table):boolean?,LycheeError? Atomic import into an absent namespace; never overwrite existing data or delete the source.
---@field Migrate fun(self:LycheeSettings):boolean?,LycheeError? Explicit atomic schema migration.
---@field Close fun(self:LycheeSettings) Release accessor references; keep persisted data.

---@class LycheeStorageOptions
---@field id string Provider namespace in the AddOn-owned root.
---@field version integer Current settings schema.
---@field root fun():table Read the current AddOn-owned settings root.
---@field ready fun():boolean True only after the AddOn's SV has been restored.
---@field migrations? table<integer,fun(values:table):table> Version n to n+1, at most 32 steps per operation.

---@class LycheeStorage
---@field Open fun(options:LycheeStorageOptions):LycheeSettings?,LycheeError?

---@class LycheeCache
---@field Get fun(self:LycheeCache,key:string):any,LycheeError?
---@field Set fun(self:LycheeCache,key:string,value:any):boolean?,LycheeError?
---@field Clear fun(self:LycheeCache):boolean?,LycheeError?
---@field GetDiagnostics fun(self:LycheeCache):{entries:integer,bytes:integer,entryLimit:integer,byteLimit:integer,active:boolean}

---@class LycheeQueryHit
---@field entry LycheeEntry
---@field confidence number In [0,1].
---@field evidence? table Plain scoring evidence.

---@class LycheeCatalogOptions
---@field id string
---@field title? LycheeText
---@field scope? LycheeScope
---@field i18n? LycheeLocaleResources
---@field actions? table<string,LycheeProviderAction>
---@field drags? table<string,LycheeDragHandler>
---@field views? table<string,LycheeViewFactory>
---@field active? fun():boolean
---@field changed? fun() Notify the registered Provider after a changed commit.

---@class LycheeCatalog
---@field Update fun(self:LycheeCatalog,delta:LycheeProviderUpdate):boolean?,LycheeError?
---@field Search fun(self:LycheeCatalog,request:LycheeQueryRequest):LycheeQueryHit[]?,LycheeError?
---@field Query fun(self:LycheeCatalog,request:LycheeQueryRequest,reply:LycheeReply):boolean?,LycheeError? Only the live Host reply; never return its boolean from Provider.query.
---@field Resolve fun(self:LycheeCatalog,id:string):LycheeEntry?,LycheeError?
---@field Clear fun(self:LycheeCatalog):boolean
---@field Close fun(self:LycheeCatalog):boolean
---@field GetState fun(self:LycheeCatalog):{revision:integer,entries:integer}?,LycheeError?

---@class LycheeSDK
---@field VERSION '1.0.0'
---@field CreateCatalog fun(options:LycheeCatalogOptions):LycheeCatalog?,LycheeError?
---@field Score fun(request:LycheeQueryRequest,entries:LycheeEntry[],scope?:LycheeScope):LycheeQueryHit[]?,LycheeError?
---@field CompileLocales fun(resources:LycheeLocaleResources):table?,LycheeError?
---@field WhenSavedVariablesReady fun(addonName:string,callback:fun()):LycheeReadySubscription?,LycheeError?
---@field Normalizer table Optional text tools, not a business catalog.
---@field RuntimeIdentity {Current:fun(self:table):table} Current client identity copy.
