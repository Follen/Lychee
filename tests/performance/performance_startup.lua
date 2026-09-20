-- Cold real Provider -> Registry -> StaticIndex path, without UI or queries.
-- --record records a baseline; default checks the allocation budget.
local baselineRoot = os.getenv("LYCHEE_PERF_BASELINE")
local function source(path)
    return dofile((baselineRoot and baselineRoot ~= "" and baselineRoot .. "/" or "") .. "addon/Lychee/" .. path)
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
dofile("tests/support/runtime.lua").Load("provider", {"Providers/Crests/Locales/enUS.lua", "Providers/Crests/Locales/zhCN.lua", "Providers/GameMenus/Locales/enUS.lua", "Providers/GameMenus/Locales/zhCN.lua", "Providers/Bosses/Locales/enUS.lua", "Providers/Bosses/Locales/zhCN.lua", "Providers/Mounts/Locales/enUS.lua", "Providers/Mounts/Locales/zhCN.lua", "Providers/Shared/CatalogProvider.lua", "Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Providers/Shared/InterfaceActions.lua", "Providers/Bosses/JournalCatalog.lua", "Providers/Crests/Provider.lua", "Providers/GameMenus/Provider.lua", "Providers/Bosses/Provider.lua", "Providers/Mounts/Provider.lua", "Providers/Init.lua"}, {root=(baselineRoot and baselineRoot~="" and baselineRoot.."/" or "").."addon/Lychee/",load=source})
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
local allocated, retained, ms = measure(function() I.ProviderModules:Init(); I.Registry:SetReady(true) end)
local index = I.Search.StaticIndex
local count = 0; for _ in pairs(index.entries) do count=count+1 end
assert(I.ProviderModules.JournalCatalog.encounterCount==490,"captured raid boss coverage changed")
assert(count == 1535+490, "startup dataset changed: "..count)
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
