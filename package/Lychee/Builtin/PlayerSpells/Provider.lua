local I = _G.LycheeInternal
local P={items={},byAlias={},extensionID="builtin.player-spells"}
I.Builtin.PlayerSpells.Provider=P
P.aliasDefinitions=(I.BuiltinData and I.BuiltinData.PlayerSpellAliases) or {}
local function norm(s) return I.Search.Normalizer:Normalize(s) end
local function addAlias(self,alias,spellID)
    local text=I.Search.Normalizer:AliasText(alias); if not text then return end
    local locale=type(alias)=="table" and alias.locale
    if locale and locale~="default" and locale~=I.Search.Normalizer.locale then return end
    local key=norm(text); self.byAlias[key]=self.byAlias[key] or {}; self.byAlias[key][#self.byAlias[key]+1]=spellID
end
function P:AddSpell(spell)
    if type(spell.id)~="number" or type(spell.name)~="string" then return end
    local aliases=spell.aliases or self.aliasDefinitions[spell.id]
    self.items[spell.id]=spell; addAlias(self,spell.name,spell.id)
    if type(aliases)=="table" then for i=1,#aliases do addAlias(self,aliases[i],spell.id) end end
end
function P:Clear() self.items={}; self.byAlias={} end
function P:RefreshFromSpellBook()
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines)~="function" then return false end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank==nil then return false end
    local ok,count=pcall(C_SpellBook.GetNumSpellBookSkillLines); if not ok or type(count)~="number" then return false end
    local nextItems={}
    for line=1,count do
        local good,info=pcall(C_SpellBook.GetSpellBookSkillLineInfo,line)
        if good and type(info)=="table" and not info.shouldHide and not info.isGuild then
            local first=(info.itemIndexOffset or 0)+1
            local last=first+(info.numSpellBookItems or 0)-1
            for slot=first,last do
                local itemOK,item=pcall(C_SpellBook.GetSpellBookItemInfo,slot,bank)
                if itemOK and type(item)=="table" and type(item.spellID)=="number" and item.spellID>0 and not item.isPassive and not item.isOffSpec then
                    nextItems[item.spellID]={id=item.spellID,name=item.name,icon=item.iconID,subtext=item.subName,aliases=self.aliasDefinitions[item.spellID]}
                end
            end
        end
    end
    self:Clear(); for _,spell in pairs(nextItems) do self:AddSpell(spell) end
    self.lastRefresh="spellbook"; return true
end
function P:Refresh()
    if self:RefreshFromSpellBook() then return end
    self:Clear()
    self:AddSpell({id=642,name="复仇之怒",subtext="离线 fixture",aliases=self.aliasDefinitions[642],icon=135875})
    self:AddSpell({id=395289,name="红玉新生法池传送门",subtext="离线 fixture",aliases=self.aliasDefinitions[395289],icon=237515})
    self:AddSpell({id=446534,name="麦卡贡传送门",subtext="离线 fixture",aliases=self.aliasDefinitions[446534],icon=154285})
    self.lastRefresh="fallback"
end
function P:Query(request)
    local q=norm(request.text or request.normalized or ""); local out={}; local seen={}
    for alias,ids in pairs(self.byAlias) do if alias:find(q,1,true) then for i=1,#ids do local id=ids[i]; if not seen[id] then seen[id]=true; local s=self.items[id]; out[#out+1]={id="spell-"..id,text=s.name,subtext=s.subtext,icon=s.icon,payload={spellID=id},interaction={primaryActionID="open-detail",actions={{id="open-detail",title="查看详情",kind="intent"},{id="cast",title="施放",kind="secure-spell",spellID=id}},drag={type="spell",spellID=id}}} end end end end
    return out
end
