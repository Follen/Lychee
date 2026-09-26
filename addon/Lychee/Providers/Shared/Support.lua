local I = _G.LycheeInternal
local definitions = I.ProviderModules.Definitions
local byID = {}
for _, definition in ipairs(definitions) do byID[definition.id] = definition end
local S = {}
I.ProviderModules.Support = S
local dependencies = {
    ["builtin.ellesmere"]={addon="EllesmereUI",global="EllesmereUI"},
    ["builtin.exwind"]={addon="ExwindCore",global="ExwindTools"},
}
local detected = {} -- Two session-local booleans; never persist automatic defaults.

function S:DefaultSearchEnabled(id)
    local definition = byID[id]
    if definition and not I.Search.RuntimeIdentity:MatchesScope(definition.scope) then return false end
    local dependency = dependencies[id]
    if not dependency then return true end
    if detected[id] ~= nil then return detected[id] end
    if not C_AddOns or type(C_AddOns.GetAddOnInfo) ~= "function"
        or type(C_AddOns.GetAddOnEnableState) ~= "function" then
        return type(_G[dependency.global]) == "table"
    end
    local character = type(UnitGUID) == "function" and UnitGUID("player")
    if not character or character == "" then return false end
    local ok, name = pcall(C_AddOns.GetAddOnInfo, dependency.addon)
    if not ok then return false end
    if not name then detected[id]=false;return false end
    local enabled, state = pcall(C_AddOns.GetAddOnEnableState, dependency.addon, character)
    if not enabled or type(state) ~= "number" then return false end
    detected[id] = state > 0
    return detected[id]
end

function S:Scope(id)
    local definition = assert(byID[id], "Unknown built-in Provider: " .. tostring(id))
    local client=I.Search.RuntimeIdentity:Current()
    local selected=I.ClientSupport:SelectRange(definition.ranges,client)
    if selected then return I.ClientSupport:Scope(selected) end
    -- Keep a nonmatching scope for unsupported clients, never a nil scope
    -- (which public registration would interpret as the retail default).
    return {products=definition.scope.products,minInterface=9999999,maxInterface=9999999}
end

function S:Known(id)
    return byID[id] ~= nil
end

function S:Available(definition, product)
    local supported = false
    for _, candidate in ipairs(definition.scope.products) do
        if candidate == product then supported = true; break end
    end
    if not supported then return false end
    local current=I.Search.RuntimeIdentity:Current()
    if current.product == product and not I.ClientSupport:SelectRange(definition.ranges,current) then return false,"UNSUPPORTED_CLIENT" end
    -- Evaluated only during startup, before business frames/events/tasks exist.
    for _, symbol in ipairs(definition.requires) do
        local value = _G
        for part in symbol:gmatch("[^.]+") do
            value = type(value) == "table" and value[part] or nil
        end
        if type(value) ~= "function" then return false,"REQUIRED_API_UNAVAILABLE",symbol end
    end
    return true
end

