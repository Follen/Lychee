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
function CreateFrame(_,name,parent) frames=frames+1;return frame(parent,name) end
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
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints(target) self.anchor=target end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha end
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
function methods:GetFrameLevel() return 2 end
function methods:SetClampedToScreen(...) end
function methods:EnableMouse(...) end
function methods:EnableKeyboard(v) self.keyboard=v end
function methods:SetPropagateKeyboardInput(v) self.propagate=v end
function methods:Enable() self.disabled=false end
function methods:Disable() self.disabled=true end
function methods:IsMouseOver() return false end
function methods:SetMultiLine(...) end
function methods:SetAutoFocus(...) end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:HighlightText() self.highlighted=true end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetDebugName() return "debug-frame" end
function methods:GetObjectType() return "Frame" end
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
local setting="0"
C_CVar={GetCVar=function() return setting end,SetCVar=function(_,v) setting=v end}
C_AddOns={GetAddOnMetadata=function(folder) return ({ElvUI="ElvUI",Example="示例插件"})[folder] end}
function ReloadUI() reloads=reloads+1 end
C_Timer={NewTimer=function(delay,fn)
    local t={fn=fn};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
for _,file in ipairs({"Bootstrap.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
    "Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua",
    "Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua",
    "UI/Theme.lua","UI/Components.lua","UI/AddonInspector.lua","Builtin/AddonInspector.lua"}) do dofile("package/Lychee/"..file) end
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
assert(v.heading:GetText()=="示例插件" and v.confidence:GetText()=="创建来源" and v.corner==2,"live exact source and avoidance")
assert(v.outline:IsShown() and v.outline.anchor==a)
collectgarbage("collect");local retained=collectgarbage("count")-baseline
assert(retained<512 and frames-beforeFrames<=16 and regions-beforeRegions<=40,"bounded initial objects")
local warmFrames,warmRegions=frames,regions
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
local previousCorner=v.corner
cursorX=previousCorner%2==1 and 1850 or 50
cursorY=previousCorner<=2 and 1000 or 50
foci={v.frame};M:Poll()
assert(v.corner~=previousCorner,"cursor entering inspector must move it aside")
local movedCorner=v.corner
for n=1,20 do M:Poll() end
assert(v.corner==movedCorner,"stationary cursor must not make inspector bounce")
shift=true
local pausedCorner=v.corner
foci={a};M:Poll()
assert(v.corner==pausedCorner and M.target==child,"Shift pauses both target and placement")
foci={v.copy.frame};M:Poll();assert(M.target==child,"paused panel preserves target")
v.copy.frame.scripts.OnClick(v.copy.frame)
assert(v.copying and v.edit.focused and v.edit.highlighted and v.report:find("父级关联",1,true))
M:Poll();assert(v.copying)
v.edit.scripts.OnEscapePressed();shift=false;cursorX,cursorY=960,540
assert(not M.running and not M.timer and not v.frame:IsShown() and not v.outline:IsShown() and not v.report)
assert(not v.frame.keyboard and next(v.frame.events)==nil and not M.target and not M.data)
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
