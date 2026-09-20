local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.achievements"] = {
    ["%s · %d 点 · Shift 点击贴到聊天框"] = "%s · %d 点 · Shift 点击贴到聊天框",
    ["已完成"] = "已完成",
    ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "当前无法打开此界面，请检查角色条件或稍后重试。",
    ["当前无法打开聊天输入框"] = "当前无法打开聊天输入框",
    ["当前无法生成成就链接"] = "当前无法生成成就链接",
    ["成就"] = "成就",
    ["未完成"] = "未完成",
    ["条件 %d/%d"] = "条件 %d/%d",
    ["查看成就"] = "查看成就",
    ["请在脱离战斗后打开此界面。"] = "请在脱离战斗后打开此界面。",
    ["贴到聊天框"] = "贴到聊天框",
    ["进度 %s/%s"] = "进度 %s/%s",
}
