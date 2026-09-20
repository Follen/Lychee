local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.mounts"] = {
    ["召唤"] = "召唤",
    ["坐骑"] = "坐骑",
    ["点击召唤 · 可拖到动作条"] = "点击召唤 · 可拖到动作条",
}
