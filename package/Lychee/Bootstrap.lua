local addonName = ...
local I = _G.LycheeInternal or {}
_G.LycheeInternal = I
I.VERSION = I.VERSION or { api = 1, revision = 1 }
I.Modules = I.Modules or {}
LycheeDB = LycheeDB or {}
local pendingSearchSnapshot = LycheeDB.searchIndex

local function wireRegistryLifecycle()
    if I._registryLifecycleWired or not I.Registry then return end
    I._registryLifecycleWired = true
    I.Registry:OnChange(function(entry, state)
        if state ~= "disabled" and state ~= "retiring" and state ~= "removed" then return end
        if I.Search and I.Search.Session then I.Search.Session:Invalidate("extension-" .. state)
        elseif I.Search and I.Search.Query and I.Search.Query.Cancel then I.Search.Query:Cancel("extension-" .. state) end
        local palette = I.Host and I.Host.PaletteController
        if palette and palette.InvalidateExtension then palette:InvalidateExtension(entry.id, state) end
    end)
end

local function onLogin()
    if type(GetBindingKey)=="function" and type(GetBindingAction)=="function" and type(SetBinding)=="function" and type(SaveBindings)=="function" and type(GetCurrentBindingSet)=="function" and not LycheeDB.defaultBindingAttempted and not (InCombatLockdown and InCombatLockdown()) then
        LycheeDB.defaultBindingAttempted = true
        if not GetBindingKey("TOGGLELYCHEE") and not GetBindingAction("ALT-SPACE") then
            SetBinding("ALT-SPACE", "TOGGLELYCHEE")
            SaveBindings(GetCurrentBindingSet())
        end
    end
    wireRegistryLifecycle()
    if I.Builtin and I.Builtin.Init then I.Builtin:Init() end
    if not I._searchSnapshotRestored and I.Search and I.Search.StaticIndex and type(pendingSearchSnapshot) == "table" then
        I._searchSnapshotRestored = true
        I.Search.StaticIndex:RestoreSnapshot(pendingSearchSnapshot)
        pendingSearchSnapshot = nil
    end
    if I.Registry then I.Registry:SetReady(true) end
    local palette = I.Host and I.Host.PaletteController
    if palette then I.WirePalette(palette) end
end

function I.WirePalette(palette)
    if not palette or not I.Search or not I.Search.Session or not I.ResultActionExecutor or I._paletteWired then return false end
    I._paletteWired = true
    I.Search.Session:BindPalette(palette)
    I.ResultActionExecutor:BindPalette(palette)
    palette:SetQueryCallback(function(raw) return I.Search.Session:Input(raw) end)
    return true
end

local frame = CreateFrame and CreateFrame("Frame")
if frame then
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then onLogin()
        elseif event == "PLAYER_REGEN_DISABLED" and I.Host and I.Host.PaletteController then I.Host.PaletteController:Hide("combat")
        elseif event == "PLAYER_REGEN_ENABLED" then
            if I.Host and I.Host.SecureBroker then I.Host.SecureBroker:Flush() end
            onLogin()
        end
    end)
end

I.OnLogin = onLogin
