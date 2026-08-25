local I = _G.LycheeInternal
local P={items={},byAlias={},extensionID="builtin.player-spells"}
I.Builtin.PlayerSpells.Provider=P
local function norm(s) return I.Search.Normalizer:Normalize(s) end
function P:AddSpell(spell)
    if type(spell.id)~="number" then return end
    self.items[spell.id]=spell
    local function addAlias(v)
        if type(v)=="table" and v.locale and v.locale~="default" and v.locale~=I.Search.Normalizer.locale then return end
        local x=I.Search.Normalizer:AliasText(v); if not x then return end
        local k=norm(x); self.byAlias[k]=self.byAlias[k] or {}; self.byAlias[k][#self.byAlias[k]+1]=spell.id
    end
    addAlias(spell.name)
    for i=1,#(spell.aliases or {}) do addAlias(spell.aliases[i]) end
end
function P:Query(request)
    local q=norm(request.text or request.normalized or ""); local out={}; local seen={}
    for alias,ids in pairs(self.byAlias) do if alias:find(q,1,true) then for i=1,#ids do local id=ids[i]; if not seen[id] then seen[id]=true; local s=self.items[id]; out[#out+1]={id="spell-"..id,text=s.name,subtext=s.subtext,icon=s.icon,payload={spellID=id},interaction=s.interaction} end end end end
    return out
end
