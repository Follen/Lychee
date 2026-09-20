local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.keystones"] = {
    ["传送"] = "Teleport",
    ["分数 %s"] = "Rating %s",
    ["分数未知"] = "Rating unknown",
    ["副本 %d"] = "Instance %d",
    ["尚未解锁对应传送"] = "Dungeon teleport not unlocked",
    ["当季副本成绩"] = "Season dungeon records",
    ["暂无钥匙"] = "No keystone",
    ["未完成"] = "Not completed",
    ["未获取"] = "Unavailable",
    ["点击传送至该副本"] = "Click to teleport to this dungeon",
    ["等待队友的兼容插件回复"] = "Waiting for a compatible party addon to reply",
    ["赛季副本列表尚未获取"] = "Season dungeon list is not available yet",
    ["超时 +%d"] = "Over time +%d",
    ["钥匙未知"] = "Keystone unknown",
    ["队伍钥匙"] = "Party keystones",
    ["限时 +%d"] = "In time +%d",
}
