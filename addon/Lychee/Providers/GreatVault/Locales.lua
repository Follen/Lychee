local I = _G.LycheeInternal
I.ProviderLocaleData = I.ProviderLocaleData or {}
do
    local enUS = {
        ["宏伟宝库"] = "Great vault",
        ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
        ["打开宏伟宝库"] = "Open great vault",
        ["查看宏伟宝库进度与奖励"] = "View great vault progress and rewards",
        ["每周奖励"] = "Weekly rewards",
        ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.ProviderLocaleData["builtin.great-vault"] = {enUS=enUS,zhCN=zhCN}
end
