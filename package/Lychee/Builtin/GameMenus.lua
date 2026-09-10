local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.game-menus")
local A = I.Builtin.InterfaceActions
local M = {}
I.Builtin.GameMenus = M

local function character(tab)
    return function() return A:Call(ToggleCharacter, tab, true) and A:IsShown("CharacterFrame") and A:IsShown(tab) end
end
local function spells(method)
    return function() return A:Call(PlayerSpellsUtil and PlayerSpellsUtil[method]) and A:IsShown("PlayerSpellsFrame") end
end
local function collection(tab, frame)
    return function() return A:Call(SetCollectionsJournalShown, true, tab) and A:IsShown("CollectionsJournal") and A:IsShown(frame) end
end
local function toggle(fn, frame, alternate)
    return function() return A:ToggleOpen(_G[fn], frame, alternate) end
end
local function openGroupFinder(side, selection)
    if not C_LFGInfo or not C_LFGInfo.CanPlayerUseGroupFinder then return false end
    local ok, allowed = pcall(C_LFGInfo.CanPlayerUseGroupFinder)
    if not ok or not allowed or (Kiosk and Kiosk.IsEnabled()) then return false end
    return A:Call(PVEFrame_ShowFrame, side, selection) and A:IsShown("PVEFrame")
        and (not side or A:IsShown(side)) and (not selection or A:IsShown(selection))
end
local function groupFinder(side, selection)
    return function() return openGroupFinder(side, selection) end
end
local function journalTab(key)
    return function() return A:OpenJournalTab(key) end
end

local menus = {
    {"character", "角色", {"人物", "装备", "属性", "character"}, character("PaperDollFrame")},
    {"reputation", "声望", {"阵营声望", "reputation"}, character("ReputationFrame")},
    {"currency", "货币", {"代币", "currency"}, character("TokenFrame")},
    {"talents", "天赋", {"天赋树", "talents"}, spells("OpenToClassTalentsTab")},
    {"specialization", "专精", {"切换专精", "specialization"}, spells("OpenToClassSpecializationsTab")},
    {"spellbook", "法术书", {"技能书", "spellbook"}, spells("OpenToSpellBookTab")},
    {"professions", "专业技能", {"专业", "制造", "professions"}, toggle("ToggleProfessionsBook", "ProfessionsBookFrame")},
    {"mounts", "坐骑", {"坐骑收藏", "mounts"}, collection(1, "MountJournal")},
    {"pets", "宠物手册", {"宠物", "战斗宠物", "pets"}, collection(2, "PetJournal")},
    {"toys", "玩具箱", {"玩具", "toys"}, collection(3, "ToyBox")},
    {"heirlooms", "传家宝", {"heirlooms"}, collection(4, "HeirloomsJournal")},
    {"appearances", "外观", {"幻化", "衣柜", "收藏", "外观收藏", "wardrobe", "collections"}, collection(5, "WardrobeCollectionFrame")},
    {"warband-scenes", "战团营地", {"战团场景", "营地", "warband"}, collection(6, "WarbandSceneJournal")},
    {"achievements", "成就", {"成就界面", "achievements"}, toggle("ToggleAchievementFrame", "AchievementFrame")},
    {"quests", "任务日志", {"任务", "任务列表", "quests"}, function() return A:Call(OpenQuestLog) and A:IsShown("WorldMapFrame") end},
    {"map", "世界地图", {"地图", "map"}, toggle("ToggleWorldMap", "WorldMapFrame")},
    {"friends", "好友", {"社交", "好友列表", "friends", "social"}, toggle("ToggleFriendsFrame", "FriendsFrame", "SocialUIFrame")},
    {"guild", "公会与社区", {"公会", "社区", "guild", "communities"}, toggle("ToggleGuildFrame", "CommunitiesFrame", "GuildFinderFrame")},
    {"group-finder", "地下城和团队", {"组队", "队伍查找器", "pve"}, groupFinder()},
    {"dungeon-finder", "地下城查找器", {"随机地下城", "排本", "dungeon finder"}, groupFinder("GroupFinderFrame", "LFDParentFrame")},
    {"raid-finder", "团队查找器", {"随机团本", "随机团队", "raid finder"}, groupFinder("GroupFinderFrame", "RaidFinderFrame")},
    {"premade-groups", "预创建队伍", {"集合石", "寻找队伍", "premade groups"}, groupFinder("GroupFinderFrame", "LFGListPVEStub")},
    {"pvp", "PvP", {"玩家对战", "战场", "竞技场", "荣誉"}, groupFinder("PVPUIFrame")},
    {"journal", "冒险指南", {"冒险手册", "地下城手册", "地下城指南", "团队手册", "journal"}, function() return A:OpenJournal() end},
    {"journeys", "旅程", {"冒险旅程", "赛季旅程", "journeys"}, journalTab("JourneysTab")},
    {"travelers-log", "旅行者日志", {"旅行者", "旅行日志", "商栈日志", "商栈任务", "travelers log"}, journalTab("MonthlyActivitiesTab")},
    {"suggested-content", "推荐玩法", {"推荐内容", "推荐活动", "suggested content"}, journalTab("suggestTab")},
    {"journal-dungeons", "地下城", {"地下城目录", "地下城指南目录", "dungeons"}, journalTab("dungeonsTab")},
    {"journal-raids", "团队副本", {"团本", "团队副本目录", "团本指南", "raids"}, journalTab("raidsTab")},
    {"tutorials", "教程", {"游戏教程", "新手教程", "tutorials"}, journalTab("TutorialsTab")},
    {"calendar", "日历", {"活动日历", "calendar"}, toggle("ToggleCalendar", "CalendarFrame")},
    {"macros", "宏命令", {"宏", "宏设置", "macros"}, function() return A:Call(ShowMacroFrame) and A:IsShown("MacroFrame") end},
    {"settings", "设置", {"选项", "系统设置", "声音", "画面", "快捷键", "settings", "options"}, function()
        return A:Call(C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel) and A:IsShown("SettingsPanel")
    end},
    {"game-menu", "游戏菜单", {"主菜单", "esc", "menu"}, function() return A:Call(GameMenuFrame_Show) and A:IsShown("GameMenuFrame") end},
}

