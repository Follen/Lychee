-- Integration tests use the real Host/index with deterministic game boundaries.
local combat,stamp=false,100
local virtual=0
local hasSocket,socket=pcall(require,"socket")
local wall=hasSocket and socket.gettime or os.clock
local frames,timers,calls={},{},{}
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function GetTime() return stamp end
function debugprofilestop() return os.clock()*1000 end
function CreateFrame()
    local f={events={},scripts={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    frames[#frames+1]=f; return f
end
C_Timer={NewTimer=function(delay,fn)
    local t={callback=fn,delay=delay,due=virtual+delay}
    function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t; return t
end}
local maxBatch,totalCPU,batches=0,0,0
local function drain()
    local rounds=0
    while #timers>0 do
        rounds=rounds+1;assert(rounds<500,"unbounded work")
        local batch=timers;timers={}
        for _,timer in ipairs(batch) do
            if not timer.cancelled then
                virtual=math.max(virtual,timer.due)
                local start=os.clock();timer.callback()
                local ms=(os.clock()-start)*1000
                maxBatch=math.max(maxBatch,ms); totalCPU=totalCPU+ms;batches=batches+1
            end
        end
    end
end
local function event(m,e,...)
    if m.frame and m.frame.events[e] and m.frame.scripts.OnEvent then m.frame.scripts.OnEvent(m.frame,e,...) end
end
local bags={}
for n=1,512 do bags[n]={itemID=n,itemName="物品"..n,iconFileID=134400,stackCount=2} end
NUM_TOTAL_EQUIPPED_BAG_SLOTS=5
C_Container={GetContainerNumSlots=function(b) return b==0 and 512 or 0 end,
    GetContainerItemInfo=function(b,s) return b==0 and bags[s] or nil end,
    GetContainerItemID=function(b,s) return b==0 and bags[s] and bags[s].itemID end,
    SetItemSearch=function(s) calls.bagSearch=s end}
function OpenAllBags() calls.bags=true end
function ContainerFrameUtil_GetItemButtonAndContainer()
    return {IsVisible=function() return true end,GetFrameLevel=function() return 1 end}
end
local createCatalogFrame=CreateFrame
function CreateFrame(...)
    local f=createCatalogFrame(...)
    function f:EnableMouse() end
    function f:ClearAllPoints() end
    function f:SetAllPoints() end
    function f:SetParent() end
    function f:SetFrameLevel() end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:CreateTexture()
        return {SetColorTexture=function() end,SetPoint=function() end,SetHeight=function() end,SetWidth=function() end,SetAllPoints=function() end}
    end
    return f
end
C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 62 end}
local talentIDs,gearIDs={},{}
for n=1,16 do talentIDs[n]=n;gearIDs[n]=n end
C_ClassTalents={GetConfigIDsBySpecID=function() return talentIDs end,GetLastSelectedSavedConfigID=function() return 1 end}
C_Traits={GetConfigInfo=function(id) return {name="天赋方案"..id} end}
PlayerSpellsFrame={TalentsFrame={LoadConfigInternal=function(_,id,auto) calls.talent=id;assert(auto);return true end}}
PlayerSpellsUtil={OpenToClassTalentsTab=function() calls.talentsOpen=true end}
C_EquipmentSet={GetEquipmentSetIDs=function() return gearIDs end,
    GetEquipmentSetInfo=function(id) return "装备方案"..id,134400,id,id==1,10,10,0,0 end,
    UseEquipmentSet=function(id) calls.gear=id;return true end}
local inits={}
for n=1,256 do inits[n]={data={name="设置"..n}} end
local cat={GetCategorySet=function() return 1 end,GetID=function() return 7 end,GetName=function() return "声音" end}
Settings={CategorySet={Game=1}}
SettingsPanel={GetAllCategories=function() return {cat} end,GetLayout=function() return {GetInitializers=function() return inits end} end,
    OpenToCategory=function(_,id,name) calls.category=id;calls.setting=name;return true end}
SettingsPanel.GetCurrentCategory=function() return cat end
SettingsPanel.IsShown=function() return calls.category~=nil end
C_SettingsUtil={OpenSettingsPanel=function(id,name) SettingsPanel:OpenToCategory(id,name) end}
function ReloadUI() calls.reload=true end
CooldownViewerSettings={ShowUIPanel=function() calls.cdm=true end,IsShown=function() return calls.cdm end}
local units={player={"我","甲服","Player-1-1"},party1={"同名","乙服","Player-2-2"},party2={"同名","丙服","Player-3-3"}}
function UnitFullName(u) if units[u] then return units[u][1],units[u][2] end end
function UnitGUID(u) return units[u] and units[u][3] end
function UnitClass() return "法师","MAGE" end
C_ClassColor={GetClassColor=function() return {r=0.25,g=0.5,b=1} end}
function UnitExists(u) return units[u]~=nil end
function GetNormalizedRealmName() return "甲服" end
function IsInGroup() return units.party1~=nil end
function IsInRaid() return false end
local maps,runs={},{}
for n=1,8 do maps[n]=600+n;runs[n]={challengeModeID=600+n,mapScore=200+n,bestRunLevel=12,finishedSuccess=n~=2} end
C_MythicPlus={GetOwnedKeystoneChallengeMapID=function() return 601 end,GetOwnedKeystoneLevel=function() return 10 end,RequestMapInfo=function() end}
C_ChallengeMode={GetMapTable=function() return maps end,GetMapUIInfo=function(id) return id==602 and "毒牙祭坛" or "地城"..(id-600),id,1800,134400 end}
C_ChallengeMode.GetDungeonScoreRarityColor=function() return {r=1,g=0.5,b=0} end
C_ChallengeMode.GetSpecificDungeonScoreRarityColor=function() return {r=0.5,g=0,b=1} end
C_MythicPlus.GetSeasonBestForMap=function(id) if id==602 then return {level=11},{level=12} end end
C_PlayerInfo={GetPlayerMythicPlusRatingSummary=function(u) if u~="party2" then return {currentSeasonScore=2500,runs=runs} end end}
function GetLFGDungeonInfo(id) return id==3102 and "地城1" or "其他" end
C_SpellBook={IsSpellKnown=function(id) return id==1286801 end}
C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,SendAddonMessage=function(prefix,msg,channel)
    calls.messages=(calls.messages or 0)+1;assert(prefix=="LibKS" and channel=="PARTY");return 0 end}
dofile("tests/support/runtime.lua").Load("provider", {"Builtin/Achievements/Locales.lua", "Builtin/AddonInspector/Locales.lua", "Builtin/Bags/Locales.lua", "Builtin/BlizzardSettings/Locales.lua", "Builtin/Bosses/Locales.lua", "Builtin/Crests/Locales.lua", "Builtin/EquipmentSets/Locales.lua", "Builtin/GameMenus/Locales.lua", "Builtin/GreatVault/Locales.lua", "Builtin/Keystones/Locales.lua", "Builtin/Mounts/Locales.lua", "Builtin/PlayerSpells/Locales.lua", "Builtin/TalentLoadouts/Locales.lua", "Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Core/ResultActionExecutor.lua", "Builtin/Shared/CatalogProvider.lua", "Builtin/Bags/Provider.lua", "Builtin/TalentLoadouts/Provider.lua", "Builtin/EquipmentSets/Provider.lua", "Builtin/BlizzardSettings/Provider.lua", "Builtin/Keystones/Provider.lua", "Builtin/Init.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local baseFrames=#frames
collectgarbage("collect");local baseKB=collectgarbage("count")
local ids={"builtin.bags","builtin.talent-loadouts","builtin.equipment-sets","builtin.blizzard-settings","builtin.keystones"}
local defaultScenario=arg and arg[1]=="--defaults"
if not defaultScenario then
    for _,id in ipairs(ids) do I.CharacterStore:DisabledProviders()[id]=true end
end
I.Builtin:Init()
if defaultScenario then
    drain()
    for _,id in ipairs(ids) do
        local entry=assert(I.Registry.entries[id])
        assert(entry.userEnabled and I.Registry:IsEnabled(id),id.." must activate by default")
    end
    assert(next(I.CharacterStore:DisabledProviders())==nil)
    print("Catalog defaults PASS all five real registration paths activate without user opt-in")
    return
end
collectgarbage("collect");local disabledKB=collectgarbage("count")-baseKB
assert(#frames==baseFrames and #timers==0,"disabled optional sources must not start work")
assert(disabledKB<128,"disabled registration memory")
local modules={I.Builtin.Bags,I.Builtin.TalentLoadouts,I.Builtin.EquipmentSets,I.Builtin.BlizzardSettings,I.Builtin.Keystones}
local metrics={}
for _,m in ipairs(modules) do
    local inherited=m.Step
    metrics[m.id]={cpu=0,peak=0}
    function m:Step()
        local startCPU,startWall=os.clock(),wall()
        inherited(self)
        local metric=metrics[self.id]
        metric.cpu=metric.cpu+(os.clock()-startCPU)*1000
        metric.peak=math.max(metric.peak,(wall()-startWall)*1000)
        metric.finish=virtual
    end
end
for _,m in ipairs(modules) do assert(I.Registry:SetUserEnabled(m.id,true)) end
drain()
for _,m in ipairs(modules) do assert(not m.lastError,m.id..":"..tostring(m.lastError)) end
for id,metric in pairs(metrics) do
    print(string.format("COLD %s cpu_ms=%.2f peak_wall_ms=%.2f scheduled_seconds=%.2f",id,metric.cpu,metric.peak,metric.finish))
    -- Bags now validate one secure-item descriptor per entry; measured baseline/new in bag-actions.md.
    local cpuBudget=id=="builtin.bags" and 75 or 50
    assert(metric.cpu<cpuBudget and metric.peak<5 and metric.finish<1.5,"cold budget "..id)
end
collectgarbage("collect"); local retained=collectgarbage("count")-baseKB
local function query(text)
    local _,items=I.Search.Query:Query(text,{visible=true});return items
end
local function find(text,id)
    for _,item in ipairs(query(text)) do if not id or item.id==id then return item end end
    error("Missing "..text.." / "..tostring(id))
end
local function action(m,id,recordID)
    local record=I.Providers.entries[m.id].recordMap[recordID]
    return m.actions[id].run(record)
end
assert(find("背包:物品512").providerID=="builtin.bags")
assert(find("装备：装备方案16").providerID=="builtin.equipment-sets")
for _,item in ipairs(query("设置：")) do assert(item.providerID=="builtin.blizzard-settings") end
assert(find("rl").id=="reload" and find("reload").id=="reload" and find("cdm").id=="cdm")
-- Full public-shaped hits versus compact internal hits, with fixed fuzzy clock.
local realProfiler=debugprofilestop
debugprofilestop=function() return 1 end
for _,text in ipairs({"物品512","物品","设置256","冰","not-found"}) do
    local filter={sourceID="builtin.bags:records"}
    I.Search.StaticIndex:ClearQueryCache()
    local full=I.Search.StaticIndex:Search(text,20,filter)
    I.Search.StaticIndex:ClearQueryCache()
    local compact=I.Search.StaticIndex:Search(text,20,filter,true)
    assert(#full==#compact)
    for index=1,#full do
        local a,z=I.Search.Query:Materialize(full[index]),I.Search.Query:Materialize(compact[index])
        for _,key in ipairs({"id","text","subtext","description","icon","sourceID","sourceTitle","sourceGeneration","sourceRevision","confidence","stableID","kindTitle"}) do
            assert(a[key]==z[key],"compact divergence "..key)
        end
        for key,value in pairs(a.evidence) do assert(value==z.evidence[key],"evidence divergence") end
        assert(a.interaction.actions[1].id==z.interaction.actions[1].id)
    end
end
debugprofilestop=realProfiler
assert(action(I.Builtin.BlizzardSettings,"open",find("设置:设置256").id).ok and calls.category==7 and calls.setting=="设置256")
assert(action(I.Builtin.BlizzardSettings,"cdm","cdm").ok and calls.cdm)
bags[1],bags[2]=bags[2],bags[1]
assert(action(I.Builtin.Bags,"locate","item:1").ok and calls.bagSearch=="")
bags[2]=nil
assert(not action(I.Builtin.Bags,"locate","item:1").ok,"stale slot must not act on another item")
event(I.Builtin.Bags,"BAG_UPDATE_DELAYED");drain()
assert(not I.Providers.entries["builtin.bags"].recordMap["item:1"])
assert(action(I.Builtin.TalentLoadouts,"apply","talent:2").ok and calls.talent==2)
talentIDs={1};assert(not action(I.Builtin.TalentLoadouts,"apply","talent:2").ok)
assert(action(I.Builtin.EquipmentSets,"equip","equipment:2").ok and calls.gear==2)
local keys=I.Builtin.Keystones
for _,item in ipairs(query("毒牙")) do
    assert(item.providerID~="builtin.keystones","unrelated keys must not match a dungeon listed only in seasonal scores")
end
local ownItem=find("key","key:Player-1-1")
assert(ownItem.kindTitle=="分数 |cffff80002500|r" and ownItem.payload.scoreRows[8][3]:find("208.0",1,true))
assert(ownItem.icon==134400 and ownItem.text:find("|cff4080ff我-甲服|r",1,true))
assert(#ownItem.payload.scoreRows==8 and ownItem.payload.scoreRows[2][2]=="限时 +11","own timed record must win over overtime level")
assert(find("key","key:Player-2-2").payload.scoreRows[2][2]=="超时 +12","peer overtime must not appear timed")
assert(find("key","key:Player-3-3").payload.scoreRows[1][2]=="未获取")
assert(ownItem.searchRecord.actions[1].spellID==1286801)
for _,term in ipairs({"地城1","毒牙","我-甲服","keys","大秘境","key:","钥匙：毒牙"}) do
    for _,item in ipairs(query(term)) do assert(item.providerID~="builtin.keystones","restricted key query: "..term) end
end
assert(find(" KEY ","key:Player-1-1") and find("钥匙","key:Player-1-1"))
assert(find("分数","key:Player-1-1"),"score overview remains searchable")
event(keys,"CHAT_MSG_ADDON","LibKS","12,601,2700","PARTY","同名")
assert(not keys.members["同名-乙服"].received,"ambiguous short name rejected")
event(keys,"CHAT_MSG_ADDON","LibKS","12,601,2700","GUILD","同名-乙服");drain()
assert(find("key","key:Player-2-2").text:find("+12",1,true))
stamp=stamp+2
event(keys,"CHAT_MSG_ADDON","LibKS","13,602,2700","PARTY","同名-乙服");drain()
local matched=query("毒牙")
assert(#matched==0,"dungeon search never returns team keys, even matching keys")
assert(find("key","key:Player-2-2").payload.mapID==602,"key trigger still returns updated member")
stamp=stamp+2
event(keys,"CHAT_MSG_ADDON","LibKS","12,601,2700","PARTY","同名-乙服");drain()
local keyRevision=keys.handle:GetState().revision
runs[8].mapScore=209;keys:MarkDirty();drain()
assert(keys.handle:GetState().revision>keyRevision and find("key","key:Player-1-1").payload.scoreRows[8][3]:find("209.0",1,true),"score-only update still refreshes tooltip")
local messages=calls.messages;query("key");query("key");assert(calls.messages==messages,"request throttle")
event(keys,"CHAT_MSG_ADDON","LibKS","20,601,9999","PARTY","外人-乙服")
assert(not keys.members["外人-乙服"])
units.party1=nil;event(keys,"GROUP_ROSTER_UPDATE");drain()
assert(not keys.members["同名-乙服"])
local b=I.Builtin.Bags
local rev=b.handle:GetState().revision
event(b,"GET_ITEM_INFO_RECEIVED",99999);assert(#timers==0,"unrelated item event")
event(b,"BAG_UPDATE_DELAYED");drain();assert(b.handle:GetState().revision==rev,"no-change must not publish")
combat=true;event(b,"PLAYER_REGEN_DISABLED");assert(not b.timer and not b.job)
combat=false;event(b,"PLAYER_REGEN_ENABLED");drain()
local source=I.Search.Query:_BuildRequest("未知:物品",{},1)
assert(source.raw=="未知:物品" and not source.filter.sourceID and source.filter.excludedSources["builtin.keystones:records"],"unknown prefix retains global policy")
-- Independent reference: prefix isolation equals a direct scan of this fixture.
local fixture=assert(Lychee:RegisterProvider({id="builtin.player-spells",title="技能",version="1",apiVersion=2,
    entries={{id="frost",title="冰霜箭"},{id="fire",title="火焰箭"}}}))
local results=query("技能：冰")
assert(#results==1 and results[1].id=="frost")
results=query("技能:");assert(#results==2)
fixture:Unregister()
-- Warm precisely the measured operation sequence; cold timing is above.
for n=1,10 do query(n%2==0 and "背包:物品512" or "设置:设置256") end
drain();collectgarbage("collect");local warm=collectgarbage("count")
if arg[1]=="--profile" then
    local search=I.Search.StaticIndex.Search
    function I.Search.StaticIndex:Search(...)
        local before=collectgarbage("count");local out=search(self,...)
        print("INDEX_ALLOC",collectgarbage("count")-before,"results",#out,"candidates",self.diagnostics.lastCandidates)
        return out
    end
    collectgarbage("stop");local before=collectgarbage("count");query("背包:物品512")
    print("TOTAL_ALLOC",collectgarbage("count")-before)
    local item=query("背包:物品512")[1];local n=0;for k in pairs(item) do n=n+1;print(k) end;print("FIELDS",n)
    collectgarbage("restart");return
end
collectgarbage("stop");local start=os.clock()
for n=1,100 do query(n%2==0 and "背包:物品512" or "设置:设置256") end
local queryMS=(os.clock()-start)*1000;local allocation=collectgarbage("count")-warm
collectgarbage("restart");collectgarbage("collect");local growth=collectgarbage("count")-warm
print(string.format("MEASURE disabled=%.1f retained=%.1f alloc=%.1f growth=%.1f max_batch=%.2f total=%.2f",disabledKB,retained,allocation,growth,maxBatch,totalCPU))
assert(retained<4096,"added catalogue memory")
assert(allocation<4096,"100-query allocation")
assert(growth<512,"retained growth")
for _,m in ipairs(modules) do
    m:MarkDirty();assert(I.Registry:SetUserEnabled(m.id,false))
    assert(not m.timer and not m.job and not next(m.frame.events),"disable stops work")
    local retainedIDs=0
    for id,signature in pairs(m.signatures) do
        assert(type(id)=="string" and signature==false,"disabled keeps only invalidated identity keys")
        retainedIDs=retainedIDs+1
    end
    assert(retainedIDs<=4096,"retained identities stay bounded")
end
drain()
bags[3]=nil
assert(I.Registry:SetUserEnabled(b.id,true));drain()
assert(not I.Providers.entries[b.id].recordMap["item:3"],"disable/re-enable removes obsolete record")
local originalUpdate=b.handle.Update
local previousSignature=b.signatures["item:4"]
bags[4].stackCount=7
b.handle.Update=function() return nil,{code="INJECTED_FAILURE"} end
b:MarkDirty();drain()
assert(b.signatures["item:4"]==previousSignature and b.dirty,"failed commit must keep dirty/snapshot")
b.handle.Update=originalUpdate;b:MarkDirty();drain()
assert(b.signatures["item:4"]~=previousSignature,"retry commits fresh signature")
local oldBuild=b.build
b.build=function(self) self:MarkDirty();coroutine.yield() end
b:MarkDirty()
local one=timers;timers={}
for _,t in ipairs(one) do if not t.cancelled then t.callback() end end
b.build=oldBuild
assert(I.Registry:SetUserEnabled(b.id,false));drain()
assert(not b.job and not b.timer,"reentrant old batch stopped")
local originalFrames=#frames
local retired=b.handle
assert(retired:Unregister());assert(retired:GetState()==nil)
assert(b:Init());assert(I.Registry:SetUserEnabled(b.id,true));drain()
assert(#frames==originalFrames,"unregister/re-register reuses event frame")
print(string.format("EXPANSION PASS disabled_KiB=%.1f added_KiB=%.1f alloc100_KiB=%.1f growth_KiB=%.1f query100_ms=%.2f batches=%d max_batch_ms=%.2f total_cpu_ms=%.2f",disabledKB,retained,allocation,growth,queryMS,batches,maxBatch,totalCPU))
