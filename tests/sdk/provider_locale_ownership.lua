function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","69587","",120100 end
dofile("tests/support/runtime.lua").Load("provider",{"../Lychee_Player/TalentLoadouts/Locales.lua","../Lychee_Player/EquipmentSets/Locales.lua"})
local I=TestPackages.namespaces.Lychee_Player
local root="addon/Lychee/"
local P=I.ProviderLocales
local compile=Lychee.SDK.CompileLocales
for _,id in ipairs({"lychee.talent-loadouts","lychee.equipment-sets"}) do
 local old=I.ProviderLocaleData[id];I.ProviderLocaleData[id]={enUS=old.enUS,zhCN=old.zhCN}
end
local calls=0
function Lychee.SDK.CompileLocales(...) calls=calls+1;return compile(...) end
local talent=assert(P:ForProvider("lychee.talent-loadouts"))
assert(P:ForProvider("lychee.talent-loadouts")==talent and calls==1)
local gear=assert(P:ForProvider("lychee.equipment-sets"));assert(gear~=talent and calls==2)
for i=1,1000 do assert(P:ForProvider("lychee.equipment-sets")==gear) end
assert(calls==2)
local original=I.ProviderLocaleData["lychee.equipment-sets"]
I.ProviderLocaleData["lychee.equipment-sets"]={enUS={["装备方案"]="Replacement"}}
local replaced=assert(P:ForProvider("lychee.equipment-sets"));assert(replaced~=gear and replaced["装备方案"]=="Replacement" and calls==3)
assert(gear["装备方案"]=="Equipment sets")
I.ProviderLocaleData["lychee.equipment-sets"].enUS={["装备方案"]="Language table replacement"}
assert(P:ForProvider("lychee.equipment-sets")["装备方案"]=="Language table replacement" and calls==4)
I.ProviderLocaleData["lychee.equipment-sets"]=original
I.Locale.code="zhCN";LycheeInternal.Locale.code="zhCN"
assert(P:ForProvider("lychee.equipment-sets")["装备方案"]=="装备方案")
I.Locale.code="enUS";LycheeInternal.Locale.code="enUS"
assert(P:ForProvider("lychee.equipment-sets")["装备方案"]=="Equipment sets")
-- Both Providers intentionally define identical keys with conflicting texts.
-- Actual scanners and action callbacks must select their own namespace.
local all={}
for _,id in ipairs({"lychee.talent-loadouts","lychee.equipment-sets"}) do
 for key in pairs(I.ProviderLocaleData[id].enUS) do all[key]=true end
end
for _,id in ipairs({"lychee.talent-loadouts","lychee.equipment-sets"}) do
 local dict={};for key in pairs(all) do dict[key]=id..":"..key end
 I.ProviderLocaleData[id]={enUS=dict}
end
local catalog={}
function catalog:New(id,title,events,scanner,actions) return {id=id,title=title,scanner=scanner,actions=actions} end
I.Modules.CatalogProvider=catalog
C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 62 end}
C_ClassTalents={GetConfigIDsBySpecID=function() return {7} end,GetLastSelectedSavedConfigID=function() return 7 end}
C_Traits={GetConfigInfo=function() return {name="Player talent name"} end}
local exists=true
C_EquipmentSet={GetEquipmentSetIDs=function() return {8} end,GetEquipmentSetInfo=function() if exists then return "Player gear name",123,nil,true end end,UseEquipmentSet=function() return false end}
TestPackages:File(root.."../Lychee_Player/TalentLoadouts/Provider.lua")
TestPackages:File(root.."../Lychee_Player/EquipmentSets/Provider.lua")
local function collect(module)
 local result={};module.scanner(nil,function(row) result[#result+1]=row end,function() end);return result[1]
end
local t,g=TestPackages.Modules.TalentLoadouts,TestPackages.Modules.EquipmentSets
local tr,gr=collect(t),collect(g)
assert(tr.kindTitle=="lychee.talent-loadouts:天赋方案" and tr.subtitle=="lychee.talent-loadouts:当前方案")
assert(gr.kindTitle=="lychee.equipment-sets:装备方案" and gr.subtitle=="lychee.equipment-sets:当前装备方案")
assert(gr.title=="Player gear name" and tr.title=="Player talent name")
assert(t.actions.apply.title=="lychee.talent-loadouts:应用方案")
assert(g.actions.equip.title=="lychee.equipment-sets:装备方案")
assert(g.actions.equip.run(gr).message=="lychee.equipment-sets:无法装备此方案")
exists=false;assert(g.actions.equip.run(gr).message=="lychee.equipment-sets:装备方案已删除")
C_ClassTalents.GetConfigIDsBySpecID=function() return {} end
assert(t.actions.apply.run(tr).message=="lychee.talent-loadouts:天赋方案已删除")
local external={enUS={key="Before"}}
local baseline=assert(Lychee.SDK.CompileLocales(external))
external.enUS.key="After"
assert(baseline:Text("key")=="Before")
collectgarbage("collect");local memory=collectgarbage("count");local before=calls
for i=1,10000 do P:ForProvider("lychee.talent-loadouts");P:ForProvider("lychee.equipment-sets") end
collectgarbage("collect");assert(calls==before)
print(string.format("Provider locale ownership PASS: actual scans/actions isolated; 20000 cached calls, 0 compilations, %.1f KiB retained growth",collectgarbage("count")-memory))
