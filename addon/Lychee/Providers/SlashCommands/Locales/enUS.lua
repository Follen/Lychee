local I = _G.LycheeInternal
if not I.ProviderLocales:IsModuleLocale("enUS") then return end
I.ProviderLocaleData = I.ProviderLocaleData or {}
I.ProviderLocaleData["builtin.slash-commands"] = {
    ["斜杠命令"] = "Slash commands",
    ["搜索并运行已注册的斜杠命令"] = "Find and run registered slash commands",
    ["点击运行命令"] = "Click to run command",
    ["运行命令"] = "Run command",
    ["命令数量超出限制"] = "Too many registered commands",
    ["命令暂不可用，请重试"] = "Commands unavailable; try again",
    ["请先脱离战斗"] = "Leave combat first",
    ["命令已注销，请重新搜索"] = "Command removed; search again",
    ["命令执行失败，请检查插件错误后重试"] = "Command failed; check addon errors and retry",
}
