local timers,frames,combat={},0,false
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
for _,file in ipairs({"Bootstrap.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
    "Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua",
    "Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua",
    "Builtin/InterfaceActions.lua","Builtin/CatalogProvider.lua","Builtin/Achievements.lua"}) do dofile("package/Lychee/"..file) end
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.Builtin.Achievements
local baseFrames,baseTimers=frames,#timers
collectgarbage("collect");local baseline=collectgarbage("count")
M:Init();assert(reads==0 and frames==baseFrames and #timers==baseTimers,"disabled means no scans/frames/timers")
assert(I.Registry:SetUserEnabled(M.id,true));drain()
assert(M.ids and #M.ids==6002 and not M.job and not M.timer,"enabled achievement catalog missing: "..tostring(M.lastError))
collectgarbage("collect");local retained=collectgarbage("count")-baseline
assert(retained<4096,"6002 compact records stay below 4 MiB")
local function query(q)
    local result
    M.query({normalized=q,limit=50},function(v) result=v end);drain();assert(result)
    return result
end
local actual
I.Search.Query:Query("引领潮流",{visible=true},nil,function(items) actual=items end)
drain();assert(actual and #actual==1 and actual[1].id=="achievement:6000","enabled achievement missing from real search")
local previousReads=reads
M.frame.onEvent(M.frame,"ACHIEVEMENT_EARNED",6000);drain()
assert(reads==previousReads+1 and #M.ids==6002,"earned achievement refreshes catalogue")
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
print(string.format("Achievements PASS records=6002 retained_KiB=%.1f peak_batch_ms=%.2f frames=%d disabled_work=0",retained,peak,frames))
