local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.talent-loadouts"] = {
    ["专精已改变，请重新搜索"] = "专精已改变，请重新搜索",
    ["天赋方案"] = "天赋方案",
    ["天赋方案已删除"] = "天赋方案已删除",
    ["应用方案"] = "应用方案",
    ["当前方案"] = "当前方案",
    ["点击应用天赋方案"] = "点击应用天赋方案",
}
