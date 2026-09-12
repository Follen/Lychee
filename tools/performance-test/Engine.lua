-- Native file factories are compiled by the TOC; no source strings or loadstring.
local _, carrier = ...
function carrier.Run(nativeLoadMs)
local bundle=carrier.modules
local G=_G
if type(G.LycheePerformanceTestDB)~="table" then return {status="blocked",reason="Diagnostic database unavailable"} end
if G.LycheePerformanceTestControl then return {status="blocked",reason="A study is already running"} end
if InCombatLockdown() then return {status="blocked",reason="Leave combat before starting"} end
if GetLocale()~="zhCN" or not C_Timer or type(C_Timer.NewTimer)~="function" or type(getfenv)~="function" or type(setfenv)~="function" then return {status="blocked",reason="Expected zhCN Retail Lua APIs"} end
local clock=debugprofilestop
local liveI=G.LycheeInternal
if not liveI or not liveI.Search or not liveI.Search.StaticIndex or not liveI.Providers then return {status="blocked",reason="Lychee is unavailable or not initialized"} end
local liveIndex=liveI.Search.StaticIndex
local liveP=liveI.Providers.entries
local liveDB,liveCharacterDB=G.LycheeDB,G.LycheeCharacterDB
local start=clock()
local wallLimitSeconds=600
local id="LYCHEE-PERF-"..tostring(time())
local store=G.LycheePerformanceTestDB.reports
if type(store)~="table" or store[id] then return {status="blocked",reason="Study storage collision"} end
local stored=0;for _ in pairs(store) do stored=stored+1 end
if stored>=8 then return {status="blocked",reason="Eight study reports retained; no automatic deletion"} end
local version,build,buildDate,interface=GetBuildInfo()
local report={schema="lychee.lifecycle-study.v1",id=id,status="running",sourceCommit=carrier.sourceCommit,sourceDirty=carrier.sourceDirty,sourceTreeHash=carrier.sourceTreeHash,nativeLoadMs=tonumber(nativeLoadMs),
    client={version=version,build=build,buildDate=buildDate,interface=interface,locale=GetLocale()},
    phases={},rounds={},coverage={},memory={},uncovered={
        "Client restart / truly unloaded first open cannot be recreated in this loaded session",
        "Game-internal API caches are not flushed; first sample is first probe sample only",
        "Combat, hardware Alt+Space/Esc dispatch, visual smoothness and every upstream settings page require separate interaction",
        "Network refresh, new permanent diagnostic hooks and business actions are suppressed; normal Ellesmere settings preparation is separately recorded",
        "Private fake-frame memory is not native UI memory; private heap deltas are not addon-accounted total residency",
        "SDK 3, compact representation and final dormant architecture do not exist yet; this is baseline feasibility evidence"}}
store[id]=report
report.carrierRevision="0.3.1-compact-search"
report.wallLimitSeconds=wallLimitSeconds
report.scheduler={requestedWaitMs=0,actualWaitMs=0,maxOvershootMs=0,wakeups=0,resumeMs=0}
report.diagnosticStatusUI={frames=1,fontStrings=2,scope="Reusable inert overlay created before baseline; included in diagnostic addon counters"}
local control={report=report};G.LycheePerformanceTestControl=control
local E,I,roots,queue,ownedUI,uiController
local upstreamCleanup,upstreamOptions
local aggregate={activeMs=0,maxCallMs=0,calls=0}
report.activity=aggregate
local currentPhase="preflight"
local profiling=false
local profileStack={}
report.profile={}
local function pack(...) return {n=select('#',...),...} end
local function count(t,limit)
    local n=0;for _ in pairs(t or {}) do n=n+1;if n>(limit or 20000) then error("table limit") end end;return n
end
local function timed(fn,...)
    local begin=clock();local result=pack(pcall(fn,...));local elapsed=clock()-begin
    report.observedHeapHighKiB=math.max(report.observedHeapHighKiB or 0,collectgarbage("count"))
    aggregate.activeMs=aggregate.activeMs+elapsed;aggregate.maxCallMs=math.max(aggregate.maxCallMs,elapsed);aggregate.calls=aggregate.calls+1
    local phase=report.phases[currentPhase] or {activeMs=0,maxCallMs=0,calls=0};report.phases[currentPhase]=phase
    phase.activeMs=phase.activeMs+elapsed;phase.maxCallMs=math.max(phase.maxCallMs,elapsed);phase.calls=phase.calls+1
    if not result[1] then error(result[2]) end
    return unpack(result,2,result.n)
