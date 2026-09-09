local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells

local function registerEvent(frame, event)
    -- Some client branches omit individual legacy events; do not abort addon init.
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

local function scheduleRefresh(provider)
    if not provider._active or provider._refreshPending then return end
    provider._refreshPending = true
    local function flush()
        if not provider._active then provider._refreshPending = nil; return end
        provider._refreshPending = nil
        provider:Refresh()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, flush) else flush() end
end

local function attachEvents(provider)
    if not provider._active or provider._eventFrame or not CreateFrame then return end
    provider._eventFrame = CreateFrame("Frame")
    registerEvent(provider._eventFrame, "SPELLS_CHANGED")
    registerEvent(provider._eventFrame, "LEARNED_SPELL_IN_SKILL_LINE")
    registerEvent(provider._eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
    registerEvent(provider._eventFrame, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    registerEvent(provider._eventFrame, "TRAIT_CONFIG_UPDATED")
    registerEvent(provider._eventFrame, "SPELL_TEXT_UPDATE")
    registerEvent(provider._eventFrame, "SPELL_DATA_LOAD_RESULT")
    provider._eventFrame:SetScript("OnEvent",function(_, event, spellID)
        if event == "SPELL_DATA_LOAD_RESULT" then provider:ClearDescriptionRequest(spellID) end
        scheduleRefresh(provider)
    end)
end

function M:Init()
    if self._initialized then return true end
    local refreshed, refreshErr = self.Provider:Refresh()
    if not refreshed then return false, refreshErr end
    local module = self
    local handle, err = _G.Lychee:RegisterProvider({
        id = self.Provider.extensionID, apiVersion = 2, version = "2.0.0", title = "玩家技能",
        scope = { product = "retail" }, entries = self.Provider:BuildSearchRecords(),
        onEnable = function(providerHandle)
            module.Provider.providerHandle = providerHandle
            module.Provider._active = true
            attachEvents(module.Provider)
            module.Provider:Refresh()
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