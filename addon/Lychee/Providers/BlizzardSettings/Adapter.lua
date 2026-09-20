local I=_G.LycheeInternal
-- Discover stable native destinations only; no values, options or setters are exposed.
local A={byID={},byVariable={},ordered={}}
I.ProviderModules.SettingsAdapter=A
local fields={"setting","cbSetting","sliderSetting","dropdownSetting"}
local function scalar(v)
 if issecretvalue and issecretvalue(v) then return nil end
 local t=type(v);if t=="string" or t=="boolean" or t=="number" and v==v and math.abs(v)<=1e9 then return v end
end
local function call(o,k,...)
 if o and type(o[k])=="function" then local ok,v=pcall(o[k],o,...);if ok then return v end end
end
A.Call=call
function A.Available(spec)
 -- A native control's visibility is not a prerequisite for opening its category.
 return spec~=nil and not (InCombatLockdown and InCombatLockdown())
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
  map[spec.id]=spec;ordered[#ordered+1]=spec
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
    if template=="SettingsAdvancedQualitySectionTemplate" and I.ProviderModules.SettingsGraphics then
     I.ProviderModules.SettingsGraphics.Collect(initializer,categoryID,categoryName,add,checkpoint);found=true
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
       initializer=initializer})
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
 if not A.Available(spec) or not C_SettingsUtil or not C_SettingsUtil.OpenSettingsPanel then return {status="failed",code="SETTINGS_NOT_READY"} end
 local ok=pcall(C_SettingsUtil.OpenSettingsPanel,spec.categoryID,spec.searchName or spec.name)
 local selected=call(SettingsPanel,"GetCurrentCategory")
 if not ok or not selected or call(selected,"GetID")~=spec.categoryID or call(SettingsPanel,"IsShown")~=true then return {status="failed",code="SETTINGS_NOT_READY"} end
 return {status="succeeded"}
end
