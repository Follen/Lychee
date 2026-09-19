local I=_G.LycheeInternal
local A,G=I.Builtin.SettingsAdapter,I.Builtin.SettingsLanguage
local L=I.ProviderLocales:Builtin("builtin.blizzard-settings")
local M={}
I.Builtin.SettingsInvocations=M
local labels={open="打开并定位",boolean="设置开关",toggle="切换开关",number="设置数值",increase="增加",decrease="减少",choice="选择选项",multi="设置选项",reset="恢复默认值",color="设置颜色"}
local schemas={open={},toggle={},reset={},boolean={value={type="boolean",required=true}},
 number={value={type="number",precision=6,required=true}},increase={value={type="number",precision=6,min=0}},decrease={value={type="number",precision=6,min=0}},
 color={color={type="string",minLength=8,maxLength=8,required=true}},choice={choice={type="string",maxLength=256,required=true}},multi={choice={type="string",maxLength=256,required=true},enabled={type="boolean",required=true}}}
local function target(spec) return {version=1,key={setting=spec.id}} end
local function actionID(operation,staged) return (staged and "stage-" or "setting-")..operation end
local function ref(spec,operation,args)
 return {kind="invocation",product=I.Search.RuntimeIdentity:Current().product,providerID="builtin.blizzard-settings",
  actionID=actionID(operation,operation~="open" and A.Staged(spec)),actionVersion=1,target=target(spec),args=args or {}}
end
local function descriptor(spec,id,operation,args,title)
 return {id=id,kind="invocation",title=title or L[labels[operation]],invocation=ref(spec,operation,args)}
end
local function presentation(spec)
 local writable=spec.kind~="native" and (not A.Staged(spec) or A.Call(spec.setting,"HasCommitFlag",Settings.CommitFlag.Apply))
 local adjust=I.Builtin.SettingsView and writable and (spec.kind=="number" or spec.kind=="choice" or spec.kind=="multi")
 return writable,adjust
end
function M.Document(spec)
 local _,adjust=presentation(spec)
 return {id=spec.id,title=spec.name,aliases=spec.aliases,
  subtitle=L:Format((spec.channel or adjust) and "%s · 直接调整" or spec.kind=="boolean" and not A.Staged(spec) and "%s · 切换开关" or "%s · 点击定位",spec.categoryName)}
