local _,I=...
I.ProviderLocaleData = I.ProviderLocaleData or {}
local enUS = {
    ["打开所在设置页"]="Open settings page",
    ["打开面板"]="Open panel",
    ["解锁界面"]="Unlock layout",
    ["进入 Exwind 编辑模式"]="Enter Exwind Edit Mode",
    ["请先启用 Exwind Core"]="Enable Exwind Core first",
    ["请先脱离战斗"]="Leave combat first",
    ["Exwind 设置暂不可用"]="Exwind settings are unavailable",
    ["此设置页面已不可用"]="This settings page is no longer available",
    ["Exwind 设置目录超出限制"]="Exwind settings catalog exceeds the limit",
}
local zhCN={}
for key in pairs(enUS) do zhCN[key]=key end
I.ProviderLocaleData["lychee.exwind"]={enUS=enUS,zhCN=zhCN}
