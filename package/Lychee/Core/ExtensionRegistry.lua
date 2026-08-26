local I = _G.LycheeInternal
local Registry = {
    entries = {}, drafts = {}, order = {}, ready = false,
    listeners = {}, readyListeners = {}, panels = {}, panelsByExtension = {},
}
I.Registry = Registry

function Registry:ValidateBoundary(value, field)
    return I.Boundary:Validate(value, field)
end
function Registry:ValidateSchema(value, schema, field)
    return I.Boundary:ValidateSchema(value, schema, field)
end

local descriptorCallbacks = {
    availability=true, resolve=true, resolver=true, itemIntent=true, intentFactory=true,
    query=true, handle=true, execute=true, create=true,
    onHostAttached=true, onHostDetached=true, onEnabled=true, onDisabled=true,
    snapshot=true,
}

local function failure(code, field, extensionID)
    return { code=code, field=field, extensionID=extensionID, retryable=false }
end
local function validID(value)
    return type(value)=="string" and #value<=64 and value:match("^[a-z0-9][a-z0-9%.%-]*$")~=nil
end
local function integer(value) return type(value)=="number" and value==math.floor(value) end
local function validTitle(value)
    return (type(value)=="string" and value~="") or
        (type(value)=="table" and type(value.default)=="string" and value.default~="")
end
local function invoke(callback, ...)
    if type(callback)~="function" then return true end
    local args={...}
    return xpcall(function() return callback(unpack(args)) end, function() return "CALLBACK_ERROR" end)
end
local function notify(entry, state, reason)
    entry.state=state
    for i=1,#Registry.listeners do pcall(Registry.listeners[i],entry,state,reason) end
end

local function validateDescriptor(desc, public)
    if type(desc)~="table" then return nil,failure("INVALID_SCHEMA","descriptor") end
    local ok,why=I.Boundary:Validate(desc,"descriptor",{callbacks=descriptorCallbacks})
    if not ok then return nil,why end
    if not validID(desc.id) or not integer(desc.apiVersion) or not integer(desc.minApiRevision or 1) or not validTitle(desc.title) then
        return nil,failure("INVALID_SCHEMA","descriptor",desc.id)
    end
    if public and (type(desc.version)~="string" or desc.version=="") then return nil,failure("INVALID_SCHEMA","version",desc.id) end
    if desc.invalidationKeys~=nil then
        if type(desc.invalidationKeys)~="table" then return nil,failure("INVALID_SCHEMA","invalidationKeys",desc.id) end
        local seen={}
        for i=1,#desc.invalidationKeys do
            local key=desc.invalidationKeys[i]
            if type(key)~="string" or key=="" or seen[key] then return nil,failure("INVALID_SCHEMA","invalidationKeys",desc.id) end
            seen[key]=true
        end
    end
    return true
