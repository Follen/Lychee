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
-- Editor-only API 1.0.0 declarations. Do not list this file in an AddOn TOC.

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
---@field product? string Single-product restriction; omitted Provider product scope defaults to retail.
---@field products? LycheeProduct[] Optional explicit 1..4 unique products; use for supported non-retail clients.
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

---@class LycheeInvocationAction
---@field id string Unique menu descriptor ID; may differ from invocation.actionID.
---@field title? LycheeText
---@field kind 'invocation'
---@field invocation LycheeInvocation Concrete arguments, owned by this Provider; normalized before publication.

---@alias LycheeEntryAction string|LycheeSpellAction|LycheeItemAction|LycheeViewAction|LycheeInvocationAction

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
---@field title LycheeText Required nonempty display title.
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
---@field invocation? LycheeInvocation Complete concrete call; mutually exclusive with command/targetRef.
---@field command? LycheeCommandRef Incomplete command; declare an explicit panel action to collect arguments.
---@field targetRef? LycheeTargetStoredRef Stable target bookmark; restoration requires targetView.
---@field invocationError? {code:string,field?:string,span?:LycheeInputSpan} Preserved validation explanation; optional span addresses originalRaw. Never execute default arguments for invalid input.

---@class LycheeActionResult
---@field ok boolean
---@field close? boolean Defaults to false.
---@field view? string A view declared by this Provider.
---@field state? table
---@field code? string Failure code when ok=false.
---@field message? string User-readable business failure.

---@class LycheeProviderAction
---@field title string|LycheeLocaleKey
---@field run fun(value:LycheeEntry|LycheeInvocation,context:LycheeContext,reply?:fun(result:LycheeInvocationResult):boolean):LycheeActionResult|LycheeInvocationResult|LycheeCancel? Legacy actions receive Entry; actionVersion actions receive Invocation.
---@field actionVersion? integer Positive data version; requires schema and the Invocation result protocol.
---@field schema? table<string,LycheeParameterSchema>
---@field execution? 'ordinary'|'secure' Secure invocations require the existing physical-click broker; ordinary Invoke rejects them.
---@field absolute? boolean Only absolute actions allow latest-wins editing.
---@field conflictKey? string Provider-local conflict domain, combined with stable target.
---@field panel? string Explicit registered view for argument editing; state is target.key or an empty table.

---@class LycheeParameterSchema
---@field type 'string'|'number'|'integer'|'boolean'|'enum'|'list'
---@field required? boolean
---@field default? any Bounded pure data, validated against this schema.
---@field unit? string Display metadata; input parsing remains Provider-owned.
---@field min? number
---@field max? number
---@field step? number Exact decimal step, anchored at min or zero.
---@field precision? integer Required for number; 0..6.
---@field minLength? integer String bytes.
---@field maxLength? integer Required for string; at most 1024 bytes.
---@field values? string[] Required for enum; 1..32 distinct stable IDs.
---@field items? LycheeParameterSchema Required for list; scalar types only.
---@field minItems? integer
---@field maxItems? integer Required for list; at most 32.
---@field set? boolean List-only; sorts and deduplicates normalized values.

---@class LycheeTargetRef
---@field version integer Positive target data version.
---@field key table<string,any> Nonempty bounded pure-data identity; never a display-name fallback.

---@class LycheeStoredRef
---@field kind 'legacy-entry'|'target'|'command'|'invocation'
---@field product string
---@field providerID string
---@field entryID? string Legacy identity; presentation/ranking hint only for other kinds.
---@field title? string Display fallback, excluded from identity.
---@field icon? integer|string Display fallback, excluded from identity.
---@field sourceTitle? string Display fallback, excluded from identity.

---@class LycheeTargetStoredRef: LycheeStoredRef
---@field kind 'target'
---@field target LycheeTargetRef

---@class LycheeCommandRef: LycheeStoredRef
---@field kind 'command'
---@field actionID string
---@field actionVersion integer
---@field target? LycheeTargetRef

