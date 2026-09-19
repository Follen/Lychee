local I = _G.LycheeInternal
local V = { diagnostics = {}, sequence = 0 }
I.Invocations = V
local B = I.Boundary
local copy = B.CopyPlain
local prepared = setmetatable({}, {__mode="k"})
local actionTokens = setmetatable({}, {__mode="k"})
local nextActionToken=0
local characterTokens=setmetatable({}, {__mode="k"})
local nextCharacterToken=0
local operations={}
local publicPreparations={}
local edits,conflicts,running={},{},{}
local preparedMeta = {__metatable="Lychee PreparedInvocation"}
local limits = {maxDepth=6,maxFields=32,maxNodes=256,maxBytes=16384,scalarKeys=true}
local common = {type=true,required=true,default=true,unit=true}
local numericConstraints={"min","max","step"}
local referenceLabels={"title","sourceTitle"}
local typed = {
 string={minLength=true,maxLength=true}, number={min=true,max=true,step=true,precision=true},
 integer={min=true,max=true,step=true}, boolean={}, enum={values=true},
 list={items=true,minItems=true,maxItems=true,set=true},
}
local function fail(code,field) return nil,{code=code,field=field} end
local function boundedStrings(node)
 if type(node)=="string" then return #node<=1024 end
 if type(node)=="table" then for key,child in pairs(node) do if not boundedStrings(key) or not boundedStrings(child) then return false end end end
 return true
end
local function plain(value,field)
 local owned,err=B:Copy(value,field,limits)
 if err then return nil,err end
 if not boundedStrings(owned) then return fail("DATA_LIMIT",field) end
 return owned
end
-- Read-only validation has the same graph/string budgets as copying. Callers
-- must not publish borrowed values as owned output or yield while using them.
local function checkedData(value,field)
 local ok,err=B:Validate(value,field,limits)
 if not ok then return nil,err end
 if not boundedStrings(value) then return fail("DATA_LIMIT",field) end
 return value
end
function V:CopyData(value,field) return plain(value,field) end
local function keys(value,allowed)
 if type(value)~="table" then return false end
 for key in pairs(value) do if not allowed[key] then return false end end
 return true
end
local function integer(value,min,max)
 return type(value)=="number" and value==value and value>=min and value<=max and value==math.floor(value)
end
local function actionToken(action)
 if not actionTokens[action] then nextActionToken=nextActionToken+1;actionTokens[action]=nextActionToken end
 return actionTokens[action]
end
local function identifier(value)
 return B.Access(value,"identifier") and type(value)=="string" and #value>0 and #value<=64 and value:match("^[a-z0-9][a-z0-9%.%-]*$")~=nil
end
local function equal(left,right)
 if type(left)~=type(right) then return false end
 if type(left)~="table" then return left==right end
 for key,value in pairs(left) do if not equal(value,right[key]) then return false end end
 for key in pairs(right) do if left[key]==nil then return false end end
 return true
