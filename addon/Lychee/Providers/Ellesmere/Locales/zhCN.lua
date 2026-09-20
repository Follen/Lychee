local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.ellesmere"] = {
    ["Ellesmere UI 设置暂不可用"] = "Ellesmere UI 设置暂不可用",
    ["Ellesmere UI 设置目录超出限制"] = "Ellesmere UI 设置目录超出限制",
    ["打开设置"] = "打开设置",
    ["此设置页面已不可用"] = "此设置页面已不可用",
    ["解锁界面"] = "解锁界面",
    ["请先启用 Ellesmere UI"] = "请先启用 Ellesmere UI",
    ["请先脱离战斗"] = "请先脱离战斗",
    ["进入 Ellesmere UI 解锁模式"] = "进入 Ellesmere UI 解锁模式",
}
