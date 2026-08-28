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
    local d=I.Registry:Begin({
        id=self.Provider.extensionID,apiVersion=1,minApiRevision=1,title="玩家技能",
        onEnabled=function()
            if not module._initialized then return end
            module.Provider._active=true
            attachEvents(module.Provider)
            module.Provider:Refresh()
        end,
        onDisabled=function()
            if module._initialized then module.Provider:Detach(false) end
        end,
        onHostDetached=function()
            module.Provider:Detach(true)
            module.handle=nil
            module._initialized=nil
        end,
    }); if not d then return false, "REGISTRATION_UNAVAILABLE" end
    local sourceToken = d:RegisterSearchSource({
        id = "records",
        version = 1,
        revision = 1,
        priority = 100,
        scope = { product = "retail" },
        snapshot = function() return self.Provider:BuildSearchRecords() end,
    })
    if not sourceToken then d:Abort(); return false, "SOURCE_REGISTRATION_FAILED" end
    local handle, commitErr=d:Commit()
    if not handle then return false, commitErr end
    local sourceHandle, sourceErr=handle:GetSearchSource("records")
    if not sourceHandle then handle:Unregister(); return false, sourceErr end

    self.handle=handle
    self.Provider.sourceHandle=sourceHandle
    self.Provider._active=true
    attachEvents(self.Provider)
    self._initialized=true
    return true
end
