local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.exwind"] = {
    ["Exwind 设置暂不可用"] = "Exwind settings are unavailable",
    ["Exwind 设置目录超出限制"] = "Exwind settings catalog exceeds the limit",
    ["打开所在设置页"] = "Open settings page",
    ["打开面板"] = "Open panel",
    ["此设置页面已不可用"] = "This settings page is no longer available",
    ["解锁界面"] = "Unlock layout",
    ["请先启用 Exwind Core"] = "Enable Exwind Core first",
    ["请先脱离战斗"] = "Leave combat first",
    ["进入 Exwind 编辑模式"] = "Enter Exwind Edit Mode",
}
