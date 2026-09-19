local f=dofile("tests/support/settings_fixture.lua").Load()
local I,A,G,M=f.I,f.A,f.G,f.M
local advance,writes,state=f.advance,f.writes,f.state
local loot,fps,display,gfx,gfxShadow,color,scale,use=f.loot,f.fps,f.display,f.gfx,f.gfxShadow,f.color,f.scale,f.use
I.Registry:SetReady(true);assert(M:Init());advance();assert(not M.dirty,M.lastError)
assert(A.byID["binding:CLICK_20ExampleButton:LeftButton"].name~=A.byID["binding:CLICK_5F20ExampleButton:LeftButton"].name,"escaped binding IDs collided")
assert(A.byID["category:1"],"native category must remain available for oversized bindings")
assert(A.byID['setting:PROXY_DISPLAY_MODE'].kind=="choice","boolean dropdown is not a toggle")
assert(A.byID['setting:PROXY_UI_SCALE'].name=="UI缩放","composite visible label must override internal name")
for _,s in ipairs(A.ordered) do assert(s.name~="分组标题","section header became an action") end
for _,text in ipairs({"把后台帧数调到","set background fps to","后台帧数设置为"}) do
 local p=G.Parse(text);assert(p and p.code=="MISSING_ARGS",text.." must request a value instead of reporting invalid input")
end
local positive={
 {"把后台帧数调节到30","maxFPSBk","number",30},{"調節背景音樂音量至30","Sound_MusicVolume","number",30},
 {"把音乐音量调节为30","Sound_MusicVolume","number",30},{"adjust music volume to 30","Sound_MusicVolume","number",30},
 {"后台帧数三十","maxFPSBk","number",30},{"后台帧数调低到30","maxFPSBk","number",30},
 {"please turn off background music","Sound_EnableMusic","boolean",false},{"关闭背景音乐","Sound_EnableMusic","boolean",false},
 {"静音","Sound_EnableAllSound","boolean",false},{"unmute","Sound_EnableAllSound","boolean",true},
 {"生命条背景色设为#123456","raidFramesHealthBarColorBG","color"},
 {"画质设为7","PROXY_GRAPHICS_QUALITY","number",7},
 {"开启自动拾取","autoLootDefault","boolean",true},{"请帮我把自动拾取打开","autoLootDefault","boolean",true},
 {"关闭自动拾取","autoLootDefault","boolean",false},{"自动拾取设为关闭","autoLootDefault","boolean",false},
 {"enable auto loot","autoLootDefault","boolean",true},{"please turn off auto loot","autoLootDefault","boolean",false},
 {"自动拾取重置","autoLootDefault","reset"},{"toggle auto loot","autoLootDefault","toggle"},
 {"后台帧数30","maxFPSBk","number",30},{"把后台帧数设置到30","maxFPSBk","number",30},
 {"please set the background fps to 30 fps","maxFPSBk","number",30},
 {"后台帧数调高10","maxFPSBk","increase",10},{"decrease background fps by 10","maxFPSBk","decrease",10},
 {"提高后台帧数","maxFPSBk","increase"},{"关闭音乐","Sound_EnableMusic","boolean",false},
 {"麦克风音量设为30%","PROXY_VOICE_INPUT_VOLUME","number",30},
 {"设置分辨率为1920x1080","PROXY_RESOLUTION","choice"},
 {"显示模式设为窗口","PROXY_DISPLAY_MODE","choice"},
 {"把界面缩放设置到80%","PROXY_UI_SCALE","number",80},
 {"综合阴影设为low","PROXY_SHADOW_QUALITY","choice"},
}
for _,v in ipairs(positive) do local p,why=G.Parse(v[1]);assert(p and p.spec.variable==v[2] and p.operation==v[3],v[1]..":"..tostring(p and p.operation or why));if v[4]~=nil then assert(p.args.value==v[4],v[1]) end end
assert(G.Parse("显示模式设为窗口").args.choice=="boolean:false")
for _,q in ipairs({"不要开启自动拾取","do not enable auto loot","后台帧数30 40","后台帧数30oops","后台帧数-30","auto looting on","请把自动拾取和音乐关闭"}) do
 local p=G.Parse(q);assert(not p or p.operation=="invalid",q)
