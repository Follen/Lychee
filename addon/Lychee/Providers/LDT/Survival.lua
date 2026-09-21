-- Bounded, synchronous calculator. No upstream globals, saved data, events or frames.
local M=_G.LycheeInternal.ProviderModules.LDT
local S={}
M.Survival=S
-- Display season IDs, not MythicPlusSeason DB2 IDs. See WCL investigation.
local seasonFactors={[34]=1.8945719251,[37]=1.9393*1.621}
-- Shared descriptions include another spell's direct hit. These IDs only tick.
local periodicOnly={[270292]=true,[265773]=true}
function S:DescriptionSpell(id) return id==1312104 and 1306736 or id end
local levels={1,1.07000005245,1.13999998569,1.23000001907,1.30999994278,1.39999997616,1.5,1.61000001431,1.72000002861,1.84000003338,2.01999998093,2.22000002861,2.45000004768,2.69000005722,2.96000003815,3.25999999046,3.57999992371,3.94000005722,4.32999992371,4.76999998093,5.25,5.76999998093,6.34999990463,6.98000001907,7.67999982834,8.44999980927,9.28999996185,10.22000026703,11.23999977112,12.36999988556,13.60999965668,14.97000026703,16.45999908447,18.11000061035,19.92000007629}
-- Numeric mechanics snapshot; localized names/icons come from the client.
S.effects={
    {id=1235057,group=1,flaskRating=165},
    {id=102342,group=1,dr=.2},{id=33206,group=1,dr=.4},{id=6940,group=1,dr=.3},
    {id=116849,group=1,absorb=.864},{id=357170,group=1,dr=.5},
    {id=388681,group=1,dr=.06},{id=382020,group=1,dr=.03},{id=53480,group=1,dr=.15},
    {id=387801,group=1,augment=6940,extra=.105},{id=440738,group=1,augment=33206,extra=.1},
    {id=465,group=2,dr=.03},{id=21562,group=2,health=.05},{id=1126,group=2,vers=.03},
    {id=207401,aura=207400,group=2,health=.1},{id=403264,group=2,health=.02},
    {id=238063,group=2,dr=.02,manual=true},{id=381637,group=2,dr=.04,manual=true},
    {id=407243,group=2,augment=403264,healthExtra=.02},{id=196864,group=2,augment=381637,extra=.008},
    {id=97462,group=3,health=.15},{id=98008,group=3,dr=.1},{id=62618,group=3,dr=.2},
    {id=51052,group=3,dr=.2,school="magic"},{id=374227,group=3,aoe=.2},
    {id=31821,group=3,dr=.09},{id=461243,group=3,dr=.05},
    {id=406220,group=3,absorb=.12},{id=388031,group=3,augment=406220,absorbExtra=1},
    {id=288384,group=3,augment=98008,extra=.05},
    {id=48707,group=3,absorb=.3,school="magic"},
}
S.passives={
    {id=454842,class="DEATHKNIGHT",dr=.05,school="magic"},
    {id=203513,class="DEMONHUNTER",dr=.1,school="magic",vengeance=true},
    {id=389696,class="DEMONHUNTER",dr=.03,school="magic",ranks=2},
    {id=428241,class="DEMONHUNTER",dr=.05,school="physical"},
    {id=16931,class="DRUID",dr=.04},
    {id=375544,class="EVOKER",dr=.02,school="magic",ranks=2,evoker=true},
    {id=384799,class="HUNTER",aoe=.05},
    {id=263135,class="HUNTER",spec=255,dr=.06,pet=true},
    {id=383092,class="MAGE",dr=.02,school="magic",ranks=2},
    {id=1297073,class="MAGE",aoe=.04},
    {id=388664,class="MONK",notSpec=268,dr=.06,windwalker=.1},
    {id=450427,class="MONK",notSpec=268,aoe=.02,ranks=2,windwalker=.03},
    {id=385427,class="PALADIN",aoe=.02,ranks=2},
    {id=402964,class="PALADIN",aoe=.03,holyAoe=.015,ranks=2},
    {id=390667,class="PRIEST",dr=.03,school="magic",ranks=2},
    {id=381650,class="SHAMAN",dr=.08,school="magic"},
    {id=386124,class="WARLOCK",dr=.03},
    {id=108415,class="WARLOCK",dr=.1,pet=true},
    {id=279423,class="WARRIOR",spec=71,aoe=.05},
}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v) return plain(v) and type(v)=="number" and v==v and v>=0 and v<1e15 and v or nil end
S.Number=number
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok and plain(a) and plain(b) and plain(c) then return a,b,c end
end
local function aura(id)
    local a=call(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID,id)
    return type(a)=="table"
