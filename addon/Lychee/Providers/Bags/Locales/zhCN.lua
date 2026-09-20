local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.bags"] = {
    ["使用物品"] = "使用物品",
    ["共 %d 个 · 左键使用 · 右键更多"] = "共 %d 个 · 左键使用 · 右键更多",
    ["定位背包"] = "定位背包",
    ["已打开背包；目标格位当前不可见，请展开对应分类"] = "已打开背包；目标格位当前不可见，请展开对应分类",
    ["物品已不在背包中"] = "物品已不在背包中",
    ["背包"] = "背包",
    ["背包/格位："] = "背包/格位：",
    ["背包物品"] = "背包物品",
}
