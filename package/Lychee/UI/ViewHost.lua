local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ViewHost = {}
ViewHost.__index = ViewHost

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
    self.panel, self.active = nil, false
    self.generation = self.generation + 1
    local resources=self.resources;self.resources=nil
    if resources then _G.LycheeInternal.Resources:Close(resources,reason) end
    if panel then
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
    self.panel = { factory = factory, instance = instance, context = context, owner = owner }
    if self.cancelReason then return finish(self, true) end
    self.active = true
    self.frame:Show()
    if self.cancelReason then return finish(self, true) end
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
