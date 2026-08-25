local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells

local function registerEvent(frame, event)
    -- Some client branches omit individual legacy events; do not abort addon init.
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

local function scheduleRefresh(provider)
    if provider._refreshPending then return end
    provider._refreshPending = true
    local function flush()
        provider._refreshPending = nil
        provider:Refresh()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, flush) else flush() end
end

function M:Init()
    if self._initialized then return end; self._initialized=true
    self.Provider:Refresh()
    self.Provider._eventFrame = CreateFrame and CreateFrame("Frame")
    if self.Provider._eventFrame then
        registerEvent(self.Provider._eventFrame, "SPELLS_CHANGED")
        registerEvent(self.Provider._eventFrame, "LEARNED_SPELL_IN_SKILL_LINE")
        registerEvent(self.Provider._eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
        registerEvent(self.Provider._eventFrame, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
        registerEvent(self.Provider._eventFrame, "TRAIT_CONFIG_UPDATED")
        registerEvent(self.Provider._eventFrame, "SPELL_TEXT_UPDATE")
        registerEvent(self.Provider._eventFrame, "SPELL_DATA_LOAD_RESULT")
        self.Provider._eventFrame:SetScript("OnEvent",function(_, event, spellID)
            if event == "SPELL_DATA_LOAD_RESULT" then self.Provider:ClearDescriptionRequest(spellID) end
            scheduleRefresh(self.Provider)
        end)
    end
    local d=I.Registry:Begin({id=self.Provider.extensionID,apiVersion=1,minApiRevision=1,title="玩家技能"}); if not d then return end
    d:RegisterCapabilityProvider({id="player-spells.index",type="player.spells",version=1,priority=100,query=function(req) return self.Provider:Query(req) end})
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
