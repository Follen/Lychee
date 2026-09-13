function GetLocale()return "enUS"end
function GetBuildInfo()return "12.1.0","70000","",120100 end
function InCombatLockdown()return false end
dofile("tests/support/runtime.lua").Load("provider")
local SDK=Lychee.SDK
do
    local hits={}
    for i=1,276 do hits[i]={entry={id=string.format('%03d',i),title='Common'},confidence=.9} end
    local sorted=assert(SDK.SortHits({normalized='common',ranking={['276']=30,['275']=8}},hits,20))
    assert(#sorted==20 and sorted[1]==hits[276] and sorted[2]==hits[275] and hits[1].entry.id=='001','batch rank before truncate without mutating input')
    hits[277]=hits[1];assert(not SDK.SortHits({normalized='common'},hits));hits[277]=nil
    for _,limit in ipairs({0,257,.5,math.huge,0/0,'20'})do assert(not SDK.SortHits({normalized='common'},hits,limit))end
    hits[1].confidence=0/0;assert(not SDK.SortHits({normalized='common'},hits));hits[1].confidence=.9
    local sentinel={};issecretvalue=function(v)return v==sentinel end
    assert(not SDK.SortHits({normalized='common'},hits,sentinel));issecretvalue=nil
    local bad={};bad[2]=hits[2];assert(not SDK.SortHits({normalized='common'},bad))
end
assert(type(SDK.CreateRanker)=='function')
local request={normalized='common',preferredEntryID='memory',ranking={pinned=30,recent=8,both=38}}
local rank=assert(SDK.CreateRanker(request))
local function equal(a,b)assert(math.abs(a-b)<0.000001)end
equal(rank('pinned',.9),.93);equal(rank('recent',.9),.908);equal(rank('both',.9),.938)
equal(rank('memory',.4),2.4);equal(rank('other',.9),.9)
assert(rank('memory',nil)==nil,'nonmatches cannot be promoted')
request.ranking.pinned=0;request.preferredEntryID='other'
equal(rank('pinned',.9),.93);equal(rank('memory',.4),2.4)
for _,bad in ipairs({-1,1.1,0/0,math.huge,false,'1'})do local value,err=rank('pinned',bad);assert(value==nil and err)end
assert(not rank({},.5));assert(not rank('',.5));assert(not rank(string.rep('a',129),.5))
local catalog=assert(SDK.CreateCatalog({id='rank.sdk'}))
local function reject(value)
    local value1,err1=SDK.CreateRanker({normalized='common',ranking=value})
    local value2,err2=catalog:Search({normalized='common',ranking=value})
    local value3,err3=SDK.Score({normalized='common',ranking=value},{})
    assert(not value1 and err1 and not value2 and err2 and not value3 and err3,'consistent public validation')
end
reject(false);reject({bad=-1});reject({bad=39});reject({bad=.1});reject({bad=0/0});reject({bad=math.huge})
reject({bad='30'});reject({['bad id']=1});reject({['']=1});reject({[string.rep('a',129)]=1})
reject(setmetatable({bad=1},{}));reject({[1]=30});local cycle={};cycle.x=cycle;reject(cycle)
local weights={}
for index=1,72 do weights[string.format('%03d',index)]=index<=64 and 30 or 73-index end
assert(SDK.CreateRanker({normalized='common',ranking=weights}))
weights.overflow=1;reject(weights);weights.overflow=nil
local secret={}
issecretvalue=function(v)return v==secret end
reject({bad=secret});assert(not rank(secret,.5));issecretvalue=nil
canaccessvalue=function(v)return v~=secret end
reject({bad=secret});assert(not rank(secret,.5));canaccessvalue=nil

-- Scalar hot path creates no per-candidate tables or closures.
rank=assert(SDK.CreateRanker({normalized='common',ranking=weights}))
for i=1,100 do rank('072',.9)end
collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count')
for i=1,10000 do rank('072',.9)end
local scalarAllocation=collectgarbage('count')-before
collectgarbage('restart');assert(scalarAllocation<1,'ranker hot path allocates')

-- Independent full scan with >20 weighted candidates; same inputs on/off.
local entries={}
for index=1,128 do entries[index]={id=string.format('%03d',index),title='Common '..index}end
assert(catalog:Update({replace=entries}))
local expected={}
for index=1,128 do local id=string.format('%03d',index);expected[index]={id=id,value=.9+(weights[id]or 0)/1000}end
table.sort(expected,function(a,b)return a.value>b.value or a.value==b.value and a.id<b.id end)
local hits=assert(catalog:Search({normalized='common',ranking=weights,limit=20}))
assert(#hits==20)
for index=1,20 do assert(hits[index].entry.id==expected[index].id and hits[index].confidence==.9)end
local function measure(enabled)
    local req={normalized='common',limit=20,ranking=enabled and weights or nil}
    for i=1,10 do assert(catalog:Search(req))end
    collectgarbage('collect');local retained=collectgarbage('count')
    collectgarbage('stop');local start,maximum=os.clock(),0
    for i=1,200 do local started=os.clock();assert(catalog:Search(req));maximum=math.max(maximum,(os.clock()-started)*1000)end
    local cpu,allocated=(os.clock()-start)*1000,collectgarbage('count')-retained
    collectgarbage('restart');collectgarbage('collect');local growth=collectgarbage('count')-retained
    assert(growth<16 and maximum<10,'ranking performance budget')
    return cpu/200,maximum,allocated,growth
end
local off,offMax,offAlloc,offGrowth=measure(false)
local on,onMax,onAlloc,onGrowth=measure(true)
print(string.format('SDK ranking 200 queries: off mean=%.3f max=%.3f alloc=%.1f growth=%.2f KiB; on mean=%.3f max=%.3f alloc=%.1f growth=%.2f KiB; scalar10000 alloc=%.2f KiB',off,offMax,offAlloc,offGrowth,on,onMax,onAlloc,onGrowth,scalarAllocation))
assert(catalog:Close())
print('SDK ranking PASS: capacity, invalid/secret input, snapshot copy, matching evidence, full-scan oracle and bounded hot path')
