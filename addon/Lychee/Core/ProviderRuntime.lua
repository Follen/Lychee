local I = _G.LycheeInternal
local P = { entries = {}, jobs = {}, diagnostics = {}, queryEpoch = 0, instanceSequence = 0, entryLimit = 4096, queryLimit = 256 }
I.Providers = P
-- Membership follows each live resolved snapshot, not its ID: pins and recent
-- may resolve the same entry independently. UI/action references keep it alive.
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
local function publicQueryRequest(request, providerID)
    local result={}
    for key,value in pairs(request) do
        if key=="filter" and type(value)=="table" then
            local filter={}
            for field,setting in pairs(value) do
                if field~="excludedSources" and field~="policyVersion" then filter[field]=copy(setting) end
            end
            if next(filter) then result.filter=filter end
        elseif key~="_preferences" then result[key]=copy(value) end
    end
    local personal=request._preferences and request._preferences.providers[providerID]
    if personal then result.preferredEntryID=personal.preferredEntryID;result.ranking=copy(personal.ranking) end
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
    return I.RecordCodec:Receive(entry,input,limit or P.entryLimit)
end
local function catalogRecords(entry,input)
    if entry.definition.entryMode=="documents" then
        local list,map=I.RecordCodec:ReceiveDocuments(entry,input,P.entryLimit)
        if list then for _,record in ipairs(list) do record.kind="entry" end end
        return list,map
    end
    return records(entry,input)
end
local function active(entry)
    local identity = I.Search.RuntimeIdentity
    return P.entries[entry.id] == entry and I.Registry:IsEnabled(entry.id)
        and (not identity or identity:MatchesScope(entry.definition.scope))
