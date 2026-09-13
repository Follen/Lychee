local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Broker = {}
Broker.__index = Broker

function Broker:UpdateEventInterest()
    local cast = self.pendingButton and self.pendingButton.pendingCast or false
    local regen = self.dirty == true
    if self._observingCast == cast and self._observingRegen == regen then return end
    self.eventFrame:UnregisterAllEvents()
    if regen then self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") end
    if cast then
        if self.eventFrame.RegisterUnitEvent then
            self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
            self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        else
            self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
            self.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
            self.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        end
    end
    self._observingCast, self._observingRegen = cast, regen
end

function Broker:Create(parent)
    local self = setmetatable({ parent = parent or UIParent, buttons = {}, active = {}, dirty = false }, Broker)
    self.eventFrame = CreateFrame("Frame")
    self._observingCast, self._observingRegen = false, false
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
    local binding = _G.LycheeInternal.InteractionBinding
    binding:Attach(button, button)
    button:SetScript("OnMouseDown", function(current, mouseButton)
        binding:Press(current, current, mouseButton)
        local token = current.token
        if mouseButton == "RightButton" and token and token.controller and token.controller.ShowRowActions then
            token.controller:ShowRowActions(token.row)
        end
    end)
    button:SetAttribute("useOnKeyDown", false)
    button:SetScript("OnDragStart", function(current)
        if not binding:Consume(current, current, "LeftButton") then return end
        local token = current.token
        if token and token.controller then token.controller:BeginRowDrag(token.row) end
    end)
    button:SetSize(24, 24)
    button:Hide()
    -- The secure button covers the renderer's primary target.  Forward hover
    -- state to the owning pooled row so the protected layer stays visually
    -- indistinguishable from an ordinary primary action.
    button:SetScript("OnEnter", function(current)
        local token, controller = current.token, current.token and current.token.controller
        if controller and controller.DeferRowHover and controller:DeferRowHover(current) then return end
        local list = token and (token.row.ownerView or (controller and controller.list))
        if token and list and list.SetHover then list:SetHover(token.row, true) end
        if current.armedSecondary and controller and controller.list and controller.list.ShowActionTooltip then
            controller.list:ShowActionTooltip(current.action, current)
        elseif token and list and list.ShowTooltip then list:ShowTooltip(token.row, current) end
    end)
    button:SetScript("OnLeave", function(current)
        local token, controller = current.token, current.token and current.token.controller
        local list = token and (token.row.ownerView or (controller and controller.list))
        if token and list and list.SetHover then list:SetHover(token.row, false) end
        if controller and controller.list and controller.list.HideTooltip then controller.list:HideTooltip() end
    end)
    button:SetScript("PreClick", function(current)
        current.itemClicked=nil
        local valid, tokenErr = self:ValidateToken(current.token)
        if not binding:Consume(current, current, "LeftButton") then valid, tokenErr = false, "STALE_GENERATION" end
        if valid and current.itemID then current.itemClicked=true; return end
        if valid then
            current.pendingCast = true
            self.pendingButton = current
            self:UpdateEventInterest()
            self:Notify("pending", current.action)
            return
        end
        self:Notify("failed", current.action, tokenErr)
        self:Release(current)
    end)
    button:SetScript("PostClick", function(current, mouseButton)
        if mouseButton == "LeftButton" and current.itemID and current.itemClicked then
            current.itemClicked=nil
            local palette=self:EnsureBound()
            local item=current.token and current.token.item
            if palette then
                if item then palette:TouchRecent(item) end
                palette:Hide("item-click")
            end
            self:Release(current)
            return
        end
        if mouseButton ~= "LeftButton" or not current.mountID or not current.pendingCast then return end
        if InCombatLockdown and InCombatLockdown() then
            self:FinishCast("UNIT_SPELLCAST_FAILED", current.spellID, "COMBAT_LOCKED")
            return
        end
        -- Collections use their mount ID, matching Blizzard's mount journal.
        -- Keep the pending cast until the real success/failure event arrives.
        local summon = C_MountJournal and C_MountJournal.SummonByID
        local ok = type(summon) == "function" and pcall(summon, current.mountID)
        if not ok then self:FinishCast("UNIT_SPELLCAST_FAILED", current.spellID, "ACTION_UNAVAILABLE") end
    end)
    button.busy = true
    self.buttons[#self.buttons + 1] = button
    return button
end
function Broker:ValidateToken(token, preparing)
    if type(token) ~= "table" then return false, "STALE_GENERATION" end
    local controller = token.controller or self:EnsureBound()
    if not controller or not controller.ValidateRowAction then return false, "STALE_GENERATION" end
    return controller:ValidateRowAction(token.row, token.session, token.generation, token.item, token.extensionID, preparing)
end
function Broker:IsTokenCurrent(token) return self:ValidateToken(token) == true end
function Broker:Prepare(action, token)
    self:EnsureBound()
    if token and token.row then
        local current, tokenErr = self:ValidateToken(token, true)
        if not current then return nil, tokenErr end
    end
    local descriptor, err = Lychee.Secure.Descriptor.FromAction(action)
    if not descriptor then return nil, err end
    local ok, policyErr, mountID = Lychee.Secure.Policy:Check(descriptor)
    if not ok then self:Invalidate(); return nil, policyErr end
    for index = 1, #self.buttons do
        local existing = self.buttons[index]
        local bound = existing.token
        if existing.busy and not existing.pendingRelease and bound and token and bound.row == token.row
            and bound.item == token.item and bound.session == token.session and bound.generation == token.generation
            and existing.itemID == descriptor.itemID and existing.spellID == descriptor.spellID and existing.mountID == mountID then return existing end
    end
    local button = self:_Acquire()
    if not button then self:Invalidate(); return nil, "COMBAT_LOCKED" end
    if mountID then button:SetAttribute("type", nil)
    else button:SetAttribute("type", descriptor.kind == "item" and "item" or "spell") end
    button:SetAttribute("spell", descriptor.spellID)
    button:SetAttribute("item", descriptor.itemID and ("item:"..descriptor.itemID) or nil)
    button.itemID,button.itemClicked=descriptor.itemID,nil
    _G.LycheeInternal.InteractionBinding:Bind(button, token, token and token.session, token and token.generation)
    button.token = token
    button.action = action
    button.spellID = descriptor.spellID
    button.mountID = mountID
    button.pendingCast = false
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if executor then executor:ConfigureDragTarget(button, token and (token.item or token.row and token.row.item)) end
    button:Show()
    self.active[#self.active + 1] = button
    button.activeIndex = #self.active
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
    self:UpdateEventInterest()
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local item = button.token and button.token.item
        self:Notify("success", button.action)
        self:Release(button)
        local palette = self:EnsureBound()
        if palette then
            palette:Hide("spell-success")
            if item then palette:TouchRecent(item) end
        end
    else
        self:Notify("failed", button.action, reason)
    end
    return true
end
function Broker:Release(button)
    if button then
        _G.LycheeInternal.InteractionBinding:Bind(button, nil, nil, nil)
        _G.LycheeInternal.InteractionBinding:Cancel(button)
    end
    if not button or (not button.busy and not button.pendingRelease and not button.activeIndex) then return end
    if InCombatLockdown and InCombatLockdown() then
        button.pendingRelease = true
        self:Invalidate()
        return
    end
    button:Hide(); button:SetAttribute("type", nil); button:SetAttribute("spell", nil); button:SetAttribute("item", nil)
    if button.activeIndex then
        local index, last = button.activeIndex, self.active[#self.active]
        self.active[index] = last
        if last then last.activeIndex = index end
        self.active[#self.active], button.activeIndex = nil, nil
    end
    if self.pendingButton == button then self.pendingButton = nil end
    button.busy, button.pendingRelease, button.token, button.action, button.spellID, button.pendingCast = false, nil, nil, nil, nil, nil
    button.armedSecondary = nil
    button.mountID = nil
    button.itemID,button.itemClicked = nil,nil
    self:UpdateEventInterest()
end
function Broker:ShowFor(row, action, session, generation, item, extensionID)
    local button, err = self:Prepare(action, {
        controller = self:EnsureBound(), row = row, item = item or (row and row.item),
        extensionID = extensionID or (row and row.extensionID), session = session, generation = generation,
    })
    if not button then return false, err end
    for index = 1, #self.buttons do
        local previous = self.buttons[index]
        if previous ~= button and previous.token and previous.token.row == row then self:Release(previous) end
    end
    button.armedSecondary, button.action, button._target = true, action, nil
    if button:GetParent() ~= row then button:SetParent(row) end
    if row.GetFrameLevel and button.SetFrameLevel and button:GetFrameLevel() ~= row:GetFrameLevel() + 3 then button:SetFrameLevel(row:GetFrameLevel() + 3) end
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 2); button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, -2)
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
    self:UpdateEventInterest()
end
function Broker:Invalidate() self.dirty = true; self:UpdateEventInterest() end
function Broker:ReleaseAll()
    for i = 1, #self.buttons do self:Release(self.buttons[i]) end
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
