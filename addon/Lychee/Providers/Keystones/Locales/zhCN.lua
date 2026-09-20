local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.keystones"] = {
    ["传送"] = "传送",
    ["分数 %s"] = "分数 %s",
    ["分数未知"] = "分数未知",
    ["副本 %d"] = "副本 %d",
    ["尚未解锁对应传送"] = "尚未解锁对应传送",
    ["当季副本成绩"] = "当季副本成绩",
    ["暂无钥匙"] = "暂无钥匙",
    ["未完成"] = "未完成",
    ["未获取"] = "未获取",
    ["点击传送至该副本"] = "点击传送至该副本",
    ["等待队友的兼容插件回复"] = "等待队友的兼容插件回复",
    ["赛季副本列表尚未获取"] = "赛季副本列表尚未获取",
    ["超时 +%d"] = "超时 +%d",
    ["钥匙未知"] = "钥匙未知",
    ["队伍钥匙"] = "队伍钥匙",
    ["限时 +%d"] = "限时 +%d",
}
