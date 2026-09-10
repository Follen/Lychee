function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
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
    "Bootstrap.lua", "Core/ProviderLocales.lua", "Locales/Builtin.enUS.lua", "Builtin/CatalogProvider.lua", "Core/ContextStore.lua", "Search/RuntimeIdentity.lua", "Search/Normalizer.lua", "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua", "Core/IntentRouter.lua", "Core/Scheduler.lua",
    "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "Core/ResultActionExecutor.lua", "Core/ProviderRuntime.lua", "PublicAPI/SDK.lua",
    "Builtin/Data/PlayerSpellAliases.lua", "Builtin/PlayerSpells/Provider.lua",
    "Builtin/PlayerSpells/Init.lua", "Builtin/Init.lua",
}
for i = 1, #files do dofile(root .. files[i]) end
assert(_G.Lychee and _G.Lychee:Supports(2, 1))
assert(_G.LycheeInternal.Builtin and _G.LycheeInternal.Builtin.Init)
_G.LycheeInternal.Builtin:Init()
_G.LycheeInternal.Registry:SetReady(true)
local q = _G.LycheeInternal.Search.Query
local queryToken, results = q:Query("翅膀", {})
assert(queryToken ~= nil)
assert(#results > 0 and results[1].payload and results[1].payload.spellID == 31884)
local _, ruby = q:Query("红玉", {})
assert(#ruby > 0 and ruby[1].payload.spellID == 393256)
dofile("lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua")
local fixture = _G.ThirdPartyFixture and _G.ThirdPartyFixture.GetProvider()
assert(fixture and fixture:GetState().lifecycle == "enabled")
local _, fixtureResults = q:Query("第三方示例条目", {})
assert(#fixtureResults == 1 and fixtureResults[1].sourceID == "third-party-fixture:records")
local fixtureItem = fixtureResults[1]
local fixtureAction = fixtureItem.interaction and fixtureItem.interaction.actions[1]
assert(fixtureAction and fixtureAction.kind == "provider")
local openedPanel
local fixturePalette = {
    visible = true,
    session = 1,
    generation = queryToken,
    viewHost = {},
    OpenView = function(_, factory, owner, panelState)
        openedPanel = { factory = factory, owner = owner, state = panelState }
        return true
    end,
    RejectRow = function(_, _, reason) return false, reason end,
}
assert(_G.LycheeInternal.ResultActionExecutor:BindPalette(fixturePalette))
local actionResult, actionErr = _G.LycheeInternal.ResultActionExecutor:Execute({
    item = fixtureItem,
    extensionID = "third-party-fixture",
    session = fixturePalette.session,
    generation = fixturePalette.generation,
}, fixtureAction.id)
assert(actionResult and not actionErr and actionResult.ok == true)
assert(actionResult.transition)
assert(actionResult.transition.panelID == "detail")
assert(openedPanel and openedPanel.owner.extensionID == "third-party-fixture")
assert(openedPanel.owner.panelID == "detail" and openedPanel.state.itemID == 12345)
assert(openedPanel.factory == _G.LycheeInternal.Router:ResolvePanel("third-party-fixture", "detail"))
local _, isolatedFixtureResults = q:Query("wings", {})
assert(#isolatedFixtureResults == 1 and isolatedFixtureResults[1].providerID == "builtin.player-spells", "English spell alias fallback must not leak into the third-party fixture")
assert(_G.ThirdPartyFixture.SetEnabled(false))
assert(fixture:GetState().lifecycle == "disabled")
local _, disabledFixtureResults = q:Query("第三方示例条目", {})
assert(#disabledFixtureResults == 0)
assert(_G.ThirdPartyFixture.SetEnabled(true))
assert(fixture:GetState().lifecycle == "enabled")
local _, reenabledFixtureResults = q:Query("第三方示例条目", {})
assert(#reenabledFixtureResults == 1 and reenabledFixtureResults[1].sourceID == "third-party-fixture:records")
assert(results[1].interaction and results[1].interaction.actions[1].kind == "secure-spell")
assert(results[1].interaction.drag and results[1].interaction.drag.spellID == 31884)
local publicDraft, publicErr = _G.LycheeInternal.Registry:Begin({ id = "test.public-bad", apiVersion = 2, minApiRevision = 1, title = "Bad", version = "1.0.0" })
assert(publicDraft and not publicErr)
local publicCommand, commandErr = publicDraft:RegisterCommand({ id = "broken", title = "Broken", presentation = "dynamic-list" })
assert(not publicCommand and commandErr and commandErr.code == "INVALID_SCHEMA")
publicDraft:Abort()
local oldSecret = issecretvalue
issecretvalue = function(value) return value == "SECRET" end
local secretBad, secretErr = _G.LycheeInternal.Registry:Begin({ id = "test.secret", apiVersion = 2, minApiRevision = 1, title = "SECRET", version = "1.0.0" })
assert(not secretBad and secretErr and secretErr.code == "SECRET_VALUE")
issecretvalue = oldSecret
local callbackToken
local scheduledToken = q:Schedule("翅膀", {}, nil, function(scheduledResults, token)
    callbackToken = token
    assert(#scheduledResults > 0)
end, 0.05)
assert(scheduledToken ~= nil and q:Flush(scheduledToken))
assert(callbackToken == scheduledToken)
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
local bad = _G.LycheeInternal.Registry:Begin({ id = "test.bad", apiVersion = 2, minApiRevision = 1, title = "Bad" })
assert(bad and not bad:RegisterCommand({ id = "broken", title = "Broken" }))
local panel = _G.LycheeInternal.Registry:Get("builtin.player-spells")
assert(panel and panel:GetState().lifecycle == "enabled")
local playerSpellsEntry = _G.LycheeInternal.Registry.entries["builtin.player-spells"]
assert(playerSpellsEntry and #playerSpellsEntry.sources == 1)
assert(#playerSpellsEntry.commands == 0 and #playerSpellsEntry.providers == 0)
assert(#playerSpellsEntry.handlers == 0 and #playerSpellsEntry.panels == 0)
local playerSpells = _G.LycheeInternal.Builtin.PlayerSpells
local committedSourceHandle = playerSpells.Provider.providerHandle
assert(committedSourceHandle and playerSpells.Provider._active == true and playerSpells.Provider._eventFrame)
assert(panel:SetEnabled(false))
assert(playerSpells.Provider._active == false and playerSpells.Provider._eventFrame == nil)
assert(playerSpells.Provider.providerHandle == committedSourceHandle, "disable retains the committed source handle")
assert(panel:SetEnabled(true))
assert(playerSpells.Provider._active == true and playerSpells.Provider._eventFrame)
assert(playerSpells.Provider.providerHandle == committedSourceHandle, "enable reuses the committed source handle")
assert(panel:Unregister())
assert(playerSpells.Provider.providerHandle == nil and playerSpells.Provider._eventFrame == nil)
assert(playerSpells._initialized == nil and playerSpells.handle == nil)
assert(_G.ThirdPartyFixture.Unregister())
assert(_G.ThirdPartyFixture.Unregister())
assert(fixture:GetState() == nil)
assert(_G.LycheeInternal.Router:Execute({ type = "third-party-fixture.open-detail", version = 1, payload = { itemID = 12345 } }, {}) == nil)
print("Lychee smoke PASS")
