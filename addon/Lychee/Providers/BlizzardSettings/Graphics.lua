local I=_G.LycheeInternal
local L=I.ProviderLocales:Module("builtin.blizzard-settings")
local G={};I.ProviderModules.SettingsGraphics=G
-- Retail 12.1.0 Graphics.lua/GraphicsOverrides.lua: native composite controls
-- keep settings in two private maps instead of separate list initializers.
function G.Collect(initializer,categoryID,categoryName,add,checkpoint)
 local A=I.ProviderModules.SettingsAdapter
 for _,field in ipairs({"settings","raidSettings"}) do
  local map=initializer.data[field]
  if type(map)=="table" then
   local keys={};for key in pairs(map) do keys[#keys+1]=key;if #keys>64 then error("GRAPHICS_SETTINGS_LIMIT") end end;table.sort(keys)
   for _,cvar in ipairs(keys) do
    local s=map[cvar];local variable=A.Call(s,"GetVariable");local name=A.Call(s,"GetName")
    if type(variable)=="string" and type(name)=="string" then
     local raid=field=="raidSettings"
     local spec={id="setting:"..variable,variable=variable,name=raid and L:Format("团队 · %s",name) or name,
      categoryID=categoryID,categoryName=categoryName,initializer=initializer,cvar=cvar,raid=raid}
     add(spec)
    end
    checkpoint()
   end
  end
 end
 local setting=Settings.GetSetting and Settings.GetSetting("RAIDsettingsEnabled")
 if setting then add({id="setting:RAIDsettingsEnabled",variable="RAIDsettingsEnabled",name=A.Call(setting,"GetName"),initializer=initializer,categoryID=categoryID,categoryName=categoryName}) end
end
