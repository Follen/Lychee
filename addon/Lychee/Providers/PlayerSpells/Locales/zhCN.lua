local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.player-spells"] = {
    ["技能"] = "技能",
    ["施放"] = "施放",
    ["玩家技能"] = "玩家技能",
}
