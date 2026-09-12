local I = _G.LycheeInternal
I.BuiltinLocaleData = I.BuiltinLocaleData or {}
do
    local enUS = {
        ["召唤"] = "Summon",
        ["坐骑"] = "Mounts",
        ["点击召唤 · 可拖到动作条"] = "Click to summon · Drag to an action bar",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.BuiltinLocaleData["builtin.mounts"] = {enUS=enUS,zhCN=zhCN}
end
