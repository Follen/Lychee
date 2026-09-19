function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
C_Timer={NewTimer=function(_,fn) return {Cancel=function() end} end}
dofile("tests/support/runtime.lua").Load("provider",{"Search/ProviderPolicy.lua"})
local I=LycheeInternal
assert(Lychee:Supports("1.0.0") and not Lychee:Supports(2,1))
I.Registry:SetReady(true)
local handle,catalog,enabled
local calls=0
local options={id="fixture.catalog",title="Fixture",scope={products={"retail"}},i18n={enUS={}},
    actions={open={title="Open",run=function(entry) calls=calls+1;assert(entry.payload.value==3);return {ok=true} end}},
    active=function() return enabled end,changed=function() if handle then assert(handle:Invalidate()) end end}
catalog=assert(Lychee.SDK.CreateCatalog(options))
handle=assert(Lychee:RegisterProvider({id=options.id,title="Fixture",version="1",apiVersion="1.0.0",scope=options.scope,i18n=options.i18n,actions=options.actions,
    query=function(request,reply) assert(catalog:Query(request,reply)) end,
    resolve=function(id) return catalog:Resolve(id) end,
    onEnable=function() enabled=true;return function() enabled=false;catalog:Clear() end end}))
assert(type(handle.Update)=="function", "simple entry publication remains available")
local source={id="one",title="Portal Silvermoon",payload={value=3},actions={"open"}}
assert(catalog:Update({replace={source,{id="two",title="Another result"}}}))
source.payload.value=4
assert(catalog:GetState().entries==2)
assert(next(I.Search.StaticIndex.entries)==nil)
assert(#I.Providers.entries[handle.id].records==0 and next(I.Providers.entries[handle.id].recordMap)==nil, "query-only catalog must not populate Host records")
local received=0
local receive=I.RecordCodec.ReceiveQuery
function I.RecordCodec:ReceiveQuery(...) received=received+1;return receive(self,...) end
local _,items=I.Search.Query:Query("Silvermoon",{visible=true})
I.RecordCodec.ReceiveQuery=receive
assert(received==1,"catalog results cross one Provider record-validation boundary")
assert(#items==1,"catalog result is returned through the query protocol")
assert(not handle:GetState().lastError,"query must not return the boolean reply result")
local copy=catalog:Search({normalized="Silvermoon",limit=20});copy[1].entry.payload.value=999
assert(catalog:Resolve("one").payload.value==3)
local called=false
local accepted,reason=catalog:Query({normalized="Silvermoon",limit=20},function() called=true;return true end)
assert(accepted and reason==nil and called,"ordinary callbacks receive isolated public hits")
for _,request in ipairs({{normalized="a",limit=0},{normalized="a",limit=257},{normalized="a",limit="20"},{normalized="a",filter=false},setmetatable({normalized="a"},{})}) do
 local safe,value,err=pcall(catalog.Search,catalog,request)
 assert(safe and not value and err.code=="INVALID_SCHEMA")
end
assert(I.Providers:Execute(items[1],"open",{}))
assert(calls==1)
assert(not catalog:Update({upsert={{id="bad",title="Bad",rememberable="yes"}}}))
assert(catalog:Update({upsert={{id="private",title="Not remembered",rememberable=false}}}))
assert(not I.Providers:CanRemember(I.Providers:Resolve({providerID=handle.id,entryID="private"})))
assert(catalog:Update({remove={"private"}}))

assert(catalog:Update({upsert={{id="one",title="Portal Updated"}}}))
assert(not I.Providers:IsCurrent(items[1]),"catalog update invalidates old actions")
assert(catalog:GetState().entries==2)
assert(catalog:Update({remove={"two"}}))
assert(catalog:GetState().entries==1)
assert(handle:SetAvailability(false))
assert(catalog:GetState().entries==0)
assert(not catalog:Search({normalized="",limit=20}))
assert(handle:Unregister());assert(catalog:Close())
local old={id="old.api",title="Old",version="1",apiVersion=2,scope=options.scope,i18n=options.i18n,query=function() end}
local value,err=Lychee:RegisterProvider(old);assert(not value and err.code=="UNSUPPORTED_API")
old.apiVersion="1.0.0";old.entries={};value,err=Lychee:RegisterProvider(old)
assert(value,"simple entries remain supported in API 1.0.0");assert(value:Unregister())
print("SDK catalog PASS: isolation, query, action, invalidation, delta counts, release, API rejection")

assert(not Lychee.SDK.CreateCatalog({id="bad.options",changed=true}))
assert(not Lychee.SDK.CreateCatalog({id="bad.options",unexpected=true}))
local detached=assert(Lychee.SDK.CreateCatalog({id="fixture.mismatch",actions={hidden={title="Hidden",run=function() error("must not execute") end}}}))
assert(detached:Update({replace={{id="one",title="Mismatch",actions={"hidden"}}}}))
local late,answer
local mismatch=assert(Lychee:RegisterProvider({id="fixture.mismatch",title="Mismatch",version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}},query=function(request,reply)
 late=reply; local value,err=detached:Query(request,reply);answer=err
end}))
local _,out=I.Search.Query:Query("Mismatch",{visible=true})
assert(#out==0 and answer and answer.code=="UNKNOWN_ACTION","catalog metadata cannot bypass registered capabilities")
assert(mismatch:Unregister())
local value,why=detached:Query({normalized="Mismatch",limit=20},late)
assert(not value and why.code=="STALE_REQUEST")
assert(detached:Close())
print("SDK catalog public validation / stale callback / mismatched capability PASS")

local ordinary=assert(Lychee.SDK.CreateCatalog({id="fixture.callback"}))
assert(ordinary:Update({replace={{id="one",title="Callback",payload={value=1}}}}))
local callbackCount=0
assert(ordinary:Query({normalized="callback"},function(hits)
 callbackCount=callbackCount+1
 assert(#hits==1 and hits[1].entry.title=="Callback" and hits[1].entry._extensionID==nil)
 hits[1].entry.payload.value=99
 return true
end))
assert(callbackCount==1 and ordinary:Resolve("one").payload.value==1)
assert(ordinary:Close())

assert(not Lychee.SDK.Score({normalized="bad"},{1}))
assert(not Lychee.SDK.CreateCatalog({id="bad.actions",actions=3}))

do
 local available,activeCalls,indexCalls=true,0,0
 local empty=assert(Lychee.SDK.CreateCatalog({id="fixture.empty-cost",active=function()
  activeCalls=activeCalls+1;return available
 end}))
 local search=I.Search.StaticIndex.Search
 I.Search.StaticIndex.Search=function(self,...)
  indexCalls=indexCalls+1;return search(self,...)
 end
 assert(empty:Update({replace={}}))
 local delivered,previousSearch,previousReply=0
 for n=1,30 do
  local found=assert(empty:Search({normalized="missing",limit=20}))
  assert(#found==0 and found~=previousSearch)
  found[1]="caller-owned";previousSearch=found
  assert(empty:Query({normalized="missing",limit=20},function(hits)
   delivered=delivered+1;assert(#hits==0 and hits~=previousReply)
   hits[1]="caller-owned";previousReply=hits;return true
  end))
 end
 assert(delivered==30 and indexCalls==0 and activeCalls==61,"empty catalog must validate and deliver without building match work")
 for _,request in ipairs({{normalized=false},{normalized="x",limit=0},{normalized="x",ranking={x=-1}}}) do
  local value,why=empty:Search(request);assert(not value and why,"empty search skipped validation")
  value,why=empty:Query(request,function() error("invalid empty query was delivered") end)
  assert(not value and why,"empty query skipped validation")
 end
 assert(not empty:Query({normalized="x"},false),"empty query accepted invalid callback")
 available=false
 local value,why=empty:Search({normalized="x"});assert(not value and why.code=="PROVIDER_DISABLED")
 available=true
 assert(empty:Update({upsert={{id="one",title="Needle"}}}))
 assert(#assert(empty:Search({normalized="needle"}))==1 and indexCalls==1)
 assert(empty:Update({remove={"one"}}))
 assert(#assert(empty:Search({normalized="needle"}))==0 and indexCalls==1)
 assert(empty:Invalidate());assert(#assert(empty:Search({normalized="needle"}))==0 and indexCalls==1)
 assert(empty:Close());value,why=empty:Search({normalized="x"});assert(not value and why.code=="CATALOG_CLOSED")
 I.Search.StaticIndex.Search=search
 print("Empty catalog PASS: validated delivery, no matching work, remove/rebuild and lifecycle")
end
