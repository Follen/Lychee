local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ViewHost = {}
ViewHost.__index = ViewHost

local bindings=setmetatable({},{__mode="k"})
local function ownerPalette(context)
    local host=bindings[context]
    if not host or not host.active or not host.panel or host.panel.context~=context then return end
    local root=_G.LycheeInternal
    local palette=root and root.Host and root.Host.PaletteController
    if palette and palette.viewHost==host then return palette,host.panel.instance end
end
local function resize(context,height)
    local palette,instance=ownerPalette(context);return palette and palette:ResizeView(instance,height) or false
end
local function footer(context,value)
    local palette,instance=ownerPalette(context);return palette and palette:SetViewFooter(instance,value) or false
end
local function clearFocus(context)
    local palette=ownerPalette(context)
    if palette and palette.input then palette.input:ClearFocus();return true end
    return false
end
local function close(context)
    local palette=ownerPalette(context);return palette and palette:CloseView("provider-back") or false
end
local function invocationOwner(context)
    local host=bindings[context]
    if not host or not host.active or not host.panel or host.panel.context~=context then return nil,{code="VIEW_CLOSED"} end
    local I=_G.LycheeInternal
    local entry=I.Providers.entries[host.panel.owner]
    if not entry or entry.instanceToken~=host.providerInstance or not I.Registry:IsEnabled(entry.id) then return nil,{code="STALE_HANDLE"} end
    return entry,host
end
local function lease(host,cleanup)
    host.invocationSequence=(host.invocationSequence or 0)+1
    return host.resources:Own("invocation:"..host.invocationSequence,cleanup)
end
local function prepareInvocation(context,actionID,target,args,reply)
    if reply~=nil and type(reply)~="function" then return nil,{code="INVALID_CALLBACK"} end
    local entry,host=invocationOwner(context);if not entry then return nil,host end
    local I=_G.LycheeInternal
    local holder={context=context,reply=reply}
    local resource,err=lease(host,function()
        holder.context,holder.reply=nil,nil
        if holder.operation then holder.operation:Cancel();holder.operation=nil end
        if holder.prepared then I.Invocations:Release(holder.prepared);holder.prepared=nil end
    end)
    if not resource then return nil,err end
    local token,problem,operation=I.Invocations:Prepare(entry.id,actionID,target,args,{},function(prepared,invalid)
        holder.operation=nil
        if not holder.context then if prepared then I.Invocations:Release(prepared) end;return end
        holder.prepared=prepared
        local callback=holder.reply
        if prepared then
            local panel=host.panel
            if not panel.prepared then panel.prepared={} end
            panel.prepared[prepared]=resource
        else resource:Cancel() end
        if callback then callback(prepared,invalid) end
    end)
    if operation and operation:GetState().status=="pending" then holder.operation=operation end
    if not operation then resource:Cancel() end
    return token,problem,operation
end
local function invokeInvocation(context,prepared,reply)
    if reply~=nil and type(reply)~="function" then return nil,{code="INVALID_CALLBACK"} end
    local entry,host=invocationOwner(context);if not entry then return nil,host end
    local I=_G.LycheeInternal
    local ref,err=I.Invocations:ToInvocation(prepared)
    if not ref or ref.providerID~=entry.id then return nil,err or {code="STALE_PREPARED"} end
    local holder={reply=reply,context=context}
    local listener,problem=lease(host,function() holder.reply,holder.context=nil,nil end)
    if not listener then return nil,problem end
    local op,why=I.Invocations:Invoke(prepared,{},function(result)
        local callback=holder.reply
        listener:Cancel()
        if result.status=="succeeded" and I.UserPreferences then I.UserPreferences:TouchInvocation(result.invocation) end
        if callback then callback(result) end
    end)
    local grant=host.panel and host.panel.prepared and host.panel.prepared[prepared]
    if grant then host.panel.prepared[prepared]=nil;grant:Cancel() end
    if not op then listener:Cancel() end
    return op,why
end
local function beginEdit(context,actionID,target,options)
    local entry,host=invocationOwner(context);if not entry then return nil,host end
    local I=_G.LycheeInternal
    local checked,why=I.Boundary:Copy(options or {},"edit",{maxFields=8,maxDepth=3,callbacks={onState=true}})
    if why or type(checked)~="table" then return nil,why or {code="INVALID_SCHEMA"} end
    local holder={callback=checked.onState}
    local resource,err=lease(host,function()
        holder.callback=nil
        if holder.edit then holder.edit:Cancel("view-closed");holder.edit=nil end
    end)
    if not resource then return nil,err end
    checked.onState=function(state)
        local callback=holder.callback
        if not state.pending and state.status~="editing" then resource:Cancel() end
        if callback then callback(state) end
    end
    local edit,problem=I.Invocations:BeginEdit(entry.id,actionID,target,checked,{})
    holder.edit=edit
    if not edit then resource:Cancel() end
    return edit,problem
