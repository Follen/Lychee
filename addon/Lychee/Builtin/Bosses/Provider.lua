local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.bosses")
local M
local function build(self,put,checkpoint)
    self.hasFallback=false
    local data=I.Builtin.JournalCatalog
    -- One localized name per bounded instance catalogue, reused across encounters.
    local instances={}
    for offset=1,#data.encounters,3 do
        local encounterID,instanceID,canonical=data.encounters[offset],data.encounters[offset+1],data.encounters[offset+2]
        local instance=data.instances[instanceID]
        local name=instances[instanceID]
        if not name then
            name=EJ_GetInstanceInfo and EJ_GetInstanceInfo(instanceID)
            if not name then self.hasFallback=true end
            name=name or (I.Locale:IsChinese() and instance[1]) or L:Format("副本 %d",instanceID)
            instances[instanceID]=name
        end
        local title=EJ_GetEncounterInfo and EJ_GetEncounterInfo(encounterID)
        if not title then self.hasFallback=true end
        title=title or (I.Locale:IsChinese() and canonical) or L:Format("首领 %d",encounterID)
        local record={id="boss-"..encounterID,title=title,subtitle=name,kindTitle=L["团本首领"],
            icon=instance[2],aliases={name},keywords={"首领","boss",tostring(encounterID)},
            payload={encounterID=encounterID,instanceID=instanceID},actions={"open"}}
        put(record,title.."\0"..name)
        checkpoint()
    end
end
M=I.Builtin.CatalogProvider:New("builtin.bosses",L["团本首领"],{"ADDON_LOADED"},build,
    {open={title=L["查看首领指南"],run=function(entry)
        return I.Builtin.InterfaceActions:Run(function()
            return M:Open(entry)
        end,L)
    end}})
M.defaultEnabled=true
M.batchSize=16
function M:onEvent(event,addon)
    if event=="ADDON_LOADED" and addon=="Blizzard_EncounterJournal" and self.hasFallback then self:MarkDirty() end
end
function M:onReady()
    if not self.hasFallback and self.frame then self.frame:UnregisterEvent("ADDON_LOADED") end
end
-- Encoded relations are private to this provider; outward records use named fields.
local N=I.Search.Normalizer
local diffIDs={3,4,5,6,9,14,15,16}
local families={[3]=1,[4]=1,[9]=1,[14]=1,[5]=2,[6]=2,[15]=2,[16]=3}
local familyNames={"普通","英雄","史诗"}
local familyEnglish={"normal","heroic","mythic"}
local familyWords={["普通"]=1,["英雄"]=2,["史诗"]=3,normal=1,heroic=2,mythic=3}
local function included(mask,index) return math.floor(mask/2^(index-1))%2==1 end
local function choose(mask,family,wanted)
    local best
    for index,d in ipairs(diffIDs) do
        if included(mask,index) and (not family or families[d]==family) and (not wanted or d==wanted) then
            if not best or families[d]<families[best] or families[d]==families[best] and d<best then best=d end
        end
    end
    return best
end
local function bossMask(id)
    local mask=0
    for text in (I.Builtin.JournalCatalog.difficulties[id] or ""):gmatch("%d+") do
        local d=tonumber(text)
        for index,value in ipairs(diffIDs) do if value==d then mask=mask+2^(index-1);break end end
    end
    return mask
end
function M:Names(offset)
    local data=I.Builtin.JournalCatalog
    local id,owner,canonical=data.encounters[offset],data.encounters[offset+1],data.encounters[offset+2]
    local name=EJ_GetEncounterInfo and EJ_GetEncounterInfo(id)
    local instance=EJ_GetInstanceInfo and EJ_GetInstanceInfo(owner)
    return name or (I.Locale:IsChinese() and canonical) or L:Format("首领 %d",id),
        instance or (I.Locale:IsChinese() and data.instances[owner][1]) or L:Format("副本 %d",owner)
