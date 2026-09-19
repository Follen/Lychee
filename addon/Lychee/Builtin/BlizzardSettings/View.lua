local I=_G.LycheeInternal
local A=I.Builtin.SettingsAdapter
local L=I.ProviderLocales:Builtin("builtin.blizzard-settings")
local V={};I.Builtin.SettingsView=V
local cached
function V.Create()
 if cached then return cached end
 local panel={page=1,epoch=0}
 function panel:Execute(operation,args)
  if not self.active or self.busy then return end
  local spec=self.spec;local staged=operation~="open" and A.Staged(spec)
  local id=(staged and "stage-" or "setting-")..operation
  local epoch=self.epoch;self.busy=true
  local function status(ok)
   if not self.active or epoch~=self.epoch then return end
   self.busy=false;self.message=ok and L[staged and "预填到暴雪设置，点击应用后生效" or "已更新"] or L["设置未能确认，请检查可用范围或打开暴雪设置"]
   if ok then self.draft=nil end
   self:Refresh()
  end
  local _,why=self.context:Prepare(id,{version=1,key={setting=spec.id}},args,function(token)
   if not token then status(false);return end
   local _,err=self.context:Invoke(token,function(result) status(result.status=="succeeded") end)
   if err then status(false) end
  end)
  if why then status(false) end
 end
 function panel:Refresh()
  local spec=self.spec
  if not self.active or not spec then return end
  local current=A.Read(spec)
  local number=spec.kind=="number"
  local low,high,step=A.Limits(spec)
  local options=(spec.kind=="choice" or spec.kind=="multi") and A.Options(spec) or {}
  options=options or {};if #options>128 then options={} end
  local count=#options;self.page=math.max(1,math.min(self.page,math.max(1,math.ceil(count/8))))
  local props={title=spec.name,number=number,enabled=A.Available(spec,true) and not self.busy,
   hint=number and low and L:Format("范围 %s–%s，步长 %s",tostring(low),tostring(high),tostring(step)) or spec.categoryName,
   message=self.message or (A.Staged(spec) and L["预填到暴雪设置，点击应用后生效"] or L["选择后立即生效"]),
   input=self.draft or (type(current)=="number" and tostring(current*(spec.factor or 1)+(spec.offset or 0)) or ""),
   previous=count>8 and self.page>1,next=count>8 and self.page*8<count,
   apply=L[A.Staged(spec) and "预填并打开设置" or "应用"]}
  self.choices={}
  for slot=1,8 do
   local option=options[(self.page-1)*8+slot];local selected=option and option.value==current
   if option and spec.kind=="multi" and bit and type(current)=="number" then selected=bit.band(current,bit.lshift(1,option.value-(option.enumValueOffset or 1)))~=0 end
   props["label"..slot]=option and ((selected and "✓ " or "")..(option.label or option.text or "")) or ""
   props["show"..slot]=option~=nil;self.choices[slot]=option
   props["enabled"..slot]=props.enabled and option~=nil and not option.disabled
  end
  assert(self.ui:Update(props))
  if self.context.Resize then self.context:Resize(number and 240 or 480) end
 end
 function panel:Mount(context,state)
  self.context,self.spec=context,A.byID[state.setting]
  if not self.spec then error("SETTINGS_NOT_READY") end
  self.active,self.busy,self.page,self.draft,self.message=true,false,1,nil,nil;self.epoch=self.epoch+1
  if not self.ui then
   local children={
    {type="Text",key="title",props={role="title",point={"TOPLEFT",nil,"TOPLEFT",20,-16}},bind={text="title"}},
    {type="Text",key="hint",props={role="meta",point={"TOPLEFT",nil,"TOPLEFT",20,-48}},bind={text="hint"}},
    {type="Input",key="value",props={width=220,height=32,maxBytes=32,point={"TOPLEFT",nil,"TOPLEFT",20,-84}},bind={visible="number",text="input"},
     on={change=function(_,_,_,frame) self.draft=frame:GetText() end}},
    {type="Button",key="apply",props={width=190,height=32,point={"TOPLEFT",nil,"TOPLEFT",254,-84}},bind={visible="number",enabled="enabled",text="apply"},
     on={click=function() local n=I.Builtin.SettingsLanguage.Number(self.ui:Get("value"):GetText());if n then self:Execute("number",{value=n}) else self.message=L["请输入数字"];self:Refresh() end end}},
   }
   for slot=1,8 do
    local index=slot
    children[#children+1]={type="Button",key="option"..slot,props={width=500,height=30,point={"TOPLEFT",nil,"TOPLEFT",20,-78-(slot-1)*34}},bind={visible="show"..slot,text="label"..slot,enabled="enabled"..slot},on={click=function()
     local option=self.choices[index];if not option then return end
     local args={choice=type(option.value)..":"..tostring(option.value)}
     if self.spec.kind=="multi" then local current=A.Read(self.spec);if type(current)~="number" or not bit then return end;args.enabled=bit.band(current,bit.lshift(1,option.value-(option.enumValueOffset or 1)))==0 end
     self:Execute(self.spec.kind,args)
    end}}
   end
   children[#children+1]={type="Button",key="previous",props={text=L["上一页"],width=96,height=28,point={"TOPLEFT",nil,"TOPLEFT",20,-356}},bind={visible="previous"},on={click=function() self.page=self.page-1;self:Refresh() end}}
   children[#children+1]={type="Button",key="next",props={text=L["下一页"],width=96,height=28,point={"TOPLEFT",nil,"TOPLEFT",126,-356}},bind={visible="next"},on={click=function() self.page=self.page+1;self:Refresh() end}}
   children[#children+1]={type="Text",key="message",props={role="meta",width=500,point={"BOTTOMLEFT",nil,"BOTTOMLEFT",20,54}},bind={text="message"}}
   children[#children+1]={type="Button",key="native",props={text=L["打开并定位"],width=160,height=28,point={"BOTTOMLEFT",nil,"BOTTOMLEFT",20,16}},on={click=function() self:Execute("open",{}) end}}
   self.ui=assert(_G.Lychee.UI:Create(context.contentFrame,{type="Fragment",children=children}))
  end
  self:Refresh()
 end
 function panel:Unmount(reason)
  self.active=false;self.epoch=self.epoch+1;self.spec,self.context,self.choices,self.draft,self.message=nil,nil,nil,nil,nil
  if self.ui then self.ui:Release(reason) end
 end
 cached=panel;return panel
end
