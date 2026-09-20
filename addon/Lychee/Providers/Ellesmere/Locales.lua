local I = _G.LycheeInternal
I.ProviderLocaleData = I.ProviderLocaleData or {}
local enUS = {
    ["解锁界面"] = "Unlock layout",
    ["进入 Ellesmere UI 解锁模式"] = "Enter Ellesmere UI Unlock Mode",
    ["打开设置"] = "Open settings",
    ["请先启用 Ellesmere UI"] = "Enable Ellesmere UI first",
    ["请先脱离战斗"] = "Leave combat first",
    ["Ellesmere UI 设置暂不可用"] = "Ellesmere UI settings are unavailable",
    ["此设置页面已不可用"] = "This settings page is no longer available",
    ["Ellesmere UI 设置目录超出限制"] = "Ellesmere UI settings catalog exceeds the limit",
}
local zhCN = {}
for key in pairs(enUS) do zhCN[key] = key end
I.ProviderLocaleData["builtin.ellesmere"] = {enUS=enUS,zhCN=zhCN}
