-- Cold real Provider -> Registry -> StaticIndex path, without UI or queries.
-- --record records a baseline; default checks the allocation budget.
local baselineRoot = os.getenv("LYCHEE_PERF_BASELINE")
local function source(path)
    return dofile((baselineRoot and baselineRoot ~= "" and baselineRoot .. "/" or "") .. "package/Lychee/" .. path)
end
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "today", 120100 end
function InCombatLockdown() return false end
STANDARD_TEXT_FONT = "test.ttf"
local frames = 0
local Frame = {}; Frame.__index = Frame
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterAllEvents() for event in pairs(self.events) do self.events[event] = nil end end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function CreateFrame(_, name, parent)
    frames = frames + 1
    local frame = setmetatable({scripts={}, events={}, parent=parent}, Frame)
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame()
local mountNames = {"星光云端翔龙", "无敌", "机械路霸", "翡翠梦境角鹰兽", "冰霜巨龙", "炽焰凤凰", "午夜战马", "岩石始祖幼龙"}
C_MountJournal = {
    GetMountIDs=function() local ids={}; for n=1,1500 do ids[n]=n end; return ids end,
    GetMountInfoByID=function(n) return mountNames[(n-1)%#mountNames+1]..n,100000+n,123456,false,true,1,false,false,nil,false,true,n end,
}
for _, path in ipairs({"Bootstrap.lua", "Core/CharacterStore.lua", "Builtin/Definitions.lua", "Builtin/Shared/Support.lua", "Core/ProviderLocales.lua",
    "Builtin/Crests/Locales.lua", "Builtin/GameMenus/Locales.lua", "Builtin/Bosses/Locales.lua", "Builtin/Mounts/Locales.lua",
    "Builtin/Shared/CatalogProvider.lua", "Core/ContextStore.lua", "Search/RuntimeIdentity.lua", "Search/Normalizer.lua",
    "Search/ProviderPolicy.lua", "Search/StaticIndex.lua", "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua",
    "Core/IntentRouter.lua", "Core/Scheduler.lua", "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "Core/ProviderRuntime.lua",
    "PublicAPI/SDK.lua", "Builtin/Shared/InterfaceActions.lua", "Builtin/Bosses/JournalCatalog.lua", "Builtin/Crests/Provider.lua",
    "Builtin/GameMenus/Provider.lua", "Builtin/Bosses/Provider.lua", "Builtin/Mounts/Provider.lua", "Builtin/Init.lua"}) do source(path) end
local I = LycheeInternal
local function measure(callback)
    collectgarbage("collect")
    local before = collectgarbage("count")
    collectgarbage("stop")
    local started = os.clock()
    local ok, err = pcall(callback)
    local ms, allocated = (os.clock()-started)*1000, collectgarbage("count")-before
    collectgarbage("restart"); collectgarbage("collect")
    local retained = collectgarbage("count")-before
    assert(ok, err)
    return allocated, retained, ms
end
local beforeFrames = frames
local allocated, retained, ms = measure(function() I.Builtin:Init(); I.Registry:SetReady(true) end)
local index = I.Search.StaticIndex
local count = 0; for _ in pairs(index.entries) do count=count+1 end
assert(count == 2689, "startup dataset changed: "..count)
assert(frames == beforeFrames + 1, "mount event frame count changed")
local rebuildAlloc, rebuildRetained, rebuildMS = measure(function() index:Rebuild() end)
print(string.format("STARTUP entries=%d alloc_KiB=%.2f retained_KiB=%.2f transient_KiB=%.2f ms=%.2f frames=%d", count, allocated, retained, allocated-retained, ms, frames-beforeFrames))
print(string.format("REBUILD alloc_KiB=%.2f retained_delta_KiB=%.2f ms=%.2f", rebuildAlloc, rebuildRetained, rebuildMS))
if arg[1] ~= "--record" then
    assert(allocated < 15000, "startup allocation exceeds 15000 KiB")
    assert(retained < 7424, "startup retained memory exceeds existing 7.25 MiB limit")
    assert(rebuildAlloc < 4500, "rebuild allocation exceeds 4500 KiB")
    assert(rebuildRetained < 128, "rebuild retained growth exceeds 128 KiB")
end
print("performance_startup: PASS")
