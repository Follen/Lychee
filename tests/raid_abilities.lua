-- Real SDK query lifecycle with independent encounter/difficulty fixtures.
local locale=arg[1] or "zhCN"
local clock,timers,frames,combat,missing,failed,sync,reads,requests=0,{},{},false,{},false,false,0,0
local function fire(event,...)
 for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
function GetLocale()return locale end
function GetBuildInfo()return "12.1.0","69587","",120100 end
function GetTime()return clock end
function debugprofilestop()return os.clock()*1000 end
function InCombatLockdown()return combat end
function CreateFrame()
 local f={events={},scripts={}}
 function f:RegisterEvent(e)self.events[e]=true end
 function f:UnregisterEvent(e)self.events[e]=nil end
 function f:UnregisterAllEvents()self.events={}end
 function f:SetScript(e,fn)self.scripts[e]=fn end
 function f:Show()end
 function f:Hide()end
 frames[#frames+1]=f;return f
end
C_Timer={NewTimer=function(delay,fn)
 local t={at=clock+delay,fn=fn};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t
end}
local maxBatch=0
local function drain(stop)
 local count=0
 while #timers>0 do
  count=count+1;assert(count<20000,"unbounded query")
  table.sort(timers,function(a,b)return a.at<b.at end)
  local t=table.remove(timers,1);if not t.cancelled then clock=t.at;local started=debugprofilestop();t.fn();maxBatch=math.max(maxBatch,debugprofilestop()-started)end
  if stop and stop() then return end
 end
end
local spellNames={[101]="Fire Nova",[102]="Shadow Grip",[103]="Fire Nova",[104]="Heroic Fury",[105]="Heroic Resolve"}
C_Spell={GetSpellName=function(id)reads=reads+1;if not missing[id] then return spellNames[id] or ("Ability "..id) end end,GetSpellTexture=function(id)return id end,
 RequestLoadSpellData=function(id)
  requests=requests+1
  local function done()if not failed then missing[id]=nil end;fire("SPELL_DATA_LOAD_RESULT",id,not failed)end
  if sync then done()else C_Timer.NewTimer(0.1,done)end
 end}
function EJ_GetEncounterInfo(id)return id==11 and "Alpha Boss" or id==12 and "Beta Boss" or "Boss "..id end
function EJ_GetInstanceInfo(id)return "Raid "..id end
local load=dofile("tests/support/runtime.lua").Load
load("provider",{"Search/ProviderPolicy.lua","Core/Scheduler.lua","Builtin/Shared/CatalogProvider.lua","Builtin/Shared/InterfaceActions.lua","Builtin/Bosses/Locales.lua","Builtin/Bosses/JournalCatalog.lua"})
local I=LycheeInternal
local full=I.Builtin.JournalCatalog
I.Builtin.JournalCatalog={instances={[1]={"Raid 1",123}},encounters={11,1,"Alpha Boss",12,1,"Beta Boss"},encounterCount=2,
 difficulties={[11]="14,15,16",[12]="14,15"},abilities={[11]="101:1001:96;101:1002:128;102:1003:128;103:1004:32;104:1005:64;105:1007:32",[12]="101:1006:96"}}
dofile("addon/Lychee/Builtin/Bosses/Provider.lua")
local m=I.Builtin.Bosses;assert(m:Init());I.Registry:SetReady(true);drain()
assert(I.Providers.entries[m.id].definition.apiVersion=="1.0.0", "all locales receive query resources")
assert(I.Providers.entries[m.id].definition.title==(locale=="zhCN" and "团本首领" or "Raid bosses"))
local function query(q)
 local result
 local _,initial=I.Search.Query:Query(q,{visible=true},nil,function(rows)result=rows end)
 drain();return result or initial
end
local function find(rows,boss,spell)
 for _,r in ipairs(rows)do if r.payload and r.payload.encounterID==boss and r.payload.spellID==spell then return r end end
end
local list=query("Fire Nova")
local a=assert(find(list,11,101));assert(a.payload.difficultyID==14 and a.payload.sectionID==1001)
assert(find(list,11,103) and find(list,12,101),"same names do not erase separate spells/encounters")
local n=0;for _,r in ipairs(list)do if r.payload.encounterID==11 and r.payload.spellID==101 then n=n+1 end end;assert(n==1)
a=assert(find(query("史诗 Fire Nova"),11,101));assert(a.payload.difficultyID==16 and a.payload.sectionID==1002)
assert(not find(query("普通 Shadow Grip"),11,102));assert(find(query("mythic Shadow Grip"),11,102))
assert(find(query("Heroic Fury"),11,104),"difficulty-looking spell name must remain searchable")
assert(find(query("Heroic Resolve"),11,105),"literal spell name is not a heroic filter")
assert(find(query("heroic Alpha Boss"),11,0),"difficulty-filtered boss lookup")
local before=reads;query("Alpha Boss");assert(reads==before,"exact boss skips unrelated abilities")
missing[102]=true;local beforeRequests=requests;assert(find(query("Shadow Grip"),11,102));assert(requests>beforeRequests)
missing[102]=true;sync=true;assert(find(query("Shadow Grip"),11,102));sync=false
missing[102]=true;failed=true;assert(not find(query("Shadow Grip"),11,102));failed=false;missing[102]=nil
local called=false
I.Search.Query:Query("Fire Nova",{visible=true},nil,function()called=true end)
I.Providers:CancelQueries("cancelled-test");drain();assert(not called)
missing[102]=true;beforeRequests=requests
I.Search.Query:Query("Shadow Grip",{visible=true},nil,function()called=true end)
drain(function()return requests>beforeRequests end)
I.Providers:CancelQueries("cancelled-awaiting-load");drain();assert(not called,"late spell event cannot revive a query")
local callback=false
I.Search.Query:Query("Shadow Grip",{visible=true},nil,function()callback=true end)
assert(m.handle:SetAvailability(false));drain();assert(not callback)
assert(m.handle:SetAvailability(true));drain()
local currentDiff,opened
EncounterJournal={instanceID=0,encounterID=0,IsShown=function()return true end}
function EncounterJournal_OpenJournal(d,i,e,s)currentDiff=d;opened={d,i,e,s};EncounterJournal.instanceID=i;EncounterJournal.encounterID=e end
function EJ_GetDifficulty()return currentDiff end
C_EncounterJournal={GetSectionInfo=function(id)return {filteredByDifficulty=id==9999}end}
a=assert(find(query("Fire Nova"),11,101))
assert(m.actions.mythic.run(a).ok and opened[1]==16 and opened[4]==1002)
assert(m.actions.open.run(a).ok and opened[1]==14 and opened[4]==1001)
combat=true;assert(m.actions.open.run(a).code=="COMBAT_LOCKED");combat=false
assert(not m:ResolveReference("boss-11-spell-102-14"),"invalid difficulty cannot be restored")
assert(not m:ResolveReference("boss-89-spell-101-14"),"removed dungeon cannot be restored")
print("Raid abilities correctness PASS "..locale)
-- Fixed full-catalogue query scenario; generation data is restored intact.
I.Builtin.JournalCatalog=full
query("Ability 1229327")
collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
local started=os.clock()
for i=1,20 do query(i%2==0 and "Ability 1229327" or "mythic Ability 1230087") end
local allocated=collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-base
assert(allocated<8192,"20 raid queries allocation budget")
assert(retained<128,"raid query retained growth")
assert(maxBatch<8,"raid callback must stay below 8 ms")
print(string.format("Raid query20 PASS cpu_ms=%.2f allocated_KiB=%.1f retained_KiB=%.1f max_batch_ms=%.2f",(os.clock()-started)*1000,allocated,retained,maxBatch))
