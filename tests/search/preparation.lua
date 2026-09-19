-- Real public SDK, ProviderRuntime, preparation, query and Session lifecycle.
local Runtime=dofile("tests/support/runtime.lua")
local function setup(packages)
    _G.LycheeInternal,_G.Lychee,_G.LycheeDB,_G.LycheeCharacterDB,_G.TestPackages=nil,nil,nil,nil,nil
    local env={clock=0,timers={},frames={},errors={},loads={},background=0}
    packages=packages or {}
    local map={Lychee={name="Lychee",loaded=true,metadata={}}}
    for _,row in ipairs(packages) do map[row.name]=row end
    function GetTimePreciseSec() return env.clock end
    function GetLocale() return "enUS" end
    function GetBuildInfo() return "12.1.0","70000","today",120100 end
    function UnitGUID() return "Player-1-ABC" end
    function InCombatLockdown() return false end
    function geterrorhandler() return function(message) env.errors[#env.errors+1]=message end end
    function CreateFrame()
        local frame={events={}}
        function frame:RegisterEvent(event) self.events[event]=true end
        function frame:UnregisterEvent(event) self.events[event]=nil end
        function frame:SetScript(event,callback) self[event]=callback end
        function frame:Hide() self.shown=false end
        function frame:Show() self.shown=true end
        env.frames[#env.frames+1]=frame;return frame
    end
    C_Timer={NewTimer=function(delay,callback)
        local timer={due=env.clock+delay,callback=callback}
        function timer:Cancel() self.cancelled=true end
        env.timers[#env.timers+1]=timer;return timer
    end}
    C_AddOns={GetNumAddOns=function() return #packages end,
        GetAddOnInfo=function(value) local row=type(value)=="number" and packages[value] or map[value];return row and row.name end,
        GetAddOnMetadata=function(name,key) return map[name] and map[name].metadata[key] end,
        GetAddOnEnableState=function() return 2 end,IsAddOnLoadable=function() return true end,
        IsAddOnLoaded=function(name) return map[name] and map[name].loaded or false,map[name] and map[name].loaded or false end}
    Runtime.Load("provider",{"Core/Preparation.lua","PublicAPI/Preparation.lua","Search/SearchSession.lua","Core/UserPreferences.lua"})
    local I=LycheeInternal
    function env:Event(event,name)
        local snapshot={};for _,frame in ipairs(self.frames) do if frame.events[event] then snapshot[#snapshot+1]=frame end end
        for _,frame in ipairs(snapshot) do if frame.OnEvent then frame.OnEvent(frame,event,name) end end
    end
    function env:Advance(value)
        self.clock=value
        local timers=self.timers;self.timers={}
        for _,timer in ipairs(timers) do
            if not timer.cancelled and timer.due<=value then timer.fired=true;timer.callback()
            elseif not timer.cancelled then self.timers[#self.timers+1]=timer end
        end
    end
    function env:Register(id,prepare,query,extra)
        local definition={id=id,title=id,apiVersion="1.0.0",version="1",scope={products={"retail"}},i18n={enUS={}},prepare=prepare,
            query=query or function(request,reply) assert(reply({{entry={id="entry",title=request.raw},confidence=1}})) end}
        for key,value in pairs(extra or {}) do definition[key]=value end
        local handle,err=Lychee:RegisterProvider(definition);assert(handle,err and err.code);return handle
    end
    function C_AddOns.LoadAddOn(name)
        env.loads[name]=(env.loads[name] or 0)+1;map[name].loaded=true
        env:Register(map[name].id,map[name].prepare,nil,{addon=name,scope={products={"retail"},minInterface=120100,maxInterface=120199,minBuild=1,maxBuild=9999999},
            searchGlobal=false,searchPrefixes={map[name].prefix},resolve=function(id) return {id=id,title="Restored "..id} end,
            onEnable=function() env.background=env.background+1 end,onDisable=function() env.background=env.background-1 end})
        env:Event("ADDON_LOADED",name);return true
    end
    env:Event("PLAYER_LOGIN")
    assert(Lychee:IsReady())
    env.palette={visible=true,home=true,refreshes=0,publications={}}
    function env.palette:ApplySearchState(_,_,pending,items,incomplete)
        self.pending=pending
        if items then self.publications[#self.publications+1]={items=items,pending=pending,incomplete=incomplete} end
        return true
    end
    function env.palette:IsHomeVisible() return self.home end
    function env.palette:MarkHomeDirty() self.refreshes=self.refreshes+1 end
    I.Search.Session:BindPalette(env.palette);I.Search.Session:Start()
    return I,env
end
local function inactive(I,env)
    I.Search.Session:Stop("close")
    for _,timer in ipairs(env.timers) do assert(timer.cancelled or timer.fired,"active timer after closure") end
    assert(I.Preparation.requestCount==0 and not I.Preparation.timer)
    for _,slots in pairs(I.Preparation.jobs) do for _,job in pairs(slots) do assert(job.status=="ready" and not job.resources and not job.context and not job.cleanup) end end
    assert(#env.errors==0,env.errors[1])
end

local I,env=setup()
env:Register("prep.none")
local timerCount=#env.timers
local ready
assert(Lychee.SDK.Preparation:Ensure({"prep.none"},{},5,function(result) ready=result.ready["prep.none"] end))
assert(ready and #env.timers==timerCount,"no-prepare providers are synchronous and create no deadline timer")
inactive(I,env)

I,env=setup()
local calls,cleanup,reply,context=0,0
local handle=env:Register("prep.shared",function(value,complete)
    calls=calls+1;context=value;reply=complete
    assert(value.product=="retail" and value.locale=="enUS" and value.publicscope=="search" and value.resources)
    return function() cleanup=cleanup+1 end
end)
local warm,query
local warmToken=I.Preparation:Ensure({"prep.shared"},{scope="search",intent="prewarm"},3,function(result) warm=result end)
env:Advance(0);assert(calls==1)
env.clock=1
I.Preparation:Ensure({"prep.shared"},{scope="search",intent="query"},5,function(result) query=result end)
assert(calls==1 and context.deadline==5,"real query joins the same work and retains an independent deadline")
warmToken:Cancel();assert(cleanup==0 and not warm)
assert(reply({status="ready"}));assert(query.ready["prep.shared"] and cleanup==1)
assert(not reply({status="ready"}),"reply completes at most once")
I.Preparation:Ensure({"prep.shared"},{scope="search"},5,function(result) assert(result.ready["prep.shared"]) end)
assert(calls==1,"ready credential reuses the same provider revision and scope")
assert(handle:Invalidate())
I.Preparation:Ensure({"prep.shared"},{scope="search"},5,function() end);assert(calls==2)
assert(reply({status="ready"}));assert(handle:Unregister());assert(not I.Preparation.jobs["prep.shared"])
inactive(I,env)

I,env=setup();calls=0
env:Register("prep.deadline",function(_,complete) calls=calls+1;reply=complete end)
local first,second
I.Preparation:Ensure({"prep.deadline"},{},1,function(result) first=result end)
I.Preparation:Ensure({"prep.deadline"},{},4,function(result) second=result end)
env:Advance(1)
assert(first.failed["prep.deadline"]=="PREPARATION_TIMEOUT" and not second and calls==1)
assert(reply({status="ready"}));assert(second.ready["prep.deadline"])
inactive(I,env)

I,env=setup();calls=0
local replies={}
env:Register("prep.scope",function(value,complete) calls=calls+1;replies[value.publicscope]=complete end)
I.Preparation:Ensure({"prep.scope"},{scope="search"},5,function() end)
I.Preparation:Ensure({"prep.scope"},{scope="restore",intent="visible"},5,function() end)
assert(calls==2);replies.search({status="ready"});replies.restore({status="ready"})
inactive(I,env)

I,env=setup();calls=0;cleanup=0
env:Register("prep.cancel",function(_,complete) calls=calls+1;reply=complete;return function() cleanup=cleanup+1 end end)
local cancelled=I.Preparation:Ensure({"prep.cancel"},{},5,function() error("cancelled subscriber") end)
cancelled:Cancel();assert(cleanup==1 and not reply({status="ready"}) and not I.Preparation.jobs["prep.cancel"])
inactive(I,env)

I,env=setup();calls=0;replies={}
for index=1,4 do env:Register("prep.low"..index,function(_,complete) calls=calls+1;replies[index]=complete end) end
local low=I.Preparation:Ensure({"prep.low1","prep.low2","prep.low3","prep.low4"},{intent="prewarm"},5,function() end)
env:Advance(0);assert(calls==2,"optional prewarm starts at most two asynchronous jobs")
replies[1]({status="ready"});env:Advance(0);assert(calls==3)
low:Cancel();inactive(I,env)

I,env=setup()
local prepared,queried=0,0
env:Register("prep.route",function(_,complete) prepared=prepared+1;reply=complete end,function(_,complete) queried=queried+1;complete({}) end,
    {searchGlobal=false,searchPrefixes={"route"}})
env:Register("prep.other",function() error("non-participating preparation") end,nil,{searchGlobal=false,searchPrefixes={"other"}})
env.palette.home=false
local q,s=I.Search.Query,I.Search.Session
assert(s:Input("route: desired"));env:Advance(0.04)
assert(prepared==1 and queried==0 and I.Search.SourceAccess:IsPending() and env.palette.pending)
env.clock=3;reply({status="ready"});env:Advance(3);assert(queried==1 and not env.palette.pending)
inactive(I,env)

local function cold(name,id,prefix)
    return {name=name,id=id,prefix=prefix,metadata={["X-Lychee-Protocol"]="1",["X-Lychee-Package"]=name,["X-Lychee-Providers"]=id,
        ["X-Lychee-Provider-"..id]="title="..id..";global=0;prefixes="..prefix..";ranges=retail:120100:120199:1:9999999;requires=Lychee"}}
end
I,env=setup()
local searchReply,searchContext
env:Register("prep.total",function(_,complete) reply=complete end,function(_,complete,context) searchReply=complete;searchContext=context end)
env.palette.home=false
I.Search.Session:Input("total deadline");env:Advance(0.04)
env.clock=4.9;reply({status="ready"});env:Advance(4.9)
assert(searchReply and searchContext.deadline==5,"preparation and query retain the input's original deadline")
env:Advance(5)
assert(not env.palette.pending and I.Search.Session.incomplete and not searchReply({}),"late query completion cannot extend preparation's total deadline")
inactive(I,env)

I,env=setup({cold("Visible_Lychee","visible.ref","visible"),cold("Hidden_Lychee","hidden.ref","hidden")})
I.CharacterStore:DisabledProviders()["visible.ref"]=true
local visible={providerID="visible.ref",entryID="favorite"}
local hidden={providerID="hidden.ref",entryID="offscreen"}
I.Search.Session:HomeReferences({visible})
env:Advance(0)
assert(env.loads.Visible_Lychee==1 and not env.loads.Hidden_Lychee,"only currently visible stable refs load")
assert(I.Search.Session:GetHomeItem(visible),"explicit visible reference restores even when search is off")
assert(env.background==1 and env.palette.refreshes==1)
I.Search.Session:Stop("closed")
assert(env.background==1,"closing the palette must preserve provider background lifetime")
assert(not I.Search.Session:GetHomeItem(visible))
env:Advance(5);inactive(I,env)

I,env=setup({cold("Visible_Lychee","visible.ref","visible")})
local pending
env:Register("prep.background",function(_,complete) pending=complete end,nil,{onEnable=function() env.background=env.background+1 end})
I.Search.Session:HomeReferences({});env:Advance(0)
assert(pending and I.Preparation.requestCount==1)
I.Search.Session:Stop("closed");assert(not pending({status="ready"}) and env.background==1)
inactive(I,env)
I,env=setup()
local owner,terminal
owner=env:Register("prep.cleanup",function(_,complete)
    reply=complete
    return function() owner:Invalidate() end
end)
I.Preparation:Ensure({"prep.cleanup"},{},5,function(result) terminal=result end)
reply({status="ready"})
assert(terminal.failed["prep.cleanup"]=="STALE_PREPARATION" and not terminal.ready["prep.cleanup"],"cleanup invalidation cannot publish stale ready")
inactive(I,env)

I,env=setup();calls=0;replies={}
for index=1,3 do env:Register("prep.demote"..index,function(_,complete) calls=calls+1;replies[index]=complete end) end
local queryToken=I.Preparation:Ensure({"prep.demote1"},{},5,function() end)
local optional=I.Preparation:Ensure({"prep.demote1","prep.demote2","prep.demote3"},{intent="prewarm"},5,function() end)
env:Advance(0);assert(calls==3)
queryToken:Cancel()
local activeOptional=0
for _,slots in pairs(I.Preparation.jobs) do for _,job in pairs(slots) do if job.status=="active" and job.priority==3 then activeOptional=activeOptional+1 end end end
assert(activeOptional<=2,"leaving a shared query cannot expand optional concurrency")
optional:Cancel();inactive(I,env)

I,env=setup()
local outer=I.Search.Query.operation or 0
local cancellations=0
I.Invocations={CancelSearch=function()
    cancellations=cancellations+1
    assert(I.Search.Query.operation>outer,"query identity must expire before invocation cleanup")
end}
I.Search.Session:Input("replacement");I.Search.Session:Stop("hidden")
assert(cancellations>=2,"input and hiding cancel pending search-bound invocation preparation")
inactive(I,env)

for _,transition in ipairs({"input","close"}) do
    I,env=setup()
    dofile("addon/Lychee/Core/InvocationRuntime.lua")
    dofile("addon/Lychee/PublicAPI/Invocation.lua")
    local restoreReply,writes,restoreCancelled=nil,0,0
    env:Register("prep.history",nil,nil,{
        resolveTarget=function(_,_,complete) restoreReply=complete;return function() restoreCancelled=restoreCancelled+1 end end,
        actions={set={title="Set",actionVersion=1,schema={},run=function() writes=writes+1;return {status="succeeded"} end}},
    })
    I.CharacterStore:DisabledProviders()["prep.history"]=true
    local ref={kind="invocation",product="retail",providerID="prep.history",actionID="set",actionVersion=1,target={version=1,key={id=1}},args={}}
    I.Search.Session:HomeReferences({ref})
    assert(restoreReply and not I.Search.Session:GetHomeItem(ref),"explicit concrete reference starts asynchronous target preparation while search is off")
    if transition=="input" then env.palette.home=false;I.Search.Session:Input("replacement") else I.Search.Session:Stop("hidden") end
    local refreshes=env.palette.refreshes
    assert(not restoreReply({status="ready",target=ref.target,identity="1"}))
    env:Advance(0.04)
    assert(restoreCancelled==1 and writes==0 and not I.Search.Session:GetHomeItem(ref) and env.palette.refreshes==refreshes,"late concrete history restoration cannot publish or execute after cancellation")
    inactive(I,env)
end

I,env=setup()
Lychee.UI={Theme={Metrics={rowHeight=40}}}
dofile("addon/Lychee/UI/HomeView.lua")
local view=setmetatable({scroll=80,sections={{}},tiles={},frame={GetHeight=function() return 80 end,IsShown=function() return true end}},Lychee.UI.HomeView)
for index=1,5 do view.tiles[index]={section={pinnedRef={providerID="viewport",entryID=tostring(index)}},_demandTop=(index-1)*40,_demandHeight=40} end
local refs=view:GetVisibleReferences(20)
assert(#refs==2 and refs[1].entryID=="3" and refs[2].entryID=="4","viewport intersects only displayed stable references")
assert(view:HasPresentation())
view.scroll=0;view.frame.GetHeight=function() return 10000 end
for index=6,30 do view.tiles[index]={section={pinnedRef={providerID="viewport",entryID=tostring(index)}},_demandTop=(index-1)*40,_demandHeight=40} end
assert(#view:GetVisibleReferences(100)==20,"viewport demand keeps the host reference bound")
inactive(I,env)

-- Only current visible references retain scalar status; failed visual recovery
-- neither erases persisted references nor retries on an unchanged viewport.
local categories={
    {"ADDON_DISABLED","disabled","Addon disabled"},
    {"UNKNOWN_PROVIDER","missing","Provider not found"},
    {"deleted","deleted","Target deleted"},
    {"INCOMPATIBLE_ACTION_VERSION","incompatible","Incompatible version"},
    {"LOAD_TIMEOUT","timeout","Restore timed out; reopen to retry"},
    {"DEPENDENCY_MISSING","dependency","Dependency unavailable"},
    {"temporarilyUnavailable","unavailable","Target unavailable"},
    {"UNKNOWN_BUSINESS_ERROR","failed","Restore failed; reopen to retry"},
}
for _,case in ipairs(categories) do
    I,env=setup()
    dofile("addon/Lychee/Locales/UI.enUS.lua")
    Lychee.UI={Theme={Metrics={rowHeight=40}}};dofile("addon/Lychee/UI/HomeView.lua")
    local ref={providerID="restore.failed",entryID="saved",title="Original title"}
    local count=0
    I.AddonLoader.Ensure=function(_,_,deadline,callback)
        count=count+1;assert(deadline==5)
        callback({ready={},failed={[ref.providerID]=case[1]}})
        return {Cancel=function() end}
    end
    I.Search.Session:HomeReferences({ref});env:Advance(0)
    assert(I.Search.Session:GetHomeStatus(ref)==case[2])
    assert(Lychee.UI.HomeView:GetRecoveryText(ref)==case[3])
    assert(not I.Search.Session:GetHomeItem(ref) and ref.entryID=="saved" and ref.title=="Original title")
    I.Search.Session:HomeReferences({ref});assert(count==1,"terminal failure must not retry on repaint")
    I.Search.Session:Stop("character-changed");assert(not I.Search.Session.homeStatus)
    I.Search.Session:Start();I.Search.Session:HomeReferences({ref});assert(count==2,"new visible session may retry")
    inactive(I,env)
end
I,env=setup()
dofile("addon/Lychee/Locales/UI.enUS.lua")
Lychee.UI={Theme={Metrics={rowHeight=40}}};dofile("addon/Lychee/UI/HomeView.lua")
local ref={providerID="restore.wait",entryID="saved"}
local late
I.AddonLoader.Ensure=function(_,_,_,callback) late=callback;return {Cancel=function() end} end
I.Search.Session:HomeReferences({ref})
assert(I.Search.Session:GetHomeStatus(ref)=="pending" and Lychee.UI.HomeView:GetRecoveryText(ref)=="Restoring…")
I.Search.Session:Stop("hidden")
late({ready={},failed={[ref.providerID]="ADDON_DISABLED"}})
assert(not I.Search.Session:GetHomeStatus(ref) and not I.Search.Session.homeRefresh,"late failure cannot restore old status")
inactive(I,env)

I,env=setup()
local latePreparation
env:Register("restore.timeout",function(_,complete) latePreparation=complete end,nil,{resolve=function(id) return {id=id,title=id} end})
ref={providerID="restore.timeout",entryID="saved"}
I.Search.Session:HomeReferences({ref});assert(I.Search.Session:GetHomeStatus(ref)=="pending")
env:Advance(5)
assert(I.Search.Session:GetHomeStatus(ref)=="timeout" and not I.Search.Session:GetHomeItem(ref))
latePreparation({status="ready"});assert(not I.Search.Session:GetHomeItem(ref))
inactive(I,env)

I,env=setup()
dofile("addon/Lychee/Core/InvocationRuntime.lua");dofile("addon/Lychee/PublicAPI/Invocation.lua")
local lateTarget
env:Register("restore.deleted",nil,nil,{
    resolveTarget=function(_,_,complete) lateTarget=complete end,
    actions={set={title="Set",actionVersion=1,schema={},run=function() error("restore is read-only") end}},
})
ref={kind="invocation",product="retail",providerID="restore.deleted",actionID="set",actionVersion=1,target={version=1,key={id=1}},args={}}
I.Search.Session:HomeReferences({ref});assert(I.Search.Session:GetHomeStatus(ref)=="pending")
lateTarget({status="deleted"})
assert(I.Search.Session:GetHomeStatus(ref)=="deleted" and not I.Search.Session:GetHomeItem(ref))
inactive(I,env)

I,env=setup()
dofile("addon/Lychee/Core/InvocationRuntime.lua");dofile("addon/Lychee/PublicAPI/Invocation.lua")
local observed,parsed
env:Register("offset.demo",nil,function(request,complete)
    observed=request
    parsed=assert(Lychee.SDK.Invocation:ParsePatterns(request.raw,{{{slot="percent"},"%"}},
        {percent={type="integer",min=0,max=100,required=true}},request.rawOffset))
    complete({})
end,
    {searchGlobal=true,searchPrefixes={"gear","装备"},searchKeywords={"status"}})
for _,sample in ipairs({
    {"gear:-1%","-1%",5},
    {"装备：-1%","-1%",9},
    {"  装备： -1%"," -1%",11},
    {"-1%","-1%",0},
    {"status","",6},
}) do
    observed=nil
    I.Search.Query:Query(sample[1],{visible=true})
    assert(observed and observed.raw==sample[2] and observed.rawOffset==sample[3] and observed.originalRaw==sample[1],"public request must retain byte-exact original route coordinates")
    assert(observed.originalRaw:sub(observed.rawOffset+1)==observed.raw)
    if observed.raw~="" then
        assert(parsed.status=="invalid" and parsed.rawOffset==sample[3] and parsed.originalSpans.percent)
        local span=parsed.originalSpans.percent
        assert(observed.originalRaw:sub(span.start,span.finish)==observed.raw:sub(1,-2),"invalid negative input must point to its original UTF-8 byte slice")
    end
end
inactive(I,env)

-- Missing discovery APIs must not suppress preparation of loaded Providers.
I,env=setup()
C_AddOns.GetNumAddOns=nil
local preparedMissing,queriedMissing=0,0
env:Register("prep.no-discovery-api",function(_,complete) preparedMissing=preparedMissing+1;complete({status="ready"}) end,
    function(_,complete) queriedMissing=queriedMissing+1;complete({}) end)
I.Search.Query:Query("loaded",{visible=true})
assert(preparedMissing==1 and queriedMissing==1)
inactive(I,env)

-- Static entries remain immediately searchable without any async facilities.
I,env=setup()
C_Timer=nil;C_AddOns=nil
assert(Lychee:RegisterProvider({id="static.offline",apiVersion="1.0.0",version="1",title="Static",
    entries={{id="instant",title="instant fixture"}}}))
local _,instant=I.Search.Query:Query("instant",{visible=true})
assert(#instant==1 and instant[1].id=="instant" and not I.Search.SourceAccess:IsPending())
inactive(I,env)

-- Rejection without a completion callback must become a terminal partial result.
I,env=setup()
env:Register("prep.rejected",function() end)
I.Preparation.Ensure=function() return nil,{code="RESOURCE_LIMIT"} end
I.Search.Query:Query("rejected",{visible=true})
assert(not I.Search.SourceAccess:IsPending() and I.Search.SourceAccess:HasFailure())
assert(I.Search.SourceAccess.failures["prep.rejected"]=="RESOURCE_LIMIT")
inactive(I,env)

I,env=setup()
I.AddonDiscovery.Scan=function(_,complete) complete({error="DISCOVERY_UNAVAILABLE"});return {Cancel=function() end} end
I.Search.Query:Query("discovery failure",{visible=true})
assert(not I.Search.SourceAccess:IsPending() and I.Search.SourceAccess:HasFailure())
inactive(I,env)

-- Source preparation is shared across partial publications of the same input.
I,env=setup()
local readyFast,readySlow,slowCalls,slowCancels=nil,nil,0,0
env:Register("prep.fast",function(_,complete) readyFast=complete end)
env:Register("prep.slow",function(_,complete)
    slowCalls=slowCalls+1;readySlow=complete
    return function() slowCancels=slowCancels+1 end
end)
I.Search.Session:Input("progressive");env:Advance(0.04)
assert(readyFast and readySlow)
readyFast({status="ready"});env:Advance(0.05)
assert(slowCalls==1 and slowCancels==0,"partial publication must not restart slow preparation")
assert(env.palette.pending and #I.Search.Query.last.results==1,"ready result publishes while another source prepares")
readySlow({status="ready"});env:Advance(0.06)
assert(not env.palette.pending and #I.Search.Query.last.results==2)
inactive(I,env)

-- Cancellation in either access or invocation may schedule a newer input.
for _,owner in ipairs({"SourceAccess","Invocations"}) do
    for _,operation in ipairs({"Query","Schedule","Cancel"}) do
        I,env=setup()
        local Q=I.Search.Query
        local target=owner=="SourceAccess" and I.Search.SourceAccess or {CancelSearch=function() end}
        if owner=="Invocations" then I.Invocations=target end
        local method=owner=="SourceAccess" and "Cancel" or "CancelSearch"
        local original,armed=target[method],true
        target[method]=function(self,...)
            original(self,...)
            if armed then armed=false;Q:Schedule("newest",{visible=true},9,function() end,1) end
        end
        if operation=="Cancel" then Q:Cancel("older",1)
        elseif operation=="Schedule" then Q:Schedule("older",{visible=true},1,function() end,1)
        else Q:Query("older",{visible=true},1,function() end) end
        assert(Q.pending and Q.pending.raw=="newest" and Q.timer and not Q.timer.cancelled,owner.." "..operation.." overwrote newer work")
        target[method]=original
        inactive(I,env)
    end
end

for _,locale in ipairs({"zhCN","zhTW","enUS","enGB"}) do
    _G.LycheeInternal=nil;CreateFrame=nil;GetLocale=function() return locale end
    dofile("addon/Lychee/Bootstrap.lua");dofile("addon/Lychee/Locales/UI.enUS.lua")
    local L=LycheeInternal.Locale
    assert(L["目标已删除"]==((locale=="zhCN" or locale=="zhTW") and "目标已删除" or "Target deleted"))
end
print("preparation: shared work, deadlines, scope/revision, bounded prewarm, query, viewport and cancellation reentry passed")
