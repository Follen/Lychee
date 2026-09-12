-- Unified SearchSource/SearchRecord contract smoke.
_G = _G or {}
_G.__locale = "zhCN"
function GetLocale() return _G.__locale end
function GetBuildInfo() return "12.1.0", "12345", "today", 120100 end
function InCombatLockdown() return false end
function CreateFrame()
    local f = {}
    function f:RegisterEvent() end
    function f:SetScript() end
    function f:Hide() end
    function f:Show() end
    return f
end
UIParent = {}

local root = "package/Lychee/"
local files = {
    "Bootstrap.lua", "Core/CharacterStore.lua", "Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua", "Core/ContextStore.lua", "Search/RuntimeIdentity.lua", "Search/Normalizer.lua",
    "Search/Storage.lua", "Search/StaticIndex.lua", "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua",
    "Core/IntentRouter.lua", "Core/Scheduler.lua", "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua",
    "Core/ProviderRuntime.lua", "PublicAPI/SDK.lua",
}
for i = 1, #files do dofile(root .. files[i]) end

local I = _G.LycheeInternal
local index = I.Search.StaticIndex:New()
local sourceID = "search-platform-test"
assert(index:RegisterSource({ id = sourceID, priority = 50, _extensionID = "test.search" }))
assert(index:CommitSnapshot(sourceID, {
    {
        id = "spell:393256", kind = "spell",
        kindTitle = { default = "Spell", zhCN = "技能" },
        category = { id = "spells", title = { default = "Spell", zhCN = "技能" } },
        title = "利爪防御者之路",
        aliases = { { text = "红玉", locale = "zhCN" }, { text = "ruby life pools", locale = "enUS" } },
        keywords = { { text = "传送", locale = "zhCN" } },
        description = { { text = "传送至红玉新生法池入口。", locale = "zhCN" } },
        scope = { product = "retail", minInterface = 120000, maxInterface = 120999 },
    },
    {
        id = "spell:old", kind = "spell", title = "过期技能",
        aliases = { { text = "旧版本", locale = "zhCN", scope = { minBuild = 99999 } } },
    },
    {
        id = "spell:shared-filter", kind = "spell",
        category = { id = "spells", title = { zhCN = "技能" } }, title = "共同过滤",
    },
}, 1))
assert(index:RegisterSource({ id = "filter-other", priority = 40, _extensionID = "test.other" }))
assert(index:CommitSnapshot("filter-other", {
    { id = "achievement:shared-filter", kind = "achievement",
        category = { id = "achievements", title = { zhCN = "成就" } }, title = "共同过滤" },
}, 1))

