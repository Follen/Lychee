local Fixture=dofile("tests/support/provider_fixture.lua")
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

local root = "addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"Core/Scheduler.lua"})

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
assert(index:ApplyDelta("mutation-test", {{
    id = "spell:393256", kind = "spell", category = { id = "spells", title = { zhCN = "技能" } },
    title = "利爪防御者之路（更新）", aliases = { { text = "红玉新", locale = "zhCN" } },
}}, {}))
local mutationHits = index:Search("红玉新", 10)
local mutationFound = false
for mutationIndex = 1, #mutationHits do if mutationHits[mutationIndex].sourceID == "mutation-test" then mutationFound = true end end
assert(mutationFound)
assert(index:ApplyDelta("mutation-test",{}, {"spell:393256"}))
local afterRemoveHits = index:Search("红玉新", 10)
for removeIndex = 1, #afterRemoveHits do assert(afterRemoveHits[removeIndex].sourceID ~= "mutation-test") end
assert(index:Invalidate("mutation-test", 4))

assert(index:RegisterSource({ id = "generation-test", revision = 2 }))
assert(index:ApplyDelta("generation-test", {{ id = "one", title = "代际记录" }},{}))
local generation = index.sources["generation-test"]._generation
local stale,reason=index:CommitSnapshot("generation-test", {{ id = "old", title = "旧代记录" }}, 2, generation - 1)
assert(not stale and reason=="STALE_GENERATION")

_G.__locale = "enUS"
I.Search.RuntimeIdentity:Refresh()
I.Search.Normalizer.locale = "enUS"
index:Rebuild()
assert(#index:Search("红玉", 10) == 0)
local english = index:Search("ruby life pools", 10)
assert(#english == 1 and english[1].item.id == "spell:393256")

-- Catalog owners deliver bounded hits through API 3; no Host catalog is created.
_G.__locale="zhCN";I.Search.RuntimeIdentity:Refresh();I.Search.Normalizer.locale="zhCN";I.Locale.code="zhCN"
I.Registry:SetReady(true)
local handle=assert(Fixture:Register({id="test.search",apiVersion=3,minApiRevision=1,version="1",title="生物来源",catalog={
 {id="creature:1",title="红玉小怪",kindTitle="生物",category={id="dungeons",title="副本",color={0.8,0.4,0.7,1}}}
}}))
local catalog=handle.catalog
local version=catalog:GetState().revision
assert(catalog:Update({upsert={{id="creature:2",title="增量小怪"}}}))
assert(catalog:GetState().revision==version+1)
local _,results=I.Search.Query:Query("红玉小怪",{})
assert(#results==1 and results[1].kindTitle=="生物" and results[1].sourceTitle=="生物来源")
assert(results[1].category=="副本" and results[1].categoryColor[1]==0.8)
assert(next(I.Search.StaticIndex.entries)==nil,"Host retains no complete catalog")
local other=assert(Fixture:Register({id="test.other",apiVersion=3,version="1",title="Other",catalog={{id="one",title="保留记录"}}}))
local previous=other.catalog:GetState().revision
assert(catalog:Update({upsert={{id="creature:3",title="局部更新"}}}))
assert(other.catalog:GetState().revision==previous and other.catalog:Resolve("one").title=="保留记录")
version=catalog:GetState().revision
assert(catalog:Update({upsert={{id="batch1",title="批量一"},{id="batch2",title="批量二"}}}))
assert(catalog:GetState().revision==version+1,"one atomic delta bumps once")
assert(not catalog:Update({upsert={{id="bad",title="Bad",category={id="bad id"}}}}))
assert(catalog:GetState().revision==version+1,"invalid batch changes nothing")
local previousProfiler,clock=debugprofilestop,0
debugprofilestop=function()clock=clock+10;return clock end
index:Search("过期技绿",10)
debugprofilestop=previousProfiler
assert((index:GetDiagnostics().FUZZY_TIME_BUDGET or 0)>0)
assert(handle:Unregister() and other:Unregister())
local _,removed=I.Search.Query:Query("红玉小怪",{})
assert(#removed==0)

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
for _,name in ipairs({"entries","exact","prefix","tokens","grams","categories"}) do
    assert(next(compact[name])==nil,"source removal must clear "..name)
end
print("Lychee search platform PASS")