---@class LycheeInvocation: LycheeStoredRef
---@field kind 'invocation'
---@field actionID string
---@field actionVersion integer
---@field target LycheeTargetRef
---@field args table<string,any> Fully normalized, bounded arguments; no callbacks or frames.

---@class LycheePreparedInvocation Opaque one-use grant. Do not inspect, forge, copy or persist.

---@class LycheeInvocationResult
---@field status 'pending'|'succeeded'|'failed'|'cancelled'|'indeterminate'
---@field code? string
---@field changed? boolean
---@field value? any Bounded pure data.
---@field invocation? LycheeInvocation Host-added on confirmed success.
---@field operationID? integer Temporary Host identity, never persisted.

---@class LycheeInvocationOperation
---@field Cancel fun(self:LycheeInvocationOperation):boolean
---@field GetState fun(self:LycheeInvocationOperation):LycheeInvocationResult

---@class LycheeEditState
---@field status 'editing'|'succeeded'|'failed'|'cancelled'|'indeterminate'
---@field draft? table
---@field lastApplied? table Last confirmed normalized arguments.
---@field pending boolean
---@field code? string

---@class LycheeEditOptions
---@field mode? 'single'|'latest'
---@field interval? number 0..1 seconds, one bounded throttle timer.
---@field onState? fun(state:LycheeEditState)

---@class LycheeEditSession
---@field Push fun(self:LycheeEditSession,args:table):boolean?,LycheeError?
---@field Finish fun(self:LycheeEditSession):boolean
---@field Cancel fun(self:LycheeEditSession,reason?:string):boolean
---@field GetState fun(self:LycheeEditSession):LycheeEditState

---@class LycheeObservation
---@field stateRevision number|string
---@field values table Bounded pure current state; Provider owns interpretation.
---@field correlation? number|string Optional Provider-defined write correlation, not execution authority.

---@class LycheeInputSpan
---@field start integer 1-based UTF-8 byte start (1..1025).
---@field finish integer Inclusive UTF-8 byte end (0..1024); start-1 denotes an empty insertion span.

---@class LycheeInvocationAPI
---@field ValidateSchema fun(self:LycheeInvocationAPI,schema:table):table?,LycheeError?
---@field NormalizeArgs fun(self:LycheeInvocationAPI,schema:table,args:table):table?,LycheeError?
---@field ParsePatterns fun(self:LycheeInvocationAPI,raw:string,patterns:(string|{slot:string})[][],schema?:table,rawOffset?:integer):{status:string,raw:string,args?:table,spans?:table<string,LycheeInputSpan>,rawOffset?:integer,originalSpans?:table<string,LycheeInputSpan>,code?:string,field?:string}?,LycheeError? Raw-relative spans remain unchanged; optional 0-based UTF-8 byte offset adds originalSpans. Entire addressed input <=1024 bytes.
---@field NormalizeStoredRef fun(self:LycheeInvocationAPI,ref:table):LycheeStoredRef?,LycheeError?
---@field Equal fun(self:LycheeInvocationAPI,left:table,right:table):boolean
---@field Prepare fun(self:LycheeInvocationAPI,providerID:string,actionID:string,target:LycheeTargetRef,args:table,context?:table,reply?:fun(prepared:LycheePreparedInvocation?,error:LycheeError?)):LycheePreparedInvocation?,LycheeError?,LycheeInvocationOperation?
---@field PrepareStoredRef fun(self:LycheeInvocationAPI,ref:LycheeInvocation,context?:table,reply?:fun(prepared:LycheePreparedInvocation?,error:LycheeError?)):LycheePreparedInvocation?,LycheeError?,LycheeInvocationOperation?
---@field ToInvocation fun(self:LycheeInvocationAPI,prepared:LycheePreparedInvocation):LycheeInvocation?,LycheeError?
---@field Release fun(self:LycheeInvocationAPI,prepared:LycheePreparedInvocation):boolean
---@field Invoke fun(self:LycheeInvocationAPI,prepared:LycheePreparedInvocation,context?:table,reply?:fun(result:LycheeInvocationResult)):LycheeInvocationOperation?,LycheeError?
---@field BeginEdit fun(self:LycheeInvocationAPI,providerID:string,actionID:string,target:LycheeTargetRef,options?:LycheeEditOptions,context?:table):LycheeEditSession?,LycheeError?

