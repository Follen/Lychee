-- Public SDK, real Host and an independent full-scan ranking oracle.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function()end,SetScript=function()end,Hide=function()end,Show=function()end} end
UIParent={}
dofile("tests/support/runtime.lua").Load("provider",{"Search/ProviderPolicy.lua","Core/Scheduler.lua","Core/UserPreferences.lua","Search/Personalization.lua"})
local I,SDK=LycheeInternal,Lychee.SDK
I.Registry:SetReady(true)
local function query(text) local _,rows=I.Search.Query:Query(text,{visible=true});return rows end
local entries={}
for index=1,100 do entries[index]={id=string.format("%03d",index),title="Common entry "..index} end
local catalog=assert(SDK.CreateCatalog({id="rank.catalog"}))
assert(catalog:Update({replace=entries}))
local captured
local function register(id,callback,resolve)
    return assert(Lychee:RegisterProvider({id=id,title=id,version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}},query=callback,resolve=resolve}))
end
local handle=register("rank.catalog",function(request,reply)
    captured=request
    assert(catalog:Query(request,reply))
end,function(id)return catalog:Resolve(id)end)
local function item(id,provider)
    return assert(I.Providers:Resolve({providerID=provider or "rank.catalog",entryID=id},{}))
end
local preferences=I.UserPreferences
assert(preferences:Pin(item("099")))
assert(preferences:Pin(item("098")))
assert(preferences:TouchRecent(item("097")))
assert(preferences:TouchRecent(item("099")))
assert(preferences:TouchRecent(item("096")))
local rows=query("Common")
assert(#rows==20 and rows[1].id=="099" and rows[2].id=="098" and rows[3].id=="096" and rows[4].id=="097","all preferences survive truncation")
assert(captured.ranking["099"]==37 and captured.ranking["096"]==8 and captured._preferences==nil)
assert(rows[1].confidence==0.90 and rows[1].evidence.confidence==0.90,"matching evidence is unchanged")
local oracle={}
local weights={['099']=37,['098']=30,['096']=8,['097']=6}
for _,entry in ipairs(entries) do oracle[#oracle+1]={id=entry.id,score=0.90+(weights[entry.id] or 0)/1000} end
table.sort(oracle,function(a,b)return a.score>b.score or a.score==b.score and a.id<b.id end)
for index=1,20 do assert(rows[index].id==oracle[index].id,"full scan differs at "..index) end
local direct=assert(catalog:Search(captured))
for index=1,20 do assert(direct[index].entry.id==rows[index].id,"Search/Query ranking parity") end
assert(#query("unrelated")==0)
I.Search.Personalization:Remember("Common",item("100"))
assert(query("Common")[1].id=="100","same-query memory keeps priority")
assert(#query("Different")==0)
I.Search.Personalization:ClearChoices()
assert(catalog:Update({upsert={{id="exact",title="Common"}}}))
assert(query("Common")[1].id=="exact","ordinary boost cannot displace clearly stronger text match")
assert(catalog:Update({remove={"exact"}}))
local oldDB=LycheeCharacterDB
LycheeCharacterDB={}
assert(query("Common")[1].id=="001","character preferences stay isolated")
LycheeCharacterDB=oldDB
I.Search.Personalization.owner=nil
assert(query("Common")[1].id=="099","reload restores reference-only preferences")
assert(handle:SetAvailability(false));assert(#query("Common")==0)
assert(handle:SetAvailability(true));assert(query("Common")[1].id=="099")
assert(catalog:Update({remove={"099"}}));assert(query("Common")[1].id=="098","stale fixed reference cannot resurrect entry")
assert(catalog:Update({upsert={entries[99]}}))
for _,entry in ipairs(entries) do
    assert(I.Search.Personalization:SetAlias({providerID='rank.catalog',entryID=entry.id},'回家'))
end
local chinese=query('回家')
assert(#chinese==20 and chinese[1].id=='099' and chinese[2].id=='098' and chinese[3].id=='096','Chinese aliases rank before their separate TopK')
assert(chinese[1].confidence==.98)

-- Snapshot isolation: Provider mutates its request and an async query changes SV.
local pending,received
local dynamic=register("rank.dynamic",function(request,reply)
    received=request;pending=reply
end,function(id)return {id=id,title="Common dynamic "..id}end)
assert(preferences:Pin(item("099","rank.dynamic")))
query("Common")
assert(received.ranking["099"]==30 and received.ranking["098"]==nil,"no other Provider's preferences")
received.ranking["099"]=0;received.ranking["001"]=38
assert(preferences:Pin(item("001","rank.dynamic")))
assert(pending({{entry={id="001",title="Common dynamic 1"},confidence=.95},{entry={id="099",title="Common dynamic 99"},confidence=.95}}))
local position={}
for index,row in ipairs(I.Search.Query.last.results) do if row.ref.providerID=="rank.dynamic" then position[row.id]=index end end
assert(position['099']<position['001'],"Host uses its frozen original snapshot")
local late=pending
query("Different")
local ok,err=late({});assert(not ok and err.code=="STALE_REQUEST")
assert(dynamic:Unregister())

-- Real dynamic Provider applies the public ranker BEFORE selecting its Top K.
assert(handle:Unregister())
LycheeCharacterDB={}
local dynamicCatalog=register("rank.dynamic",function(request,reply)
    local rank=assert(SDK.CreateRanker(request))
    local selected={}
    for _,entry in ipairs(entries) do
        local match=SDK.Normalizer:MatchRecord(request.normalized,entry)
        if match then
            local value=rank(entry.id,match.confidence)
            local at=#selected+1
            for index,row in ipairs(selected) do if value>row.rank or value==row.rank and entry.id<row.entry.id then at=index;break end end
            if at<=request.limit then
                table.insert(selected,at,{entry=entry,confidence=match.confidence,evidence=match,rank=value})
                if #selected>request.limit then selected[#selected]=nil end
            end
        end
    end
    for _,row in ipairs(selected) do row.rank=nil end
    reply(selected)
end,function(id)return catalog:Resolve(id)end)
for _,id in ipairs({'099','098'}) do assert(preferences:Pin(item(id,'rank.dynamic'))) end
assert(preferences:TouchRecent(item('097','rank.dynamic')))
rows=query('Common')
assert(rows[1].id=='098' and rows[2].id=='099' and rows[3].id=='097')
I.Search.Personalization:Remember('Common',item('100','rank.dynamic'))
assert(query('Common')[1].id=='100')
assert(#query('unrelated')==0)
assert(dynamicCatalog:Unregister());catalog:Close()
print('Personalized ranking PASS: independent TopK oracle, public Catalog/dynamic parity, snapshots, isolation, memory, lifecycle, no unrelated injection')
