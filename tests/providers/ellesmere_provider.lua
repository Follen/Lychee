local locale,combat="zhCN",false
local timers,calls={}, {load=0,open=0,unlock=0}
local virtual=0
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function debugprofilestop() return os.clock()*1000 end
function GetTime() return 100 end
function UnitGUID() return "Player-1-fixture" end
C_AddOns={GetAddOnInfo=function(name) if name=="EllesmereUI" then return name end end,
    GetAddOnEnableState=function() return 2 end}
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
dofile("tests/support/runtime.lua").Load("provider", {"Providers/Ellesmere/Locales/enUS.lua", "Providers/Ellesmere/Locales/zhCN.lua", "Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Providers/Ellesmere/Adapter.lua", "Providers/Ellesmere/Provider.lua"}, {overrides={ ["Providers/Ellesmere/Provider.lua"]=arg[1] }})
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.ProviderModules.Ellesmere
M:Init()
assert(M.active,"Ellesmere defaults enabled")
assert(M.handle:SetAvailability(true))
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
local function managedQuery(request,reply)
    local resources=assert(I.Resources:Create(function() return M.active end,nil,assert(M.handle:Resources())))
    local cancel=M:Query(request,function(rows) I.Resources:Close(resources,"complete");reply(rows) end,{resources=resources})
    return function() I.Resources:Close(resources,"cancelled");if cancel then cancel() end end
end
local function query(text)
    local raw,filter=I.Search.ProviderPolicy:Route(text)
    local result
    local cancel=managedQuery({normalized=I.Search.Normalizer:Normalize(raw),filter=filter,limit=20},function(rows) result=rows end)
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
local cancel=managedQuery({normalized="test",filter={sourceID=M.id..":records"}},function() replied=true end)
cancel();drain();assert(not replied and not M.cancel,"cancel releases work")
managedQuery({normalized="test",filter={sourceID=M.id..":records"}},function() replied=true end)
assert(M.handle:SetAvailability(false));drain();assert(not replied and not M.cancel)
assert(M.options==nil,"disabled collector releases callback references")
EllesmereUI._RegisterSearchEntry("Ignored",nil,nil,"Another","New Page")
assert(M.options==nil,"disabled hook short circuits")
assert(M.handle:SetAvailability(true))
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
local favoredID=rows[1].id
local favored
managedQuery({normalized="setting",limit=20,filter={sourceID=M.id..":records"},ranking={[favoredID]=30}},function(result)favored=result end)
drain();assert(#favored==20 and favored[1].id==favoredID,"EUI preference survives Top20 truncation")
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
assert(M.handle:SetAvailability(false))
assert(M.options==nil and not M.cancel and M.optionCount==0,"release full catalog")
-- Captured selectors belong to their upstream object, not just the stable label.
assert(M.handle:SetAvailability(true))
local oldOwner=EllesmereUI
local setterCalls=0
oldOwner._RegisterSearchEntry("Owner selector",nil,nil,"Module1","Setting 1 1","Appearance",function()setterCalls=setterCalls+1 end,"old")
local optionID,oldOption
for id,row in pairs(M.options) do if row.label=="Owner selector" then optionID=id;oldOption=M:Resolve(id) end end
assert(oldOption)
local nextOwner={}
for key,value in pairs(oldOwner) do nextOwner[key]=value end
nextOwner._RegisterSearchEntry=function()end
EllesmereUI=nextOwner
local previous=M.optionCount
oldOwner._RegisterSearchEntry("Late old owner",nil,nil,"Module1","Setting 1 1")
assert(M.optionCount==previous,"old hook rejects a replaced upstream immediately")
assert(not M:Resolve(optionID) and not definition.actions.open.run(oldOption).ok and setterCalls==0,"restore cannot revive an old selector")
nextOwner._RegisterSearchEntry("Owner selector",nil,nil,"Module1","Setting 1 1","Appearance",function()setterCalls=setterCalls+1 end,"fresh")
assert(M:Resolve(optionID) and definition.actions.open.run(M:Resolve(optionID)).ok and setterCalls==1)
local completed
managedQuery({normalized="setting",filter={sourceID=M.id..":records"}},function(result)completed=result end)
local first=table.remove(timers,1);assert(first and not first.cancelled);virtual=first.due;first.fn()
EllesmereUI=oldOwner
drain();assert(completed and #completed==1 and completed[1].id=="status","query cannot publish old-owner candidates after a yield")
assert(M.handle:SetAvailability(false))
print(string.format("Ellesmere PASS cold_fixture_ms=%.3f warm_1000_pages_ms=%.3f allocation_20_queries_KiB=%.1f retained_KiB=%.1f",coldMS,warmMS,allocated,retained))
