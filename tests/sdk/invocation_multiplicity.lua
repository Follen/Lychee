-- One business setting can expose several parameterized result actions.
function GetTimePreciseSec() return 0 end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","69814","fixture",120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function()end,UnregisterEvent=function()end,SetScript=function()end} end
C_Timer={NewTimer=function()return {Cancel=function()end}end}
dofile("tests/support/runtime.lua").Load("provider")
for _,path in ipairs({"Core/InvocationRuntime.lua","PublicAPI/Invocation.lua"}) do dofile("addon/Lychee/"..path) end
local I=LycheeInternal
I.Registry:SetReady(true)
local accepted,why,duplicate,writes=nil,nil,false,{}
local handle=assert(Lychee:RegisterProvider({id="reference.multiplicity",title="Multiplicity",version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={}},
 actions={set={title="Set",actionVersion=1,absolute=true,conflictKey="value",schema={percent={type="integer",min=0,max=100,required=true}},
  run=function(value)writes[#writes+1]=value.args.percent;return {status="succeeded"}end}},
 resolveTarget=function(target)return {status="ready",target=target,identity="master"}end,
 query=function(_,reply)
  local rows={}
  for _,percent in ipairs({30,duplicate and 30 or 70}) do
   rows[#rows+1]={entry={id="master",title="Master volume",actions={"set"},
    invocation={kind="invocation",product="retail",providerID="reference.multiplicity",actionID="set",actionVersion=1,
     target={version=1,key={channel="master"}},args={percent=percent}}},confidence=1}
  end
  accepted,why=reply(rows)
 end}))
local _,rows=I.Search.Query:Query("volume",{visible=true},1)
assert(accepted and #rows==2 and #writes==0,"parameter variants must survive search without executing")
assert(rows[1].stableID~=rows[2].stableID and rows[1].ref.args.percent~=rows[2].ref.args.percent)
for _,item in ipairs(rows) do
 assert(I.Providers:IsCurrent(item),"same-ID variant invalidated its sibling")
 local prepared=assert(Lychee.SDK.Invocation:PrepareStoredRef(item.ref,{}))
 local operation=assert(Lychee.SDK.Invocation:Invoke(prepared,{}))
 assert(operation:GetState().status=="succeeded")
 assert(writes[#writes]==item.ref.args.percent,"restoring/executing a variant lost its arguments")
end
duplicate=true
local _,invalid=I.Search.Query:Query("volume",{visible=true},2)
assert(not accepted and why.code=="DUPLICATE_ID" and #invalid==0 and I.Search.Query.last.incomplete)
for _,item in ipairs(rows) do assert(not I.Providers:IsCurrent(item),"replaced query retained a valid old variant") end
assert(#writes==2)
I.Search.Query:Cancel("done",3);assert(handle:Unregister())
print("Invocation multiplicity PASS: same ID/different args, current membership, stable identity, restored execution, duplicate rejection and replacement")
