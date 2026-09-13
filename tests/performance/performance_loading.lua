-- Measures TOC execution separately from login, provider activation and UI creation.
local product=arg[1] or "Mainline"
local runtimeRoot=arg[2] or "addon/Lychee"
local measureOnly=arg[3]=="--measure" or arg[4]=="--measure"
local baselineOnly=arg[3]=="--baseline"
local frames,events=0,0
local methods={}
function methods:RegisterEvent() events=events+1 end
function methods:UnregisterAllEvents() end
function methods:UnregisterEvent() end
function methods:SetScript(key,fn) self[key]=fn end
function CreateFrame() frames=frames+1;return setmetatable({},{__index=methods}) end
function InCombatLockdown() return false end
function GetLocale() return "enUS" end
function GetBuildInfo() return "fixture","69587","",120100 end
WOW_PROJECT_ID=1
local paths,namespaces={},{}
local root=runtimeRoot:gsub("Lychee$","")
for _,name in ipairs({"Lychee","Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"}) do
 namespaces[name]={}
 for line in io.lines(root..name.."/"..name.."_"..product..".toc") do
  line=line:gsub("\r$","")
  if line~="" and line:sub(1,1)~="#" and not (baselineOnly and line:find("LDT/",1,true)) then paths[#paths+1]={name=name,path=line} end
 end
end
collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
local started=os.clock()
local measurements={}
for _,path in ipairs(paths) do
    local before=collectgarbage("count")
    assert(loadfile(root..path.name.."/"..path.path))(path.name,namespaces[path.name])
    measurements[#measurements+1]={path=path.name.."/"..path.path,kib=collectgarbage("count")-before}
end
local elapsed=(os.clock()-started)*1000
local allocated=collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect")
local retained=collectgarbage("count")-base
assert(not (LycheeInternal.Host and LycheeInternal.Host.PaletteController),"TOC execution must not create the search UI")
assert(frames<=2 and events<=4,"TOC execution adds no eager feature UI or subscriptions")
-- Retained component definitions + presence channel may add at most 64 KiB to
-- the previous 1282 KiB ceiling; startup allocation savings are measured apart.
local creature=namespaces.Lychee_Encounters.Modules and namespaces.Lychee_Encounters.Modules.LDT~=nil
-- The new captured raid ability relationships have a separate 128 KiB allowance.
-- Full retail loading retains its existing 1858 KiB ceiling (not an additive bump).
local raid=namespaces.Lychee_Encounters.Modules.JournalCatalog and namespaces.Lychee_Encounters.Modules.JournalCatalog.abilities~=nil
print(string.format("TOC loading files=%d cpu_ms=%.2f allocated_KiB=%.4f retained_KiB=%.4f frames=%d events=%d",#paths,elapsed,allocated,retained,frames,events))
if not measureOnly then
    assert(retained<(creature and 1858 or raid and 1974 or 1346) and elapsed<(creature and 61 or 46),"loading stays below the declared memory/time budgets")
end
table.sort(measurements,function(a,b) return a.kib>b.kib end)
for i=1,math.min(8,#measurements) do print(string.format("  %.1f KiB %s",measurements[i].kib,measurements[i].path)) end
