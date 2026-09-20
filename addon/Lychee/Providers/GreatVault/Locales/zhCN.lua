local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.great-vault"] = {
    ["宏伟宝库"] = "宏伟宝库",
    ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "当前无法打开此界面，请检查角色条件或稍后重试。",
    ["打开宏伟宝库"] = "打开宏伟宝库",
    ["查看宏伟宝库进度与奖励"] = "查看宏伟宝库进度与奖励",
    ["每周奖励"] = "每周奖励",
    ["请在脱离战斗后打开此界面。"] = "请在脱离战斗后打开此界面。",
}
