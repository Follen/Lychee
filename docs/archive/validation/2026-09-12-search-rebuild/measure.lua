-- OFFLINE ONLY. Never paste into WoW: destroys isolated fixture Providers.
-- lua analyze/measure-search-rebuild.lua [mountCount=287] [rounds=11]
-- Reuses the exact startup fixture bootstrap, not its timed test body.
assert(io and os, "offline harness required")
assert(not os.getenv("LYCHEE_PERF_BASELINE"), "unset LYCHEE_PERF_BASELINE")
local mounts,rounds=tonumber(arg[1]) or 287,tonumber(arg[2]) or 11
assert(mounts>=1 and mounts<=1500 and rounds>=1 and rounds<=21)
local clock=BENCH_CLOCK_MS or function() return os.clock()*1000 end
local function pack(...) return {n=select('#',...),...} end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function emit(stage,round,key,value)
    print(table.concat({"MEASURE",stage,round,key,type(value)=="number" and string.format("%.6f",value) or tostring(value)},"\t"))
end
local file=assert(io.open("tests/performance_startup.lua","rb"))
local fixture=file:read("*a");file:close()
local boundary=assert(fixture:find("local I = LycheeInternal",1,true))
local prefix=fixture:sub(1,boundary-1)
local nativeDofile=dofile
local loadCount,loadMax=0,0
dofile=function(path)
    local started=clock();local values=pack(nativeDofile(path))
    local elapsed=clock()-started;loadCount=loadCount+1;loadMax=math.max(loadMax,elapsed)
    return unpack(values,1,values.n)
end
local started=clock();assert(loadstring(prefix,"@startup-fixture-bootstrap"))()
local loadMS=clock()-started;dofile=nativeDofile
emit("load",0,"fixture_code_ms",loadMS);emit("load",0,"files",loadCount);emit("load",0,"max_file_ms",loadMax)
local I=LycheeInternal
local Index,Query,N=I.Search.StaticIndex,I.Search.Query,I.Search.Normalizer
-- Preserve original startup fixture data; change only available mount count.
local getInfo=C_MountJournal.GetMountInfoByID
local apiReads,listReads=0,0
C_MountJournal.GetMountIDs=function()
    listReads=listReads+1;local ids={};for n=1,mounts do ids[n]=n end;return ids
end
C_MountJournal.GetMountInfoByID=function(...)
    apiReads=apiReads+1;return getInfo(...)
