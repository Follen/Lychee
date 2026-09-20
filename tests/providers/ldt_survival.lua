LycheeInternal={ProviderModules={LDT={}}}
dofile("addon/Lychee/Providers/LDT/Survival.lua")
local S=LycheeInternal.ProviderModules.LDT.Survival
local function near(a,b) assert(math.abs(a-b)<.001,tostring(a).." ~= "..tostring(b)) end
local stats={valid=true,health=1000000,vers=.2,versDR=.1,avoidance=.2,armorDR=.3,active={},passives={},season=0,spec=70}
local input={confirmed=true,first=600000,tick=120000,ticks=6,level=1,boss=true,firstSchool="magic",tickSchool="magic",aoe=true}
local selected,out={},{}
S:Calculate(stats,input,selected,out)
near(out.first,360000);assert(out.status=="survives" and not out.total)
input.first=2400000;S:Calculate(stats,input,selected,out);assert(out.status=="lethal")
input.first=600000;input.ticks=100000;S:Calculate(stats,input,selected,out)
near(out.first,360000);assert(out.status=="survives","periodic damage never affects direct survival")
input.firstSchool="physical";S:Calculate(stats,input,selected,out);near(out.first,252000)
input.firstSchool="bleed";S:Calculate(stats,input,selected,out);near(out.first,360000)
input.firstSchool="magic";selected[357170]=true;S:Calculate(stats,input,selected,out);near(out.first,180000)
selected[357170]=nil;selected[48707]=true;S:Calculate(stats,input,selected,out);near(out.first,0)
selected={};stats.passives[402964]=2;stats.spec=65
S:Calculate(stats,input,selected,out);near(out.first,349200)
input.firstSchool="physical";S:Calculate(stats,input,selected,out);near(out.first,244440)
input.aoe=false;S:Calculate(stats,input,selected,out);near(out.first,315000)
input.aoe=true;stats.passives[402964]=1;S:Calculate(stats,input,selected,out);near(out.first,248220)
stats.passives={};input.firstSchool=nil;S:Calculate(stats,input,selected,out);assert(out.status=="unknown")
input.first=0;S:Calculate(stats,input,selected,out);assert(out.status=="noDirect" and not out.first)
local p=S:Parse("对所有玩家造成600,000点火焰伤害，并且每2秒造成120,000点火焰伤害，持续12秒。")
assert(p.damageValid and p.first==600000 and p.firstSchool=="magic" and p.aoe)
p=S:Parse("Inflicts 600,000 Physical damage to all players, then 120,000 Fire damage every 2 sec for 12 sec.")
assert(p.damageValid and p.first==600000 and p.firstSchool=="physical" and p.aoe)
assert(not S:Parse("恢复100000点生命值，持续10秒").damageValid)
assert(not S:Parse("造成100000点伤害").damageValid)
assert(not S:Parse("造成100000点火焰伤害，然后造成200000点冰霜伤害").damageValid)
input.first=600000;input.firstSchool="magic"
p=S:Parse("每1秒造成120000点火焰伤害。")
p.confirmed=p.damageValid;p.level=1
S:Calculate(stats,p,{},out);assert(out.status=="noDirect")
stats.flaskVers=.04;stats.flaskDR=.02
S:Calculate(stats,input,{[1235057]=true},out);near(out.first,352000)
stats.active[1235057]=true;S:Calculate(stats,input,{[1235057]=true},out);near(out.first,360000)
stats.active[1235057]=nil;stats.flaskDR=nil
S:Calculate(stats,input,{[1235057]=true},out);assert(out.status=="unknown","missing rating conversion cannot claim safety")
-- Snapshot uses only current class/spec/known spells and never duplicates stat passives.
function UnitHealthMax() return 1000000 end
function UnitArmor() return 0,1000 end
function GetCombatRatingBonus() return 10 end
function GetVersatilityBonus() return 0 end
function GetAvoidance() return 5 end
function UnitClass() return "Paladin","PALADIN" end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 65 end
C_PaperDollInfo={GetArmorEffectiveness=function() return .2 end}
C_SeasonInfo={GetCurrentDisplaySeasonID=function() return 34 end}
C_SpellBook={IsSpellKnown=function(id) return id==402964 or id==454842 end}
C_UnitAuras={GetPlayerAuraBySpellID=function(id) if id==465 then return {} end end}
local snap=S:Snapshot();assert(not snap.valid and not snap.passives[402964] and not snap.passives[454842] and snap.active[465])
C_ClassTalents={GetActiveConfigID=function() return 1 end}
C_Traits={GetConfigInfo=function() return {treeIDs={2}} end,GetTreeNodes=function() return {3,4} end,
    GetNodeInfo=function(_,id) return {activeEntry={entryID=id,rank=id==3 and 1 or 2}} end,
    GetEntryInfo=function(_,id) return {definitionID=id} end,
    GetDefinitionInfo=function(id) return {spellID=id==3 and 385427 or 454842} end}
C_SpellBook.IsSpellKnown=function(id) return id==385427 or id==402964 end
snap=S:Snapshot(snap);assert(snap.passives[385427]==1 and not snap.passives[454842],"selected rank and learned hero/class spell gate")
local reads=0
C_Traits.GetTreeNodes=function() local ids={};for i=1,600 do ids[i]=i end;return ids end
C_Traits.GetNodeInfo=function() reads=reads+1;return {} end
S:Snapshot(snap);assert(reads==512 and not snap.valid,"talent overflow is not a partial successful snapshot")
function issecretvalue(v) return v=="secret" end
function UnitHealthMax() return "secret" end
assert(not S:Snapshot(snap).valid)
function InCombatLockdown() return true end
assert(not S:Snapshot(snap).valid)
-- Reused result stays bounded; no timer, frame, catalogue or per-query cache.
collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
local start=os.clock()
for i=1,1000 do S:Calculate(stats,input,selected,out) end
local allocated=collectgarbage("count")-base;local elapsed=(os.clock()-start)*1000
assert(elapsed<1000,"average direct-hit computation stays below 1 ms")
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-base
assert(retained<4,"retained result must not grow across calculations")
print(string.format("LDT survival PASS: 1000 calculations %.2f ms, allocated %.2f KiB, retained %.2f KiB",elapsed,allocated,retained))
