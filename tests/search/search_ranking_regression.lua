local Fixture=dofile("tests/support/provider_fixture.lua")
-- Real Host ranking paths, with only the game environment substituted.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","fixture",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end,Hide=function() end,Show=function() end} end
UIParent={}
dofile("tests/support/runtime.lua").Load("provider", {"Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Core/UserPreferences.lua", "Search/Personalization.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local P=I.Search.Personalization
local function query(text,filter)
    local _,rows=I.Search.Query:Query(text,{visible=true,searchFilter=filter})
    return rows
end
local function register(id,entries)
    return assert(Fixture:Register({id=id,apiVersion="1.0.0",version="1",title="Ranking test",catalog=entries}))
end
local entries={}
for index=1,21 do entries[index]={id=string.format("%03d",index),title="Neutral item "..index} end
local handle=register("ranking.alias",entries)
for index=1,21 do
    assert(P:SetAlias({providerID="ranking.alias",entryID=string.format("%03d",index)},
        index==21 and "destination" or "destination entry "..index))
end
local resolve,calls=I.Providers.Resolve,0
I.Providers.Resolve=function(self,...) calls=calls+1;return resolve(self,...) end
local rows=query("destination")
assert(#rows==20 and rows[1].id=="021","late exact alias must beat earlier partial aliases")
assert(calls==20,"do not resolve the entire declaration set when enough valid results exist")
P:Remember("destination",rows[20])
local remembered=rows[20].id
assert(handle.catalog:Update({upsert={{id="000",title="New aliased item"}}}))
assert(P:SetAlias({providerID="ranking.alias",entryID="000"},"destination entry new"))
assert(query("destination")[1].id==remembered,"alias preference participates before candidate truncation")
assert(#query("destination",{sourceID="other:records"})==0,"aliases respect source routes")
assert(handle:SetAvailability(false))
assert(#query("destination")==0,"aliases cannot resurrect a disabled source")
assert(handle:SetAvailability(true))
assert(handle:Unregister())

-- Historical aliases may outlive their records. Missing matches do not spend
-- the twenty-result budget, but nonmatching declarations are never resolved.
LycheeCharacterDB={palette={}}
handle=register("ranking.stale",{{id="999",title="Only live record"}})
for index=1,20 do
    assert(P:SetAlias({providerID="ranking.stale",entryID=string.format("%03d",index)},"destination"))
end
assert(P:SetAlias({providerID="ranking.stale",entryID="999"},"destination"))
assert(P:SetAlias({providerID="ranking.stale",entryID="unrelated"},"other"))
calls=0;rows=query("destination")
assert(#rows==1 and rows[1].id=="999","missing references cannot hide the live alias")
assert(calls==21,"only matching declarations are resolved")
assert(handle:Unregister())
I.Providers.Resolve=resolve

LycheeCharacterDB={palette={}}
catalog={}
for index=101,120 do entries[#entries+1]={id=tostring(index),title="Common "..index} end
handle=register("ranking.memory",entries)
rows=query("Common")
P:Remember("Common",rows[20])
local preferred=P:Preferred({normalized="common"})
assert(preferred and preferred.entryID=="120")
assert(not P:Preferred({normalized="unrelated"}),"preference applies only to the same query")
assert(query("Common")[1].id=="120")
local locale=I.Locale.code
I.Locale.code="zhCN"
assert(not P:Preferred({normalized="common"}),"preference is locale-scoped")
I.Locale.code=locale
assert(handle.catalog:Update({upsert={{id="001",title="Common newcomer"}}}))
assert(query("Common")[1].id=="120","preference must survive TopK truncation after catalogue growth")
assert(#query("unrelated")==0,"preference cannot inject unrelated entries")
assert(handle:Unregister())
print("Search ranking regression passed: alias quality, stale references, route/lifecycle and remembered TopK")

local static=register("ranking.static",{{id="x",title="Neutral",aliases={"destination"}}})
local dynamic=assert(Fixture:Register({id="ranking.dynamic",apiVersion="1.0.0",version="1",title="Dynamic",query=function(request,reply)
 reply({{id="x",title="Neutral",aliases={"destination"}}})
end}))
local hits=query("destination")
assert(#hits==2 and hits[1].confidence==.98 and hits[2].confidence==.98,"same fields have same lexical score across static/dynamic")
for _,hit in ipairs(hits) do assert(hit.evidence.matchedField=="alias") end
static:Unregister();dynamic:Unregister()
print("Static/dynamic lexical score parity passed")
