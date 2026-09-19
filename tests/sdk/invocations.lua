-- Public Invocation contract; game time/timers are deterministic substitutes.
local clock,timers,combat,frames=0,{},false,0
function GetTimePreciseSec() return clock end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","12345","today",120100 end
function InCombatLockdown() return combat end
function CreateFrame()
 frames=frames+1
 return {RegisterEvent=function() end,UnregisterEvent=function() end,SetScript=function() end}
end
C_Timer={NewTimer=function(delay,callback)
 local timer={due=clock+delay,callback=callback}
 function timer:Cancel() self.cancelled=true end
 timers[#timers+1]=timer;return timer
end}
dofile("tests/support/runtime.lua").Load("provider")


local I=LycheeInternal
I.Registry:SetReady(true)
local initialFrames=frames
local API=Lychee.SDK.Invocation
local function expect(code,value,err)
 assert(value==nil and err and err.code==code,"expected "..code..", got "..tostring(err and err.code))
end
local schema={percent={type="number",precision=1,min=0,max=100,step=0.1,required=true},
 enabled={type="boolean",default=false},channel={type="enum",values={"master","music"},default="master"}}
local args=assert(API:NormalizeArgs(schema,{percent="30.0"}))
local patterns={{"volume ",{slot="percent"},"%"},{"音量",{slot="percent"},"%"},{"音量百分之",{slot="percent"}}}
assert(API:ParsePatterns("volume 30.0%",patterns,schema).args.percent==30)
assert(API:ParsePatterns("音量30%",patterns,schema).args.percent==30)
assert(API:ParsePatterns("音量百分之30",patterns,schema).args.percent==30)
local parsed=API:ParsePatterns("volume -1%",patterns,schema)
assert(parsed.status=="invalid" and parsed.code=="OUT_OF_RANGE" and parsed.args.percent=="-1" and parsed.raw=="volume -1%")
assert(parsed.rawOffset==nil and parsed.originalSpans==nil and parsed.raw:sub(parsed.spans.percent.start,parsed.spans.percent.finish)=="-1")
local original="  装备：音量-1%"
local routed="音量-1%"
local offset=#original-#routed
parsed=assert(API:ParsePatterns(routed,patterns,schema,offset))
assert(parsed.status=="invalid" and parsed.field=="args.percent" and parsed.rawOffset==offset and parsed.args.percent=="-1")
assert(original:sub(parsed.originalSpans.percent.start,parsed.originalSpans.percent.finish)=="-1","signed invalid input lost its original byte span")
assert(routed:sub(parsed.spans.percent.start,parsed.spans.percent.finish)=="-1","offset changed the compatible raw-relative span")
parsed=assert(API:ParsePatterns("音量%",patterns,schema,offset))
assert(parsed.status=="incomplete" and parsed.originalSpans.percent.finish==parsed.originalSpans.percent.start-1)
parsed=assert(API:ParsePatterns("音量30%",patterns,schema,offset))
assert(parsed.status=="ready" and parsed.originalSpans.percent.start==offset+#"音量"+1)
assert(API:ParsePatterns("unmatched",patterns,schema,0).rawOffset==0)
for _,invalidOffset in ipairs({-1,0.5,1025,math.huge,0/0,"1",{}}) do
 expect("INVALID_SCHEMA",API:ParsePatterns(routed,patterns,schema,invalidOffset))
end
expect("DATA_LIMIT",API:ParsePatterns(routed,patterns,schema,1024))
assert(API:ParsePatterns("volume %",patterns,schema).status=="incomplete")
assert(API:ParsePatterns("x volume 30%",patterns,schema).status=="notMatched")
assert(API:ParsePatterns("volume 30% trailing",patterns,schema).status=="notMatched")
assert(API:ParsePatterns("a*b",{{{slot="left"},"*b"},{"a*",{slot="right"}}}).status=="ambiguous")
expect("INVALID_SCHEMA",API:ParsePatterns("anything",{{{slot="a"},{slot="b"}}}))
expect("DATA_LIMIT",API:ParsePatterns(string.rep("x",1025),patterns))
assert(args.percent==30 and args.enabled==false and args.channel=="master")
assert(API:NormalizeArgs(schema,{percent=0.1+0.2}).percent==0.3)
expect("MISSING_ARGUMENT",API:NormalizeArgs(schema,{}))
expect("OUT_OF_RANGE",API:NormalizeArgs(schema,{percent="-1"}))
expect("INVALID_PRECISION",API:NormalizeArgs(schema,{percent="30.01"}))
expect("INVALID_NUMBER",API:NormalizeArgs(schema,{percent="30%"}))
expect("UNKNOWN_ARGUMENT",API:NormalizeArgs(schema,{percent=30,hidden=true}))
expect("UNKNOWN_ENUM",API:NormalizeArgs(schema,{percent=30,channel="unknown"}))
expect("INVALID_SCHEMA",API:NormalizeArgs(schema,{percent=0/0}))
expect("INVALID_SCHEMA",API:NormalizeArgs(schema,{percent=math.huge}))
expect("INVALID_SCHEMA",API:ValidateSchema({x={type="number",precision=1,unknown=true}}))
expect("INVALID_SCHEMA",API:ValidateSchema({x={type="number"}}))
expect("INVALID_STEP",API:NormalizeArgs({x={type="number",precision=2,min=-1,step=0.25}},{x="0.30"}))
assert(API:NormalizeArgs({x={type="number",precision=2,min=-1,step=0.25}},{x="-0.50"}).x==-0.5)
local cyclic={};cyclic.x=cyclic
expect("INVALID_SCHEMA",API:NormalizeArgs(schema,cyclic))
expect("INVALID_SCHEMA",API:NormalizeArgs(schema,setmetatable({},{__index=function() error("not read") end})))
expect("DATA_LIMIT",API:NormalizeArgs({x={type="string",maxLength=1024}},{x=string.rep("x",1025)}))
local listSchema={x={type="list",maxItems=4,items={type="integer"}}}
local ordered=assert(API:NormalizeArgs(listSchema,{x={3,1,3}}));assert(ordered.x[1]==3 and #ordered.x==3)
listSchema.x.set=true
local unordered=assert(API:NormalizeArgs(listSchema,{x={3,1,3}}));assert(unordered.x[1]==1 and unordered.x[2]==3 and #unordered.x==2)
expect("INVALID_ARGUMENT",API:NormalizeArgs(listSchema,{x={[1]=1,[3]=3}}))
local target={version=1,key={channel="master"}}
local ref={kind="invocation",product="retail",providerID="invoke.fixture",actionID="set",actionVersion=1,target=target,args=args}
local restored=assert(API:NormalizeStoredRef(ref));restored.title="new display"
assert(API:Equal(ref,restored));restored.args.percent=50;assert(not API:Equal(ref,restored))
restored=assert(API:NormalizeStoredRef(ref));restored.product="classic";assert(not API:Equal(ref,restored))
expect("INVALID_SCHEMA",API:NormalizeStoredRef({kind="invocation",product="retail",providerID="invoke.fixture",actionID="set",actionVersion=2,target=target,args={},callback=function() end}))

local owner,definition,runs,describes,resolves,capability,identity,mode,late,prepareLate,reenteredOp,reenteredError
local weak=setmetatable({},{__mode="v"})
local function register()
 runs,describes,resolves,capability,identity,mode=0,0,0,1,"master:1","sync"
 definition={id="invoke.fixture",apiVersion="1.0.0",version="1",title="Fixture",scope={products={"retail"}},i18n={enUS={}},
  query=function(_,reply) reply({}) end,
  resolveTarget=function(value,context,reply)
   resolves=resolves+1
   if mode=="prepare-pending" then weak.context=context;prepareLate=reply;return function() return true end end
   return {status="ready",target=value,identity=identity}
  end,
  describe=function() describes=describes+1;return {available=true,revision=capability} end,
  actions={set={title="Set",actionVersion=1,schema=schema,run=function(invocation,context,reply)
   runs=runs+1
   assert(invocation.args.percent==30 and invocation.target.key.channel=="master")
   if mode=="throw" then error("dispatch uncertain") end
   if mode=="slow" then clock=clock+6;return {status="succeeded"} end
   if mode=="pending" or mode=="cancel-confirmed" or mode=="cancel-reentry" then
    weak.context=context
    late=reply
    return function()
     if mode=="cancel-reentry" then
      mode="sync"
      local nextToken=assert(Lychee:PrepareInvocation("invoke.fixture","set",target,{percent=30},{}))
      reenteredOp,reenteredError=Lychee:InvokeInvocation(nextToken,{})
     end
     return mode=="cancel-confirmed"
    end
   end
   return {status="succeeded",changed=true}
  end}}}
 owner=assert(Lychee:RegisterProvider(definition))
end
local function prepare()
 local token=assert(Lychee:PrepareInvocation("invoke.fixture","set",target,{percent=30},{}))
 assert(next(token)==nil,"Prepared exposes authorization data")
 return token
end
local function reset()
 if owner then assert(owner:Unregister());owner=nil end
 for _,timer in ipairs(timers) do assert(timer.cancelled or timer.fired,"operation timer leaked") end
 timers={};clock=0;late,prepareLate=nil,nil
end
local function expire()
 clock=clock+5
 local pending={};for _,timer in ipairs(timers) do if not timer.cancelled and not timer.fired and timer.due<=clock then pending[#pending+1]=timer end end
 for _,timer in ipairs(pending) do timer.fired=true;timer.callback() end
end
register()
local token=prepare();assert(runs==0 and resolves==1 and describes==1)
local saved=assert(API:ToInvocation(token));saved.args.percent=50
assert(API:ToInvocation(token).args.percent==30,"Prepared data escaped by reference")
assert(API:PrepareStoredRef(API:ToInvocation(token),{}))
saved.actionVersion=2;expect("INCOMPATIBLE_ACTION_VERSION",API:PrepareStoredRef(saved,{}))
saved.actionVersion=1;saved.product="classic";expect("INCOMPATIBLE_PRODUCT",API:PrepareStoredRef(saved,{}))
expect("STALE_PREPARED",Lychee:InvokeInvocation({},{}))
local completions=0
local op=assert(Lychee:InvokeInvocation(token,{},function(result) completions=completions+1;assert(result.status=="succeeded" and result.invocation.args.percent==30) end))
assert(op:GetState().status=="succeeded" and completions==1 and runs==1 and describes==3 and resolves==3)
expect("STALE_PREPARED",Lychee:InvokeInvocation(token,{}))
assert(not op:Cancel() and completions==1)
token=prepare();capability=2
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:GetState().code=="CAPABILITY_CHANGED" and runs==1)
token=prepare();identity="master:2"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:GetState().code=="CAPABILITY_CHANGED" and runs==1)
token=prepare();combat=true
expect("COMBAT_LOCKED",Lychee:InvokeInvocation(token,{}));combat=false
assert(I.Registry:SetUserEnabled("invoke.fixture",false))
token=prepare();op=assert(Lychee:InvokeInvocation(token,{}));assert(op:GetState().status=="succeeded","search preference blocked Invocation")
reset()

register();token=prepare();mode="pending"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:GetState().status=="pending")
assert(late({status="pending"}));assert(op:GetState().status=="pending")
assert(late({status="succeeded"}));assert(not late({status="failed"}));assert(op:GetState().status=="succeeded")
reset()
register();token=prepare();mode="pending"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:Cancel() and op:GetState().status=="indeterminate")
assert(not late({status="succeeded"}))
token=prepare();expect("OPERATION_UNCERTAIN",API:Invoke(token,{}))
expect("OPERATION_UNCERTAIN",API:BeginEdit("invoke.fixture","set",target,{},{}))
reset()
register();token=prepare();mode="cancel-confirmed"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:Cancel() and op:GetState().status=="cancelled");reset()
register();token=prepare();mode="pending"
op=assert(Lychee:InvokeInvocation(token,{}));expire()
assert(op:GetState().status=="indeterminate" and op:GetState().code=="OPERATION_TIMEOUT" and not late({status="succeeded"}));reset()
register();token=prepare();mode="slow"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:GetState().status=="indeterminate" and op:GetState().code=="OPERATION_TIMEOUT");reset()
register();mode="prepare-pending"
local value,err
value,err,op=Lychee:PrepareInvocation("invoke.fixture","set",target,{percent=30},{})
expect("PENDING",value,err);expire()
assert(op:GetState().status=="failed" and op:GetState().code=="PREPARE_TIMEOUT")
assert(not prepareLate({status="ready",target=target,identity=identity}));reset()
register();mode="prepare-pending"
local delivered
value,err,op=Lychee:PrepareInvocation("invoke.fixture","set",target,{percent=30},{},function(ready) delivered=ready end)
expect("PENDING",value,err);mode="sync"
assert(prepareLate({status="ready",target=target,identity=identity}))
assert(delivered and op:GetState().status=="succeeded" and runs==0)
assert(not prepareLate({status="ready",target=target,identity=identity}))
assert(Lychee:InvokeInvocation(delivered,{}):GetState().status=="succeeded");reset()
register();token=prepare();mode="cancel-reentry"
op=assert(Lychee:InvokeInvocation(token,{}));assert(op:Cancel())
assert(op:GetState().status=="indeterminate" and not reenteredOp and reenteredError.code=="OPERATION_BUSY" and runs==1);reset()
register();mode="prepare-pending"
local function pendingContext()
 local callbackOwner={}
 weak.callbackOwner=callbackOwner
 local _,_,pending=Lychee:PrepareInvocation("invoke.fixture","set",target,{percent=30},{marker=string.rep("x",1024)},function() return callbackOwner end)
 return pending
