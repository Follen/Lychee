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
do
    local enUS = {
        ["创建位置来自暴雪代码"] = "Created by Blizzard code",
        ["创建位置："] = "Created at: ",
        ["创建来源"] = "Created by",
        ["可能来自 · 根据框体名称"] = "Likely owner · frame name",
        ["可能来自 · 根据父级来源"] = "Likely owner · parent source",
        ["尚未选择框体"] = "No frame selected",
        ["尺寸："] = "Size: ",
        ["层级："] = "Layer: ",
        ["工具"] = "Tools",
        ["开始识别"] = "Start inspecting",
        ["归属未确定"] = "Owner undetermined",
        ["指向界面，查看来自哪个插件"] = "Point at a frame to identify its addon",
        ["插件识别"] = "Addon inspector",
        ["暂未识别"] = "Not identified",
        ["暴雪创建代码"] = "Blizzard creation code",
        ["未命名框体"] = "Unnamed frame",
        ["未命名父级"] = "Unnamed parent",
        ["未提供创建位置"] = "Source location unavailable",
        ["来源未确定"] = "Source undetermined",
        ["框体："] = "Frame: ",
        ["父级信息已截断"] = "Parent information truncated",
        ["父级关联（不代表修改来源）："] = "Parent chain (does not identify modifications):",
        ["类型："] = "Type: ",
        ["请先启用插件识别来源"] = "Enable the addon inspector provider first",
        ["请在脱离战斗后识别插件"] = "Leave combat before inspecting addons",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.addon-inspector"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["使用物品"] = "Use item",
        ["共 %d 个 · 左键使用 · 右键定位"] = "%d total · Left-click to use · Right-click to locate",
        ["定位背包"] = "Locate in bags",
        ["已打开背包；目标格位当前不可见，请展开对应分类"] = "Bags opened; expand the category containing this item",
        ["物品已不在背包中"] = "This item is no longer in your bags",
        ["背包"] = "Bags",
        ["背包/格位："] = "Bag/slot: ",
        ["背包物品"] = "Bag items",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.bags"] = {enUS=enUS,zhCN=zhCN}
end
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
do
    local enUS = {
        ["副本 %d"] = "Instance %d",
        ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
        ["查看首领指南"] = "View encounter guide",
        ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
        ["首领"] = "Bosses",
        ["首领 %d"] = "Boss %d",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.bosses"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["当前角色 · 迷雾纹章"] = "Current character · crests",
        ["查看当前角色的迷雾纹章数量"] = "View this character's crest balances",
        ["查看纹章"] = "View crests",
        ["纹章"] = "Crests",
        ["角色货币"] = "Character currencies",
        ["货币 %d"] = "Currency %d",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.crests"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["专精已改变，请重新搜索"] = "Your specialization changed. Search again.",
        ["天赋方案"] = "Talent loadouts",
        ["天赋方案已删除"] = "This talent loadout was deleted",
        ["应用方案"] = "Apply loadout",
        ["当前方案"] = "Current loadout",
        ["当前装备方案"] = "Current equipment set",
        ["无法装备此方案"] = "Unable to equip this set",
        ["点击应用天赋方案"] = "Click to apply this talent loadout",
        ["点击装备方案"] = "Click to equip this set",
        ["装备方案"] = "Equipment sets",
        ["装备方案已删除"] = "This equipment set was deleted",
        ["部分装备缺失"] = "Some items are missing",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.equipment-sets"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["专业技能"] = "Professions",
        ["专精"] = "Specialization",
        ["世界地图"] = "World map",
        ["任务日志"] = "Quest log",
        ["传家宝"] = "Heirlooms",
        ["公会与社区"] = "Guild and communities",
        ["冒险指南"] = "Adventure guide",
        ["团队副本"] = "Raids",
        ["团队查找器"] = "Raid finder",
        ["地下城"] = "Dungeons",
        ["地下城和团队"] = "Dungeons and raids",
        ["地下城查找器"] = "Dungeon finder",
        ["坐骑"] = "Mounts",
        ["声望"] = "Reputation",
        ["外观"] = "Appearances",
        ["天赋"] = "Talents",
        ["好友"] = "Friends",
        ["宏命令"] = "Macros",
        ["宠物手册"] = "Pet journal",
        ["当前无法打开此界面，请检查角色条件或稍后重试。"] = "This interface is unavailable. Check character requirements or try again later.",
        ["成就"] = "Achievements",
        ["战团营地"] = "Warband camps",
        ["打开%s"] = "Open %s",
        ["打开界面"] = "Open interface",
        ["推荐玩法"] = "Suggested content",
        ["教程"] = "Tutorials",
        ["旅程"] = "Journeys",
        ["旅行者日志"] = "Traveler's log",
        ["日历"] = "Calendar",
        ["法术书"] = "Spellbook",
        ["游戏菜单"] = "Game menu",
        ["玩具箱"] = "Toy box",
        ["角色"] = "Character",
        ["设置"] = "Settings",
        ["请在脱离战斗后打开此界面。"] = "Leave combat before opening this interface.",
        ["货币"] = "Currency",
        ["预创建队伍"] = "Premade groups",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.game-menus"] = {enUS=enUS,zhCN=zhCN}
end
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
    I.BuiltinLocaleData["builtin.great-vault"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
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
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.keystones"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["召唤"] = "Summon",
        ["坐骑"] = "Mounts",
        ["点击召唤 · 可拖到动作条"] = "Click to summon · Drag to an action bar",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.mounts"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["技能"] = "Spells",
        ["施放"] = "Cast",
        ["玩家技能"] = "Player spells",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.player-spells"] = {enUS=enUS,zhCN=zhCN}
end
do
    local enUS = {
        ["专精已改变，请重新搜索"] = "Your specialization changed. Search again.",
        ["天赋方案"] = "Talent loadouts",
        ["天赋方案已删除"] = "This talent loadout was deleted",
        ["应用方案"] = "Apply loadout",
        ["当前方案"] = "Current loadout",
        ["当前装备方案"] = "Current equipment set",
        ["无法装备此方案"] = "Unable to equip this set",
        ["点击应用天赋方案"] = "Click to apply this talent loadout",
        ["点击装备方案"] = "Click to equip this set",
        ["装备方案"] = "Equipment sets",
        ["装备方案已删除"] = "This equipment set was deleted",
        ["部分装备缺失"] = "Some items are missing",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.talent-loadouts"] = {enUS=enUS,zhCN=zhCN}
end
