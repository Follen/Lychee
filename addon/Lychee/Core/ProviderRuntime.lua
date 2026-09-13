local I = _G.LycheeInternal
local P = { entries = {}, jobs = {}, diagnostics = {}, queryEpoch = 0, instanceSequence = 0, queryLimit = 256 }
I.Providers = P
-- Membership follows each live resolved snapshot, not its ID: pins and recent
-- may resolve the same entry independently. UI/action references keep it alive.
local catalogReplies, catalogToken = {}, {}
local weakRecords = { __mode = "k" }
local function resolvedRecords() return setmetatable({}, weakRecords) end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function failure(code, field, owner)
    return nil, { code = code, field = field, providerID = owner, retryable = false }
end
local function publicQueryRequest(request)
    local result={}
    for key,value in pairs(request) do
        if key=="filter" and type(value)=="table" then
            local filter={}
            for field,setting in pairs(value) do
                if field~="excludedSources" and field~="policyVersion" then filter[field]=copy(setting) end
            end
            if next(filter) then result.filter=filter end
        else result[key]=copy(value) end
    end
    return result
end
local function report(entry, code, field)
    entry.lastError = { providerID = entry.id, code = code, field = field }
    P.diagnostics[#P.diagnostics + 1] = entry.lastError
    if #P.diagnostics > 32 then table.remove(P.diagnostics, 1) end
end
local function validID(id)
    return type(id) == "string" and #id > 0 and #id <= 64 and id:match("^[a-z0-9][a-z0-9%.%-]*$")
end
local function keys(value, allowed, field)
    for key in pairs(value) do if not allowed[key] then return failure("INVALID_SCHEMA", field .. "." .. tostring(key)) end end
    return true
end
local function array(value, limit, field)
    if type(value) ~= "table" then return failure("INVALID_SCHEMA", field) end
    if #value > limit then return failure("RESULT_LIMIT", field) end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key ~= math.floor(key) then return failure("INVALID_SCHEMA", field) end
        count = count + 1
    end
    return count == #value and true or failure("INVALID_SCHEMA", field)
end

local function records(entry,input,limit)
    local list,map=I.RecordCodec:Receive(entry,input,limit or P.queryLimit)
    if list then I.Boundary:_ConsumeRecordReceipt(list) end
    return list,map
end
local function active(entry)
    local identity = I.Search.RuntimeIdentity
    return P.entries[entry.id] == entry and I.Registry:IsEnabled(entry.id)
        and (not identity or identity:MatchesScope(entry.definition.scope))
end
local function finish(job, reason)
    if job.done then return end
    if job.reply then catalogReplies[job.reply]=nil;job.reply=nil end
    job.done, job.reason = true, reason
    P.jobs[job] = nil
    local resources,timer=job.resources,job.timer
    job.resources,job.timer=nil,nil
    local cancel = job.cancel; job.cancel = nil
    if timer and not pcall(timer.Cancel,timer) then report(job.entry,"CALLBACK_ERROR","query.timer") end
    if resources then I.Resources:Close(resources, reason) end
    if cancel then
        local ok = pcall(cancel, reason)
        if not ok then report(job.entry, "CALLBACK_ERROR", "query.cancel") end
    end
end
function P:CancelQueries(reason, owner)
    if not owner then self.queryEpoch = self.queryEpoch + 1 end
    local epoch = self.queryEpoch
    local pending = {}
    for job in pairs(self.jobs) do if not owner or job.entry == owner then pending[#pending + 1] = job end end
    for index = 1, #pending do finish(pending[index], reason or "cancelled") end
    return epoch
end

function P:Register(definition)
    local ok, err = I.Boundary:Validate(definition, "provider", {
        maxFields = 256, maxDepth = 12,
        callbacks = { query = true, resolve = true, run = true, begin = true, create = true, onEnable = true, onDisable = true },
    })
    if not ok then return nil, err end
    if type(definition) ~= "table" then return failure("INVALID_SCHEMA", "provider") end
    ok, err = keys(definition, { id=true, apiVersion=true, version=true, title=true,
        description=true,icon=true,source=true,order=true,
        query=true, resolve=true, searchGlobal=true, searchPrefixes=true, searchKeywords=true, actions=true, drags=true, views=true, scope=true, i18n=true, onEnable=true, onDisable=true }, "provider")
    if not ok then return nil, err end
    if not validID(definition.id) or type(definition.version) ~= "string" or definition.version == "" then return failure("INVALID_SCHEMA", "provider.id/version") end
    if not _G.Lychee:Supports(definition.apiVersion) then return failure("UNSUPPORTED_API", "apiVersion") end
    if definition.order~=nil and (type(definition.order)~="number" or definition.order~=definition.order or math.abs(definition.order)>10000) then
        return failure("INVALID_SCHEMA","order")
    end
    if definition.icon~=nil and not (type(definition.icon)=="string" and #definition.icon>0 and #definition.icon<=512)
        and not (type(definition.icon)=="number" and definition.icon>0 and definition.icon<math.huge and definition.icon==math.floor(definition.icon)) then
        return failure("INVALID_SCHEMA","icon")
    end
    if definition.source~=nil then
        local source=definition.source
        if type(source)~="table" or type(source.id)~="string" or #source.id==0 or #source.id>128 then return failure("INVALID_SCHEMA","source") end
        ok,err=keys(source,{id=true,title=true},"source");if not ok then return nil,err end
    end
    if I.Search.ProviderPolicy then
        local valid,field=I.Search.ProviderPolicy:ValidateDefinition(definition)
        if not valid then return failure("INVALID_SCHEMA",field) end
    end
    if definition.scope ~= nil and type(definition.scope) ~= "table" then return failure("INVALID_SCHEMA", "scope") end
    ok, err = I.Boundary:ValidateScope(definition.scope or {},"scope")
    if not ok then return nil, err end
    if not definition.scope or not definition.scope.products or definition.i18n==nil then
        return failure("INVALID_SCHEMA","scope.products/i18n")
    end
    local localizer
    if definition.i18n~=nil then
        if not I.ProviderLocales then return failure("UNSUPPORTED_API","i18n") end
        localizer,err=I.ProviderLocales:Compile(definition.i18n)
        if not localizer then return nil,err end
    end
    local ownedDefinition={}
    for key,value in pairs(definition) do if key~="entries" and key~="i18n" then ownedDefinition[key]=copy(value) end end
    definition=ownedDefinition
    if localizer then
        if definition.description~=nil then
            definition.description,err=localizer:Resolve(definition.description)
            if not definition.description then return nil,err end
        end
        if definition.source and definition.source.title~=nil then
            definition.source.title,err=localizer:Resolve(definition.source.title)
            if not definition.source.title then return nil,err end
        end
        definition.title,err=localizer:Resolve(definition.title)
        if not definition.title then
            if err then return nil,err end
            return failure("INVALID_SCHEMA","provider.title")
        end
        for _,field in ipairs({"actions","drags"}) do
            if type(definition[field])=="table" then
                for _,action in pairs(definition[field]) do
                    if type(action)=="table" and action.title then
                        action.title,err=localizer:Resolve(action.title)
                        if not action.title then return nil,err end
                    end
                end
            end
        end
    end
    if definition.description~=nil and (type(definition.description)~="string" or #definition.description>512) then return failure("INVALID_SCHEMA","description") end
    if definition.source and definition.source.title~=nil and (type(definition.source.title)~="string" or #definition.source.title==0 or #definition.source.title>128) then return failure("INVALID_SCHEMA","source.title") end
    if type(definition.query)~="function" then return failure("INVALID_SCHEMA","query") end
    for _, field in ipairs({ "query", "resolve", "onEnable", "onDisable" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "function" then return failure("INVALID_SCHEMA", field) end
    end
    for _, field in ipairs({ "actions", "drags", "views" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "table" then return failure("INVALID_SCHEMA", field) end
        for id, value in pairs(definition[field] or {}) do
            local callback = field == "actions" and "run" or field == "drags" and "begin" or "create"
            if not validID(id) or type(value) ~= "table" or type(value[callback]) ~= "function" then return failure("INVALID_SCHEMA", field) end
            local allowed = field == "views" and { create=true, stateSchema=true } or { title=true, [callback]=true }
            ok, err = keys(value, allowed, field .. "." .. id); if not ok then return nil, err end
            if field ~= "views" and (type(value.title) ~= "string" or value.title == "") then return failure("INVALID_SCHEMA", field .. ".title") end
            if field == "views" and type(value.stateSchema) ~= "table" then return failure("INVALID_SCHEMA", "views.stateSchema") end
            if field == "views" then
                ok, err = I.Boundary:Validate(value.stateSchema, "views.stateSchema")
                if not ok then return nil, err end
            end
        end
    end
    self.instanceSequence = self.instanceSequence + 1
    local entry = { id = definition.id, instanceToken = self.instanceSequence, definition = definition, revision = 1, dynamic = {}, resolved = resolvedRecords(), dynamicEpoch = 0, localizer=localizer }
    local handle,internal,enabledBeforeCommit
    local function start()
        if not internal then enabledBeforeCommit = true; return end
        if not active(entry) or entry.started then return end
        entry.started = true
        entry.lifecycleEpoch=(entry.lifecycleEpoch or 0)+1
        local lifecycle=entry.lifecycleEpoch
        if definition.onEnable then
            local called, cleanup = pcall(definition.onEnable, handle)
            if not called then report(entry, "CALLBACK_ERROR", "onEnable")
            elseif type(cleanup) == "function" then
                if active(entry) and entry.lifecycleEpoch==lifecycle then entry.cleanup = cleanup
                elseif not pcall(cleanup, "cancelled-enable") then report(entry, "CALLBACK_ERROR", "cleanup") end
            elseif cleanup ~= nil then report(entry, "INVALID_CALLBACK", "onEnable.cleanup") end
        end
    end
    local function stop(reason)
        local wasStarted = entry.started
        entry.started = nil
        entry.lifecycleEpoch=(entry.lifecycleEpoch or 0)+1
        local lifecycle=entry.lifecycleEpoch
        local resources=entry.resources;entry.resources=nil
        local cleanup = entry.cleanup; entry.cleanup = nil
        local pending={}
        for job in pairs(P.jobs) do if job.entry==entry then pending[#pending+1]=job end end
        entry.dynamic, entry.resolved = {}, resolvedRecords()
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        if resources then I.Resources:Close(resources,reason) end
        for _,job in ipairs(pending) do finish(job,reason) end
        if cleanup and not pcall(cleanup, reason) then report(entry, "CALLBACK_ERROR", "cleanup") end
        if wasStarted and entry.lifecycleEpoch==lifecycle and definition.onDisable
            and not pcall(definition.onDisable, reason) then report(entry, "CALLBACK_ERROR", "onDisable") end
    end
    local draft
    draft, err = I.Registry:Begin({ id = entry.id, title = definition.title, version = definition.version,
        apiVersion = definition.apiVersion,
        onEnabled = start, onDisabled = stop }, { public = true })
    if not draft then return nil, err end
    for id, view in pairs(definition.views or {}) do
        ok, err = draft:RegisterPanelFactory({ id = id, create = view.create, stateSchema = view.stateSchema })
        if not ok then draft:Abort(); return nil, err end
    end
    internal, err = draft:Commit()
    if not internal then return nil, err end
    self.entries[entry.id] = entry
    if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
    handle = {id=entry.id}
    function handle:Invalidate()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not active(entry) then return failure("PROVIDER_DISABLED",nil,entry.id) end
        entry.revision=entry.revision+1
        entry.dynamic,entry.resolved={},resolvedRecords()
        P:CancelQueries("provider-changed",entry)
        if active(entry) and I.Search.Session then I.Search.Session:SourceChanged(entry.id) end
        return true
    end
    function handle:Resources()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not active(entry) then return failure("PROVIDER_DISABLED",nil,entry.id) end
        if not entry.resources then
            entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end)
        end
        return entry.resources
    end
    function handle:GetDiagnostics()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        return entry.resources and entry.resources:GetDiagnostics() or {active=false,resources=0,providerResources=0,errors=0,limit=I.Resources.limit}
    end
    function handle:Text(key,...)
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not entry.localizer then return failure("INVALID_LOCALE_KEY","i18n",entry.id) end
        return entry.localizer:Text(key,...)
    end
    function handle:GetState()
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        local state = internal:GetState()
        return { enabled = active(entry), ownerEnabled = state.ownerEnabled, userEnabled = state.userEnabled,
            lifecycle = state.lifecycle, revision = entry.revision, lastError = copy(entry.lastError) }
    end
    function handle:SetAvailability(available,reason)
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if entry.updating then return nil,{code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        local valid=I.Boundary:Validate(reason,"availability.reason")
        if not valid or type(available)~="boolean" or reason~=nil and (type(reason)~="string" or #reason>256) then
            return failure("INVALID_SCHEMA","availability",entry.id)
        end
        local previous=entry.unavailableReason
        entry.unavailableReason=not available and reason or nil
        local ok,why=internal:SetEnabled(available)
        if not ok then entry.unavailableReason=previous;return nil,why end
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if previous~=entry.unavailableReason then I.Registry:NotifyMetadata(entry.id) end
        return true
    end
    function handle:Unregister()
        if P.entries[entry.id] ~= entry then return true end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        local removed, removeError = internal:Unregister()
        if removed then
            P.entries[entry.id] = nil
            if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
            entry.localizer=nil
            entry.metadataPool, entry.actionRecords, entry.actionLists = nil, nil, nil
            entry.dynamic, entry.resolved = {}, {}
            definition.actions, definition.drags, definition.views, definition.query, definition.resolve = nil, nil, nil, nil, nil
            definition.onEnable, definition.onDisable = nil, nil
        end
        return removed, removeError
    end
    if enabledBeforeCommit then start() end
    return handle
end

function P:CreateViewResources(owner)
    local entry=self.entries[owner]
    if not entry or not active(entry) then return nil end
    if not entry.resources then entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end) end
    return I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end,entry.resources)
end

function P:Stamp(item, dynamic)
    local entry = item and self.entries[item._ext]
    if not entry then
        if item and item._ext and item.sourceID then item.ref = { providerID = item._ext, entryID = item.id, sourceID = item.sourceID } end
        return item
    end
    item.ref = {providerID=entry.id,entryID=item.id}
    if not getmetatable(item) then
        item.providerID=entry.id
        item._providerInstance,item._providerRevision=entry,entry.revision
        item._dynamicEpoch=dynamic and entry.dynamicEpoch or nil
    end
    item._providerRecord = item.searchRecord
    return item
end
function P:IsCurrent(item)
    local entry = item and item._providerInstance
    if not entry then return true end
    local record, identity = item._providerRecord, I.Search.RuntimeIdentity
    return active(entry) and item._providerRevision == entry.revision
        and record ~= nil and (not identity or identity:MatchesScope(record.scope or entry.definition.scope))
        and (not item._dynamicEpoch or item._dynamicEpoch == entry.dynamicEpoch)
        and (item._providerRecord == entry.dynamic[item.id] or entry.resolved[item._providerRecord] == true)
end
local function materialize(entry, record)
    local presentation=entry.presentation
    if not presentation or presentation.revision~=entry.revision or presentation.epoch~=entry.dynamicEpoch then
        local sourceID=entry.id..":records"
        local metadata={source=sourceID,sourceID=sourceID,sourceTitle=I.Search.Normalizer:Display(entry.definition.title),
            _ext=entry.id,providerID=entry.id,_providerInstance=entry,_providerRevision=entry.revision,_dynamicEpoch=entry.dynamicEpoch}
        presentation={sourceID=sourceID,confidence=0.75,metadata={__index=metadata},revision=entry.revision,epoch=entry.dynamicEpoch}
        entry.presentation=presentation
    end
    local item = I.Search.ResultSnapshot:Materialize(entry.presentation,record)
    item.stableID=entry.id..":"..record.id
    P:Stamp(item, true)
    item._providerRecord = record
    return item
end
function P:CanRemember(item)
    local entry=item and self.entries[item.providerID]
    return entry and active(entry) and item._providerInstance==entry and item._providerRecord.rememberable~=false and type(entry.definition.resolve)=="function"
end
function P:Resolve(ref,context)
    if type(ref)~="table" or type(ref.providerID)~="string" or type(ref.entryID)~="string" then return nil end
    local entry=self.entries[ref.providerID]
    if not entry or not active(entry) or not entry.definition.resolve then return nil end
    local revision=entry.revision
    local ok,result=pcall(entry.definition.resolve,ref.entryID,copy(context or {}))
    if not ok then report(entry,"CALLBACK_ERROR","resolve");return nil end
    if not active(entry) or revision~=entry.revision or result==nil then return nil end
    local list,err=records(entry,{result},1)
    if not list or list[1].id~=ref.entryID then report(entry,err and err.code or "INVALID_SCHEMA","resolve");return nil end
    local record=list[1]
    local identity=I.Search.RuntimeIdentity
    if identity and not identity:MatchesScope(record.scope or entry.definition.scope) then return nil end
    entry.resolved[record]=true
    return materialize(entry,record)
end
function P:Execute(item, actionID, context, dragging)
    if not self:IsCurrent(item) then return failure("STALE_RESULT", nil, item and item.providerID) end
    local entry = item and self.entries[item.providerID]
    if not entry then return failure("PROVIDER_DISABLED") end
    local record = item._providerRecord
    local definition = dragging and entry.definition.drags or entry.definition.actions
    local action = definition and definition[actionID]
    if not record or not action then return failure("ACTION_UNAVAILABLE", actionID, entry.id) end
    local publicRecord = I.RecordCodec:Public(record,entry.id)
    local resultOK, result = pcall(dragging and action.begin or action.run, publicRecord, copy(context or {}))
    if not resultOK then report(entry, "CALLBACK_ERROR", actionID); return failure("CALLBACK_ERROR", actionID, entry.id) end
    if not active(entry) then return failure("STALE_RESULT", actionID, entry.id) end
    local valid = I.Boundary:Validate(result, "action.result")
    if not valid or type(result) ~= "table" or type(result.ok) ~= "boolean" then return failure("INVALID_RESULT", actionID, entry.id) end
    if not keys(result, { ok=true, close=true, view=true, state=true, code=true, message=true }, "action.result") then return failure("INVALID_RESULT", actionID, entry.id) end
    if (result.message ~= nil and type(result.message) ~= "string") or (result.code ~= nil and type(result.code) ~= "string")
        or (result.view ~= nil and type(result.view) ~= "string") or (result.close ~= nil and type(result.close) ~= "boolean") then
        return failure("INVALID_RESULT", actionID, entry.id)
    end
    if result.ok == false then
        return nil, { code = type(result.code) == "string" and result.code or "ACTION_FAILED", message = result.message, providerID = entry.id }
    end
    if result.view then result.transition = { panelID = result.view, state = result.state or {} } end
    result.closePalette = result.close == true and not result.view
    return result
end

-- One completion per Provider per query, whether synchronous or delayed.
function P:HasPendingQuery()
    return next(self.jobs) ~= nil
end

function P:HasQuery(filter)
    if type(filter)~="table" or not filter.sourceID then return true end
    if type(filter.sourceID)~="string" then return false end
    local id=filter.sourceID:match("^(.*):records$")
    local entry=id and self.entries[id]
    return entry~=nil and active(entry) and type(entry.definition.query)=="function"
end
function P:Search(request, context, onChange)
    -- Search is also callable without QueryOrchestrator. Supersede old work at
    -- this boundary; a cancel callback may reenter and start an even newer query.
    local epoch = self:CancelQueries("query-replaced")
    if epoch ~= self.queryEpoch then return {} end
    local output, collecting = {}, true
    local function gather()
        local result = {}
        for _, list in pairs(output) do for _, item in ipairs(list) do if P:IsCurrent(item) then result[#result + 1] = item end end end
        return result
    end
    local function settle(job, reason)
        finish(job, reason)
        -- finish may reenter through a Provider cancel callback. Only the
        -- surviving query publishes its terminal state, including invalid replies.
        if epoch == P.queryEpoch and not collecting and onChange then onChange(gather(), P:HasPendingQuery()) end
    end
    local ids = {}
    for id, entry in pairs(self.entries) do
        if active(entry) and entry.definition.query and (not request.filter or not request.filter.sourceID or request.filter.sourceID == id .. ":records")
            and not (request.filter and request.filter.excludedSources and request.filter.excludedSources[id..":records"]) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if epoch ~= self.queryEpoch then break end
        local entry = self.entries[id]
        if entry and active(entry) then
        entry.dynamic, entry.resolved = {}, resolvedRecords()
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        local job = { entry = entry, epoch = epoch, revision = entry.revision, dynamicEpoch = entry.dynamicEpoch }
        self.jobs[job] = true
        local function reply(input,token)
            if job.done then return failure("STALE_REQUEST", "query", id) end
            if not active(entry) or job.epoch ~= P.queryEpoch or job.revision ~= entry.revision
                or job.dynamicEpoch ~= entry.dynamicEpoch then
                settle(job, "stale")
                return failure("STALE_REQUEST", "query", id)
            end
            local list,map
            if token==catalogToken then
                list,map={},{}
                for at,hit in ipairs(input) do local record=hit.entry.record;list[at],map[record.id]=record,record end
            else
            local valid,why=I.Boundary:Validate(input,"hits",{maxFields=P.queryLimit,maxDepth=14})
            if valid then valid,why=array(input,P.queryLimit,"hits") end
            if not valid then report(entry,why.code,"query");settle(job,"invalid");return nil,why end
            local raw={}
            for index,hit in ipairs(input) do
                if type(hit)~="table" or not keys(hit,{entry=true,confidence=true,evidence=true},"hit")
                    or type(hit.confidence)~="number" or hit.confidence<0 or hit.confidence>1
                    or hit.evidence~=nil and type(hit.evidence)~="table" then
                    settle(job,"invalid");return failure("INVALID_RESULT","hit",id)
                end
                if type(hit.entry)~="table" then settle(job,"invalid");return failure("INVALID_SCHEMA","query.entry",entry.id) end
                raw[index]=hit.entry
            end
            list,map=records(entry,raw,P.queryLimit)
            if not list then report(entry,map.code,"query");settle(job,"invalid");return nil,map end
            end
            entry.dynamic=map
            local items={}
            for index,record in ipairs(list) do
                local category=type(record.category)=="table" and record.category.id or record.category
                local identity=I.Search.RuntimeIdentity
                if (not request.filter or not request.filter.categoryID or request.filter.categoryID==category)
                    and (not identity or identity:MatchesScope(record.scope or entry.definition.scope)) then
                    local item=materialize(entry,record)
                    item.confidence,item.evidence=input[index].confidence,token==catalogToken and input[index] or copy(input[index].evidence)
                    item.categoryOrder=type(record.category)=="table" and record.category.order or 0
                    if token==catalogToken then input[index].entry=nil end
                    items[#items+1]=item
                end
            end
            output[id] = items
            settle(job, "complete")
            return true
        end
        job.reply=reply
        catalogReplies[reply]={entry=entry,reply=reply}
        local queryContext=copy(context or {})
        local resourceError
        if true then
            if not entry.resources then entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end) end
            job.resources,resourceError=I.Resources:Create(function() return not job.done and active(entry) and job.epoch==P.queryEpoch end,
                function(code,field) report(entry,code,field) end,entry.resources)
            queryContext.resources=job.resources
        end
        local ok, cancel
        if not job.resources then
            ok=false
        else
            local publicRequest=publicQueryRequest(request)
            local preferred=I.Search.Personalization and I.Search.Personalization:Preferred(request)
            if preferred and preferred.providerID==id then publicRequest.preferredEntryID=preferred.entryID end
            ok,cancel=pcall(entry.definition.query,publicRequest,reply,queryContext)
        end
        if not ok then
            if P.entries[id]==entry and epoch==P.queryEpoch and job.dynamicEpoch==entry.dynamicEpoch then
                output[id], entry.dynamic = nil, {}
            end
            report(entry, resourceError and resourceError.code or "CALLBACK_ERROR", "query"); settle(job, "error")
        elseif cancel ~= nil and type(cancel) ~= "function" then report(entry, "INVALID_CALLBACK", "query.cancel"); settle(job, "error")
        elseif job.done then
            if cancel and not pcall(cancel, job.reason) then report(entry, "CALLBACK_ERROR", "query.cancel") end
        else
            job.cancel = cancel
            if C_Timer and C_Timer.NewTimer then
                local scheduled,timer=pcall(C_Timer.NewTimer,5, function()
                if job.done then return end
                report(entry, "QUERY_TIMEOUT", "query"); settle(job, "timeout")
                end)
                if scheduled and timer then job.timer=timer
                else report(entry,"RESOURCE_UNAVAILABLE","query.timer");settle(job,"error") end
            end
        end
        end
    end
    collecting = false
    return gather(), self:HasPendingQuery()
end

-- Private transfer: only SDK-owned catalogs can reach this bridge. The public
-- reply function cannot manufacture catalogToken or reach canonical records.
local function equal(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function I.CatalogFactory:Deliver(reply,definition,hits)
    local target=catalogReplies[reply]
    if not target then return nil,{code="STALE_REQUEST"} end
    local actual=target.entry.definition
    if definition.id~=actual.id then return false end
    for _,field in ipairs({"scope","actions","drags","views"}) do
        if not equal(definition[field],actual[field]) then return false end
    end
    return reply(hits,catalogToken)
end
