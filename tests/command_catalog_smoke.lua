-- CommandCatalog owns fixed-command search and exposes only a schedulable ambient view.
_G = _G or {}
function GetLocale() return "zhCN" end
LycheeDB = { searchIndex = { marker = "shared-index" } }

local root = "package/Lychee/"
for _, file in ipairs({
    "Bootstrap.lua", "Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua",
    "Search/Normalizer.lua",
    "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua",
    "Core/Boundary.lua",
    "Core/ExtensionRegistry.lua",
}) do
    dofile(root .. file)
end

local I = _G.LycheeInternal
local catalog, globalIndex = I.Catalog, I.Search.StaticIndex
assert(catalog.commands == nil and catalog.byExt == nil, "mutable command storage stays private")

local originalItemIntent = function() return { type = "test.open-low", version = 1, payload = {} } end
local low = {
    id = "low",
    title = { default = "Open settings", zhCN = "打开设置" },
    aliases = { { text = "配置", locale = "zhCN" } },
    keywords = { "选项" },
    description = { default = "Open settings.", zhCN = "打开设置面板。" },
    category = { id = "settings", title = { default = "Settings", zhCN = "设置" }, order = 4 },
    presentation = "row",
    intent = { type = "test.open-low", version = 1, payload = { page = "general" } },
    itemIntent = originalItemIntent,
    payload = { nested = { value = "registered" } },
    priority = 10,
}
local high = {
    id = "high",
    title = "打开设置",
    presentation = "custom-panel",
    panel = "settings",
    priority = 90,
}
local originalResolve = function() return { { id = "resolved" } } end
local ambient = {
    id = "ambient",
    title = "动态搜索",
    presentation = "dynamic-list",
    priority = 30,
    match = { type = "ambient", minLength = 2, maxLength = 6 },
    payload = { nested = { value = "ambient-registered" } },
    resolve = originalResolve,
}

assert(catalog:Add("test.low", low))
assert(catalog:Add("test.high", high))
assert(catalog:Add("test.ambient", ambient))

-- Registration snapshots the complete descriptor, including nested tables and callbacks.
low.id = "mutated-low"
low.title.zhCN = "篡改标题"
low.aliases[1].text = "篡改别名"
low.keywords[1] = "篡改关键词"
low.description.zhCN = "篡改描述"
low.category.title.zhCN = "篡改分类"
low.category.order = 99
low.presentation = "custom-panel"
low.intent.type = "test.mutated"
low.itemIntent = function() return nil end
low.payload.nested.value = "descriptor-mutated"
low.priority = 999
ambient.title = "篡改动态标题"
ambient.match.type = "explicit"
ambient.match.minLength = 99
ambient.priority = 999
ambient.payload.nested.value = "descriptor-mutated"
ambient.resolve = function() return nil end

assert(next(globalIndex.sources) == nil, "commands must not leak into the shared SearchRecord index")
assert(next(globalIndex.entries) == nil, "commands must not become shared SearchRecords")

