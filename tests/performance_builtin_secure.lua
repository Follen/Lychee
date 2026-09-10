-- Deterministic lifecycle/cost regression; --baseline reports pre-fix counters.
local baseline = arg and arg[1] == "--baseline"
local frames, scans, commits, submitted, queue = 0, 0, 0, 0, {}
local combat, disabled, failCommit = false, true, false
local count, changed = 200, false
function InCombatLockdown() return combat end
function CreateFrame()
    frames=frames+1
    return {events={}, RegisterEvent=function(self,e) self.events[e]=true end,
        UnregisterAllEvents=function(self) self.events={} end,
        SetScript=function(self,e,fn) self[e]=fn end}
end
C_Timer={After=function(_, fn) queue[#queue+1]=fn end}
Enum={SpellBookSpellBank={Player=0}}
C_SpellBook={GetNumSpellBookSkillLines=function() scans=scans+1; return 1 end,
    GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=count} end,
    GetSpellBookItemInfo=function(id) return {spellID=id,name=(changed and id==1) and "changed" or "spell"..id,iconID=id} end}
C_Spell={GetSpellDescription=function(id) return "description"..id end}
LycheeInternal={Builtin={}}
local definition, cleanup, records
local handle={Update=function(_,patch)
    commits=commits+1
    submitted=submitted+#(patch.replace or patch.upsert or {})+#(patch.remove or {})
    if failCommit then return false end
    if patch.replace then records={}; for _,r in ipairs(patch.replace) do records[r.id]=r end end
    for _,r in ipairs(patch.upsert or {}) do records[r.id]=r end
    for _,id in ipairs(patch.remove or {}) do records[id]=nil end
    return true
end}
Lychee={RegisterProvider=function(_,d)
    definition=d; records={}; for _,r in ipairs(d.entries) do records[r.id]=r end
    if not disabled then cleanup=d.onEnable(handle) end
    return handle
end}
local function flush() local pending=queue; queue={}; for _,fn in ipairs(pending) do fn() end end
local function enable(noFlush) disabled=false; cleanup=definition.onEnable(handle); if not noFlush then flush() end end
local function disable() disabled=true; cleanup("disable") end
local root = os.getenv('LYCHEE_PERF_SOURCE') or 'package/Lychee'
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
-- Exclude the shared bootstrap frame from this isolated feature cost fixture.
local featureCreateFrame=CreateFrame
CreateFrame=nil
dofile(root.."/".."Bootstrap.lua")
CreateFrame=featureCreateFrame
dofile(root.."/".."Builtin/Definitions.lua")
dofile(root.."/".."Builtin/Shared/Support.lua")
dofile(root.."/".."Core/ProviderLocales.lua")
dofile(root.."/".."Builtin/Achievements/Locales.lua")
dofile(root.."/".."Builtin/AddonInspector/Locales.lua")
dofile(root.."/".."Builtin/Bags/Locales.lua")
dofile(root.."/".."Builtin/BlizzardSettings/Locales.lua")
dofile(root.."/".."Builtin/Bosses/Locales.lua")
dofile(root.."/".."Builtin/Crests/Locales.lua")
dofile(root.."/".."Builtin/EquipmentSets/Locales.lua")
dofile(root.."/".."Builtin/GameMenus/Locales.lua")
dofile(root.."/".."Builtin/GreatVault/Locales.lua")
dofile(root.."/".."Builtin/Keystones/Locales.lua")
dofile(root.."/".."Builtin/Mounts/Locales.lua")
dofile(root.."/".."Builtin/PlayerSpells/Locales.lua")
dofile(root.."/".."Builtin/TalentLoadouts/Locales.lua")
dofile(root.."/".."Search/RuntimeIdentity.lua")
dofile(root.."/Builtin/PlayerSpells/Provider.lua")
dofile(root.."/Builtin/PlayerSpells/Init.lua")
local module=LycheeInternal.Builtin.PlayerSpells
local p=module.Provider
assert(module:Init())
local disabledScans=scans
enable()
local before=commits
for i=1,20 do p:Refresh() end
local redundant=commits-before
local initialFrame=p._eventFrame
before=scans
p._eventFrame.OnEvent(p._eventFrame,"SPELL_DATA_LOAD_RESULT",99999,true); flush()
local unrelated=scans-before
p._eventFrame.OnEvent(p._eventFrame,"SPELLS_CHANGED")
disable(); enable(true)
local reuse=frames
before=scans; flush(); local late=scans-before
collectgarbage("collect"); local memory=collectgarbage("count"); collectgarbage("stop")
local started=os.clock()
for i=1,100 do p:Refresh() end
local ms=(os.clock()-started)*1000
local allocation=collectgarbage("count")-memory
collectgarbage("restart")
collectgarbage('collect'); local retained=collectgarbage('count')-memory
for i=1,20 do disable(); enable() end
print(string.format("builtin perf: disabled scans=%d unchanged commits=%d unrelated scans=%d frames after reenable=%d late scans=%d; frames after 20 more toggles=%d; 100 unchanged refresh %.3fms %.1fKiB allocated %.1fKiB retained growth",disabledScans,redundant,unrelated,reuse,late,frames,ms,allocation,retained))
if baseline then return end
assert(disabledScans==0,"disabled provider must not scan")
assert(redundant==0,"unchanged refresh must not rebuild source")
assert(unrelated==0,"unrelated spell load must not scan")
assert(frames==1 and p._eventFrame==initialFrame,"event frame must be reused")
assert(late==0,"old lifecycle callback must not refresh")
before=submitted; changed=true; assert(p:Refresh()); assert(submitted-before==1 and records['spell:1'].title=='changed')
before=submitted; count=199; assert(p:Refresh()); assert(submitted-before==1 and not records['spell:200'])
changed=false; failCommit=true; assert(not p:Refresh()); assert(records['spell:1'].title=='changed')
failCommit=false; assert(p:Refresh()); assert(records['spell:1'].title=='spell1')
before=scans; combat=true; p._eventFrame.OnEvent(p._eventFrame,'SPELLS_CHANGED'); flush(); assert(scans==before)
combat=false; p._eventFrame.OnEvent(p._eventFrame,'PLAYER_REGEN_ENABLED'); flush(); assert(scans==before+1)
for i=1,20 do disable(); enable() end
assert(frames==1)
disable(); assert(not p._active and not next(initialFrame.events))
print('Builtin lifecycle/incremental regression PASS')
