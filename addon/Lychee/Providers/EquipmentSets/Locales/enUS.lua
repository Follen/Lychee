local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.equipment-sets"] = {
    ["当前装备方案"] = "Current equipment set",
    ["无法装备此方案"] = "Unable to equip this set",
    ["点击装备方案"] = "Click to equip this set",
    ["装备方案"] = "Equipment sets",
    ["装备方案已删除"] = "This equipment set was deleted",
    ["部分装备缺失"] = "Some items are missing",
}