end
local function observe(context,target,publish)
    local entry,host=invocationOwner(context);if not entry then return nil,host end
    local I=_G.LycheeInternal
    if type(publish)~="function" or type(entry.definition.observe)~="function" then return nil,{code="OBSERVE_UNAVAILABLE"} end
    local ref,err=I.Invocations:NormalizeStoredRef({kind="target",product=I.Search.RuntimeIdentity:Current().product,providerID=entry.id,target=target})
    if not ref then return nil,err end
    local holder={context=context,publish=publish}
    local scope;scope,err=I.Resources:Create(function() return holder.context~=nil end,nil,host.resources)
    if not scope then return nil,err end
    local token={Cancel=function() return I.Resources:Close(scope,"observation-closed") end}
    local own;own,err=scope:Own("observe",function()
        holder.context,holder.publish=nil,nil
        local cancel=holder.cancel;holder.cancel=nil
        if type(cancel)=="function" then pcall(cancel,"observation-closed")
        elseif type(cancel)=="table" and type(cancel.Cancel)=="function" then pcall(cancel.Cancel,cancel) end
    end)
    if not own then token:Cancel();return nil,err end
    local ok,cancel=pcall(entry.definition.observe,ref.target,{resources=scope},function(input)
        if not holder.context or not invocationOwner(holder.context) then return false end
        local state,why=I.Invocations:CopyData(input,"observation")
        if why or type(state)~="table" or type(state.values)~="table" or (type(state.stateRevision)~="number" and type(state.stateRevision)~="string") then return false end
        for key in pairs(state) do if key~="stateRevision" and key~="values" and key~="correlation" then return false end end
        if state.correlation~=nil and type(state.correlation)~="number" and type(state.correlation)~="string" then return false end
        if holder.publish and not pcall(holder.publish,state) then token:Cancel();return false end
        return true
    end)
    if not ok or cancel~=nil and type(cancel)~="function" and not (type(cancel)=="table" and type(cancel.Cancel)=="function") then token:Cancel();return nil,{code="INVALID_CALLBACK"} end
    if holder.context then holder.cancel=cancel
    elseif type(cancel)=="function" then pcall(cancel,"observation-closed")
    elseif cancel then pcall(cancel.Cancel,cancel) end
    return token
end

local function report(message)
    if geterrorhandler then return geterrorhandler()(message) end
    return message
end
local function invoke(panel, key, first, second)
    -- Lookup is part of the third-party boundary too. No per-call argument table.
    return xpcall(function()
        local instance = panel.instance
        local fn = panel.factory[key] or instance[key]
        if type(fn) ~= "function" then return end
        if key == "Unmount" or key == "Dispose" then return fn(instance, first) end
        return fn(instance, first, second)
    end, report)
end

function ViewHost:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    return setmetatable({ frame = frame, panel = nil, generation = 0, active = false }, ViewHost)
end

local function release(self, reason)
    local panel = self.panel
    self.panel, self.active, self.providerInstance = nil, false, nil
    self.generation = self.generation + 1
    local resources=self.resources;self.resources=nil
    if resources then _G.LycheeInternal.Resources:Close(resources,reason) end
    if panel then
        bindings[panel.context]=nil
        invoke(panel, "Unmount", reason)
        invoke(panel, "Dispose", reason)
    end
    self.frame:Hide()
end

local function finish(self, ok, err)
    if self.cancelReason or not ok then
        local reason = self.cancelReason or "panel-error"
        if ok then ok, err = false, "PANEL_CANCELLED" end
        self.cancelReason = nil
        release(self, reason)
    end
    self.cancelReason, self.pendingOwner, self.busy = nil, nil, false
    return ok, err
end

function ViewHost:Unmount(reason)
    reason = reason or "unmount"
    if self.busy then
        self.active = false
        self.cancelReason = self.cancelReason or reason
        return
    end
    self.busy = true
    release(self, reason)
    self.cancelReason, self.busy = nil, false
end

function ViewHost:Mount(factory, context, state)
    if self.busy then return false, "PANEL_BUSY" end
    self.busy = true
    release(self, "replace")
    if self.cancelReason then return finish(self, true) end
    if type(factory) ~= "table" then return finish(self, false, "PANEL_ERROR") end
    context = context or {}
    if context.contentFrame == nil then context.contentFrame = self.frame end
    if context.width == nil then context.width = self.frame:GetWidth() end
    if context.height == nil then context.height = self.frame:GetHeight() end
    -- Lua callbacks may ignore the second argument, so legacy create(context) factories remain valid.
    local owner = context.extensionID
    self.pendingOwner = owner
    local providers=_G.LycheeInternal and _G.LycheeInternal.Providers
    if providers and providers.CreateViewResources then
        local resources,err=providers:CreateViewResources(owner)
        if err then return finish(self,false,err.code) end
        self.resources=resources
        context.resources=resources
    end
    local ok, instance = xpcall(function()
        if type(factory.create) == "function" then return factory.create(context, state) end
    end, report)
    if not ok or (type(instance) ~= "table" and type(instance) ~= "userdata") then return finish(self, false, "PANEL_ERROR") end
    self.generation = self.generation + 1
    local provider=providers and providers.entries[owner]
    self.providerInstance=provider and provider.instanceToken
    self.panel = { factory = factory, instance = instance, context = context, owner = owner }
    if self.cancelReason then return finish(self, true) end
    self.active = true
    self.frame:Show()
    if self.cancelReason then return finish(self, true) end
    bindings[context]=self
    context.Resize,context.SetFooter,context.ClearFocus,context.Close=resize,footer,clearFocus,close
    context.Prepare,context.Invoke,context.BeginEdit,context.Observe=prepareInvocation,invokeInvocation,beginEdit,observe
    local mounted = invoke(self.panel, "Mount", context, state)
    return finish(self, mounted, not mounted and "PANEL_ERROR" or nil)
end

function ViewHost:Update(state)
    if self.busy then return false, "PANEL_BUSY" end
    if not self.active or not self.panel then return false, "INVALID_STATE" end
    local panel = self.panel
    self.busy = true
    local ok = invoke(panel, "Update", state, panel.context)
    return finish(self, ok, not ok and "PANEL_ERROR" or nil)
end

function ViewHost:IsActive() return self.active end
function ViewHost:IsOwnedBy(owner)
    return owner ~= nil and ((self.busy and self.pendingOwner == owner)
        or (self.active and self.panel ~= nil and self.panel.owner == owner))
end
function ViewHost:GetFrame() return self.frame end

Lychee.UI.ViewHost = ViewHost
