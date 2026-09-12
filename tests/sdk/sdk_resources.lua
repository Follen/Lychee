local Fixture=dofile("tests/support/provider_fixture.lua")
-- Public SDK behaviour; deterministic external timer/event adapter.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","1","",120100 end
local combat=false
function InCombatLockdown() return combat end
local timers,frames={},{}
C_Timer={NewTimer=function(_,callback)
    local timer={callback=callback,Cancel=function(self) self.cancelled=true end}
    timers[#timers+1]=timer;return timer
end}
function CreateFrame()
    local f={events={},shown=false}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:UnregisterEvent(event) self.events[event]=nil end
    function f:SetScript(event,callback) self[event]=callback end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:SetAllPoints() end
    function f:GetWidth() return 100 end
    function f:GetHeight() return 100 end
    frames[#frames+1]=f;return f
end
local function drain()
    local pending=timers;timers={}
    for _,timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
end
dofile("tests/support/runtime.lua").Load("provider",{"UI/ViewHost.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local function definition(id)
    return {id=id,title=id,version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={NAME="Test"}},catalog={}}
end
assert(Lychee:Supports("1.0.0"))
local def=definition("test.resources")
local scope,queryScope,viewScope
def.onEnable=function(handle) scope=assert(handle:Resources()) end
def.query=function(_,reply,context)
    queryScope=context.resources
    assert(queryScope:After("reply",0,function() reply({{id="row",title="Result"}}) end))
end
local handle=assert(Fixture:Register(def))
local called=0
scope:After("refresh",0,function() called=called+100 end)
scope:After("refresh",0,function() called=called+1 end)
drain();assert(called==1,"replacement is latest only")
local old=assert(scope:After("late",0,function() called=called+100 end));local late=timers[#timers]
old:Cancel();late.callback();assert(called==1,"late timer cannot publish")
local finished=0
scope:Run("batch",function() coroutine.yield();return 7 end,{complete=function(value) finished=value end})
drain();assert(finished==0);drain();assert(finished==7)
local oldCancelled=false
scope:Own("replace",function()
    oldCancelled=true
    scope:Own("replace",function() end)
end)
local accepted,err=scope:Own("replace",function() error("must not install") end)
assert(not accepted and err.code=="RESOURCE_REENTRANT" and oldCancelled)
local beforeFrames=#frames
local token=assert(scope:OnEvent("PLAYER_LEVEL_UP",function() called=called+1 end))
assert(#frames==beforeFrames+1)
local hub=frames[#frames]
hub.OnEvent(hub,"PLAYER_LEVEL_UP");assert(called==2)
token:Cancel();assert(not next(hub.events) and hub.OnEvent==nil)
local register=hub.RegisterEvent
local beforeEvent=scope:GetDiagnostics().providerResources
hub.RegisterEvent=function() return false end
local rejected,invalidEvent=scope:OnEvent("INVALID_EVENT",function() end)
hub.RegisterEvent=register
assert(not rejected and invalidEvent.code=="INVALID_EVENT" and scope:GetDiagnostics().providerResources==beforeEvent)
assert(handle.Settings==nil,"Host must not provide a business DB")
local Storage=dofile("lychee-sdk/Storage.lua")
local addonDB={providerSettings={}}
local function openSettings()
    return assert(Storage.Open({id=def.id,version=1,root=function() return addonDB.providerSettings end,ready=function() return true end}))
end
local settings=openSettings()
local input={text="hello"};assert(settings:Set("choice",input));input.text="changed"
local first=settings:Get("choice");first.text="mutated"
assert(settings:Get("choice").text=="hello")
assert(settings:Set("enabled",false));assert(settings:Get("enabled",true)==false)
local saved=addonDB;addonDB={providerSettings={}}
assert(settings:Get("choice")==nil,"character settings are isolated")
addonDB=saved
local storedProviders=saved.providerSettings
saved.providerSettings=setmetatable({},{__index=function() error("must not read corrupt container") end})
local badSettings,settingsError=settings:Get("choice")
assert(not badSettings and settingsError.code=="INVALID_SETTINGS")
saved.providerSettings=storedProviders
assert(not settings:Set("bad",setmetatable({},{__index={}})))
assert(not settings:Set("big",string.rep("x",20000)))
local cache=assert(scope:Cache("recent",{entries=2,bytes=256}))
assert(cache:Set("a",{x=1}));assert(cache:Set("b",2));assert(cache:Set("c",3))
assert(cache:Get("a")==nil and cache:Get("b")==2)
assert(not cache:Set("big",string.rep("x",300)))
assert(cache:Get("b")==2,"oversized replacement leaves old cache intact")
local copy=cache:GetDiagnostics();assert(copy.entries==2 and copy.bytes<=256)
local received
I.Search.Query:Query("result",{visible=true},nil,function(rows) received=rows end)
local oldQuery=queryScope
I.Search.Query:Cancel("changed")
assert(not oldQuery:IsActive())
drain();assert(not received or #received==0)
local count=0
while true do
    local owned,why=scope:Own("limit"..count,function() end)
    if not owned then assert(why.code=="RESOURCE_LIMIT");break end
    count=count+1;assert(count<=64)
end
assert(handle:GetDiagnostics().providerResources==64)
handle:SetAvailability(false)
assert(not scope:IsActive() and handle:GetDiagnostics().providerResources==0)
assert(not cache:Set("x",1) and not scope:After("x",0,function() end))
assert(settings:Get("choice").text=="hello","settings survive disable")
handle:SetAvailability(true);assert(scope:IsActive())
local closed=0
local panel=Lychee.UI.ViewHost:Create({})
local ok=panel:Mount({create=function(context)
    viewScope=context.resources
    context.resources:Own("cleanup",function() closed=closed+1 end)
    error("partial construction")
end},{extensionID=def.id})
assert(not ok and closed==1 and not viewScope:IsActive(),"failed view releases resources")
assert(panel:Mount({create=function(context)
    viewScope=context.resources;context.resources:Own("cleanup",function() closed=closed+1 end)
    return {}
end},{extensionID=def.id}))
panel:Unmount();panel:Unmount();assert(closed==2 and not viewScope:IsActive())
local settled=0
scope:Run("combat",function() error("must not execute in combat") end,{combat=function() settled=settled+1 end})
combat=true;drain();combat=false;assert(settled==1)
local capturedScope=scope
assert(handle:Unregister());assert(not capturedScope:IsActive())
assert(settings:Get("choice").text=="hello","AddOn storage has an independent lifetime")
settings:Close()
local value,why=settings:Get("choice");assert(value==nil and why.code=="STORAGE_CLOSED")
local fresh=assert(Fixture:Register(definition(def.id)))
settings=openSettings();assert(settings:Get("choice").text=="hello")
assert(not handle:Resources())
-- Creation failures must be total, bounded and return stable errors.
local isolated=assert(fresh:Resources())
for _,options in ipairs({false,1,"invalid"}) do
    local v,e=isolated:Run("bad",function() end,options);assert(not v and e.code=="INVALID_SCHEMA")
    v,e=isolated:Cache("bad",options);assert(not v and e.code=="INVALID_SCHEMA")
end
local factory=C_Timer.NewTimer
for _,broken in ipairs({function() error("timer failed") end,function() end}) do
    C_Timer.NewTimer=broken
    for n=1,100 do
        local v,e=isolated:After("failed"..n,0,function() end);assert(not v and e.code=="RESOURCE_UNAVAILABLE")
        v,e=isolated:Run("failed"..n,function() end);assert(not v and e.code=="RESOURCE_UNAVAILABLE")
    end
    assert(isolated:GetDiagnostics().providerResources==0)
end
C_Timer.NewTimer=factory
local taskError
isolated:Run("reschedule",function() coroutine.yield() end,{error=function(e) taskError=e.code end})
C_Timer.NewTimer=function() error("reschedule failed") end
drain();C_Timer.NewTimer=factory
assert(taskError=="RESOURCE_UNAVAILABLE" and isolated:GetDiagnostics().providerResources==0)
local longKey=string.rep("k",96)
assert(isolated:Own(longKey,function() end)):Cancel()
assert(isolated:After(longKey,0,function() end)):Cancel()
local small=assert(isolated:Cache(longKey,{bytes=4}))
assert(small:Set("a","x"));assert(small:Set("a",nil));assert(small:Get("a")==nil)
local shared={leaf=true}
for depth=1,3 do local parent={};for n=1,10 do parent[n]=shared end;shared=parent end
local visits=0
canaccessvalue=function() visits=visits+1;return true end
local v,e=settings:Set("oversized-graph",shared)
canaccessvalue=nil
assert(not v and e.code=="DATA_LIMIT" and visits<300,"reject during copy, before exponential expansion")

-- Disable callbacks can start a new generation; only old resources are stopped.
local starts,stops=0,{}
local restart=definition("test.restart")
restart.onEnable=function(h)
    starts=starts+1;local generation=starts
    if generation==1 then h:Resources():Own("restart",function() h:SetAvailability(true) end) end
    return function() stops[generation]=(stops[generation] or 0)+1 end
end
local restarting=assert(Fixture:Register(restart))
restarting:SetAvailability(false)
assert(restarting:GetState().enabled and starts==2 and stops[1]==1 and not stops[2])
restarting:SetAvailability(false);assert(stops[2]==1)

-- Old reply cleanup searches again; a subsequent old error cannot erase it.
local query=definition("test.reentrant-query")
local latest,turn= nil,0
local request={normalized="result",filter={sourceID=query.id..":records"}}
query.query=function(_,reply,context)
    turn=turn+1
    if turn==1 then
        context.resources:Own("next",function() latest=I.Providers:Search(request,{}) end)
        reply({{id="old",title="Old result"}})
        error("old callback failed after reply")
    else reply({{id="new",title="New result"}}) end
end
local reentrant=assert(Fixture:Register(query))
I.Providers:Search(request,{})
assert(latest and #latest==1 and latest[1].id=="new" and I.Providers:IsCurrent(latest[1]))
reentrant:Unregister()
local unavailable=definition("test.no-resources")
local entered=0
unavailable.query=function() entered=entered+1 end
local full=assert(Fixture:Register(unavailable))
local fullScope=assert(full:Resources())
for n=1,64 do assert(fullScope:Own("slot"..n,function() end)) end
I.Providers:Search({normalized="",filter={sourceID=unavailable.id..":records"}},{})
assert(entered==0 and full:GetState().lastError.code=="RESOURCE_LIMIT" and not I.Providers:HasPendingQuery())
full:SetAvailability(false);full:SetAvailability(true)
C_Timer.NewTimer=function() error("deadline unavailable") end
I.Providers:Search({normalized="",filter={sourceID=unavailable.id..":records"}},{})
C_Timer.NewTimer=factory
assert(entered==1 and full:GetState().lastError.code=="RESOURCE_UNAVAILABLE" and not I.Providers:HasPendingQuery())
full:Unregister()

-- Published SDK example runs without accessing private Host modules.
local example=assert(dofile("lychee-sdk/examples/ManagedProvider.lua")(Lychee,"example.managed",{{id="demo",title="Demo"}},openSettings()))
assert(not example:GetState().lastError,"published example must enable without callback errors")
local rows
I.Providers:Search({normalized="demo",filter={sourceID="example.managed:records"}},{},function(value) rows=value end)
drain();assert(rows and #rows==1 and rows[1].id=="demo")
example:SetAvailability(false);assert(example:GetDiagnostics().providerResources==0)
assert(example:Unregister())
-- Retention gate uses a drained external timer queue, separately from allocations.
local function cycle()
    local resources=assert(I.Resources:Create(nil,nil,isolated))
    resources:After("work",0,function() end)
    I.Resources:Close(resources,"test")
    drain()
end
for n=1,20 do cycle() end
collectgarbage("collect")
local retainedBefore=collectgarbage("count")
local framesBefore=#frames
for n=1,1000 do cycle() end
collectgarbage("collect")
local growth=collectgarbage("count")-retainedBefore
assert(growth<64 and #frames==framesBefore,"1000 scope cycles retain <64 KiB and create no frame")
assert(isolated:GetDiagnostics().providerResources==1,"only explicitly retained cache remains")
fresh:SetAvailability(false)
assert(isolated:GetDiagnostics().providerResources==0 and not next(hub.events) and hub.OnEvent==nil)
print(string.format("Managed lifecycle 1000 cycles: retained_growth_kib=%.3f, new_frames=0, resources_after_disable=0",growth))
print("SDK managed resources PASS: replace/late/reentry/event/query/view/disable/quota/settings/cache/identity")
