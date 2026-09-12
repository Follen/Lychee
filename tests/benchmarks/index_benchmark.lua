-- Reproducible offline workload; arg[1] may point to a baseline StaticIndex.lua.
-- This measures Lua index work, not WoW frame time or combat CPU.
function GetLocale() return "enUS" end
function debugprofilestop() return os.clock() * 1000 end
LycheeInternal = { Search={} }
LycheeDB = {}
dofile("addon/Lychee/Search/Normalizer.lua")
dofile(arg[1] or "addon/Lychee/Search/StaticIndex.lua")
local index=LycheeInternal.Search.StaticIndex
local delta=arg[2]=="delta"
local count, iterations=1000,delta and 100 or 10
local function data(revision)
    local result={}
    for i=1,count do result[i]={id="entry-"..i,kind="info",title="Benchmark entry "..i,payload={value=i==1 and revision or i}} end
    return result
end
collectgarbage("collect")
local memoryBefore=collectgarbage("count")
local started=os.clock()
assert(index:RegisterSource({id="bench:records",version=2,revision=1,priority=0,scope={}}))
assert(index:CommitSnapshot("bench:records",data(0)))
local cold=(os.clock()-started)*1000
local untouched=index.entries["bench:records:entry-2"]
local preserved=0
started=os.clock()
for iteration=1,iterations do
    if delta then assert(index:ApplyDelta("bench:records",{{id="entry-1",kind="info",title="Benchmark entry 1",payload={value=iteration}}},{}))
    else assert(index:CommitSnapshot("bench:records",data(iteration))) end
    if index.entries["bench:records:entry-2"]==untouched then preserved=preserved+1 end
end
local update=(os.clock()-started)*1000/iterations
started=os.clock()
for iteration=1,100 do index:Search("Benchmark entry 500",20) end
local search=(os.clock()-started)*1000/100
collectgarbage("collect")
local memory=collectgarbage("count")-memoryBefore
print(string.format('{"entries":%d,"updates":%d,"coldMS":%.3f,"meanUpdateMS":%.3f,"meanSearchMS":%.3f,"retainedKB":%.1f,"unchangedEntryRetained":%d}',count,iterations,cold,update,search,memory,preserved))
