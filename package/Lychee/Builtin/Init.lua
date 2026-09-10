local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
-- Evaluated once at login, before a module can allocate frames or subscribe.
local all = {retail=true, classic=true, titan=true, anniversary=true}
local collections = {retail=true, classic=true, titan=true}
local retail = {retail=true}
local modules = {
    {"PlayerSpells",all}, {"Mounts",collections}, {"Crests",retail},
    {"GameMenus",all}, {"Bosses",retail}, {"GreatVault",retail},
    {"Bags",all}, {"TalentLoadouts",retail}, {"EquipmentSets",collections},
    {"BlizzardSettings",all}, {"Keystones",retail},
    {"Achievements",collections}, {"AddonInspector",all},
}
local function functions(namespace, ...)
    if type(namespace) ~= "table" then return false end
    for index=1,select("#",...) do
        if type(namespace[select(index,...)]) ~= "function" then return false end
    end
    return true
end
local function available(name)
    if name=="Mounts" then return functions(C_MountJournal,"GetMountIDs","GetMountInfoByID") end
    if name=="EquipmentSets" then return functions(C_EquipmentSet,"GetEquipmentSetIDs","GetEquipmentSetInfo","UseEquipmentSet") end
    if name=="Achievements" then return functions(_G,"GetCategoryList","GetAchievementInfo","GetAchievementCriteriaInfo","GetAchievementNumCriteria","GetAchievementLink") end
    if name=="Bags" then return functions(C_Container,"GetContainerNumSlots","GetContainerItemInfo") end
    if name=="AddonInspector" then return type(GetMouseFoci)=="function" end
    return true
end
function I.Builtin:Init()
    if self._initialized then return end
    self._initialized=true
    local product=I.Search.RuntimeIdentity:Current().product
    for index=1,#modules do
        local spec=modules[index]
        local module=self[spec[1]]
        if spec[2][product] and module and type(module.Init)=="function" and available(spec[1]) then
            module:Init()
        end
    end
end
