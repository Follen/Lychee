function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","69875","fixture",120100 end
function InCombatLockdown() return false end
dofile("tests/support/runtime.lua").Load("provider",{"Core/UserPreferences.lua","Search/Personalization.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local entries={}
for n=1,40 do entries[n]={id=string.format("item%02d",n),title="Candidate"} end
assert(Lychee:RegisterProvider({id="candidate.fixture",apiVersion="1.0.0",version="1",title="Candidate",entries=entries}))
local ref={providerID="candidate.fixture",entryID="item40"}
local item=assert(I.Providers:Resolve(ref,{}))
assert(I.UserPreferences:Pin(item))
local _,rows=I.Search.Query:Query("Candidate",{visible=true})
assert(#rows==20 and rows[1].id=="item40","pin reaches static top K before truncation")
assert(rows[1].confidence<=1 and rows[1].evidence.confidence<=1,"weight does not rewrite matching evidence")
local observed
assert(Lychee:RegisterProvider({id="candidate.dynamic",apiVersion="1.0.0",version="1",title="Dynamic",entries={},query=function(request,reply)
    observed=request
    assert(not request._preferences,"Host preference map must not escape")
    assert(not request.ranking or not request.ranking.item40,"other provider weights must not escape")
    reply({})
end}))
I.Search.Query:Query("Candidate",{visible=true})
assert(observed)
local request=I.Search.Query:_BuildRequest("Candidate",{visible=true},1)
assert(request._preferences.providers["candidate.fixture"].ranking.item40==30)
local catalog=assert(Lychee.SDK.CreateCatalog({id="candidate.catalog",title="Catalog"}))
assert(catalog:Update({replace=entries}))
local hits=assert(catalog:Search({normalized="candidate",limit=20,ranking={item40=30}}))
assert(hits[1].entry.id=="item40","public catalog weights apply before top K")
print("Candidate preference PASS: static/catalog top K, unchanged evidence, provider isolation")
