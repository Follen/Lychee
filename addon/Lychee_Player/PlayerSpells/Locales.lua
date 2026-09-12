local _,I=...
I.ProviderLocaleData = I.ProviderLocaleData or {}
do
    local enUS = {
        ["技能"] = "Spells",
        ["施放"] = "Cast",
        ["玩家技能"] = "Player spells",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.ProviderLocaleData["lychee.player-spells"] = {enUS=enUS,zhCN=zhCN}
end
