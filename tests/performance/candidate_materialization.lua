-- Counterfactual experiment only. It knows the final winners in advance; the
-- production query must publish the static batch before async replies arrive.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","69875","fixture",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
dofile("tests/support/runtime.lua").Load("provider")
local I=LycheeInternal;I.Registry:SetReady(true)
local documents={}
for i=1,20 do documents[i]={id="entry"..i,title="Candidate "..i} end
local reads=0
local handle=assert(Lychee:RegisterProvider({id="experiment.candidates",title="Experiment",version="1",apiVersion="1.0.0",
    entryMode="documents",entries=documents,readEntry=function(id)
        reads=reads+1
        return {id=id,title="Candidate "..id,actions={{id="use",kind="secure-item",itemID=123,title="Use"}}}
    end}))
local hits=I.Search.StaticIndex:Search("candidate",20,nil,true)
assert(#hits==20)
local function measure(count)
    reads=0;collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
    local t=os.clock()
    for round=1,100 do
        local results={}
        for i=1,count do results[i]=assert(I.Search.ResultSnapshot:Materialize(hits[i])) end
        assert(results[1].interaction.actions[1].itemID==123)
    end
    local ms=(os.clock()-t)*1000;local allocated=collectgarbage("count")-base
    collectgarbage("restart");collectgarbage("collect")
    return ms,allocated,reads
end
local eagerMS,eagerKB,eagerReads=measure(20)
local finalMS,finalKB,finalReads=measure(10)
assert(eagerReads==2000 and finalReads==1000)
print(string.format("Candidate experiment 100 queries: eager20 %.2fms %.1fKiB %d reads; oracle10 %.2fms %.1fKiB %d reads",eagerMS,eagerKB,eagerReads,finalMS,finalKB,finalReads))
print("Not adopted: oracle requires completed dynamic rankings. An unresolved provider can take up to the 5s deadline; waiting loses the immediately usable static batch. Does not establish equivalent alias/personalized ordering.")
assert(handle:Unregister())
