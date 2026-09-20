local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.ellesmere"] = {
    ["Ellesmere UI 设置暂不可用"] = "Ellesmere UI settings are unavailable",
    ["Ellesmere UI 设置目录超出限制"] = "Ellesmere UI settings catalog exceeds the limit",
    ["打开设置"] = "Open settings",
    ["此设置页面已不可用"] = "This settings page is no longer available",
    ["解锁界面"] = "Unlock layout",
    ["请先启用 Ellesmere UI"] = "Enable Ellesmere UI first",
    ["请先脱离战斗"] = "Leave combat first",
    ["进入 Ellesmere UI 解锁模式"] = "Enter Ellesmere UI Unlock Mode",
}