---@class LycheeDragHandler
---@field title string|LycheeLocaleKey
---@field begin fun(entry:LycheeEntry,context:LycheeContext):LycheeActionResult

---@class LycheeQueryRequest
---@field raw string
---@field originalRaw string Original complete input before source routing.
---@field rawOffset? integer 0-based UTF-8 byte offset, present only when raw is an exact suffix of originalRaw.
---@field normalized string
---@field tokens string[]
---@field limit integer
---@field generation integer Request lifetime only; do not persist.
---@field contextToken? any
---@field session? integer
---@field visible? boolean
---@field filter? {sourceID?:string,categoryID?:string}
---@field preferredEntryID? string
---@field ranking? table<string,integer> Provider-local entry IDs to weights 0..38; at most 72. Query snapshot only.

---@alias LycheeReply fun(hits:LycheeEntry[]|LycheeQueryHit[],replaceSource?:boolean):boolean?,LycheeError? Single completion, at most 256 entries; true replaces this source's static candidates only.
---@alias LycheeRanker fun(entryID:string,confidence:number?):number?,LycheeError? Nil confidence stays nil; result is sorting-only, not reply confidence.
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
---@field Prepare fun(self:LycheeViewContext,actionID:string,target:LycheeTargetRef,args:table,reply?:fun(prepared:LycheePreparedInvocation?,error:LycheeError?)):LycheePreparedInvocation?,LycheeError?,LycheeInvocationOperation? Mount owner and instance only.
---@field Invoke fun(self:LycheeViewContext,prepared:LycheePreparedInvocation,reply?:fun(result:LycheeInvocationResult)):LycheeInvocationOperation?,LycheeError?
---@field BeginEdit fun(self:LycheeViewContext,actionID:string,target:LycheeTargetRef,options?:LycheeEditOptions):LycheeEditSession?,LycheeError?
---@field Observe fun(self:LycheeViewContext,target:LycheeTargetRef,publish:fun(state:LycheeObservation)):LycheeResourceToken?,LycheeError?
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

---@class LycheeAddonResource
---@field kind 'addon'
---@field path string Relative forward-slash path owned and shipped by the declaring AddOn.

---@class LycheeFileResource
---@field kind 'file'
---@field id integer Positive game file ID.

---@class LycheeAtlasResource
---@field kind 'atlas'
---@field name string Game atlas name.

---@alias LycheeProviderResource LycheeAddonResource|LycheeFileResource|LycheeAtlasResource

