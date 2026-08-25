local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Broker = {}
Broker.__index = Broker

function Broker:Create(parent)
    local self = setmetatable({ parent = parent or UIParent, buttons = {}, active = {}, dirty = false }, Broker)
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:SetScript("OnEvent", function() self:Flush() end)
    if Lychee.UI and Lychee.UI.PaletteController then Lychee.UI.PaletteController.secureBroker = self end
    local internal = _G.LycheeInternal
    if internal then
        internal.Host = internal.Host or {}
        if not internal.Host.FlushSecure then internal.Host.FlushSecure = function() return self:Flush() end end
    end
    return self
end
function Broker:_Acquire()
    for i = 1, #self.buttons do if not self.buttons[i].busy then self.buttons[i].busy = true; return self.buttons[i] end end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local button = CreateFrame("Button", "LycheeSecureActionButton" .. tostring(#self.buttons + 1), self.parent, "SecureActionButtonTemplate")
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(24, 24)
    button:Hide()
    button.busy = true
    self.buttons[#self.buttons + 1] = button
    return button
end
function Broker:Prepare(action, token)
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
    button:Show()
    self.active[#self.active + 1] = button
    return button
end
function Broker:Release(button)
    if not button then return end
    if not (InCombatLockdown and InCombatLockdown()) then button:Hide(); button:SetAttribute("type", nil); button:SetAttribute("spell", nil) end
    button.busy, button.token, button.action = false, nil, nil
end
function Broker:ShowFor(row, action, session, generation)
    local button, err = self:Prepare(action, { row = row, session = session, generation = generation })
    if not button then return false, err end
    button:ClearAllPoints(); button:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    return true
end
function Broker:Flush()
    if not self.dirty or (InCombatLockdown and InCombatLockdown()) then return end
    self.dirty = false
end
function Broker:Invalidate() self.dirty = true end
function Broker:ReleaseAll()
    for i = 1, #self.buttons do self:Release(self.buttons[i]) end
    self.active = {}
end
function Broker:Destroy()
    self:ReleaseAll()
end
Lychee.Secure.SecureActionBroker = Broker
if Lychee.UI and Lychee.UI.PaletteController and not Lychee.Secure.BrokerInstance then
    Lychee.Secure.BrokerInstance = Broker:Create(Lychee.UI.PaletteController.frame)
end