local hits = index:Search("红玉", 10)
assert(#hits == 1 and hits[1].item.id == "spell:393256")
assert(hits[1].confidence == 0.98 and hits[1].evidence.matchedField == "alias")
assert(I.Search.Normalizer:MatchText("红玉", "红玉", "title").confidence > I.Search.Normalizer:MatchText("红玉", "红玉", "alias").confidence)
assert(I.Search.Normalizer:MatchText("红玉", "红玉新生", "alias").confidence > I.Search.Normalizer:MatchText("红玉", "红玉", "keyword").confidence)
assert(I.Search.Normalizer:MatchText("红玉", "红玉", "keyword").confidence > I.Search.Normalizer:MatchText("红玉", "红玉", "description").confidence)
local descriptionHits = index:Search("入口", 10)
assert(#descriptionHits == 1 and descriptionHits[1].evidence.matchedField == "description")
assert(#index:Search("旧版本", 10) == 0)
local categoryHits = index:Search("技能 红玉", 10)
assert(#categoryHits == 1 and categoryHits[1].evidence.matchType == "token")
local categoryBrowse = index:Search("", 10, { categoryID = "spells" })
assert(#categoryBrowse == 2, "empty query category browse uses the category bucket")
for hitIndex = 1, #categoryBrowse do assert(categoryBrowse[hitIndex].record.category.id == "spells") end
local sourceBrowse = index:Search("", 10, { sourceID = "filter-other" })
assert(#sourceBrowse == 1 and sourceBrowse[1].sourceID == "filter-other", "empty query source browse uses source entry keys")
local firstSourceShared = index:Search("共同过滤", 10, { sourceID = sourceID })
local otherSourceShared = index:Search("共同过滤", 10, { sourceID = "filter-other" })
assert(#firstSourceShared == 1 and firstSourceShared[1].sourceID == sourceID, "first source filter")
assert(#otherSourceShared == 1 and otherSourceShared[1].sourceID == "filter-other", "filter key isolates candidate reuse")
index:Search("红玉", 10)
index:Search("红玉新", 10)
assert(index:GetDiagnostics().reusedPrevious == true)

assert(index:RegisterSource({ id = "mutation-test", revision = 1 }))
assert(index:Upsert("mutation-test", {
    id = "spell:393256", kind = "spell", category = { id = "spells", title = { zhCN = "技能" } },
    title = "利爪防御者之路（更新）", aliases = { { text = "红玉新", locale = "zhCN" } },
}, 2))
local mutationHits = index:Search("红玉新", 10)
local mutationFound = false
for mutationIndex = 1, #mutationHits do if mutationHits[mutationIndex].sourceID == "mutation-test" then mutationFound = true end end
assert(mutationFound)
assert(index:Remove("mutation-test", "spell:393256", 3))
local afterRemoveHits = index:Search("红玉新", 10)
for removeIndex = 1, #afterRemoveHits do assert(afterRemoveHits[removeIndex].sourceID ~= "mutation-test") end
assert(index:Invalidate("mutation-test", 4))
assert(index:GetSignature():find("search%-schema%-2", 1, false))

assert(index:RegisterSource({ id = "generation-test", revision = 2 }))
assert(index:Upsert("generation-test", { id = "one", title = "代际记录" }, 2))
local generation = index.sources["generation-test"]._generation
assert(index:Upsert("generation-test", { id = "old", title = "旧代记录" }, 2, generation - 1) == false)

_G.__locale = "enUS"
I.Search.RuntimeIdentity:Refresh()
I.Search.Normalizer.locale = "enUS"
index:Rebuild()
assert(#index:Search("红玉", 10) == 0)
local english = index:Search("ruby life pools", 10)
assert(#english == 1 and english[1].item.id == "spell:393256")

-- Public Extension registration publishes a source into the Host index.
_G.__locale = "zhCN"
I.Search.RuntimeIdentity:Refresh()
I.Search.Normalizer.locale = "zhCN"
I.Search.StaticIndex:Clear()
I.Registry:SetReady(true)
local draft = I.Registry:Begin({ id = "test.search", apiVersion = 2, minApiRevision = 1, title = "Search fixture" })
assert(draft)
assert(draft:RegisterSearchSource({
    id = "creatures", version = 1, revision = 1, priority = 50, scope = {}, title = { default = "Creature source", zhCN = "生物来源" },
    records = {
        { id = "creature:1", kind = "creature", kindTitle = { default = "Creature", zhCN = "生物" }, category = { id = "dungeons", title = { default = "Dungeon", zhCN = "副本" }, color = { 0.8, 0.4, 0.7, 1 } }, title = "红玉小怪", aliases = { { text = "红玉小怪", locale = "zhCN" } } },
    },
}))
local handle = draft:Commit()
assert(handle and handle:GetState().effectiveEnabled == true)
local sourceHandle = assert(handle:GetSearchSource("creatures"))
local sourceState = sourceHandle:GetState()
local snapshotGeneration = sourceHandle:BeginSnapshot()
assert(sourceHandle:Upsert({ id = "creature:2", kind = "creature", category = { id = "dungeons", title = "副本" }, title = "增量小怪" }, snapshotGeneration))
assert(sourceHandle:CommitSnapshot(nil, nil, snapshotGeneration))
assert(sourceHandle:GetState().revision > sourceState.revision)
assert(#I.Search.StaticIndex:Search("增量小怪", 10) == 1)
local generation, results = I.Search.Query:Query("红玉小怪", {})
assert(generation and #results > 0 and results[1].searchRecord and results[1].category == "副本")

local typedGeneration, typedResults = I.Search.Query:Query("红玉小怪", {})
assert(typedGeneration and typedResults[1].kindTitle == "生物", "SearchRecord kindTitle is projected without a Host kind dictionary")
assert(typedResults[1].sourceTitle == "生物来源", "result source title comes from the Source declaration")
assert(typedResults[1].categoryColor and typedResults[1].categoryColor[1] == 0.8, "category color comes from the SearchRecord")

-- Source-local updates preserve unrelated source entries and snapshots restore real records.
local sourceB = "test.search:other"
assert(I.Search.StaticIndex:RegisterSource({ id = sourceB, revision = 1, _extensionID = "test.search" }))
assert(I.Search.StaticIndex:CommitSnapshot(sourceB, { { id = "other:1", kind = "creature", title = "保留记录" } }, 1))
local unrelatedKey = sourceB .. ":other:1"
local unrelatedEntry = I.Search.StaticIndex.entries[unrelatedKey]
assert(sourceHandle:Upsert({ id = "creature:3", kind = "creature", category = { id = "dungeons", title = "副本" }, title = "局部更新" }))
assert(I.Search.StaticIndex.entries[unrelatedKey] == unrelatedEntry)
local exported = I.Search.StaticIndex:ExportSnapshot()
local restored = I.Search.StaticIndex:New()
for sourceIndex = 1, #exported.sources do assert(restored:RegisterSource(exported.sources[sourceIndex])) end
assert(restored:RestoreSnapshot(exported))
assert(#restored:Search("保留记录", 10) == 1)

-- Fuzzy work obeys a millisecond deadline and records a stable diagnostic code.
local previousProfiler = debugprofilestop
local clock = 0
debugprofilestop = function() clock = clock + 10; return clock end
I.Search.StaticIndex:Search("保留记绿", 10)
debugprofilestop = previousProfiler
assert((I.Search.StaticIndex:GetDiagnostics().FUZZY_TIME_BUDGET or 0) > 0)

-- Public immediate mutations are staged and committed once per frame when the client timer exists.
local scheduled = {}
C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }
local beforeBatch = sourceHandle:GetState()
assert(sourceHandle:Upsert({ id = "creature:batched-one", kind = "creature", category = { id = "dungeons", title = "副本" }, title = "批量一" }))
assert(sourceHandle:Upsert({ id = "creature:batched-two", kind = "creature", category = { id = "dungeons", title = "副本" }, title = "批量二" }))
assert(#scheduled == 1 and sourceHandle:GetState().revision == beforeBatch.revision, "same-frame mutations are coalesced")
scheduled[1]()
assert(sourceHandle:GetState().revision == beforeBatch.revision + 1, "same-frame batch bumps once")
C_Timer = { After = function(_, callback) callback() end }
local synchronousBefore = sourceHandle:GetState().revision
assert(sourceHandle:Upsert({ id = "creature:sync-timer", kind = "creature", category = { id = "dungeons", title = "副本" }, title = "同步计时器" }))
assert(sourceHandle:GetState().revision == synchronousBefore + 1, "synchronous timer commits staged mutation")
C_Timer = nil

local invalidCategoryDraft = I.Registry:Begin({ id = "test.category", apiVersion = 2, minApiRevision = 1, title = "Category" })
assert(invalidCategoryDraft)
assert(invalidCategoryDraft:RegisterSearchSource({ id = "records", version = 1, revision = 1, priority = 1, scope = {}, records = { { id = "one", kind = "other", category = { id = "unprefixed" }, title = "Bad" } } }))
local invalidCategoryHandle, invalidCategoryErr = invalidCategoryDraft:Commit()
assert(not invalidCategoryHandle and invalidCategoryErr and invalidCategoryErr.code == "INVALID_SCHEMA")
assert(handle:Unregister())
local _, removed = I.Search.Query:Query("红玉小怪", {})
assert(#removed == 0)

-- Shared postings survive one owner changing/removing a repeated alias; then
-- the last owner removal clears every index, including singleton categories.
local compact=I.Search.StaticIndex:New()
assert(compact:RegisterSource({id="compact",revision=1}))
local first={id="one",title="专属白马",aliases={"共享坐骑", "共享坐骑"},category="坐骑类"}
local second={id="two",title="专属黑马",aliases={"共享坐骑"},category="坐骑类"}
assert(compact:CommitSnapshot("compact",{first}))
assert(#compact:Search("",10,{categoryID="坐骑类"})==1)
assert(compact:ApplyDelta("compact",{second},{}))
assert(#compact:Search("共享坐骑",10)==2)
assert(compact:ApplyDelta("compact",{}, {"one"}))
local shared=compact:Search("共享坐骑",10)
assert(#shared==1 and shared[1].record.id=="two", "removing duplicate memberships keeps the other owner")
assert(compact:ApplyDelta("compact",{first},{}))
compact:Rebuild()
assert(#compact:Search("共享坐骑",10)==2 and #compact:Search("",10,{categoryID="坐骑类"})==2)
assert(compact:ApplyDelta("compact",{{id="two",title="独立飞龙",category="飞龙类"}},{}))
assert(#compact:Search("共享坐骑",10)==1)
assert(compact:UnregisterSource("compact"))
for _,name in ipairs({"entries","grams","categories"}) do
    assert(next(compact[name])==nil,"source removal must clear "..name)
end
assert(compact.exact==nil and compact.prefix==nil and compact.tokens==nil,"retired index families must not return")
print("Lychee search platform PASS")
