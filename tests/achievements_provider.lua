local timers,frames,combat={},0,false
local apiReads=0
local serverTime=1000000
local character="Player-fixture"
function GetServerTime() return serverTime end
function UnitGUID() return character end
function GetAchievementCategory() return 1 end
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function debugprofilestop() return os.clock()*1000 end
function CreateFrame()
    frames=frames+1
    local f={events={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(_,fn) self.onEvent=fn end
    return f
end
C_Timer={NewTimer=function(delay,fn)
    local t={fn=fn,delay=delay};function t:Cancel() self.cancelled=true;self.fn=nil end
    timers[#timers+1]=t;return t
end}
local peak=0
local function drain()
    local guard=0
    while #timers>0 do
        guard=guard+1;assert(guard<2000)
        local batch=timers;timers={}
        -- Host timeout is not part of successful deterministic completion.
        table.sort(batch,function(a,b) return a.delay<b.delay end)
        for _,t in ipairs(batch) do if not t.cancelled and t.delay<5 then
            local start=os.clock();t.fn();peak=math.max(peak,(os.clock()-start)*1000)
        end end
    end
end
local reads,complete,shift,linked,opened=0,false,false,nil,nil
function GetCategoryList() reads=reads+1;return {1} end
function GetCategoryNumAchievements(_,all) return all and 6003 or 6000 end
function GetAchievementInfo(id,index)
    apiReads=apiReads+1
    if index and index>6000 then error("Invalid achievement index") end
    if index then id=index end
    if id<1 or id>6002 then return end
    return id,id==6000 and "引领潮流：乌拉特点" or "测试成就"..id,10,complete,nil,nil,nil,"成就描述",0,134400
end
function GetPreviousAchievement(id) return id==1 and 6001 or nil end
function GetNextAchievement(id) return id==1 and 6002 or nil end
function GetAchievementNumCriteria() return 1 end
function GetAchievementCriteriaInfo() return "条件",0,complete,25,100 end
function GetAchievementLink(id) return "|Hachievement:"..id.."|h[成就]|h" end
function IsShiftKeyDown() return shift end
AchievementFrame={IsShown=function() return opened~=nil end}
function ToggleAchievementFrame() opened=0 end
function AchievementFrame_SelectAchievement(id) opened=id end
ChatFrameUtil={InsertLink=function(link) linked=link;return false end,OpenChat=function(link) linked=link;return {} end}
dofile("tests/support/runtime.lua").Load("provider", {"../Lychee_Player/Achievements/Locales.lua", "../Lychee_Inspector/Locales.lua", "../Lychee_Player/Bags/Locales.lua", "../Lychee_Player/BlizzardSettings/Locales.lua", "../Lychee_Encounters/Bosses/Locales.lua", "../Lychee_Player/Crests/Locales.lua", "../Lychee_Player/EquipmentSets/Locales.lua", "../Lychee_Player/GameMenus/Locales.lua", "../Lychee_Player/GreatVault/Locales.lua", "../Lychee_Player/Keystones/Locales.lua", "../Lychee_Player/Mounts/Locales.lua", "../Lychee_Player/PlayerSpells/Locales.lua", "../Lychee_Player/TalentLoadouts/Locales.lua", "Core/Scheduler.lua", "Shared/InterfaceActions.lua", "Shared/CatalogProvider.lua", "../Lychee_Player/Achievements/Provider.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local M=TestPackages.Modules.Achievements
local baseFrames,baseTimers=frames,#timers
collectgarbage("collect");local baseline=collectgarbage("count")
M:Init();assert(M.active and reads==0 and frames==baseFrames+1,"default enabled; catalogue collection is scheduled, not synchronous")
assert(I.Registry:SetUserEnabled(M.id,true))
local coldResults
local timersBeforeQuery=#timers
I.Providers:Search({normalized="引领潮流",limit=20},{},function(items) coldResults=items end)
assert(M.resumeQuery and I.Providers:HasPendingQuery(),"cold search waits for catalogue completion")
assert(#timers==timersBeforeQuery+1,"waiting adds only Host timeout, no polling timer")
drain()
assert(coldResults and #coldResults==1 and not M.resumeQuery and not I.Providers:HasPendingQuery(),"cold search automatically receives the target")
assert(M.ids and #M.ids==6002 and not M.job and not M.timer,"enabled achievement catalog missing: "..tostring(M.lastError))
collectgarbage("collect");local retained=collectgarbage("count")-baseline
assert(retained<1024,"6002 character-owned compact records stay below 1 MiB")
local function query(q)
    local result
    M.query({normalized=q,limit=50},function(v) result=v end);drain();assert(result)
    return result
end
local actual
I.Search.Query:Query("引领潮流",{visible=true},nil,function(items) actual=items end)
drain();assert(actual and #actual==1 and actual[1].id=="achievement:6000","enabled achievement missing from real search")
local previousReads,previousAPI=reads,apiReads
M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",6000);drain()
assert(reads==previousReads and apiReads==previousAPI+1 and #M.ids==6002,"earned achievement reads only its ID")
I.Search.Query:Query("   ",{visible=true})
assert(not I.Providers:HasPendingQuery(),"whitespace must not query all achievements")
local categoryResults
I.Search.Query:Query("成就：",{visible=true},nil,function(items) categoryResults=items end)
drain();assert(categoryResults and #categoryResults>0,"explicit category remains browsable")
local result=query("6001")
query("测试成就6001")
collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count")
for i=1,20 do query("测试成就6001") end
local allocation=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect")
local growth=collectgarbage("count")-before
assert(allocation<1024 and growth<128,"repeated queries have bounded allocation and retention")
print(string.format("Achievement query20 allocated_KiB=%.1f retained_growth_KiB=%.1f",allocation,growth))
assert(#result==1 and result[1].payload.achievementID==6001 and result[1].subtitle:find("25/100",1,true))
assert(#query("测试 成就6002")==1,"multiple search terms")
assert(#query("成就")==50,"broad result count is bounded")
local hostResults
I.Providers:Search({normalized="6001",limit=50,filter={sourceID=M.id..":records"}},{},function(v) hostResults=v end)
drain();assert(hostResults and #hostResults==1 and hostResults[1].text=="测试成就6001","real Host dynamic search")
complete=true;assert(query("6001")[1].subtitle:find("已完成",1,true));complete=false
local ref={providerID=M.id,entryID="achievement:6001"}
local restored=I.Providers:Resolve(ref,{})
assert(restored,"dynamic entries restore from history")
local actionResult=I.Providers:Execute(restored,"open",{})
assert(actionResult and opened==6001)
shift=true;assert(I.Providers:Execute(restored,"open",{}));assert(linked:find("6001",1,true))
shift=false;linked=nil;assert(I.Providers:Execute(restored,"share",{}));assert(linked)
local openChat=ChatFrameUtil.OpenChat
ChatFrameUtil.OpenChat=function() return nil end
assert(not I.Providers:Execute(restored,"share",{}),"chat input failure must not be reported as success")
ChatFrameUtil.OpenChat=openChat
local replied=false
local cancel=M.query({normalized="测试",limit=50},function() replied=true end)
cancel();drain();assert(not replied and not M.cancelQuery)
M.query({normalized="测试",limit=50},function() error("late reply") end)
assert(I.Registry:SetUserEnabled(M.id,false));drain()
assert(not M.ids and not M.texts and not M.job and not M.timer and not M.cancelQuery and next(M.frame.events)==nil)
assert(I.Registry:SetUserEnabled(M.id,true));combat=true;M:MarkDirty();assert(not M.timer)
combat=false;M:MarkDirty();drain();assert(#M.ids==6002 and frames==baseFrames+1)
assert(I.Registry:SetUserEnabled(M.id,false));drain()
local saved=LycheePlayerCharacterDB.achievementCatalog
assert(saved and #LycheePlayerCharacterDB.achievementCatalog.ids==6002,"character cache persists while disabled")
local beforeWarm=apiReads
assert(I.Registry:SetUserEnabled(M.id,true));drain()
assert(apiReads==beforeWarm and M.ids==LycheePlayerCharacterDB.achievementCatalog.ids,"warm enable reuses the owned character arrays without enumeration or array copies")
local beforeIdle=reads
combat=true;M.frame.onEvent(M.frame,"PLAYER_REGEN_DISABLED")
assert(not M.timer and not M.job and not M.frame.events.PLAYER_REGEN_ENABLED,"idle combat does not schedule rebuild")
combat=false
local beforeGain=apiReads
combat=true;M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",6000)
assert(apiReads==beforeGain and M.pendingCount==1 and not M.timer,"combat queues ID only")
combat=false;M.frame.onEvent(M.frame,"PLAYER_REGEN_ENABLED");drain()
assert(apiReads==beforeGain+1 and M.pendingCount==0 and reads==beforeIdle,"combat recovery is incremental")
I.Registry:SetUserEnabled(M.id,false)
LycheePlayerCharacterDB.achievementCatalog.ids[2]=LycheePlayerCharacterDB.achievementCatalog.ids[1]
local beforeCorrupt=apiReads
I.Registry:SetUserEnabled(M.id,true);drain()
assert(apiReads>beforeCorrupt and #M.ids==6002,"duplicate historical IDs trigger rebuild")
I.Registry:SetUserEnabled(M.id,false)
serverTime=serverTime+604801
local beforeExpired=apiReads
I.Registry:SetUserEnabled(M.id,true);drain();assert(apiReads>beforeExpired,"expired cache gets full audit")
I.Registry:SetUserEnabled(M.id,false)
character="Player-other"
local beforeCharacter=apiReads
I.Registry:SetUserEnabled(M.id,true);drain();assert(apiReads>beforeCharacter,"character visibility is isolated")
I.Registry:SetUserEnabled(M.id,false);drain()
local beforeCounts=apiReads
LycheePlayerCharacterDB.achievementCatalog.counts[1]=5999
I.Registry:SetUserEnabled(M.id,true);drain();assert(apiReads>beforeCounts,"offline category drift rebuilds")
I.Registry:SetUserEnabled(M.id,false)
I.Search.RuntimeIdentity.build="next-build"
local beforeBuild=apiReads
I.Registry:SetUserEnabled(M.id,true);drain();assert(apiReads>beforeBuild,"build signature invalidates cache")
combat=true
for id=1,257 do M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",id) end
assert(M.pendingCount==256 and M.forceFull and not M.timer,"bounded event queue falls back to one full rebuild")
combat=false;M.frame.onEvent(M.frame,"PLAYER_REGEN_ENABLED");drain()
assert(M.pendingCount==0 and not M.forceFull)
I.Registry:SetUserEnabled(M.id,false);drain()
collectgarbage("collect");local warmBase=collectgarbage("count")
local infoBefore,started=apiReads,os.clock()
collectgarbage("stop")
for n=1,10 do I.Registry:SetUserEnabled(M.id,true);drain();I.Registry:SetUserEnabled(M.id,false);drain() end
local warmAlloc=collectgarbage("count")-warmBase
local warmMs=(os.clock()-started)*1000
collectgarbage("restart");collectgarbage("collect");local warmGrowth=collectgarbage("count")-warmBase
assert(apiReads==infoBefore and warmAlloc<2048 and warmGrowth<64,"warm cycles do not enumerate or retain growth")
print(string.format("Achievement warm10 cpu_ms=%.2f allocated_KiB=%.1f retained_growth_KiB=%.1f achievement_reads=0",warmMs,warmAlloc,warmGrowth))
-- Independent two-category fixture: removing/readding one item must not read the unchanged category.
local sourceInfo=GetAchievementInfo
local categoryTwo=100
local categoryReads={[1]=0,[2]=0}
function GetCategoryList() reads=reads+1;return {1,2} end
function GetCategoryNumAchievements(category) return category==1 and 5900 or categoryTwo end
function GetAchievementCategory(id) return id>5900 and id<=6000 and 2 or 1 end
function GetAchievementInfo(id,index)
    if index then
        categoryReads[id]=categoryReads[id]+1
        id=id==1 and index or 5900+index
    end
    return sourceInfo(id)
end
I.Registry:SetUserEnabled(M.id,true);drain()
assert(#M.ids==6002)
I.Registry:SetUserEnabled(M.id,false)
categoryTwo=99;categoryReads={[1]=0,[2]=0}
I.Registry:SetUserEnabled(M.id,true);drain()
assert(categoryReads[1]==0 and categoryReads[2]==99 and not M.positions[6000] and #M.ids==6001,"only changed category is read; deleted ID removed")
I.Registry:SetUserEnabled(M.id,false)
categoryTwo=100;categoryReads={[1]=0,[2]=0}
I.Registry:SetUserEnabled(M.id,true);drain()
assert(categoryReads[1]==0 and categoryReads[2]==100 and M.positions[6000],"new item appears without unchanged category reads")
for id=1,6002 do assert(M.positions[id],"independent expected ID set") end
I.Registry:SetUserEnabled(M.id,false)
-- Real character SV swaps: only current role exists in the loaded root.
local characters={}
local function switch(id)
    I.Registry:SetUserEnabled(M.id,false);drain()
    characters[character]=LycheePlayerCharacterDB
    character=id
    LycheePlayerCharacterDB=characters[id] or {schema=1,settings={}}
    I.Registry:SetUserEnabled(M.id,true);drain()
end
switch("Player-A")
local cacheA=LycheePlayerCharacterDB.achievementCatalog
assert(cacheA.schema==4 and cacheA.entries==nil and cacheA.base==nil)
local idsA=M.ids
switch("Player-B")
assert(M.ids~=idsA and LycheePlayerCharacterDB.achievementCatalog~=cacheA)
local beforeSwitch=apiReads
switch("Player-A")
assert(apiReads==beforeSwitch and M.ids==idsA,"return to current role reuses its persisted authority")
assert(not LycheeDB or LycheeDB.achievementCatalog==nil,"account no longer retains other character caches")
local function serialize(value)
    if type(value)=="number" then return tostring(value) end
    if type(value)=="string" then return string.format("%q",value) end
    assert(type(value)=="table")
    local out={"{"}
    for k,v in pairs(value) do out[#out+1]="["..serialize(k).."]="..serialize(v).."," end
    out[#out+1]="}";return table.concat(out)
end
I.Registry:SetUserEnabled(M.id,false);drain()
local encoded=serialize(LycheePlayerCharacterDB.achievementCatalog)
LycheePlayerCharacterDB.achievementCatalog=assert(loadstring("return "..encoded))()
local beforeReload=apiReads
I.Registry:SetUserEnabled(M.id,true);drain()
assert(apiReads==beforeReload and #M.ids==6002,"SV roundtrip avoids directory rescan")
local fixtureInfo=GetAchievementInfo
function GetAchievementInfo(id,index)
    local found,name,p,c,a,b,d,desc,flags,icon=fixtureInfo(id,index)
    if found==2 and character=="Player-A" then name="角色甲变更名称" end
    return found,name,p,c,a,b,d,desc,flags,icon
end
local earnedBefore=apiReads
M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",2);drain()
assert(apiReads==earnedBefore+1 and #query("角色甲变更名称")==1)
local changedText=LycheePlayerCharacterDB.achievementCatalog.texts[M.positions[2]]
local count=#M.ids
M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",2);drain()
assert(#M.ids==count and LycheePlayerCharacterDB.achievementCatalog.texts[M.positions[2]]==changedText)
switch("Player-B")
assert(#query("角色甲变更名称")==0,"another role did not acquire changed text")
switch("Player-A")
assert(#query("角色甲变更名称")==1,"current role incremental change survives switch")
I.Registry:SetUserEnabled(M.id,false);drain()
local raw=LycheePlayerCharacterDB.achievementCatalog
raw.texts[1]=string.rep("x",513)
local beforeBad=apiReads
I.Registry:SetUserEnabled(M.id,true);drain()
assert(apiReads>beforeBad and #M.ids==6002,"oversized persisted text rebuilds rather than truncating results")
-- Migrate a valid v3 role once, including sparse updates; no API full scan.
I.Registry:SetUserEnabled(M.id,false);drain()
raw=LycheePlayerCharacterDB.achievementCatalog
LycheeDB=LycheeDB or {}
LycheeDB.achievementCatalog={schema=3,domain=M.cacheDomain,
    base={ids=raw.ids,texts=raw.texts,categories=raw.categories},entries={{key=raw.key,
    builtAt=raw.builtAt,counts=raw.counts,ops={1,#raw.ids},
    extra={ids={},texts={},categories={}},updates={ids={2},texts={"旧缓存更新"},categories={1}}}}}
LycheePlayerCharacterDB.achievementCatalog=nil
local beforeMigration=apiReads
I.Registry:SetUserEnabled(M.id,true);drain()
assert(apiReads==beforeMigration and M.texts[M.positions[2]]=="旧缓存更新")
assert(LycheeDB.achievementCatalog==nil and LycheePlayerCharacterDB.achievementCatalog.schema==4)
I.Registry:SetUserEnabled(M.id,false);drain()
assert(not M.ids and not M.positions and not M.cache and not M.timer and next(M.frame.events)==nil)
print("Achievement character authority PASS default-on/role-isolation/roundtrip/increment/legacy-migration/budget")
print(string.format("Achievements PASS records=6002 retained_KiB=%.1f peak_batch_ms=%.2f frames=%d disabled_work=0",retained,peak,frames))
