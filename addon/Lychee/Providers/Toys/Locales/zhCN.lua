local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.toys"] = {
    ["玩具"] = "玩具",
    ["搜索并使用已收藏玩具"] = "搜索并使用已收藏玩具",
    ["使用玩具"] = "使用玩具",
    ["左键使用 · 放置类玩具需再点击地面"] = "左键使用 · 放置类玩具需再点击地面",
    ["玩具 #%d"] = "玩具 #%d",
}
