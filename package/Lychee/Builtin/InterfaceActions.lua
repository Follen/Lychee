local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
local A = {}
I.Builtin.InterfaceActions = A

function A:IsShown(name)
    local frame = _G[name]
    return frame and frame.IsShown and frame:IsShown() or false
end

-- Only fixed, source-verified functions from built-in definitions reach here.
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

function A:OpenJournal(instanceID, encounterID)
    if not EncounterJournal_OpenJournal then
        if not self:Call(EncounterJournal_LoadUI) then return false end
    end
    if not self:Call(EncounterJournal_OpenJournal, nil, instanceID, encounterID) then return false end
    if not self:IsShown("EncounterJournal") then return false end
    if encounterID then
        return EncounterJournal.instanceID == instanceID and EncounterJournal.encounterID == encounterID
    end
    return true
end

function A:Run(open)
    if InCombatLockdown and InCombatLockdown() then
        return { ok=false, code="COMBAT_LOCKED", message="请在脱离战斗后打开此界面。" }
    end
    if DISALLOW_FRAME_TOGGLING or not open() then
        return { ok=false, code="UI_UNAVAILABLE", message="当前无法打开此界面，请检查角色条件或稍后重试。" }
    end
    return { ok=true, close=true }
end
