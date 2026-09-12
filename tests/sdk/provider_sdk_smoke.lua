local env=dofile("tests/support/sdk.lua")
local timers=env.timers
local I=LycheeInternal
local Fixture=dofile("tests/support/provider_fixture.lua")
assert(Lychee:Supports("1.0.0") and not Lychee:Supports(2,1) and not Lychee:Supports(3,2))
assert(Lychee.API_VERSION=="1.0.0" and Lychee.SDK.VERSION==Lychee.API_VERSION and Lychee.API_REVISION==nil)
assert(not Lychee:Supports(3) and not Lychee:Supports(1) and not Lychee:Supports("1.0"))
assert(not Lychee:Supports("1.0.1") and not Lychee:Supports("2.0.0") and not Lychee:Supports("1.0.0",1))
assert(not Lychee.RegisterExtension and not Lychee.RegisterSearchSource)
local ready=0
local token=assert(Lychee:RegisterReady(function() ready=ready+1 end));token:Cancel()
local deferredVersion
assert(Lychee:RegisterReady(function(info) deferredVersion=info.apiVersion;assert(info.apiRevision==nil) end))
I.Registry:SetReady(true);assert(ready==0)
assert(deferredVersion=="1.0.0","deferred ready reports the same public version")
local readyVersion
assert(Lychee:RegisterReady(function(info) readyVersion=info.apiVersion;assert(info.apiRevision==nil) end))
assert(readyVersion=="1.0.0","ready callback reports the same public version")
local function definition(id)
 return {id=id,title=id,version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}}}
end
local function expect(code,value,err)
 assert(not value and err and err.code==code,"expected "..code..", got "..tostring(err and err.code))
end
local callbacks,cancellations={},{}
local d=definition("test.dynamic")
d.query=function(request,reply) callbacks[request.raw]=reply;return function(reason) cancellations[#cancellations+1]=reason end end
d.resolve=function(id) return {id=id,title="Restored",payload={fresh=true},actions={"open"}} end
local executed=0
d.actions={open={title="Open",run=function(row) assert(row.payload.fresh);executed=executed+1;return {ok=true} end}}
local h=assert(Lychee:RegisterProvider(d))
assert(h.Update==nil and h.Settings==nil and h.SetEnabled==nil)
local function query(text,callback) local _,items=I.Search.Query:Query(text,{visible=true},nil,callback);return items end
query("first");query("second")
expect("STALE_REQUEST",callbacks.first({}))
local rows
query("third",function(items) rows=items end)
assert(callbacks.third({{entry={id="remote",title="Remote",payload={fresh=true},actions={"open"}},confidence=0.9}}))
assert(rows and #rows==1 and not I.Providers:HasPendingQuery())
assert(I.Providers:Execute(rows[1],"open",{}));assert(executed==1)
expect("STALE_REQUEST",callbacks.third({}))
assert(h:Invalidate());assert(not I.Providers:IsCurrent(rows[1]))
local restored=assert(I.Providers:Resolve({providerID=d.id,entryID="remote"}))
assert(I.Providers:Execute(restored,"open",{}))
query("timeout");local timer=timers[#timers];assert(timer.seconds==5);timer.callback()
expect("STALE_REQUEST",callbacks.timeout({}))
query("hidden");I.Search.Query:Cancel("hidden");expect("STALE_REQUEST",callbacks.hidden({}))
query("bad-score");expect("INVALID_RESULT",callbacks["bad-score"]({{entry={id="x",title="X"},confidence=2}}))
assert(not I.Providers:HasPendingQuery())
query("no-entry");expect("INVALID_SCHEMA",callbacks["no-entry"]({{confidence=1}}));assert(not I.Providers:HasPendingQuery())
query("raw-record");expect("INVALID_RESULT",callbacks["raw-record"]({{id="x",title="X"}}))
query("too-many");local many={};for n=1,257 do many[n]={entry={id=tostring(n),title="X"},confidence=1} end
assert(not callbacks["too-many"](many));assert(not I.Providers:HasPendingQuery())
query("disabled");assert(I.Registry:SetUserEnabled(d.id,false));expect("STALE_REQUEST",callbacks.disabled({}))
assert(not I.Providers:Resolve({providerID=d.id,entryID="remote"}))
assert(h:SetAvailability(false,"missing dependency"));assert(I.Registry:SetUserEnabled(d.id,true));assert(not h:GetState().enabled)
assert(h:SetAvailability(true));assert(h:GetState().enabled)
query("removed");assert(h:Unregister());expect("STALE_REQUEST",callbacks.removed({}));expect("STALE_HANDLE",h:Invalidate())
local plain=definition("test.transient");plain.query=function(_,reply) reply({{entry={id="once",title="Once"},confidence=1}}) end
local transient=assert(Lychee:RegisterProvider(plain));local item=query("Once")[1]
assert(item and not I.Providers:CanRemember(item));transient:Unregister()
for _,field in ipairs({"entries","searchable","searchMode"}) do
 local invalid=definition("invalid."..field:lower());invalid.query=function() end;invalid[field]={}
 expect("INVALID_SCHEMA",Lychee:RegisterProvider(invalid))
end
local old=definition("invalid.version");old.query=function() end;old.apiVersion=2
expect("UNSUPPORTED_API",Lychee:RegisterProvider(old))
for _,version in ipairs({1,3,"3","1.0","1.0.1","2.0.0"}) do
 old.apiVersion=version
 expect("UNSUPPORTED_API",Lychee:RegisterProvider(old))
 assert(not I.Providers.entries[old.id],"failed version checks leave no registration")
end
old.apiVersion="1.0.0";old.minApiRevision=1
expect("INVALID_SCHEMA",Lychee:RegisterProvider(old))
old.minApiRevision=nil
local recovered=assert(Lychee:RegisterProvider(old));assert(recovered:Unregister())
local removal=definition("test.self-removal");removal.query=function() end
local clean=0
removal.onEnable=function(owner) owner:Unregister();return function() clean=clean+1 end end
assert(Lychee:RegisterProvider(removal));assert(clean==1 and not I.Providers.entries[removal.id])
assert(next(I.Search.StaticIndex.entries)==nil,"Host retains no full provider catalogue")
assert(next(I.Providers.jobs)==nil)
print("Provider API 1.0.0 PASS: cancellation, deadline, malformed replies, action isolation, resolve, availability, stale identity, old API rejection")
