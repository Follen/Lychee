local I = _G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
do
    local enUS = {
        ["技能"] = "Spells",
        ["施放"] = "Cast",
        ["玩家技能"] = "Player spells",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.player-spells"] = {enUS=enUS,zhCN=zhCN}
end