end
local normalizeValue,scaled
local function schemaField(spec,field,item)
 if type(spec)~="table" or not typed[spec.type] then return fail("INVALID_SCHEMA",field) end
 for key in pairs(spec) do if not common[key] and not typed[spec.type][key] then return fail("INVALID_SCHEMA",field.."."..tostring(key)) end end
 if spec.required~=nil and type(spec.required)~="boolean" or spec.unit~=nil and (type(spec.unit)~="string" or #spec.unit>64) then return fail("INVALID_SCHEMA",field) end
 if spec.type=="number" or spec.type=="integer" then
  for _,key in ipairs(numericConstraints) do
   local value=spec[key]
   if value~=nil and (type(value)~="number" or math.abs(value)>1000000000 or spec.type=="integer" and value~=math.floor(value)) then return fail("INVALID_SCHEMA",field.."."..key) end
  end
  if spec.min and spec.max and spec.min>spec.max or spec.step and spec.step<=0 then return fail("INVALID_SCHEMA",field) end
  if spec.type=="number" and not integer(spec.precision,0,6) then return fail("INVALID_SCHEMA",field..".precision") end
  for _,key in ipairs(numericConstraints) do
   if spec[key]~=nil and not scaled(spec[key],spec.type=="integer" and 0 or spec.precision,field) then return fail("INVALID_SCHEMA",field.."."..key) end
  end
 elseif spec.type=="string" then
  if not integer(spec.maxLength,0,1024) or spec.minLength~=nil and not integer(spec.minLength,0,spec.maxLength) then return fail("INVALID_SCHEMA",field) end
 elseif spec.type=="enum" then
  if not B.Array(spec.values,32,field) or #spec.values==0 then return fail("INVALID_SCHEMA",field) end
  local seen={}
  for _,value in ipairs(spec.values) do
   if type(value)~="string" or #value==0 or #value>128 or seen[value] then return fail("INVALID_SCHEMA",field) end
   seen[value]=true
  end
 elseif spec.type=="list" then
  if item or not integer(spec.maxItems,0,32) or spec.minItems~=nil and not integer(spec.minItems,0,spec.maxItems)
   or spec.set~=nil and type(spec.set)~="boolean" then return fail("INVALID_SCHEMA",field) end
  local ok,err=schemaField(spec.items,field..".items",true);if not ok then return nil,err end
 end
 if spec.default~=nil then local _,err=normalizeValue(spec,spec.default,field);if err then return nil,err end end
 return true
end
scaled=function(value,precision,field)
 local scale=10^precision
 if type(value)=="string" then
  if #value>64 or not (value:match("^[+-]?%d+%.?%d*$") or value:match("^[+-]?%d*%.%d+$")) then return fail("INVALID_NUMBER",field) end
  local fraction=value:match("%.(%d*)$") or ""
  fraction=fraction:gsub("0+$","")
  if #fraction>precision then return fail("INVALID_PRECISION",field) end
  value=tonumber(value)
 end
 if type(value)~="number" or value~=value or math.abs(value)>1000000000 then return fail("INVALID_NUMBER",field) end
 local raw=value*scale
 if math.abs(raw)>9007199254740991 then return fail("DATA_LIMIT",field) end
 local nearest=math.floor(raw+0.5)
 -- A decimal integer is accepted only within the multiplication's binary
 -- representation error; fractional user input is never rounded or clamped.
 if math.abs(raw-nearest)>math.max(1,math.abs(raw))*0.00000000000000045 then return fail("INVALID_PRECISION",field) end
 return nearest,scale
end
normalizeValue=function(spec,value,field)
 if value==nil then
  if spec.default~=nil then value=copy(spec.default)
  elseif spec.required then return fail("MISSING_ARGUMENT",field)
  else return nil end
 end
 local kind=spec.type
 if kind=="number" or kind=="integer" then
  local number,scale=scaled(value,kind=="integer" and 0 or spec.precision,field)
  if number==nil then return nil,scale end
  local numeric=number/scale
  if spec.min and numeric<spec.min or spec.max and numeric>spec.max then return fail("OUT_OF_RANGE",field) end
  if spec.step then
   local step,err=scaled(spec.step,kind=="integer" and 0 or spec.precision,field)
   if not step or step<=0 then return fail("INVALID_SCHEMA",field..".step") end
   local origin=0
   if spec.min then origin,err=scaled(spec.min,kind=="integer" and 0 or spec.precision,field);if not origin then return nil,err end end
   if (number-origin)%step~=0 then return fail("INVALID_STEP",field) end
  end
  return numeric
 elseif kind=="string" then
  if type(value)~="string" then return fail("INVALID_ARGUMENT",field) end
  if #value<(spec.minLength or 0) or #value>spec.maxLength then return fail("OUT_OF_RANGE",field) end
 elseif kind=="boolean" then
  if type(value)~="boolean" then return fail("INVALID_ARGUMENT",field) end
 elseif kind=="enum" then
  local found=false;for _,choice in ipairs(spec.values) do if value==choice then found=true;break end end
  if not found then return fail("UNKNOWN_ENUM",field) end
 elseif kind=="list" then
  if not B.Array(value,spec.maxItems,field) or #value<(spec.minItems or 0) then return fail("INVALID_ARGUMENT",field) end
  local out={}
  for at,child in ipairs(value) do
   local normalized,err=normalizeValue(spec.items,child,field.."["..at.."]");if err then return nil,err end
   out[at]=normalized
  end
  if spec.set then
   table.sort(out,function(a,b) if type(a)=="boolean" then return a==false and b==true end;return a<b end)
   for at=#out,2,-1 do if equal(out[at],out[at-1]) then table.remove(out,at) end end
   if #out<(spec.minItems or 0) then return fail("INVALID_ARGUMENT",field) end
  end
  return out
 end
 return value
end
local function checkedSchema(schema)
 if type(schema)~="table" then return fail("INVALID_SCHEMA","schema") end
 for name,spec in pairs(schema) do
  if type(name)~="string" or #name==0 or #name>64 then return fail("INVALID_SCHEMA","schema") end
  local ok;ok,err=schemaField(spec,"args."..name);if not ok then return nil,err end
 end
 return schema
end
function V:ValidateSchema(input)
 local schema,err=plain(input,"schema");if err then return nil,err end
 return checkedSchema(schema)
end
function V:NormalizeArgs(schema,input)
 local checked,err=checkedData(schema,"schema");if err then return nil,err end
 checked,err=checkedSchema(checked);if not checked then return nil,err end
 local args;args,err=plain(input,"args");if err then return nil,err end
 if type(args)~="table" then return fail("INVALID_ARGUMENT","args") end
 for key in pairs(args) do if not checked[key] then return fail("UNKNOWN_ARGUMENT","args."..tostring(key)) end end
 local out={}
 for key,spec in pairs(checked) do
  local value;value,err=normalizeValue(spec,args[key],"args."..key);if err then return nil,err end
  out[key]=value
 end
 -- Defaults are data too; expansion cannot exceed the input graph budget.
 return checkedData(out,"args")
end
-- Literal segments and named slots only. No pattern engine, target expansion,
-- backtracking or normalization of the original numeric text.
function V:ParsePatterns(raw,patterns,schema,rawOffset)
 local text,err=plain(raw,"raw");if err then return nil,err end
 if type(text)~="string" then return fail("INVALID_SCHEMA","raw") end
 if rawOffset~=nil then
  if not B.Access(rawOffset,"rawOffset") or not integer(rawOffset,0,1024) then return fail("INVALID_SCHEMA","rawOffset") end
  if rawOffset+#text>1024 then return fail("DATA_LIMIT","originalRaw") end
 end
 local declarations;declarations,err=plain(patterns,"patterns");if err then return nil,err end
 if not B.Array(declarations,32) or #declarations==0 then return fail("INVALID_SCHEMA","patterns") end
 local checked
 if schema~=nil then checked,err=self:ValidateSchema(schema);if not checked then return nil,err end end
 for _,parts in ipairs(declarations) do
  if not B.Array(parts,32) or #parts==0 then return fail("INVALID_SCHEMA","patterns") end
  local slots={}
  for at,part in ipairs(parts) do
   if type(part)=="string" then if #part==0 then return fail("INVALID_SCHEMA","literal") end
   elseif not keys(part,{slot=true}) or type(part.slot)~="string" or #part.slot==0 or #part.slot>64
    or slots[part.slot] or at>1 and type(parts[at-1])=="table" or checked and not checked[part.slot] then return fail("INVALID_SCHEMA","slot")
   else slots[part.slot]=true end
  end
 end
 local chosen,fallback
 for _,parts in ipairs(declarations) do
  local cursor,args,spans,matched,missing=1,{},{},true,nil
  for at,part in ipairs(parts) do
   if type(part)=="string" then
    if text:sub(cursor,cursor+#part-1)~=part then matched=false;break end
    cursor=cursor+#part
   else
    local following=parts[at+1]
    local boundary=following and text:find(following,cursor,true) or #text+1
    if not boundary then matched=false;break end
    local value=text:sub(cursor,boundary-1)
    spans[part.slot]={start=cursor,finish=boundary-1}
    if value=="" then missing=part.slot else args[part.slot]=value end
    cursor=boundary
   end
  end
  if matched and cursor==#text+1 then
   local normalized,why=args,nil
   if checked then normalized,why=self:NormalizeArgs(checked,args) end
   local result={raw=text,args=normalized or args,spans=spans,status="ready"}
   if why then result.status=why.code=="MISSING_ARGUMENT" and "incomplete" or "invalid";result.code,result.field=why.code,why.field
   elseif missing and not checked then result.status="incomplete";result.code,result.field="MISSING_ARGUMENT",missing end
   if result.status=="ready" then
    if chosen and not equal(chosen.args,result.args) then return {status="ambiguous",raw=text,rawOffset=rawOffset,code="AMBIGUOUS_INPUT"} end
    chosen=result
   elseif not fallback then fallback=result end
  end
 end
 local result=chosen or fallback or {status="notMatched",raw=text}
 if rawOffset~=nil then
  result.rawOffset=rawOffset
  if result.spans then
   result.originalSpans={}
   for name,span in pairs(result.spans) do result.originalSpans[name]={start=rawOffset+span.start,finish=rawOffset+span.finish} end
  end
 end
 return plain(result,"parseResult")
end
function V:ValidateAction(action)
 if type(action)~="table" or not integer(action.actionVersion,1,2147483647) or type(action.run)~="function"
  or action.execution~=nil and action.execution~="ordinary" and action.execution~="secure" then return fail("INVALID_SCHEMA","action") end
 if action.absolute~=nil and type(action.absolute)~="boolean" or action.conflictKey~=nil and not identifier(action.conflictKey)
  or action.panel~=nil and not identifier(action.panel) then return fail("INVALID_SCHEMA","action") end
 return self:ValidateSchema(action.schema)
end
local targetKeys={version=true,key=true}
local function targetRef(value)
 if not keys(value,targetKeys) or not integer(value.version,1,2147483647) or type(value.key)~="table" or not next(value.key) then return fail("INVALID_TARGET","target") end
 for key in pairs(value.key) do if type(key)~="string" or #key==0 or #key>64 then return fail("INVALID_TARGET","target.key") end end
 return value
end
local refKeys={kind=true,product=true,providerID=true,actionID=true,actionVersion=true,target=true,args=true,entryID=true,title=true,icon=true,sourceTitle=true}
local function checkedReference(value)
 local err
 if not keys(value,refKeys) or not identifier(value.providerID) or type(value.product)~="string" or #value.product==0 or #value.product>32 then return fail("INVALID_REFERENCE") end
 local kind=value.kind
 if kind~="legacy-entry" and kind~="target" and kind~="command" and kind~="invocation" then return fail("INVALID_REFERENCE","kind") end
 if kind=="legacy-entry" then
  if type(value.entryID)~="string" or #value.entryID==0 or #value.entryID>1024 or value.target~=nil or value.actionID~=nil or value.actionVersion~=nil or value.args~=nil then return fail("INVALID_REFERENCE") end
 else
  if value.entryID~=nil and (type(value.entryID)~="string" or #value.entryID==0 or #value.entryID>1024) then return fail("INVALID_REFERENCE","entryID") end
  if value.target~=nil then local ok;ok,err=targetRef(value.target);if not ok then return nil,err end
  elseif kind~="command" then return fail("INVALID_TARGET") end
  if kind=="target" then
   if value.actionID~=nil or value.actionVersion~=nil or value.args~=nil then return fail("INVALID_REFERENCE") end
  elseif not identifier(value.actionID) or not integer(value.actionVersion,1,2147483647) then return fail("INVALID_REFERENCE","actionID/actionVersion") end
  if kind=="invocation" then
   if type(value.args)~="table" then return fail("INVALID_ARGUMENT","args") end
   for key in pairs(value.args) do if type(key)~="string" or #key==0 or #key>64 then return fail("INVALID_ARGUMENT","args") end end
  elseif value.args~=nil then return fail("INVALID_REFERENCE","args") end
 end
 for _,key in ipairs(referenceLabels) do if value[key]~=nil and type(value[key])~="string" then return fail("INVALID_REFERENCE",key) end end
 if value.icon~=nil and not (type(value.icon)=="string" or integer(value.icon,1,2147483647)) then return fail("INVALID_REFERENCE","icon") end
 return value
end
function V:NormalizeStoredRef(input)
 local value,err=plain(input,"reference");if err then return nil,err end
 return checkedReference(value)
end
-- Host-only: validating a reference does not require a disposable deep copy.
-- RecordCodec owns the input before attaching entryID; other users only read.
function V:_ValidateStoredRef(input)
 local value,err=checkedData(input,"reference");if err then return nil,err end
 return checkedReference(value)
end
function V:Equal(left,right)
 local a=self:NormalizeStoredRef(left);local b=self:NormalizeStoredRef(right)
 if not a or not b then return false end
 a.title,a.icon,a.sourceTitle=nil,nil,nil;b.title,b.icon,b.sourceTitle=nil,nil,nil
 if a.kind~="legacy-entry" then a.entryID=nil end
 if b.kind~="legacy-entry" then b.entryID=nil end
 return equal(a,b)
end
function V:ToInvocation(handle)
 if type(handle)~="table" or not B.Access(handle,"prepared") then return fail("STALE_PREPARED") end
 local state=prepared[handle]
 if not state then return fail("STALE_PREPARED") end
 return copy(state.invocation)
end
function V:Release(handle)
 if type(handle)~="table" or not B.Access(handle,"prepared") then return false end
 local exists=prepared[handle]~=nil;prepared[handle]=nil;return exists
end

local function available(entry)
 return entry and I.Providers.entries[entry.id]==entry and I.Registry:IsEnabled(entry.id)
  and I.Search.RuntimeIdentity:MatchesScope(entry.definition.scope)
end
local function currentProduct() return I.Search.RuntimeIdentity:Current().product end
local function conflictReason(providerID,key,target,editing)
 for at=#conflicts,1,-1 do
  local row=conflicts[at];local owner=I.Providers.entries[row.providerID]
  if not available(owner) or owner.instanceToken~=row.instance or owner.lifecycleEpoch~=row.lifecycle then table.remove(conflicts,at)
  elseif row.providerID==providerID and row.key==key and equal(row.target,target) then return "OPERATION_UNCERTAIN" end
 end
 for state in pairs(edits) do
  if state~=editing and state.providerID==providerID and state.key==key and equal(state.target,target) then return "OPERATION_BUSY" end
 end
 local count=0
 for state in pairs(running) do
  count=count+1
  if state.providerID==providerID and state.key==key and equal(state.target,target) then return "OPERATION_BUSY" end
 end
 -- Reserve space for every potentially indeterminate completion before dispatch.
 if count+#conflicts>=64 then return "RESOURCE_LIMIT" end
end
local function characterToken()
 local root=rawget(_G,"LycheeCharacterDB")
 if type(root)~="table" then return 0 end
 if not characterTokens[root] then nextCharacterToken=nextCharacterToken+1;characterTokens[root]=nextCharacterToken end
 return characterTokens[root]
end
local function diagnostic(code,providerID)
 V.diagnostics[#V.diagnostics+1]={code=code,providerID=providerID}
 if #V.diagnostics>32 then table.remove(V.diagnostics,1) end
end
local live
local function operation(entry,context,callback,preparing,onFinish)
 local owned,err=plain(context or {},"context");if err then return nil,err end
 if type(owned)~="table" or owned.deadline~=nil and type(owned.deadline)~="number" then return fail("INVALID_SCHEMA","context.deadline") end
 if callback~=nil and type(callback)~="function" then return fail("INVALID_CALLBACK") end
 if not available(entry) then return fail("PROVIDER_UNAVAILABLE") end
 local ownerID=entry.id
 local now=I.Providers:QueryTime()
 owned.deadline=math.min(owned.deadline or now+5,now+5)
 if owned.deadline<=now then return fail("PREPARE_TIMEOUT") end
 local state={entry=entry,context=owned,callback=callback,status="pending",preparing=preparing,product=currentProduct(),character=characterToken(),deadline=owned.deadline,onFinish=onFinish}
 V.sequence=V.sequence+1;state.id=V.sequence
 local handle={}
 local finish
 local function stop(reason)
  if state.done or state.closing then return false end
  if state.character~=characterToken() then state.callback=nil;reason="CHARACTER_CHANGED" end
  state.closing=true
  if state.release then state.release();state.release=nil end
  local cancel=state.cancel;state.cancel=nil
  local confirmed=false
  if cancel then local ok,value=pcall(cancel,reason);confirmed=ok and value==true end
  state.closing=false
  finish({status=state.dispatched and not confirmed and "indeterminate" or "cancelled",code=reason})
  return true
 end
 finish=function(result,token)
  if state.done or state.closing then return false end
  state.done=true;state.status=result.status;state.result=result;state.prepared=token
  operations[state]=nil
  local finalized=state.onFinish;state.onFinish=nil
  if finalized then finalized(result) end
  if state.release then state.release();state.release=nil end
  local callback,scope,cancel=state.callback,state.scope,state.cancel
  state.callback,state.scope,state.cancel,state.entry,state.context=nil,nil,nil,nil,nil
  if scope then I.Resources:Close(scope,"complete") end
  if cancel then pcall(cancel,"complete") end
  if result.status~="succeeded" then diagnostic(result.code or result.status,ownerID) end
  if callback and state.character==characterToken() then
   if preparing then pcall(callback,token,token and nil or {code=result.code or result.status,field=result.field})
   else pcall(callback,copy(result)) end
  end
  return true
 end
 state.finish=finish
 state.stop=stop
 operations[state]=true
 function handle:Cancel() return stop("CANCEL_REQUESTED") end
 function handle:GetState() return copy(state.result or {status=state.status,operationID=state.id}) end
 state.handle=handle
 if not entry.resources then entry.resources=I.Resources:Create(function() return available(entry) end) end
 local scope;scope,err=I.Resources:Create(function() return not state.done and available(entry) end,nil,entry.resources)
 if not scope then operations[state]=nil;return nil,err end
 state.scope=scope
 local cleanup;cleanup,err=scope:Own("operation",function(reason) if not state.done then stop(reason or "OWNER_UNAVAILABLE") end end)
 if not cleanup then operations[state]=nil;I.Resources:Close(scope);return nil,err end
 local timer;timer,err=scope:After("deadline",math.max(0,state.deadline-I.Providers:QueryTime()),function()
  live(state)
 end)
 if not timer then finish({status="failed",code=err.code});return nil,err end
 return state
end
live=function(state)
 if state.done or state.closing then return false end
 if state.character~=characterToken() then state.callback=nil;state.stop("CHARACTER_CHANGED");return false end
 if not available(state.entry) or state.product~=currentProduct() then state.stop("OWNER_UNAVAILABLE");return false end
 if state.dispatched and InCombatLockdown and InCombatLockdown() then state.stop("COMBAT_LOCKED");return false end
 if I.Providers:QueryTime()>=state.deadline then
  if state.dispatched then state.stop("OPERATION_TIMEOUT") else state.finish({status="failed",code="PREPARE_TIMEOUT"}) end
  return false
 end
 return true
end
local function callStage(state,fn,args,receive)
 if not live(state) then state.finish({status="failed",code="PROVIDER_UNAVAILABLE"});return end
 local replied,stageState=false,state
 local function release() receive,args,fn,stageState=nil,nil,nil,nil end
 state.release=release
 local function reply(value)
  local active=stageState
  if replied or not active or not live(active) then return false end
  replied=true
  local deliver=receive
  release();if active.release==release then active.release=nil end
  local cancel=active.cancel;active.cancel=nil
  if cancel then pcall(cancel,"complete") end
  if not live(active) then return false end
  deliver(value);return true
 end
 args[#args+1]=reply
 local ok,value=pcall(fn,unpack(args))
 args,fn=nil,nil
 if not ok then state.finish({status="failed",code="CALLBACK_ERROR"})
 elseif type(value)=="function" then
  if replied or state.done then pcall(value,"complete") else state.cancel=value end
 elseif value~=nil then if not replied then reply(value) end end
end
local descriptionKeys={available=true,revision=true,schema=true,code=true}
local resolvedKeys={status=true,target=true,identity=true}
local function revision(value) return type(value)=="string" and #value>0 and #value<=128 or type(value)=="number" and value==value and math.abs(value)<math.huge end
local function targetResult(input)
 local value,why=plain(input,"targetResult")
 if why or not keys(value,resolvedKeys) then return nil,why and why.code or "INVALID_TARGET" end
 if value.status~="ready" then
  local status=value.status
  return nil,(status=="notReady" or status=="temporarilyUnavailable" or status=="deleted" or status=="incompatible") and status or "INVALID_TARGET"
 end
 if not targetRef(value.target) or not revision(value.identity) then return nil,"INVALID_TARGET" end
 return value
end
-- Read-only target restoration uses the same bounded operation lifetime as preparation.
function V:ResolveTarget(providerID,target,context,reply)
 local entry=I.Providers.entries[providerID]
 if not available(entry) or not entry.definition.resolveTarget then return fail("TARGET_VIEW_UNAVAILABLE") end
 local owned,err=plain(target,"target");if err then return nil,err end
 local ok;ok,err=targetRef(owned);if not ok then return nil,err end
 local state;state,err=operation(entry,context,reply,true);if not state then return nil,err end
 callStage(state,entry.definition.resolveTarget,{owned,copy(state.context)},function(input)
  local value,why=targetResult(input)
  if not value then state.finish({status="failed",code=why});return end
  state.finish({status="succeeded"},value.target)
 end)
 if state.done then return state.prepared,state.prepared and nil or {code=state.result.code},state.handle end
 return nil,{code="PENDING"},state.handle
end
function V:Prepare(providerID,actionID,target,args,context,reply)
 if not identifier(providerID) or not identifier(actionID) then return fail("INVALID_SCHEMA","providerID/actionID") end
 local entry=I.Providers.entries[providerID]
 local action=entry and entry.definition.actions and entry.definition.actions[actionID]
 if not available(entry) or not action then return fail("ACTION_UNAVAILABLE") end
 local schema,err=self:ValidateAction(action);if not schema then return nil,err end
 local ownedTarget;ownedTarget,err=plain(target,"target");if err then return nil,err end
 local ok;ok,err=targetRef(ownedTarget);if not ok then return nil,err end
 local ownedArgs;ownedArgs,err=plain(args,"args");if err then return nil,err end
 local state;state,err=operation(entry,context,reply,true);if not state then return nil,err end
 local function describe(identity,resolved)
  local function ready(input)
   local desc,why=plain(input,"description")
   if why or not keys(desc,descriptionKeys) or type(desc.available)~="boolean" or not revision(desc.revision) or desc.code~=nil and type(desc.code)~="string" then state.finish({status="failed",code=why and why.code or "INVALID_DESCRIPTION"});return end
   if not desc.available then state.finish({status="failed",code=desc.code or "ACTION_UNAVAILABLE"});return end
   local normalized;normalized,why=V:NormalizeArgs(desc.schema or schema,ownedArgs)
   if why then state.finish({status="failed",code=why.code,field=why.field});return end
   local invocation={kind="invocation",product=state.product,providerID=providerID,actionID=actionID,actionVersion=action.actionVersion,target=resolved,args=normalized}
   invocation,why=V:NormalizeStoredRef(invocation)
   if not invocation then state.finish({status="failed",code=why.code});return end
   local handle=setmetatable({},preparedMeta)
   local count=0
   for token,grant in pairs(prepared) do
    local owner=I.Providers.entries[grant.invocation.providerID]
    if not available(owner) or owner.instanceToken~=grant.instance or owner.lifecycleEpoch~=grant.lifecycle or grant.character~=characterToken() then prepared[token]=nil
    else count=count+1 end
   end
   if count>=64 then state.finish({status="failed",code="RESOURCE_LIMIT"});return end
   prepared[handle]={invocation=invocation,instance=entry.instanceToken,lifecycle=entry.lifecycleEpoch,actionToken=actionToken(action),character=state.character,
    targetIdentity=copy(identity),capability=copy(desc),schema=copy(schema),execution=action.execution or "ordinary"}
   state.finish({status="succeeded"},handle)
  end
  if entry.definition.describe then callStage(state,entry.definition.describe,{copy(resolved),actionID,copy(state.context)},ready)
  else ready({available=true,revision=action.actionVersion}) end
 end
 if entry.definition.resolveTarget then
  callStage(state,entry.definition.resolveTarget,{copy(ownedTarget),copy(state.context)},function(input)
   local value,why=targetResult(input)
   if not value then state.finish({status="failed",code=why});return end
   describe(value.identity,value.target)
  end)
 else describe(ownedTarget,ownedTarget) end
 if state.done then
  if state.prepared then return state.prepared,nil,state.handle end
  return nil,{code=state.result.code,field=state.result.field},state.handle
 end
 return nil,{code="PENDING"},state.handle
end
local resultKeys={status=true,code=true,value=true,changed=true}
local function invoke(handle,context,reply,editing)
 if type(handle)~="table" or not B.Access(handle,"prepared") then return fail("STALE_PREPARED") end
 local grant=prepared[handle]
 if not grant then return fail("STALE_PREPARED") end
 prepared[handle]=nil
 local invocation=grant.invocation
 local entry=I.Providers.entries[invocation.providerID]
 if not available(entry) or entry.instanceToken~=grant.instance or entry.lifecycleEpoch~=grant.lifecycle or invocation.product~=currentProduct() or grant.character~=characterToken() then return fail("STALE_PREPARED") end
 if InCombatLockdown and InCombatLockdown() then return fail("COMBAT_LOCKED") end
 if grant.execution=="secure" then return fail("SECURE_ACTION_REQUIRED") end
 local action=entry.definition.actions[invocation.actionID]
 if not action then return fail("ACTION_UNAVAILABLE") end
 local key=action.conflictKey or invocation.actionID
 local blocked=conflictReason(entry.id,key,invocation.target,editing)
 if blocked then return fail(blocked) end
 if editing then editing.target=copy(invocation.target) end
 local lock={providerID=entry.id,instance=entry.instanceToken,lifecycle=entry.lifecycleEpoch,key=key,target=copy(invocation.target)}
 running[lock]=true
 local state,err=operation(entry,context,reply,false,function(result)
  running[lock]=nil
  if result.status=="indeterminate" then conflicts[#conflicts+1]=lock end
 end)
 if not state then running[lock]=nil;return nil,err end
 local function dispatch(fresh,why)
  if not live(state) then return end
  if not fresh then state.finish({status="failed",code=why and why.code or "STALE_PREPARED"});return end
  local checked=prepared[fresh];prepared[fresh]=nil
  if not checked or checked.instance~=grant.instance or checked.lifecycle~=grant.lifecycle or checked.actionToken~=grant.actionToken
   or checked.execution~=grant.execution or not equal(checked.targetIdentity,grant.targetIdentity)
   or not equal(checked.capability,grant.capability) or not equal(checked.schema,grant.schema)
   or not equal(checked.invocation,invocation) then state.finish({status="failed",code="CAPABILITY_CHANGED"});return end
  if InCombatLockdown and InCombatLockdown() then state.finish({status="failed",code="COMBAT_LOCKED"});return end
  local action=entry.definition.actions[invocation.actionID]
  state.cancel=nil
  state.dispatched=true
  local callbackState,callbackInvocation=state,invocation
  state.release=function() callbackState,callbackInvocation=nil,nil end
  local function complete(input)
   local active=callbackState
   if not active or not live(active) then return false end
   local result,invalid=plain(input,"result")
   if not live(active) then return false end
   if invalid or not keys(result,resultKeys) or result.code~=nil and type(result.code)~="string" or result.changed~=nil and type(result.changed)~="boolean" then active.finish({status="indeterminate",code="INVALID_RESULT"});return false end
   if result.status=="pending" then return true end
   if result.status~="succeeded" and result.status~="failed" and result.status~="cancelled" and result.status~="indeterminate" then active.finish({status="indeterminate",code="INVALID_RESULT"});return false end
   result.operationID=active.id
   if result.status=="succeeded" then result.invocation=copy(callbackInvocation) end
   return active.finish(result)
  end
  local ok,value=pcall(action.run,copy(invocation),copy(state.context),complete)
  if not ok then state.finish({status="indeterminate",code="CALLBACK_ERROR"})
  elseif type(value)=="function" then if state.done then pcall(value,"complete") else state.cancel=value end
  elseif value~=nil then complete(value) end
 end
 local _,why,preparation=V:Prepare(invocation.providerID,invocation.actionID,invocation.target,invocation.args,state.context,dispatch)
 if not state.done and not state.dispatched and preparation then state.cancel=function() preparation:Cancel();return true end
 elseif not preparation and why then state.finish({status="failed",code=why.code}) end
 return state.handle
end
function V:Invoke(handle,context,reply) return invoke(handle,context,reply) end
function V:PrepareStoredRef(input,context,reply)
 local ref,err=self:NormalizeStoredRef(input);if not ref then return nil,err end
 if ref.kind~="invocation" then return fail("INCOMPLETE_INVOCATION","kind") end
 if ref.product~=currentProduct() then return fail("INCOMPATIBLE_PRODUCT","product") end
 local entry=I.Providers.entries[ref.providerID]
 local action=entry and entry.definition.actions and entry.definition.actions[ref.actionID]
 if not action then return fail("ACTION_UNAVAILABLE") end
 if action.actionVersion~=ref.actionVersion then return fail("INCOMPATIBLE_ACTION_VERSION","actionVersion") end
 return self:Prepare(ref.providerID,ref.actionID,ref.target,ref.args,context,reply)
end
-- Public explicit requests own one bounded load/readiness/prepare subscription.
-- Each phase inherits the original deadline and cannot restart its five seconds.
function V:PrepareAvailable(providerID,actionID,target,args,context,reply,actionVersion)
 if not identifier(providerID) or not identifier(actionID) then return fail("INVALID_SCHEMA","providerID/actionID") end
 if reply~=nil and type(reply)~="function" then return fail("INVALID_CALLBACK") end
 local owned,err=plain(context or {},"context");if err then return nil,err end
 if type(owned)~="table" or owned.deadline~=nil and type(owned.deadline)~="number" then return fail("INVALID_SCHEMA","context.deadline") end
 local ownedTarget;ownedTarget,err=plain(target,"target");if err then return nil,err end
 local valid;valid,err=targetRef(ownedTarget);if not valid then return nil,err end
 local ownedArgs;ownedArgs,err=plain(args,"args");if err then return nil,err end
 if type(ownedArgs)~="table" then return fail("INVALID_ARGUMENT","args") end
 local now=I.Providers:QueryTime();owned.deadline=math.min(owned.deadline or now+5,now+5)
 if owned.deadline<=now then return fail("PREPARE_TIMEOUT") end
 local count=0;for _ in pairs(publicPreparations) do count=count+1 end
 if count>=64 then return fail("RESOURCE_LIMIT") end
 local state={context=owned,target=ownedTarget,args=ownedArgs,callback=reply,character=characterToken(),product=currentProduct()}
 publicPreparations[state]=true
 local handle={};state.handle=handle
 local function finish(token,problem)
  if state.done then if token then V:Release(token) end;return end
  state.done=true;state.prepared,state.error=token,problem;publicPreparations[state]=nil
  local callback,stage=state.callback,state.stage
  state.callback,state.stage,state.context,state.target,state.args=nil,nil,nil,nil,nil
  if stage then stage:Cancel() end
  if callback and state.character==characterToken() then pcall(callback,token,problem) end
 end
 function handle:Cancel(reason)
  if state.done then return false end
  if reason=="CHARACTER_CHANGED" then state.callback=nil end
  state.cancelled=true
  finish(nil,{code=reason or "CANCEL_REQUESTED"});return true
 end
 function handle:GetState() return {status=not state.done and "pending" or state.prepared and "succeeded" or state.cancelled and "cancelled" or "failed",code=state.error and state.error.code} end
 local function current()
  if state.done then return false end
  if state.character~=characterToken() or state.product~=currentProduct() then state.callback=nil;handle:Cancel("CHARACTER_CHANGED");return false end
  if I.Providers:QueryTime()>=state.context.deadline then finish(nil,{code="PREPARE_TIMEOUT"});return false end
  return true
 end
 local function attach(stage,problem,phase)
  if state.done or state.phase~=phase then if stage then stage:Cancel() end
  elseif not stage then finish(nil,problem or {code="PREPARE_FAILED"}) else state.stage=stage end
 end
 local function prepare()
  if not current() then return end
  state.stage=nil;state.phase="prepare"
  local entry=I.Providers.entries[providerID]
  local action=entry and entry.definition.actions and entry.definition.actions[actionID]
  if actionVersion and (not action or action.actionVersion~=actionVersion) then finish(nil,{code="INCOMPATIBLE_ACTION_VERSION"});return end
  local _,problem,stage=V:Prepare(providerID,actionID,state.target,state.args,state.context,function(token,why)
   if not current() then if token then V:Release(token) end;return end
   finish(token,why)
  end)
  attach(stage,problem,"prepare")
 end
 local function readiness()
  if not current() then return end
  state.stage=nil;state.phase="readiness"
  local entry=I.Providers.entries[providerID]
  if not available(entry) then finish(nil,{code="PROVIDER_UNAVAILABLE"});return end
  if not entry.definition.prepare then prepare();return end
  if not I.Preparation then finish(nil,{code="PREPARATION_UNAVAILABLE"});return end
  local phase=state.phase
  local stage,problem=I.Preparation:Ensure({providerID},{scope=state.context.scope or "invocation",intent=state.context.searchBound and "query" or "visible"},state.context.deadline,function(result)
   if not current() or state.phase~=phase then return end
   if result.ready and result.ready[providerID] then prepare()
   else finish(nil,{code=result.failed and result.failed[providerID] or "PREPARATION_FAILED"}) end
  end)
  attach(stage,problem,phase)
 end
 if I.Providers.entries[providerID] then readiness()
 elseif I.AddonLoader then
  state.phase="loading"
  local stage,problem=I.AddonLoader:Ensure({providerID},owned.deadline,function(result)
   if not current() or state.phase~="loading" then return end
   if result.ready and result.ready[providerID] then readiness()
   else finish(nil,{code=result.failed and result.failed[providerID] or "PROVIDER_UNAVAILABLE"}) end
  end)
  attach(stage,problem,"loading")
 else finish(nil,{code="ACTION_UNAVAILABLE"}) end
 if state.done then return state.prepared,state.error,handle end
 return nil,{code="PENDING"},handle
end
-- Host lifecycle seam; snapshot first so cancellation cannot consume new work.
function V:CancelAll(reason)
 for handle in pairs(prepared) do prepared[handle]=nil end
 local editing={};for state in pairs(edits) do editing[#editing+1]=state end
 local pending={};for state in pairs(operations) do pending[#pending+1]=state end
 local preparing={};for state in pairs(publicPreparations) do preparing[#preparing+1]=state end
 for _,state in ipairs(preparing) do state.handle:Cancel(reason or "HOST_UNAVAILABLE") end
 for _,state in ipairs(editing) do state.handle:Cancel(reason or "HOST_UNAVAILABLE") end
 for _,state in ipairs(pending) do
  if reason=="CHARACTER_CHANGED" then state.callback=nil end
  state.stop(reason or "HOST_UNAVAILABLE")
 end
end
function V:CancelSearch(reason)
 local preparing={}
 for state in pairs(publicPreparations) do if state.context and state.context.searchBound then preparing[#preparing+1]=state end end
 local pending={}
 for state in pairs(operations) do
  if not state.dispatched and state.context and state.context.searchBound then pending[#pending+1]=state end
 end
 for _,state in ipairs(preparing) do state.handle:Cancel(reason or "SEARCH_CHANGED") end
 for _,state in ipairs(pending) do state.stop(reason or "SEARCH_CHANGED") end
end
function V:BeginEdit(providerID,actionID,target,options,context)
 local entry=I.Providers.entries[providerID]
 local action=entry and entry.definition.actions and entry.definition.actions[actionID]
 if not available(entry) or not action or not action.actionVersion then return fail("ACTION_UNAVAILABLE") end
 local opts,err=B:Copy(options or {},"edit",{maxDepth=3,maxFields=8,maxNodes=32,maxBytes=2048,scalarKeys=true,callbacks={onState=true}})
 if err then return nil,err end
 if not keys(opts,{mode=true,interval=true,onState=true}) or opts.onState~=nil and type(opts.onState)~="function"
  or opts.mode~=nil and opts.mode~="latest" and opts.mode~="single"
  or opts.interval~=nil and (type(opts.interval)~="number" or opts.interval<0 or opts.interval>1) then return fail("INVALID_SCHEMA","edit") end
 if opts.mode=="latest" and action.absolute~=true then return fail("NON_IDEMPOTENT_ACTION") end
 local ownedTarget;ownedTarget,err=plain(target,"target");if err then return nil,err end
 local valid;valid,err=targetRef(ownedTarget);if not valid then return nil,err end
 local ownedContext;ownedContext,err=plain(context or {},"context");if err then return nil,err end
 local conflictKey=action.conflictKey or actionID
 local blocked=conflictReason(providerID,conflictKey,ownedTarget)
 if blocked then return fail(blocked) end
 local count=0
 for state in pairs(edits) do
  count=count+1
  if state.providerID==providerID and state.key==conflictKey and equal(state.target,ownedTarget) then return fail("OPERATION_BUSY") end
 end
 if count>=64 or #conflicts>=64 then return fail("RESOURCE_LIMIT") end
 local scope;scope,err=I.Providers:CreateOperationResources(providerID);if not scope then return nil,err or {code="PROVIDER_UNAVAILABLE"} end
 local state={providerID=providerID,key=conflictKey,target=ownedTarget,context=ownedContext,scope=scope,status="editing",character=characterToken(),nextAllowed=0}
 edits[state]=true
 local handle={}
 state.handle=handle
 local function snapshot()
  return copy({status=state.status,draft=state.draft,lastApplied=state.lastInvocation and state.lastInvocation.args,pending=state.pending==true,code=state.code})
 end
 local function notify()
  if state.character~=characterToken() then opts.onState=nil end
  if state.notifying or not opts.onState then return end
  state.notifying=true;pcall(opts.onState,snapshot());state.notifying=nil
 end
 local function finish()
  if state.finished or state.pending then return end
  state.finished=true;edits[state]=nil
  if state.lastInvocation and state.character==characterToken() and I.UserPreferences then I.UserPreferences:TouchInvocation(state.lastInvocation,{title=action.title}) end
  local resource=state.scope;state.scope=nil
  state.queued,state.context,state.target,state.operation=nil,nil,nil,nil
  if resource then I.Resources:Close(resource,"edit-finished") end
  notify();opts.onState=nil
  entry,action,ownedTarget,ownedContext=nil,nil,nil,nil
 end
 local dispatch,schedule
 function handle:GetState() return snapshot() end
 function handle:Cancel(reason)
  if state.character~=characterToken() then reason="CHARACTER_CHANGED" end
  if state.finished or state.closed and reason~="CHARACTER_CHANGED" then return false end
  if reason=="CHARACTER_CHANGED" then opts.onState=nil;state.character=-1;state.pending=false end
  state.closed=true;state.status="cancelled";state.code=reason
  state.queued=nil
  if state.timer then state.timer:Cancel();state.timer=nil end
  if state.phase=="preparing" and state.operation then state.operation:Cancel() end
  if state.character~=characterToken() or not available(entry) then state.pending=false;state.operation=nil end
  notify();opts.onState=nil
  finish();return true
 end
 schedule=function()
  if state.character~=characterToken() then handle:Cancel("CHARACTER_CHANGED");return end
  if state.closed or state.finished then finish();return end
  if state.pending or state.timer then return end
  if not state.queued then if state.finalRequested then state.status="succeeded";finish() end;return end
  local delay=math.max(0,state.nextAllowed-I.Providers:QueryTime())
  if delay==0 and not state.dispatchedOnce then dispatch();return end
  local timer,why=state.scope:After("edit-next",delay,function() state.timer=nil;dispatch() end)
  if not timer then state.status="failed";state.code=why.code;state.closed=true;finish() else state.timer=timer end
 end
 dispatch=function()
  if state.character~=characterToken() then handle:Cancel("CHARACTER_CHANGED");return end
  if state.closed or state.finished or state.pending or not state.queued then return end
  local args=state.queued;state.queued=nil;state.pending=true;state.phase="preparing";state.dispatchedOnce=true
  local dispatchContext=copy(state.context)
  local now=I.Providers:QueryTime();dispatchContext.deadline=math.min(dispatchContext.deadline or now+5,now+5)
  notify()
  if state.character~=characterToken() then handle:Cancel("CHARACTER_CHANGED");return end
  if state.closed then state.pending=false;finish();return end
  local function completed(result)
   state.pending=false;state.operation=nil;state.phase=nil
   state.nextAllowed=I.Providers:QueryTime()+(opts.interval or 0)
   if result.status=="succeeded" then state.lastInvocation=result.invocation
   else
    state.status=result.status;state.code=result.code;state.closed=true;state.queued=nil
   end
   notify();schedule()
  end
  local _,why,preparation=V:Prepare(providerID,actionID,ownedTarget,args,dispatchContext,function(token,problem)
   if state.closed then if token then V:Release(token) end;state.pending=false;finish();return end
   if not token then completed({status="failed",code=problem and problem.code});return end
   state.phase="dispatching"
   local operation,error=invoke(token,dispatchContext,completed,state)
   if error then completed({status="failed",code=error.code}) elseif state.pending then state.operation=operation end
  end)
  if state.pending and state.phase=="preparing" then state.operation=preparation end
  if not preparation and why then completed({status="failed",code=why.code}) end
 end
 function handle:Push(input)
  if state.character~=characterToken() then self:Cancel("CHARACTER_CHANGED");return fail("EDIT_CLOSED") end
  if state.closed or state.finished or state.finalRequested then return fail("EDIT_CLOSED") end
  if state.pending and opts.mode~="latest" then return fail("OPERATION_BUSY") end
  local args,why=V:NormalizeArgs(action.schema,input)
  if not args then state.draft=plain(input,"draft");state.code=why.code;notify();return nil,why end
  state.draft=args;state.queued=args;state.code=nil;notify();schedule();return true
 end
 function handle:Finish()
  if state.character~=characterToken() then self:Cancel("CHARACTER_CHANGED");return false end
  if state.closed or state.finished then return false end
  state.finalRequested=true;schedule();return true
 end
 local lease;lease,err=scope:Own("edit",function(reason) handle:Cancel(reason) end)
 if not lease then edits[state]=nil;I.Resources:Close(scope);return nil,err end
 return handle
end