-- Conservative cross-client menu set. Unsupported retail panels are never indexed.
local sharedMenus={character=true,reputation=true,spellbook=true,talents=true,map=true,friends=true,
    macros=true,settings=true,["game-menu"]=true}
local progressionMenus={currency=true,mounts=true,pets=true,achievements=true,calendar=true}
local function classicAction(id)
    if id=="spellbook" then return function()
        if A:IsShown("SpellBookFrame") and SpellBookFrame.bookType==(BOOKTYPE_SPELL or "spell") then return true end
        return A:Call(ToggleSpellBook,BOOKTYPE_SPELL or "spell") and A:IsShown("SpellBookFrame")
    end end
    if id=="talents" then return toggle("ToggleTalentFrame","PlayerTalentFrame") end
end

function M:Init()
    if self.handle then return true end
    local records, opens = {}, {}
    local product=I.Search.RuntimeIdentity:Current().product
    for index = 1, #menus do
        local menu = menus[index]
        if product=="retail" or sharedMenus[menu[1]] or ((product=="classic" or product=="titan") and progressionMenus[menu[1]]) then
        records[#records+1] = {id=menu[1], title=L[menu[2]], kindTitle=L["游戏菜单"], subtitle=L:Format("打开%s",L[menu[2]]), aliases=menu[3],
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\" .. menu[1] .. ".tga", payload={menuID=menu[1]}, actions={"open"}}
        opens[menu[1]] = product~="retail" and classicAction(menu[1]) or menu[4]
        end
    end
    local handle, err = _G.Lychee:RegisterProvider({
        id="builtin.game-menus", apiVersion=2,minApiRevision=2,i18n=L.resources, version="1.0.0", title=L["游戏菜单"], scope={products={"retail","classic","titan","anniversary"}}, entries=records,
        actions={open={title=L["打开界面"],run=function(entry)
            local open = opens[entry.payload.menuID]
            if not open then return {ok=false, code="UI_UNAVAILABLE"} end
            return A:Run(open,L)
        end}},
        onEnable=function() return function(reason) if reason == "unregister" then M.handle=nil end end end,
    })
    self.handle = handle
    return handle ~= nil, err
end
