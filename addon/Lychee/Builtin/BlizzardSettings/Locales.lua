local I=_G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
do
    local enUS = {
        ["%s · 切换开关"] = "%s · Toggle",
        ["直接调整"] = "Adjust directly",
        ["已更新"] = "Updated",
        ["设置未能确认，请检查可用范围或打开暴雪设置"] = "Change not confirmed; check the range or open Blizzard settings",
        ["范围 %s–%s，步长 %s"] = "Range %s–%s, step %s",
        ["选择后立即生效"] = "Selections take effect immediately",
        ["应用"] = "Apply",
        ["预填并打开设置"] = "Prefill and open settings",
        ["请输入 %s–%s 范围内的数值"] = "Enter a value from %s to %s",
        ["请选择要设置的值"] = "Enter the value to set",
        ["请输入数字"] = "Enter a number",
        ["上一页"] = "Previous",
        ["下一页"] = "Next",
        ["团队 · %s"] = "Raid · %s",
        ["设置开关"] = "Set switch",
        ["切换开关"] = "Toggle",
        ["设置数值"] = "Set value",
        ["设置颜色"] = "Set color",
        ["增加"] = "Increase",
        ["减少"] = "Decrease",
        ["选择选项"] = "Choose option",
        ["设置选项"] = "Set option",
        ["恢复默认值"] = "Restore default",
        ["开启"] = "On",
        ["关闭"] = "Off",
        ["（需应用）"] = " (Apply required)",
        ["预填到暴雪设置，点击应用后生效"] = "Prefill Blizzard settings; click Apply to confirm",
        ["无法识别这个值，请打开设置查看可用范围和选项"] = "Value not recognized; open settings to see the available range or options",
        ["%s · 点击定位"] = "%s · Click to locate",
        ["%s · 直接调整"] = "%s · Adjust directly",
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