end
op=pendingContext();assert(op:Cancel() and op:GetState().status=="cancelled")
collectgarbage("collect");collectgarbage("collect")
assert(weak.context==nil and weak.callbackOwner==nil,"cancelled prepare retained context/callback through an external reply")
assert(not prepareLate({status="ready",target=target,identity=identity}));reset()
register();token=prepare();mode="pending"
local oldCallbacks=0
op=assert(Lychee:InvokeInvocation(token,{},function() oldCallbacks=oldCallbacks+1 end))
LycheeCharacterDB={}
assert(not late({status="succeeded"}) and op:GetState().status=="indeterminate" and oldCallbacks==0)
reset()
register();token=prepare();mode="pending"
op=assert(Lychee:InvokeInvocation(token,{}));assert(owner:Unregister());owner=nil
assert(op:GetState().status=="indeterminate" and not late({status="succeeded"}));reset()
register();token=prepare();assert(owner:Unregister());owner=nil
register();expect("STALE_PREPARED",Lychee:InvokeInvocation(token,{}));reset()

-- Public registration rejects malformed contracts before committing an owner.
register()
local grants={};for index=1,64 do grants[index]=prepare() end
expect("RESOURCE_LIMIT",API:Prepare("invoke.fixture","set",target,{percent=30},{}))
assert(API:Release(grants[1]));grants[1]=prepare()
for _,grant in ipairs(grants) do assert(API:Release(grant)) end
reset()
register();assert(owner:Unregister());owner=nil
definition.actions.set.schema={x={type="number"}}
expect("INVALID_SCHEMA",Lychee:RegisterProvider(definition))
definition.actions.set.schema=schema;definition.actions.set.execution="secure"
owner=assert(Lychee:RegisterProvider(definition));token=prepare()
expect("SECURE_ACTION_REQUIRED",Lychee:InvokeInvocation(token,{}));assert(runs==0);reset()
assert(frames==initialFrames,"Invocation created a Frame")
print("invocations PASS: bounded schema/refs, opaque one-shot prepare, capability/owner checks, sync/async/cancel/timeout, secure rejection")