end
function M:Reference(offset,spell,mask,section,diff)
    local data=I.Builtin.JournalCatalog
    local id,owner=data.encounters[offset],data.encounters[offset+1]
    local boss,instance=self:Names(offset)
    local name=spell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    local aliases={boss,instance,tostring(id)}
    local actions,labels={"open"},{}
    for family,key in ipairs(familyEnglish) do
        if choose(mask,family) then
            labels[#labels+1]=L[familyNames[family]]
            aliases[#aliases+1]=familyNames[family];aliases[#aliases+1]=key
            actions[#actions+1]=key
        end
    end
    if spell then aliases[#aliases+1]=tostring(spell) end
    return {id="boss-"..id..(spell and "-spell-"..spell.."-"..diff or "-difficulty-"..diff),
        title=spell and (name or L:Format("技能 %d",spell)) or boss,
        subtitle=(spell and boss.." · " or "")..instance.." · "..table.concat(labels," / "),
        kindTitle=L["团本首领"]..(spell and " · "..L["技能"] or ""),
        icon=spell and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or data.instances[owner][2],
        aliases=aliases,actions=actions,
        payload={encounterID=id,instanceID=owner,spellID=spell or 0,sectionID=section or 0,difficultyID=diff}}
end
function M:ResolveReference(id,family)
    if type(id)~="string" then return end
    local boss,spell,wanted=id:match("^boss%-(%d+)%-spell%-(%d+)%-(%d+)$")
    if not boss then boss,wanted=id:match("^boss%-(%d+)%-difficulty%-(%d+)$") end
    if not boss then return end
    boss,spell,wanted=tonumber(boss),tonumber(spell),tonumber(wanted)
    if family then wanted=nil end
    local data=I.Builtin.JournalCatalog
    for offset=1,#data.encounters,3 do if data.encounters[offset]==boss then
        if not spell then
            local mask=bossMask(boss);local diff=choose(mask,family,wanted)
            if diff then return self:Reference(offset,nil,mask,0,diff) end
            return
        end
        local total,best,section=0,nil,nil
        for sid,sec,maskText in (data.abilities[boss] or ""):gmatch("(%d+):(%d+):(%d+)") do
            if tonumber(sid)==spell then
                local mask=tonumber(maskText)
                for index in ipairs(diffIDs) do if included(mask,index) and not included(total,index) then total=total+2^(index-1) end end
                local diff=choose(mask,family,wanted)
                if diff and (not best or families[diff]<families[best] or families[diff]==families[best] and diff<best) then best,section=diff,tonumber(sec) end
            end
        end
        if best then return self:Reference(offset,spell,total,section,best) end
        return
    end end
end
function M:Open(entry,family)
    local payload=entry.payload
    if payload.difficultyID then
        local current=self:ResolveReference(entry.id,family)
        if not current then return false end
        payload=current.payload
    end
    return I.Builtin.InterfaceActions:OpenJournal(payload.instanceID,payload.encounterID,payload.difficultyID,payload.sectionID)
end
for family,key in ipairs(familyEnglish) do
    local target=family
    M.actions[key]={title=L[familyNames[family]],run=function(entry)
        return I.Builtin.InterfaceActions:Run(function() return M:Open(entry,target) end,L)
    end}
end
M.resolve=function(id) return M:ResolveReference(id) end
function M:Query(request,reply,context)
    if not self.active then reply({});return end
    local query=request.normalized or ""
    local original=query
    if query=="" then reply({});return end
    local word,rest=query:match("^(%S+)%s+(.+)$")
    local family=word and familyWords[word]
    if family then query=rest end
    if not C_Spell or not C_Spell.GetSpellName then reply({});return end
    local resources=context.resources
    local fields,selected,pending={},{},{}
    local task,event,deadline,owned
    local closed,scanning,changed,awaiting=false,false,false,0
    local limit=math.max(1,math.min(20,request.limit or 20))
    local terms=N:Terms(query)
    local function dispose()
        closed=true;fields,selected,pending=nil,nil,nil
        if task then task:Cancel();task=nil end
        if event then event:Cancel();event=nil end
        if deadline then deadline:Cancel();deadline=nil end
    end
    owned=resources:Own("raid-query",dispose)
    if not owned then reply({});return end
    local function finish()
        if closed then return end
        local rows={}
        for _,r in ipairs(selected) do rows[#rows+1]=M:Reference(r.offset,r.spell,r.mask,r.section,r.diff) end
        dispose();reply(rows)
    end
    local function field(kind,text)
        if text and text~="" then local n=#fields;fields[n+1],fields[n+2],fields[n+3]=kind,text,N:Normalize(text,false) end
    end
    local function add(offset,spell,mask,section,diff,score)
        if not score or not diff then return end
        local at=#selected+1
        for i,r in ipairs(selected) do if score>r.score then at=i;break end end
        if at<=limit then
            local r=#selected==limit and table.remove(selected) or {}
            r.offset,r.spell,r.mask,r.section,r.diff,r.score=offset,spell,mask,section,diff,score
            table.insert(selected,at,r)
        end
    end
    local exact=false
    local run
    local function work(skills,loadMissing)
        selected={};local count,started=0,debugprofilestop()
        local function checkpoint()
            count=count+1
            if count>=128 or debugprofilestop()-started>=1 then coroutine.yield();count,started=0,debugprofilestop() end
        end
        local data=I.Builtin.JournalCatalog
        for offset=1,#data.encounters,3 do
            local id=data.encounters[offset]
            local boss,instance=M:Names(offset)
            for i=#fields,1,-1 do fields[i]=nil end
            field("alias",boss);field("alias",instance);field("alias",tostring(id))
            local base=#fields
            if family then local mask=bossMask(id);add(offset,nil,mask,0,choose(mask,family),N:ScoreCompiled(query,fields,terms,false)) end
            if not skills then
                if query==fields[3] or query==fields[6] or query==tostring(id) then exact=true end
            else
                local current,total,section,diff,fallbackDiff,fallbackSection
                local function flush()
                    if not current then return end
                    if diff or family then
                        local name=C_Spell.GetSpellName(current)
                        if not name and loadMissing and pending[current]==nil and event and C_Spell.RequestLoadSpellData then
                            pending[current]=true;awaiting=awaiting+1
                            local ok=pcall(C_Spell.RequestLoadSpellData,current)
                            if not ok and pending[current]==true then pending[current]=false;awaiting=awaiting-1 end
                        end
                        field("title",name);field("alias",tostring(current))
                        -- A full spell name wins over an ambiguous leading difficulty word.
                        local literal=family and name and N:Normalize(name,false)==original
                        local rank=N:ScoreCompiled(literal and original or query,fields,literal and N:Terms(original) or terms,false)
                        add(offset,current,total,literal and fallbackSection or section,literal and fallbackDiff or diff,rank)
                        for i=#fields,base+1,-1 do fields[i]=nil end
                    end
                    checkpoint()
                end
                for spellText,sectionText,maskText in (data.abilities[id] or ""):gmatch("(%d+):(%d+):(%d+)") do
                    local spell,mask=tonumber(spellText),tonumber(maskText)
                    if spell~=current then flush();current,total,section,diff,fallbackDiff,fallbackSection=spell,0,nil,nil,nil,nil end
                    for i in ipairs(diffIDs) do if included(mask,i) and not included(total,i) then total=total+2^(i-1) end end
                    local d=choose(mask,family)
                    if d and (not diff or families[d]<families[diff] or families[d]==families[diff] and d<diff) then diff,section=d,tonumber(sectionText) end
                    if family then
                        local any=choose(mask)
                        if any and (not fallbackDiff or families[any]<families[fallbackDiff] or families[any]==families[fallbackDiff] and any<fallbackDiff) then fallbackDiff,fallbackSection=any,tonumber(sectionText) end
                    end
                end
                flush()
            end
            checkpoint()
        end
    end
    run=function(skills,loadMissing)
        if closed then return end
        scanning=true
        task=resources:Run("raid-scan",function() work(skills,loadMissing) end,{
            complete=function()
                scanning=false
                if not skills then if exact then finish() else run(true,true) end
                elseif not loadMissing then finish()
                elseif awaiting==0 then if changed then run(true,false) else finish() end
                else deadline=resources:After("raid-spell-deadline",1.5,function()run(true,false)end);if not deadline then finish() end end
            end,
            error=function()dispose();reply({})end,combat=function()dispose();reply({})end})
        if not task then dispose();reply({}) end
    end
    event=resources:OnEvent("SPELL_DATA_LOAD_RESULT",function(_,id)
        if closed or pending[id]~=true then return end
        pending[id]=false;awaiting=awaiting-1;changed=true
        if awaiting==0 and not scanning then if deadline then deadline:Cancel();deadline=nil end;run(true,false) end
    end)
    run(false,false)
    return dispose
end
M.query=function(request,reply,context)return M:Query(request,reply,context)end
-- Chinese uses the shipped canonical catalogue, preserving its zero-driver
-- startup baseline. English native lookup is separately bounded by the builder.
if I.Locale:IsChinese() then
    function M:Init()
        if self.handle then return true end
        local data,records=I.Builtin.JournalCatalog,{}
        for offset=1,#data.encounters,3 do
            local encounterID,instanceID,canonical=data.encounters[offset],data.encounters[offset+1],data.encounters[offset+2]
            local instance=data.instances[instanceID]
            records[#records+1]={id="boss-"..encounterID,title=canonical,subtitle=instance[1],
                kindTitle=L["团本首领"],icon=instance[2],aliases={instance[1]},keywords={"首领","boss"},
                payload={encounterID=encounterID,instanceID=instanceID},actions={"open"}}
        end
        local handle,err=Lychee:RegisterProvider({id=self.id,apiVersion="1.0.0",version="1.0.0",
            title=L["团本首领"],i18n=L.resources,scope=I.Builtin.Support:Scope("builtin.bosses"),entries=records,actions=self.actions,query=self.query,resolve=self.resolve,
            onEnable=function() M.active=true;return function(reason) M.active=false;if reason=="unregister" then M.handle=nil end end end})
        self.handle=handle
        return handle~=nil,err
    end
end
I.Builtin.Bosses=M
