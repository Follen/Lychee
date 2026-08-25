local I = _G.LycheeInternal
local P=I.Builtin.DungeonGuide
function P:Init()
    if self._initialized then return end; self._initialized=true
    self:Add({id=101,name="阿瓦罗恩",aliases={"Avaron","M1"},skills={"炽热冲击","烈焰新星"},subtext="大秘境小怪"})
    self:Add({id=102,name="红玉守护者",aliases={"红玉老一","Ruby"},skills={"爆裂碎片"},subtext="红玉新生法池"})
    local d=I.Registry:Begin({id=self.extensionID,apiVersion=1,minApiRevision=1,title="大秘境指南"}); if not d then return end
    d:RegisterCapabilityProvider({id="dungeon-guide.index",type="dungeon.creatures",version=1,priority=90,query=function(req) return self:Query(req) end})
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
