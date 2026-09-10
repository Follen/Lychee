local I = _G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
do
    local enUS = {
        ["%s · 点击定位"] = "%s · Click to locate",
        ["打开冷却管理器"] = "Open cooldown manager",
        ["打开冷却管理器设置"] = "Open cooldown manager settings",
        ["打开并定位"] = "Open and locate",
        ["暴雪冷却管理器"] = "Blizzard cooldown manager",
        ["暴雪设置"] = "Blizzard settings",
        ["系统"] = "System",
        ["重新加载插件与界面"] = "Reload addons and the interface",
        ["重载界面"] = "Reload UI",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.blizzard-settings"] = {enUS=enUS,zhCN=zhCN}
end
