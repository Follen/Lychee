LycheeInternal={Locale={code="enUS"},ProviderModules={}}
local I=LycheeInternal
local root="addon/Lychee/"
dofile(root.."Providers/Definitions.lua")
dofile(root.."Providers/Shared/Support.lua")
dofile(root.."Core/ProviderLocales.lua")
dofile(root.."Providers/Achievements/Locales.lua")
dofile(root.."Providers/AddonInspector/Locales.lua")
dofile(root.."Providers/Bags/Locales.lua")
dofile(root.."Providers/BlizzardSettings/Locales.lua")
dofile(root.."Providers/Bosses/Locales.lua")
dofile(root.."Providers/Crests/Locales.lua")
dofile(root.."Providers/EquipmentSets/Locales.lua")
dofile(root.."Providers/GameMenus/Locales.lua")
dofile(root.."Providers/GreatVault/Locales.lua")
dofile(root.."Providers/Keystones/Locales.lua")
dofile(root.."Providers/Mounts/Locales.lua")
dofile(root.."Providers/PlayerSpells/Locales.lua")
dofile(root.."Providers/TalentLoadouts/Locales.lua")
local P=I.ProviderLocales
local compile=P.Compile
local calls=0
function P:Compile(...) calls=calls+1;return compile(self,...) end
local talent=assert(P:Module("builtin.talent-loadouts"))
assert(P:Module("builtin.talent-loadouts")==talent and calls==1)
local gear=assert(P:Module("builtin.equipment-sets"));assert(gear~=talent and calls==2)
for i=1,1000 do assert(P:Module("builtin.equipment-sets")==gear) end
assert(calls==2)
I.ProviderLocaleData.unknown={enUS={a="x"}}
for i=1,100 do local t,e=P:Module("unknown");assert(not t and e.code=="INVALID_LOCALE_KEY") end
assert(calls==2)
local original=I.ProviderLocaleData["builtin.equipment-sets"]
I.ProviderLocaleData["builtin.equipment-sets"]={enUS={["装备方案"]="Replacement"}}
local replaced=assert(P:Module("builtin.equipment-sets"));assert(replaced~=gear and replaced["装备方案"]=="Replacement" and calls==3)
assert(gear["装备方案"]=="Equipment sets")
I.ProviderLocaleData["builtin.equipment-sets"].enUS={["装备方案"]="Language table replacement"}
assert(P:Module("builtin.equipment-sets")["装备方案"]=="Language table replacement" and calls==4)
I.ProviderLocaleData["builtin.equipment-sets"]=original
I.Locale.code="zhCN"
assert(P:Module("builtin.equipment-sets")["装备方案"]=="装备方案")
I.Locale.code="enUS"
assert(P:Module("builtin.equipment-sets")["装备方案"]=="Equipment sets")
-- Both Providers intentionally define identical keys with conflicting texts.
-- Actual scanners and action callbacks must select their own namespace.
local all={}
for _,id in ipairs({"builtin.talent-loadouts","builtin.equipment-sets"}) do
 for key in pairs(I.ProviderLocaleData[id].enUS) do all[key]=true end
end
for _,id in ipairs({"builtin.talent-loadouts","builtin.equipment-sets"}) do
 local dict={};for key in pairs(all) do dict[key]=id..":"..key end
 I.ProviderLocaleData[id]={enUS=dict}
end
local catalog={}
function catalog:New(id,title,events,scanner,actions) return {id=id,title=title,scanner=scanner,actions=actions} end
I.ProviderModules.CatalogProvider=catalog
C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 62 end}
C_ClassTalents={GetConfigIDsBySpecID=function() return {7} end,GetLastSelectedSavedConfigID=function() return 7 end}
C_Traits={GetConfigInfo=function() return {name="Player talent name"} end}
local exists=true
C_EquipmentSet={GetEquipmentSetIDs=function() return {8} end,GetEquipmentSetInfo=function() if exists then return "Player gear name",123,nil,true end end,UseEquipmentSet=function() return false end}
dofile(root.."Providers/TalentLoadouts/Provider.lua")
dofile(root.."Providers/EquipmentSets/Provider.lua")
local function collect(module)
 local result={};module.scanner(nil,function(row) result[#result+1]=row end,function() end);return result[1]
end
local t,g=I.ProviderModules.TalentLoadouts,I.ProviderModules.EquipmentSets
local tr,gr=collect(t),collect(g)
assert(tr.kindTitle=="builtin.talent-loadouts:天赋方案" and tr.subtitle=="builtin.talent-loadouts:当前方案")
assert(gr.kindTitle=="builtin.equipment-sets:装备方案" and gr.subtitle=="builtin.equipment-sets:当前装备方案")
assert(gr.title=="Player gear name" and tr.title=="Player talent name")
assert(t.actions.apply.title=="builtin.talent-loadouts:应用方案")
assert(g.actions.equip.title=="builtin.equipment-sets:装备方案")
assert(g.actions.equip.run(gr).message=="builtin.equipment-sets:无法装备此方案")
exists=false;assert(g.actions.equip.run(gr).message=="builtin.equipment-sets:装备方案已删除")
C_ClassTalents.GetConfigIDsBySpecID=function() return {} end
assert(t.actions.apply.run(tr).message=="builtin.talent-loadouts:天赋方案已删除")
local external={enUS={key="Before"}}
local baseline=assert(P:Compile(external))
external.enUS.key="After"
assert(baseline:Text("key")=="Before")
collectgarbage("collect");local memory=collectgarbage("count");local before=calls
for i=1,10000 do P:Module("builtin.talent-loadouts");P:Module("builtin.equipment-sets") end
collectgarbage("collect");assert(calls==before)
print(string.format("Provider locale ownership PASS: actual scans/actions isolated; 20000 cached calls, 0 compilations, %.1f KiB retained growth",collectgarbage("count")-memory))
