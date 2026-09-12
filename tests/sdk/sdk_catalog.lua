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
assert(handle.Update==nil and handle.Settings==nil and handle.SetEnabled==nil)
local source={id="one",title="Portal Silvermoon",payload={value=3},actions={"open"}}
assert(catalog:Update({replace={source,{id="two",title="Another result"}}}))
source.payload.value=4
assert(catalog:GetState().entries==2)
assert(next(I.Search.StaticIndex.entries)==nil)
assert(I.Providers.entries[handle.id].records==nil and I.Providers.entries[handle.id].recordMap==nil)
local received=0
local receive=I.RecordCodec.Receive
function I.RecordCodec:Receive(...) received=received+1;return receive(self,...) end
local _,items=I.Search.Query:Query("Silvermoon",{visible=true})
I.RecordCodec.Receive=receive
assert(received==0,"matching catalog handoff does not ingest a second business record copy")
assert(#items==1,"catalog result is returned through the query protocol")
assert(not handle:GetState().lastError,"query must not return the boolean reply result")
local copy=catalog:Search({normalized="Silvermoon",limit=20});copy[1].entry.payload.value=999
assert(catalog:Resolve("one").payload.value==3)
local called=false
local accepted,reason=catalog:Query({normalized="Silvermoon",limit=20},function() called=true end)
assert(not accepted and reason.code=="STALE_REQUEST" and not called)
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
assert(not value and err.code=="INVALID_SCHEMA","the old full-catalog registration is not supported")
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

assert(not Lychee.SDK.Score({normalized="bad"},{1}))
assert(not Lychee.SDK.CreateCatalog({id="bad.actions",actions=3}))
