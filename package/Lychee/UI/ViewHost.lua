local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ViewHost = {}
ViewHost.__index = ViewHost

local function invoke(fn, ...)
    if type(fn) ~= "function" then return true end
    return xpcall(fn, geterrorhandler and geterrorhandler() or function(e) return e end, ...)
end

function ViewHost:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    return setmetatable({ frame = frame, panel = nil, generation = 0, active = false }, ViewHost)
end

function ViewHost:Unmount(reason)
    local panel = self.panel
    self.panel, self.active = nil, false
    self.generation = self.generation + 1
    if panel then invoke(panel.Unmount, panel.instance, reason or "unmount"); invoke(panel.Dispose, panel.instance, reason or "unmount") end
    self.frame:Hide()
end

function ViewHost:Mount(factory, context, state)
    self:Unmount("replace")
    if type(factory) ~= "table" or type(factory.create) ~= "function" then return false, "PANEL_ERROR" end
    context = context or {}
    if context.contentFrame == nil then context.contentFrame = self.frame end
    if context.width == nil then context.width = self.frame:GetWidth() end
    if context.height == nil then context.height = self.frame:GetHeight() end
    local ok, instance = invoke(factory.create, context)
    if not ok or not instance then return false, "PANEL_ERROR" end
    self.generation = self.generation + 1
    self.panel = { factory = factory, instance = instance, context = context }
    self.active = true
    self.frame:Show()
    local mounted = invoke(factory.Mount or instance.Mount, instance, context, state)
    if not mounted then self:Unmount("panel-error"); return false, "PANEL_ERROR" end
    return true
end

function ViewHost:Update(state)
    if not self.active or not self.panel then return false, "INVALID_STATE" end
    local panel = self.panel
    local ok = invoke(panel.factory.Update or panel.instance.Update, panel.instance, state, panel.context)
    if not ok then self:Unmount("panel-error"); return false, "PANEL_ERROR" end
    return true
end

function ViewHost:IsActive() return self.active end
function ViewHost:GetFrame() return self.frame end
