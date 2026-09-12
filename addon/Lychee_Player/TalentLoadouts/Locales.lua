local _,I=...
I.ProviderLocaleData = I.ProviderLocaleData or {}
do
    local enUS = {
        ["专精已改变，请重新搜索"] = "Your specialization changed. Search again.",
        ["天赋方案"] = "Talent loadouts",
        ["天赋方案已删除"] = "This talent loadout was deleted",
        ["应用方案"] = "Apply loadout",
        ["当前方案"] = "Current loadout",
        ["点击应用天赋方案"] = "Click to apply this talent loadout",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.ProviderLocaleData["lychee.talent-loadouts"] = {enUS=enUS,zhCN=zhCN}
end
