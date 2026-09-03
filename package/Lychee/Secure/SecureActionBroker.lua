local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Broker = {}
Broker.__index = Broker

function Broker:Create(parent)
    local self = setmetatable({ parent = parent or UIParent, buttons = {}, active = {}, dirty = false }, Broker)
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    if self.eventFrame.RegisterUnitEvent then
        self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    else
        self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
        self.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    end
    self.eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID, reason)
        if event == "PLAYER_REGEN_ENABLED" then
            self:Flush()
        elseif unit == nil or unit == "player" then
            self:FinishCast(event, spellID, reason)
        end
    end)
    self:EnsureBound()
    local internal = _G.LycheeInternal
    if internal then
        internal.Host = internal.Host or {}
        if not internal.Host.FlushSecure then internal.Host.FlushSecure = function() return self:Flush() end end
    end
    return self
end
function Broker:BindPalette(palette)
    if not palette then return false end
    self.palette = palette
    palette.secureBroker = self
    if palette.frame and self.parent == UIParent then self.parent = palette.frame end
    return true
end
function Broker:EnsureBound()
    if self.palette then return self.palette end
    local palette = _G.LycheeInternal and _G.LycheeInternal.Host and _G.LycheeInternal.Host.PaletteController
    if palette then self:BindPalette(palette) end
    return self.palette
end
function Broker:_Acquire()
    for i = 1, #self.buttons do if not self.buttons[i].busy then self.buttons[i].busy = true; return self.buttons[i] end end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local button = CreateFrame("Button", "LycheeSecureActionButton" .. tostring(#self.buttons + 1), self.parent, "SecureActionButtonTemplate")
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(24, 24)
    button:Hide()
    button:SetScript("PreClick", function(current)
        local valid, tokenErr = self:ValidateToken(current.token)
        if valid then
            current.pendingCast = true
            self.pendingButton = current
            self:Notify("pending", current.action)
            return
        end
        self:Notify("failed", current.action, tokenErr)
        if not (InCombatLockdown and InCombatLockdown()) then
            current:SetAttribute("type", nil)
            current:SetAttribute("spell", nil)
            current:Hide()
        else
            current.pendingRelease = true
            self.dirty = true
        end
        current.busy, current.token, current.action, current.pendingCast = false, nil, nil, nil
    end)
    button.busy = true
    self.buttons[#self.buttons + 1] = button
    return button
end
function Broker:ValidateToken(token)
    if type(token) ~= "table" then return false, "STALE_GENERATION" end
    local controller = token.controller or self:EnsureBound()
    if not controller or not controller.ValidateRowAction then return false, "STALE_GENERATION" end
    return controller:ValidateRowAction(token.row, token.session, token.generation, token.item, token.extensionID)
end
function Broker:IsTokenCurrent(token) return self:ValidateToken(token) == true end
function Broker:Prepare(action, token)
    self:EnsureBound()
    if token and token.row then
        local current, tokenErr = self:ValidateToken(token)
        if not current then return nil, tokenErr end
    end
    local descriptor, err = Lychee.Secure.Descriptor.FromAction(action)
    if not descriptor then return nil, err end
    local ok, policyErr = Lychee.Secure.Policy:Check(descriptor)
    if not ok then self.dirty = true; return nil, policyErr end
    if InCombatLockdown and InCombatLockdown() then self.dirty = true; return nil, "COMBAT_LOCKED" end
    local button = self:_Acquire()
    if not button then self.dirty = true; return nil, "COMBAT_LOCKED" end
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", descriptor.spellID)
    button.token = token
    button.action = action
    button.spellID = descriptor.spellID
    button.pendingCast = false
    button:Show()
    self.active[#self.active + 1] = button
    return button
end

function Broker:Notify(state, action, reason)
    local palette = self:EnsureBound()
    if not palette then return false end
    if state == "pending" then
        if palette.SetActionFeedback then palette:SetActionFeedback("pending", action) end
    elseif state == "success" then
        if palette.SetActionFeedback then palette:SetActionFeedback("success", action) end
    elseif palette.SetActionFeedback then
        palette:SetActionFeedback("failed", reason)
    end
    return true
end

function Broker:FinishCast(event, spellID, reason)
    local button = self.pendingButton
    if not button or not button.pendingCast then return false end
    if spellID and button.spellID and spellID ~= button.spellID then return false end
    button.pendingCast = false
    self.pendingButton = nil
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        self:Notify("success", button.action)
    else
        self:Notify("failed", button.action, reason)
    end
    self:Release(button)
    return true
end
function Broker:Release(button)
    if not button then return end
    if InCombatLockdown and InCombatLockdown() then
        button.pendingRelease = true
        self.dirty = true
        return
    end
    button:Hide(); button:SetAttribute("type", nil); button:SetAttribute("spell", nil)
    button.busy, button.pendingRelease, button.token, button.action, button.spellID, button.pendingCast = false, nil, nil, nil, nil, nil
end
function Broker:ShowFor(row, action, session, generation, item, extensionID)
    local button, err = self:Prepare(action, {
        controller = self:EnsureBound(), row = row, item = item or (row and row.item),
        extensionID = extensionID or (row and row.extensionID), session = session, generation = generation,
    })
    if not button then return false, err end
    button:ClearAllPoints(); button:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    return true
end
function Broker:InvalidateRow(row)
    if not row then return false end
    for i = 1, #self.buttons do
        local button = self.buttons[i]
        if button.token and button.token.row == row then self:Release(button) end
    end
    return true
end
function Broker:Flush()
    if self == Broker then
        local instance = _G.LycheeInternal and _G.LycheeInternal.Host and _G.LycheeInternal.Host.SecureBroker
        return instance and instance:Flush() or false
    end
    if not self.dirty or (InCombatLockdown and InCombatLockdown()) then return end
    self.dirty = false
    for i = 1, #self.buttons do
        local button = self.buttons[i]
        if button.pendingRelease then
            button.pendingRelease = nil
            self:Release(button)
        end
    end
end
function Broker:Invalidate() self.dirty = true end
function Broker:ReleaseAll()
    for i = 1, #self.buttons do self:Release(self.buttons[i]) end
    self.active = {}
end
function Broker:Destroy()
    self:ReleaseAll()
end
local internal = _G.LycheeInternal
internal.Host = internal.Host or {}
if not internal.Host.SecureBroker then
    local palette = internal.Host.PaletteController
    internal.Host.SecureBroker = Broker:Create(palette and palette.frame or UIParent)
end
