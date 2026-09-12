local file=assert(io.open("tests/performance_startup.lua","rb"));local source=file:read("*a");file:close()
assert(loadstring(source:sub(1,assert(source:find("local I = LycheeInternal",1,true))-1)))()
LycheeInternal.Builtin:Init();LycheeInternal.Registry:SetReady(true)
local virtual=0
function debugprofilestop() return os.clock()*1000+virtual end
function GetTime() return debugprofilestop()/1000 end
local serial=100
function time() return serial end
function UnitGUID() return "fixture-player" end
LycheeDevDB=nil
SlashCmdList={}
LycheePerformanceTestDB={schemaVersion=1,reports={}}
local tasks={}
C_Timer={NewTimer=function(delay,fn)
    local t={due=debugprofilestop()+delay*1000,fn=fn};function t:Cancel() self.cancelled=true end
    tasks[#tasks+1]=t;return t
end}
local nativeCalls,externalCalls=0,0
local overlayFrames,overlayFonts=0,0
STANDARD_TEXT_FONT="fixture-font"
CreateFrame=function(_,name,parent)
    if name=="LycheePerformanceTestStatus" then
        overlayFrames=overlayFrames+1
        local frame={parent=parent}
        function frame:SetSize(w,h) self.width=w;self.height=h end
        function frame:SetPoint(...) self.point={...} end
        function frame:SetFrameStrata(v) self.strata=v end
        function frame:EnableMouse(v) self.mouse=v end
        function frame:Show() self.shown=true end
        function frame:CreateFontString()
            overlayFonts=overlayFonts+1
            local label={}
            function label:SetFont(...) self.font={...};return true end
            function label:SetTextColor(...) self.color={...} end
            function label:SetPoint(...) self.point={...} end
            function label:SetText(v) self.text=v end
            return label
        end
        return frame
    end
    nativeCalls=nativeCalls+1;error("native frame in private probe")
end
local function external() externalCalls=externalCalls+1;error("external business action") end
EllesmereUI={_modules={Unit={title="Unit",pages={"冷却","框体"}}},_deferredLoaded=true,
    L=function(s) return s end,_RegisterSearchEntry=external,EnsureLoaded=external,NavigateToElementSettings=external}
ExwindTools={UnifiedPanel={Providers={tools={title="工具",ApplyRoute=external}},ProviderMeta={},Show=external},
    ModuleList={{Key="Tools",Name="冷却工具"}},RegisteredLayouts={Tools={{type="checkbox",label="冷却文字"}}},
    UI={EditModeState={modules={},routers={}}}}
local realI,realIndex=LycheeInternal,LycheeInternal.Search.StaticIndex
local originalGetMounts=C_MountJournal.GetMountIDs
local originalInfo=C_MountJournal.GetMountInfoByID
ColorMixin={}
C_ClassColor={GetClassColor=function() return {r=1,g=0.5,b=0.25} end}
C_ChallengeMode=C_ChallengeMode or {}
C_ChallengeMode.GetDungeonScoreRarityColor=function() return {r=1,g=0.5,b=0.25} end
C_ChallengeMode.GetSpecificDungeonScoreRarityColor=function() return {r=0.5,g=1,b=0.25} end
local nativeClassColor=C_ClassColor.GetClassColor
local carrier={}
local packagePath="analyze/performance-test-package/Lychee Performance Test/"
for line in io.lines(packagePath.."Lychee Performance Test.toc") do
    if line:match("%.lua$") then assert(loadfile(packagePath..line))("Lychee Performance Test",carrier) end
end
assert(#carrier.modules==57 and #tasks==0 and nativeCalls==0 and overlayFrames==0)
assert(next(LycheePerformanceTestDB.reports)==nil and LycheeDevDB==nil)
local script=LycheePerformanceTest.Start
local function checkFactories()
    for _,file in ipairs(carrier.modules) do assert(getfenv(file[2])==_G,"factory retains private environment") end
end
checkFactories()
local returned=script();assert(returned.status=="running",returned.reason)
assert(carrier.statusFrame.title.text=="正在执行中…" and overlayFrames==1 and overlayFonts==2)
assert(carrier.statusFrame.mouse==false and carrier.statusFrame.strata=="TOOLTIP")
assert(carrier.statusFrame.title.font[2]==42 and carrier.statusFrame.title.color[1]==1)
assert(script().status=="blocked" and carrier.statusFrame.title.text=="正在执行中…")
local steps=0
while #tasks>0 do
    steps=steps+1;assert(steps<20000,"real timer runaway")
    table.sort(tasks,function(a,b) return a.due<b.due end)
    local t=table.remove(tasks,1)
    virtual=virtual+math.max(0,t.due-debugprofilestop())
    if not t.cancelled then t.fn() end
end
local report=LycheePerformanceTestDB.reports[returned.studyID]
print("STATUS",report.status,report.lastPhase,report.error,report.cleanupError)
assert(report.status=="complete",report.error or report.cleanupError)
assert(carrier.statusFrame.title.text=="执行完毕，可落盘")
assert(report.cleanupOK and report.liveRootsUnchanged and #report.rounds==4)
assert(nativeCalls==0 and externalCalls==0)
assert(LycheeInternal==realI and realI.Search.StaticIndex==realIndex)
assert(C_MountJournal.GetMountIDs==originalGetMounts and C_MountJournal.GetMountInfoByID==originalInfo,"real API was patched")
for _,id in ipairs({"builtin.exwind","builtin.ellesmere"}) do local v=report.rounds[1].providers[id];print(id,v.available,v.initializationOK,v.registered,v.error,v.providerError) end
print("queries",report.rounds[1].queries["ex:"].count,report.rounds[1].queries["eui:"].count)
assert(report.rounds[1].queries["ex:"].count>0 and report.rounds[1].queries["eui:"].count>0)
assert(report.rounds[2].recordsEqual and report.rounds[2].queryOrderEqual)
assert(report.rounds[1].queries["ex:"].resolved and report.rounds[1].queries["eui:"].resolved)
assert(report.rounds[4].cancelledQueryNoLateReply)
assert(not LycheePerformanceTestControl)
serial=serial+1
returned=script();assert(returned.status=="running");LycheePerformanceTestControl:Cancel()
assert(LycheePerformanceTestDB.reports[returned.studyID].status=="cancelled" and not LycheePerformanceTestControl)
assert(carrier.statusFrame.title.text=="执行已取消，可落盘")
local function drainReal(limit)
    local steps=0
    while #tasks>0 do
        steps=steps+1;assert(steps<(limit or 20000))
        table.sort(tasks,function(a,b) return a.due<b.due end)
        local t=table.remove(tasks,1);virtual=virtual+math.max(0,t.due-debugprofilestop())
        if not t.cancelled then t.fn() end
    end
end
drainReal()
serial=serial+1;returned=script()
-- Interrupt after private instances have been created, not only before start.
while LycheePerformanceTestControl and LycheePerformanceTestControl.report.rounds[1]==nil do
    table.sort(tasks,function(a,b) return a.due<b.due end)
    local t=table.remove(tasks,1);assert(t);virtual=virtual+math.max(0,t.due-debugprofilestop());if not t.cancelled then t.fn() end
end
LycheePerformanceTestControl:Cancel();drainReal()
assert(LycheePerformanceTestDB.reports[returned.studyID].cleanupOK and not LycheePerformanceTestControl)
serial=serial+1;returned=script();virtual=virtual+180001
local pending=table.remove(tasks,1);assert(pending and not pending.cancelled);pending.fn()
assert(LycheePerformanceTestControl and LycheePerformanceTestControl.report.status=="running","old 180s limit still active")
assert(LycheePerformanceTestControl.report.wallLimitSeconds==600)
virtual=virtual+420001;drainReal()
assert(carrier.statusFrame.title.text=="执行超时，可落盘")
local expired=LycheePerformanceTestDB.reports[returned.studyID]
assert(expired.status=="aborted" and expired.error=="600 second wall limit")
assert(expired.cleanupOK and not LycheePerformanceTestControl and #tasks==0)
serial=serial+1
local originalEUI,originalEx=EllesmereUI,ExwindTools
EllesmereUI=nil;ExwindTools=nil;returned=script();drainReal()
report=LycheePerformanceTestDB.reports[returned.studyID]
assert(report.status=="complete" and report.dependencies.ellesmerePresent==false and report.dependencies.exwindPresent==false)
EllesmereUI=originalEUI;ExwindTools=originalEx
serial=serial+1
local originalTimer=C_Timer.NewTimer
C_Timer.NewTimer=function() error("simulated scheduler failure") end
returned=script();assert(returned.status=="aborted" and not LycheePerformanceTestControl)
C_Timer.NewTimer=originalTimer
serial=serial+1
local shows,hides=0,0
local palette={visible=false,list={rows={{},{}}}}
palette.frame={IsShown=function() return palette.visible end,GetRect=function() return 10,20,640,508 end}
palette.header={GetAlpha=function() return 1 end};palette.content={GetAlpha=function() return 1 end}
function palette:Show() shows=shows+1;self.visible=true;return true end
function palette:Hide() hides=hides+1;self.visible=false;return true end
realI.Host={PaletteController=palette}
returned=script();drainReal()
report=LycheePerformanceTestDB.reports[returned.studyID]
assert(report.status=="complete" and shows==3 and hides==3 and not palette.visible)
assert(report.geometryStable and report.ui.closed and report.ui.initiallyCreated)
realI.Host=nil
assert(nativeCalls==0 and externalCalls==0 and C_MountJournal.GetMountInfoByID==originalInfo)
print("unified study: normal/resolve/equivalence/late-reply/early+mid-cancel/missing-dependency/timeout/scheduler-failure/UI-sequence/isolation PASS")

checkFactories()
-- Fresh fixture-owned report store for failure injection, never production storage.
LycheePerformanceTestDB={schemaVersion=1,reports={}}
local oldI=LycheeInternal
LycheeInternal=nil
assert(script().status=="blocked")
assert(carrier.statusFrame.title.text=="未能开始执行")
LycheeInternal=oldI
local oldCombat=InCombatLockdown
InCombatLockdown=function() return true end
assert(script().status=="blocked")
InCombatLockdown=oldCombat
serial=serial+1;returned=script();assert(script().status=="blocked")
InCombatLockdown=function() return true end;drainReal();InCombatLockdown=oldCombat
assert(LycheePerformanceTestDB.reports[returned.studyID].status=="aborted")
checkFactories()
local originalFactory=carrier.modules[10][2]
carrier.modules[10][2]=function() error("injected module initialization failure") end
serial=serial+1;returned=script();drainReal()
assert(LycheePerformanceTestDB.reports[returned.studyID].status=="aborted")
assert(not LycheePerformanceTestControl)
checkFactories();carrier.modules[10][2]=originalFactory
-- A later run remains usable after errors, cancellation and timeout.
serial=serial+1;returned=script();drainReal()
assert(LycheePerformanceTestDB.reports[returned.studyID].status=="complete")
checkFactories()
assert(LycheeDevDB==nil and nativeCalls==0 and externalCalls==0)
-- Serialize exactly the declared SavedVariable, then parse without host globals.
local function literal(value)
    local kind=type(value)
    if kind=="string" then return string.format("%q",value) end
    if kind=="number" or kind=="boolean" then return tostring(value) end
    assert(kind=="table","nonpersistent report type: "..kind)
    local out={"{"};for key,item in pairs(value) do out[#out+1]="["..literal(key).."]="..literal(item).."," end
    out[#out+1]="}";return table.concat(out)
end
local serialized="LycheePerformanceTestDB="..literal(LycheePerformanceTestDB)
local saved=assert(io.open("analyze/performance-test-package/fixture-savedvariables.lua","wb"));saved:write(serialized);saved:close()
local env={};local parse=assert(loadfile("analyze/performance-test-package/fixture-savedvariables.lua"));setfenv(parse,env);parse()
local restored=env.LycheePerformanceTestDB
assert(restored.lastID==returned.studyID and restored.reports[returned.studyID].status=="complete")
assert(#restored.reports[returned.studyID].rounds==4)
-- A new loaded session exposes interrupted reports rather than a false active job.
LycheePerformanceTestDB=restored
restored.reports[returned.studyID].status="running"
LycheePerformanceTest=nil
assert(loadfile(packagePath.."Entry.lua"))("Lychee Performance Test",carrier)
assert(LycheePerformanceTest.Status().status=="interrupted")
assert(#tasks==0 and not LycheePerformanceTestControl)
print("standalone addon: native TOC / no auto-run / no Dev / module-error recovery / combat / reentry / factory env / report persistence / interrupted recovery PASS",#serialized)
-- Exercise the actual normal-settings seam. No real business setter may run.
local registrations=0
local registration=function() registrations=registrations+1 end
local mode
local preparedUI={_deferredLoaded=false,_modules={Unit={title="Unit",pages={"冷却"}}},L=function(s) return s end,
    _RegisterSearchEntry=registration,GetMainFrame=function() return {GetRect=function() return 10,20,900,700 end} end}
function preparedUI:EnsureLoaded() if mode=="load_error" then error("injected upstream load error") end;if mode~="load_incomplete" then self._deferredLoaded=true end end
function preparedUI:ShowModule(name)
    self.visible=true;self.selected=name
    if mode=="show_error" then error("injected upstream show error") end
    self._RegisterSearchEntry("冷却开关",nil,"真实登记文字",name,"冷却","测试",external,"player",false)
end
function preparedUI:Hide() self.visible=false end
function preparedUI:IsShown() return self.visible==true end
function preparedUI:GetActiveModule() return self.selected end
function preparedUI:GetActivePage() return "冷却" end
local function prepareRun(which)
    mode=which;EllesmereUI=preparedUI;preparedUI.visible=false;preparedUI._deferredLoaded=false
    LycheePerformanceTestDB={schemaVersion=1,reports={}};serial=serial+1
    local result=LycheePerformanceTest.Start();assert(result.status=="running")
    return result
end
returned=prepareRun("normal");drainReal()
report=LycheePerformanceTestDB.reports[returned.studyID]
assert(report.status=="complete" and report.carrierRevision=="0.3.0-character-storage")
assert(report.ellesmerePreparation.status=="complete" and report.ellesmerePreparation.loadedBefore==false)
assert(report.ellesmerePreparation.loadedAfter and report.ellesmerePreparation.shown and report.ellesmerePreparation.closed)
assert(report.ellesmerePreparation.optionsCaptured==1 and report.ellesmerePreparation.registrationRestored)
for _,round in ipairs(report.rounds) do assert(round.ellesmereOptionCheck.status=="verified" and round.ellesmereOptionCheck.resolved>0) end
assert(preparedUI._RegisterSearchEntry==registration and not preparedUI.visible and registrations==1)
for _,failure in ipairs({"load_error","show_error","load_incomplete"}) do
    returned=prepareRun(failure);drainReal();report=LycheePerformanceTestDB.reports[returned.studyID]
    assert(preparedUI._RegisterSearchEntry==registration and not preparedUI.visible)
    assert(report.cleanupOK and (report.status=="aborted" or report.ellesmerePreparation.status=="failed"))
end
for _,point in ipairs({"loaded","visible"}) do
    returned=prepareRun("normal")
    while LycheePerformanceTestControl do
        local p=LycheePerformanceTestControl.report.ellesmerePreparation
        if p and (point=="loaded" and p.loadedAfter or point=="visible" and preparedUI.visible) then break end
        table.sort(tasks,function(a,b) return a.due<b.due end)
        local timer=table.remove(tasks,1);assert(timer)
        virtual=virtual+math.max(0,timer.due-debugprofilestop());if not timer.cancelled then timer.fn() end
    end
    LycheePerformanceTest.Cancel();drainReal();report=LycheePerformanceTestDB.reports[returned.studyID]
    assert(report.status=="cancelled" and report.ellesmerePreparation.registrationRestored)
    assert(preparedUI._RegisterSearchEntry==registration and not preparedUI.visible)
end
assert(externalCalls==0 and nativeCalls==0);checkFactories()
print("Ellesmere: real registration capture -> private SDK query/option Resolve / initialization+visible open+close / load+show errors / incomplete load / cancellation before+after show / observer restoration PASS")
realI.Host=nil
Lychee_Toggle=function() realI.Host={PaletteController=palette};palette:Show() end
shows,hides=0,0
returned=prepareRun("normal");drainReal();report=LycheePerformanceTestDB.reports[returned.studyID]
assert(report.ui.initiallyCreated==false and report.ui.closed and #report.ui.samples==3)
assert(shows==3 and hides==3 and not palette.visible)
Lychee_Toggle=nil;realI.Host=nil
print("Lychee first-controller creation uses normal Toggle and completes three open/close cycles PASS")

assert(overlayFrames==1 and overlayFonts==2,"status overlay grew across repeated runs")
assert(carrier.statusFrame.title.text=="执行完毕，可落盘" and #tasks==0)
print("Center status: no load-time UI / running+complete+cancel+timeout+blocked / reuse / no extra timers PASS")

assert(C_ClassColor.GetClassColor==nativeClassColor,"native color namespace changed")
assert(report.nativeCalls.status=="verified" and #report.nativeCalls.failures==0)
assert(report.baseline and report.baseline.status=="incomplete","fixture missing coverage silently passed")
