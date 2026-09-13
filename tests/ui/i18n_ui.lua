-- Actual Bootstrap locale resolver and shipped UI dictionaries; no game renderer claims.
local originalLocale, originalCreateFrame = GetLocale, CreateFrame
CreateFrame = nil
for _, locale in ipairs({"zhCN", "zhTW", "enUS", "enGB", "deDE"}) do
    GetLocale = function() return locale end
    LycheeInternal = nil
    dofile("addon/Lychee/Bootstrap.lua"); dofile("addon/Lychee/Core/CharacterStore.lua")
    dofile("addon/Lychee/Locales/UI.enUS.lua")
    local L = LycheeInternal.Locale
    local chinese = locale == "zhCN" or locale == "zhTW"
    assert(L:IsChinese() == chinese)
    assert(L["操作菜单"] == (chinese and "操作菜单" or "Actions"))
    dofile("addon/Lychee/Core/ProviderLocales.lua")
    local namespace={ProviderLocaleData={}}
    assert(loadfile("addon/Lychee_Inspector/Locales.lua"))("Lychee_Inspector",namespace)
    local inspector=assert(LycheeInternal.ProviderLocales:Compile(namespace.ProviderLocaleData["lychee.addon-inspector"]))
    assert(inspector:Text("复制信息") == (chinese and "复制信息" or "Copy info"))
    assert(inspector:Text("上一级") == (chinese and "上一级" or "Parent"))
    assert(L["尚未翻译的键"] == "尚未翻译的键")
    assert(L:Resolve({zhCN="中文",enUS="English"}) == (chinese and "中文" or "English"))
    assert(L:Resolve({zhTW="繁体",enGB="British"}, "fallback") == (locale=="zhTW" and "繁体" or locale=="enGB" and "British" or "fallback"))
    assert(L:Resolve({{text="中文",locale="zhCN"},{text="English",locale="enUS"}}) == (chinese and "中文" or "English"))
    assert(L:Resolve({"Default"}) == "Default")
    assert(L:Resolve(nil,"Fallback") == "Fallback")
    assert(L.name == (chinese and "|cffd53c49荔枝|r启动器" or "|cffd53c49Lychee|r Launcher"))
    L:Add({["结果 %d"]="Results: %d"})
    assert(L:Format("结果 %d", 3) == (chinese and "结果 3" or "Results: 3"))
    if chinese then assert(rawget(L,"复制信息")==nil) end
end
GetLocale, CreateFrame = originalLocale, originalCreateFrame
print("UI locales PASS: zhCN, zhTW fallback, enUS, enGB, other-English fallback; maps, arrays, formats and brand")
