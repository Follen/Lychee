local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.mounts"] = {
    ["召唤"] = "Summon",
    ["坐骑"] = "Mounts",
    ["点击召唤 · 可拖到动作条"] = "Click to summon · Drag to an action bar",
}
