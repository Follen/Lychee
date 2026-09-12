-- Destructive offline attribution only; never loaded by the addon or test suite.
-- lua tests/profile_search_memory.lua [mounts|builtins] [seen|memberships|cache|saved|updates]
-- Optional args 3/4 override the index/mount module for an isolated baseline.
local scenario=arg[1] or "mounts"
local part=arg[2] or "seen"
local path=scenario=="mounts" and "tests/mounts_vault_smoke.lua" or "tests/builtin_providers_smoke.lua"
-- Capture the populated index before a fixture unregisters its peak source.
local originalGC=collectgarbage
local retainedIndex
collectgarbage=function(operation,...)
    local index=LycheeInternal and LycheeInternal.Search and LycheeInternal.Search.StaticIndex
    if index and operation=="count" then
        local count=0; for _ in pairs(index.entries) do count=count+1 end
        if count>=1000 then retainedIndex=index.entries end
    end
    return originalGC(operation,...)
end
local originalDofile=dofile
dofile=function(file)
    if arg[3] and file=="addon/Lychee/Search/StaticIndex.lua" then return originalDofile(arg[3]) end
    if arg[4] and file=="addon/Lychee/Builtin/Mounts/Provider.lua" then return originalDofile(arg[4]) end
    return originalDofile(file)
end
local ok,err=pcall(dofile,path)
dofile=originalDofile
collectgarbage=originalGC
if not ok and not tostring(err):find("memory budget",1,true) then error(err) end
local index=LycheeInternal.Search.StaticIndex
local entries=retainedIndex or index.entries
-- Mount fixture unregisters by removing entries in-place: profile a fresh
-- registration using its same 1500-record synthetic collection.
if scenario=="mounts" then
    C_Timer=nil
    assert(LycheeInternal.Builtin.Mounts:Init())
    entries=index.entries
end
local count,memberships,seen=0,0,0
for _,entry in pairs(entries) do
    count=count+1
    memberships=memberships+#(entry.memberships or {})
    for _ in pairs(entry.membershipSeen or {}) do seen=seen+1 end
end
if part=="updates" then
    local _,entry=next(entries)
    local record,sourceID=entry.record,entry.sourceID
    local started=os.clock()
    for n=1,100 do
        local updated={}; for key,value in pairs(record) do updated[key]=value end
        updated.title="更新测量坐骑"..n
        assert(index:ApplyDelta(sourceID,{updated},{}))
    end
    local updateMS=(os.clock()-started)*10
    started=os.clock()
    assert(index:UnregisterSource(sourceID))
    local removeMS=(os.clock()-started)*1000
    print(string.format("Updates %s: %d entries; one-record update mean %.3f ms; source removal %.3f ms",scenario,count,updateMS,removeMS))
    return
end
originalGC("collect")
local before=originalGC("count")
if part=="seen" then
    for _,entry in pairs(entries) do entry.membershipSeen=nil end
elseif part=="memberships" then
    for _,entry in pairs(entries) do entry.memberships=nil end
elseif part=="cache" then
    LycheeInternal.Search.Normalizer:ClearCache()
    index.previousQuery,index.previousCandidates,index.previousFilterKey=nil,nil,nil
elseif part=="saved" then
    LycheeDB.searchIndex=nil
else error("unknown attribution part") end
originalGC("collect")
print(string.format("Attribution %s/%s: %d entries, %d membership tuples, %d seen keys; released %.1f KiB",
    scenario,part,count,memberships,seen,before-originalGC("count")))
