local addonName = ...
local I = _G.LycheeInternal or {}
_G.LycheeInternal = I
I.VERSION = I.VERSION or { api = 1, revision = 1 }
I.Modules = I.Modules or {}
LycheeDB = LycheeDB or {}

local function onLogin()
    if type(GetBindingKey)=="function" and type(GetBindingAction)=="function" and type(SetBinding)=="function" and type(SaveBindings)=="function" and type(GetCurrentBindingSet)=="function" and not LycheeDB.defaultBindingAttempted and not (InCombatLockdown and InCombatLockdown()) then
        LycheeDB.defaultBindingAttempted = true
        if not GetBindingKey("TOGGLELYCHEE") and not GetBindingAction("ALT-SPACE") then
            SetBinding("ALT-SPACE", "TOGGLELYCHEE")
            SaveBindings(GetCurrentBindingSet())
        end
    end
    if I.Builtin and I.Builtin.Init then I.Builtin:Init() end
    if I.Registry then I.Registry:SetReady(true) end
    local palette = _G.Lychee and _G.Lychee.UI and _G.Lychee.UI.PaletteController
    if palette and I.Search and I.Search.Query and not I._paletteWired then
        I._paletteWired = true
        palette:SetQueryCallback(function(raw, generation, session)
            if InCombatLockdown and InCombatLockdown() then return end
            local snapshot = I.Context and I.Context:Snapshot() or {}
            local _, results = I.Search.Query:Query(raw, snapshot, generation)
            palette:SetResults(results, generation, session)
        end)
        palette:SetActivateCallback(function(item, actionID)
            local command = item and item.command
            if not command or type(command.itemIntent) ~= "function" then return false, "ACTION_UNAVAILABLE" end
            local intent = command.itemIntent(item, actionID, I.Context and I.Context:Snapshot() or {})
            return I.Router and I.Router:Execute(intent, I.Context and I.Context:Snapshot() or {}) or false
        end)
    end
end

local frame = CreateFrame and CreateFrame("Frame")
if frame then
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then onLogin()
        elseif event == "PLAYER_REGEN_DISABLED" and _G.Lychee and _G.Lychee.UI and _G.Lychee.UI.PaletteController then _G.Lychee.UI.PaletteController:Hide("combat")
        elseif event == "PLAYER_REGEN_ENABLED" and _G.Lychee and _G.Lychee.Secure and _G.Lychee.Secure.SecureActionBroker then _G.Lychee.Secure.SecureActionBroker:Flush() end
    end)
end

I.OnLogin = onLogin