-- Trusted project assembly policy; public Provider descriptors cannot set these flags.
I.ProjectProviders=S
function S:IsRequired(id) return id=="lychee.settings" end
local presentation
function S:Presentation(id)
    if not presentation then
        local L=I.Locale
        local moduleOrder = { ["builtin.player-spells"]=1, ["builtin.mounts"]=2, ["builtin.bosses"]=3,
            ["builtin.game-menus"]=4,["builtin.crests"]=5,["builtin.great-vault"]=6,
            ["builtin.bags"]=7,["builtin.talent-loadouts"]=8,["builtin.equipment-sets"]=9,
            ["builtin.blizzard-settings"]=10,["builtin.keystones"]=11,["builtin.achievements"]=12,["builtin.addon-inspector"]=13 }
        local providerDescriptions = {
            ["builtin.player-spells"]=L["搜索并施放已学技能"],
            ["builtin.mounts"]=L["搜索并召唤坐骑"],
            ["builtin.bosses"]=L["搜索团本首领和技能并查看指南"],
            ["builtin.game-menus"]=L["快速打开游戏面板"],
            ["builtin.crests"]=L["查看当前角色的纹章数量"],
            ["builtin.great-vault"]=L["查看宏伟宝库进度与奖励"],
            ["builtin.bags"]=L["搜索物品并定位背包"],
            ["builtin.talent-loadouts"]=L["搜索并切换天赋方案"],
            ["builtin.equipment-sets"]=L["搜索并切换装备方案"],
            ["builtin.blizzard-settings"]=L["定位设置、重载界面与冷却管理器"],
            ["builtin.keystones"]=L["队伍钥匙、分数与副本传送"],
            ["builtin.achievements"]=L["搜索成就、查看进度与分享链接"],
            ["builtin.addon-inspector"]=L["指向界面，识别来源插件"],
            ["builtin.ellesmere"]=L["用 EUI：搜索设置页面或解锁界面"],
            ["builtin.exwind"]=L["用 EX：搜索设置页面或解锁界面"],
        }
        local iconRoot = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
        local providerIcons = {
            ["builtin.player-spells"] = iconRoot .. "spellbook.tga",
            ["builtin.mounts"] = iconRoot .. "mounts.tga",
            ["builtin.bosses"] = iconRoot .. "skull.tga",
            ["builtin.game-menus"] = iconRoot .. "game-menu.tga",
            ["builtin.crests"] = iconRoot .. "currency.tga",
            ["builtin.great-vault"] = iconRoot .. "great-vault.tga",
            ["builtin.bags"] = iconRoot .. "toys.tga",
            ["builtin.talent-loadouts"] = iconRoot .. "talents.tga",
            ["builtin.equipment-sets"] = iconRoot .. "character.tga",
            ["builtin.blizzard-settings"] = iconRoot .. "settings.tga",
            ["builtin.keystones"] = iconRoot .. "keystone.tga",
            ["builtin.achievements"] = iconRoot .. "achievements.tga",
            ["builtin.addon-inspector"] = iconRoot .. "addon-inspector.tga",
        }
        moduleOrder["builtin.slash-commands"]=17
        moduleOrder["builtin.toys"]=18
        moduleOrder["builtin.ldt"]=14
        moduleOrder["builtin.exwind"]=15
        moduleOrder["builtin.ellesmere"]=16
        providerDescriptions["builtin.ldt"]=L["搜索地下城怪物和技能并查看资料"]
        providerIcons["builtin.ldt"]=iconRoot.."skull.tga"
        presentation={order=moduleOrder,descriptions=providerDescriptions,icons=providerIcons}
    end
    return presentation.order[id],presentation.descriptions[id],presentation.icons[id]
end

local legacyPrefixes={
    ["技能"]="builtin.player-spells",spell="builtin.player-spells",spells="builtin.player-spells",
    ["坐骑"]="builtin.mounts",mounts="builtin.mounts",
    ["背包"]="builtin.bags",["物品"]="builtin.bags",bags="builtin.bags",
    ["天赋"]="builtin.talent-loadouts",["天赋方案"]="builtin.talent-loadouts",talents="builtin.talent-loadouts",
    ["装备"]="builtin.equipment-sets",["装备方案"]="builtin.equipment-sets",gear="builtin.equipment-sets",
    ["设置"]="builtin.blizzard-settings",["暴雪设置"]="builtin.blizzard-settings",settings="builtin.blizzard-settings",
    ["钥匙"]="builtin.keystones",key="builtin.keystones",keys="builtin.keystones",
    ["成就"]="builtin.achievements",achievement="builtin.achievements",achievements="builtin.achievements",
    ["团本首领"]="builtin.bosses",["首领"]="builtin.bosses",bosses="builtin.bosses",["菜单"]="builtin.game-menus",
    ["玩家技能"]="builtin.player-spells",["背包物品"]="builtin.bags",["队伍钥匙"]="builtin.keystones",
    ["游戏菜单"]="builtin.game-menus",["纹章"]="builtin.crests",["宏伟宝库"]="builtin.great-vault",["宝库"]="builtin.great-vault",
}

local searchPrefixes={}
for prefix,id in pairs(legacyPrefixes) do
    local list=searchPrefixes[id] or {};searchPrefixes[id]=list;list[#list+1]=prefix
end
for _,list in pairs(searchPrefixes) do table.sort(list) end
function S:SearchPrefixes(id) return searchPrefixes[id] end
function S:PrefixOwner(prefix) return legacyPrefixes[prefix] end

function S:InitializeSystemSources()
    if self.settingsProvider or not Lychee or not Lychee.RegisterProvider then return end
    local L=I.Locale
    self.settingsProvider=Lychee:RegisterProvider({id="lychee.settings",apiVersion="1.0.0",version="1.0.0",title=L["荔枝设置"],
        scope={products={"retail","classic","titan","anniversary","forever"}},
        entries={{id="settings",title=L["荔枝设置"],kindTitle=L["设置"],aliases={"设置","荔枝设置","lychee settings"},rememberable=false,
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga",actions={"open"}}},
        actions={open={title=L["打开荔枝设置"],run=function()
            if not I.Host or not I.Host.OpenSettings then return nil,{code="ACTION_UNAVAILABLE"} end
            local ok,err=I.Host.OpenSettings();if not ok then return nil,err end;return {ok=true,close=false}
        end}}})
end
