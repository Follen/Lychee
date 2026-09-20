local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.bosses"] = {
    ["副本 %d"] = "副本 %d",
    ["史诗"] = "史诗",
    ["团本首领"] = "团本首领",
    ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "当前无法打开此界面，请检查角色条件或稍后重试。",
    ["技能"] = "技能",
    ["技能 %d"] = "技能 %d",
    ["普通"] = "普通",
    ["查看技能指南"] = "查看技能指南",
    ["查看首领指南"] = "查看首领指南",
    ["英雄"] = "英雄",
    ["请在脱离战斗后打开此界面。"] = "请在脱离战斗后打开此界面。",
    ["首领"] = "首领",
    ["首领 %d"] = "首领 %d",
}
