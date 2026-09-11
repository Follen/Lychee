local frames,regions,sourceReads,reloads=0,0,0,0
local combat=false
local cursorX,cursorY,shift=960,540,false
function GetCursorPosition() return cursorX,cursorY end
function IsShiftKeyDown() return shift end
local timers={}
local methods={}
local function frame(parent,name)
    return setmetatable({parent=parent,name=name,shown=true,scripts={},width=100,height=100,alpha=1,scale=1,events={}},{__index=methods})
end
function CreateFrame(kind,name,parent)
    assert(kind~="GameTooltip","inspector must not create a tooltip or enter third-party tooltip skinning")
    frames=frames+1;return frame(parent,name)
end
function methods:CreateTexture() regions=regions+1;return frame(self) end
function methods:CreateFontString() regions=regions+1;return frame(self) end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show() self.shown=true end
function methods:Hide() local shown=self.shown;self.shown=false;if shown and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...) self.point={...};self.pointWrites=(self.pointWrites or 0)+1 end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints(target) self.anchor=target end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha end
function methods:GetEffectiveAlpha() return self.alpha*(self.parent and self.parent:GetEffectiveAlpha() or 1) end
function methods:IsVisible() return self:IsShown() end
function methods:GetRect() return self.left or 0,self.bottom or 0,self.width,self.height end
function methods:GetRegions() if self.visualRegions then return unpack(self.visualRegions) end end
function methods:GetTexture() return self.texture end
function methods:GetVertexColor() return 1,1,1,self.colorAlpha or 1 end
function methods:GetTextColor() return 1,1,1,self.colorAlpha or 1 end
function methods:GetDrawLayer() return self.layer or "ARTWORK",0 end
function methods:DoesClipChildren() return self.clips or false end
function methods:SetScale(v) self.scale=v end
function methods:GetEffectiveScale() return self.scale end
function methods:SetTexture(v) self.texture=v end
function methods:SetFont(...) return true end
function methods:SetTextColor(...) end
function methods:SetColorTexture(...) end
function methods:SetVertexColor(...) end
function methods:SetTexCoord(...) end
function methods:SetShadowOffset(...) end
function methods:SetJustifyH(...) end
function methods:SetJustifyV(...) end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:GetFrameLevel() return self.level or 2 end
function methods:SetClampedToScreen(...) end
function methods:EnableMouse(...) end
function methods:EnableKeyboard(v) self.keyboard=v end
function methods:SetPropagateKeyboardInput(v) self.propagate=v end
function methods:Enable() self.disabled=false end
function methods:Disable() self.disabled=true end
function methods:IsMouseOver() return false end
function methods:SetMultiLine(...) end
function methods:SetAutoFocus(...) end
function methods:SetTextInsets(...) self.insets={...} end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:HighlightText() self.highlighted=true end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetDebugName() return "debug-frame" end
function methods:GetObjectType() return self.kind or "Frame" end
function methods:GetSourceLocation() sourceReads=sourceReads+1;return self.location end
function methods:IsForbidden() return self.forbidden end
function methods:GetLeft() return self.left or 0 end
function methods:GetRight() return self.right or 100 end
function methods:GetBottom() return self.bottom or 0 end
function methods:GetTop() return self.top or 100 end
UIParent=frame();UIParent:SetSize(1920,1080)
WorldFrame=frame(UIParent)
STANDARD_TEXT_FONT="font"
function InCombatLockdown() return combat end
function issecretvalue(v) return type(v)=="table" and rawget(v,"secret")==true end
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function debugprofilestop() return os.clock()*1000 end
local foci={}
function GetMouseFoci() return foci end
local visualFrames,visualIndexes,enumerations={},{},0
local function scene(list)
    visualFrames=list;visualIndexes={}
    for i,f in ipairs(list) do visualIndexes[f]=i end