end
local function validateCommand(command)
    local boundaryOK, boundaryErr=I.Boundary:Validate(command,"command",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(command)~="table" or not validID(command.id) or not validTitle(command.title) then return nil,failure("INVALID_SCHEMA","command") end
    if command.presentation~="row" and command.presentation~="dynamic-list" and command.presentation~="custom-panel" then return nil,failure("INVALID_SCHEMA","presentation") end
    if command.presentation=="dynamic-list" and type(command.resolve)~="function" then return nil,failure("INVALID_SCHEMA","resolve") end
    if command.presentation=="row" and ((command.intent~=nil)==(type(command.intentFactory)=="function")) then return nil,failure("INVALID_SCHEMA","intent") end
    if command.presentation=="custom-panel" and not validID(command.panel) then return nil,failure("INVALID_SCHEMA","panel") end
    if command.match~=nil and (type(command.match)~="table" or (command.match.type~="ambient" and command.match.type~="explicit")) then return nil,failure("INVALID_SCHEMA","match") end
    return true
end
local function validateProvider(provider, public)
    local boundaryOK, boundaryErr=I.Boundary:Validate(provider,"provider",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(provider)~="table" or not validID(provider.id) or type(provider.type)~="string" or provider.type=="" or not integer(provider.version or 1) or type(provider.query)~="function" then
        return nil,failure("INVALID_SCHEMA","provider")
    end
    if public and (provider.requestSchema==nil or provider.resultSchema==nil) then return nil,failure("INVALID_SCHEMA","providerSchema") end
    return true
end
local function validateHandler(handler, public)
    local boundaryOK, boundaryErr=I.Boundary:Validate(handler,"handler",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(handler)~="table" or type(handler.type)~="string" or handler.type=="" or not integer(handler.version or 1) or (type(handler.handle)~="function" and type(handler.execute)~="function") then
        return nil,failure("INVALID_SCHEMA","handler")
    end
    if public and handler.schema==nil then return nil,failure("INVALID_SCHEMA","handlerSchema") end
    return true
end
local function validatePanel(panel, public)
    local boundaryOK, boundaryErr=I.Boundary:Validate(panel,"panel",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(panel)~="table" or not validID(panel.id) or type(panel.create)~="function" then return nil,failure("INVALID_SCHEMA","panel") end
    if public and panel.stateSchema==nil then return nil,failure("INVALID_SCHEMA","stateSchema") end
    return true
end
local function validateSearchSource(source, public)
    local boundaryOK, boundaryErr=I.Boundary:Validate(source,"searchSource",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(source)~="table" or not validID(source.id) or not integer(source.version) or source.version < 1
        or type(source.priority)~="number" or type(source.scope)~="table"
        or not integer(source.revision) or source.revision < 0
        or (type(source.snapshot)~="function" and type(source.records)~="table") then
        return nil,failure("INVALID_SCHEMA","searchSource")
    end
    return true
end

local function validateSearchRecords(records, field)
    if type(records) ~= "table" then return nil, failure("INVALID_SCHEMA", field) end
    if #records > 256 then return nil, failure("RESULT_LIMIT", field) end
    for index = 1, #records do
        local ok, why = I.Boundary:ValidateSearchRecord(records[index], field .. "[" .. index .. "]")
        if not ok then return nil, why end
    end
    return true
end

local function validateCategoryOwnership(record, extensionID, field)
    local category = record and record.category
    local id = type(category) == "table" and category.id or category
    if type(id) ~= "string" or id == "" then return true end
    local core = { spells=true, achievements=true, quests=true, dungeons=true, extensions=true }
    if core[id] or extensionID:sub(1, 7) == "builtin." then return true end
    if id:sub(1, #extensionID + 1) ~= extensionID .. ":" then
        return nil, failure("INVALID_SCHEMA", field .. ".category", extensionID)
    end
    return true
end

function Registry:OnChange(callback)
    if type(callback)=="function" then self.listeners[#self.listeners+1]=callback; return true end
    return nil,failure("INVALID_SCHEMA","callback")
end
function Registry:RegisterReady(callback)
    if self.ready then invoke(callback,{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision}); return true end
    self.readyListeners[#self.readyListeners+1]=callback
    return true
end
function Registry:SetReady(ready)
    local becameReady=not self.ready and not not ready
    self.ready=not not ready
    if not becameReady then return end
    local callbacks=self.readyListeners; self.readyListeners={}
    for i=1,#callbacks do invoke(callbacks[i],{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision}) end
    local pending={}
    for i=1,#self.order do local entry=self.entries[self.order[i]]; if entry and entry.state=="pending" and not entry.incompatible then pending[#pending+1]=entry end end
    table.sort(pending,function(a,b) return a.id<b.id end)
    for i=1,#pending do self:_Publish(pending[i]) end
end

function Registry:Begin(desc, options)
    local public=options and options.public==true
    local ok,why=validateDescriptor(desc,public); if not ok then return nil,why end
    if self.drafts[desc.id] or (self.entries[desc.id] and self.entries[desc.id].state~="removed") then return nil,failure("DUPLICATE_ID","id",desc.id) end
    local registry=self
    local draft={descriptor=desc,commands={},providers={},handlers={},panels={},sources={},state="draft",public=public}
    self.drafts[desc.id]=draft
    local function add(collection,value,validator,idField)
        if draft.state~="draft" then return nil,failure("REGISTRATION_CLOSED",collection,desc.id) end
        local valid,invalid=validator(value,public)
        if not valid then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,invalid end
        local key=value[idField or "id"]
        for i=1,#draft[collection] do if draft[collection][i][idField or "id"]==key then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,failure("DUPLICATE_ID",collection,desc.id) end end
        draft[collection][#draft[collection]+1]=value
        return {id=key,kind=collection}
    end
    function draft:RegisterCommand(value) return add("commands",value,validateCommand) end
    function draft:RegisterCapabilityProvider(value) return add("providers",value,validateProvider) end
    function draft:RegisterIntentHandler(value)
        if type(value)=="table" and type(value.handle)~="function" and type(value.execute)=="function" then value.handle=value.execute end
        return add("handlers",value,validateHandler,"type")
    end
    function draft:RegisterPanelFactory(value) return add("panels",value,validatePanel) end
    function draft:RegisterSearchSource(value) return add("sources",value,validateSearchSource) end
    function draft:Abort()
        if draft.state~="draft" and draft.state~="invalid" then return nil,failure("REGISTRATION_CLOSED",nil,desc.id) end
        draft.state="removed"; registry.drafts[desc.id]=nil; return true
    end
    function draft:Commit()
        if draft.state~="draft" then return nil,failure("REGISTRATION_CLOSED",nil,desc.id) end
        if desc.apiVersion~=I.VERSION.api then draft.state="removed"; registry.drafts[desc.id]=nil; return nil,failure("UNSUPPORTED_API",nil,desc.id) end
        if #draft.commands+#draft.providers+#draft.handlers+#draft.panels+#draft.sources>256 then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,failure("INVALID_SCHEMA","declarations",desc.id) end
        local panels={}; for i=1,#draft.panels do panels[draft.panels[i].id]=true end
        for i=1,#draft.commands do local c=draft.commands[i]; if c.presentation=="custom-panel" and not panels[c.panel] then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,failure("COMMAND_NOT_FOUND","panel",desc.id) end end
        local entry={id=desc.id,descriptor=desc,commands=draft.commands,providers=draft.providers,handlers=draft.handlers,panels=draft.panels,sources=draft.sources,ownerEnabled=true,state="pending",incompatible=(desc.minApiRevision or 1)>I.VERSION.revision}
        draft.state="closed"; registry.drafts[desc.id]=nil; registry.entries[entry.id]=entry; registry.order[#registry.order+1]=entry.id
        notify(entry,"pending",entry.incompatible and "INCOMPATIBLE_HOST" or nil)
        local handle=registry:_Handle(entry)
        if registry.ready and not entry.incompatible then local published,publishErr=registry:_Publish(entry); if not published then return nil,publishErr end end
        return handle
    end
    return draft
end

function Registry:_Rollback(entry)
    if I.Catalog then I.Catalog:RemoveExtension(entry.id) end
    if I.Broker then I.Broker:RemoveExtension(entry.id) end
    if I.Router then I.Router:RemoveExtension(entry.id) end
    if I.Search and I.Search.StaticIndex and entry.sources then
        for i=1,#entry.sources do I.Search.StaticIndex:UnregisterSource(entry.id..":"..entry.sources[i].id) end
    end
    self:RemovePanels(entry.id)
    self.entries[entry.id]=nil
    for i=#self.order,1,-1 do if self.order[i]==entry.id then table.remove(self.order,i) end end
    notify(entry,"removed","publication-failed")
end
function Registry:_Publish(entry)
    if entry.state~="pending" then return nil,failure("INVALID_STATE",nil,entry.id) end
    if I.Search and I.Search.StaticIndex and entry.sources then
        for i=1,#entry.sources do
            local source=entry.sources[i]
            local sourceID=entry.id..":"..source.id
            source._extensionID, source._sourceID, source._enabled = entry.id, sourceID, entry.ownerEnabled
            local registered, sourceGeneration = I.Search.StaticIndex:RegisterSource({id=sourceID,version=source.version or 1,priority=source.priority or 0,scope=source.scope,revision=source.revision,_enabled=source._enabled,_extensionID=entry.id})
            if not registered then self:_Rollback(entry); return nil,failure("INVALID_SCHEMA","searchSource",entry.id) end
            local records=source.records
            if type(source.snapshot)=="function" then
                local snapshotOK,snapshot=xpcall(function() return source.snapshot({ locale=I.Search.RuntimeIdentity and I.Search.RuntimeIdentity.locale, signature=I.Search.RuntimeIdentity and I.Search.RuntimeIdentity.signature }) end,function() return nil end)
                if not snapshotOK or type(snapshot)~="table" then self:_Rollback(entry); return nil,failure("CALLBACK_ERROR","searchSource",entry.id) end
                records=snapshot
            end
            local recordsOK, recordsErr = validateSearchRecords(records, "searchSource." .. source.id .. ".records")
            if not recordsOK then self:_Rollback(entry); return nil, recordsErr end
            for recordIndex = 1, #records do
                local categoryOK, categoryErr = validateCategoryOwnership(records[recordIndex], entry.id, "searchSource." .. source.id .. ".records[" .. recordIndex .. "]")
                if not categoryOK then self:_Rollback(entry); return nil, categoryErr end
                records[recordIndex]._extensionID = entry.id
            end
            local committed,commitErr=I.Search.StaticIndex:CommitSnapshot(sourceID,records,source.revision,sourceGeneration)
            if not committed then self:_Rollback(entry); return nil,failure(commitErr or "INVALID_SCHEMA","searchSource",entry.id) end
        end
    end
    if I.Catalog then for i=1,#entry.commands do local ok=I.Catalog:Add(entry.id,entry.commands[i]); if not ok then self:_Rollback(entry); return nil,failure("INVALID_SCHEMA","command",entry.id) end end end
    if I.Broker then for i=1,#entry.providers do local ok=I.Broker:Add(entry.id,entry.providers[i]); if not ok then self:_Rollback(entry); return nil,failure("INVALID_SCHEMA","provider",entry.id) end end end
    if I.Router then for i=1,#entry.handlers do local ok=I.Router:Add(entry.id,entry.handlers[i]); if not ok then self:_Rollback(entry); return nil,failure("INVALID_SCHEMA","handler",entry.id) end end end
    self.panelsByExtension[entry.id]={}
    for i=1,#entry.panels do local panel=entry.panels[i]; local key=entry.id..":"..panel.id; if self.panels[key] then self:_Rollback(entry); return nil,failure("DUPLICATE_ID","panel",entry.id) end; self.panels[key]={extensionID=entry.id,descriptor=panel}; self.panelsByExtension[entry.id][panel.id]=key end
    notify(entry,"registered")
    invoke(entry.descriptor.onHostAttached,{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision})
    if entry.ownerEnabled then notify(entry,"enabled"); invoke(entry.descriptor.onEnabled) else notify(entry,"disabled") end
    return true
end

function Registry:RemovePanels(extensionID)
    local panels=self.panelsByExtension[extensionID]
    if panels then for _,key in pairs(panels) do self.panels[key]=nil end end
    self.panelsByExtension[extensionID]=nil
end
function Registry:GetPanel(extensionID,panelID)
    local record=self.panels[extensionID..":"..panelID]
    if not record then return nil end
    local entry=self.entries[extensionID]
    if not entry or entry.state~="enabled" then return nil end
    return record.descriptor
end
function Registry:IsEnabled(extensionID) local entry=self.entries[extensionID]; return entry~=nil and entry.state=="enabled" end

function Registry:_Handle(entry)
    local registry=self
    local handle={id=entry.id,_entry=entry}
    function handle:GetState()
        return {lifecycle=entry.state,ownerEnabled=entry.ownerEnabled,userEnabled=true,hostAttached=(entry.state=="registered" or entry.state=="enabled" or entry.state=="disabled"),effectiveEnabled=entry.state=="enabled",errorCode=entry.incompatible and "INCOMPATIBLE_HOST" or nil}
    end
    function handle:QueryCapability(request,context)
        if entry.state~="enabled" then return nil,failure("EXTENSION_DISABLED",nil,entry.id) end
        local ok,why=I.Boundary:Validate(request,"request"); if not ok then return nil,why end
        if not I.Broker then return nil,failure("CAPABILITY_NOT_FOUND",nil,entry.id) end
        return I.Broker:Query(request.type,request.request or request,context)
    end
    function handle:Invalidate(key)
        local allowed = false
        local keys = entry.descriptor.invalidationKeys or {}
        for index = 1, #keys do if keys[index] == key then allowed = true; break end end
        if not allowed then return nil, failure("INVALID_SCHEMA", "invalidationKey", entry.id) end
        local states = {}
        for index = 1, #entry.sources do
            local sourceID = entry.id .. ":" .. entry.sources[index].id
            local ok, generation, revision = I.Search.StaticIndex:Invalidate(sourceID, key)
            if not ok then return nil, failure(generation or "SOURCE_NOT_FOUND", "searchSource", entry.id) end
            states[#states + 1] = { sourceID = sourceID, generation = generation, revision = revision }
        end
        return true, states
    end
    function handle:GetSearchSource(sourceID)
        if type(sourceID) ~= "string" then return nil, failure("INVALID_SCHEMA", "sourceID", entry.id) end
        for index = 1, #entry.sources do
            local source = entry.sources[index]
            if source.id == sourceID then
                local fullID = entry.id .. ":" .. source.id
                local token = { id = source.id, extensionID = entry.id, sourceID = fullID }
                function token:GetState() return I.Search.StaticIndex:GetSourceState(fullID) end
                function token:BeginSnapshot() return I.Search.StaticIndex:BeginSnapshot(fullID) end
                local function beginAutoSnapshot()
                    if token._autoGeneration then return token._autoGeneration end
                    local generation, beginErr = I.Search.StaticIndex:BeginSnapshot(fullID)
                    if not generation then return nil, beginErr end
                    token._autoGeneration = generation
                    return generation
                end
                local function scheduleCommit(generation)
                    if token._autoScheduledGeneration == generation then return end
                    token._autoScheduledGeneration = generation
                    C_Timer.After(0, function()
                        if token._autoScheduledGeneration == generation then token._autoScheduledGeneration = nil end
                        if token._autoGeneration ~= generation then return end
                        token._autoGeneration = nil
                        local ok, _, revision = I.Search.StaticIndex:CommitSnapshot(fullID, nil, nil, generation)
                        if ok then source.revision = revision or source.revision end
                    end)
                end
                function token:Upsert(record, generation)
                    local ok, why = I.Boundary:ValidateSearchRecord(record, "searchSource." .. source.id)
                    if not ok then return nil, why end
                    local categoryOK, categoryErr = validateCategoryOwnership(record, entry.id, "searchSource." .. source.id)
                    if not categoryOK then return nil, categoryErr end
                    record._extensionID = entry.id
                    if generation == nil and C_Timer and type(C_Timer.After) == "function" then
                        local autoGeneration, autoErr = beginAutoSnapshot()
                        if not autoGeneration then return nil, autoErr end
                        local updated, updateErr = I.Search.StaticIndex:Upsert(fullID, record, nil, autoGeneration)
                        if updated then scheduleCommit(autoGeneration) end
                        return updated, updateErr
                    end
                    return I.Search.StaticIndex:Upsert(fullID, record, nil, generation)
                end
                function token:Remove(recordID, generation)
                    if generation == nil and C_Timer and type(C_Timer.After) == "function" then
                        local autoGeneration, autoErr = beginAutoSnapshot()
                        if not autoGeneration then return nil, autoErr end
                        local removed, removeErr = I.Search.StaticIndex:Remove(fullID, recordID, nil, autoGeneration)
                        if removed then scheduleCommit(autoGeneration) end
                        return removed, removeErr
                    end
                    return I.Search.StaticIndex:Remove(fullID, recordID, nil, generation)
                end
                function token:CommitSnapshot(records, revision, generation)
                    if generation == nil and token._autoGeneration then generation = token._autoGeneration end
                    if generation == token._autoGeneration then token._autoGeneration = nil end
                    if records ~= nil then
                        local valid, why = validateSearchRecords(records, "searchSource." .. source.id .. ".records")
                        if not valid then return nil, why end
                        for i = 1, #records do
                            local categoryOK, categoryErr = validateCategoryOwnership(records[i], entry.id, "searchSource." .. source.id .. ".records[" .. i .. "]")
                            if not categoryOK then return nil, categoryErr end
                            records[i]._extensionID = entry.id
                        end
                    end
                    local ok, a, b = I.Search.StaticIndex:CommitSnapshot(fullID, records, revision, generation)
                    if ok then source.revision = b or source.revision end
                    return ok, a, b
                end
                function token:Invalidate(key) return I.Search.StaticIndex:Invalidate(fullID, key) end
                return token
            end
        end
        return nil, failure("SOURCE_NOT_FOUND", "sourceID", entry.id)
    end
    function handle:SetEnabled(enabled)
        if entry.state=="removed" or entry.state=="retiring" then return nil,failure("INVALID_STATE",nil,entry.id) end
        entry.ownerEnabled=not not enabled
        if entry.state=="enabled" and not entry.ownerEnabled then if I.Catalog then I.Catalog:SetExtensionEnabled(entry.id,false) end; if I.Search and I.Search.StaticIndex then for i=1,#entry.sources do I.Search.StaticIndex:TouchSource(entry.id..":"..entry.sources[i].id, false) end end; notify(entry,"disabled","owner"); invoke(entry.descriptor.onDisabled,"owner")
        elseif entry.state=="disabled" and entry.ownerEnabled then if I.Catalog then I.Catalog:SetExtensionEnabled(entry.id,true) end; if I.Search and I.Search.StaticIndex then for i=1,#entry.sources do I.Search.StaticIndex:TouchSource(entry.id..":"..entry.sources[i].id, true) end end; notify(entry,"enabled"); invoke(entry.descriptor.onEnabled) end
        return true
    end
    function handle:Unregister()
        if entry.state=="removed" then return true end
        if entry.state=="retiring" then return true end
        local wasEnabled=entry.state=="enabled"
        local wasAttached=(entry.state=="registered" or entry.state=="enabled" or entry.state=="disabled")
        notify(entry,"retiring","unregister")
        if I.Catalog then I.Catalog:RemoveExtension(entry.id) end
        if I.Broker then I.Broker:RemoveExtension(entry.id) end
        if I.Router then I.Router:RemoveExtension(entry.id) end
        if I.Search and I.Search.StaticIndex then for i=1,#entry.sources do I.Search.StaticIndex:UnregisterSource(entry.id..":"..entry.sources[i].id) end end
        registry:RemovePanels(entry.id)
        if wasEnabled then invoke(entry.descriptor.onDisabled,"unregister") end
        if wasAttached then invoke(entry.descriptor.onHostDetached,"unregister") end
        registry.entries[entry.id]=nil
        for i=#registry.order,1,-1 do if registry.order[i]==entry.id then table.remove(registry.order,i) end end
        notify(entry,"removed","unregister")
        return true
    end
    return handle
end
function Registry:Get(id) local entry=self.entries[id]; return entry and self:_Handle(entry) end
