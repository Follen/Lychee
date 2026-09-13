-- Search-owned allocation and lifetime budgets. Same harness accepts archived sources.
local baselineRoot = os.getenv("LYCHEE_PERF_BASELINE")
local function loadSource(file)
    return dofile((baselineRoot and baselineRoot ~= "" and baselineRoot .. "/" or "") .. "addon/Lychee/" .. file)
end
function GetLocale() return "zhCN" end
_G.LycheeInternal = {}
loadSource("Search/Normalizer.lua")
loadSource("Search/StaticIndex.lua")
loadSource("Search/ResultSnapshot.lua")
loadSource("Search/QueryOrchestrator.lua")
local I, N = LycheeInternal, LycheeInternal.Search.Normalizer
local baselineMode = arg[1] == "--measure"
local function oracle(value)
    local raw, parts = string.lower(tostring(value or "")), {}
    for index = 1, #raw do
        local byte = raw:byte(index)
        local punctuation = byte <= 32 or byte == 127 or byte >= 33 and byte <= 47
            or byte >= 58 and byte <= 64 or byte >= 91 and byte <= 96 or byte >= 123 and byte <= 126
        parts[index] = punctuation and " " or raw:sub(index, index)
    end
    return table.concat(parts):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end
for byte = 0, 255 do
    local value = "中文 A" .. string.char(byte) .. "B [技能]"
    assert(N:Normalize(value) == oracle(value), "normalizer byte mismatch " .. byte)
end
for n = 1, 1000 do
    local value = "别名\0 [" .. n .. "] \t Frost/中国 -- " .. string.char(n % 256)
    assert(N:Normalize(value) == oracle(value), "normalizer mixed text mismatch")
end
N:ClearCache(); collectgarbage("collect")
local before = collectgarbage("count")
collectgarbage("stop")
local start = os.clock()
for n = 1, 2048 do N:Normalize("  技能 " .. n .. "::Frost / alias [" .. n .. "]  ") end
local normalizationMS = (os.clock() - start) * 1000
local normalizationKB = collectgarbage("count") - before
collectgarbage("restart"); N:ClearCache(); collectgarbage("collect")
before = collectgarbage("count")
for n = 1, 128 do N:Normalize(string.rep("Long Mixed 中国:: ", 512) .. n) end
collectgarbage("collect")
local longRetained = collectgarbage("count") - before
local index = I.Search.StaticIndex:New()
assert(index:RegisterSource({ id = "performance", enabled = true }))
before = collectgarbage("count")
for n = 1, 5000 do assert(index:Invalidate("performance", "entry:" .. n)) end
local invalidationCount = 0
for _ in pairs(index.sources.performance.invalidation or {}) do invalidationCount = invalidationCount + 1 end
local entries = {}
for n = 1, 1000 do entries[n] = { id = tostring(n), title = "共同候选 " .. n } end
assert(index:CommitSnapshot("performance", entries, 1))
assert(#index:Search("共同", 20) == 20)
local candidateCount = #(index.previousCandidates or {})
index:ClearQueryCache() -- A private index owner releases its own query workspace.
I.Search.Query:Cancel("hidden", 1)
local cancelledCandidates = #(index.previousCandidates or {})
print(string.format("SEARCH normalization_2048_KiB=%.1f normalization_ms=%.1f long_cache_retained_KiB=%.1f invalidation_keys=%d candidates_before=%d candidates_after_cancel=%d",
    normalizationKB, normalizationMS, longRetained, invalidationCount, candidateCount, cancelledCandidates))
if not baselineMode then
    assert(normalizationKB < 1024, "normalization exceeds fixed-workload allocation budget")
    assert(longRetained < 512, "long query text exceeds normalizer retained memory budget")
    assert(invalidationCount <= 1, "source invalidation retains unbounded keys")
    assert(cancelledCandidates == 0, "closed search retains prior candidates")
end
print(baselineMode and "Search measurement complete (new budgets not enforced)" or "Search allocation, byte-normalization and cancellation checks PASS")

-- Exercise the public catalog path, not only the private index cleanup primitive.
function GetBuildInfo() return "12.1.0","70000","",120100 end
dofile("tests/support/runtime.lua").Load("provider")
local captured;local create=LycheeInternal.Search.StaticIndex.New
function LycheeInternal.Search.StaticIndex:New() captured=create(self);return captured end
local catalog=assert(Lychee.SDK.CreateCatalog({id="cancellation",scope={products={"retail"}}}))
assert(catalog:Update({replace=entries}))
assert(#catalog:Search({normalized="共同",limit=20})==20)
assert(captured.previousCandidates==nil,"public catalog never retains candidates beyond Search")
assert(catalog:Close())
