local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.bosses"] = {
    ["副本 %d"] = "Instance %d",
    ["史诗"] = "Mythic",
    ["团本首领"] = "Raid bosses",
    ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
    ["技能"] = "Ability",
    ["技能 %d"] = "Ability %d",
    ["普通"] = "Normal",
    ["查看技能指南"] = "View ability guide",
    ["查看首领指南"] = "View encounter guide",
    ["英雄"] = "Heroic",
    ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
    ["首领"] = "Bosses",
    ["首领 %d"] = "Boss %d",
}
