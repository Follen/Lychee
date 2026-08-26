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
Enum = { SpellBookSpellBank = { Player = 0 } }
C_Spell = {
    GetSpellDescription = function(id)
        if id == 393256 then return "传送至红玉新生法池入口。" end
    end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
    GetSpellBookItemInfo = function(slot)
        if slot == 1 then return { spellID = 31884, name = "复仇之怒", iconID = 135875, isPassive = false, isOffSpec = false } end
        if slot == 2 then return { spellID = 393256, name = "利爪防御者之路", iconID = 4578416, isPassive = false, isOffSpec = false } end
    end,
}
local root = "package/Lychee/"
local files = {
    "Bootstrap.lua", "Core/ContextStore.lua", "Search/Normalizer.lua", "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua", "Core/IntentRouter.lua", "Core/Scheduler.lua",
    "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "PublicAPI/SDK.lua",
    "Builtin/Data/PlayerSpellAliases.lua",
    "Builtin/PlayerSpells/AliasIndex.lua", "Builtin/PlayerSpells/Provider.lua", "Builtin/PlayerSpells/Command.lua",
    "Builtin/PlayerSpells/Intent.lua", "Builtin/PlayerSpells/Panel.lua", "Builtin/PlayerSpells/Init.lua", "Builtin/Init.lua",
}
for i = 1, #files do dofile(root .. files[i]) end
assert(_G.Lychee and _G.Lychee:Supports(1, 1))
assert(_G.LycheeInternal.Builtin and _G.LycheeInternal.Builtin.Init)
_G.LycheeInternal.Builtin:Init()
_G.LycheeInternal.Registry:SetReady(true)
local q = _G.LycheeInternal.Search.Query
local _, results = q:Query("翅膀", {})
assert(#results > 0 and results[1].payload and results[1].payload.spellID == 31884)
local _, ruby = q:Query("红玉", {})
assert(#ruby > 0 and ruby[1].payload.spellID == 393256)
assert(q.generation >= 2)
dofile("lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua")
local fixture = _G.ThirdPartyFixture and _G.ThirdPartyFixture.GetExtension()
assert(fixture and fixture:GetState().lifecycle == "enabled")
local _, fixtureResults = q:Query("翅膀", {})
assert(#fixtureResults > 0)
local _, isolatedFixtureResults = q:Query("wings", {})
assert(#isolatedFixtureResults == 0)
local transition = _G.LycheeInternal.Router:Execute({ type = "builtin.player-spells.open", version = 1, payload = { spellID = 31884 } }, {})
assert(transition and transition.ok == true and transition.transition and transition.transition.panelID == "spell-detail")
local publicDraft, publicErr = _G.Lychee:RegisterExtension({ id = "test.public-bad", apiVersion = 1, minApiRevision = 1, title = "Bad", version = "1.0.0" })
assert(publicDraft and not publicErr)
local publicCommand, commandErr = publicDraft:RegisterCommand({ id = "broken", title = "Broken", presentation = "dynamic-list" })
assert(not publicCommand and commandErr and commandErr.code == "INVALID_SCHEMA")
publicDraft:Abort()
local oldSecret = issecretvalue
issecretvalue = function(value) return value == "SECRET" end
local secretBad, secretErr = _G.Lychee:RegisterExtension({ id = "test.secret", apiVersion = 1, minApiRevision = 1, title = "SECRET", version = "1.0.0" })
assert(not secretBad and secretErr and secretErr.code == "SECRET_VALUE")
issecretvalue = oldSecret
local scheduledGeneration = q:Schedule("翅膀", {}, nil, function(results, generation) assert(generation == q.generation and #results > 0) end, 0.05)
assert(q:Flush(scheduledGeneration))
C_Spell = {
    GetSpellDescription = function(id) if id == 9001 then return "传送至测试副本入口。" end end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function() return { spellID = 9001, name = "实时技能", iconID = 1, subName = "当前角色", isPassive = false, isOffSpec = false } end,
}
_G.LycheeInternal.Builtin.PlayerSpells.Provider:Refresh()
local _, live = q:Query("实时技能", {})
assert(#live > 0 and live[1].payload.spellID == 9001)
local _, descriptionMatch = q:Query("测试副本", {})
assert(#descriptionMatch > 0 and descriptionMatch[1].payload.spellID == 9001)
C_SpellBook.GetSpellBookItemInfo = function() error("transient") end
assert(_G.LycheeInternal.Builtin.PlayerSpells.Provider:Refresh() == false)
local _, retained = q:Query("实时技能", {})
assert(#retained > 0 and retained[1].payload.spellID == 9001)
-- Known alias spells are indexed even when the visible skill-line snapshot omits them.
C_SpellBook.GetSpellBookItemInfo = function() return nil end
IsPlayerSpell = function(id) return id == 393256 end
C_Spell = { GetSpellInfo = function(id) if id == 393256 then return { name = "利爪防御者之路", iconID = 4578416 } end end }
assert(_G.LycheeInternal.Builtin.PlayerSpells.Provider:Refresh())
local _, knownAlias = q:Query("红玉", {})
assert(#knownAlias > 0 and knownAlias[1].payload.spellID == 393256)
local bad = _G.LycheeInternal.Registry:Begin({ id = "test.bad", apiVersion = 1, minApiRevision = 1, title = "Bad" })
assert(bad and not bad:RegisterCommand({ id = "broken", title = "Broken" }))
local panel = _G.LycheeInternal.Registry:Get("builtin.player-spells")
assert(panel and panel:GetState().lifecycle == "enabled")
assert(panel:Unregister())
assert(_G.LycheeInternal.Router:Execute({ type = "builtin.player-spells.open", version = 1, payload = { spellID = 9001 } }, {}) == nil)
assert(fixture:Unregister())
assert(_G.LycheeInternal.Router:Execute({ type = "third-party-fixture.open-detail", version = 1, payload = { itemID = 12345 } }, {}) == nil)
print("Lychee smoke PASS")
