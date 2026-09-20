local I = _G.LycheeInternal
local L = I.ProviderLocales:Module("builtin.player-spells")
local M=I.ProviderModules.PlayerSpells

local function registerEvent(frame, event)
    -- Some client branches omit individual legacy events; do not abort addon init.
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

local function scheduleRefresh(provider)
    if not provider._active then return end
    provider.dirty = true
    if provider._refreshPending or (InCombatLockdown and InCombatLockdown()) then return end
    provider._refreshPending = true
    local epoch = provider._epoch
    local function flush()
        if not provider._active or provider._epoch ~= epoch then return end
        provider._refreshPending = nil
        if InCombatLockdown and InCombatLockdown() then return end
        provider:Refresh()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, flush) else flush() end
end

local function attachEvents(provider)
    if not provider._active or provider._eventFrame or not CreateFrame then return end
    provider._cachedEventFrame = provider._cachedEventFrame or CreateFrame("Frame")
    provider._eventFrame = provider._cachedEventFrame
    registerEvent(provider._eventFrame, "SPELLS_CHANGED")
    registerEvent(provider._eventFrame, "LEARNED_SPELL_IN_SKILL_LINE")
    registerEvent(provider._eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
    registerEvent(provider._eventFrame, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    registerEvent(provider._eventFrame, "TRAIT_CONFIG_UPDATED")
    registerEvent(provider._eventFrame, "SPELL_TEXT_UPDATE")
    registerEvent(provider._eventFrame, "SPELL_DATA_LOAD_RESULT")
    registerEvent(provider._eventFrame, "PLAYER_REGEN_ENABLED")
    provider._eventFrame:SetScript("OnEvent",function(_, event, spellID)
        if event == "SPELL_DATA_LOAD_RESULT" then
            if not provider.descriptionRequests[spellID] then return end
            provider:ClearDescriptionRequest(spellID)
        elseif event == "PLAYER_REGEN_ENABLED" and not provider.dirty then return end
        scheduleRefresh(provider)
    end)
end

function M:Init()
    if self._initialized then return true end
    local module = self
    local handle, err = _G.Lychee:RegisterProvider({
        id = self.Provider.extensionID, apiVersion="1.0.0", i18n=L.resources, version = "2.0.0", title = L["玩家技能"],
        scope=I.ProviderModules.Support:Scope("builtin.player-spells"), entries = {},
        onEnable = function(providerHandle)
            module.Provider.providerHandle = providerHandle
            module.Provider._active = true
            attachEvents(module.Provider)
            if InCombatLockdown and InCombatLockdown() then module.Provider.dirty = true
            else module.Provider:Refresh() end
            return function(reason)
                module.Provider:Detach(reason == "unregister")
                if reason == "unregister" then module.handle, module._initialized = nil, nil end
            end
        end,
    })
    if not handle then return false, err end
    self.handle, self.Provider.providerHandle, self._initialized = handle, handle, true
    return true
end