---@class LycheeProviderDefinition
---@field description? LycheeText
---@field icon? integer|string
---@field addon? string AddOn folder name; must match an applicable discovery declaration when provided.
---@field resource? LycheeProviderResource Must match the cold declaration; addon paths cannot address Host/sibling private media.
---@field id string Globally unique; lower-case ASCII letters/numbers/dots/hyphens.
---@field apiVersion "1.0.0"
---@field searchable? boolean Default true; false excludes static entries and user aliases from general search, including source filters. Dynamic query and stable resolution remain available. Immutable registration option.
---@field searchMode? 'global'|'prefix'|'keyword' Alternative exclusive modes; original behavior retained. New providers should use searchGlobal. Cannot coexist with searchGlobal or searchable=false.
---@field searchGlobal? boolean Ordinary search, default true; false requires at least one prefix/keyword.
---@field searchPrefixes? string[] 0..8 unique literal prefixes, at most 48 bytes each.
---@field searchKeywords? string[] 0..8 unique literal triggers; maps to an empty source query.
---@field version string Integration version.
---@field title string|table<string,string>|LycheeLocaleKey Legacy localized maps require default.
---@field i18n? LycheeLocaleResources Optional for plain text; required when using locale keys. Key <=96 bytes, value <=1024 bytes, total <=128 KiB.
---@field entries? LycheeEntry[] Optional simple static catalog; maximum 4096. Provide entries, query or actions.
---@field query? fun(request:LycheeQueryRequest,reply:LycheeReply,context:LycheeQueryContext):LycheeCancel?
---@field resolve? fun(entryID:string,context:LycheeContext):LycheeEntry?
---@field actions? table<string,LycheeProviderAction>
---@field drags? table<string,LycheeDragHandler>
---@field views? table<string,LycheeViewFactory>
---@field targetView? string Explicit existing view for TargetRef restoration; requires resolveTarget and stateSchema accepting {target=normalizedTarget}.
---@field releaseSearch? fun(reason:string) Release temporary search state; does not disable background work.
---@field prepare? fun(context:table,reply:fun(result:table)):table|LycheeCancel? Read-only readiness preparation; distinct from Invocation Prepare.
---@field resolveTarget? fun(target:LycheeTargetRef,context:table,reply:fun(result:table):boolean):table|LycheeCancel? Ready result requires status='ready', target and stable identity; other statuses: notReady/temporarilyUnavailable/deleted/incompatible.
---@field describe? fun(target:LycheeTargetRef,actionID:string,context:table,reply:fun(result:table):boolean):table|LycheeCancel? Pure {available,revision,schema?,code?} capability snapshot.
---@field observe? fun(target:LycheeTargetRef,context:{resources:LycheeResources},publish:fun(state:LycheeObservation):boolean):LycheeCancel|LycheeResourceToken?
---@field scope? LycheeScope Defaults to retail when no product is declared.
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
---@field Settings fun(self:LycheeProviderHandle):LycheeSettings?,LycheeError? Simple bounded settings owned by this Host registration.
---@field Update fun(self:LycheeProviderHandle,delta:LycheeProviderUpdate):boolean?,LycheeError? Atomic update of the optional simple entries catalog.
---@field Invalidate fun(self:LycheeProviderHandle):boolean?,LycheeError? Invalidate current results after business data changes.
---@field GetState fun(self:LycheeProviderHandle):LycheeProviderState?,LycheeError?
---@field SetAvailability fun(self:LycheeProviderHandle,available:boolean,reason?:string):boolean?,LycheeError? Optional plain reason <=256 bytes; cleared on becoming available. Does not change the user's preference.
---@field Unregister fun(self:LycheeProviderHandle):boolean?,LycheeError?

---@class LycheeReadySubscription
---@field Cancel fun(self:LycheeReadySubscription):boolean

---@class LycheeFacade
---@field SDK LycheeSDK
---@field UI LycheeUIRuntime
---@field OpenSettings fun(self:LycheeFacade):boolean,string?
---@field ObservePalette fun(self:LycheeFacade,callback:fun(visible:boolean)):LycheeReadySubscription?,LycheeError?
---@field API_VERSION "1.0.0"
---@field GetClient fun(self:LycheeFacade):table Current client identity; isolated copy.
---@field SupportsFeature fun(self:LycheeFacade,name:string,version?:integer):boolean
---@field Supports fun(self:LycheeFacade,apiVersion:string):boolean
---@field IsReady fun(self:LycheeFacade):boolean
---@field RegisterReady fun(self:LycheeFacade,callback:fun(info:{apiVersion:"1.0.0"})):LycheeReadySubscription?,LycheeError?
---@field RegisterProvider fun(self:LycheeFacade,definition:LycheeProviderDefinition):LycheeProviderHandle?,LycheeError?
---@field PrepareInvocation fun(self:LycheeFacade,providerID:string,actionID:string,target:LycheeTargetRef,args:table,context?:table,reply?:fun(prepared:LycheePreparedInvocation?,error:LycheeError?)):LycheePreparedInvocation?,LycheeError?,LycheeInvocationOperation?
---@field InvokeInvocation fun(self:LycheeFacade,prepared:LycheePreparedInvocation,context?:table,reply?:fun(result:LycheeInvocationResult)):LycheeInvocationOperation?,LycheeError?

