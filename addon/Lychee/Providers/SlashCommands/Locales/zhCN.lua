local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("zhCN") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.slash-commands"] = {
    ["斜杠命令"] = "斜杠命令",
    ["搜索并运行已注册的斜杠命令"] = "搜索并运行已注册的斜杠命令",
    ["点击运行命令"] = "点击运行命令",
    ["运行命令"] = "运行命令",
    ["命令数量超出限制"] = "命令数量超出限制",
    ["命令暂不可用，请重试"] = "命令暂不可用，请重试",
    ["请先脱离战斗"] = "请先脱离战斗",
    ["命令已注销，请重新搜索"] = "命令已注销，请重新搜索",
    ["命令执行失败，请检查插件错误后重试"] = "命令执行失败，请检查插件错误后重试",
}
