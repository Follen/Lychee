local I = _G.LycheeInternal
local Registry = { entries = {}, order = {}, ready = false, listeners = {} }
I.Registry = Registry

local valid = { draft=true, pending=true, registered=true, enabled=true, slow=true, disabled=true, retiring=true, removed=true }
local function transition(e, state)
    if valid[state] then e.state = state end
    for i=1,#Registry.listeners do pcall(Registry.listeners[i], e, state) end
end

function Registry:OnChange(fn) if type(fn)=="function" then self.listeners[#self.listeners+1]=fn end end
function Registry:SetReady(ready)
    self.ready = not not ready
    if self.ready then
        for i=1,#self.order do local e=self.entries[self.order[i]]; if e and e.state=="pending" and not e.incompatible then self:_publish(e) end end
    end
end
function Registry:Begin(desc)
    if type(desc)~="table" or type(desc.id)~="string" or desc.id=="" then return nil,{code="INVALID_EXTENSION"} end
    if self.entries[desc.id] and self.entries[desc.id].state~="removed" then return nil,{code="DUPLICATE_EXTENSION"} end
    local registry=self
    local d={descriptor=desc,commands={},providers={},handlers={},panels={},state="draft",registry=registry}
    function d:RegisterCommand(c) if type(c)~="table" then return nil,{code="INVALID_COMMAND"} end; d.commands[#d.commands+1]=c; return true end
    function d:RegisterCapabilityProvider(p) if type(p)~="table" then return nil,{code="INVALID_PROVIDER"} end; d.providers[#d.providers+1]=p; return true end
    function d:RegisterIntentHandler(h) if type(h)~="table" then return nil,{code="INVALID_HANDLER"} end; if type(h.handle)~="function" and type(h.execute)=="function" then h.handle=h.execute end; d.handlers[#d.handlers+1]=h; return true end
    function d:RegisterPanelFactory(p) if type(p)~="table" then return nil,{code="INVALID_PANEL"} end; d.panels[#d.panels+1]=p; return true end
    function d:Abort() d.state="removed" end
    function d:Commit()
        if d.state~="draft" then return nil,{code="ALREADY_COMMITTED"} end
        local api=desc.apiVersion or 1; local rev=desc.minApiRevision or 1
        if I.VERSION.api~=api then d.state="removed"; return nil,{code="UNSUPPORTED_API"} end
        local e={id=desc.id, descriptor=desc, commands=d.commands, providers=d.providers, handlers=d.handlers, panels=d.panels, ownerEnabled=true, state="pending", incompatible=(rev>I.VERSION.revision)}
        registry.entries[e.id]=e; registry.order[#registry.order+1]=e.id
        if registry.ready and not e.incompatible then registry:_publish(e) else transition(e,"pending") end
        return registry:_handle(e)
    end
    return d
end
function Registry:_handle(e)
    local h={id=e.id, _entry=e}
    function h:GetState() return e.state, e.incompatible and "INCOMPATIBLE_HOST" or nil end
    function h:QueryCapability(request, context)
        if not I.Broker or type(request)~="table" then return nil,{code="CAPABILITY_UNAVAILABLE"} end
        return I.Broker:Query(request.type, request.request or request, context)
    end
    function h:SetEnabled(enabled) e.ownerEnabled=not not enabled; if e.state=="enabled" or e.state=="registered" or e.state=="disabled" then transition(e,enabled and "enabled" or "disabled"); if self and I.Catalog then I.Catalog:SetExtensionEnabled(e.id,enabled) end end; return true end
    function h:Unregister() if e.state=="removed" then return true end; transition(e,"retiring"); if I.Catalog then I.Catalog:RemoveExtension(e.id) end; if I.Broker then I.Broker:RemoveExtension(e.id) end; transition(e,"removed"); return true end
    return h
end
function Registry:_publish(e)
    if I.Catalog then for i=1,#e.commands do I.Catalog:Add(e.id,e.commands[i]) end end
    if I.Broker then for i=1,#e.providers do I.Broker:Add(e.id,e.providers[i]) end end
    if I.Router then for i=1,#e.handlers do I.Router:Add(e.id,e.handlers[i]) end end
    transition(e,e.ownerEnabled and "enabled" or "disabled")
end
function Registry:Get(id) local e=self.entries[id]; return e and self:_handle(e) end