---@type LycheeFacade
Lychee = {}

---@class LycheeUIRuntime
---@field RuntimeVersion 1
---@field Create fun(self:LycheeUIRuntime,parent:any,definition:LycheeUIDefinition):LycheeUIView?,string?
---@field AsView fun(self:LycheeUIRuntime,definition:LycheeUIDefinition,stateSchema?:table):table

---@class LycheeQueryContext: table
---@field resources? LycheeResources  closed at query completion/cancellation/error.
---@field deadline number Absolute deadline in SDK.Now() seconds; loading/preparation/query share this deadline.
---@field fail fun(error:LycheeError):boolean?,LycheeError? Ends this query as incomplete and releases its resources; late calls return STALE_REQUEST.

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

---@class LycheeStorageHandle: LycheeSettings
---@field Import fun(self:LycheeStorageHandle,values:table):boolean?,LycheeError? Atomic import into an absent namespace; never overwrite existing data or delete the source.
---@field Migrate fun(self:LycheeStorageHandle):boolean?,LycheeError? Explicit atomic schema migration.
---@field Close fun(self:LycheeStorageHandle) Release accessor references; keep persisted data.

---@class LycheeStorageOptions
---@field id string Provider namespace in the AddOn-owned root.
---@field version integer Current settings schema.
---@field root fun():table Read the current AddOn-owned settings root.
---@field ready fun():boolean True only after the AddOn's SV has been restored.
---@field migrations? table<integer,fun(values:table):table> Version n to n+1, at most 32 steps per operation.

---@class LycheeStorage
---@field Open fun(options:LycheeStorageOptions):LycheeStorageHandle?,LycheeError?

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
---@field mode? 'entries'|'documents' Defaults to entries.
---@field readEntry? fun(id:string,context:LycheeCatalogReadContext):LycheeEntry?,LycheeError? Required in documents mode; synchronous, no business action execution.
---@field compact? LycheeCompactOptions Explicit caller-owned storage budget; no automatic persistent Host database.
---@field title? LycheeText
---@field scope? LycheeScope
---@field i18n? LycheeLocaleResources
---@field actions? table<string,LycheeProviderAction>
---@field drags? table<string,LycheeDragHandler>
---@field views? table<string,LycheeViewFactory>
---@field active? fun():boolean
---@field changed? fun() Notify the registered Provider after a changed commit.

---@class LycheeCatalog
---@field Update fun(self:LycheeCatalog,delta:LycheeCatalogUpdate):boolean?,LycheeError?
---@field Search fun(self:LycheeCatalog,request:LycheeQueryRequest):LycheeQueryHit[]?,LycheeError?
---@field Query fun(self:LycheeCatalog,request:LycheeQueryRequest,reply:LycheeReply,context?:LycheeQueryContext):boolean?,LycheeError? Never return its boolean from Provider.query; documents batches only with context.resources; entries stays synchronous; forward returned errors to context.fail.
---@field Resolve fun(self:LycheeCatalog,id:string):LycheeEntry?,LycheeError?
---@field Clear fun(self:LycheeCatalog):boolean?,LycheeError?
---@field Close fun(self:LycheeCatalog):boolean
---@field GetState fun(self:LycheeCatalog):LycheeCatalogState?,LycheeError?
---@field Invalidate fun(self:LycheeCatalog):boolean?,LycheeError? Invalidate generated entries after authoritative business data changes.

---@class LycheeCatalogState
---@field revision integer
---@field entries integer
---@field bytes? integer Compact storage logical bytes; not Lua heap usage.

---@class LycheeSearchDocument
---@field id string Stable business ID, never an internal storage position.
---@field title LycheeText Required nonempty display title, using the Entry localization contract.
---@field aliases? LycheeText
---@field keywords? LycheeText
---@field description? LycheeText
---@field category? string|table
---@field scope? LycheeScope
---@field subtitle? LycheeText Display metadata; not an additional matching field.
---@field subtext? LycheeText Display metadata; not an additional matching field.