end
local function finish(job, reason)
    if job.done then return end
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
        maxFields = P.entryLimit, maxDepth = 12,
        callbacks = { readEntry = true, query = true, resolve = true, resolveTarget=true, describe=true, observe=true, prepare=true, releaseSearch=true, run = true, begin = true, create = true, onEnable = true, onDisable = true },
    })
    if not ok then return nil, err end
    if type(definition) ~= "table" then return failure("INVALID_SCHEMA", "provider") end
    ok, err = keys(definition, { id=true, apiVersion=true, version=true, title=true, addon=true, description=true, icon=true, resource=true, targetView=true,
        entries=true, entryMode=true, readEntry=true, query=true, resolve=true, resolveTarget=true, describe=true, observe=true, prepare=true, releaseSearch=true, searchable=true, searchMode=true, searchGlobal=true, searchPrefixes=true, searchKeywords=true, actions=true, drags=true, views=true, scope=true, i18n=true, onEnable=true, onDisable=true }, "provider")
    if not ok then return nil, err end
    if not validID(definition.id) or type(definition.version) ~= "string" or definition.version == "" then return failure("INVALID_SCHEMA", "provider.id/version") end
    if not _G.Lychee:Supports(definition.apiVersion) then return failure("UNSUPPORTED_API", "apiVersion") end
    if I.Search.ProviderPolicy then
        local valid,field=I.Search.ProviderPolicy:ValidateDefinition(definition)
        if not valid then return failure("INVALID_SCHEMA",field) end
    end
    if definition.searchable~=nil then
        if type(definition.searchable)~="boolean" then return failure("INVALID_SCHEMA","searchable") end
    end
    if definition.scope ~= nil and type(definition.scope) ~= "table" then return failure("INVALID_SCHEMA", "scope") end
    ok, err = I.Boundary:ValidateScope(definition.scope or {},"scope")
    if not ok then return nil, err end
    local localizer
    if definition.i18n~=nil then
        if not I.ProviderLocales then return failure("UNSUPPORTED_API","i18n") end
        localizer,err=I.ProviderLocales:Compile(definition.i18n)
        if not localizer then return nil,err end
    end
    local inputEntries,ownedDefinition=definition.entries,{}
    for key,value in pairs(definition) do if key~="entries" and key~="i18n" then ownedDefinition[key]=copy(value) end end
    definition=ownedDefinition
    -- An omitted product scope targets retail; other clients require an explicit declaration.
    if not definition.scope or (not definition.scope.product and not definition.scope.products) then
        definition.scope=definition.scope or {};definition.scope.product="retail"
    end
    definition.entries=inputEntries
    if localizer then
        definition.title,err=localizer:Resolve(definition.title)
        if not definition.title then
            if err then return nil,err end
            return failure("INVALID_SCHEMA","provider.title")
        end
        if definition.description~=nil then
            definition.description,err=localizer:Resolve(definition.description)
            if not definition.description then return nil,err or {code="INVALID_SCHEMA",field="provider.description"} end
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
    if definition.description~=nil and (type(definition.description)~="string" or #definition.description>4096) then
        return failure("INVALID_SCHEMA","provider.description")
    end
    if definition.entryMode~=nil and definition.entryMode~="entries" and definition.entryMode~="documents" then return failure("INVALID_SCHEMA","entryMode") end
    if (definition.entryMode=="documents")~=(type(definition.readEntry)=="function") then return failure("INVALID_SCHEMA","readEntry") end
    if definition.entries == nil and type(definition.query) ~= "function" and definition.actions == nil then return failure("INVALID_SCHEMA", "entries/query") end
    if definition.entries ~= nil and type(definition.entries) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
    for _, field in ipairs({ "readEntry", "query", "resolve", "resolveTarget", "describe", "observe", "prepare", "releaseSearch", "onEnable", "onDisable" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "function" then return failure("INVALID_SCHEMA", field) end
    end
    for _, field in ipairs({ "actions", "drags", "views" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "table" then return failure("INVALID_SCHEMA", field) end
        for id, value in pairs(definition[field] or {}) do
            local callback = field == "actions" and "run" or field == "drags" and "begin" or "create"
            if not validID(id) or type(value) ~= "table" or type(value[callback]) ~= "function" then return failure("INVALID_SCHEMA", field) end
            local allowed = field == "views" and { create=true, stateSchema=true } or field=="actions" and {title=true,run=true,schema=true,actionVersion=true,execution=true,absolute=true,conflictKey=true,panel=true} or {title=true,[callback]=true}
            ok, err = keys(value, allowed, field .. "." .. id); if not ok then return nil, err end
            if field=="actions" and value.schema~=nil then
                local schema,problem=I.Invocations:ValidateAction(value)
                if not schema then return nil,problem end
                value.schema=schema
            end
            if field ~= "views" and (type(value.title) ~= "string" or value.title == "") then return failure("INVALID_SCHEMA", field .. ".title") end
            if field == "views" and type(value.stateSchema) ~= "table" then return failure("INVALID_SCHEMA", "views.stateSchema") end
            if field == "views" then
                ok, err = I.Boundary:Validate(value.stateSchema, "views.stateSchema")
                if not ok then return nil, err end
            end
        end
    end
    if definition.addon~=nil or I.AddonDiscovery and I.AddonDiscovery:Get(definition.id) then
        local valid,problem=I.AddonDiscovery:ValidateRegistration(definition)
        if not valid then return nil,problem end
    end
    self.instanceSequence = self.instanceSequence + 1
    local entry = { id = definition.id, instanceToken = self.instanceSequence, definition = definition, revision = 1, dynamic = {}, resolved = resolvedRecords(), readRecords=resolvedRecords(), dynamicEpoch = 0, localizer=localizer }
    local initial, map = catalogRecords(entry, inputEntries or {})
    if not initial then return nil, map end
    entry.records, entry.recordMap = initial, map
    entry.recordOrder = {}
    for index, record in ipairs(initial) do entry.recordOrder[record.id] = index end
    definition.entries = nil
    local handle, internal, enabledBeforeCommit
    local sourceID = entry.id .. ":records"
    local function canonical(record)
        return I.Search.StaticIndex:GetRecord(sourceID, record.id) or record
    end
    local function adoptRecords()
        for index, record in ipairs(entry.records) do
            local owned = canonical(record)
            entry.records[index], entry.recordMap[record.id] = owned, owned
        end
    end
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
        if I.Preparation then I.Preparation:CancelProvider(entry.id,entry,reason) end
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
        apiVersion="1.0.0",
        onHostAttached = adoptRecords, onEnabled = start, onDisabled = stop }, { public = true })
    if not draft then return nil, err end
    ok, err = draft:RegisterSearchSource({ id = "records", title = definition.title, version = 2, revision = 1,
        priority = 0, scope = definition.scope or {}, searchable=definition.searchable,
        snapshot = function() return I.Registry:_OwnRecords(entry.records, entry.id) end })
    if not ok then draft:Abort(); return nil, err end
    for id, view in pairs(definition.views or {}) do
        ok, err = draft:RegisterPanelFactory({ id = id, create = view.create, stateSchema = view.stateSchema })
        if not ok then draft:Abort(); return nil, err end
    end
    internal, err = draft:Commit()
    if not internal then return nil, err end
    self.entries[entry.id] = entry
    if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
    local source = internal:GetSearchSource("records")
    handle = { id = entry.id }
    function handle:Update(delta)
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        if not active(entry) then return failure("PROVIDER_DISABLED", nil, entry.id) end
        local valid, why = I.Boundary:Validate(delta, "update", { maxFields = P.entryLimit, maxDepth = 12 })
        if not valid then return nil, why end
        if type(delta) ~= "table" then return failure("INVALID_SCHEMA", "update") end
        for _, field in ipairs({ "replace", "upsert", "remove" }) do
            if delta[field] ~= nil and type(delta[field]) ~= "table" then return failure("INVALID_SCHEMA", "update." .. field) end
        end
        valid, why = keys(delta, { replace=true, upsert=true, remove=true }, "update"); if not valid then return nil, why end
        if delta.replace ~= nil and (delta.upsert ~= nil or delta.remove ~= nil) then return failure("INVALID_SCHEMA", "update.replace") end
        if delta.replace ~= nil then
            local nextList, nextMap = catalogRecords(entry, delta.replace)
            if not nextList then return nil, nextMap end
            entry.updating = true
            local committed, commitError, _, changed = source:CommitSnapshot(I.Registry:_OwnRecords(nextList, entry.id))
            entry.updating = nil
            if not committed then return nil, commitError end
            if not changed then return true end
            entry.records, entry.recordMap, entry.recordOrder = nextList, nextMap, {}
            for index, record in ipairs(nextList) do entry.recordOrder[record.id] = index end
            adoptRecords()
        else
            local additions, addedMap = catalogRecords(entry, delta.upsert or {})
            if not additions then return nil, addedMap end
            valid, why = array(delta.remove or {}, P.entryLimit, "update.remove"); if not valid then return nil, why end
            local removed, count = {}, #entry.records
            for _, id in ipairs(delta.remove or {}) do
                if type(id) ~= "string" or id == "" or addedMap[id] or removed[id] then return failure("INVALID_SCHEMA", "update.remove") end
                removed[id] = true
                if entry.recordMap[id] then count = count - 1 end
            end
            for _, record in ipairs(additions) do if not entry.recordMap[record.id] then count = count + 1 end end
            if count > P.entryLimit then return failure("RESULT_LIMIT", "update") end
            entry.updating = true
            local committed, commitError, _, changed = source:ApplyDelta(I.Registry:_OwnRecords(additions, entry.id), delta.remove or {})
            entry.updating = nil
            if not committed then return nil, commitError end
            if not changed then return true end
            for id in pairs(removed) do
                local index = entry.recordOrder[id]
                if index then
                    local last = entry.records[#entry.records]
                    entry.records[index], entry.recordOrder[last.id] = last, index
                    entry.records[#entry.records] = nil
                    entry.recordOrder[id], entry.recordMap[id] = nil, nil
                end
            end
            for _, record in ipairs(additions) do
                record = canonical(record)
                local index = entry.recordOrder[record.id] or #entry.records + 1
                entry.records[index], entry.recordMap[record.id], entry.recordOrder[record.id] = record, record, index
            end
        end
        entry.revision = entry.revision + 1
        local session=I.Search.Session
        if session and session.HomeOwnerChanged then
            session:HomeOwnerChanged(entry.id,"updated")
            if session.palette and session.palette.MarkHomeDirty then session.palette:MarkHomeDirty() end
        end
        if not (C_Timer and C_Timer.NewTimer) and I.Search.Session then I.Search.Session:RefreshSource() end
        return true
    end
    function handle:Invalidate()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not active(entry) then return failure("PROVIDER_DISABLED",nil,entry.id) end
        entry.revision=entry.revision+1
        if I.Preparation then I.Preparation:CancelProvider(entry.id,entry,"invalidated") end
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
    function handle:Settings()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not entry.settings then entry.settings=I.ProviderData:Settings(entry.id,function() return P.entries[entry.id]==entry end) end
        return entry.settings
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
    function handle:SetAvailability(enabled, reason)
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        if type(enabled) ~= "boolean" then return failure("INVALID_SCHEMA", "enabled") end
        local accessible=I.Boundary.Access(reason,"reason")
        if not accessible or reason~=nil and (type(reason)~="string" or #reason>256) then return failure("INVALID_SCHEMA","reason") end
        entry.availabilitySequence=(entry.availabilitySequence or 0)+1
        local sequence,previous=entry.availabilitySequence,entry.unavailableReason
        entry.unavailableReason=not enabled and reason or nil
        local ok,why=internal:SetEnabled(enabled)
        if not ok and entry.availabilitySequence==sequence then entry.unavailableReason=previous end
        local session=I.Search.Session
        if ok and P.entries[entry.id]==entry and session and session.HomeOwnerChanged then
            session:HomeOwnerChanged(entry.id,enabled and "enabled" or "disabled")
            if session.palette and session.palette.MarkHomeDirty then session.palette:MarkHomeDirty() end
        end
        return ok,why
    end
    function handle:Unregister()
        if P.entries[entry.id] ~= entry then return true end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        local removed, removeError = internal:Unregister()
        if removed then
            P.entries[entry.id] = nil
            if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
            entry.localizer,entry.settings=nil,nil
            entry.metadataPool, entry.actionRecords, entry.actionLists = nil, nil, nil
            entry.records, entry.recordMap, entry.recordOrder, entry.dynamic, entry.resolved = {}, {}, {}, {}, {}
            definition.readEntry=nil
            definition.actions, definition.drags, definition.views, definition.query, definition.resolve = nil, nil, nil, nil, nil
            definition.onEnable, definition.onDisable = nil, nil
        end
        return removed, removeError
    end
    if I.AddonDiscovery then I.AddonDiscovery:Registered(entry.id,entry) end
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
    item.providerID, item.ref = entry.id, { providerID = entry.id, entryID = item.id }
    local record=item.searchRecord
    if record then item.ref=record.invocation or record.command or record.targetRef or item.ref end
    if item.ref.kind then item.stableID=I.Search.RuntimeIdentity:ReferenceKey(item.ref) end
    item._providerInstance, item._providerRevision = entry, entry.revision
    item._providerRecord = record and (entry.resolved[record] or entry.readRecords[record]) and record or entry.recordMap[item.id]
    item._dynamicEpoch = dynamic and entry.dynamicEpoch or nil
    return item
end
function P:IsCurrent(item)
    local entry = item and item._providerInstance
    if not entry then return true end
    local record, identity = item._providerRecord, I.Search.RuntimeIdentity
    return active(entry) and item._providerRevision == entry.revision
        and record ~= nil and (not identity or identity:MatchesScope(record.scope or entry.definition.scope))
        and (not item._dynamicEpoch or item._dynamicEpoch == entry.dynamicEpoch)
        and (item._providerRecord == entry.recordMap[item.id] or item._providerRecord == entry.dynamic[item.ref.kind and I.Search.RuntimeIdentity:ReferenceKey(item.ref) or item.id] or entry.resolved[item._providerRecord] == true or entry.readRecords[item._providerRecord] == true)
end
function P:ReadEntry(id,entryID,context)
    local entry=self.entries[id]
    if not entry or not active(entry) or not entry.definition.readEntry then return nil end
    local revision=entry.revision
    local ok,result,err=pcall(entry.definition.readEntry,entryID,{ref=context and context.ref and copy(context.ref) or {providerID=id,entryID=entryID},revision=revision,reason=context and context.reason or "query"})
    if not active(entry) or entry.revision~=revision then return failure("STALE_RESULT") end
    if not ok then report(entry,"CALLBACK_ERROR","readEntry");return failure("CALLBACK_ERROR") end
    if not result then
        if err then
            if not I.Boundary:Validate(err,"readEntry.error",{maxDepth=2,maxFields=8}) or type(err)~="table" or type(err.code)~="string" then err={code="INVALID_RESULT"} end
            report(entry,err.code,"readEntry")
        end
        return nil,err
    end
    local list,why=records(entry,{result},1)
    if not list or list[1].id~=entryID then report(entry,why and why.code or "INVALID_REFERENCE","readEntry");return failure(why and why.code or "INVALID_REFERENCE") end
    local record=list[1]
    if not I.Search.RuntimeIdentity:MatchesScope(record.scope or entry.definition.scope) then return failure("PROVIDER_UNAVAILABLE") end
    record._extensionID=entry.id
    entry.readRecords[record]=true
    return record
end
local function materialize(entry, record)
    local item = I.Search.ResultSnapshot:Materialize({ record = record, sourceID = entry.id .. ":records",
        sourceExtensionID = entry.id, sourceTitle = entry.definition.title, confidence = 0.75,
        stableID = entry.id .. ":" .. record.id })
    P:Stamp(item, true)
    item._providerRecord = record
    return item
end
local function restoreEntryAction(item,ref)
    if not item or not ref.actionID then return item end
    local interaction=item.interaction
    for _,action in ipairs(interaction and interaction.actions or {}) do
        if action.id==ref.actionID then
            -- Materialize owns the interaction table; never alter the catalog.
            interaction.primaryActionID=action.id
            item.ref={providerID=ref.providerID,entryID=ref.entryID,sourceID=ref.sourceID,actionID=action.id}
            item.stableID=I.Search.RuntimeIdentity:ReferenceKey(item.ref)
            return item
        end
    end
    return failure("ACTION_UNAVAILABLE")
end
function P:CanRemember(item)
    local entry = item and self.entries[item.providerID]
    if entry then
        local record=item._providerRecord
        return active(entry) and item._providerInstance==entry and record and record.rememberable~=false
            and (not record.invocationError or item.ref.kind=="command")
            and (item.ref.kind~=nil or entry.recordMap[item.id]~=nil or type(entry.definition.resolve)=="function")
    end
    return item and item.ref and item.sourceID and I.Search.StaticIndex.entries[item.sourceID .. ":" .. item.id] ~= nil
end
function P:Resolve(ref, context, reply)
    if type(ref)=="table" and ref.kind~=nil and ref.kind~="legacy-entry" then
        if not I.Invocations then return failure("UNSUPPORTED_API","invocation") end
        local stored,err=I.Invocations:NormalizeStoredRef(ref);if not stored then return nil,err end
        if stored.product~=I.Search.RuntimeIdentity:Current().product then return failure("INCOMPATIBLE_PRODUCT") end
        local owner=self.entries[stored.providerID]
        if not owner or not active(owner) then return failure("PROVIDER_UNAVAILABLE") end
        local action=stored.actionID and owner.definition.actions and owner.definition.actions[stored.actionID]
        if stored.kind~="target" and (not action or action.actionVersion~=stored.actionVersion) then return failure("INCOMPATIBLE_ACTION_VERSION") end
        local function resolved(value)
            if not active(owner) then return failure("STALE_RESULT") end
            local record={id=stored.entryID or stored.actionID or "target",title=stored.title or action and action.title or owner.definition.title,icon=stored.icon,kindTitle=owner.definition.title,actions={}}
            record[stored.kind=="target" and "targetRef" or stored.kind]=value
            if stored.kind=="invocation" then
                -- Rebuild presentation from the exact saved invocation, never
                -- from a same-named entry with different arguments or actions.
                local current=self:ReadEntry(owner.id,record.id,{reason="resolve",ref=value})
                if not active(owner) then return failure("STALE_RESULT") end
                local matched
                for _,candidate in ipairs(current and current.actions or {}) do
                    if candidate.kind=="invocation" and I.Invocations:Equal(candidate.invocation,value) then matched=candidate;break end
                end
                if current and (matched or current.invocation and I.Invocations:Equal(current.invocation,value)) then
                    record.title,record.icon=current.title,current.icon
                    record.subtitle,record.kindTitle,record.description=current.subtitle,current.kindTitle,current.description
                end
                record.actions[1]=matched or stored.actionID
                record.primaryActionID=matched and matched.id or stored.actionID
                if action.panel then record.actions[2]={id="panel",kind="open-panel",title=owner.definition.title,panel=action.panel,state=value.target.key} end
            elseif stored.kind=="command" and action.panel then
                record.actions[1]={id="panel",kind="open-panel",title=owner.definition.title,panel=action.panel,state=value.target and value.target.key or {}}
                local current=self:ReadEntry(owner.id,record.id,{reason="resolve",ref=value})
                if not active(owner) then return failure("STALE_RESULT") end
                if current and current.command and I.Invocations:Equal(current.command,value) then
                    record.title,record.icon=current.title,current.icon
                    record.subtitle,record.kindTitle,record.description=current.subtitle,current.kindTitle,current.description
                    record.actions={}
                    for index,declared in ipairs(current.actions or {}) do record.actions[index]=declared.kind=="provider" and declared.id or declared end
                    record.primaryActionID,record.payload=current.primaryActionID,current.payload
                end
            elseif stored.kind=="target" and owner.definition.targetView then
                record.actions[1]={id="panel",kind="open-panel",title=owner.definition.title,panel=owner.definition.targetView,state={target=value.target}}
            else return failure("TARGET_VIEW_UNAVAILABLE") end
            local list,why=records(owner,{record},1);if not list then return nil,why end
            owner.resolved[list[1]]=true
            return materialize(owner,list[1])
        end
        if stored.kind=="target" then
            if not owner.definition.targetView then return failure("TARGET_VIEW_UNAVAILABLE") end
            local item,problem
            local _,why,operation=I.Invocations:ResolveTarget(stored.providerID,stored.target,context,function(target,invalid)
                if target then stored.target=target;item,problem=resolved(stored) else problem=invalid end
                if reply then reply(item,problem) end
            end)
            return item,problem or why,operation
        end
        if stored.kind~="invocation" then return resolved(stored) end
        local item,problem
        local _,why,operation=I.Invocations:PrepareStoredRef(stored,context,function(token,invalid)
            if token then
                local normalized=I.Invocations:ToInvocation(token);I.Invocations:Release(token)
                item,problem=resolved(normalized)
            else problem=invalid end
            if reply then reply(item,problem) end
        end)
        return item,problem or why,operation
    end
    if type(ref) ~= "table" or type(ref.providerID) ~= "string" or type(ref.entryID) ~= "string" then return nil end
    local entry = self.entries[ref.providerID]
    if not entry then
        local indexed = type(ref.sourceID) == "string" and I.Search.StaticIndex.entries[ref.sourceID .. ":" .. ref.entryID]
        local source = indexed and indexed.source
        if not source or source.extensionID ~= ref.providerID or not I.Registry:IsEnabled(ref.providerID) or not source.enabled then return nil end
        local item = I.Search.ResultSnapshot:Materialize({ record = indexed.record, sourceID = source.id, sourceExtensionID = ref.providerID,
            sourceTitle = source.title or source.extensionTitle, sourceGeneration = source.generation, sourceRevision = source.revision, stableID = indexed.stableID })
        return restoreEntryAction(self:Stamp(item),ref)
    end
    if not active(entry) then return nil end
    local record
    if entry.definition.readEntry then record=self:ReadEntry(entry.id,ref.entryID,{reason="resolve"})
    else record=entry.recordMap[ref.entryID] end
    if not record and not entry.definition.readEntry and entry.definition.resolve then
        local ok, result = pcall(entry.definition.resolve, ref.entryID, copy(context or {}))
        if not ok then report(entry, "CALLBACK_ERROR", "resolve"); return nil end
        if not active(entry) then return nil end
        if result == nil then return nil end
        local restored, err = records(entry, { result })
        if not restored or restored[1].id ~= ref.entryID then report(entry, err and err.code or "INVALID_SCHEMA", "resolve"); return nil end
        record = restored[1]; entry.resolved[record] = true
    end
    local identity = I.Search.RuntimeIdentity
    if record and identity and not identity:MatchesScope(record.scope or entry.definition.scope) then return nil end
    return restoreEntryAction(record and materialize(entry, record),ref)
end
function P:PublicRecord(record,owner)
    local publicRecord = copy(record)
    publicRecord._extensionID = nil
    for index, declared in ipairs(publicRecord.actions or {}) do
        if declared.kind == "provider" then publicRecord.actions[index] = declared.id end
    end
    local category = publicRecord.category
    if type(category) == "table" and type(category.id) == "string" then category.id = category.id:sub(#owner + 2) end
    return publicRecord
end
function P:Execute(item, actionID, context, dragging)
    if not self:IsCurrent(item) then return failure("STALE_RESULT", nil, item and item.providerID) end
    local entry = item and self.entries[item.providerID]
    if not entry then return failure("PROVIDER_DISABLED") end
    local record = item._providerRecord
    local definition = dragging and entry.definition.drags or entry.definition.actions
    local action = definition and definition[actionID]
    if not record or not action then return failure("ACTION_UNAVAILABLE", actionID, entry.id) end
    if action.actionVersion then return failure("ACTION_REQUIRES_INVOCATION",actionID,entry.id) end
    local publicRecord=self:PublicRecord(record,entry.id)
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
    return next(self.jobs) ~= nil or I.Search.SourceAccess and I.Search.SourceAccess:IsPending() or false
end

function P:HasQueryFailure()
    return self.materializationFailed==true or self.queryFailures and next(self.queryFailures)~=nil or I.Search.SourceAccess and I.Search.SourceAccess:HasFailure() or false
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
    self.queryFailures={}
    local output, replacements, collecting = {}, {}, true
    local function gather()
        local result = {}
        for _, list in pairs(output) do for _, item in ipairs(list) do if P:IsCurrent(item) then result[#result + 1] = item end end end
        return result, replacements
    end
    local function settle(job, reason)
        if reason~="complete" and reason~="stale" then P.queryFailures[job.entry.id]=reason end
        finish(job, reason)
        -- finish may reenter through a Provider cancel callback. Only the
        -- surviving query publishes its terminal state, including invalid replies.
        if epoch == P.queryEpoch and not collecting and onChange then onChange(gather()) end
    end
    local ids = {}
    for id, entry in pairs(self.entries) do
        if active(entry) and I.Registry:IsSearchEnabled(id) and (not I.Search.SourceAccess or I.Search.SourceAccess:QueryReady(entry)) and entry.definition.query and (not request.filter or not request.filter.sourceID or request.filter.sourceID == id .. ":records")
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
        local function reply(input, replaceSource)
            if job.done then return failure("STALE_REQUEST", "query", id) end
            if not active(entry) or job.epoch ~= P.queryEpoch or job.revision ~= entry.revision
                or job.dynamicEpoch ~= entry.dynamicEpoch then
                settle(job, "stale")
                return failure("STALE_REQUEST", "query", id)
            end
            local function invalid(problem)
                report(entry,problem.code,"query");settle(job,"invalid");return nil,problem
            end
            if replaceSource~=nil and type(replaceSource)~="boolean" then return invalid({code="INVALID_SCHEMA",field="query.replaceSource"}) end
            local values,problem=I.Boundary:Copy(input,"query.results",{maxDepth=12,maxFields=P.queryLimit})
            if problem then return invalid(problem) end
            local valid,why=array(values,P.queryLimit,"query.results");if not valid then return invalid(why) end
            local entries,confidences={},{}
            for at,value in ipairs(values) do
                if type(value)=="table" and value.entry~=nil then
                    for key in pairs(value) do if key~="entry" and key~="confidence" and key~="evidence" then return invalid({code="INVALID_SCHEMA",field="query.result"}) end end
                    if value.confidence~=nil and (type(value.confidence)~="number" or value.confidence<0 or value.confidence>1) then return invalid({code="INVALID_SCHEMA",field="query.confidence"}) end
                    entries[at],confidences[at]=value.entry,value.confidence
                else entries[at]=value end
            end
            local list, map = I.RecordCodec:ReceiveQuery(entry, entries, P.queryLimit)
            if not list then report(entry, map.code, "query"); settle(job, "invalid"); return nil, map end
            entry.dynamic = map
            local items = {}
            for index = 1, #list do
                local record = list[index]
                local category = type(record.category) == "table" and record.category.id or record.category
                local identity = I.Search.RuntimeIdentity
                if (not request.filter or not request.filter.categoryID or request.filter.categoryID == category)
                    and (not identity or identity:MatchesScope(record.scope or entry.definition.scope)) then
                    local item = materialize(entry, record)
                    local match = I.Search.Normalizer:MatchRecord(request.normalized, record, entry.definition.scope)
                    if match then item.confidence, item.evidence = match.confidence, match end
                    if confidences[index]~=nil then item.confidence=confidences[index] end
                    items[#items + 1] = item
                end
            end
            output[id] = items
            replacements[id]=replaceSource==true or nil
            settle(job, "complete")
            return true
        end
        local queryContext=copy(context or {})
        queryContext.deadline=queryContext.deadline or P:QueryTime()+5
        queryContext.fail=function(problem)
            if job.done or job.epoch~=P.queryEpoch then return failure("STALE_REQUEST","query",id) end
            local valid=I.Boundary:Validate(problem,"query.failure",{maxDepth=1,maxFields=4})
            if not valid or type(problem)~="table" or type(problem.code)~="string" or #problem.code>128 then
                return failure("INVALID_SCHEMA","query.failure",id)
            end
            output[id],entry.dynamic=nil,{}
            report(entry,problem.code,"query");settle(job,problem.code);return true
        end
        local resourceError
        do
            if not entry.resources then entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end) end
            job.resources,resourceError=I.Resources:Create(function() return not job.done and active(entry) and job.epoch==P.queryEpoch end,
                function(code,field) report(entry,code,field) end,entry.resources)
            queryContext.resources=job.resources
        end
        local ok, cancel
        if P:QueryTime()>=queryContext.deadline then
            settle(job,"timeout");ok=true
        elseif not job.resources then
            ok=false
        else ok,cancel=pcall(entry.definition.query, publicQueryRequest(request, id), reply, queryContext) end
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
                local scheduled,timer=pcall(C_Timer.NewTimer,math.max(0,queryContext.deadline-P:QueryTime()), function()
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
    return gather()
end

P.CreateOperationResources=P.CreateViewResources
function P:QueryTime()
    return GetTimePreciseSec and GetTimePreciseSec() or GetTime and GetTime() or 0
end
