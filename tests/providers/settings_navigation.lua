local f=dofile("tests/support/settings_fixture.lua").Load()
local I,A,M=f.I,f.A,f.M
f.add(f.setting("Sound_MasterVolume","主音量",.3,.5),{minValue=0,maxValue=1,steps=100},"SettingsSliderControlTemplate")
I.Registry:SetReady(true);assert(M:Init());f.advance();assert(not M.dirty,M.lastError)
local owner=I.Providers.entries[M.id]
assert(not owner.definition.query,"settings must not parse natural-language commands")
assert(not owner.definition.resolveTarget and not owner.definition.describe and not owner.definition.observe,"settings still registers Invocation capabilities")
assert(not owner.definition.views or not next(owner.definition.views),"settings still registers edit panels")
local opened={}
C_SettingsUtil.OpenSettingsPanel=function(category,name) opened[#opened+1]={category,name};f.state.shown=true end
for _,spec in ipairs(A.ordered) do
 local item=assert(I.Providers:Resolve({providerID=M.id,entryID=spec.id},{}))
 assert(#item.interaction.actions==1 and item.interaction.primaryActionID=="open",spec.id.." must only open")
 assert(not item.ref.kind,"ordinary setting became a typed invocation")
 local result=assert(I.Providers:Execute(item,"open",{}))
 assert(result.ok and result.close and opened[#opened][1]==spec.categoryID and opened[#opened][2]==(spec.searchName or spec.name),"wrong native destination")
end
assert(#f.writes==0,"navigation changed settings")
for _,text in ipairs({"主音量","music volume","后台帧数","auto loot","综合阴影","UI缩放"}) do
 local ok,items=I.Search.Query:Query(text,{visible=true});assert(ok and #items>0,text)
 for _,item in ipairs(items) do assert(not item.ref.kind and #item.interaction.actions==1 and item.interaction.primaryActionID=="open",text.." exposed an editing action") end
end
for _,id in ipairs({"setting-toggle","setting-number","setting-open","stage-choice","set-volume"}) do
 assert(not owner.definition.actions[id],id.." still registered")
 local ref={kind="invocation",product="retail",providerID=M.id,actionID=id,actionVersion=1,target={version=1,key={setting="setting:maxFPSBk"}},args={value=30}}
 if id=="set-volume" then ref.target={version=1,key={channel="master"}};ref.args={percent=30} end
 assert(not I.Invocations:Prepare(ref),"retired invocation can still prepare")
 assert(not I.Providers:Resolve(ref,{}),"retired history silently falls back")
 ref.kind="command";ref.args=nil
 assert(not I.Providers:Resolve(ref,{}),"retired panel command still resolves")
end
local spec=A.byVariable.maxFPSBk
assert(I.Providers:Resolve({providerID=M.id,entryID=spec.id,actionID="open"},{}),"ordinary open history lost")
assert(not I.Providers:Resolve({providerID=M.id,entryID=spec.id,actionID="adjust"},{}),"old adjust action silently changed")
local item=assert(I.Providers:Resolve({providerID=M.id,entryID=spec.id},{}))
-- Conditional native controls still have a useful category destination.
local shouldShow=spec.initializer.ShouldShow
spec.initializer.ShouldShow=function() return false end
assert(I.Providers:Execute(item,"open",{}).ok,"hidden native control blocked category navigation")
spec.initializer.ShouldShow=shouldShow
C_SettingsUtil.OpenSettingsPanel=function() error("unavailable") end
local failed=I.Providers:Execute(item,"open",{})
assert(not failed or not failed.ok,"failed native open claimed success")
f.state.combat=true;assert(A.Open(spec).status=="failed");f.state.combat=false
assert(A.byID["binding:CLICK_20ExampleButton:LeftButton"].name~=A.byID["binding:CLICK_5F20ExampleButton:LeftButton"].name)
assert(A.byID["setting:PROXY_UI_SCALE"].name=="UI缩放")
for _,s in ipairs(A.ordered) do assert(s.name~="分组标题") end
assert(M.handle:Unregister());assert(not next(A.byID))
assert(M:Init());f.advance();assert(I.Providers:Resolve({providerID=M.id,entryID=spec.id},{}))
assert(#f.writes==0)
-- The searchable binding initializer is NOT in the visible category layout.
local bindingSpec=A.byID["binding:CLICK_20ExampleButton:LeftButton"]
local section={data={name="视角",expanded=false,bindingsCategories={{2,"CLICK_20ExampleButton:LeftButton"},{1,"CLICK ExampleButton:LeftButton"}}},GetTemplate=function() return "SettingsKeybindingSectionTemplate" end}
local control={GetTop=function() return 350 end}
local sectionFrame={Controls={{},control},GetTop=function() return 420 end}
sectionFrame.Button={Click=function() section.data.expanded=true end}
local scrolled,offset,updated
ScrollBoxConstants={AlignBegin=0,UpdateImmediately=true}
local box={ScrollToElementData=function(_,row,_,delta)
 if delta~=0 then assert(updated,"expanded scroll range still pending") end
 scrolled=row;offset=delta
end,FindFrame=function(_,row) if row==section then return sectionFrame end end,FullUpdate=function(_,immediate) updated=immediate end}
SettingsPanel.GetSettingsList=function() return {ScrollBox=box} end
SettingsPanel.GetLayout=function() return {GetInitializers=function() return {section} end} end
C_SettingsUtil.OpenSettingsPanel=function() f.state.shown=true end
assert(A.Open(bindingSpec).status=="succeeded")
assert(section.data.expanded,"native binding section remained collapsed")
assert(scrolled==section and offset==-70,"binding child was not positioned by identity")
section.data.expanded=false
section.data.bindingsCategories={{1,"CLICK ExampleButton:LeftButton"}}
sectionFrame.Controls={control}
assert(A.Open(bindingSpec).status=="succeeded" and section.data.expanded,"rebuilt native layout was not resolved")
local combo=A.byID["setting:PROXY_UI_SCALE"]
SettingsPanel.GetLayout=function() return {GetInitializers=function() return {combo.initializer} end} end
assert(A.Open(combo).status=="succeeded" and scrolled==combo.initializer,"composite label did not locate its actual row")
local gfx=A.byID["setting:PROXY_SHADOW_QUALITY"]
local graphicsFrame={GetTop=function() return 420 end,BaseQualityControls={ShadowQuality=control},RaidQualityControls={ShadowQuality=control}}
local selectedTab
graphicsFrame.tabsGroup={SelectAtIndex=function(_,index) selectedTab=index end}
box.FindFrame=function(_,row) if row==gfx.initializer then return graphicsFrame end end
SettingsPanel.GetLayout=function() return {GetInitializers=function() return {gfx.initializer} end} end
assert(A.Open(gfx).status=="succeeded" and selectedTab==1 and offset==-70,"base graphics child not located")
gfx.raid=true;gfx.initializer.data.raidSettings=gfx.initializer.data.settings
assert(A.Open(gfx).status=="succeeded" and selectedTab==2 and offset==-70,"raid graphics tab not selected")
assert(#f.writes==0,"locating controls changed settings")
print("Settings navigation PASS: all kinds open natively; no grammar, edits, panels or legacy invocation execution; aliases and lifecycle retained")

local camera=M:Record(assert(A.byID["binding:CAMERAZOOMOUT"]))
local minimap=M:Record(assert(A.byID["binding:MINIMAPZOOMOUT"]))
assert(camera.title==minimap.title and camera.subtitle~=minimap.subtitle,"duplicate binding labels need distinct native groups")
assert(camera.subtitle:find(BINDING_HEADER_CAMERA,1,true) and minimap.subtitle:find(BINDING_HEADER_INTERFACE,1,true),"native localized group missing")