end
assert(#writes==0,"discovery and parsing changed settings")
for _,path in ipairs({"Core/UserPreferences.lua","Core/ResultActionExecutor.lua"}) do dofile("addon/Lychee/"..path) end
local palette={visible=true,session=1,generation=1,RejectRow=function(_,_,err) return false,err end}
I.ResultActionExecutor:BindPalette(palette)
local function query(q)
 local completed
 local ok,items=I.Search.Query:Query(q,{visible=true},1,function(result) completed=result end);assert(ok)
 advance();items=completed or items
 assert(#items>0,q.." returned nothing")
 return {item=items[1],session=1,generation=1,extensionID=M.id}
end
for _,case in ipairs({{"music volume","Sound_MusicVolume"},{"effects volume","Sound_SFXVolume"},{"音乐音量","Sound_MusicVolume"},{"音效音量","Sound_SFXVolume"}}) do
 local row=query(case[1])
 assert(row.item.id=="setting:"..case[2],case[1].." selected "..row.item.id)
 assert(row.item.interaction.primaryActionID=="adjust-volume",case[1].." must adjust, not toggle")
end
for _,case in ipairs({{"turn off music volume","Sound_EnableMusic"},{"关闭音乐音量","Sound_EnableMusic"},{"enable effects volume","Sound_EnableSFX"}}) do
 local parsed=G.Parse(case[1]);assert(parsed and parsed.spec.variable==case[2] and parsed.operation=="boolean",case[1])
end
local r=query("自动拾取");assert(r.item.interaction.primaryActionID=="toggle")
assert(I.ResultActionExecutor:ExecutePrimary(r).ok and loot.value)
assert(I.ResultActionExecutor:Execute(r,"disable").ok and not loot.value)
assert(I.UserPreferences:GetRecent()[1].args.value==false)
local disabled=assert(I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]))
assert(disabled.text==r.item.text and disabled.interaction.actions[1].title==(GetLocale()=="enUS" and "Off" or "关闭"),"restored right-click action lost its specific label")
r=query("后台帧数30");assert(r.item.ref.actionID=="setting-number")
assert(I.ResultActionExecutor:ExecutePrimary(r).ok and fps.value==30)
local thirty=I.UserPreferences:GetRecent()[1]
local restoreThirty=assert(I.UserPreferences:Resolve(thirty))
assert(restoreThirty.text:find("30",1,true) and restoreThirty.kindTitle~="","numeric history lost parameters or source")
local slider={kind="invocation",product="retail",providerID=M.id,actionID="setting-number",actionVersion=1,
 target=thirty.target,args={value=50},title="Set value"}
assert(I.UserPreferences:Resolve(slider).text:find("50",1,true),"non-audio slider history lost target/value")
r=query("后台帧数调高10");assert(I.ResultActionExecutor:ExecutePrimary(r).ok and fps.value==40)
r=query("显示模式设为窗口");assert(r.item.ref.actionID=="stage-choice")
local staged=I.ResultActionExecutor:ExecutePrimary(r)
assert(staged.ok and display.value==true and display.pending==false and state.shown,"staging must not apply")
assert(staged.message:find(GetLocale()=="enUS" and "Apply" or "应用",1,true),"staged action claimed it already took effect")
assert(A.Write(A.byVariable.PROXY_GRAPHICS_QUALITY,"number",{value=7},true).status=="succeeded" and gfx.pending==6 and gfx.value==5)
local rejected=G.Parse("综合阴影设为最高");assert(rejected and rejected.operation=="invalid")
assert(A.Write(A.byVariable.PROXY_SHADOW_QUALITY,"choice",{choice="number:5"},true).status=="failed")
assert(A.Write(A.byVariable.raidFramesHealthBarColorBG,"color",{color="ff123456"},false).status=="succeeded" and color.value=="FF123456")
assert(A.Write(A.byVariable.PROXY_UI_SCALE,"number",{value=80},true).status=="succeeded" and scale.pending==.8)
use.pending=false;assert(A.Write(A.byVariable.PROXY_UI_SCALE,"number",{value=85},true).status=="failed");use.pending=nil
local before=#writes;local spec=A.byID['setting:maxFPSBk']
for _,v in ipairs({-1,300,30.5}) do assert(A.Write(spec,"number",{value=v},false).status=="failed") end
state.combat=true;assert(A.Write(spec,"number",{value=30},false).status=="failed");state.combat=false
assert(#writes==before)
local actual=fps.SetValue;fps.SetValue=function() error('setter failed') end
assert(A.Write(spec,"number",{value=30},false).status=="indeterminate");fps.SetValue=actual
local _,negative=I.Search.Query:Query("不要开启自动拾取",{visible=true},1);assert(#negative==0)
assert(M.handle:Unregister());assert(not next(A.byID) and not next(G.index))
print("Blizzard Invocation PASS: metadata, full bilingual grammar, default/menu actions, actual history, staged choices, range/combat/failure guards and cleanup")
