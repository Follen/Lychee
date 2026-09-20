local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.toys"] = {
    ["玩具"] = "Toys",
    ["搜索并使用已收藏玩具"] = "Find and use collected toys",
    ["使用玩具"] = "Use toy",
    ["左键使用 · 放置类玩具需再点击地面"] = "Left-click to use; placement toys need a ground click",
    ["玩具 #%d"] = "Toy #%d",
}
