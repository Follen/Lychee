local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.crests"] = {
    ["当前角色 · 迷雾纹章"] = "Current character · crests",
    ["查看当前角色的迷雾纹章数量"] = "View this character's crest balances",
    ["查看纹章"] = "View crests",
    ["纹章"] = "Crests",
    ["角色货币"] = "Character currencies",
    ["货币 %d"] = "Currency %d",
}