end
function M.Record(spec)
 local actions={};local primary
 local writable,adjust=presentation(spec)
 if spec.channel then actions[#actions+1]="adjust-volume";primary="adjust-volume"
 elseif spec.kind=="boolean" and writable and not A.Staged(spec) then actions[#actions+1]=descriptor(spec,"toggle","toggle");primary="toggle"
 elseif adjust then
  actions[#actions+1]={id="adjust",kind="open-panel",title=L["直接调整"],panel="setting-controls",state={setting=spec.id}};primary="adjust"
 end
 actions[#actions+1]=descriptor(spec,"open","open")
 primary=primary or "open"
 if spec.kind=="boolean" and writable then
  local suffix=A.Staged(spec) and L["（需应用）"] or ""
  actions[#actions+1]=descriptor(spec,"enable","boolean",{value=true},L["开启"]..suffix)
  actions[#actions+1]=descriptor(spec,"disable","boolean",{value=false},L["关闭"]..suffix)
 end
 if writable and A.Call(spec.setting,"GetDefaultValue")~=nil then actions[#actions+1]=descriptor(spec,"reset","reset",{},L["恢复默认值"]..(A.Staged(spec) and L["（需应用）"] or "")) end
 local record=M.Document(spec)
 record.kind,record.kindTitle,record.icon="setting",L["暴雪设置"],"Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga"
 record.payload={categoryID=spec.categoryID,name=spec.name,channel=spec.channel}
 record.actions,record.primaryActionID=actions,primary
 if spec.channel then record.command={kind="command",product=I.Search.RuntimeIdentity:Current().product,providerID="builtin.blizzard-settings",
  actionID="set-volume",actionVersion=1,target={version=1,key={channel=spec.channel}}} end
 return record
end
local function applyInvocation(record,spec,operation,args,invocation)
 record.command=nil
 record.invocation=invocation or ref(spec,operation,args)
 table.insert(record.actions,1,record.invocation.actionID);record.primaryActionID=record.invocation.actionID
 record.title=L[labels[operation]].." · "..spec.name
 local value=args.value
 if value~=nil then record.title=record.title.." · "..(type(value)=="boolean" and L[value and "开启" or "关闭"] or tostring(value)..(spec.factor and "%" or "")) end
 if args.choice then
  for _,option in ipairs(A.Options(spec) or {}) do
   if type(option.value)..":"..tostring(option.value)==args.choice then record.title=record.title.." · "..(option.label or option.text or tostring(option.value));break end
  end
 end
 if args.color then record.title=record.title.." · "..args.color end
 if args.enabled~=nil then record.title=record.title.." · "..L[args.enabled and "开启" or "关闭"] end
 if A.Staged(spec) and operation~="open" then record.subtitle=L["预填到暴雪设置，点击应用后生效"] end
 return record
end
function M.Attach(owner)
 if owner.settingsAttached then return end;owner.settingsAttached=true
 local oldQuery,oldResolve,oldTarget,oldDescribe=owner.query,owner.resolve,owner.resolveTarget,owner.describe
 if I.Builtin.SettingsView then
  owner.views=owner.views or {};owner.views["setting-controls"]={create=I.Builtin.SettingsView.Create,stateSchema={setting="string"}}
 end
 for operation,schema in pairs(schemas) do
  for _,stage in ipairs({false,true}) do
   if not stage or operation~="open" then
    local op,staged=operation,stage
    owner.actions[actionID(op,staged)]={title=L[labels[op]]..(staged and L["（需应用）"] or ""),actionVersion=1,
     absolute=op=="number" or op=="boolean" or op=="choice" or op=="color",conflictKey="setting",schema=schema,
     run=function(invocation)
      local spec=A.byID[invocation.target.key.setting]
      local result=op=="open" and A.Open(spec) or A.Write(spec,op,invocation.args,staged)
      if result.status=="succeeded" then
       local display=applyInvocation(M.Record(spec),spec,op,invocation.args,invocation)
       result.message=L:Format(op=="open" and "已打开：%s" or staged and "已预填：%s；点击应用后生效" or "已更新：%s",display.title)
      end
      return result
     end}
   end
  end
 end
 owner.resolveTarget=function(value,...)
  local id=value and value.version==1 and value.key and value.key.setting
  if id then
   local spec=A.byID[id]
   if not spec then return {status="temporarilyUnavailable"} end
   return {status="ready",target=value,identity=spec.variable or spec.id}
  end
  if oldTarget then return oldTarget(value,...) end
  return {status="missing"}
 end
 owner.describe=function(value,id,...)
  if not value.key.setting then if oldDescribe then return oldDescribe(value,id,...) end;return {available=false,revision=1} end
  local spec=A.byID[value.key.setting];local staged,op=id:match("^(stage)%-(.+)$")
  op=op or id:match("^setting%-(.+)$")
  local available=spec and schemas[op] and A.Available(spec,op~="open")
  if available and op~="open" then
   local kind=A.Classify(spec)
   available=kind~="native" and (not A.Staged(spec) or staged~=nil)
   if staged and not A.Call(spec.setting,"HasCommitFlag",Settings.CommitFlag.Apply) then available=false end
   if op=="boolean" or op=="toggle" then available=available and kind=="boolean"
   elseif op=="number" or op=="increase" or op=="decrease" then available=available and kind=="number"
   elseif op=="choice" or op=="multi" or op=="color" then available=available and kind==op end
  end
  return {available=available==true,revision=1,code=not available and "ACTION_UNAVAILABLE" or nil}
 end
 owner.query=function(request,reply)
  local parsed,parseError=G.Parse(request.raw or request.normalized)
  if parseError=="NEGATED" or parseError=="AMBIGUOUS_TARGET" then reply({},true);return end
  -- Audio owns its established absolute 0..100 action and controls. Other
  -- operations on native audio rows use the same underlying setting identity.
  if parsed and parsed.spec.channel and (parsed.operation=="number" or parsed.code=="MISSING_ARGS") then parsed=nil end
  if not parsed then if oldQuery then return oldQuery(request,reply) end;reply({},false);return end
  local spec=parsed.spec;local record=M.Record(spec)
  if parsed.operation~="invalid" and parsed.operation~="open" then
   local value,why=A.Validate(spec,parsed.operation,parsed.args,A.Staged(spec))
   if value==nil then parsed.operation,parsed.code="invalid",why end
  end
  if parsed.operation=="invalid" then
   if parsed.code=="MISSING_ARGS" then
    local low,high=A.Limits(spec)
    record.subtitle=low and high and L:Format("请输入 %s–%s 范围内的数值",tostring(low),tostring(high)) or L["请选择要设置的值"]
   else record.subtitle=L["无法识别这个值，请打开设置查看可用范围和选项"] end
   record.invocationError={code=parsed.code or "INVALID_ARGS",field="value"}
   -- Invalid text must never activate the setting's default toggle.
   record.actions={descriptor(spec,"open","open")};record.primaryActionID="open"
   record.invocationError.span={start=(request.rawOffset or 0)+1,finish=(request.rawOffset or 0)+#(request.raw or "")}
  else
   applyInvocation(record,spec,parsed.operation,parsed.args)
  end
  reply({record},true)
 end
 owner.resolve=function(id,context,...)
  local saved=context and context.ref
  local setting=saved and saved.target and saved.target.key and saved.target.key.setting
  local spec=setting and A.byID[setting]
  if spec and saved.kind=="invocation" then
   local op=saved.actionID:match("^setting%-(.+)$") or saved.actionID:match("^stage%-(.+)$")
   if schemas[op] and saved.actionVersion==1 then
    local record=M.Record(spec);record.id=id
    for _,action in ipairs(record.actions) do
     if type(action)=="table" and action.invocation and I.Invocations:Equal(action.invocation,saved) then return record end
    end
    return applyInvocation(record,spec,op,saved.args,saved)
   end
  end
  if A.byID[id] then return M.Record(A.byID[id]) end
  if oldResolve then return oldResolve(id,context,...) end
 end
 local oldStop=owner.onStop
 function owner:onStop(...)
  A.Clear();G.Clear();if oldStop then oldStop(self,...) end
 end
end
