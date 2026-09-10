-- Real Host integration; only the game environment is substituted.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","fixture",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end,Hide=function() end,Show=function() end} end
UIParent={}
for _,file in ipairs({"Bootstrap.lua","Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua",
    "Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua",
    "Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua","Core/Scheduler.lua",
    "Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua",
    "Core/UserPreferences.lua","Search/Personalization.lua","UI/Theme.lua","UI/TextHighlight.lua"}) do dofile("package/Lychee/"..file) end
local I=LycheeInternal
I.Registry:SetReady(true)
local P=I.Search.Personalization
local function query(text,context) local _,rows=I.Search.Query:Query(text,context or {visible=true});return rows end
local handle=assert(Lychee:RegisterProvider({id="personal.test",apiVersion=2,version="1.0.0",title="Test",
    entries={{id="a",title="Common Alpha",category={id="tools",title="Tools"}},
        {id="b",title="Common Beta",category={id="tools",title="Tools"}}}}))
local original=query("Common")
assert(#original==2)
P:Remember("  COMMON  ",original[2])
assert(query("common")[1].id==original[2].id,"last executed match is first")
assert(query("Alpha")[1].id=="a","memory cannot inject unrelated records")
P:ClearChoices();assert(query("Common")[1].id==original[1].id)
local ref={providerID="personal.test",entryID="b"}
assert(P:SetAlias(ref," 回家 ","Common Beta"))
ref.entryID="a"
local rows=query("回家")
assert(#rows==1 and rows[1].id=="b" and rows[1].text=="Common Beta")
assert(#query("huijia")==0,"no pinyin matching")
assert(#query("  ")==0,"whitespace never lists aliases")
assert(#query("回家",{visible=true,searchFilter={sourceID="other:records"}})==0)
assert(#query("回家",{visible=true,searchFilter={categoryID="other"}})==0)
assert(#query("回家",{visible=true,searchFilter={categoryID="personal.test:tools"}})==1)
assert(P:SetAlias(rows[1].ref,"Common","Common Beta"))
assert(#query("Common")==2,"alias and normal match are deduplicated")
assert(P:SetAlias(rows[1].ref,"回家","Common Beta"))
assert(handle:SetEnabled(false));assert(#query("回家")==0,"disabled provider not resurrected")
assert(handle:SetEnabled(true));assert(#query("回家")==1)
local saved=LycheeDB.palette.searchPersonalization
LycheeDB={palette={searchPersonalization=saved}}
assert(#query("回家")==1,"reload migration retains valid aliases")
local product=I.Search.RuntimeIdentity.Current
I.Search.RuntimeIdentity.Current=function() return {product="other"} end
assert(P:Find(rows[1].ref)==nil,"aliases separated by product")
I.Search.RuntimeIdentity.Current=product
assert(P:SetAlias(rows[1].ref,"","Common Beta"));assert(#query("回家")==0)
assert(not P:SetAlias(rows[1].ref,string.rep("中",33)))
assert(not P:SetAlias(rows[1].ref,"bad|text"))
for index=1,128 do assert(P:SetAlias({providerID="personal.test",entryID=tostring(index)},"alias"..index,"Title")) end
local ok,err=P:SetAlias({providerID="personal.test",entryID="overflow"},"overflow")
assert(not ok and err=="ALIAS_LIMIT" and #P:Aliases()==128)
for index=1,150 do P:Remember("query"..index,original[1]) end
assert(#P:Data().choices==128 and P:Data().choices[1].query=="query150")
P:Remember(string.rep("x",129),original[1]);assert(#P:Data().choices==128)
local H=Lychee.UI.TextHighlight;local color=Lychee.UI.Theme.MatchColorCode
assert(H:Format("引领潮流：乌拉","潮流")=="引领"..color.."潮流|r：乌拉")
assert(H:Format("Alpha ALPHA","alpha")==color.."Alpha|r "..color.."ALPHA|r")
assert(H:Format("abcd","abc bcd")==color.."abcd|r")
assert(H:Format("a.b",".")=="a"..color..".|rb","plain matching, no Lua patterns")
assert(H:Format("Hello","")=="Hello")
assert(H:Format("|cff00ff00Mage|r","Mage")=="|cff00ff00Mage|r","preserve semantic colors")
assert(handle:Unregister())
-- Worst bounded overlay: 128 valid aliases share the same query, 20 resolves.
LycheeDB={palette={}}
local entries={}
for index=1,128 do entries[index]={id=tostring(index),title="Performance "..index} end
local perf=assert(Lychee:RegisterProvider({id="personal.perf",apiVersion=2,version="1.0.0",title="Perf",entries=entries}))
for index=1,128 do assert(P:SetAlias({providerID="personal.perf",entryID=tostring(index)},"共同别名"..index,"Performance")) end
local function measure(enabled)
    I.Search.Personalization=enabled and P or nil
    for index=1,10 do query("共同别名") end
    collectgarbage("collect");local retained=collectgarbage("count")
    collectgarbage("stop");local allocated=collectgarbage("count");local start=os.clock();local maximum=0
    for index=1,200 do
        local before=os.clock();query("共同别名");maximum=math.max(maximum,(os.clock()-before)*1000)
    end
    local cpu=(os.clock()-start)*1000;allocated=collectgarbage("count")-allocated
    collectgarbage("restart");collectgarbage("collect");local growth=collectgarbage("count")-retained
    return cpu/200,maximum,allocated,growth
end
local before,beforeMax,beforeAlloc=measure(false)
local after,afterMax,afterAlloc,growth=measure(true)
assert(after<2 and afterMax<10,"bounded overlay exceeds offline latency budget")
assert(growth<16,"repeated queries retain unexpected memory")
print(string.format("Alias capacity benchmark (200 queries, Lua 5.1): off mean=%.3f max=%.3f alloc=%.1f KiB; on mean=%.3f max=%.3f alloc=%.1f KiB retained_delta=%.2f KiB",before,beforeMax,beforeAlloc,after,afterMax,afterAlloc,growth))
assert(perf:Unregister())
do
    local function definition(value,revision)
        return {id="restricted",apiVersion=2,minApiRevision=revision or 3,version="1",title="Restricted",
            scope={products={"retail"}},i18n={enUS={TITLE="Restricted"}},searchable=value,
            entries={{id="row",title="Hidden title",aliases={"hiddenalias"}}},
            query=function(request,reply)
                reply(request.normalized=="trigger" and {{id="row",title="Dynamic title"}} or {})
            end}
    end
    assert(Lychee:Supports(2,3))
    assert(not Lychee:RegisterProvider(definition("false")))
    assert(not Lychee:RegisterProvider(definition(false,2)))
    local restricted=assert(Lychee:RegisterProvider(definition(false)))
    assert(#query("Hidden")==0 and #query("hiddenalias")==0)
    assert(#query("",{visible=true,searchFilter={sourceID="restricted:records"}})==0)
    assert(#query("trigger")==1,"dynamic query remains available")
    local ref={providerID="restricted",entryID="row"}
    assert(I.Providers:Resolve(ref,{}),"stable references still resolve")
    P:Remove(P:Aliases()[1]);assert(P:SetAlias(ref,"privatealias"))
    assert(#query("privatealias")==0,"user aliases cannot bypass searchable=false")
    assert(restricted:Update({upsert={{id="row",title="Updated hidden"}}}))
    assert(#query("Updated")==0 and I.Providers:Resolve(ref,{}).text=="Updated hidden")
    assert(restricted:SetEnabled(false));assert(#query("trigger")==0)
    assert(restricted:SetEnabled(true));assert(#query("Updated")==0 and #query("trigger")==1)
    local indexed=I.Search.StaticIndex.entries["restricted:records:row"]
    assert(indexed and indexed.fields==nil and not indexed.indexed,"no search postings retained")
    assert(restricted:Update({remove={"row"}}));assert(not I.Providers:Resolve(ref,{}))
    assert(restricted:Unregister())
    local normal=assert(Lychee:RegisterProvider(definition(true)))
    assert(#query("Hidden")==1,"explicit true retains old behavior")
    assert(normal:Unregister())
    print("Provider searchable contract PASS: declaration, update, filter, alias, resolve, disable, dynamic")
end
print("Search personalization PASS: real query, aliases, filtering, disable/reload, caps, literal highlight")
