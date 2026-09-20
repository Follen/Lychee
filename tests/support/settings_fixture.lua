local function loadFixture()
local clock,timers,writes=0,{},{}
function GetLocale() return arg[1] or "zhCN" end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function GetTime() return clock end
function GetTimePreciseSec() return clock end
local state={combat=false,shown=false}
function InCombatLockdown() return state.combat end
function CreateFrame() return {RegisterEvent=function() end,UnregisterEvent=function() end,UnregisterAllEvents=function() end,SetScript=function() end} end
C_Timer={NewTimer=function(delay,fn) local t={at=clock+delay,fn=fn,Cancel=function(self) self.cancelled=true end};timers[#timers+1]=t;return t end}
local function advance()
 for i=1,100 do clock=clock+.02;local due={};for _,t in ipairs(timers) do if not t.done and not t.cancelled and t.at<=clock then t.done=true;due[#due+1]=t end end;for _,t in ipairs(due) do t.fn() end end
end
Settings={CategorySet={Game=1},ControlType={Radio=1,Checkbox=2},CommitFlag={Apply=1,ClientRestart=2,GxRestart=3,UpdateWindow=4,SaveBindings=5,KioskProtected=6}}
local rows,byVariable={},{}
local function setting(variable,name,value,default,flags)
 local s={variable=variable,name=name,value=value,default=default,flags=flags or {}}
 function s:GetName() return self.name end
 function s:GetVariable() return self.variable end
 function s:GetVariableType() return type(self.value) end
 function s:GetValue() if self.pending~=nil then return self.pending end;return self.value end
 function s:GetValueDerived() return self.value end
 function s:GetDefaultValue() return self.default end
 function s:HasCommitFlag(f) return self.flags[f]==true end
 function s:SetValue(v) writes[#writes+1]={id=self.variable,value=v};if self.flags[1] then self.pending=v else self.value=v end end
 byVariable[variable]=s;return s
end
local function add(s,options,template)
 local row={data={name=s.name,setting=s,options=options},GetTemplate=function() return template or "SettingsCheckboxControlTemplate" end,ShouldShow=function(self) return not self.hidden end,EvaluateModifyPredicates=function(self) return not self.disabled end}
 rows[#rows+1]=row;return row
end
local loot=setting("autoLootDefault","自动拾取",false,true);add(loot)
local fps=setting("maxFPSBk","后台最大帧数",60,30);add(fps,{minValue=10,maxValue=200,steps=190},"SettingsSliderControlTemplate")
local allSound=setting("Sound_EnableAllSound","声音",true,true);add(allSound)
local sound=setting("Sound_EnableMusic","音乐",true,true);add(sound)
local en=GetLocale()=="enUS"
sound.name=en and "Music" or "音乐";rows[#rows].data.name=sound.name
local effects=setting("Sound_EnableSFX",en and "Sound Effects" or "音效",true,true);add(effects)
for variable,name in pairs({Sound_MusicVolume=sound.name,Sound_SFXVolume=en and "Effects" or "音效"}) do
 add(setting(variable,name,.5,.5),{minValue=0,maxValue=1,steps=100},"SettingsSliderControlTemplate")
end
C_CVar={GetCVar=function() return "0.5" end,SetCVar=function() error("unexpected audio write") end}
local voice=setting("PROXY_VOICE_INPUT_VOLUME","麦克风音量",50,50);add(voice,{minValue=0,maxValue=100,steps=100},"SettingsSliderControlTemplate")
local resolution=setting("PROXY_RESOLUTION","分辨率","2560x1440","1920x1080",{[1]=true});add(resolution,function() return {{value="2560x1440",label="2560x1440",controlType=1},{value="1920x1080",label="1920x1080",controlType=1}} end,"SettingsDropdownControlTemplate")
local display=setting("PROXY_DISPLAY_MODE","显示模式",true,true,{[1]=true});add(display,function() return {{value=true,label="全屏（窗口化）",controlType=1},{value=false,label="窗口",controlType=1}} end,"SettingsDropdownControlTemplate")
local use=setting("PROXY_USE_UI_SCALE","渲染倍数",true,false,{[1]=true})
local scale=setting("PROXY_UI_SCALE","渲染倍数",1,1,{[1]=true})
rows[#rows+1]={data={name="使用UI缩放",cbLabel="使用UI缩放",sliderLabel="UI缩放",cbSetting=use,sliderSetting=scale,sliderOptions={minValue=.65,maxValue=1.15,steps=50}},GetTemplate=function() return "SettingsCheckboxSliderControlTemplate" end}
local quality=setting("graphicsShadowQuality","阴影质量",2,1);add(quality,{{value=0,label="关闭",controlType=1},{value=1,label="低",controlType=1},{value=2,label="高",controlType=1}},"SettingsDropdownControlTemplate")
local color=setting("raidFramesHealthBarColorBG","生命条背景色","FF000000","FF000000");add(color,nil,"SettingsColorSwatchControlTemplate")
local gfx=setting("PROXY_GRAPHICS_QUALITY","画质",5,5,{[1]=true})
local gfxShadow=setting("PROXY_SHADOW_QUALITY","综合阴影",2,1,{[1]=true})
VIDEO_OPTIONS_LOW="低";VIDEO_OPTIONS_FAIR="普通";VIDEO_OPTIONS_MEDIUM="中等";VIDEO_OPTIONS_HIGH="高";VIDEO_OPTIONS_ULTRA="极高";VIDEO_OPTIONS_ULTRA_HIGH="最高"
function IsGraphicsSettingValueSupported(_,value) return value==5 and 1 or 0 end
Settings.GetSetting=function(variable) return byVariable[variable] end
rows[#rows+1]={data={settings={graphicsQuality=gfx,graphicsShadowQuality=gfxShadow}},GetTemplate=function() return "SettingsAdvancedQualitySectionTemplate" end}
local header={data={name="分组标题"},GetTemplate=function() return "SettingsListSectionHeaderTemplate" end};rows[#rows+1]=header
local bindings={"CLICK ExampleButton:LeftButton","CLICK_20ExampleButton:LeftButton",string.rep("LongBinding",20)}
function GetBinding(index) return bindings[index] end
function GetBindingName(binding) return "示例快捷键 "..binding end
for index=1,#bindings do rows[#rows+1]={data={bindingIndex=index},GetTemplate=function() return "KeyBindingFrameBindingTemplate" end} end
local cat={GetID=function() return 1 end,GetName=function() return "游戏" end,GetCategorySet=function() return 1 end}
local selected=cat
SettingsPanel={GetAllCategories=function() return {cat} end,GetLayout=function() return {GetInitializers=function() return rows end} end,GetCurrentCategory=function() return selected end,IsShown=function() return state.shown end}
C_SettingsUtil={OpenSettingsPanel=function() state.shown=true end}
local files={"BlizzardSettings/Locales.lua","Shared/CatalogProvider.lua","BlizzardSettings/Provider.lua","BlizzardSettings/Graphics.lua","BlizzardSettings/Adapter.lua","BlizzardSettings/Aliases.lua","BlizzardSettings/Language.lua"}
local extra={"Core/InvocationRuntime.lua","PublicAPI/Invocation.lua"};for _,f in ipairs(files) do extra[#extra+1]="Providers/"..f end
dofile("tests/support/runtime.lua").Load("provider",extra)
return {I=LycheeInternal,A=LycheeInternal.ProviderModules.SettingsAdapter,G=LycheeInternal.ProviderModules.SettingsLanguage,
 M=LycheeInternal.ProviderModules.BlizzardSettings,advance=advance,rows=rows,add=add,setting=setting,
 writes=writes,loot=loot,fps=fps,display=display,gfx=gfx,gfxShadow=gfxShadow,color=color,scale=scale,use=use,
 state=state,namespace=LycheeInternal}
end
return {Load=loadFixture}
