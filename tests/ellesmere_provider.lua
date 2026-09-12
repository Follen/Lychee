local locale,combat="zhCN",false
local timers,calls={}, {load=0,open=0,unlock=0}
local virtual=0
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function debugprofilestop() return os.clock()*1000 end
function GetTime() return 100 end
local hookCount=0
function hooksecurefunc(owner,name,callback)
    hookCount=hookCount+1
    local original=owner[name]
    owner[name]=function(...) original(...);callback(...) end
end
function CreateFrame()
    return {SetScript=function() end,Hide=function() end,Show=function() end,RegisterEvent=function() end}
end
C_Timer={NewTimer=function(delay,fn)
    local timer={fn=fn,due=virtual+delay};function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer;return timer
end}
local function drain()
    local count=0
    while #timers>0 do
        count=count+1;assert(count<10000,"runaway timers")
        table.sort(timers,function(a,b) return a.due<b.due end)
        local timer=table.remove(timers,1)
        if not timer.cancelled then virtual=timer.due;timer.fn() end
    end
end
for _,file in ipairs({"Bootstrap.lua", "Core/CharacterStore.lua","Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua",
    "Builtin/Ellesmere/Locales.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
    "Search/ProviderPolicy.lua","Search/Storage.lua", "Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua",
    "Core/IntentRouter.lua","Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua",
    "Core/ProviderRuntime.lua","PublicAPI/SDK.lua","Builtin/Ellesmere/Adapter.lua","Builtin/Ellesmere/Provider.lua"}) do
    dofile(file=="Builtin/Ellesmere/Provider.lua" and arg[1] or "package/Lychee/"..file)
