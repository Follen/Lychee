local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:Init()
    if self._initialized then return end; self._initialized=true
    local spells={
        {id=642,name="复仇之怒",aliases={{text="翅膀",locale="zhCN"},{text="wings",locale="enUS"}},subtext="圣骑士爆发技能",icon=135875},
        {id=395289,name="红玉新生法池传送门",aliases={{text="红玉",locale="zhCN"},{text="ruby",locale="enUS"}},subtext="副本传送",icon=237515},
        {id=446534,name="麦卡贡传送门",aliases={{text="麦卡贡",locale="zhCN"},{text="mechagon",locale="enUS"}},subtext="副本传送",icon=154285},
    }
    for i=1,#spells do self.Provider:AddSpell(spells[i]) end
    local d=I.Registry:Begin({id=self.Provider.extensionID,apiVersion=1,minApiRevision=1,title="玩家技能"}); if not d then return end
    d:RegisterCapabilityProvider({id="player-spells.index",type="player.spells",version=1,priority=100,query=function(req) return self.Provider:Query(req) end})
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
