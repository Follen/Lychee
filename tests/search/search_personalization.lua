local Fixture=dofile("tests/support/provider_fixture.lua")
-- Real Host integration; only the game environment is substituted.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","fixture",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end,Hide=function() end,Show=function() end} end
UIParent={}
dofile("tests/support/runtime.lua").Load("provider", {"Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Core/UserPreferences.lua", "Search/Personalization.lua", "UI/Theme.lua", "UI/TextHighlight.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local P=I.Search.Personalization
local function query(text,context) local _,rows=I.Search.Query:Query(text,context or {visible=true});return rows end
local handle=assert(Fixture:Register({id="personal.test",apiVersion="1.0.0",version="1.0.0",title="Test",
    catalog={{id="a",title="Common Alpha",category={id="tools",title="Tools"}},
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
assert(I.Providers:IsCurrent(rows[1]),"alias result remains executable after the search epoch starts")
assert(#query("huijia")==0,"no pinyin matching")
assert(#query("  ")==0,"whitespace never lists aliases")
assert(#query("回家",{visible=true,searchFilter={sourceID="other:records"}})==0)
assert(#query("回家",{visible=true,searchFilter={categoryID="other"}})==0)
assert(#query("回家",{visible=true,searchFilter={categoryID="personal.test:tools"}})==1)
assert(P:SetAlias(rows[1].ref,"Common","Common Beta"))
assert(#query("Common")==2,"alias and normal match are deduplicated")
assert(P:SetAlias(rows[1].ref,"回家","Common Beta"))
assert(handle:SetAvailability(false));assert(#query("回家")==0,"disabled provider not resurrected")
assert(handle:SetAvailability(true));assert(#query("回家")==1)
local saved=LycheeCharacterDB.palette.searchPersonalization
LycheeCharacterDB={palette={searchPersonalization=saved}}
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
LycheeCharacterDB={palette={}}
local entries={}
for index=1,128 do entries[index]={id=tostring(index),title="Performance "..index} end
local perf=assert(Fixture:Register({id="personal.perf",apiVersion="1.0.0",version="1.0.0",title="Perf",catalog=entries}))
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
    for _,field in ipairs({"searchable","searchMode","entries"}) do
        local definition={id="removed.api",title="Removed",version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}},query=function(_,reply) reply({}) end}
        definition[field]=field=="entries" and {} or field=="searchable" and false or "global"
        local value,err=Lychee:RegisterProvider(definition)
        assert(not value and err.code=="INVALID_SCHEMA","old field must be rejected: "..field)
    end
end
print("Search personalization PASS: real query, aliases, filtering, disable/reload, caps, literal highlight")
do
    local policy=I.Search.ProviderPolicy
    local function definition(id)
        return {id=id,apiVersion="1.0.0",version="1",title="Combined",scope={products={"retail"}},i18n={enUS={TITLE="Combined"}},
            searchGlobal=true,searchPrefixes={"inside"},searchKeywords={"openlist"},catalog={{id="one",title="Unique target"}}}
    end
    assert(Lychee:Supports("1.0.0"))
    local bad=definition("combined.bad");bad.apiVersion="2.0.0";assert(not Fixture:Register(bad))
    bad=definition("combined.bad");bad.searchMode="global";assert(not Fixture:Register(bad))
    bad=definition("combined.bad");bad.searchGlobal=false;bad.searchPrefixes={};bad.searchKeywords={};assert(not Fixture:Register(bad))
    local handle=assert(Fixture:Register(definition("combined.test")))
    assert(#query("Unique target")==1 and #query("inside:target")==1 and #query("openlist")==1)
    assert(policy:SetConfiguration("combined.test",false,{"within"},{"showlist"}))
    assert(#query("Unique target")==0 and #query("inside:target")==0 and #query("openlist")==0)
    assert(#query("within:target")==1 and #query("showlist")==1)
    local saved=LycheeCharacterDB.palette;LycheeCharacterDB={palette=saved};policy.owner=nil
    assert(not policy:Configuration("combined.test",definition("combined.test")) and #query("showlist")==1,"false survives saved migration")
    assert(not policy:SetConfiguration("combined.test",false,{},{}))
    assert(policy:SetConfiguration("combined.test",true,{},{}))
    assert(#query("Unique target")==1 and #query("within:target")==0 and #query("showlist")==0,"empty tables remove shortcuts")
    LycheeCharacterDB={palette=LycheeCharacterDB.palette};policy.owner=nil;assert(#query("within:target")==0,"empty tables survive reload")
    assert(policy:Reset("combined.test"));assert(#query("inside:target")==1 and #query("openlist")==1)
    assert(handle:SetAvailability(false));assert(#query("openlist")==0)
    assert(handle:SetAvailability(true));assert(#query("openlist")==1)
    assert(handle:Unregister());assert(#query("openlist")==0)
    print("Combined search policy PASS: coexistence, exact route priority, revision, saved false/empty, reset, lifecycle")
end
do
    local policy=I.Search.ProviderPolicy
    local calls=0
    local function definition(id,list)
        return {id=id,apiVersion="1.0.0",version="1",title="Scoped",
            scope={products={"retail"}},i18n={enUS={TITLE="Scoped"}},searchGlobal=false,searchPrefixes=list,
            catalog={{id="one",title="限定目标"}},query=function(_,reply) calls=calls+1;reply({}) end}
    end
    local handle=assert(Fixture:Register(definition("prefix.test",{"限定","scope"})))
    local legacyCalled,legacyFilter=0,nil
    local legacy=assert(Fixture:Register({id="prefix.legacy",apiVersion="1.0.0",version="1",title="Legacy",
        query=function(request,reply) legacyCalled=legacyCalled+1;legacyFilter=request.filter;reply({}) end}))
    local before=calls
    assert(#query("限定目标")==0 and calls==before,"global search excludes static and dynamic provider work")
    assert(legacyCalled==1 and legacyFilter==nil,"legacy callback retains unfiltered request shape")
    assert(legacy:Unregister())
    assert(#query("限定：目标")==1 and #query(" SCOPE :目标")==1)
    assert(#query("限定：")==1 and #query(" ")==0)
    local bad,err=Fixture:Register(definition("prefix.collision",{"scope"}))
    assert(not bad and err.field=="searchPrefixes.conflict")
    assert(not Fixture:Register(definition("prefix.invalid",{"bad:prefix"})))
    assert(policy:SetConfiguration("prefix.test",true,{}, {}));assert(#query("限定目标")==1)
    assert(policy:SetConfiguration("prefix.test",false,{"newprefix"},{}))
    assert(#query("限定目标")==0 and #query("newprefix:目标")==1 and #query("scope:目标")==0)
    assert(not policy:SetConfiguration("prefix.test",false,{"bad:prefix"},{}))
    assert(policy:Reset("prefix.test"));assert(#query("scope:目标")==1)
    local saved=LycheeCharacterDB.palette;LycheeCharacterDB={palette=saved};policy.owner=nil
    assert(#query("scope:目标")==1,"reload normalization retains declaration")
    assert(handle:SetAvailability(false));assert(#query("scope:目标")==0)
    assert(handle:SetAvailability(true));assert(#query("scope:目标")==1)
    assert(handle:Unregister());assert(#query("scope:目标")==0)
    print("Prefix policy PASS: global exclusion, routed search, dynamic guard, override, conflict, reset, lifecycle")
end
do
    local policy=I.Search.ProviderPolicy
    local calls,last=0,nil
    local function definition(id,words)
        return {id=id,apiVersion="1.0.0",version="1",title="Triggered",scope={products={"retail"}},i18n={enUS={TITLE="Triggered"}},
            searchGlobal=false,searchKeywords=words,searchPrefixes={},catalog={{id="one",title="Hidden dungeon"}},
            query=function(request,reply) calls=calls+1;last=request;reply({{id="live",title="Live result"}}) end}
    end
    assert(Lychee:Supports("1.0.0"))
    local old=definition("keyword.old",{"show"});old.apiVersion="2.0.0"
    assert(not Fixture:Register(old),"unsupported API versions are rejected")
    local missing=definition("keyword.missing",nil);assert(not Fixture:Register(missing))
    local handle,registrationError=Fixture:Register(definition("keyword.test",{"KEYWORD","触发"}))
    assert(handle,registrationError and tostring(registrationError.code)..":"..tostring(registrationError.field))
    assert(#query("Hidden dungeon")==0 and calls==0,"keyword provider does no work for ordinary input")
    assert(#query("keyword extra")==0 and #query("keywor")==0 and #query(" ")==0 and calls==0,"whole query required")
    assert(#query("keyword:")==0 and #query("keyword!")==0 and #query("keyword。")==0 and calls==0,"punctuation is not discarded for triggers")
    assert(#query(" KEYWORD ")==2 and last.normalized=="" and last.filter.sourceID=="keyword.test:records","trigger routes empty scoped query")
    assert(last.filter.excludedSources==nil and last.filter.policyVersion==nil,"internal filters remain private")
    assert(#query("触发")==2 and #query("keywordtest:Hidden")==0,"colon cannot bypass keyword mode")
    local bad,err=Fixture:Register(definition("keyword.other",{"触发"}))
    assert(not bad and err.field=="searchKeywords.conflict")
    local coexist=definition("keyword.prefix",{"different"});coexist.searchGlobal=false;coexist.searchPrefixes={"触发"};coexist.query=nil
    local other=assert(Fixture:Register(coexist))
    assert(#query("触发:Hidden")==1 and #query("触发")==2,"prefix and trigger namespaces are independent")
    assert(not policy:SetConfiguration("keyword.test",false,{},{"different"}),"overrides cannot steal another trigger")
    assert(other:Unregister())
    assert(not policy:SetConfiguration("keyword.test",false,{},{"bad word"}))
    for _,words in ipairs({{"a","A"},{"x:"},{string.rep("x",49)},{"1","2","3","4","5","6","7","8","9"}}) do
        assert(not policy:SetConfiguration("keyword.test",false,{},words),"trigger validation is bounded")
    end
    assert(policy:SetConfiguration("keyword.test",false,{},{"新的"}))
    assert(#query("触发")==0 and #query("新的")==2,"override replaces declaration trigger")
    local saved=LycheeCharacterDB.palette;LycheeCharacterDB={palette=saved};policy.owner=nil
    assert(#query("新的")==2,"keyword overrides survive reload")
    assert(handle:SetAvailability(false));assert(#query("新的")==0)
    assert(handle:SetAvailability(true));assert(#query("新的")==2)
    assert(handle.catalog:Update({upsert={{id="one",title="Changed dungeon"}}}));assert(#query("新的")==2)
    assert(policy:SetConfiguration("keyword.test",true,{}, {}));assert(#query("Changed dungeon")>=1)
    assert(policy:SetConfiguration("keyword.test",false,{"scoped"},{}));assert(#query("scoped:Changed")>=1 and #query("触发")==0)
    assert(policy:Reset("keyword.test"));assert(#query("触发")==2 and #query("Changed dungeon")==0)
    assert(handle:Unregister());assert(#query("触发")==0)
    LycheeCharacterDB={palette={providerSearch={{id="keyword.corrupt",mode="keyword",keywords={"bad:word"}}}}};policy.owner=nil
    assert(#policy:Data()==0,"raw saved trigger input is revalidated")
    print("Keyword policy PASS: exact routing, no global work, revision, conflict, override, mode switch, reload, lifecycle")
end