end
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.Builtin.Ellesmere
M:Init()
assert(M.active,"Ellesmere defaults enabled")
assert(I.Registry:SetUserEnabled(M.id,true))
assert(M.active and #timers==0,"enable without loading or polling")
local definition=I.Providers.entries[M.id].definition
assert(#definition.scope.products==1 and definition.scope.products[1]=="retail")
assert(not definition.searchGlobal and definition.searchPrefixes[1]=="eui")
local translate={HoverCast="悬停施法",["Raid Frames"]="团队框体",Frames="框体",Buffs="增益"}
EllesmereUI={_modules={},TAB_LABEL_OVERRIDES={["Buff Manager"]="Buffs"},L=function(s) return locale=="zhCN" and translate[s] or s end}
EllesmereUI._RegisterSearchEntry=function() end
function EllesmereUI:EnsureLoaded()
    if self._deferredLoaded then return end
    calls.load=calls.load+1
    self._deferredLoaded=true
    self._modules.EllesmereUIRaidFrames={title="Raid Frames",pages={"Frames","HoverCast","Buff Manager"},
        buildPage=function() error("must not build settings pages") end}
end
function EllesmereUI:NavigateToElementSettings(folder,page,section,preSelect,label)
    calls.open=calls.open+1;calls.folder,calls.page=folder,page
    calls.section,calls.label=section,label
    if preSelect then preSelect() end
end
function EllesmereUI:EnsureUnlockCore() end
function EllesmereUI:OpenUnlockMode()
    if self._unlockActive then return end
    self._unlockActive=true;calls.unlock=calls.unlock+1
end
local function query(text)
    local raw,filter=I.Search.ProviderPolicy:Route(text)
    local result
    local cancel=M:Query({normalized=I.Search.Normalizer:Normalize(raw),filter=filter,limit=20},function(rows) result=rows end)
    drain();assert(result,"query did not finish");return result,cancel
end
assert(#query("悬停施法")==0 and calls.load==0,"no global query")
local rows=query("EUI：解锁")
assert(#rows==1 and rows[1].id=="unlock" and calls.load==0,"unlock avoids options loading")
local firstStart=os.clock()
rows=query("EUI：悬停施法")
local coldMS=(os.clock()-firstStart)*1000
assert(#rows==1 and rows[1].payload.page=="HoverCast" and calls.load==1)
local hover=rows[1]
assert(definition.actions.open.run(hover).ok and calls.page=="HoverCast")
assert(definition.actions.unlock.run(rows[1]).ok)
assert(definition.actions.unlock.run(rows[1]).ok and calls.unlock==1,"unlock is idempotent")
assert(query("eui:HoverCast")[1].id==hover.id,"English alias")
assert(query("eui:团队 悬停")[1].id==hover.id,"multiword across module/page")
assert(query("EUI：增益")[1].payload.page=="Buff Manager","tab display override")
assert(M:Resolve(hover.id).payload.page=="HoverCast")
local selected
EllesmereUI._RegisterSearchEntry(" Border Style ","边框样式",function() error("dynamic tooltip") end,
    "EllesmereUIRaidFrames","Frames","Appearance",function(key) selected=key end,"party")
EllesmereUI._RegisterSearchEntry("Border Style","另一译名",nil,"EllesmereUIRaidFrames","Frames","Wrong")
EllesmereUI._searchIndexSuppress=true
EllesmereUI._RegisterSearchEntry("Excluded","排除",nil,"EllesmereUIRaidFrames","Frames","Macro Factory")
EllesmereUI._searchIndexSuppress=nil
assert(M.optionCount==1 and #query("eui:排除")==0,"suppression and dedup")
local option=query("eui:边框样式")[1]
assert(option and not option.description and definition.actions.open.run(option).ok)
assert(calls.section=="Appearance" and calls.label=="Border Style" and selected=="party","precise selector navigation")
EllesmereUI._modules.EllesmereUIRaidFrames.pages={"Frames"}
assert(#query("eui:HoverCast")==0 and not M:Resolve(hover.id),"removed page disappears")
assert(not definition.actions.open.run(hover).ok,"stale action rejected")
EllesmereUI._modules.Another={title="Dynamic",pages={"New Page"}}
assert(query("eui:New Page")[1].payload.page=="New Page","new module visible")
local dynamic=query("eui:New Page")[1]
locale="enUS"
assert(M:Resolve(dynamic.id).title=="New Page","locale-independent identity")
locale="zhCN"
combat=true
assert(query("eui:test")[1].id=="status")
assert(not definition.actions.open.run(dynamic).ok and not definition.actions.unlock.run(dynamic).ok)
combat=false
local oldEUI=EllesmereUI;EllesmereUI=nil
assert(query("eui:test")[1].title=="请先启用 Ellesmere UI")
EllesmereUI=oldEUI
local replied=false
local cancel=M:Query({normalized="test",filter={sourceID=M.id..":records"}},function() replied=true end)
cancel();drain();assert(not replied and not M.cancel,"cancel releases work")
M:Query({normalized="test",filter={sourceID=M.id..":records"}},function() replied=true end)
assert(I.Registry:SetUserEnabled(M.id,false));drain();assert(not replied and not M.cancel)
assert(M.options==nil,"disabled collector releases callback references")
EllesmereUI._RegisterSearchEntry("Ignored",nil,nil,"Another","New Page")
assert(M.options==nil,"disabled hook short circuits")
assert(I.Registry:SetUserEnabled(M.id,true))
assert(hookCount==1,"re-enable must not duplicate hook")
-- Real Host orchestration, not just direct Provider calls: no leakage to global.
local function hostQuery(text)
    local delivered
    local _,items=I.Search.Query:Query(text,{visible=true},nil,function(results) delivered=results end)
    drain();return delivered or items
end
assert(#hostQuery("New Page")==0)
local found=false
for _,item in ipairs(hostQuery("EUI：New Page")) do if item.providerID==M.id and item.id==dynamic.id then found=true end end
assert(found,"Host prefix orchestration")
-- 1,000 dynamic pages; a match late in traversal must survive top-K selection.
I.Providers:CancelQueries("performance")
EllesmereUI._modules={}
for m=1,10 do
    local config={title="Module"..m,pages={}}
    for p=1,100 do config.pages[p]="Setting "..m.." "..p end
    EllesmereUI._modules["Module"..m]=config
end
local start=os.clock();rows=query("eui:Setting 10 100");local warmMS=(os.clock()-start)*1000
assert(rows[1].title=="Setting 10 100")
collectgarbage("collect");local base=collectgarbage("count")
collectgarbage("stop")
for i=1,20 do query("eui:Setting 10 100") end
local allocated=collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect")
local retained=collectgarbage("count")-base
assert(allocated<40960,"query allocation budget")
assert(retained<256 and not M.cancel and #timers==0,"bounded retention and no idle timers")
for index=1,4100 do EllesmereUI._RegisterSearchEntry("Captured "..index,nil,nil,"Module1","Setting 1 1","Appearance") end
assert(M.optionCount==4096 and M.overflow and M.optionBytes<=2097152,"bounded observed catalog")
assert(I.Registry:SetUserEnabled(M.id,false))
assert(M.options==nil and not M.cancel and M.optionCount==0,"release full catalog")
print(string.format("Ellesmere PASS cold_fixture_ms=%.3f warm_1000_pages_ms=%.3f allocation_20_queries_KiB=%.1f retained_KiB=%.1f",coldMS,warmMS,allocated,retained))