end
local function wrap(object,key,label)
    local original=object and object[key]
    if type(original)~="function" then return end
    object[key]=function(...)
        if not profiling then return original(...) end
        local parent=profileStack[#profileStack];local node={children=0};profileStack[#profileStack+1]=node
        local begin=clock();local result=pack(pcall(original,...));local elapsed=clock()-begin
        profileStack[#profileStack]=nil;if parent then parent.children=parent.children+elapsed end
        local phase=report.profile[currentPhase] or {};report.profile[currentPhase]=phase
        local m=phase[label] or {exclusiveMs=0,calls=0,maxInclusiveMs=0};phase[label]=m
        m.exclusiveMs=m.exclusiveMs+elapsed-node.children;m.calls=m.calls+1;m.maxInclusiveMs=math.max(m.maxInclusiveMs,elapsed)
        if not result[1] then error(result[2]) end
        return unpack(result,2,result.n)
    end
end
local function pause(seconds) coroutine.yield(seconds or 0.01) end
local function shallow(t) local out={};for key,value in pairs(t or {}) do out[key]=value end;return out end
local function hash(value)
    local h,n,seen=0,0,{}
    local function add(s) for p=1,#s do h=(h*31+s:byte(p))%2147483647 end end
    local function walk(v,depth)
        n=n+1;if n>300000 or depth>14 then error("fingerprint limit") end
        local kind=type(v);add(kind)
        if kind~="table" then if kind~="function" and kind~="userdata" then add(tostring(v)) end;return end
        if seen[v] then error("fingerprint cycle") end;seen[v]=true
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        for _,key in ipairs(keys) do walk(key,depth+1);walk(v[key],depth+1) end
        seen[v]=nil
    end
    walk(value,0);return h
end
local function heapSample(label)
    currentPhase=label
    local sample={beforeGC=collectgarbage("count")}
    local begin=clock();collectgarbage("collect");sample.globalGCms=clock()-begin
    sample.afterGC=collectgarbage("count")
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        begin=clock();UpdateAddOnMemoryUsage();sample.accountingMs=clock()-begin
        sample.lycheeKiB=GetAddOnMemoryUsage("Lychee")
        sample.diagnosticAddonKiB=GetAddOnMemoryUsage("Lychee Performance Test")
        local ok,value=pcall(GetAddOnMemoryUsage,"Lychee_Runtime");if ok and type(value)=="number" then sample.runtimeCompanionKiB=value end
    end
    report.memory[label]=sample
    return sample
end
local function clearQueue()
    for _,timer in ipairs(queue or {}) do timer.cancelled=true;timer.fn=nil end
    queue={}
end
local function release()
    if not I then return end
    I.Search.Query:Cancel("unified-study")
    local ids={};for providerID in pairs(I.Providers.entries) do ids[#ids+1]=providerID end
    for _,providerID in ipairs(ids) do
        local m
        for _,def in ipairs(I.Builtin.Definitions) do if def.id==providerID then m=I.Builtin[def.module];break end end
        if m and m.handle then m.handle:Unregister();m.handle=nil end
    end
    I.Builtin._initialized=nil
    I.Search.StaticIndex:ClearQueryCache();I.Search.Normalizer:ClearCache()
    clearQueue()
    if count(I.Providers.entries)~=0 or count(I.Search.StaticIndex.entries)~=0 or count(I.Providers.jobs)~=0 then error("private release incomplete") end
end
local finish
local function verifyLive()
    return G.LycheeInternal==liveI and liveI.Search.StaticIndex==liveIndex and liveI.Providers.entries==liveP
        and G.LycheeDB==liveDB and G.LycheeCharacterDB==liveCharacterDB
end
finish=function(status,err)
    if control.finished then return end;control.finished=true
    if control.timer then control.timer:Cancel();control.timer=nil end
    if upstreamCleanup then
        local restored,restoreError=pcall(upstreamCleanup)
        report.upstreamCleanupOK=restored
        if not restored then report.upstreamCleanupError=tostring(restoreError);status="aborted" end
        upstreamCleanup=nil
    end
    local ok,why=pcall(release)
    if ownedUI and not uiController then uiController=liveI.Host and liveI.Host.PaletteController end
    if ownedUI and uiController and not InCombatLockdown() then
        local uiOK,uiError=pcall(uiController.Hide,uiController,"unified-study-finish")
        report.uiCleanupOK=uiOK;if not uiOK then report.uiCleanupError=tostring(uiError) end
    end
    if ownedUI and InCombatLockdown() then report.uiCleanup="Combat began; production combat handler owns protected UI cleanup" end
    report.cleanupOK=ok;report.liveRootsUnchanged=verifyLive();report.elapsedMs=clock()-start
    report.status=status;if not ok then report.cleanupError=tostring(why);report.status="aborted" end
    if not report.liveRootsUnchanged then report.status="aborted";report.liveRootError="Live root replaced during study" end
    if err then report.error=tostring(err) end
    report.lastPhase=currentPhase
    if report.ellesmerePreparation and report.ellesmerePreparation.status=="preparing" then
        report.ellesmerePreparation.status="interrupted";report.ellesmerePreparation.reason=report.status
    end
    report.memory.meaning="GC operates on whole client; private heap deltas include diagnostic and background noise; observed high water is not exact allocation peak"
    report.instructions="Report in LycheePerformanceTestDB.reports["..id.."]. /reload once after completion to flush. Independent SavedVariables; no Lychee Dev required."
    E,I,roots,queue,bundle=nil,nil,nil,nil,nil
    upstreamOptions=nil
    G.LycheePerformanceTestControl=nil
    report.baseline=carrier.CheckBaseline(report)
    carrier.UpdateStatus(report.status, report)
    local euiCheck=report.rounds[1] and report.rounds[1].ellesmereOptionCheck
    print("Lychee Performance Test "..report.carrierRevision.." "..report.status..": "..id.."; EUI="..(euiCheck and euiCheck.status or "not_tested").."; /reload to save")
end
function control:Cancel() finish("cancelled","Cancelled by user") end
local function drain()
    local steps=0
    while true do
        local best,at
        for n,t in ipairs(queue) do
            if not t.cancelled and t.fn and (not best or t.due<best.due) then best,at=t,n end
        end
        if not best then queue={};return end
        steps=steps+1;if steps>6000 then error("private timer limit") end
        local wait=(best.due-clock())/1000
        if wait>0 then pause(math.min(wait,0.05)) end
        if clock()>=best.due then
            table.remove(queue,at);local callback=best.fn;best.fn=nil
            if not best.cancelled then timed(callback) end
            pause(0.001)
        end
    end
end
local function snapshotRecords()
    local out={}
    for providerID,entry in pairs(I.Providers.entries) do
        out[providerID]={count=#entry.records,hash=hash(entry.records)}
    end
    return out
end
local function query(raw)
    local begin=clock();local final
    local _,initial=timed(I.Search.Query.Query,I.Search.Query,raw,{visible=true},nil,function(items) final=items end)
    drain();final=final or initial
    local rows={}
    for n,item in ipairs(final) do rows[n]={id=item.id,stableID=item.stableID,text=item.text,subtext=item.subtext,
        record=item.searchRecord,interaction=item.interaction,payload=item.payload,icon=item.icon,confidence=item.confidence} end
    return {wallMs=clock()-begin,count=#final,hash=hash(rows)},final
end
local routine=coroutine.create(function()
    report.liveBefore={records=count(liveIndex.entries),providers=count(liveP),indexVersion=liveIndex.version}
    report.userStateBefore={character=hash(liveCharacterDB or {})}
    heapSample("live_closed_baseline");pause()
    report.acquisition={rounds={},scope="Real mount API and temporary record construction; batches <=32 records, cooperative 4ms target. This warms mount API caches before Provider rounds."}
    if not G.C_MountJournal or type(G.C_MountJournal.GetMountIDs)~="function" or type(G.C_MountJournal.GetMountInfoByID)~="function" then
        report.acquisition.skipped="Mount APIs unavailable"
    else
        for round=1,3 do
            local sample={acquireAndCaptureMs=0,constructRecordsMs=0,maxBatchMs=0};report.acquisition.rounds[round]=sample
            currentPhase="mount_acquisition_"..round
            local begin=clock();local ids=timed(G.C_MountJournal.GetMountIDs);sample.listMs=clock()-begin
            assert(type(ids)=="table" and #ids<=10000,"mount list invalid or over limit")
            sample.enumerated=#ids
            local captured,records={},{}
            local at=1
            while at<=#ids do
                begin=clock()
                timed(function()
                    local batchStart=clock();local last=math.min(at+31,#ids)
                    while at<=last do
                        local ok,name,spellID,icon,_,_,_,_,_,_,hidden,collected=pcall(G.C_MountJournal.GetMountInfoByID,ids[at])
                        assert(ok and name~=nil,"mount acquisition failed")
                        if collected and not hidden then captured[#captured+1]={ids[at],name,spellID,icon} end
                        at=at+1;if clock()-batchStart>=4 then break end
                    end
                end)
                local ms=clock()-begin;sample.acquireAndCaptureMs=sample.acquireAndCaptureMs+ms;sample.maxBatchMs=math.max(sample.maxBatchMs,ms)
                pause(0.001)
            end
            sample.collectedVisible=#captured;at=1
            currentPhase="mount_construction_"..round
            while at<=#captured do
                begin=clock()
                timed(function()
                    local batchStart=clock();local last=math.min(at+31,#captured)
                    while at<=last do
                        local v=captured[at]
                        records[at]={id="mount:"..tostring(v[1]),title=v[2],kind="mount",kindTitle="坐骑",icon=v[4],
                            subtitle="点击召唤 · 可拖到动作条",payload={mountID=v[1],spellID=v[3]},primaryActionID="summon",
                            actions={{id="summon",title="召唤",kind="secure-spell",spellID=v[3]}},drag={type="spell",spellID=v[3]}}
                        at=at+1;if clock()-batchStart>=4 then break end
                    end
                end)
                local ms=clock()-begin;sample.constructRecordsMs=sample.constructRecordsMs+ms;sample.maxBatchMs=math.max(sample.maxBatchMs,ms)
                pause(0.001)
            end
            sample.records=#records;sample.recordHash=hash(records)
            sample.measuredStagesMs=sample.listMs+sample.acquireAndCaptureMs+sample.constructRecordsMs
            sample.recordsEqualFirst=sample.recordHash==report.acquisition.rounds[1].recordHash
            captured,records,ids=nil,nil,nil;pause()
        end
    end
    currentPhase="private_module_initialize"
    E={LycheeInternal={},Lychee={},LycheeDB={schemaVersion=2,optionalProviderDefaults={},disabledProviders={}},LycheeCharacterDB={}}
    E._G=E;setmetatable(E,{__index=G});roots={};queue={}
    local F={};F.__index=F
    function F:SetScript(k,v) self.scripts[k]=v end
    function F:RegisterEvent(k) self.events[k]=true end
    function F:UnregisterEvent(k) self.events[k]=nil end
    function F:UnregisterAllEvents() for k in pairs(self.events) do self.events[k]=nil end end
    function F:Show() self.shown=true end
    function F:Hide() self.shown=false end
    function F:IsShown() return self.shown end
    E.CreateFrame=function(_,name,parent) local f=setmetatable({scripts={},events={},parent=parent},F);roots[#roots+1]=f;if name then E[name]=f end;return f end
    E.UIParent=E.CreateFrame()
    report.suppressed={}
    local function block(name,value) return function() report.suppressed[name]=(report.suppressed[name] or 0)+1;return value end end
    local function forbid(name) return function() error("Forbidden external action: "..name) end end
    E.SetBinding=forbid("SetBinding");E.SaveBindings=forbid("SaveBindings");E.ReloadUI=forbid("ReloadUI");E.hooksecurefunc=forbid("hooksecurefunc")
    E.C_AddOns=shallow(G.C_AddOns);E.C_AddOns.LoadAddOn=forbid("LoadAddOn")
    E.C_Spell=shallow(G.C_Spell);E.C_Spell.RequestLoadSpellData=block("spellDataRequest")
    E.C_ChatInfo=shallow(G.C_ChatInfo);E.C_ChatInfo.RegisterAddonMessagePrefix=block("addonPrefix",0);E.C_ChatInfo.SendAddonMessage=block("addonMessage",0)
    E.C_MythicPlus=shallow(G.C_MythicPlus);E.C_MythicPlus.RequestMapInfo=block("mapInfoRequest")
    for _,namespace in ipairs({"C_MountJournal","C_Spell","C_SpellBook","C_Container","C_EquipmentSet","C_ClassTalents","C_Traits","C_ChallengeMode","C_PlayerInfo","C_MythicPlus"}) do
        E[namespace]=rawget(E,namespace) or shallow(G[namespace])
        for key,value in pairs(E[namespace]) do if type(value)=="function" and (key:match("^Get") or key:match("^Is")) then wrap(E[namespace],key,"gameGetters") end end
    end
    currentPhase="native_color_preflight"
    assert(carrier.PrepareNativeCalls(E,report),"Native color API preflight failed; see nativeCalls")
    for _,spec in ipairs({{"C_ClassColor","GetClassColor"},{"C_ChallengeMode","GetDungeonScoreRarityColor"},{"C_ChallengeMode","GetSpecificDungeonScoreRarityColor"}}) do
        wrap(E[spec[1]],spec[2],"gameGetters")
    end
    currentPhase="private_module_initialize"
    for _,name in ipairs({"GetCategoryList","GetCategoryNumAchievements","GetAchievementInfo","GetAchievementCategory","GetAchievementNumCriteria","GetAchievementCriteriaInfo"}) do
        E[name]=G[name];wrap(E,name,"gameGetters")
    end
    E.C_Timer={NewTimer=function(delay,fn)
        if #queue>8000 then error("queue limit") end
        local t={due=clock()+delay*1000,fn=fn};function t:Cancel() self.cancelled=true;self.fn=nil end
        queue[#queue+1]=t;return t
    end}
    E.C_Timer.After=function(delay,fn) E.C_Timer.NewTimer(delay,fn) end
    report.sourceFiles=#bundle
    for _,file in ipairs(bundle) do
        timed(function()
            local fn=file[2];local previous=getfenv(fn)
            setfenv(fn,E)
            local ok,why=pcall(fn,"LycheePerformanceTestPrivate")
            setfenv(fn,previous)
            if not ok then error(why) end
        end)
        if file[1]=="Builtin/Ellesmere/Adapter.lua" then
            local adapter=E.LycheeInternal.Builtin.EllesmereAdapter
            adapter.Observe=block("ellesmerePermanentHook")
            adapter.Ready=function()
                local eui=G.EllesmereUI
                if not eui then return nil,"请先启用 Ellesmere UI" end
                if not eui._deferredLoaded or type(eui._modules)~="table" then return nil,"Ellesmere UI 设置暂不可用" end
                return eui
            end
        end
        pause(0.001)
    end
    bundle=nil;I=E.LycheeInternal
    assert(I~=liveI and I.Search.StaticIndex~=liveIndex and I.Providers.entries~=liveP,"private isolation failure")
    heapSample("private_code_only");pause()
    currentPhase="ellesmere_prepare"
    local captureOwner={active=true,hooked=G.EllesmereUI,options={},optionCount=0,optionBytes=0,Capture=I.Builtin.Ellesmere.Capture}
    carrier.PrepareEllesmere({report=report,timed=timed,pause=pause,
        capture=function(...) captureOwner:Capture(G.EllesmereUI,...) end,
        optionCount=function() return captureOwner.optionCount end,
        setCleanup=function(fn) upstreamCleanup=fn end})
    upstreamOptions=shallow(liveI.Builtin.Ellesmere and liveI.Builtin.Ellesmere.options or {})
    for key,option in pairs(captureOwner.options) do upstreamOptions[key]=option end
    report.ellesmerePreparation.captureOverflow=captureOwner.overflow==true
    report.ellesmerePreparation.optionsAvailable=count(upstreamOptions,4096)
    captureOwner=nil
    heapSample("after_ellesmere_preparation");pause()
    I.Registry:SetReady(true)
    local originalRegister=I.Providers.Register
    local wrappedHandles=setmetatable({},{__mode="k"})
    local function wrapHandle(handle) if handle and not wrappedHandles[handle] then wrappedHandles[handle]=true;wrap(handle,"Update","sdk") end end
    I.Providers.Register=function(self,definition)
        local onEnable=definition.onEnable
        if onEnable then definition.onEnable=function(handle) wrapHandle(handle);return onEnable(handle) end end
        local handle,err=originalRegister(self,definition);wrapHandle(handle);return handle,err
    end
    wrap(I.Providers,"Register","sdk")
    for _,key in ipairs({"Validate","Copy","ValidateScope","ValidateSearchRecord","ValidateSchema"}) do wrap(I.Boundary,key,"validation") end
    for _,key in ipairs({"RegisterSource","CommitSnapshot","ApplyDelta"}) do wrap(I.Search.StaticIndex,key,"index") end
    for _,def in ipairs(I.Builtin.Definitions) do I.CharacterStore:DisabledProviders()[def.id]=nil end
    report.dependencies={ellesmerePresent=type(G.EllesmereUI)=="table",ellesmereLoaded=G.EllesmereUI and G.EllesmereUI._deferredLoaded==true,
        exwindPresent=type(G.ExwindTools)=="table",exwindShell=G.ExwindTools and type(G.ExwindTools.UnifiedPanel)=="table",
        blizzardSettingsDeclarations=G.SettingsPanel and type(G.SettingsPanel.GetAllCategories)=="function"}
    heapSample("private_ready_after_upstream");pause()
    local firstRecords,firstQueries
    for round=1,4 do
        profiling=round==4
        local result={round=round,providers={},queries={}};report.rounds[round]=result
        result.instrumented=profiling
        currentPhase="build_"..round
        local begin=clock();local activeBefore=aggregate.activeMs
        -- Only round 3 intentionally retains private persisted cache; never use the real DB cache.
        if round~=3 then
            E.LycheeCharacterDB.achievementCatalog=nil
            for key in pairs(E.LycheeDB) do if key~="schemaVersion" and key~="optionalProviderDefaults" and key~="disabledProviders" then E.LycheeDB[key]=nil end end
        end
        result.privatePersistedCacheRetained=round==3
        for _,def in ipairs(I.Builtin.Definitions) do
            currentPhase="build_"..round.."/"..def.id
            local m=I.Builtin[def.module]
            local available=m and I.Builtin.Support:Available(def,I.Search.RuntimeIdentity:Current().product)
            local sample={available=available==true};result.providers[def.id]=sample
            if available then
                local startedProvider=clock();local activeStart=aggregate.activeMs
                local ok,why=pcall(function() timed(m.Init,m) end)
                if ok then drain() end
                sample.initializationOK=ok;sample.error=not ok and tostring(why) or nil
                sample.wallMs=clock()-startedProvider
                sample.activeMs=aggregate.activeMs-activeStart
                sample.providerError=m.lastError or (m.Provider and m.Provider.lastError)
                local registered=I.Providers.entries[def.id];sample.registered=registered~=nil;sample.records=registered and #registered.records or 0
                if def.id=="builtin.ellesmere" and m.options then
                    local original=shallow(liveI.Builtin.Ellesmere and liveI.Builtin.Ellesmere.options or {})
                    for key,option in pairs(upstreamOptions or {}) do original[key]=option end
                    local n=0
                    for key,option in pairs(original) do n=n+1;if n>4096 then error("Ellesmere captured option limit") end;m.options[key]=shallow(option) end
                    m.optionCount=n;sample.capturedOptionsReplayed=n
                end
            end
        end
        result.buildWallMs=clock()-begin;result.buildActiveMs=aggregate.activeMs-activeBefore
        currentPhase="records_"..round
        local records=snapshotRecords();result.records=records
        if firstRecords then
            result.recordsEqual=true
            for key,value in pairs(records) do if not firstRecords[key] or firstRecords[key].hash~=value.hash then result.recordsEqual=false end end
            for key in pairs(firstRecords) do if not records[key] then result.recordsEqual=false end end
        else firstRecords=records end
        currentPhase="queries_"..round
        local texts={"死亡矿井","坐骑","技能","设置","成就","eui:","eui:冷却","ex:","ex:冷却","key","not-found"}
        for _,raw in ipairs(texts) do
            local sample,items=query(raw);result.queries[raw]=sample
            if raw=="eui:" or raw=="ex:" then
                local providerID=raw=="eui:" and "builtin.ellesmere" or "builtin.exwind"
                local item=items[1]
                if item then
                    local b=clock();local resolved=timed(I.Providers.Resolve,I.Providers,{providerID=providerID,entryID=item.id},{})
                    sample.resolveMs=clock()-b;sample.resolved=resolved~=nil
                end
            end
            pause()
        end
        if firstQueries then result.queryOrderEqual=true;for raw,sample in pairs(result.queries) do if firstQueries[raw].hash~=sample.hash then result.queryOrderEqual=false end end
        else firstQueries=result.queries end
        local optionKeys={};for key in pairs(upstreamOptions or {}) do optionKeys[#optionKeys+1]=key end;table.sort(optionKeys)
        result.ellesmereOptionCheck={captured=#optionKeys,status="not_tested"}
        if optionKeys[1] then
            local option=upstreamOptions[optionKeys[1]]
            local optionSample,items=query("eui:"..(option.labelLoc or option.label))
            result.ellesmereOptionCheck.query=optionSample;result.ellesmereOptionCheck.resolved=0
            for _,item in ipairs(items) do
                if type(item.id)=="string" and item.id:find("option/",1,true) then
                    local resolved=timed(I.Providers.Resolve,I.Providers,{providerID="builtin.ellesmere",entryID=item.id},{})
                    if resolved then result.ellesmereOptionCheck.resolved=result.ellesmereOptionCheck.resolved+1 end
                end
            end
            result.ellesmereOptionCheck.status=result.ellesmereOptionCheck.resolved>0 and "verified" or "no_resolved_option"
        else result.ellesmereOptionCheck.reason="normal page produced no newly captured options; no fabricated option" end
        currentPhase="cancel_query_"..round
        local lateReplies=0
        timed(I.Search.Query.Query,I.Search.Query,"eui:冷却",{visible=true},nil,function() lateReplies=lateReplies+1 end)
        timed(I.Search.Query.Cancel,I.Search.Query,"unified-cancel-check");drain()
        result.cancelledQueryNoLateReply=lateReplies==0 and count(I.Providers.jobs)==0
        assert(result.cancelledQueryNoLateReply,"cancelled query published a late result")
        currentPhase="warm_queries_"..round
        begin=clock();activeBefore=aggregate.activeMs
        for n=1,24 do query(n%2==0 and "死亡矿井" or "ex:冷却") end
        result.warm24WallMs=clock()-begin;result.warm24ActiveMs=aggregate.activeMs-activeBefore
        currentPhase="index_only_"..round
        begin=clock();timed(I.Search.StaticIndex.Rebuild,I.Search.StaticIndex);result.indexOnlyMs=clock()-begin
        result.fakeFrameRoots=#roots
        heapSample("active_"..round);pause()
        currentPhase="release_"..round
        begin=clock();timed(release);result.releaseMs=clock()-begin
        result.released=true;result.privatePersistedCacheStillPresent=E.LycheeCharacterDB.achievementCatalog~=nil
        heapSample("released_"..round);pause()
    end
    profiling=false
    for providerID,entry in pairs(liveP) do
        report.coverage[providerID]={liveRecords=#entry.records,privateMeasured=report.rounds[1].providers[providerID]~=nil,
            mode="See per-round readiness and errors; live-only provider code not assumed covered"}
    end
    for _,def in ipairs(I.Builtin.Definitions) do
        local sample=report.rounds[1].providers[def.id]
        local mode="fresh source function execution against current game APIs; native events simulated"
        if def.id=="builtin.ellesmere" then mode="normal upstream preparation reported separately; real emitted/existing option metadata replay; per-round option query/resolve verdict; unvisited pages not covered"
        elseif def.id=="builtin.exwind" then mode="fresh read of existing upstream declarations and static layouts; no build/action"
        elseif def.id=="builtin.keystones" then mode="current game API cache only; communication and refresh suppressed; no fresh peer replies"
        elseif def.id=="builtin.addon-inspector" then mode="SDK declaration and cleanup only; live frame picker interaction not run"
        elseif def.id=="builtin.crests" then mode="SDK declaration only; native custom settings view not opened"
        elseif def.id=="builtin.bosses" then mode="fresh expansion from shipped Chinese static catalog; no game API acquisition required"
        elseif def.id=="builtin.blizzard-settings" then mode="fresh read of existing Blizzard category/layout declarations; no settings UI construction"
        elseif def.id=="builtin.player-spells" then mode="fresh spellbook read; missing description download requests suppressed" end
        local entry=report.coverage[def.id] or {};report.coverage[def.id]=entry
        entry.mode=mode;entry.dependencyAvailable=sample and sample.available;entry.initializationOK=sample and sample.initializationOK
        entry.providerError=sample and sample.providerError
    end
    E.LycheeCharacterDB.achievementCatalog=nil
    for key in pairs(E.LycheeDB) do if key~="schemaVersion" and key~="optionalProviderDefaults" and key~="disabledProviders" then E.LycheeDB[key]=nil end end
    heapSample("all_private_data_caches_released");pause()
    report.integrationLimits="Ellesmere normal settings initialization/page open measured separately; loaded code/native state retained; temporary registration observer restored; no global-search prebuild or business setters. Exwind reads existing declarations only."
    report.liveBeforeUI={indexVersion=liveIndex.version,records=count(liveIndex.entries),rootsUnchanged=verifyLive()}
    report.userStateBeforeUI={character=hash(liveCharacterDB or {})}
    -- Real native UI is separate from the private fake-frame instance.
    currentPhase="real_ui"
    uiController=liveI.Host and liveI.Host.PaletteController
    report.ui={method="real controller Show/Hide; not hardware shortcuts",samples={}}
    report.ui.initiallyCreated=uiController~=nil and uiController.frame~=nil
    local firstOpened=false
    if not uiController and type(G.Lychee_Toggle)=="function" then
        ownedUI=true;local begin=clock();timed(G.Lychee_Toggle)
        report.ui.initialOpenCallMs=clock()-begin
        uiController=liveI.Host and liveI.Host.PaletteController;firstOpened=true
    end
    if not uiController then report.ui.skipped="controller_unavailable"
    elseif uiController.visible and not firstOpened then report.ui.skipped="lychee_already_visible"
    elseif uiController._motionClosing then report.ui.skipped="lychee_close_animation_active"
    elseif liveI.Builtin.AddonInspector and liveI.Builtin.AddonInspector.running then report.ui.skipped="lychee_inspector_active"
    else
        for n=1,3 do
            ownedUI=true;local b=clock()
            if not (n==1 and firstOpened) then timed(uiController.Show,uiController) end
            local sample={showCallMs=n==1 and firstOpened and report.ui.initialOpenCallMs or clock()-b};report.ui.samples[n]=sample
            pause(0.8)
            sample.shown=uiController.visible==true and uiController.frame:IsShown()
            sample.rows=uiController.list and uiController.list.rows and #uiController.list.rows
            if uiController.frame.GetRect then sample.rect={uiController.frame:GetRect()} end
            if uiController.header and uiController.header.GetAlpha then sample.headerAlpha=uiController.header:GetAlpha() end
            if uiController.content and uiController.content.GetAlpha then sample.contentAlpha=uiController.content:GetAlpha() end
            b=clock();timed(uiController.Hide,uiController,"unified-study");sample.hideCallMs=clock()-b
            pause(n==1 and 0.05 or 0.8)
        end
        pause(0.8);report.ui.closed=not uiController.visible and not uiController.frame:IsShown();ownedUI=nil
    end
    heapSample("live_after_ui");report.userStateAfter={character=hash(liveCharacterDB or {})}
    report.geometryStable=true
    if report.ui.samples[1] and report.ui.samples[1].rect then
        local first=report.ui.samples[1].rect
        for _,sample in ipairs(report.ui.samples) do for n,v in ipairs(sample.rect or {}) do if math.abs(v-first[n])>0.05 then report.geometryStable=false end end end
    else report.geometryStable=nil end
    report.userCharacterStateUnchanged=report.userStateBefore.character==report.userStateAfter.character
    report.liveAfter={records=count(liveIndex.entries),providers=count(liveP),indexVersion=liveIndex.version}
    finish("complete")
end)
local function step()
    control.timer=nil
    if control.finished then return end
    local scheduling=report.scheduler
    if control.scheduledAt then
        local waited=math.max(0,clock()-control.scheduledAt)
        scheduling.actualWaitMs=scheduling.actualWaitMs+waited
        scheduling.maxOvershootMs=math.max(scheduling.maxOvershootMs,waited-control.requestedDelayMs)
        scheduling.wakeups=scheduling.wakeups+1
    end
    if InCombatLockdown() then finish("aborted","Combat began; no protected operations attempted");return end
    if clock()-start>wallLimitSeconds*1000 then finish("aborted",tostring(wallLimitSeconds).." second wall limit");return end
    local begin=clock();local ok,delay=coroutine.resume(routine);local elapsed=clock()-begin
    scheduling.resumeMs=scheduling.resumeMs+elapsed
    report.lastPhase=currentPhase
    report.maxResumeMs=math.max(report.maxResumeMs or 0,elapsed)
    if not ok then finish("aborted",delay);return end
    if not control.finished and coroutine.status(routine)~="dead" then
        delay=math.max(0.001,tonumber(delay) or 0.01)
        control.scheduledAt=clock();control.requestedDelayMs=delay*1000
        scheduling.requestedWaitMs=scheduling.requestedWaitMs+control.requestedDelayMs
        local scheduled,timer=pcall(C_Timer.NewTimer,delay,step)
        if scheduled then control.timer=timer else finish("aborted","Timer scheduling failed: "..tostring(timer)) end
    end
end
control.scheduledAt=clock();control.requestedDelayMs=100;report.scheduler.requestedWaitMs=100
local scheduled,timer=pcall(C_Timer.NewTimer,0.1,step)
if not scheduled then finish("aborted","Timer scheduling failed: "..tostring(timer));return report end
control.timer=timer
return {status="running",studyID=id,message="One staged run, wall limit 10 minutes. On completion /reload once.",reportPath="LycheePerformanceTestDB.reports["..id.."]"}
end
