local locale,combat="zhCN",false
local virtual,frames=0,0
local timers,calls={},{}
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function debugprofilestop() return os.clock()*1000 end
function GetTime() return 100 end
function hooksecurefunc() error("Exwind adapter must not install hooks") end
function CreateFrame()
    frames=frames+1
    return {SetScript=function() end,Hide=function() end,Show=function() end,RegisterEvent=function() end}
end
C_Timer={NewTimer=function(delay,fn)
    local timer={due=virtual+delay,fn=fn};function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer;return timer
end}
local function drain()
    local count=0
    while #timers>0 do
        count=count+1;assert(count<10000,"runaway work")
        table.sort(timers,function(a,b) return a.due<b.due end)
        local timer=table.remove(timers,1)
        if not timer.cancelled then virtual=timer.due;timer.fn() end
    end
end
for _,file in ipairs({"Bootstrap.lua","Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua",
    "Builtin/Exwind/Locales.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
    "Search/ProviderPolicy.lua","Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua",
    "Core/IntentRouter.lua","Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua",
    "Core/ProviderRuntime.lua","PublicAPI/SDK.lua","Builtin/Exwind/Provider.lua"}) do dofile("package/Lychee/"..file) end
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.Builtin.Exwind
local baseFrames=frames
M:Init()
assert(not M.active and #timers==0 and frames==baseFrames)
assert(I.Registry:SetUserEnabled(M.id,true))
assert(M.active and #timers==0 and frames==baseFrames)
local definition=I.Providers.entries[M.id].definition
assert(#definition.scope.products==1 and definition.scope.products[1]=="retail")
assert(definition.searchGlobal==false and definition.searchPrefixes[1]=="ex")
local function query(input)
    local result
    local _,initial=I.Search.Query:Query(input,{visible=true},nil,function(rows) result=rows end)
    drain()
    local records={}
    for _,item in ipairs(result or initial) do
        assert(item.providerID==M.id)
        records[#records+1]=assert(I.Providers.entries[M.id].dynamic[item.id])
    end
    return records
end
assert(#query("自动修理")==0,"no global results")
assert(query("ex：test")[1].title=="请先启用 Exwind Core")
local shell={Providers={tools={ApplyRoute=function() end},boss={ApplyRoute=function() end},settings={ApplyRoute=function() end}},
    ProviderMeta={tools={title="EXWINDTOOLS"},boss={title="EXBOSS"},settings={title="SETTINGS"}},
    Frame={IsShown=function() return calls.shown end}}
function shell:Show(id,route) calls.shown=true;calls.provider=id;calls.route=route end
function shell:Hide() calls.shown=false end
local ui={EditModeState={modules={},routers={EXBoss=function() end}}}
function ui:OpenModuleSettings(addon,page) calls.addon=addon;calls.page=page;shell:Show("boss",{tab=page}) end
function ui:IsEditModeActive() return calls.edit==true end
function ui:ToggleEditMode(value) assert(value==true);calls.edit=true;calls.entered=(calls.entered or 0)+1 end
local forbidden=function() error("settings callback must not execute in search") end
ExwindTools={UnifiedPanel=shell,UI=ui,ModuleList={{Key="ExTools.MiniTools",Name="常用功能设置"},
    {Key="Hidden",Name="秘密模块",HideCfg=true},{Key="Dynamic",Name="动态布局"}},
    L=setmetatable({},{__index=function(_,key) return key end}),ModuleDefinitions={},RegisteredLayouts={
        ["ExTools.MiniTools"]={{key="Repair",type="checkbox",label="|cff00ff00自动修理|r",set=forbidden,get=forbidden},
            {label="隐藏文字",hidden=true},{label="条件隐藏",hidden=forbidden},
            {label="嵌套",children={{label="目标延迟",type="slider"}}},
            {label="动态文字",type="description"},{label="危险动作",type="button",onClick=forbidden}},
        Dynamic=forbidden}}
ui.EditModeState.modules.bar={addon="EXBoss",key="timerbar",name="计时条",settingsPage="timerbar",BuildPreview=forbidden}
ui.EditModeState.modules.unknown={addon="Unknown",key="ignored",name="不可路由",settingsPage="ignored"}
ExBoss={ModuleList={{Key="ExBoss.Tools.MythicCast",Name="大米怪物施法",PanelTab="mythiccast"}}}
local id
for _,prefix in ipairs({"ex:","Ex:","EX:","ex：","Ex：","EX："}) do
    local rows=query(prefix.."自动修理")
    assert(#rows==1 and rows[1].title=="常用功能设置" and rows[1].subtitle:find("自动修理",1,true))
    id=id or rows[1].id;assert(rows[1].id==id,"prefix casing and width")
end
assert(#query("自动修理")==0)
for _,word in ipairs({"秘密模块","隐藏文字","条件隐藏","动态文字","危险动作","不可路由"}) do assert(#query("ex:"..word)==0,word) end
assert(query("ex:目标延迟")[1].id==id,"nested static layout")
assert(definition.actions.open.run({id=id}).ok and calls.provider=="tools" and calls.route.moduleKey=="ExTools.MiniTools")
local bar=query("ex:计时条")[1]
assert(bar and definition.actions.open.run(bar).ok and calls.addon=="EXBoss" and calls.page=="timerbar")
local boss=query("ex:大米怪物施法")[1]
assert(boss and definition.actions.open.run(boss).ok and calls.route.tab=="mythiccast")
local unlockRow=query("EX：解锁")[1]
assert(unlockRow and unlockRow.id=="unlock")
assert(definition.actions.unlock.run(unlockRow).ok and not calls.shown)
assert(definition.actions.unlock.run(unlockRow).ok and calls.entered==1)
assert(query("EX:unlock")[1].id=="unlock")
ExwindTools.ModuleList[#ExwindTools.ModuleList+1]={Key="New",Name="新增功能"}
ExwindTools.ModuleDefinitions.New={definition={settings={layout={{label="新声明字段",type="checkbox"}}}}}
assert(query("ex:新声明字段")[1].title=="新增功能")
assert(#query("ex:动态布局")==1,"function layout module remains searchable without invoking builder")
table.remove(ExwindTools.ModuleList,1)
assert(not M:Resolve(id) and not definition.actions.open.run({id=id}).ok,"stale destination")
ui.EditModeState.modules.bar=nil
assert(not M:Resolve(bar.id),"removed edit module")
combat=true
assert(query("ex:test")[1].title=="请先脱离战斗")
assert(not definition.actions.unlock.run(unlockRow).ok and not definition.actions.open.run(boss).ok)
combat=false
local replied=false
local cancel=M:Query({normalized="x",filter={sourceID=M.id..":records"}},function() replied=true end)
cancel();drain();assert(not replied and not M.cancel)
M:Query({normalized="x",filter={sourceID=M.id..":records"}},function() replied=true end)
assert(I.Registry:SetUserEnabled(M.id,false));drain();assert(not replied and not M.cancel)
assert(I.Registry:SetUserEnabled(M.id,true))
-- One hundred modules, ten actual static settings each. No UI/callback work.
I.Providers:CancelQueries("performance")
ExwindTools.ModuleList={};ExwindTools.RegisteredLayouts={};ExwindTools.ModuleDefinitions={};ExBoss.ModuleList={}
for module=1,100 do
    local key="Module"..module
    ExwindTools.ModuleList[module]={Key=key,Name="Module "..module}
    local layout={}
    for field=1,10 do layout[field]={label="Setting "..module.." "..field,type="checkbox",set=forbidden} end
    ExwindTools.RegisteredLayouts[key]=layout
end
local function measured()
    local result
    M:Query({normalized="setting 100 10",limit=20,filter={sourceID=M.id..":records"}},function(rows) result=rows end)
    drain();assert(result and result[1].title=="Module 100")
end
local start=os.clock();measured();local coldMS=(os.clock()-start)*1000
collectgarbage("collect");local base=collectgarbage("count")
collectgarbage("stop");start=os.clock()
for i=1,20 do measured() end
local elapsed=(os.clock()-start)*1000
local allocated=collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect")
local retained=collectgarbage("count")-base
assert(allocated<16384 and retained<256 and #timers==0 and not M.cancel and frames==baseFrames)
local cycle={};cycle[1]={children=cycle}
ExwindTools.RegisteredLayouts.Module1=cycle
measured()
ExwindTools.ModuleList={}
for i=1,513 do ExwindTools.ModuleList[i]={Key="M"..i,Name="M"..i} end
local overflow=query("ex:x")
assert(overflow[1].title=="Exwind 设置目录超出限制")
print(string.format("Exwind PASS cold_1000_settings_ms=%.3f warm20_ms=%.3f alloc20_KiB=%.1f retained_KiB=%.1f frames_added=%d",coldMS,elapsed,allocated,retained,frames-baseFrames))