local fixed = catalog:Query({ normalized = "打开设置" }, 10)
assert(#fixed == 2, "fixed commands must produce exactly one result each")
assert(fixed[1].command.id == "high" and fixed[1].sourcePriority == 90, "per-command priority must order ties")
assert(fixed[2].command.id == "low" and fixed[2].stableID == "test.low:low")
assert(fixed[1].text == "打开设置" and type(fixed[1].payload) == "table")
assert(fixed[2].command.presentation == "row" and fixed[2].command.intent.type == "test.open-low")
assert(fixed[2].command.itemIntent == originalItemIntent, "registered callback reference is frozen")
assert(fixed[2].payload.nested.value == "registered", "registered payload is deeply frozen")
assert(fixed[2].description == "打开设置面板。" and fixed[2].category == "设置")
local alias = catalog:Query({ normalized = "配置" }, 10)
assert(#alias == 1 and alias[1].command.id == "low", "aliases use the catalog-owned projection")
assert(#catalog:Query({ normalized = "篡改标题" }, 10) == 0, "descriptor mutation cannot rewrite the index")
assert(catalog:Query({ normalized = "动态搜索" }, 10)[1] == nil, "ambient resolvers are not fixed rows")

local ambientView = catalog:GetAmbientView("动态", {})
assert(#ambientView == 1 and ambientView[1].command.id == "ambient")
assert(ambientView[1].key == "test.ambient:ambient" and ambientView[1].resolve == originalResolve)
assert(ambientView[1].command.match.type == "ambient" and ambientView[1].priority == 30)
assert(ambientView[1].command.payload.nested.value == "ambient-registered")
assert(#catalog:GetAmbientView("动", {}) == 0, "minimum length applies")
assert(#catalog:GetAmbientView("动态搜索输入项", {}) == 0, "maximum length applies")
assert(#catalog:GetAmbientView("动态", { ["test.ambient:ambient"] = false }) == 0, "session toggle applies")

-- Every outward value is detached from the internal projection.
local fetched = assert(catalog:Get("test.low:low"))
fetched.id = "returned-id"
fetched.title.zhCN = "返回值篡改"
fetched.aliases[1].text = "返回别名篡改"
fetched.intent.type = "test.return-mutated"
fetched.payload.nested.value = "return-mutated"
fetched._enabled = false
fixed[2].command.title.zhCN = "查询结果篡改"
fixed[2].command.payload.nested.value = "query-command-mutated"
fixed[2].payload.nested.value = "query-payload-mutated"
fixed[2].command._enabled = false
ambientView[1].priority = -1
ambientView[1].resolve = function() return nil end
ambientView[1].command.match.minLength = 99
ambientView[1].command.payload.nested.value = "ambient-view-mutated"

local afterReturnMutation = catalog:Query({ normalized = "打开设置" }, 10)
assert(#afterReturnMutation == 2 and afterReturnMutation[2].command.id == "low")
assert(afterReturnMutation[2].command.title.zhCN == "打开设置")
assert(afterReturnMutation[2].command.intent.type == "test.open-low")
assert(afterReturnMutation[2].payload.nested.value == "registered")
local ambientAfterMutation = catalog:GetAmbientView("动态", {})
assert(#ambientAfterMutation == 1 and ambientAfterMutation[1].priority == 30)
assert(ambientAfterMutation[1].resolve == originalResolve)
assert(ambientAfterMutation[1].command.match.minLength == 2)
assert(ambientAfterMutation[1].command.payload.nested.value == "ambient-registered")

assert(catalog:SetExtensionEnabled("test.high", false))
assert(LycheeDB.schemaVersion == 2 and LycheeDB.searchIndex == nil, "old search data is discarded and private enable state does not persist an index")
fixed = catalog:Query({ normalized = "打开设置" }, 10)
assert(#fixed == 1 and fixed[1].command.id == "low", "disabled fixed commands leave the catalog query")
assert(catalog:SetExtensionEnabled("test.high", true))
fixed = catalog:Query({ normalized = "打开设置" }, 10)
assert(#fixed == 2 and fixed[1].command.id == "high", "re-enabled commands restore the same projection once")
assert(catalog:RemoveExtension("test.high"))
assert(catalog:SetExtensionEnabled("test.ambient", false))
assert(#catalog:GetAmbientView("动态", {}) == 0, "disabled ambient commands are not schedulable")

assert(catalog:Get("test.low:low").id == "low")
assert(catalog:RemoveExtension("test.low"))
assert(LycheeDB.searchIndex == nil, "private removal does not persist executable search data")
assert(catalog:Get("test.low:low") == nil)
assert(#catalog:Query({ normalized = "打开设置" }, 10) == 0)

local retiringDraft = assert(I.Registry:Begin({
    id = "test.retiring",
    apiVersion = 2,
    minApiRevision = 1,
    title = "Retiring lifecycle fixture",
}))
assert(retiringDraft:RegisterCommand({
    id = "fixed",
    title = "退役固定命令",
    presentation = "row",
    intent = "test.retiring.fixed",
}))
assert(retiringDraft:RegisterCommand({
    id = "ambient",
    title = "退役动态命令",
    presentation = "dynamic-list",
    match = { type = "ambient", minLength = 1 },
    resolve = function() return {} end,
}))
local retiringHandle = assert(retiringDraft:Commit())
I.Registry:SetReady(true)
assert(#catalog:Query({ normalized = "退役固定命令" }, 10) == 1)
assert(#catalog:GetAmbientView("退役", {}) == 1)

local retiringObserved, fixedDuringRetiring, ambientDuringRetiring = false
assert(I.Registry:OnChange(function(entry, state)
    if entry.id ~= "test.retiring" or state ~= "retiring" then return end
    retiringObserved = true
    fixedDuringRetiring = #catalog:Query({ normalized = "退役固定命令" }, 10)
    ambientDuringRetiring = #catalog:GetAmbientView("退役", {})
end))
assert(retiringHandle:Unregister())
assert(retiringObserved, "unregister must emit retiring after command teardown")
assert(fixedDuringRetiring == 0, "fixed commands must be unqueryable inside retiring listeners")
assert(ambientDuringRetiring == 0, "ambient commands must be unschedulable inside retiring listeners")

print("Lychee command catalog smoke PASS")
