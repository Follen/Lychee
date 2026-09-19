-- Host events and character identity, independent of game UI rendering.
local clock,timers,frames=0,{},{}
function GetTimePreciseSec() return clock end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","today",120100 end
function InCombatLockdown() return false end
function CreateFrame()
 local f={events={},scripts={}}
 function f:RegisterEvent(name) self.events[name]=true end
 function f:UnregisterEvent(name) self.events[name]=nil end
 function f:SetScript(name,fn) self.scripts[name]=fn end
 frames[#frames+1]=f;return f
end
C_Timer={NewTimer=function(delay,callback)
 local t={due=clock+delay,callback=callback};function t:Cancel() self.cancelled=true end
 timers[#timers+1]=t;return t
end}
dofile("tests/support/runtime.lua").Load("provider")
local I=LycheeInternal;I.Registry:SetReady(true);LycheeCharacterDB={}
local API=Lychee.SDK.Invocation
local mode,late,runs="sync",nil,0
local owner=assert(Lychee:RegisterProvider({id="lifecycle.fixture",apiVersion="1.0.0",version="1",title="Lifecycle",
 scope={products={"retail"}},query=function(_,reply) reply({}) end,
 resolveTarget=function(value,_,reply)
  if mode=="prepare" then late=reply;return function() return true end end
  return {status="ready",target=value,identity="same"}
 end,
 describe=function() return {available=true,revision=1} end,
 actions={set={title="Set",actionVersion=1,absolute=true,schema={},run=function(_,_,reply)
  runs=runs+1
  if mode=="sync-run" then return {status="succeeded"} end
  late=reply;return function() return true end
 end}}}))
local function target(key) return {version=1,key={id=key or "a"}} end
local function pending(callback,context,key)
 mode="sync";local token=assert(API:Prepare("lifecycle.fixture","set",target(key),{},{}))
 return assert(API:Invoke(token,context or {},callback))
end
local function emit(event)
 for _,frame in ipairs(frames) do if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event) end end
end
local function expire()
 clock=clock+6;local batch={}
 for _,t in ipairs(timers) do if not t.cancelled and not t.fired and t.due<=clock then batch[#batch+1]=t end end
 for _,t in ipairs(batch) do t.fired=true;t.callback() end
end
local failures={}
local function test(name,fn)
 I.Invocations:CancelAll("CHARACTER_CHANGED");LycheeCharacterDB={};mode="sync"
 local ok,why=pcall(fn)
 if not ok then failures[#failures+1]=name..": "..tostring(why) end
end
test("combat without palette cancels operation",function()
 local op=pending();emit("PLAYER_REGEN_DISABLED")
 assert(op:GetState().status=="cancelled" and op:GetState().code=="COMBAT_LOCKED")
end)
test("logout closes idle edit and suppresses callback",function()
 local calls=0;local edit=assert(API:BeginEdit("lifecycle.fixture","set",target(),{onState=function() calls=calls+1 end},{}))
 emit("PLAYER_LOGOUT")
 assert(edit:GetState().status=="cancelled" and calls==0)
 assert(API:BeginEdit("lifecycle.fixture","set",target(),{},{}),"idle edit retained conflict")
end)
test("character swap with no reply suppresses deadline callback",function()
 local calls=0;local op=pending(function() calls=calls+1 end)
 LycheeCharacterDB={};expire()
 assert(op:GetState().status=="cancelled" and op:GetState().code=="CHARACTER_CHANGED" and calls==0)
end)
test("character swap before explicit cancel suppresses callback",function()
 local calls=0;local op=pending(function() calls=calls+1 end)
 LycheeCharacterDB={};assert(op:Cancel());assert(calls==0)
end)
test("old idle edit cannot publish or dispatch after character swap",function()
 local calls=0;local edit=assert(API:BeginEdit("lifecycle.fixture","set",target(),{onState=function() calls=calls+1 end},{}))
 LycheeCharacterDB={};assert(not edit:Push({}));assert(calls==0 and edit:GetState().status=="cancelled")
end)
test("cancellation snapshot does not consume reentrant operation",function()
 local nextOp;local op=pending(function() nextOp=pending(nil,nil,"new") end)
 I.Invocations:CancelAll("TEST_CANCEL")
 assert(op:GetState().status=="cancelled" and nextOp:GetState().status=="pending")
 nextOp:Cancel()
end)
test("queued edit cannot dispatch after character swap",function()
 mode="sync-run"
 local edit=assert(API:BeginEdit("lifecycle.fixture","set",target(),{mode="latest",interval=1},{}))
 assert(edit:Push({}));local before=runs
 assert(edit:Push({}));LycheeCharacterDB={};expire()
 assert(runs==before and edit:GetState().status=="cancelled")
end)
test("search close preserves dispatched operation",function()
 local op=pending(nil,{searchBound=true})
 I.Invocations:CancelSearch("SEARCH_CLOSED");assert(op:GetState().status=="pending");op:Cancel()
end)
I.Invocations:CancelAll("CHARACTER_CHANGED");owner:Unregister()
for _,t in ipairs(timers) do assert(t.cancelled or t.fired,"deadline leaked") end
assert(#failures==0,table.concat(failures,"\n"))
print("host_invocation_lifecycle PASS combat/logout/character-deadline/idle-edit/reentry/search-boundary")
