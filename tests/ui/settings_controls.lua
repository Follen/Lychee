local env=assert(loadfile("tests/support/palette.lua"))(arg[1])
dofile("addon/Lychee/UI/Runtime.lua")
local value,writes=30,0
local options={};for i=1,18 do options[i]={value=i,label="Option "..i} end
options[2].disabled=true
local number={id="number",name="Number",kind="number",categoryName="Category"}
local choice={id="choice",name="Choice",kind="choice",categoryName="Category"}
local A={byID={number=number,choice=choice},Read=function() return value end,Staged=function() return false end,
 Limits=function(s) if s.kind=="number" then return 0,100,1 end end,Options=function() return options end,Available=function() return true end}
local L=setmetatable({Format=function(_,s,...) return string.format(s,...) end},{__index=function(_,k) return k end})
local ns={Builtin={SettingsAdapter=A,SettingsLanguage={Number=tonumber}},ProviderLocales={Builtin=function() return L end}}
local real=LycheeInternal;LycheeInternal=ns
dofile("addon/Lychee/Builtin/BlizzardSettings/View.lua");LycheeInternal=real
local context={contentFrame=CreateFrame("Frame",nil,UIParent),Resize=function(_,height) assert(height<=480) end}
local pending
function context:Prepare(id,target,args,reply) local token={id=id,target=target,args=args};reply(token);return token end
function context:Invoke(token,reply)
 writes=writes+1;value=token.args.value or tonumber((token.args.choice or ""):match(":(.+)$"))
 if pending then pending=reply else reply({status="succeeded"}) end
 return {}
end
local panel=ns.Builtin.SettingsView.Create()
panel:Mount(context,{setting="number"})
local function click(key)
 local f=panel.ui:Get(key);local down=f:GetScript("OnMouseDown");if down then down(f,"LeftButton") end
 local fn=f:GetScript("OnClick");assert(fn,key);fn(f,"LeftButton")
end
local input=panel.ui:Get("value");input:SetText("40");click("apply");assert(writes==1 and value==40)
panel:Unmount("switch");panel:Mount(context,{setting="choice"})
assert(panel.ui:Get("option1"):IsShown() and not panel.ui:Get("value"):IsShown())
click("next");assert(panel.page==2);click("option1");assert(value==9 and writes==2)
click("next");assert(panel.page==3 and not panel.ui:Get("option3"):IsShown())
local frames=env.state.createdFrames
for i=1,10 do panel:Unmount("repeat");panel:Mount(context,{setting="number"}) end
assert(env.state.createdFrames==frames,"reopening allocated frames")
pending=true;input=panel.ui:Get("value");input:SetText("50");click("apply");local late=pending
assert(type(late)=="function");panel:Unmount("closed");late({status="succeeded"})
assert(not panel.active and not panel.context and not panel.spec)
print("Settings controls PASS: real retained UI, number apply, 18 choices/paging, frame reuse and late callback cleanup")
