-- English catalogue lifecycle against real Host modules; no game UI is emulated.
local frames,timers={},{}
local batches,maxBatch,totalCPU,peakTimers=0,0,0,0
local namesReady,instanceReads,bossReads=false,0,0
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return false end
-- Deterministic read batching; wall-clock timing is measured separately.
function debugprofilestop() return 0 end
function CreateFrame(kind)
    assert(kind=="Frame","catalogue must not create visible controls")
    local f={events={},scripts={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    function f:Hide() end
    function f:Show() end
    frames[#frames+1]=f;return f
end
local function activeTimers()
    local n=0;for _,t in ipairs(timers) do if not t.cancelled then n=n+1 end end;return n
end
C_Timer={NewTimer=function(_,fn)
    local t={callback=fn};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t
    peakTimers=math.max(peakTimers,activeTimers())
    assert(activeTimers()<=1,"only one effective catalogue task may be queued")
    return t
end}
local function step()
    local t=table.remove(timers,1);if not t then return end
    if not t.cancelled then
        local beforeReads=bossReads;local started=os.clock();t.callback()
        local ms=(os.clock()-started)*1000
        batches=batches+1;maxBatch=math.max(maxBatch,ms);totalCPU=totalCPU+ms
        assert(bossReads-beforeReads<=16,"native reads exceed one batch")
    end
end
local function drain()
    local n=0;while #timers>0 do n=n+1;assert(n<500,"unbounded catalogue work");step() end
end
function EJ_GetInstanceInfo(id) instanceReads=instanceReads+1;if namesReady then return "Localized instance "..id end end
function EJ_GetEncounterInfo(id) bossReads=bossReads+1;if namesReady then return "Localized boss "..id end end
dofile("tests/support/runtime.lua").Load("provider", {"Providers/Achievements/Locales/enUS.lua", "Providers/Achievements/Locales/zhCN.lua", "Providers/AddonInspector/Locales/enUS.lua", "Providers/AddonInspector/Locales/zhCN.lua", "Providers/Bags/Locales/enUS.lua", "Providers/Bags/Locales/zhCN.lua", "Providers/BlizzardSettings/Locales/enUS.lua", "Providers/BlizzardSettings/Locales/zhCN.lua", "Providers/Bosses/Locales/enUS.lua", "Providers/Bosses/Locales/zhCN.lua", "Providers/Crests/Locales/enUS.lua", "Providers/Crests/Locales/zhCN.lua", "Providers/EquipmentSets/Locales/enUS.lua", "Providers/EquipmentSets/Locales/zhCN.lua", "Providers/GameMenus/Locales/enUS.lua", "Providers/GameMenus/Locales/zhCN.lua", "Providers/GreatVault/Locales/enUS.lua", "Providers/GreatVault/Locales/zhCN.lua", "Providers/Keystones/Locales/enUS.lua", "Providers/Keystones/Locales/zhCN.lua", "Providers/Mounts/Locales/enUS.lua", "Providers/Mounts/Locales/zhCN.lua", "Providers/PlayerSpells/Locales/enUS.lua", "Providers/PlayerSpells/Locales/zhCN.lua", "Providers/TalentLoadouts/Locales/enUS.lua", "Providers/TalentLoadouts/Locales/zhCN.lua", "Core/Scheduler.lua", "Providers/Shared/CatalogProvider.lua", "Providers/Shared/InterfaceActions.lua", "Providers/Bosses/JournalCatalog.lua"})
local I=LycheeInternal
local data=I.ProviderModules.JournalCatalog
local subset={};for i=1,65*3 do subset[i]=data.encounters[i] end;data.encounters=subset;data.encounterCount=65
local firstID,firstInstance=subset[1],subset[2]
dofile("addon/Lychee/Providers/Bosses/Provider.lua")
local m=I.ProviderModules.Bosses
local baseFrames=#frames
collectgarbage("collect");local memoryBefore=collectgarbage("count");collectgarbage("stop")
assert(m:Init());I.Registry:SetReady(true)
assert(m.defaultEnabled and m.active and activeTimers()==1)
assert(bossReads==0,"registration must defer native catalogue reads")
local provider=I.Providers.entries[m.id]
assert(#provider.records==0)
step();assert(bossReads==16 and #provider.records==0,"first batch reads without exposing partial staging")
drain()
assert(#provider.records==65 and not m.timer and not m.job and activeTimers()==0)
assert(provider.recordMap["boss-"..firstID].title=="Boss "..firstID)
assert(provider.recordMap["boss-"..firstID].subtitle=="Instance "..firstInstance)
assert(m.hasFallback and m.frame.events.ADDON_LOADED)
assert(#frames==baseFrames+1,"only one reusable lifecycle frame, no index UI")
local reads=bossReads;local revision=m.handle:GetState().revision
m.frame.scripts.OnEvent(m.frame,"ADDON_LOADED","Unrelated_AddOn")
assert(activeTimers()==0 and bossReads==reads and m.handle:GetState().revision==revision)
namesReady=true
m.frame.scripts.OnEvent(m.frame,"ADDON_LOADED","Blizzard_EncounterJournal")
assert(activeTimers()==1);drain()
assert(provider.recordMap["boss-"..firstID].title=="Localized boss "..firstID)
assert(provider.recordMap["boss-"..firstID].subtitle=="Localized instance "..firstInstance)
assert(not m.hasFallback and not m.frame.events.ADDON_LOADED and not m.timer and not m.job)
m:MarkDirty();step();assert(m.job,"cancel must interrupt a live partial build")
local stale=m.timer;local staleEvent=m.frame.scripts.OnEvent
assert(m.handle:SetAvailability(false))
assert(not m.active and not m.timer and not m.job and not next(m.frame.events) and activeTimers()==0)
reads=bossReads;stale.callback();staleEvent(m.frame,"ADDON_LOADED","Blizzard_EncounterJournal");drain()
assert(bossReads==reads and activeTimers()==0 and not m.active,"late callbacks must not restart disabled catalogue")
assert(m.handle:SetAvailability(true));drain()
assert(#provider.records==65 and #frames==baseFrames+1 and not m.timer and not m.job)
assert(m.handle:SetAvailability(false));drain()
local allocation=collectgarbage("count")-memoryBefore
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-memoryBefore
assert(peakTimers==1 and activeTimers()==0 and not next(m.frame.events))
print(string.format("English bosses PASS records=65 batches=%d cpu_ms=%.3f max_batch_ms=%.3f allocated_KiB=%.1f retained_KiB=%.1f feature_frames=1 peak_timers=%d idle_timers=0",batches,totalCPU,maxBatch,allocation,retained,peakTimers))
