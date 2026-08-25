local addonName = ...
local I = _G.LycheeInternal or {}
_G.LycheeInternal = I
I.VERSION = I.VERSION or { api = 1, revision = 1 }
I.Modules = I.Modules or {}
LycheeDB = LycheeDB or {}

local function wireRegistryLifecycle()
    if I._registryLifecycleWired or not I.Registry then return end
    I._registryLifecycleWired = true
    I.Registry:OnChange(function(entry, state)
        if state ~= "disabled" and state ~= "retiring" and state ~= "removed" then return end
        if I.Search and I.Search.Query then I.Search.Query:Invalidate() end
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
    if I.Registry then I.Registry:SetReady(true) end
    local palette = I.Host and I.Host.PaletteController
    if palette then I.WirePalette(palette) end
end

function I.WirePalette(palette)
    if not palette or not I.Search or not I.Search.Query or I._paletteWired then return false end
    I._paletteWired = true
    palette:SetQueryCallback(function(raw, generation, session)
            if InCombatLockdown and InCombatLockdown() then return end
            local snapshot = I.Context and I.Context:Snapshot() or {}
            local queryGeneration, results = I.Search.Query:Query(raw, snapshot)
            if session ~= palette.session then return end
            palette.generation = queryGeneration
            palette:SetResults(results, queryGeneration, session)
    end)
    palette:SetActivateCallback(function(item, actionID)
            local command = item and item.command
            if not command or type(command.itemIntent) ~= "function" then return false, "ACTION_UNAVAILABLE" end
            local intent = command.itemIntent(item, actionID, I.Context and I.Context:Snapshot() or {})
            local result, err = I.Router and I.Router:Execute(intent, I.Context and I.Context:Snapshot() or {}) or nil, "HANDLER_UNAVAILABLE"
            if not result then return false, err end
            local transition = result.transition
            if transition then
                local extensionID = command._ext or item._ext
                local panelID = transition.panelID or transition.panelFactoryID
                local factory = extensionID and I.Router:ResolvePanel(extensionID, panelID)
                if not factory then return false, "COMMAND_NOT_FOUND" end
                local controller = I.Host and I.Host.PaletteController
                if not controller or not controller.viewHost then return false, "PANEL_ERROR" end
                local ok, mountErr = controller:OpenView(factory, { extensionID = extensionID, panelID = panelID, session = session, generation = generation }, transition.state or {})
                if not ok then return false, mountErr or "PANEL_ERROR" end
            end
            if result.closePalette then
                local controller = I.Host and I.Host.PaletteController
                if controller then controller:Hide("intent") end
            end
            return result
    end)
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
