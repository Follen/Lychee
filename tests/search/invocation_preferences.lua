-- Exact parameterized preferences must not become entry-wide hints.
GetTimePreciseSec=function() return 0 end
GetLocale=function() return "enUS" end
GetBuildInfo=function() return "12.1.0","69875","fixture",120100 end
InCombatLockdown=function() return false end
C_Timer={NewTimer=function() return {Cancel=function() end} end}
dofile("tests/support/runtime.lua").Load("provider",{"Core/UserPreferences.lua","Search/Personalization.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local all,observed,writes=false,nil,0
assert(Lychee:RegisterProvider({id="preference.params",apiVersion="1.0.0",version="1",title="Parameterized setting",
    actions={set={title="Set",actionVersion=1,schema={percent={type="integer",min=0,max=100,required=true}},
        run=function() writes=writes+1;return {status="succeeded"} end}},
    resolveTarget=function(target) return {status="ready",target=target,identity="master"} end,
    query=function(request,reply)
        observed=request
        local entries={}
        for n=1,(all and 40 or 1) do
            local percent=all and (n==40 and 99 or n) or 99
            entries[#entries+1]={entry={id="master",title="Master volume",actions={"set"},
                invocation={kind="invocation",product="retail",providerID="preference.params",actionID="set",actionVersion=1,
                    target={version=1,key={channel="master"}},args={percent=percent}}},confidence=1}
        end
        reply(entries)
    end}))
local _,first=I.Search.Query:Query("volume",{visible=true})
assert(#first==1 and first[1].ref.args.percent==99)
local originalConfidence,originalEvidence=first[1].confidence,first[1].evidence.confidence
assert(I.UserPreferences:Pin(first[1]))
all=true
local _,rows=I.Search.Query:Query("volume",{visible=true})
assert(#rows==20 and rows[1].ref.args.percent==99,"pinned invocation must reach top K by full reference, not entry ID")
assert(not observed._preferences and not observed.preferredEntryID and not (observed.ranking and observed.ranking.master),
    "specific invocation preferences must not become scalar hints for every parameter variant")
for index,item in ipairs(rows) do
    assert(item.confidence==originalConfidence and item.evidence.confidence==originalEvidence,"preferences must not overwrite evidence")
    if index>1 then assert(item._preferenceRank==1,"siblings must not inherit the pinned invocation bonus") end
end
-- Stored parameterized refs need no legacy entry ID. Exercise Remember through
-- the same item acceptance path, then re-query with such a preferred reference.
local selected={}
for key,value in pairs(rows[1]) do selected[key]=value end
selected.ref=assert(I.Invocations:CopyData(rows[1].ref,"test.ref"))
selected.ref.entryID=nil
assert(I.UserPreferences:CanPin(selected))
assert(I.Search.Personalization:Remember("volume",selected))
local remembered=I.Search.Personalization:Preferred({normalized="volume"})
assert(remembered and remembered.entryID==nil and remembered.args.percent==99)
local ok,generation,again=pcall(I.Search.Query.Query,I.Search.Query,"volume",{visible=true})
assert(ok,"search after remembering an invocation without entryID must not concatenate nil")
assert(#again==20 and again[1].ref.args.percent==99,"remembered invocation remains the exact first choice")
assert(not observed.preferredEntryID and not (observed.ranking and observed.ranking.master))
assert(writes==0,"pinning, remembering and searching must not run business actions")
print("Invocation preferences PASS: exact parameter top K, no sibling bonus/scalar hint leak, ID-free remembered ref and no side effects")
