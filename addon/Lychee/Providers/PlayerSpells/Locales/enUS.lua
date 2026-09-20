local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.player-spells"] = {
    ["技能"] = "Spells",
    ["施放"] = "Cast",
    ["玩家技能"] = "Player spells",
}
