local I=_G.LycheeInternal
-- Native objects remain private to this settings module. Host receives stable identities
-- and bounded arguments. No setter is called during discovery or parsing.
local A={byID={},byVariable={},ordered={}}
I.Builtin.SettingsAdapter=A
local fields={"setting","cbSetting","sliderSetting","dropdownSetting"}
local optionsField={setting="options",sliderSetting="sliderOptions",dropdownSetting="dropdownOptions"}
local percentFactors={Sound_MasterVolume=100,Sound_MusicVolume=100,Sound_SFXVolume=100,
 Sound_AmbienceVolume=100,Sound_DialogVolume=100,PROXY_UI_SCALE=100,
 PROXY_VOICE_INPUT_VOLUME=1,PROXY_VOICE_OUTPUT_VOLUME=1,PROXY_VOICE_DUCKING=100,
 Sound_GameplaySFX=100,Sound_PingVolume=100,Sound_EncounterWarningsVolume=100}
local function scalar(v)
 if issecretvalue and issecretvalue(v) then return nil end
 local t=type(v);if t=="string" or t=="boolean" or t=="number" and v==v and math.abs(v)<=1e9 then return v end
end
local function call(o,k,...)
 if o and type(o[k])=="function" then local ok,v=pcall(o[k],o,...);if ok then return v end end
end
A.Call=call
local function flag(s,name)
 local flags=Settings and Settings.CommitFlag
 return flags and flags[name] and call(s,"HasCommitFlag",flags[name])==true
end
function A.Options(spec)
 local value=spec.options
 if type(value)=="function" then local ok,v=pcall(value);if not ok then return nil end;value=v end
 return type(value)=="table" and value or nil
end
function A.Classify(spec)
 local setting=spec.setting
 if not setting or type(setting.SetValue)~="function" or type(setting.GetVariableType)~="function" then return "native" end
 local t=call(setting,"GetVariableType")
 if t=="string" and spec.template=="SettingsColorSwatchControlTemplate" then return "color" end
 -- A Boolean-backed dropdown can mean windowed/fullscreen. Only actual
 -- checkbox controls use toggle semantics (some attach numeric option hints).
 if t=="boolean" and not (spec.template and spec.template:find("Dropdown")) then return "boolean" end
 local options=A.Options(spec)
 if options and #options>0 then
  if #options>128 or spec.customOptions then return "native" end
  local kind
  for _,v in ipairs(options) do
   if type(v)~="table" or scalar(v.value)==nil or type(v.label or v.text)~="string" then return "native" end
   local k=Settings.ControlType and (v.controlType==Settings.ControlType.Checkbox and "multi" or v.controlType==Settings.ControlType.Radio and "choice") or nil
   if not k or kind and kind~=k or type(v.value)~=t and k~="multi" then return "native" end
   if k=="multi" and (type(v.value)~="number" or v.value%1~=0 or v.value-(v.enumValueOffset or 1)<0 or v.value-(v.enumValueOffset or 1)>30) then return "native" end
   kind=k
  end
  return kind
 end
 if t=="number" and options and type(options.minValue)=="number" and type(options.maxValue)=="number"
  and type(options.steps)=="number" and options.steps>0 and options.maxValue>options.minValue then return "number" end
 return "native"
end
function A.Staged(spec)
 local s=spec.setting
 return flag(s,"Apply") or flag(s,"ClientRestart") or flag(s,"GxRestart") or flag(s,"UpdateWindow") or flag(s,"SaveBindings")
end
function A.Available(spec,write)
 if not spec or InCombatLockdown and InCombatLockdown() then return false end
 if spec.initializer then
  if call(spec.initializer,"ShouldShow")==false then return false end
  if write and call(spec.initializer,"EvaluateModifyPredicates")==false then return false end
 end
 if write and (call(spec.setting,"IsLocked")==true or spec.parent and call(spec.parent,"GetValue")~=true) then return false end
 if write and Kiosk and Kiosk.IsEnabled and Kiosk.IsEnabled() and (flag(spec.setting,"KioskProtected") or call(spec.initializer,"IsKioskProtected")==true) then return false end
 return true
end
function A.Read(spec)
 return spec and scalar(call(spec.setting,"GetValue"))
