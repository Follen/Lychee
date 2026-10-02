local I = _G.LycheeInternal
I.ProviderData = I.ProviderData or {}

-- A fixed vocabulary per destination; no query-time generation or game-name cache.
local function teleportAliases(chinese, english)
    local aliases = {
        { text = "传送", locale = "zhCN" },
        { text = "teleport", locale = "enUS" },
    }
    for _, name in ipairs(chinese) do
        aliases[#aliases + 1] = { text = name, locale = "zhCN" }
        aliases[#aliases + 1] = { text = "传送" .. name, locale = "zhCN" }
        aliases[#aliases + 1] = { text = name .. "传送", locale = "zhCN" }
    end
    for _, name in ipairs(english) do
        aliases[#aliases + 1] = { text = name, locale = "enUS" }
        aliases[#aliases + 1] = { text = "teleport " .. name, locale = "enUS" }
    end
    return aliases
end

I.ProviderData.PlayerSpellAliases = {
    [31884] = {
        { text = "翅膀", locale = "zhCN" },
        { text = "wings", locale = "enUS" },
    },
    [393256] = teleportAliases({ "红玉", "红玉新生法池" }, { "ruby life pools", "ruby" }),
    [373274] = {
        { text = "麦卡贡", locale = "zhCN" },
        { text = "mechagon", locale = "enUS" },
    },
    [1286801] = teleportAliases({ "夺目", "夺目谷" }, { "the blinding vale", "blinding vale" }),
    [1286804] = teleportAliases({ "虚痕", "竞技场", "虚空之痕竞技场" }, { "voidscar arena", "voidscar" }),
    [1286807] = teleportAliases({ "纳洛", "纳洛拉克", "纳洛拉克的洞穴" }, { "den of nalorakk", "nalorakk" }),
    [1286809] = teleportAliases({ "密谋", "密谋小径", "谋杀", "谋杀小径" }, { "murder row" }),
    [1286812] = teleportAliases({ "毒牙", "毒牙祭坛" }, { "altar of fangs", "fangs" }),
    [1286828] = teleportAliases({ "神庙", "塞塔里斯", "塞塔里斯神庙" }, { "temple of sethraliss", "sethraliss" }),
    [1286831] = teleportAliases({ "诸王", "诸王之眠" }, { "king's rest" }),
}
