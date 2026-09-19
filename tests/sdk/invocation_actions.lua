function GetTimePreciseSec() return 0 end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","today",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,UnregisterEvent=function() end,SetScript=function() end} end
C_Timer={NewTimer=function() return {Cancel=function() end} end}
dofile("tests/support/runtime.lua").Load("provider")
for _,path in ipairs({"Core/UserPreferences.lua","Core/ResultActionExecutor.lua"}) do dofile("addon/Lychee/"..path) end
local I=LycheeInternal;I.Registry:SetReady(true)
local writes,override={},nil
local function ref(value)
 return {kind="invocation",product="retail",providerID="actions.fixture",actionID="set",actionVersion=1,target={version=1,key={setting="test"}},args={value=value}}
end
local handle=assert(Lychee:RegisterProvider({id="actions.fixture",title="Actions",version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}},
 actions={set={title="Set",actionVersion=1,absolute=true,conflictKey="value",schema={value={type="boolean",required=true}},run=function(v) writes[#writes+1]=v.args.value;return {status="succeeded"} end}},
 resolveTarget=function(target) return {status="ready",target=target,identity="test"} end,
 query=function(_,reply)
  reply({{entry={id="test",title="Test",actions={
   {id="on",kind="invocation",title="On",invocation=override or ref(true)},
   {id="off",kind="invocation",title="Off",invocation=ref(false)}},primaryActionID="off"},confidence=1}})
 end}))
local p={visible=true,session=1,generation=1,RejectRow=function(_,_,why) return false,why end}
I.ResultActionExecutor:BindPalette(p)
local function query()
 local _,results=I.Search.Query:Query("test",{visible=true},1)
 return results[1] and {item=results[1],session=1,generation=1,extensionID="actions.fixture"}
end
local row=assert(query(),"per-action Invocation was rejected")
assert(I.ResultActionExecutor:ExecutePrimary(row).ok and writes[1]==false)
assert(I.ResultActionExecutor:Execute(row,"on").ok and writes[2]==true)
local recent=I.UserPreferences:GetRecent()
assert(recent[1].actionID=="set" and recent[1].args.value==true,"history saved the wrong branch")
local public=I.Providers:PublicRecord(row.item._providerRecord,"actions.fixture")
assert(public.actions[2].invocation.args.value==false)
p.generation=2;assert(not I.ResultActionExecutor:Execute(row,"on") and #writes==2);p.generation=1
for _,change in ipairs({function(r) r.providerID="other.owner" end,function(r) r.kind="command";r.args=nil end,
 function(r) r.actionVersion=2 end,function(r) r.args.value="yes" end,function(r) r.args.extra=true end,
 function(r) r.actionID="missing" end,function(r) r.extra=true end}) do
 override=ref(true);change(override);assert(not query(),"invalid per-action Invocation escaped validation")
end
assert(handle:Unregister())
print("Invocation actions PASS: independent primary/menu arguments, actual history, immutable publication, stale and malformed references")