---@class LycheeCatalogUpdate
---@field replace? LycheeEntry[]|LycheeSearchDocument[] Mutually exclusive with upsert/remove; validated atomically.
---@field upsert? LycheeEntry[]|LycheeSearchDocument[]
---@field remove? string[]

---@class LycheeCatalogReadContext
---@field ref {providerID:string,entryID:string} Lookup hint, not a normalized or persistable StoredRef.
---@field revision integer Expected catalog data generation.
---@field reason 'query'|'resolve'
---@field resources? LycheeResources Current query scope, when supplied.

---@class LycheeCompactOptions
---@field maxEntries integer Explicit positive finite safe integer capacity.
---@field maxBytes integer Total logical byte capacity, including keys.
---@field maxRecordBytes integer Per-record logical byte capacity.
---@field identity table Caller-owned product/locale/data identity; not a global registry key.

---@class LycheeCompactFactory
---@field Create fun(options:LycheeCompactOptions):LycheeCompactStore?,LycheeError? Standalone SDK module return; does not register data with Host.

---@alias LycheeCompactIterator fun():string?,LycheeError?

---@class LycheeCompactState
---@field revision integer
---@field entries integer
---@field bytes integer Logical validated bytes; not Lua heap usage.
---@field maxEntries integer
---@field maxBytes integer
---@field maxRecordBytes integer
---@field identity table Isolated caller identity snapshot.

---@class LycheeCompactStore
---@field Update fun(self:LycheeCompactStore,delta:table):boolean?,LycheeError?,boolean? Third result indicates an actual change on success.
---@field Read fun(self:LycheeCompactStore,id:string,out?:table,revision?:integer):table?,LycheeError?
---@field Iterate fun(self:LycheeCompactStore,revision?:integer):LycheeCompactIterator?,LycheeError?
---@field GetState fun(self:LycheeCompactStore):LycheeCompactState?,LycheeError?
---@field Clear fun(self:LycheeCompactStore):boolean?,LycheeError?
---@field Close fun(self:LycheeCompactStore):boolean

---@class LycheePreparationResult
---@field ready table<string,boolean>
---@field failed table<string,string>

---@class LycheePreparationAPI
---@field Ensure fun(self:LycheePreparationAPI,providerIDs:string[],context:{scope?:string,intent?:"query"|"visible"|"prewarm"},deadline:number,callback:fun(result:LycheePreparationResult)):LycheeResourceToken?,LycheeError? Already registered providers only; terminal callback may be synchronous, cancellation is silent.

---@class LycheeSDK
---@field VERSION '1.0.0'
---@field GetClient fun():table Current client identity; isolated copy.
---@field SupportsFeature fun(name:string,version?:integer):boolean
---@field Invocation? LycheeInvocationAPI Optional capability; feature-probe before registration.
---@field Preparation? LycheePreparationAPI Optional shared readiness preparation.
---@field Now fun():number Monotonic clock used by operation deadlines.
---@field CreateCatalog fun(options:LycheeCatalogOptions):LycheeCatalog?,LycheeError?
---@field Score fun(request:LycheeQueryRequest,entries:LycheeEntry[],scope?:LycheeScope):LycheeQueryHit[]?,LycheeError?
---@field CreateRanker fun(request:LycheeQueryRequest):LycheeRanker?,LycheeError? Compile once per query; rank before truncation.
---@field SortHits fun(request:LycheeQueryRequest,hits:LycheeQueryHit[],limit?:integer):LycheeQueryHit[]?,LycheeError? New sorted array sharing input hits, at most 276 input hits; optional output limit 1..256.
---@field CompileLocales fun(resources:LycheeLocaleResources):table?,LycheeError?
---@field WhenSavedVariablesReady fun(addonName:string,callback:fun()):LycheeReadySubscription?,LycheeError?
---@field Normalizer table Optional text tools, not a business catalog.
---@field RuntimeIdentity {Current:fun(self:table):table} Current client identity copy.
