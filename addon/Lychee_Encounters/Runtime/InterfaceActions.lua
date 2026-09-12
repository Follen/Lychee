local _,I=...
local L = I.ProviderLocales:ForProvider("lychee.bosses")
I.Modules = I.Modules or {}
local A = {}
I.Modules.InterfaceActions = A

function A:IsShown(name)
    local frame = _G[name]
    return frame and frame.IsShown and frame:IsShown() or false
end

-- Only fixed, source-verified functions from package-owned definitions reach here.
-- A failed native call never becomes a successful action/closed palette.
function A:Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, ...)
    return ok and result ~= false
end

function A:ToggleOpen(fn, frameName, alternateFrame)
    if self:IsShown(frameName) or (alternateFrame and self:IsShown(alternateFrame)) then return true end
    if not self:Call(fn) then return false end
    return self:IsShown(frameName) or (alternateFrame and self:IsShown(alternateFrame)) or false
end

function A:OpenJournal(instanceID, encounterID, difficultyID, sectionID)
    if not EncounterJournal_OpenJournal then
        if not self:Call(EncounterJournal_LoadUI) then return false end
    end
    if not self:Call(EncounterJournal_OpenJournal, difficultyID, instanceID, encounterID, sectionID~=0 and sectionID or nil) then return false end
    if not self:IsShown("EncounterJournal") then return false end
    if difficultyID and (not EJ_GetDifficulty or EJ_GetDifficulty()~=difficultyID) then return false end
    if sectionID and sectionID>0 then
        local info=C_EncounterJournal and C_EncounterJournal.GetSectionInfo and C_EncounterJournal.GetSectionInfo(sectionID)
        if not info or info.filteredByDifficulty then return false end
    end
    if encounterID then
        return EncounterJournal.instanceID == instanceID and EncounterJournal.encounterID == encounterID
    end
    return true
end

function A:OpenJournalTab(tabKey)
    if not EncounterJournal or type(EJ_ContentTab_OnClick) ~= "function" then
        if not self:Call(EncounterJournal_LoadUI) then return false end
    end
    if not EncounterJournal or not self:Call(ShowUIPanel, EncounterJournal) or not self:IsShown("EncounterJournal") then return false end
    local tab = EncounterJournal[tabKey]
    if not tab or type(tab.GetID) ~= "function" then return false end
    -- The journal decides which tabs this character can use on Show. Keep the
    -- enabled-state check inside a bounded call in case the client restricts it.
    local ok, tabID = pcall(function()
        if not tab:IsShown() or not tab:IsEnabled() then return nil end
        return tab:GetID()
    end)
    if not ok or type(tabID) ~= "number" then return false end
    if not self:Call(EJ_ContentTab_OnClick, tab) then return false end
    return self:IsShown("EncounterJournal") and EncounterJournal.selectedTab == tabID
end

function A:Run(open,locale)
    local messages=locale or L
    if InCombatLockdown and InCombatLockdown() then
        return { ok=false, code="COMBAT_LOCKED", message=messages["请在脱离战斗后打开此界面。"] }
    end
    if DISALLOW_FRAME_TOGGLING or not open() then
        return { ok=false, code="UI_UNAVAILABLE", message=messages["当前无法打开此界面，请检查角色条件或稍后重试。"] }
    end
    return { ok=true, close=true }
end
