-- Real Provider/index boundaries; no UI or native action emulation is needed.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
function InCombatLockdown() return false end
dofile("tests/support/runtime.lua").Load("provider")
local I = LycheeInternal
I.Registry:SetReady(true)
local R, providers, query = I.Search.ResultSnapshot, I.Providers, I.Search.Query

local actions = {{id="open", title="Open", kind="provider"}}
local canonical = {id="one", title="Snapshot title", subtitle="Subtitle", description="Description",
    kindTitle="Kind", icon=123, payload={number=7}, category={title="Category",color="red"}, actions=actions}
I.Providers = nil
I.Search.Query = nil
local raw = R:Materialize({record=canonical,sourceID="test:records",sourceGeneration=4,sourceRevision=9,
    sourceExtensionID="test",sourceTitle="Source",confidence=0.9,evidence={kind="exact"}})
assert(raw.text=="Snapshot title" and raw.kindTitle=="Kind" and raw.subtext=="Subtitle")
assert(raw.description=="Description" and raw.category=="Category" and raw.categoryColor=="red")
assert(raw.payload==canonical.payload and raw.searchRecord==canonical)
assert(raw.interaction.actions==actions, "immutable descriptors are shared")
assert(raw.sourceGeneration==4 and raw.sourceRevision==9 and raw.providerID==nil)
assert(R:Materialize({record=canonical})==nil)
local localized = {id="two",title={enUS="Localized"},actions={{id="open",title={enUS="Localized action"}}}}
local translated=R:Materialize({record=localized,sourceID="test:records"})
assert(translated.text=="Localized" and translated.interaction.actions[1].title=="Localized action")
assert(translated.interaction.actions~=localized.actions and type(localized.actions[1].title)=="table")
I.Providers, I.Search.Query = providers, query

local record={id="one",title="Uniform snapshot",subtitle="Same subtitle",description="Same description",
    icon=123,payload={number=7},actions={"open"}}
local executed=0
local function definition()
    return {id="snapshot.fixture",title="Fixture",version="1",apiVersion=2,entries={record},
        actions={open={title="Open",run=function(value)
            assert(value.id=="one" and value.payload.number==7);executed=executed+1;return {ok=true}
        end}},query=function(_,reply) assert(reply({record})) end}
end
local handle=assert(Lychee:RegisterProvider(definition()))
local _,results=query:Query("Uniform snapshot",{visible=true})
local static=assert(results[1])
assert(static.sourceGeneration and static.sourceRevision and static._dynamicEpoch==nil)
assert(static._providerInstance and static._providerRevision and static._providerRecord)

local stamps=0
local stamp=providers.Stamp
function providers:Stamp(...) stamps=stamps+1;return stamp(self,...) end
I.Search.Query=nil
local restored=assert(providers:Resolve({providerID="snapshot.fixture",entryID="one"},{}))
assert(stamps==1, "restoration stamps identity exactly once")
local other=assert(providers:Resolve({providerID="snapshot.fixture",entryID="one"},{}))
stamps=0
local dynamic=assert(providers:Search({normalized="Uniform snapshot",limit=20},{})[1])
assert(stamps==1, "dynamic materialization stamps identity exactly once")
local again=assert(providers:Resolve({providerID="snapshot.fixture",entryID="one"},{}))
for _,item in ipairs({dynamic,again}) do
    for _,key in ipairs({"id","text","subtext","description","icon","sourceID","sourceTitle","providerID"}) do
        assert(item[key]==static[key], "display mismatch: "..key)
    end
    assert(item.payload.number==7 and item.interaction.primaryActionID=="open")
    assert(item._dynamicEpoch~=nil and item.sourceGeneration==nil and item.sourceRevision==nil)
    assert(providers:IsCurrent(item))
end
assert(not providers:IsCurrent(restored) and not providers:IsCurrent(other), "new dynamic epoch expires earlier restored snapshots")
collectgarbage("collect")
assert(providers:IsCurrent(dynamic) and providers:IsCurrent(again), "live result references survive GC")
assert(providers:Execute(dynamic,"open",{}).ok and providers:Execute(again,"open",{}).ok and executed==2)
I.Search.Query=query
providers.Stamp=stamp
assert(handle:Update({upsert={{id="one",title="Updated snapshot",actions={"open"},payload={number=7}}}}))
assert(not providers:IsCurrent(static) and not providers:IsCurrent(dynamic) and not providers:IsCurrent(again))
local previous=assert(providers:Resolve({providerID="snapshot.fixture",entryID="one"},{}))
assert(handle:Unregister())
local replacement=assert(Lychee:RegisterProvider(definition()))
assert(not providers:IsCurrent(previous), "same ID replacement never revives an old result")
assert(replacement:Unregister())
print("Result snapshot PASS: pure presentation, canonical sharing, localized actions, one stamp, static/dynamic/restore equivalence, stale lifetime")
