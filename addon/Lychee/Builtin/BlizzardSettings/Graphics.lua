local I=_G.LycheeInternal
local L=I.ProviderLocales:Builtin("builtin.blizzard-settings")
local G={};I.Builtin.SettingsGraphics=G
-- Retail 12.1.0 Graphics.lua/GraphicsOverrides.lua: native composite controls
-- keep settings in two private maps instead of separate list initializers.
local choices={
 ShadowQuality={"LOW","FAIR","MEDIUM","HIGH","ULTRA","ULTRA_HIGH"},
 LiquidDetail={"LOW","FAIR","MEDIUM","HIGH"},
 ParticleDensity={"DISABLED","LOW","FAIR","MEDIUM","HIGH","ULTRA"},
 SSAO={"DISABLED","LOW","MEDIUM","HIGH","ULTRA"},
 DepthEffects={"DISABLED","LOW","MEDIUM","HIGH"},
 ComputeEffects={"DISABLED","LOW","MEDIUM","HIGH","ULTRA"},
 OutlineMode={"DISABLED","MEDIUM","HIGH"},TextureResolution={"LOW","FAIR","HIGH"},
 SpellDensity={"SFX_DENSITY_MIN","SFX_DENSITY_REDUCED","SFX_DENSITY_FULL"},ProjectedTextures={"DISABLED","ENABLED"},
}
local slider={Quality=true,ViewDistance=true,EnvironmentDetail=true,GroundClutter=true}
function G.Collect(initializer,categoryID,categoryName,add,checkpoint)
 local A=I.Builtin.SettingsAdapter
 for _,field in ipairs({"settings","raidSettings"}) do
  local map=initializer.data[field]
  if type(map)=="table" then
   local keys={};for key in pairs(map) do keys[#keys+1]=key;if #keys>64 then error("GRAPHICS_SETTINGS_LIMIT") end end;table.sort(keys)
   for _,cvar in ipairs(keys) do
    local s=map[cvar];local variable=A.Call(s,"GetVariable");local name=A.Call(s,"GetName")
    if type(variable)=="string" and type(name)=="string" then
     local raid=field=="raidSettings";local suffix=cvar:match("^[Rr]?aidGraphics(.+)$") or cvar:match("^graphics(.+)$")
     local spec={id="setting:"..variable,variable=variable,name=raid and L:Format("团队 · %s",name) or name,
      categoryID=categoryID,categoryName=categoryName,setting=s,initializer=initializer,cvar=cvar,raid=raid,
      parent=raid and Settings.GetSetting and Settings.GetSetting("RAIDsettingsEnabled") or nil}
     if slider[suffix] then spec.options={minValue=0,maxValue=9,steps=9};spec.offset=1;spec.template="SettingsSliderControlTemplate"
     elseif choices[suffix] then
      spec.template="SettingsDropdownControlTemplate"
      spec.options=function()
       if type(IsGraphicsSettingValueSupported)~="function" then return {} end
       local out={}
       for n,key in ipairs(choices[suffix]) do
        local value=n-1;local ok,why=pcall(IsGraphicsSettingValueSupported,cvar,value,raid)
        out[n]={value=value,label=_G["VIDEO_OPTIONS_"..key] or tostring(value),controlType=Settings.ControlType.Radio,disabled=not ok or why~=nil and why~=0}
       end
       return out
      end
     end
     add(spec)
    end
    checkpoint()
   end
  end
 end
 local setting=Settings.GetSetting and Settings.GetSetting("RAIDsettingsEnabled")
 if setting then add({id="setting:RAIDsettingsEnabled",variable="RAIDsettingsEnabled",name=A.Call(setting,"GetName"),setting=setting,initializer=initializer,categoryID=categoryID,categoryName=categoryName}) end
end
