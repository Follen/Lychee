local I = _G.LycheeInternal
local P=I.Builtin.DungeonGuide
function P:Init()
    if self._initialized then return end; self._initialized=true
    local data=I.BuiltinData and I.BuiltinData.DungeonGuide or {}
    for i=1,#data do self:Add(data[i]) end
    local d=I.Registry:Begin({id=self.extensionID,apiVersion=1,minApiRevision=1,title="大秘境指南"}); if not d then return end
    d:RegisterCapabilityProvider({id="dungeon-guide.index",type="dungeon.creatures",version=1,priority=90,query=function(req) return self:Query(req) end})
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