end
-- Native objects remain strongly rooted even when fixture callbacks detach.
local nativeRoots={UIParent};local createFrame=CreateFrame
CreateFrame=function(...)
    local f=createFrame(...);nativeRoots[#nativeRoots+1]=f;return f
end
I.Registry:SetReady(true)
local modules={I.Builtin.Crests,I.Builtin.GameMenus,I.Builtin.Bosses,I.Builtin.Mounts}
local queries={"死","死亡","死亡矿井","巫妖王","纹章","星","星光","星光云端","无敌","午夜","not-found","翡翠"}
local expected,expectedQuery,weak={}, {},setmetatable({},{__mode="v"})
local function serialize(v,seen)
    if type(v)~="table" then return type(v)..":"..tostring(v) end
    seen=seen or {};assert(not seen[v],"unexpected record cycle");seen[v]=true
    local keys,out={},{};for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do out[#out+1]=serialize(k,seen).."="..serialize(v[k],seen) end
    seen[v]=nil;return "{"..table.concat(out,";").."}"
end
local function verifyRecords(round)
    assert(count(Index.entries)==1154+35+mounts,"incomplete directory")
    assert(count(I.Providers.entries)==4 and count(Index.sources)==4,"missing Provider/source")
    assert(apiReads==mounts and listReads==1,"data collection was skipped")
    local n=0
    for key,indexed in pairs(Index.entries) do
        local fingerprint=serialize(indexed.record)
        if round==1 then expected[key]=fingerprint else assert(expected[key]==fingerprint,"record changed: "..key) end
        n=n+1;if n<=16 then weak[n]=indexed;weak[20+n]=indexed.record end
    end
end
local function queryOnce(text)
    local _,items=Query:Query(text,{visible=true})
    assert(type(items)=="table")
    if text~="not-found" then assert(#items>0,"lost search results: "..text) end
    return items,#items
end
local function verifyQuery(text,round)
    -- Query output contains session/source generation fields. Compare stable
    -- business fields below instead of ignoring generation validity itself.
    local _,items=Query:Query(text,{visible=true})
    local rows={}
    for _,item in ipairs(items) do
        rows[#rows+1]=serialize({id=item.id,stableID=item.stableID,text=item.text,subtext=item.subtext,
            confidence=item.confidence,evidence=item.evidence,record=item.searchRecord,
            interaction=item.interaction,payload=item.payload,icon=item.icon})
    end
    local stable=table.concat(rows,"\n")
    if round==1 then expectedQuery[text]=stable else assert(expectedQuery[text]==stable,"query order/content changed: "..text) end
end
local function release()
    Query:Cancel("offline-rebuild")
    for _,m in ipairs(modules) do
        assert(m.handle and m.handle:Unregister(),"unregister failed")
        assert(m.handle==nil,"Provider retained its old handle")
    end
    I.Builtin._initialized=nil
    Index:ClearQueryCache();N:ClearCache()
    assert(count(Index.entries)==0 and count(Index.sources)==0 and count(I.Providers.entries)==0,"directory survived release")
    assert(count(I.Registry.entries)==0 and #I.Registry.order==0 and count(I.Providers.jobs)==0,"Registry/jobs survived release")
end
local baseMemory
for round=1,rounds do
    collectgarbage("collect")
    assert(next(weak)==nil,"prior canonical/index objects still alive")
    local before=collectgarbage("count");if round==1 then baseMemory=before end
    apiReads,listReads=0,0
    started=clock();I.Builtin:Init();local built=clock()-started
    emit("normal",round,"build_ms",built)
    -- This path has no timer/yield: the full build is one non-interruptible span.
    emit("normal",round,"build_max_sync_ms",built)
    started=clock();local _,firstCount=queryOnce("死亡矿井");local first=clock()-started
    emit("normal",round,"first_query_ms",first);emit("normal",round,"build_plus_first_ms",built+first)
    emit("normal",round,"first_count",firstCount)
    collectgarbage("collect")
    emit("normal",round,"build_retained_before_verification_KiB",collectgarbage("count")-before)
    verifyRecords(round)
    for _,q in ipairs(queries) do verifyQuery(q,round) end
    collectgarbage("collect")
    emit("normal",round,"active_delta_KiB",collectgarbage("count")-before)
    -- Timed hot query execution excludes diagnostic serialization/assertions.
    started=clock()
    for repeatIndex=1,10 do for _,q in ipairs(queries) do Query:Query(q,{visible=true}) end end
    local hot=clock()-started
    emit("normal",round,"hot_120_ms",hot);emit("normal",round,"hot_query_mean_ms",hot/120)
    started=clock();Index:Rebuild();local reindex=clock()-started
    emit("normal",round,"index_only_rebuild_ms",reindex)
    started=clock();release();emit("normal",round,"release_ms",clock()-started)
    collectgarbage("collect")
    assert(next(weak)==nil,"release retained canonical/index objects")
    emit("normal",round,"released_delta_from_initial_KiB",collectgarbage("count")-baseMemory)
    emit("normal",round,"native_pool",#nativeRoots)
end
-- Separate GC-stopped allocation/profile pass; never mix its latency into the
-- normal-GC samples. Instrumented categories are exclusive elapsed durations.
-- Drop diagnostic fingerprints before a clean, uninstrumented memory pass.
expected,expectedQuery,weak=nil,nil,nil
collectgarbage("collect")
local memoryBefore=collectgarbage("count")
collectgarbage("stop");I.Builtin:Init()
local allocation=collectgarbage("count")-memoryBefore
collectgarbage("restart");collectgarbage("collect")
local retained=collectgarbage("count")-memoryBefore
release();collectgarbage("collect")
local released=collectgarbage("count")-memoryBefore
emit("memory",0,"build_allocation_GC_stopped_KiB",allocation)
emit("memory",0,"build_retained_KiB",retained)
emit("memory",0,"after_release_delta_KiB",released)
local metrics,stack={},{}
local function wrap(object,key,label)
    local original=assert(object[key],key)
    object[key]=function(...)
        local parent=stack[#stack];local node={children=0};stack[#stack+1]=node
        local start=clock();local result=pack(original(...));local elapsed=clock()-start
        stack[#stack]=nil;if parent then parent.children=parent.children+elapsed end
        local stat=metrics[label] or {ms=0,calls=0,max=0};metrics[label]=stat
        stat.ms=stat.ms+elapsed-node.children;stat.calls=stat.calls+1;stat.max=math.max(stat.max,elapsed)
        return unpack(result,1,result.n)
    end
end
for _,m in ipairs(modules) do wrap(m,"Init","collection") end
wrap(I.Builtin.Mounts,"Refresh","collection")
local originalRegister=I.Providers.Register
local profiledHandles=setmetatable({},{__mode="k"})
local function profileHandle(handle)
    if handle and not profiledHandles[handle] then profiledHandles[handle]=true;wrap(handle,"Update","sdk") end
end
I.Providers.Register=function(self,definition)
    local onEnable=definition.onEnable
    if onEnable then definition.onEnable=function(handle) profileHandle(handle);return onEnable(handle) end end
    local handle,err=originalRegister(self,definition)
    profileHandle(handle)
    return handle,err
end
wrap(I.Providers,"Register","sdk")
for _,key in ipairs({"Validate","ValidateScope","ValidateSearchRecord","ValidateSchema"}) do wrap(I.Boundary,key,"validation") end
wrap(I.ProviderLocales,"Compile","locales")
for _,key in ipairs({"RegisterSource","CommitSnapshot","ApplyDelta"}) do wrap(Index,key,"index") end
wrap(C_MountJournal,"GetMountIDs","mock_api");wrap(C_MountJournal,"GetMountInfoByID","mock_api")
apiReads,listReads=0,0
collectgarbage("collect");local before=collectgarbage("count");collectgarbage("stop")
started=clock();I.Builtin:Init();local profiled=clock()-started
emit("profile",0,"build_ms",profiled);emit("profile",0,"allocation_KiB",collectgarbage("count")-before)
collectgarbage("restart");collectgarbage("collect")
emit("profile",0,"retained_KiB",collectgarbage("count")-before)
for label,metric in pairs(metrics) do
    emit("profile",0,label.."_exclusive_ms",metric.ms)
    emit("profile",0,label.."_calls",metric.calls)
    emit("profile",0,label.."_max_call_ms",metric.max)
end
emit("meta",0,"records",1154+35+mounts);emit("meta",0,"mounts",mounts);emit("meta",0,"rounds",rounds)
print("CHECK complete records, query business fields/order, empty registry/index, dead old records: PASS")