end
local function known(id)
    return call(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true
end
local function clear(t) for k in pairs(t) do t[k]=nil end end
function S:ReadRanks(out)
    clear(out)
    local traits=C_Traits
    local config=call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    local info=config and call(traits and traits.GetConfigInfo,config)
    if type(info)~="table" or type(info.treeIDs)~="table" then return end
    local count=0
    for ti=1,math.min(#info.treeIDs,4) do
        local nodes=call(traits.GetTreeNodes,info.treeIDs[ti])
        if type(nodes)=="table" then for _,id in ipairs(nodes) do
            count=count+1;if count>512 then return false end
            local node=call(traits.GetNodeInfo,config,id)
            local entry=type(node)=="table" and node.activeEntry
            if type(entry)=="table" and number(entry.rank) and entry.rank>0 then
                local ei=call(traits.GetEntryInfo,config,entry.entryID)
                local di=type(ei)=="table" and call(traits.GetDefinitionInfo,ei.definitionID)
                if type(di)=="table" and number(di.spellID) and known(di.spellID) then out[di.spellID]=entry.rank end
            end
        end end
    end
    return true
end
function S:Snapshot(out,enemyLevel)
    out=out or {};out.valid=false
    if InCombatLockdown and InCombatLockdown() then return out end
    out.health=number(call(UnitHealthMax,"player"))
    local _,armor=call(UnitArmor,"player");out.armor=number(armor)
    local vd=number(call(GetCombatRatingBonus,CR_VERSATILITY_DAMAGE_DONE))
    local vb=number(call(GetVersatilityBonus,CR_VERSATILITY_DAMAGE_DONE))
    local vt=number(call(GetCombatRatingBonus,CR_VERSATILITY_DAMAGE_TAKEN))
    local vtb=number(call(GetVersatilityBonus,CR_VERSATILITY_DAMAGE_TAKEN))
    local rating=number(call(GetCombatRating,CR_VERSATILITY_DAMAGE_DONE))
    out.flaskVers,out.flaskDR=nil,nil
    if rating then
        local before=number(call(GetCombatRatingBonusForCombatRatingValue,CR_VERSATILITY_DAMAGE_DONE,rating))
        local after=number(call(GetCombatRatingBonusForCombatRatingValue,CR_VERSATILITY_DAMAGE_DONE,rating+165))
        local beforeDR=number(call(GetCombatRatingBonusForCombatRatingValue,CR_VERSATILITY_DAMAGE_TAKEN,rating))
        local afterDR=number(call(GetCombatRatingBonusForCombatRatingValue,CR_VERSATILITY_DAMAGE_TAKEN,rating+165))
        if before and after and beforeDR and afterDR then
            out.flaskVers=math.max(0,after-before)/100;out.flaskDR=math.max(0,afterDR-beforeDR)/100
        end
    end
    out.vers=vd and vb and (vd+vb)/100
    out.versDR=vt and vtb and (vt+vtb)/100
    local avoidance=number(call(GetAvoidance));out.avoidance=avoidance and avoidance/100
    local _,class=call(UnitClass,"player");out.class=class
    local specIndex=call(GetSpecialization);out.spec=specIndex and call(GetSpecializationInfo,specIndex)
    out.armorDR=out.armor and number(call(C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness,out.armor,enemyLevel or 92))
    out.season=number(call(C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID))
    out.ranks=out.ranks or {};local ranksComplete=self:ReadRanks(out.ranks)
    out.active=out.active or {};clear(out.active)
    for _,effect in ipairs(self.effects) do if not effect.manual and aura(effect.aura or effect.id) then out.active[effect.id]=true end end
    out.passives=out.passives or {};clear(out.passives)
    out.passivesComplete=ranksComplete~=false
    for _,rule in ipairs(self.passives) do
        if class==rule.class and (not rule.spec or out.spec==rule.spec) and out.spec~=rule.notSpec and known(rule.id)
            and (not rule.pet or (call(UnitExists,"pet")==true and call(UnitIsDead,"pet")==false)) then
            -- Never assume max rank when a multi-rank talent cannot be read.
            local rank=rule.ranks and out.ranks[rule.id] or 1
            if rule.ranks and not out.ranks[rule.id] then rank=nil;out.passivesComplete=false end
            if rank then out.passives[rule.id]=math.min(rank,rule.ranks or 1) end
        end
    end
    out.valid=out.health~=nil and out.health>0 and out.vers~=nil and out.versDR~=nil and out.avoidance~=nil
        and type(out.class)=="string" and number(out.spec)~=nil and out.season~=nil and out.passivesComplete
    return out
end
function S:Multiplier(level,boss,season)
    if not number(level) or level%1~=0 or level<0 or level>35 then return nil end
    local base=seasonFactors[season]
    if not base then return nil end
    local value=level==0 and 1 or levels[level]
    if level>=10 then value=value*(boss and 1.15 or 1.2) end
    return math.max(1,value*base)
end
local function school(text)
    if text:find("流血",1,true) or text:find("bleed",1,true) then return "bleed" end
    if text:find("物理",1,true) or text:find("physical",1,true) then return "physical" end
    for _,word in ipairs({"火焰","冰霜","自然","暗影","奥术","神圣","混沌","魔法","fire","frost","nature","shadow","arcane","holy","chaos","magic"}) do
        if text:find(word,1,true) then return "magic" end
    end
end
-- Parse explicit damage clauses only; never infer damage from an arbitrary large number.
function S:Parse(description,out,spellID)
    out=out or {};clear(out)
    out.first,out.tick=0,0
    out.damageSpellID=spellID==1306736 and 1312104 or spellID
    if periodicOnly[spellID] then out.periodicOnly=true;out.damageValid=true;return out end
    if type(description)~="string" or #description>8192 then return out end
    local t=description:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub(",",""):gsub("，",""):lower()
    local zh=t:find("伤害",1,true)~=nil
    local count=0
    local pattern=zh and "()(%d+%.?%d*)点([^%d]-)伤害()" or "()(%d+%.?%d*) ([%a ]-)damage()"
    for start,amount,kind,finish in t:gmatch(pattern) do
        local value=tonumber(amount)
        if value and value>0 then
            count=count+1
            local prefix=t:sub(math.max(1,start-65),start-1)
            local suffix=t:sub(finish,finish+45)
            local periodic=prefix:find("每[%d%.]+秒") or suffix:find("every [%d%.]+ sec") or prefix:find("every [%d%.]+ sec")
            local key=periodic and "tick" or "first"
            if key=="first" and (out[key]>0 or not school(kind)) then out.ambiguous=true end
            out[key]=out[key]+value;out[key.."School"]=school(kind)
        end
    end
    out.aoe=t:find("所有",1,true)~=nil or t:find("范围",1,true)~=nil or t:find("附近",1,true)~=nil or t:find("all ",1,true)~=nil or t:find("nearby",1,true)~=nil
    out.damageValid=count>0 and not out.ambiguous and (out.first>0 or out.tick>0)
    return out
end
local EMPTY={}
local function enabled(selected,active,id) return selected[id] or active[id] end
local function mitigation(self,stats,input,selected,active,versDR,kind)
        if kind~="magic" and kind~="physical" and kind~="bleed" then return nil end
        if kind=="physical" and not stats.armorDR then return nil end
        local factor=1-math.min(1,versDR)
        if kind=="physical" then factor=factor*(1-stats.armorDR) end
        if input.aoe then factor=factor*(1-math.min(1,stats.avoidance)) end
        for _,r in ipairs(self.passives) do
            local rank=stats.passives and stats.passives[r.id]
            local restriction=r.school
            if r.vengeance and stats.spec==581 then restriction=nil end
            if rank and (not restriction or restriction==kind or restriction=="physical" and kind=="bleed") then
                local dr=r.dr or 0
                if r.vengeance and stats.spec==581 then dr=.08 end
                if r.evoker and stats.spec~=1473 then dr=.04 end
                if r.windwalker and stats.spec==269 then dr=r.windwalker end
                factor=factor*(1-dr*rank)
                if input.aoe then factor=factor*(1-(r.holyAoe and stats.spec==65 and r.holyAoe or r.aoe or 0)*rank) end
            end
        end
        for _,e in ipairs(self.effects) do if enabled(selected,active,e.id) and not e.augment and (not e.school or e.school==kind) then
            local reduction=e.dr or 0
            for _,a in ipairs(self.effects) do if a.augment==e.id and a.extra and enabled(selected,active,a.id) then reduction=reduction+a.extra end end
            factor=factor*(1-math.min(1,reduction))
            if input.aoe and e.aoe then factor=factor*(1-e.aoe) end
        end end
        return factor
    end
local function hit(value,kind,absorb,magicAbsorb)
    if kind=="magic" then local used=math.min(value,magicAbsorb);value=value-used;magicAbsorb=magicAbsorb-used end
    local used=math.min(value,absorb)
    return value-used,absorb-used,magicAbsorb
end
function S:Calculate(stats,input,selected,out)
    out=out or {};clear(out)
    if not stats.valid or not input.confirmed then out.status="unknown";return out end
    if input.periodicOnly then out.status="noDirect";return out end
    local multiplier=self:Multiplier(input.level,input.boss,stats.season)
    if not multiplier or not number(input.first) then out.status="unknown";return out end
    if input.first==0 then out.status=input.tick and input.tick>0 and "noDirect" or "unknown";return out end
    local health,vers,versDR=stats.health,stats.vers,stats.versDR
    local active=stats.active or EMPTY
    for _,e in ipairs(self.effects) do
        if enabled(selected,active,e.id) then
            if e.flaskRating and not active[e.id] then
                if not stats.flaskVers or not stats.flaskDR then out.status="unknown";return out end
                vers=vers+stats.flaskVers;versDR=versDR+stats.flaskDR
            end
            if e.health and not active[e.id] then health=health*(1+e.health) end
            if e.healthExtra and enabled(selected,active,e.augment) and not active[e.augment] then health=health*(1+e.healthExtra/(1.02)) end
            if e.vers and not active[e.id] then vers=vers+e.vers;versDR=versDR+e.vers/2 end
        end
    end
    local absorb,magicAbsorb=0,0
    for _,e in ipairs(self.effects) do if enabled(selected,active,e.id) and e.absorb then
        local coefficient=e.absorb
        for _,a in ipairs(self.effects) do if a.augment==e.id and a.absorbExtra and enabled(selected,active,a.id) then coefficient=coefficient*(1+a.absorbExtra) end end
        local shield=health*coefficient*(1+vers)
        if e.school=="magic" then magicAbsorb=magicAbsorb+shield else absorb=absorb+shield end
    end end
    local firstFactor=input.first==0 and 1 or mitigation(self,stats,input,selected,active,versDR,input.firstSchool)
    if not firstFactor then out.status="unknown";return out end
    local correction=multiplier/(1+(input.tooltipVers or stats.vers))
    out.rawFirst=math.floor(input.first*correction)
    out.firstBeforeAbsorb=out.rawFirst*firstFactor
    out.health,out.shield,out.multiplier=health,absorb+magicAbsorb,multiplier
    out.first=hit(out.firstBeforeAbsorb,input.firstSchool,absorb,magicAbsorb)
    out.remaining=health-out.first
    out.status=out.remaining<=0 and "lethal" or "survives"
    return out
end
