local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.crests"] = {
    ["当前角色 · 迷雾纹章"] = "当前角色 · 迷雾纹章",
    ["查看当前角色的迷雾纹章数量"] = "查看当前角色的迷雾纹章数量",
    ["查看纹章"] = "查看纹章",
    ["纹章"] = "纹章",
    ["角色货币"] = "角色货币",
    ["货币 %d"] = "货币 %d",
}
