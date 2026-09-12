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
    create=true,
    onHostAttached=true, onHostDetached=true, onEnabled=true, onDisabled=true,
}

local function failure(code, field, extensionID)
    return { code=code, field=field, extensionID=extensionID, retryable=false }
end
local function copyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = copyValue(child) end
    return copy
end

local function validID(value)
    return type(value)=="string" and #value<=64 and value:match("^[a-z0-9][a-z0-9%.%-]*$")~=nil
end
local function integer(value) return type(value)=="number" and value > -math.huge and value < math.huge and value==math.floor(value) end
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
    return true
end
local function validatePanel(panel, public)
    local boundaryOK, boundaryErr=I.Boundary:Validate(panel,"panel",{callbacks=descriptorCallbacks}); if not boundaryOK then return nil,boundaryErr end
    if type(panel)~="table" or not validID(panel.id) or type(panel.create)~="function" then return nil,failure("INVALID_SCHEMA","panel") end
    if public and panel.stateSchema==nil then return nil,failure("INVALID_SCHEMA","stateSchema") end
    return true
end
function Registry:OnChange(callback)
    if type(callback)=="function" then self.listeners[#self.listeners+1]=callback; return true end
    return nil,failure("INVALID_SCHEMA","callback")
end
function Registry:RegisterReady(callback)
    if type(callback) ~= "function" then return nil, failure("INVALID_CALLBACK", "callback") end
    local listener = { callback = callback }
    local token = {}
    function token:Cancel()
        listener.callback = nil
        local index = listener.index
        if index and Registry.readyListeners[index] == listener then
            table.remove(Registry.readyListeners, index)
            for nextIndex = index, #Registry.readyListeners do Registry.readyListeners[nextIndex].index = nextIndex end
        end
        listener.index = nil
        return true
    end
    if self.ready then
        invoke(callback,{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision})
        listener.callback = nil
    else
        listener.index = #self.readyListeners + 1
        self.readyListeners[listener.index] = listener
    end
    return token
end
function Registry:SetReady(ready)
    local becameReady=not self.ready and not not ready
    self.ready=not not ready
    if not becameReady then return end
    local callbacks=self.readyListeners; self.readyListeners={}
    for i=1,#callbacks do
        local callback = callbacks[i].callback
        callbacks[i].callback, callbacks[i].index = nil, nil
        if callback then invoke(callback,{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision}) end
    end
    local pending={}
    for i=1,#self.order do local entry=self.entries[self.order[i]]; if entry and entry.state=="pending" and not entry.incompatible then pending[#pending+1]=entry end end
    table.sort(pending,function(a,b) return a.id<b.id end)
    for i=1,#pending do self:_Publish(pending[i]) end
end

function Registry:Begin(desc, options)
    local public=options and options.public==true
    local ok,why=validateDescriptor(desc,public); if not ok then return nil,why end
    desc = copyValue(desc)
    if self.drafts[desc.id] or (self.entries[desc.id] and self.entries[desc.id].state~="removed") then return nil,failure("DUPLICATE_ID","id",desc.id) end
    local registry=self
    local draft={descriptor=desc,panels={},state="draft",public=public}
    self.drafts[desc.id]=draft
    local function add(collection,value,validator,idField)
        if draft.state~="draft" then return nil,failure("REGISTRATION_CLOSED",collection,desc.id) end
        local valid,invalid=validator(value,public)
        if not valid then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,invalid end
        value = copyValue(value)
        local key=value[idField or "id"]
        for i=1,#draft[collection] do if draft[collection][i][idField or "id"]==key then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,failure("DUPLICATE_ID",collection,desc.id) end end
        draft[collection][#draft[collection]+1]=value
        return {id=key,kind=collection}
    end
    function draft:RegisterPanelFactory(value) return add("panels",value,validatePanel) end
    function draft:Abort()
        if draft.state~="draft" and draft.state~="invalid" then return nil,failure("REGISTRATION_CLOSED",nil,desc.id) end
        draft.state="removed"; registry.drafts[desc.id]=nil; return true
    end
    function draft:Commit()
        if draft.state~="draft" then return nil,failure("REGISTRATION_CLOSED",nil,desc.id) end
        if desc.apiVersion~=I.VERSION.api then draft.state="removed"; registry.drafts[desc.id]=nil; return nil,failure("UNSUPPORTED_API",nil,desc.id) end
        if #draft.panels>256 then draft.state="invalid"; registry.drafts[desc.id]=nil; return nil,failure("INVALID_SCHEMA","declarations",desc.id) end
        local disabled = I.CharacterStore:DisabledProviders()
        local userEnabled = not (type(disabled) == "table" and disabled[desc.id])
        local entry={id=desc.id,descriptor=desc,panels=draft.panels,ownerEnabled=true,userEnabled=userEnabled,state="pending",incompatible=(desc.minApiRevision or 1)>I.VERSION.revision}
        draft.state="closed"; registry.drafts[desc.id]=nil; registry.entries[entry.id]=entry; registry.order[#registry.order+1]=entry.id
        notify(entry,"pending",entry.incompatible and "INCOMPATIBLE_HOST" or nil)
        local handle=registry:_Handle(entry)
        if registry.ready and not entry.incompatible then local published,publishErr=registry:_Publish(entry); if not published then return nil,publishErr end end
        return handle
    end
    if public then
        local facade = {}
        for _, name in ipairs({ "RegisterPanelFactory", "Abort", "Commit" }) do
            local method = draft[name]
            facade[name] = function(_, ...) return method(draft, ...) end
        end
        return facade
    end
    return draft
end

function Registry:_Rollback(entry)
    self:RemovePanels(entry.id)
    self.entries[entry.id]=nil
    for i=#self.order,1,-1 do if self.order[i]==entry.id then table.remove(self.order,i) end end
    notify(entry,"removed","publication-failed")
end
function Registry:_Publish(entry)
    if entry.state~="pending" then return nil,failure("INVALID_STATE",nil,entry.id) end
    -- Pending providers may register before WoW restores SavedVariables.
    local disabled = I.CharacterStore:DisabledProviders()
    entry.userEnabled = not (type(disabled) == "table" and disabled[entry.id])
    self.panelsByExtension[entry.id]={}
    for i=1,#entry.panels do local panel=entry.panels[i]; local key=entry.id..":"..panel.id; if self.panels[key] then self:_Rollback(entry); return nil,failure("DUPLICATE_ID","panel",entry.id) end; self.panels[key]={extensionID=entry.id,descriptor=panel}; self.panelsByExtension[entry.id][panel.id]=key end
    notify(entry,"registered")
    invoke(entry.descriptor.onHostAttached,{apiVersion=I.VERSION.api,apiRevision=I.VERSION.revision})
    if entry.ownerEnabled and entry.userEnabled then notify(entry,"enabled"); invoke(entry.descriptor.onEnabled)
    else
        notify(entry,"disabled")
    end
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

function Registry:NotifyMetadata(id)
    local entry=self.entries[id]
    if not entry or entry.state=="removed" or entry.state=="retiring" then return false end
    for index=1,#self.listeners do pcall(self.listeners[index],entry,"metadata") end
    return true
end

function Registry:_ApplyEnabled(entry, reason)
    local enabled = entry.ownerEnabled and entry.userEnabled
    if (entry.state ~= "enabled" and entry.state ~= "disabled") or (entry.state == "enabled") == enabled then return true end
    if enabled then notify(entry, "enabled"); invoke(entry.descriptor.onEnabled)
    else notify(entry, "disabled", reason); invoke(entry.descriptor.onDisabled, reason) end
    return true
end

function Registry:SetUserEnabled(id, enabled)
    if InCombatLockdown and InCombatLockdown() then return nil, failure("COMBAT_LOCKED", nil, id) end
    local entry = self.entries[id]
    if not entry or entry.state == "removed" or entry.state == "retiring" then return nil, failure("INVALID_STATE", nil, id) end
    if type(enabled) ~= "boolean" then return nil, failure("INVALID_SCHEMA", "enabled", id) end
    local disabled = I.CharacterStore:DisabledProviders()
    if enabled then disabled[id] = nil else disabled[id] = true end
    entry.userEnabled = enabled
    return self:_ApplyEnabled(entry, "user")
end

function Registry:_Handle(entry)
    local registry=self
    local handle={id=entry.id}
    function handle:GetState()
        return {lifecycle=entry.state,ownerEnabled=entry.ownerEnabled,userEnabled=entry.userEnabled,hostAttached=(entry.state=="registered" or entry.state=="enabled" or entry.state=="disabled"),effectiveEnabled=entry.state=="enabled",errorCode=entry.incompatible and "INCOMPATIBLE_HOST" or nil}
    end

    function handle:SetEnabled(enabled)
        if entry.state=="removed" or entry.state=="retiring" then return nil,failure("INVALID_STATE",nil,entry.id) end
        entry.ownerEnabled=not not enabled
        return registry:_ApplyEnabled(entry, "owner")
    end
    function handle:Unregister()
        if entry.state=="removed" then return true end
        if entry.state=="retiring" then return true end
        local wasEnabled=entry.state=="enabled"
        local wasAttached=(entry.state=="registered" or entry.state=="enabled" or entry.state=="disabled")
        notify(entry,"retiring","unregister")
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
