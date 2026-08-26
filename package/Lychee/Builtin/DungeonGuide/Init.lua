local I = _G.LycheeInternal
local P=I.Builtin.DungeonGuide
function P:Init()
    if self._initialized then return end; self._initialized=true
    local data=I.BuiltinData and I.BuiltinData.DungeonGuide or {}
    for i=1,#data do self:Add(data[i]) end
    local d=I.Registry:Begin({id=self.extensionID,apiVersion=1,minApiRevision=1,title="大秘境指南"}); if not d then return end
    d:RegisterCapabilityProvider({id="dungeon-guide.index",type="dungeon.creatures",version=1,priority=90,query=function(req) return self:Query(req) end})
    d:RegisterSearchSource({
        id = "records",
        version = 1,
        revision = 1,
        priority = 90,
        scope = { product = "retail" },
        snapshot = function()
            local records, ids = {}, {}
            for id in pairs(self.items) do ids[#ids + 1] = id end
            table.sort(ids)
            for index = 1, #ids do
                local id, item = ids[index], self.items[ids[index]]
                records[#records + 1] = {
                    id = "dungeon-creature:" .. tostring(id),
                    kind = "creature",
                    category = { id = "dungeons", title = { default = "Dungeons", zhCN = "副本" }, order = 40 },
                    title = item.name,
                    aliases = item.aliases,
                    keywords = item.skills,
                    description = item.subtext,
                    icon = item.icon,
                    payload = { creatureID = id },
                    actions = {
                        { id = "open-detail", title = "查看详情", kind = "intent", intent = { type = "builtin.dungeon-guide.open", version = 1, payload = { creatureID = id } } },
                    },
                }
            end
            return records
        end,
    })
    d:RegisterCommand(self:BuildCommand()); d:RegisterIntentHandler(self:BuildHandler()); d:RegisterPanelFactory(self:BuildPanel()); self.handle=d:Commit()
end