end
function A.Limits(spec)
 local o=A.Options(spec);if not o then return end
 local f=spec.factor or 1
 local low,high=scalar(o.minValue),scalar(o.maxValue)
 if type(low)~="number" or type(high)~="number" or type(o.steps)~="number" or o.steps<=0 then return end
 local step=(high-low)/o.steps*f
 if spec.factor==100 and spec.variable:find("^Sound_") then step=1 end
 return low*f+(spec.offset or 0),high*f+(spec.offset or 0),step
end
local function hash(text)
 local n=0;for i=1,#text do n=(n*31+text:byte(i))%2147483647 end;return tostring(n)
end
local function bindingID(binding)
 -- Escape the escape marker too: "CLICK A" and "CLICK_20A" stay distinct.
 local id="binding:"..binding:gsub("[^A-Za-z0-9.:%-/]",function(c) return string.format("_%02X",c:byte()) end)
 -- Oversized third-party bindings remain in the native category; they must
 -- not invalidate the whole catalog by exceeding the SDK's 128-byte ID cap.
 if #id<=128 then return id end
end
function A.Scan(checkpoint)
 local map,variables,ordered={},{},{}
 if not SettingsPanel or not SettingsPanel.GetAllCategories or not Settings then A.byID,A.byVariable,A.ordered=map,variables,ordered;return end
 local function add(spec)
  if map[spec.id] then return end
  if #ordered>=4094 then error("SETTINGS_LIMIT") end
  spec.factor=percentFactors[spec.variable]
  spec.kind=A.Classify(spec);map[spec.id]=spec;ordered[#ordered+1]=spec
  if spec.variable and not variables[spec.variable] then variables[spec.variable]=spec end
 end
 for _,category in ipairs(SettingsPanel:GetAllCategories()) do
  if category:GetCategorySet()==Settings.CategorySet.Game then
   local destination=category.redirectCategory or category
   local categoryID,categoryName=destination:GetID(),destination:GetName()
   local layout=SettingsPanel:GetLayout(category)
   local list=layout and layout.GetInitializers and layout:GetInitializers() or {}
   for index,initializer in ipairs(list) do
    local data=initializer.data or {};local found=false
    local template=call(initializer,"GetTemplate")
    if template=="SettingsAdvancedQualitySectionTemplate" and I.Builtin.SettingsGraphics then
     I.Builtin.SettingsGraphics.Collect(initializer,categoryID,categoryName,add,checkpoint);found=true
    end
    if template=="KeyBindingFrameBindingTemplate" and type(data.bindingIndex)=="number" and GetBinding and GetBindingName then
     local ok,binding=pcall(GetBinding,data.bindingIndex)
     local named,name=pcall(GetBindingName,ok and binding or "")
     if ok and type(binding)=="string" and named and type(name)=="string" and name~="" then
      local id=bindingID(binding)
      if id then add({id=id,name=name,categoryID=categoryID,categoryName=categoryName,initializer=initializer,searchName=name}) end
      found=true
     end
    end
    for _,field in ipairs(fields) do
     local setting=data[field];local variable=scalar(call(setting,"GetVariable"))
     local label=field=="cbSetting" and data.cbLabel or field=="sliderSetting" and data.sliderLabel or field=="dropdownSetting" and data.dropDownLabel
     local name=scalar(label) or scalar(call(setting,"GetName")) or data.name
     if type(variable)=="string" and #variable<=192 and type(name)=="string" and name~="" then
      found=true
      add({id="setting:"..variable,variable=variable,name=name,categoryID=categoryID,categoryName=categoryName,
       setting=setting,initializer=initializer,template=template,options=data[optionsField[field]],
       parent=(field=="sliderSetting" or field=="dropdownSetting") and data.cbSetting or nil,
       customOptions=initializer.customOptionHandler~=nil})
     end
    end
    if not found and type(data.name)=="string" and data.name~="" and template~="SettingsListSectionHeaderTemplate" and template~="SettingsKeybindingSectionTemplate" then
     add({id="setting:"..categoryID..":"..hash(data.name),name=data.name,categoryID=categoryID,categoryName=categoryName,initializer=initializer})
    end
    checkpoint()
   end
   -- Custom layouts (bindings, edit mode, etc.) still have a real navigation action.
   add({id="category:"..categoryID,name=categoryName,categoryID=categoryID,categoryName=categoryName})
  end
  checkpoint()
 end
 A.byID,A.byVariable,A.ordered=map,variables,ordered
end
function A.Clear() A.byID,A.byVariable,A.ordered={},{},{} end
function A.Open(spec)
 if not A.Available(spec,false) or not C_SettingsUtil or not C_SettingsUtil.OpenSettingsPanel then return {status="failed",code="SETTINGS_NOT_READY"} end
 local ok=pcall(C_SettingsUtil.OpenSettingsPanel,spec.categoryID,spec.searchName or spec.name)
 local selected=call(SettingsPanel,"GetCurrentCategory")
 if not ok or not selected or call(selected,"GetID")~=spec.categoryID or call(SettingsPanel,"IsShown")~=true then return {status="failed",code="SETTINGS_NOT_READY"} end
 return {status="succeeded"}
end
local function choiceValue(spec,text)
 local options=A.Options(spec);if not options or #options>128 then return end
 for _,v in ipairs(options) do
  if type(v)=="table" and type(v.value)..":"..tostring(v.value)==text then return v end
 end
end
function A.Validate(spec,operation,args,stage)
 if not A.Available(spec,true) then return nil,"ACTION_UNAVAILABLE" end
 local kind=A.Classify(spec)
 if kind=="native" or A.Staged(spec) and not stage then return nil,"ACTION_UNAVAILABLE" end
 local before=A.Read(spec);if before==nil then return nil,"SETTINGS_NOT_READY" end
 local value
 if operation=="reset" then value=scalar(call(spec.setting,"GetDefaultValue"))
 elseif operation=="toggle" and kind=="boolean" then value=not before
 elseif operation=="boolean" and kind=="boolean" then value=args.value
 elseif (operation=="number" or operation=="increase" or operation=="decrease") and kind=="number" then
  local low,high,step=A.Limits(spec);if not low or step<=0 then return nil,"INVALID_ARGS" end
  local n=args.value
  if operation~="number" then n=before*(spec.factor or 1)+(spec.offset or 0)+(operation=="increase" and 1 or -1)*(n or step) end
  if type(n)~="number" or n~=n or n<low-1e-6 or n>high+1e-6 then return nil,"INVALID_ARGS" end
  local tick=(n-low)/step
  if math.abs(tick-math.floor(tick+.5))>1e-4 then return nil,"INVALID_ARGS" end
  value=(n-(spec.offset or 0))/(spec.factor or 1)
 elseif operation=="choice" and kind=="choice" then local option=choiceValue(spec,args.choice);if option and not option.disabled then value=option.value end
 elseif operation=="color" and kind=="color" and type(args.color)=="string" and #args.color==8 and args.color:match("^%x+$") then value=args.color:upper()
 elseif operation=="multi" and kind=="multi" and bit then
  local option=choiceValue(spec,args.choice)
  if option and not option.disabled then local mask=bit.lshift(1,option.value-(option.enumValueOffset or 1));value=args.enabled and bit.bor(before,mask) or bit.band(before,bit.bnot(mask)) end
 end
 if scalar(value)==nil or type(value)~=type(before) then return nil,"INVALID_ARGS" end
 if stage and not flag(spec.setting,"Apply") then return nil,"ACTION_UNAVAILABLE" end
 return value,before
end
function A.Write(spec,operation,args,stage)
 local value,before=A.Validate(spec,operation,args,stage)
 if value==nil then return {status="failed",code=before} end
 if stage then local opened=A.Open(spec);if opened.status~="succeeded" then return opened end end
 -- Apply/restart rows only use the native pending-value path. Never commit
 -- unrelated drafts or bypass Apply by passing immediate=true.
 if stage and not flag(spec.setting,"Apply") then return {status="failed",code="ACTION_UNAVAILABLE"} end
 local ok=pcall(spec.setting.SetValue,spec.setting,value)
 local after
 if stage then after=A.Read(spec) else after=scalar(call(spec.setting,"GetValueDerived")) end
 if after==nil and not stage then after=A.Read(spec) end
 local equal=type(value)=="number" and type(after)=="number" and math.abs(value-after)<1e-5 or value==after
 if not ok or not equal then return {status="indeterminate",code="SETTING_UNCONFIRMED"} end
 return {status="succeeded",changed=before~=after}
end
