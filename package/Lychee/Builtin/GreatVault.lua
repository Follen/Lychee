local I = _G.LycheeInternal
local A = I.Builtin.InterfaceActions
local M = {}
I.Builtin.GreatVault = M

local function openVault()
    return A:ToggleOpen(WeeklyRewards_ShowUI, "WeeklyRewardsFrame")
end

function M:Init()
    if self.handle then return true end
    local handle, err = _G.Lychee:RegisterProvider({
        id="builtin.great-vault", apiVersion=2, version="1.0.0", title="宏伟宝库", scope={product="retail"},
        entries={{id="great-vault", title="宏伟宝库", kindTitle="每周奖励", subtitle="查看宏伟宝库进度与奖励",
            aliases={"低保", "宝库", "每周奖励", "大秘境低保", "great vault", "weekly rewards"},
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\great-vault.tga", actions={"open"}}},
        actions={open={title="打开宏伟宝库", run=function() return A:Run(openVault) end}},
        onEnable=function() return function(reason) if reason == "unregister" then M.handle=nil end end end,
    })
    self.handle=handle
    return handle ~= nil, err
end
