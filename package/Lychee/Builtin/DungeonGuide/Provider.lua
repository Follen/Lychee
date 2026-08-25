local I = _G.LycheeInternal
local P={items={},byAlias={},extensionID="builtin.dungeon-guide"}
I.Builtin.DungeonGuide=P
local function add(map,k,id)
    if type(k)=="table" and k.locale and k.locale~="default" and k.locale~=I.Search.Normalizer.locale then return end
    k=I.Search.Normalizer:AliasText(k); if not k then return end
    k=I.Search.Normalizer:Normalize(k); map[k]=map[k] or {}; map[k][#map[k]+1]=id
end
function P:Add(x) self.items[x.id]=x; add(self.byAlias,x.name,x.id); for i=1,#(x.aliases or {}) do add(self.byAlias,x.aliases[i],x.id) end; for i=1,#(x.skills or {}) do add(self.byAlias,x.skills[i],x.id) end end
function P:Query(req) local q=I.Search.Normalizer:Normalize(req.text or ""); local out,seen={},{}; for a,ids in pairs(self.byAlias) do if a:find(q,1,true) then for i=1,#ids do local id=ids[i]; if not seen[id] then seen[id]=true; local x=self.items[id]; out[#out+1]={id="creature-"..id,text=x.name,subtext=x.subtext,icon=x.icon,payload={creatureID=id}} end end end end; return out end
