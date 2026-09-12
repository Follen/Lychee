-- Real Provider/index/policy with deterministic collection and UI adapters.
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "today", 120100 end
local combat, frames, timers = false, {}, {}
function InCombatLockdown() return combat end
function IsPlayerSpell() return false end -- Collection spells are outside this bank.
C_Timer={After=function(delay, callback) assert(delay==0); timers[#timers+1]=callback end}
function CreateFrame()
    local frame={events={},scripts={}}
    function frame:RegisterEvent(event) self.events[event]=true end
    function frame:UnregisterAllEvents() self.events={} end
    function frame:SetScript(event, callback) self.scripts[event]=callback end
    frames[#frames+1]=frame
    return frame
end
local function flush()
    local pending=timers; timers={}
    for _, callback in ipairs(pending) do callback() end
end
local mounts={
    [11]={name="无敌",spell=90011,collected=true},
    [12]={name="星光龙",spell=90012,collected=true,usable=false},
    [13]={name="未收藏战马",spell=90013,collected=false},
    [14]={name="隐藏战马",spell=90014,collected=true,hidden=true},
}
local reads, listReads, failedID, failedList = 0, 0
local journal={
    GetMountIDs=function()
        listReads=listReads+1
        if failedList then error("journal temporarily unavailable") end
        local ids={}; for id in pairs(mounts) do ids[#ids+1]=id end; table.sort(ids); return ids
    end,
    GetMountInfoByID=function(id)
        reads=reads+1
        if id==failedID then error("mount temporarily unavailable") end
        local mount=mounts[id]; if not mount then return end
        return mount.name,mount.spell,123456,false,mount.usable~=false,1,false,false,nil,mount.hidden==true,mount.collected,id
    end,
    GetMountFromSpell=function(spellID)
        for id, mount in pairs(mounts) do if mount.spell==spellID then return id end end
    end,
}
C_MountJournal=journal
local root="addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"../Lychee_Player/Achievements/Locales.lua", "../Lychee_Inspector/Locales.lua", "../Lychee_Player/Bags/Locales.lua", "../Lychee_Player/BlizzardSettings/Locales.lua", "../Lychee_Encounters/Bosses/Locales.lua", "../Lychee_Player/Crests/Locales.lua", "../Lychee_Player/EquipmentSets/Locales.lua", "../Lychee_Player/GameMenus/Locales.lua", "../Lychee_Player/GreatVault/Locales.lua", "../Lychee_Player/Keystones/Locales.lua", "../Lychee_Player/Mounts/Locales.lua", "../Lychee_Player/PlayerSpells/Locales.lua", "../Lychee_Player/TalentLoadouts/Locales.lua", "Shared/CatalogProvider.lua", "Secure/Descriptor.lua", "Secure/Policy.lua", "Shared/InterfaceActions.lua", "../Lychee_Player/Mounts/Provider.lua", "../Lychee_Player/GreatVault/Provider.lua", "Core/Modules.lua"})
local I, M = LycheeInternal, TestPackages.Modules.Mounts
local function find(text, provider)
    local _, items=I.Search.Query:Query(text,{visible=true})
    for _, item in ipairs(items) do if item.providerID==provider then return item end end
end
local function event(name, ...)
    local frame=assert(M.eventFrame)
    assert(frame.events[name], "registered event: "..name)
    frame.scripts.OnEvent(frame,name,...)
end
local baseline=#frames
C_MountJournal=nil
assert(not M:Init() and #frames==baseline, "absent collection API creates no frame or provider")
C_MountJournal=journal
TestPackages.Modules:Init(); I.Registry:SetReady(true); flush()
assert(M.handle and TestPackages.Modules.GreatVault.handle, "both providers are wired by Builtin.Init")
assert(#frames==baseline+1 and not M.eventFrame.scripts.OnUpdate, "one event-only collection frame")
local entry=assert(find("无敌","lychee.mounts"))
assert(entry.ref.entryID=="mount:11" and entry.interaction.actions[1].spellID==90011)
assert(entry.interaction.actions[1].kind=="secure-spell" and entry.interaction.primaryActionID=="summon")
assert(entry.interaction.drag.type=="spell" and entry.interaction.drag.spellID==90011)
assert(find("星光","lychee.mounts"), "temporary inability to summon does not remove search/drag")
assert(not find("未收藏战马","lychee.mounts") and not find("隐藏战马","lychee.mounts"))
local policy=Lychee.Secure.Policy
assert(policy:IsSpellAvailable(90011) and policy:IsSpellAvailable(90012))
assert(not policy:IsSpellAvailable(90013) and not policy:IsSpellAvailable(90014) and not policy:IsSpellAvailable(99999))
failedID=11; assert(not policy:IsSpellAvailable(90011), "restricted collection read fails closed"); failedID=nil
;(function()
    local oldBook, oldSpell, oldEnum, oldKnown, oldPassive = C_SpellBook, C_Spell, Enum, IsPlayerSpell, IsPassiveSpell
    local known, passive, calls = true, false, 0
    Enum = {SpellBookSpellBank = {Player = 1}}
    C_SpellBook = {IsSpellKnown=function(_, bank) assert(bank == 1); calls = calls + 1; return known end}
    C_Spell = {IsSpellPassive=function() return passive end}
    IsPlayerSpell = function() error("modern API must take precedence") end
    IsPassiveSpell = IsPlayerSpell
    assert(policy:IsSpellAvailable(99999), "modern player spell is accepted")
    passive = true
    assert(not policy:IsSpellAvailable(99999), "modern passive spell is rejected")
    passive, known = false, false
    assert(not policy:IsSpellAvailable(99999), "spell knowledge changes are not cached")
    assert(policy:IsSpellAvailable(90011), "modern unknown spell can still be a collected mount")
    assert(calls == 4, "one knowledge check per policy request")
    C_SpellBook, C_Spell, Enum, IsPlayerSpell, IsPassiveSpell = oldBook, oldSpell, oldEnum, oldKnown, oldPassive
end)()

local state=I.Providers.entries["lychee.mounts"]
local beforeReads,beforeLists,beforeRevision=reads,listReads,state.revision
for n=1,100 do find(n%2==0 and "无敌" or "星光","lychee.mounts") end
assert(reads==beforeReads and listReads==beforeLists and #timers==0, "queries use index without collection scans")
mounts[15]={name="翡翠幼龙",spell=90015,collected=true}
event("NEW_MOUNT_ADDED",15); event("NEW_MOUNT_ADDED",15)
assert(#timers==1, "same-frame mount events coalesce")
flush()
assert(reads==beforeReads+1 and listReads==beforeLists, "new mount event reads only one ID")
assert(find("翡翠幼龙","lychee.mounts") and not I.Providers:IsCurrent(entry), "delta updates index and rejects stale refs")
beforeRevision=state.revision
event("NEW_MOUNT_ADDED",15); flush()
assert(state.revision==beforeRevision, "unchanged mount does not rebuild source")
mounts[15].name="翡翠巨龙"
event("NEW_MOUNT_ADDED",15); flush()
assert(find("翡翠巨龙","lychee.mounts").text=="翡翠巨龙" and M.handle.catalog:Resolve("mount:15").title=="翡翠巨龙")
mounts[15].collected=false
event("COMPANION_UNLEARNED"); flush()
assert(not find("翡翠巨龙","lychee.mounts"), "unlearned mount removed")
mounts[16]={name="碧蓝云端翔龙",spell=90016,collected=true}
combat=true; beforeReads=reads
event("NEW_MOUNT_ADDED",16); event("COMPANION_LEARNED")
assert(reads==beforeReads and #timers==0, "combat events only mark dirty")
combat=false; event("PLAYER_REGEN_ENABLED"); flush()
assert(find("碧蓝云端翔龙","lychee.mounts"), "dirty work resumes after combat")

beforeRevision=state.revision
mounts[11].name="更新后的无敌"; failedID=11
event("NEW_MOUNT_ADDED",11); flush()
assert(state.revision==beforeRevision and M.dirtyIDs[11] and M.lastError, "failed read retains cache and dirty state")
assert(M.handle.catalog:Resolve("mount:11").title=="无敌", "failed refresh keeps the old indexed title")
failedID=nil; event("PLAYER_REGEN_ENABLED"); flush()
assert(find("更新后的无敌","lychee.mounts"))
local update=M.handle.catalog.Update
M.handle.catalog.Update=function() return nil,{code="TEST_COMMIT_FAILURE"} end
mounts[11].name="提交后的无敌"
event("NEW_MOUNT_ADDED",11); flush()
assert(M.lastError=="TEST_COMMIT_FAILURE" and M.items[11].title=="更新后的无敌" and M.dirtyIDs[11])
M.handle.catalog.Update=update; event("PLAYER_REGEN_ENABLED"); flush()
assert(find("提交后的无敌","lychee.mounts"), "failed commit remains retryable")
failedList=true; event("COMPANION_LEARNED"); flush()
assert(M.fullDirty and find("提交后的无敌","lychee.mounts"), "full read failure preserves index")
failedList=nil; event("PLAYER_REGEN_ENABLED"); flush()

event("NEW_MOUNT_ADDED",11)
beforeReads=reads
assert(M.handle:SetAvailability(false))
assert(next(M.eventFrame.events)==nil and M.eventFrame.scripts.OnEvent==nil)
flush(); assert(reads==beforeReads and not find("无敌","lychee.mounts"), "disabled callback cannot keep working")
local warmFrames=#frames
assert(M.handle:SetAvailability(true)); flush()
assert(#frames==warmFrames and find("提交后的无敌","lychee.mounts"), "re-enable reuses event frame")
event("NEW_MOUNT_ADDED",11)
assert(M.handle:SetAvailability(false)); assert(M.handle:SetAvailability(true))
beforeLists=listReads; flush()
assert(listReads==beforeLists+1, "obsolete queued callback cannot consume new lifecycle work")

local vault=TestPackages.Modules.GreatVault
local function open(text)
    return I.Providers:Execute(assert(find(text,"lychee.great-vault")),"open",{})
end
for _, keyword in ipairs({"宏伟宝库","低保","宝库","每周奖励","great vault"}) do
    assert(find(keyword,"lychee.great-vault").ref.entryID=="great-vault")
end
local result,err=open("低保")
assert(not result and err.code=="UI_UNAVAILABLE", "missing UI bootstrap fails honestly")
local opens=0
WeeklyRewards_ShowUI=function()
    opens=opens+1
    WeeklyRewardsFrame={shown=true,IsShown=function(self) return self.shown end}
end
result=open("宏伟宝库"); assert(result.ok and result.close and opens==1)
result=open("低保"); assert(result.ok and opens==1, "already-open vault stays open")
WeeklyRewardsFrame.shown=false
combat=true; result,err=open("低保"); assert(not result and err.code=="COMBAT_LOCKED" and opens==1); combat=false
DISALLOW_FRAME_TOGGLING=true; result,err=open("低保"); assert(not result and err.code=="UI_UNAVAILABLE" and opens==1); DISALLOW_FRAME_TOGGLING=nil
WeeklyRewards_ShowUI=function() error("UI loading failed") end
result,err=open("低保"); assert(not result and err.code=="UI_UNAVAILABLE")
WeeklyRewards_ShowUI=function() end
result,err=open("低保"); assert(not result and err.code=="UI_UNAVAILABLE", "silent native failure is not success")
assert(vault.handle:Unregister())
assert(not find("低保","lychee.great-vault") and not vault.handle)
assert(M.handle:Unregister() and not M.handle and next(M.items)==nil and next(M.eventFrame.events)==nil)

-- Bounded offline peak: 1,500 collected mounts, no game engine/profiler claims.
mounts={}
for n=1,1500 do mounts[n]={name="峰值测试坐骑"..n,spell=100000+n,collected=true} end
collectgarbage("collect")
local memoryBefore,started=collectgarbage("count"),os.clock()
assert(M:Init()); flush()
local initMS=(os.clock()-started)*1000
collectgarbage("collect")
local retainedKB=collectgarbage("count")-memoryBefore
assert(M.handle.catalog:GetState().entries==1500)
beforeReads,beforeLists=reads,listReads
started=os.clock()
for n=1,100 do assert(find(n%2==0 and "峰值测试坐骑1500" or "峰值测试坐骑1499","lychee.mounts")) end
local queryMS=(os.clock()-started)*1000/100
assert(reads==beforeReads and listReads==beforeLists and #timers==0, "peak query remains collection-scan free")
assert(M.handle:Unregister()); flush()
assert(next(M.eventFrame.events)==nil and #timers==0)
print(string.format("Mounts/vault PASS: 1500 mounts; init %.2f ms / retained %.1f KiB; alternating query mean %.3f ms (offline Lua only)",initMS,retainedKB,queryMS))
assert(retainedKB < 8192, "1500-mount retained index exceeds 8 MiB memory budget")
