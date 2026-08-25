local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local locale = GetLocale and GetLocale() or "enUS"
_G.BINDING_HEADER_LYCHEE = "Lychee"
_G.BINDING_NAME_TOGGLELYCHEE = locale == "zhCN" and "打开/关闭 Lychee" or "Open/Close Lychee"

local Palette = {}
Palette.__index = Palette

function Palette:Create()
    if self.frame then return self end
    local frame = CreateFrame("Frame", "LycheePalette", UIParent, "BackdropTemplate")
    frame:SetSize(620, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetScript("OnHide", function() if self.visible then self:Hide("external") end end)
    frame:SetScript("OnKeyDown", function(_, key) if key == "ESCAPE" then self:Hide("escape") end end)
    self.frame = frame
    self.session = 0
    self.generation = 0
    self.visible = false
    self.focus = Lychee.UI.FocusController:New()
    self.input = Lychee.UI.Input:Create(frame, self.focus)
    self.list = Lychee.UI.ResultList:Create(frame, self)
    self.viewHost = Lychee.UI.ViewHost:Create(frame)
    self.input:SetChangedCallback(function(text) self.generation = self.generation + 1; if self.onQuery then self.onQuery(text, self.generation, self.session) end end)
    self.input:SetSubmitCallback(function() self:ActivateSelected() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(_, event) if event == "PLAYER_REGEN_DISABLED" and self.visible then self:Hide("combat") end end)
    local internal = _G.LycheeInternal
    if internal then
        internal.Host = internal.Host or {}
        internal.Host.PaletteController = self
        local broker = internal.Host.SecureBroker
        if broker and broker.BindPalette then broker:BindPalette(self) end
        if not internal.Host.ClosePalette then internal.Host.ClosePalette = function(reason) return self:Hide(reason) end end
        if not internal.Host.TogglePalette then internal.Host.TogglePalette = function() return self:Toggle() end end
    end
    return self
end

function Palette:SetQueryCallback(callback) self.onQuery = callback end
function Palette:SetActivateCallback(callback) self.onActivate = callback end
function Palette:SetDragCallback(callback) self.onDrag = callback end
function Palette:SetResults(items, generation, session)
    if not self.visible then return false end
    if session and session ~= self.session then return false end
    if generation and generation ~= self.generation then return false end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.list:SetItems(items or {}, self.session, self.generation)
    if self.secureBroker and self.secureBroker.Prepare then
        for i = 1, #self.list.rows do
            local row = self.list.rows[i]
            local interaction = row.item and row.item.interaction
            local actions = interaction and interaction.actions
            if row:IsShown() and actions then
                for j = 1, math.min(#actions, 4) do
                    local action = actions[j]
                    if action.kind == "secure-spell" then
                        local button = self.secureBroker:Prepare(action, { row = row, session = self.session, generation = self.generation })
                        if button then
                            button:ClearAllPoints()
                            button:SetPoint("CENTER", row.actions[j], "CENTER")
                        end
                    end
                end
            end
        end
    end
    return true
end
function Palette:Show()
    self:Create()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    self.session = self.session + 1
    self.generation = self.generation + 1
    self.visible = true
    self.frame:Show()
    self.input:Show(); self.input:Focus()
    return true
end
function Palette:Hide(reason)
    if not self.frame or not self.visible then return true end
    self.visible = false
    self.session = self.session + 1
    self.generation = self.generation + 1
    self.list:Clear()
    if self.viewHost then self.viewHost:Unmount(reason or "hide") end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.focus:Restore()
    self.input:ClearFocus(); self.input:Hide()
    self.frame:Hide()
    return true
end
function Palette:Toggle()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self.visible then return self:Hide("toggle") end
    return self:Show()
end
function Palette:ActivateRow(row)
    if not row or row.item == nil then return false, "ACTION_UNAVAILABLE" end
    return self:ActivateRowAction(row, row.item.interaction and row.item.interaction.primaryActionID or "default")
end
function Palette:ActivateSelected() return self.list:ActivateSelected() end
function Palette:ActivateRowAction(row, actionID)
    if not self.visible then return false, "INVALID_STATE" end
    local item = row and row.item
    if not item then return false, "ACTION_UNAVAILABLE" end
    local interaction = item.interaction
    local action
    if interaction and interaction.actions then for i = 1, #interaction.actions do if interaction.actions[i].id == actionID then action = interaction.actions[i]; break end end end
    if action and action.kind == "secure-spell" then
        if actionID == (interaction.primaryActionID or "") then return false, "ACTION_REQUIRES_HARDWARE_CLICK" end
        return self.secureBroker and self.secureBroker:ShowFor(row, action, self.session, self.generation) or false
    end
    if self.onActivate then return self.onActivate(item, actionID, self.session, self.generation) end
    return false, "ACTION_UNAVAILABLE"
end
function Palette:BeginRowDrag(row)
    if not self.visible or not row or not row.item then return false, "STALE_GENERATION" end
    if self.onDrag then return self.onDrag(row.item, self.session, self.generation) end
    local drag = row.item.interaction and row.item.interaction.drag
    if type(drag) ~= "table" or drag.type ~= "spell" or type(drag.spellID) ~= "number" then return false, "DRAG_UNSUPPORTED" end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(drag.spellID) then return false, "ACTION_UNAVAILABLE" end
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(drag.spellID)
        return true
    end
    if PickupSpell then PickupSpell(drag.spellID); return true end
    return false, "DRAG_UNSUPPORTED"
end
function Palette:OpenView(factory, context, state) return self.viewHost:Mount(factory, context or {}, state) end
function Palette:CloseView(reason) return self.viewHost:Unmount(reason or "close") end

function Lychee_Toggle()
    if InCombatLockdown and InCombatLockdown() then return end
    local internal = _G.LycheeInternal
    local controller = internal and internal.Host and internal.Host.PaletteController
    if not controller then controller = Palette:Create() end
    controller:Toggle()
end

Lychee.UI.Palette = Lychee.UI.Palette or {}
if not (_G.LycheeInternal and _G.LycheeInternal.Host and _G.LycheeInternal.Host.PaletteController) then Palette:Create() end
