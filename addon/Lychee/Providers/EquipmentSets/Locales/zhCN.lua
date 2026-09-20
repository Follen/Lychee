local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.equipment-sets"] = {
    ["当前装备方案"] = "当前装备方案",
    ["无法装备此方案"] = "无法装备此方案",
    ["点击装备方案"] = "点击装备方案",
    ["装备方案"] = "装备方案",
    ["装备方案已删除"] = "装备方案已删除",
    ["部分装备缺失"] = "部分装备缺失",
}
