-- Measures TOC execution separately from login, provider activation and UI creation.
local product=arg[1] or "Mainline"
local runtimeRoot=arg[2] or "addon/Lychee"
local measureOnly=arg[3]=="--measure"
local baselineOnly=arg[3]=="--baseline"
local frames,events=0,0
local eventNames={}
local methods={}
function methods:RegisterEvent(name) events=events+1;eventNames[name]=(eventNames[name] or 0)+1 end
function methods:UnregisterAllEvents() end
function methods:SetScript(key,fn) self[key]=fn end
function CreateFrame() frames=frames+1;return setmetatable({},{__index=methods}) end
function InCombatLockdown() return false end
function GetLocale() return arg[4] or "enUS" end
function GetBuildInfo() return "fixture","69587","",120100 end
WOW_PROJECT_ID=1
local paths={}
for line in io.lines(runtimeRoot.."/Lychee_"..product..".toc") do
    line=line:gsub("\r$","")
    if line~="" and line:sub(1,1)~="#" and not (baselineOnly and line:find("Providers/LDT/",1,true)) then paths[#paths+1]=line end
end
collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
local started=os.clock()
local measurements={}
for _,path in ipairs(paths) do
    local before=collectgarbage("count")
    dofile(runtimeRoot.."/"..path)
    measurements[#measurements+1]={path=path,kib=collectgarbage("count")-before}
end
local elapsed=(os.clock()-started)*1000
local allocated=collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect")
local retained=collectgarbage("count")-base
assert(not (LycheeInternal.Host and LycheeInternal.Host.PaletteController),"TOC execution must not create the search UI")
assert(frames<=2 and events==4,"TOC execution creates only bounded Host infrastructure")
local hostEvents={PLAYER_LOGIN=true,PLAYER_LOGOUT=true,PLAYER_REGEN_DISABLED=true,PLAYER_REGEN_ENABLED=true}
for name,count in pairs(eventNames) do assert(hostEvents[name] and count==1,"unexpected eager subscription: "..name) end
-- Historical memory references are reviewed under PERFORMANCE.md; lifecycle
-- ownership, object counts and CPU limits remain mandatory.
local creature=LycheeInternal.ProviderModules.LDT~=nil
local raid=LycheeInternal.ProviderModules.JournalCatalog and LycheeInternal.ProviderModules.JournalCatalog.abilities~=nil
if not measureOnly then
    assert(elapsed<(creature and 61 or 46),"loading stays below the declared CPU budget")
end
print(string.format("MEMORY REVIEW: retained %.1f KiB; historical reference %d KiB; requires Agent attribution and runtime verification",retained,creature and 1858 or raid and 1474 or 1346))
table.sort(measurements,function(a,b) return a.kib>b.kib end)
print(string.format("TOC loading files=%d cpu_ms=%.2f allocated_KiB=%.1f retained_KiB=%.1f frames=%d events=%d",#paths,elapsed,allocated,retained,frames,events))
for i=1,math.min(8,#measurements) do print(string.format("  %.1f KiB %s",measurements[i].kib,measurements[i].path)) end
