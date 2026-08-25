-- Offline contract smoke test. WoW UI behavior still requires an in-client pass.
_G = _G or {}
function GetLocale() return "zhCN" end
function InCombatLockdown() return false end
function CreateFrame()
    local f={}
    function f:RegisterEvent() end
    function f:SetScript() end
    function f:Hide() end
    function f:Show() end
    return f
end
UIParent = {}
local root = "package/Lychee/"
local files = {
    "Bootstrap.lua", "Core/ContextStore.lua", "Search/Normalizer.lua", "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/IntentRouter.lua", "Core/Scheduler.lua",
    "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "PublicAPI/SDK.lua",
    "Builtin/Data/PlayerSpellAliases.lua", "Builtin/Data/DungeonGuide.lua",
    "Builtin/PlayerSpells/AliasIndex.lua", "Builtin/PlayerSpells/Provider.lua", "Builtin/PlayerSpells/Command.lua",
    "Builtin/PlayerSpells/Intent.lua", "Builtin/PlayerSpells/Panel.lua", "Builtin/PlayerSpells/Init.lua",
    "Builtin/DungeonGuide/Provider.lua", "Builtin/DungeonGuide/Command.lua", "Builtin/DungeonGuide/Init.lua", "Builtin/Init.lua",
}
for i = 1, #files do dofile(root .. files[i]) end
assert(_G.Lychee and _G.Lychee:Supports(1, 1))
assert(_G.LycheeInternal.Builtin and _G.LycheeInternal.Builtin.Init)
_G.LycheeInternal.Builtin:Init()
_G.LycheeInternal.Registry:SetReady(true)
local q = _G.LycheeInternal.Search.Query
local _, results = q:Query("翅膀", {})
assert(#results > 0 and results[1].payload and results[1].payload.spellID == 642)
local _, ruby = q:Query("红玉", {})
assert(#ruby > 0 and ruby[1].payload.spellID == 395289)
local _, m1 = q:Query("M1", {})
assert(#m1 > 0)
assert(q.generation >= 3)
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function() return { spellID = 9001, name = "实时技能", iconID = 1, subName = "当前角色", isPassive = false, isOffSpec = false } end,
}
_G.LycheeInternal.Builtin.PlayerSpells.Provider:Refresh()
local _, live = q:Query("实时技能", {})
assert(#live > 0 and live[1].payload.spellID == 9001)
print("Lychee smoke PASS")
