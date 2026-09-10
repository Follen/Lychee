local I = _G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
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
