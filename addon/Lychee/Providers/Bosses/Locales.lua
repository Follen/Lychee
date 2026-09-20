local I = _G.LycheeInternal
I.ProviderLocaleData = I.ProviderLocaleData or {}
do
    local enUS = {
        ["团本首领"] = "Raid bosses",
        ["普通"] = "Normal", ["英雄"] = "Heroic", ["史诗"] = "Mythic",
        ["技能"] = "Ability", ["技能 %d"] = "Ability %d",
        ["查看技能指南"] = "View ability guide",
        ["副本 %d"] = "Instance %d",
        ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
        ["查看首领指南"] = "View encounter guide",
        ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
        ["首领"] = "Bosses",
        ["首领 %d"] = "Boss %d",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.ProviderLocaleData["builtin.bosses"] = {enUS=enUS,zhCN=zhCN}
end
