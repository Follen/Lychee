local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:Init()
    if self._initialized then return end; self._initialized=true
    self.Provider:Refresh()
    self.Provider._eventFrame = CreateFrame and CreateFrame("Frame")
    if self.Provider._eventFrame then
        self.Provider._eventFrame:RegisterEvent("SPELLS_CHANGED")
        self.Provider._eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
        self.Provider._eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self.Provider._eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        self.Provider._eventFrame:SetScript("OnEvent",function() self.Provider:Refresh() end)
    end
    local d=I.Registry:Begin({id=self.Provider.extensionID,apiVersion=1,minApiRevision=1,title="玩家技能"}); if not d then return end
    d:RegisterCapabilityProvider({id="player-spells.index",type="player.spells",version=1,priority=100,query=function(req) return self.Provider:Query(req) end})
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