end
function EnumerateFrames(previous)
    enumerations=enumerations+1
    return visualFrames[previous and ((visualIndexes[previous] or #visualFrames)+1) or 1]
end
local setting="0"
C_CVar={GetCVar=function() return setting end,SetCVar=function(_,v) setting=v end}
C_AddOns={GetAddOnMetadata=function(folder) return ({ElvUI="ElvUI",Example="示例插件"})[folder] end}
function ReloadUI() reloads=reloads+1 end
C_Timer={NewTimer=function(delay,fn)
    local t={fn=fn,delay=delay};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
for _,file in ipairs({"Bootstrap.lua", "Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua", "Builtin/Achievements/Locales.lua","Builtin/AddonInspector/Locales.lua","Builtin/Bags/Locales.lua","Builtin/BlizzardSettings/Locales.lua","Builtin/Bosses/Locales.lua","Builtin/Crests/Locales.lua","Builtin/EquipmentSets/Locales.lua","Builtin/GameMenus/Locales.lua","Builtin/GreatVault/Locales.lua","Builtin/Keystones/Locales.lua","Builtin/Mounts/Locales.lua","Builtin/PlayerSpells/Locales.lua","Builtin/TalentLoadouts/Locales.lua", "Builtin/Shared/CatalogProvider.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
    "Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua",
    "Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua",
    "UI/Theme.lua","UI/Components.lua","UI/AddonInspector.lua","Builtin/AddonInspector/Provider.lua"}) do dofile("package/Lychee/"..file) end
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.Builtin.AddonInspector
local beforeFrames,beforeRegions=frames,regions
M:Init()
assert(not M.enabled and not M.view and frames==beforeFrames and regions==beforeRegions and sourceReads==0)
assert(I.Registry:SetUserEnabled(M.id,true))
assert(M.enabled and not M.view and not M.timer and sourceReads==0,"enabled idle creates no picker")
local _,results=I.Search.Query:Query("插件识别",{visible=true})
assert(results and #results>0,"real Host can search provider entry")
local a=frame(UIParent,"ExampleWindow");a.location="@Interface/AddOns/Example/Main.lua:25"
a.left,a.right,a.bottom,a.top=1700,1900,900,1040
local b=frame(UIParent,"ElvUI_Frame")
foci={a}
collectgarbage("collect");local baseline=collectgarbage("count")
assert(M:Start().ok and M.running and M.timer)
local v=M.view
assert(v.heading:GetText()=="示例插件" and v.confidence:GetText()=="创建来源" and v.anchorX==cursorX+20,"live exact source and avoidance")
assert(v.outline:IsShown() and v.outline.anchor==a)
assert(not v.copy.frame:IsShown() and not v.parent.frame:IsShown(),"follow summary has no unreachable action buttons")
collectgarbage("collect");local retained=collectgarbage("count")-baseline
assert(retained<512 and frames-beforeFrames<=16 and regions-beforeRegions<=48,"bounded initial objects")
local warmFrames,warmRegions=frames,regions
local realProfileClock=debugprofilestop
debugprofilestop=function() return 0 end -- Ordering tests use a fixed clock; real costs are measured below.
local cdm=frame(UIParent,"EssentialCooldownViewer.GeneratedItem")
local cdmIcon=frame(cdm);cdmIcon.kind="Texture";cdmIcon.texture="spell-icon"
cdmIcon.location="Interface/AddOns/EllesmereUICooldownManager/EllesmereUICdmHooks.lua:3081"
cdm.visualRegions={cdmIcon}
cursorX,cursorY=50,50;foci={};scene({cdm});M:Poll()
assert(M.target==cdmIcon and M.data.title=="EllesmereUICooldownManager","zero input foci must still identify a visible cooldown icon")
local aura=frame(UIParent,"GeneratedAura");aura.location="Interface/AddOns/AnotherAuraAddon/Icons.lua:9"
local auraIcon=frame(aura);auraIcon.kind="Texture";auraIcon.texture="aura-icon";aura.visualRegions={auraIcon}
scene({aura});M:Poll()
assert(M.target==auraIcon and M.data.title=="AnotherAuraAddon","Buff/Debuff icon ownership is discovered without an addon-name mapping")
local emptyAnchor=frame(UIParent,"ExBoss_DungeonExtras_Anchor")
local cursorAnchor=frame(UIParent,"EllesmereUI_TooltipCursorAnchor");cursorAnchor:SetSize(1,1)
local invisible=frame(UIParent,"HiddenIconOwner");invisible:Hide();invisible.visualRegions={cdmIcon}
local transparent=frame(UIParent,"TransparentOwner");transparent.alpha=0;transparent.visualRegions={cdmIcon}
scene({emptyAnchor,cursorAnchor,invisible,transparent});M:Poll()
assert(not M.target and not v.outline:IsShown(),"empty/hidden/transparent containers do not become fallback results")
local emptyText=frame(aura);emptyText.kind="FontString";emptyText.text="  "
local clearIcon=frame(aura);clearIcon.kind="Texture";clearIcon.texture="icon";clearIcon.colorAlpha=0
aura.visualRegions={emptyText,clearIcon};scene({aura});M:Poll();assert(not M.target,"empty text and transparent texture colors are ignored")
aura.visualRegions={auraIcon}
local clip=frame(UIParent,"ClippedParent");clip.clips=true;clip.left=1000;clip.bottom=1000
aura.parent=clip;scene({aura});M:Poll();assert(not M.target,"regions outside ancestor clipping do not count as visible")
aura.parent=UIParent
local oldRect=auraIcon.GetRect
auraIcon.GetRect=function() return {secret=true},0,100,100 end
scene({aura});M:Poll();assert(not M.target,"secret geometry is not compared")
auraIcon.GetRect=oldRect
local ownIcon=frame(v.frame);ownIcon.kind="Texture";ownIcon.texture="own"
v.frame.visualRegions={ownIcon};scene({v.frame});M:Poll();assert(not M.target,"fallback cannot pick inspector artwork")
v.frame.visualRegions=nil
aura.level=10;scene({aura,cdm});M:Poll();assert(M.target==auraIcon,"higher frame level wins independently of enumeration order")
cdm.strata="DIALOG";scene({aura,cdm});M:Poll();assert(M.target==cdmIcon,"frame strata precedes frame level")
cdm.strata=nil
cursorX,cursorY=500,500;M:Poll();assert(not M.target,"moving away never keeps an old result")
aura.scale=2;auraIcon.left=100;auraIcon.bottom=100;cursorX,cursorY=250,250
scene({aura});M:Poll();assert(M.target==auraIcon,"region geometry is converted using the owning frame scale")
aura.scale=1;auraIcon.left=0;auraIcon.bottom=0;cursorX,cursorY=50,50
local many={}
for i=1,4095 do many[i]=frame(UIParent,"FarFrame");many[i].left=1000;many[i].bottom=1000 end
-- Real client: running=true, visualPending=true, visualBest=<object>, target=nil.
-- A large frame directory must not withhold an already discovered visible icon.
local firstFar=many[1]
many[1]=cdm;many[4096]=aura;scene(many);M:ResetVisual();M:Poll()
assert(M.visualPending and M.visualBest==cdmIcon and M.target==cdmIcon,
    "a discovered icon must display before the full frame scan completes")
local partialReads=sourceReads
M:Poll();assert(M.target==cdmIcon and sourceReads==partialReads,"unchanged partial result does not repeat source analysis")
cdm:Hide();M:Poll();assert(not M.target,"hidden partial candidate is removed immediately")
cdm:Show();M:ResetVisual();M:Poll();cursorX=500;M:Poll()
assert(not M.target,"moving away clears a displayed partial candidate")
cursorX=50;M:ResetVisual();M:Poll()
local progressiveBatches=1
while M.visualPending do M:Poll();progressiveBatches=progressiveBatches+1;assert(progressiveBatches<100) end
assert(M.target==auraIcon,"later higher-layer candidate replaces the first displayed icon")
many[1]=firstFar
many[4096]=aura;scene(many);M:ResetVisual()
local beforeBatch=enumerations;M:Poll()
assert(enumerations-beforeBatch<=128 and M.visualPending and not M.target,"one batch has a fixed frame bound and does not publish a stale result")
local oldMouseX=cursorX;cursorX=500;M:Poll();assert(not M.target,"mouse movement invalidates a partial pass")
cursorX=oldMouseX;M:ResetVisual()
debugprofilestop=realProfileClock
collectgarbage("collect");local scanBase=collectgarbage("count");collectgarbage("stop")
local scanStart=os.clock();local batches,maxBatch=0,0
repeat
    local t=os.clock();local before=enumerations;M:Poll()
    maxBatch=math.max(maxBatch,(os.clock()-t)*1000);batches=batches+1
    assert(enumerations-before<=128 and batches<1000,"scan must make bounded progress")
until not M.visualPending
local scanMs=(os.clock()-scanStart)*1000;local scanAllocated=collectgarbage("count")-scanBase
assert(M.target==auraIcon and scanAllocated<1024 and frames==warmFrames and regions==warmRegions,"large fallback scan finds the aura without new UI objects or unbounded allocation")
M:Stop();collectgarbage("restart");collectgarbage("collect")
local scanGrowth=collectgarbage("count")-scanBase
assert(scanGrowth<64 and not M.visualCursor and not M.visualResult and not M.visualBest,"stop releases fallback references")
local stoppedEnumerations=enumerations;M:Poll();M:UpdatePointer();assert(enumerations==stoppedEnumerations,"stopped fallback performs no enumeration")
print(string.format("VisualFallback4096 batches=%d cpu_ms=%.2f max_batch_ms=%.2f allocated_KiB=%.1f retained_growth_KiB=%.1f new_frames=0",batches,scanMs,maxBatch,scanAllocated,scanGrowth))
debugprofilestop=function() return 0 end
M:Start();assert(M.visualPending and M.timer.delay==0.01,"incomplete fallback uses the existing timer for small batches")
local timerBatches=0
while M.visualPending do timerBatches=timerBatches+1;assert(timerBatches<100);M.timer.fn() end
assert(M.target==auraIcon and M.timer.delay==0.1,"completed fallback returns to normal inspection cadence")
shift=true;local frozenEnumerations=enumerations;M.timer.fn()
assert(enumerations==frozenEnumerations and M.target==auraIcon,"Shift freezes the fallback result without enumeration")
shift=false;M:Stop();debugprofilestop=realProfileClock
scene({});foci={a};M:Start()
scene({});cursorX,cursorY=960,540;foci={a};M:Poll()
local forbidden=frame(UIParent,"Forbidden");forbidden.forbidden=true
foci={WorldFrame,forbidden,a};M:Poll()
assert(M.target==a,"invalid first mouse focus must not hide later valid targets")
M:Stop();shift=true;foci={WorldFrame};M:Start()
assert(not M.target and v.frame:GetHeight()==140 and not v.details:IsShown(),"Shift without a target must not expand empty details")
foci={a};M:Poll()
assert(M.target==a and v.details:IsShown(),"Shift must acquire a first mouse target before freezing")
foci={b};M:Poll();assert(M.target==a,"Shift freezes an existing target")
M:Stop();M:Start()
assert(M.target==b and v.details:IsShown(),"starting with Shift held still acquires a target")
shift=false;foci={a};M:Poll()
local reads=sourceReads
for n=1,100 do M:Poll() end
assert(sourceReads==reads,"same target is not analyzed again")
foci={b};M:Poll()
assert(v.heading:GetText()=="ElvUI" and v.confidence:GetText():find("可能来自",1,true))
local templateChild=frame(a,"UnrelatedGeneratedButton42")
templateChild.location="Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua:100"
foci={templateChild};M:Poll()
assert(M.data.title=="示例插件" and M.data.confidence=="可能来自 · 根据父级来源","Blizzard template must not override dynamic addon parent evidence")
local independent=frame(UIParent,"AnyName")
independent.location="Interface/AddOns/ACompletelyDifferentAddon/Widgets.lua:12"
local helper=frame(independent,"GeneratedParent")
helper.location=templateChild.location
local leaf=frame(helper,"GeneratedChild")
leaf.location=templateChild.location
foci={leaf};M:Poll()
assert(M.data.title=="ACompletelyDifferentAddon" and M.data.confidence=="可能来自 · 根据父级来源","unknown installed addon is inferred dynamically through native helper ancestors")
local noOwner=frame(UIParent,"UnknownGeneratedWidget")
noOwner.location=templateChild.location
foci={noOwner};M:Poll()
assert(M.data.title=="归属未确定" and M.data.confidence=="创建位置来自暴雪代码","native helper alone is not ownership proof")
local cyclic=frame(nil,"Loop");cyclic.parent=cyclic
local cycleBefore=sourceReads
foci={cyclic};M:Poll();assert(sourceReads-cycleBefore<=2,"cyclic parent walk is bounded")
UIParent:SetSize(400,220);M:Poll();assert(v.scale>0 and v.scale<1,"small viewport scales popup")
UIParent:SetSize(1920,1080)
local child=frame(a)
foci={child};M:Poll()
assert(M.data.title=="示例插件" and M.data.confidence=="可能来自 · 根据父级来源")
cursorX,cursorY=900,800
v.frame.scripts.OnUpdate()
assert(v.anchorX==920 and v.anchorTop==780,"window follows cursor with gap")
local pointerReads,pointerWrites,pointerEnumerations=sourceReads,v.frame.pointWrites,enumerations
collectgarbage("collect");collectgarbage("stop")
local pointerMemory=collectgarbage("count");local pointerStart=os.clock()
for i=1,10000 do v.frame.scripts.OnUpdate() end
local pointerAllocated=collectgarbage("count")-pointerMemory
local pointerElapsed=(os.clock()-pointerStart)*1000
collectgarbage("restart")
assert(pointerAllocated<128 and sourceReads==pointerReads and enumerations==pointerEnumerations and v.frame.pointWrites==pointerWrites,"steady following avoids allocation, enumeration, source reads and redundant setters")
print(string.format("Pointer10000 ms=%.2f allocated_KiB=%.1f source_reads=0 redundant_setters=0",pointerElapsed,pointerAllocated))
UIParent.scale=2;cursorX,cursorY=1800,1600;v.frame.scripts.OnUpdate()
assert(v.anchorX==920 and v.anchorTop==780,"cursor coordinates respect UI scale")
UIParent.scale=1;cursorX,cursorY=900,800
local oldX,oldTop=v.anchorX,v.anchorTop
shift=true;v.frame.scripts.OnUpdate()
assert(v.expanded and v.details:IsShown() and v.anchorX==oldX and v.anchorTop==oldTop,"Shift freezes top edge and expands details")
assert(v.copy.frame:IsShown() and v.parent.frame:IsShown(),"detail actions become reachable while frozen")
v.copy.frame.scripts.OnEnter();assert(v.copy._state=="hover")
v.copy.frame.scripts.OnLeave();assert(v.copy._state=="normal")
v.parent:SetEnabled(false);v.parent.frame.scripts.OnEnter();assert(v.parent._state=="disabled","disabled parent cannot highlight")
v.parent:SetEnabled(true)
cursorX,cursorY=1500,300;foci={a};M:Poll()
assert(v.anchorX==oldX and v.anchorTop==oldTop and M.target==child,"Shift freezes target and placement while cursor moves")
shift=false;v.frame.scripts.OnUpdate()
assert(not v.expanded and v.anchorX~=oldX,"release collapses and resumes following")
for _,point in ipairs({{0,0},{1920,0},{0,1080},{1920,1080}}) do
    cursorX,cursorY=point[1],point[2];v.frame.scripts.OnUpdate()
    assert(v.anchorX>=16 and v.anchorX+320*v.scale<=1904 and v.anchorTop<=1064 and v.anchorTop-v.frame:GetHeight()*v.scale>=16,"edge following stays inside viewport")
end
cursorX,cursorY=900,800;v.frame.scripts.OnUpdate()
shift=true;v.frame.scripts.OnUpdate()
foci={v.copy.frame};M:Poll();assert(M.target==child,"paused panel preserves target")
v.copy.frame.scripts.OnClick(v.copy.frame)
assert(v.copying and v.edit.focused and v.edit.highlighted and v.report:find("父级关联",1,true))
M:Poll();assert(v.copying)
v.edit.scripts.OnEscapePressed();shift=false;cursorX,cursorY=960,540
assert(not M.running and not M.timer and not v.frame:IsShown() and not v.outline:IsShown() and not v.report)
assert(not v.frame.keyboard and not v.frame.scripts.OnUpdate and next(v.frame.events)==nil and not M.target and not M.data)
foci={a};M:Start()
local stale=M.timer
M:Stop();M:Start();local current=M.timer
stale.fn();assert(M.timer==current,"late callback from prior mode cannot create work")
foci={WorldFrame};M:Poll();assert(not M.data and not v.outline:IsShown())
foci={{secret=true}};M:Poll();assert(not M.data,"secret focus is never inspected")
local secretFrame=frame(UIParent,"Unknown");secretFrame.location={secret=true}
foci={secretFrame};M:Poll();assert(M.data.confidence=="来源未确定")
local native=frame(a,"Native");native.location="Interface/AddOns/Blizzard_Test/Main.lua:1"
foci={native};M:Poll();assert(M.data.title=="示例插件" and M.data.confidence=="可能来自 · 根据父级来源")
foci={child};M:Poll();foci={v.parent.frame};v.parent.frame.scripts.OnClick()
assert(M.target==a and M.data.confidence=="创建来源")
combat=true;v.frame.scripts.OnEvent(v.frame,"PLAYER_REGEN_DISABLED")
assert(not M.running and not M.timer and not v.frame:IsShown())
assert(not M:Start().ok);combat=false
assert(not M.running,"leaving combat never restarts")
foci={a};M:Start()
local settingBefore=setting
assert(setting==settingBefore and reloads==0,"start never changes configuration or reloads")
setting=nil
assert(M:EnableSource()==false and reloads==0,"unknown CVar is never written")
setting="0"
C_CVar.SetCVar=function() error("blocked") end
assert(M:EnableSource()==false and reloads==0)
C_CVar.SetCVar=function(_,value) setting=value end
assert(M:EnableSource() and reloads==1 and not M.running and setting=="1")
M:Start();I.Registry:SetUserEnabled(M.id,false)
assert(not M.running and not M.enabled and not M.timer and not v.frame:IsShown())
I.Registry:SetUserEnabled(M.id,true)
collectgarbage("collect");local warmBase=collectgarbage("count")
collectgarbage("stop");local started=os.clock()
for n=1,100 do
    foci={n%2==0 and a or b};M:Start();M:Poll();M:Stop()
end
local allocated=collectgarbage("count")-warmBase
local elapsed=(os.clock()-started)*1000
-- The test timer queue retains cancelled callbacks; real cancelled timers release them.
for n=#timers,1,-1 do if timers[n].cancelled then table.remove(timers,n) end end
collectgarbage("restart");collectgarbage("collect")
local growth=collectgarbage("count")-warmBase
assert(allocated<1024 and growth<64 and frames==warmFrames and regions==warmRegions)
assert(not M.timer and not M.target and next(v.frame.events)==nil and not v.frame.keyboard)
print(string.format("Addon inspector PASS exact/guess/parent/secret/avoidance/copy/Esc/combat/stale/disabled frames=%d regions=%d retained_KiB=%.1f cycles100_ms=%.2f allocated_KiB=%.1f growth_KiB=%.1f idle_work=0",frames-beforeFrames,regions-beforeRegions,retained,elapsed,allocated,math.max(0,growth)))
