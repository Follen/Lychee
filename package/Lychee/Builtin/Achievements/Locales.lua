local I = _G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
do
    local enUS = {
        ["%s · %d 点 · Shift 点击贴到聊天框"] = "%s · %d points · Shift-click to share in chat",
        ["已完成"] = "Completed",
        ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
        ["当前无法打开聊天输入框"] = "Unable to open chat right now",
        ["当前无法生成成就链接"] = "Unable to create an achievement link right now",
        ["成就"] = "Achievements",
        ["未完成"] = "Not completed",
        ["条件 %d/%d"] = "Criteria %d/%d",
        ["查看成就"] = "View achievement",
        ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
        ["贴到聊天框"] = "Share in chat",
        ["进度 %s/%s"] = "Progress %s/%s",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.achievements"] = {enUS=enUS,zhCN=zhCN}
end
