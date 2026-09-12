-- API 3 end-to-end behavior; game time is the only scheduled external input.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
local timers={}
C_Timer={NewTimer=function(seconds,callback)
 local t={seconds=seconds,callback=callback};function t:Cancel() self.cancelled=true end
 timers[#timers+1]=t;return t
end}
dofile("tests/support/runtime.lua").Load("provider",{"Core/Scheduler.lua"})
local I=LycheeInternal
local Fixture=dofile("tests/support/provider_fixture.lua")
assert(Lychee:Supports(3,1) and not Lychee:Supports(2,1) and not Lychee:Supports(3,2))
assert(not Lychee.RegisterExtension and not Lychee.RegisterSearchSource)
local ready=0
local token=assert(Lychee:RegisterReady(function() ready=ready+1 end));token:Cancel()
I.Registry:SetReady(true);assert(ready==0)
local function definition(id)
 return {id=id,title=id,version="1",apiVersion=3,minApiRevision=1,scope={products={"retail"}},i18n={enUS={}}}
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
local removal=definition("test.self-removal");removal.query=function() end
local clean=0
removal.onEnable=function(owner) owner:Unregister();return function() clean=clean+1 end end
assert(Lychee:RegisterProvider(removal));assert(clean==1 and not I.Providers.entries[removal.id])
assert(next(I.Search.StaticIndex.entries)==nil,"Host retains no full provider catalogue")
assert(next(I.Providers.jobs)==nil)
print("Provider API 3 PASS: cancellation, deadline, malformed replies, action isolation, resolve, availability, stale identity, old API rejection")
