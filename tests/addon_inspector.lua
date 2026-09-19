local frames,regions,sourceReads,reloads=0,0,0,0
local combat=false
local cursorX,cursorY,shift=960,540,false
function GetCursorPosition() return cursorX,cursorY end
function IsShiftKeyDown() return shift end
local timers={}
local nativeTarget,nativeReads=nil,0
local methods={}
local function frame(parent,name)
    return setmetatable({parent=parent,name=name,shown=true,scripts={},width=100,height=100,alpha=1,scale=1,events={}},{__index=methods})
end
function CreateFrame(kind,name,parent,template)
    if kind=="GameTooltip" then assert(not name and not parent:IsVisible() and template=="SharedTooltipTemplate","sampler must be isolated under a hidden parent") end
    frames=frames+1;return frame(parent,name)
end
function methods:CreateTexture() regions=regions+1;return frame(self) end
function methods:CreateFontString() regions=regions+1;return frame(self) end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show()
    local visible=self:IsVisible();self.shown=true
    if not visible and self:IsVisible() and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:HookScript(key,fn)
    self.hookCount=(self.hookCount or 0)+1
    local old=self.scripts[key]
    self.scripts[key]=function(...) if old then old(...) end;fn(...) end
    return true
end
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
function methods:IsIgnoringParentAlpha() return self.ignoreParentAlpha==true end
function methods:GetEffectiveAlpha() return self.alpha*(self.parent and self.parent:GetEffectiveAlpha() or 1) end
function methods:IsVisible() return self:IsShown() end
function methods:GetRect() return self.left or 0,self.bottom or 0,self.width,self.height end
function methods:GetRegions() if self.visualRegions then return unpack(self.visualRegions) end end
function methods:GetChildren() if self.children then return unpack(self.children) end end
function methods:GetTexture() return self.texture end
function methods:GetVertexColor() return 1,1,1,self.colorAlpha or 1 end
function methods:GetTextColor() return 1,1,1,self.colorAlpha or 1 end
function methods:GetDrawLayer() return self.layer or "ARTWORK",0 end
function methods:DoesClipChildren() return self.clips or false end
function methods:SetScale(v) self.scale=v end
function methods:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetTexture(v) self.texture=v end
function methods:SetFont(...) return true end
function methods:SetTextColor(...) end
function methods:SetColorTexture(r,g,b,a) self.solid=true;self.colorAlpha=a or 1 end
function methods:IsObjectLoaded() return self.solid==true or self.texture~=nil end
function methods:SetVertexColor(...) end
function methods:SetTexCoord(...) end
function methods:SetShadowOffset(...) end
function methods:SetJustifyH(...) end
function methods:SetJustifyV(...) end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:GetFrameLevel() return self.level or 2 end
function methods:SetFrameLevel(value) self.level=value end
function methods:SetClampedToScreen(...) end
function methods:EnableMouse(...) end
function methods:EnableKeyboard(v) self.keyboard=v end
function methods:SetPropagateKeyboardInput(v) self.propagate=v end
function methods:Enable() self.disabled=false end
function methods:Disable() self.disabled=true end
function methods:IsMouseOver() return false end
function methods:SetMultiLine(value) self.multiLine=value end
function methods:SetMaxLines(...) end
function methods:SetWordWrap(...) end
function methods:EnableMouseWheel(...) end
function methods:SetScrollChild(child) self.scrollChild=child end
function methods:GetVerticalScrollRange() return math.max(0,self.scrollChild:GetHeight()-self:GetHeight()) end
function methods:SetVerticalScroll(value) self.scrollOffset=value end
function methods:GetVerticalScroll() return self.scrollOffset or 0 end
function methods:UpdateScrollChildRect() end
function methods:SetAutoFocus(...) end
function methods:SetTextInsets(...) self.insets={...} end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:HighlightText() self.highlighted=true end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent=parent end
function methods:SetOwner(owner,anchor) self.parent=owner;self.owner=owner;assert(anchor=="ANCHOR_NONE") end
function methods:ClearLines() end
function methods:SetFrameStack(hidden,regions,index)
    nativeReads=nativeReads+1
    assert(hidden==false and regions==true and index==0,"preserve original fstack selection arguments")
    self:Show();self:SetAlpha(1)
    assert(not self:IsVisible(),"even a shown/skinned sampler must remain invisible")
    return nativeTarget
end
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
local stackObjects,stackReads,enumerations={},0,0
local tooltipTouches=0
local tooltipGuard={__index=function() tooltipTouches=tooltipTouches+1;error("tooltip read") end,
    __newindex=function() tooltipTouches=tooltipTouches+1;error("tooltip write") end}
GameTooltip=frame(UIParent,"GameTooltip");GameTooltip:SetText("normal hover")
FrameStackTooltip=setmetatable({},tooltipGuard)
local function scene(list) stackObjects=list end
function EnumerateFrames()
    enumerations=enumerations+1
    error("native stack picking must not enumerate all frames")
end
local function nativeStack()
    stackReads=stackReads+1
    local result={}
    for i,object in ipairs(stackObjects) do result[i]=object end
    return result
end
local setting="0"
C_CVar={GetCVar=function() return setting end,SetCVar=function(_,v) setting=v end}
C_AddOns={GetAddOnMetadata=function(folder) return ({ElvUI="ElvUI",Example="示例插件"})[folder] end}
function ReloadUI() reloads=reloads+1 end
C_Timer={NewTimer=function(delay,fn)
    local t={fn=fn,delay=delay};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
dofile("tests/support/runtime.lua").Load("provider", {"Builtin/Achievements/Locales.lua", "Builtin/AddonInspector/Locales.lua", "Builtin/Bags/Locales.lua", "Builtin/BlizzardSettings/Locales.lua", "Builtin/Bosses/Locales.lua", "Builtin/Crests/Locales.lua", "Builtin/EquipmentSets/Locales.lua", "Builtin/GameMenus/Locales.lua", "Builtin/GreatVault/Locales.lua", "Builtin/Keystones/Locales.lua", "Builtin/Mounts/Locales.lua", "Builtin/PlayerSpells/Locales.lua", "Builtin/TalentLoadouts/Locales.lua", "Builtin/Shared/CatalogProvider.lua", "Core/Scheduler.lua", "UI/Theme.lua", "UI/Runtime.lua", "UI/Components.lua", "UI/AddonInspector.lua", "Builtin/AddonInspector/Picker.lua", "Builtin/AddonInspector/Provider.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.Builtin.AddonInspector
local parentless=frame(nil,"ParentUnavailable")
assert(M:CheckFocus(parentless)==parentless,"absent AuraButtonTooltip global must not exclude objects with no readable parent")
local beforeFrames,beforeRegions=frames,regions
M:Init()
assert(M.enabled and not M.view and frames==beforeFrames and regions==beforeRegions and sourceReads==0,"default enabled without constructing picker")
assert(M.handle:SetAvailability(true))
assert(M.enabled and not M.view and not M.timer and sourceReads==0,"enabled idle creates no picker")
local _,results=I.Search.Query:Query("插件识别",{visible=true})
assert(results and #results>0,"real Host can search provider entry")
local a=frame(UIParent,"ExampleWindow");a.location="@Interface/AddOns/Example/Main.lua:25"
a.left,a.right,a.bottom,a.top=1700,1900,900,1040
local b=frame(UIParent,"ElvUI_Frame")
foci={a}
collectgarbage("collect");local baseline=collectgarbage("count")
assert(M:Start().ok and M.running and M.timer)
assert(not GameTooltip:IsVisible(),"starting inspection must dismiss the extra hover tooltip")
GameTooltip:Show()
assert(not GameTooltip:IsVisible(),"hover tooltip must not reappear over active inspection")
local v=M.view
assert(v.heading:GetText()=="示例插件" and v.confidence:GetText()=="创建来源" and v.anchorX==cursorX+20,"live exact source and avoidance")
assert(v.outline:IsShown() and v.outline.anchor==a)
local function assertOutlineBehindPanel()
    assert(v.outline:GetFrameStrata()==v.frame:GetFrameStrata() and v.outline:GetFrameLevel()<v.frame:GetFrameLevel(),
        "selection outline must render behind the inspector panel at overlapping screen coordinates")
end
assertOutlineBehindPanel()
local auraTooltipLayer=frame(UIParent);auraTooltipLayer:SetFrameStrata("TOOLTIP");auraTooltipLayer:SetFrameLevel(200)
assert(v.frame:GetFrameLevel()>auraTooltipLayer:GetFrameLevel(),"inspection panel must cover raised aura tooltip layers")
assert(not v.copy.frame:IsShown() and not v.parent.frame:IsShown(),"follow summary has no unreachable action buttons")
collectgarbage("collect");local retained=collectgarbage("count")-baseline
assert(retained<512 and frames-beforeFrames<=16 and regions-beforeRegions<=48,"bounded initial objects")
local warmFrames,warmRegions=frames,regions
local realProfileClock=debugprofilestop
debugprofilestop=function() return 0 end -- Ordering tests use a fixed clock; real costs are measured below.
local cdm=frame(UIParent,"EssentialCooldownViewer.GeneratedItem")
local cdmIcon=frame(cdm);cdmIcon.kind="Texture";cdmIcon.texture="spell-icon"
cdmIcon.location="Interface/AddOns/EllesmereUICooldownManager/EllesmereUICdmHooks.lua:3081"
cdm.visualRegions={cdmIcon};cdm.location=cdmIcon.location
C_System={GetFrameStack=nativeStack}
cursorX,cursorY=50,50;foci={};scene({cdm});M:Poll()
assert(M.target==cdm and M.data.title=="EllesmereUICooldownManager","zero input foci must still identify a visible cooldown icon")
scene({cdmIcon});local directReads=stackReads;M:Poll()
assert(stackReads==directReads+1 and M.target==cdmIcon,"native frame-stack objects must be used without a sampling tooltip")
local namedOwner=frame(UIParent,"Example_Surface")
local anonymousPaint=frame(namedOwner);anonymousPaint.kind="Texture";anonymousPaint.texture="paint"
namedOwner.visualRegions={anonymousPaint}
nativeTarget=namedOwner;scene({namedOwner});M:Poll()
assert(M.target==namedOwner and M.data.title=="示例插件",
    "native highlighted frame identity and its addon-name evidence must survive visual filtering")
local selectedReads=stackReads
M:Poll();assert(stackReads==selectedReads,"valid native selection must not be replaced by list ranking")
M.stackTooltip:Show();M.stackTooltip:SetAlpha(1)
assert(not M.stackTooltip:IsVisible() and not M.stackRoot:IsShown(),"deferred tooltip skinning cannot expose the sampler")
nativeTarget=anonymousPaint;M:Poll();assert(M.target==anonymousPaint,"native region identity is preserved too")
local sampleMethod=M.stackTooltip.SetFrameStack
M.stackTooltip.SetFrameStack=function(self) self:Show();error("native sample interrupted") end
scene({namedOwner});M:Poll()
assert(M.target==namedOwner and not M.stackTooltip:IsVisible() and v.outline:IsShown(),"sample failure cleans up the sampler and restores the outline")
M.stackTooltip.SetFrameStack=sampleMethod
nativeTarget=namedOwner;scene({namedOwner})
collectgarbage("collect");local selectedBase=collectgarbage("count");collectgarbage("stop")
local selectedStart=os.clock();local selectedListReads=stackReads
for i=1,100 do M:Poll() end
local selectedMs=(os.clock()-selectedStart)*1000;local selectedAllocation=collectgarbage("count")-selectedBase
collectgarbage("restart")
assert(selectedAllocation<1024 and stackReads==selectedListReads,"valid native selection has no fallback list allocation")
print(string.format("NativePreferred100 cpu_ms=%.2f allocated_KiB=%.1f fallback_reads=0",selectedMs,selectedAllocation))
nativeTarget=nil
-- Client reports: engine-managed AuraContainer has a readable shell and source,
-- but its pooled aura children deny content reads. A plain empty Frame is different.
local auraShell=frame(UIParent,"EngineAuraShell")
auraShell.location="Interface/AddOns/EllesmereUI/EllesmereUI_AuraKit.lua:1321"
local restrictedAura=frame(auraShell);restrictedAura.kind="Texture";restrictedAura.texture="aura-icon"
restrictedAura.location="Interface/AddOns/EllesmereUI/EllesmereUI_AuraKit.lua:1006"
restrictedAura.IsVisible=function() error("restricted") end
auraShell.children={restrictedAura};nativeTarget=auraShell;scene({auraShell,restrictedAura});M:Poll()
assert(M.target==restrictedAura and M.data.title=="EllesmereUI" and M.data.contentUnverified and not v.outline:IsShown(),"native restricted aura icon supplies exact addon source without claiming verified paint")
auraShell:SetSize(1,1);M:Poll()
assert(M.target==restrictedAura and M.data.contentUnverified,"native restricted child can extend beyond the public container rect")
local shellRect=auraShell.GetRect;auraShell.GetRect=function() error("restricted geometry") end;M:Poll()
assert(M.target==restrictedAura and M.data.contentUnverified,"native child evidence survives unreadable public container geometry")
auraShell.GetRect=shellRect;scene({auraShell});M:Poll()
assert(not M.target,"native container cannot use descendants missing from the native snapshot")
auraShell:SetSize(100,100);restrictedAura.IsVisible=function() return false end
scene({auraShell,restrictedAura});M:Poll()
assert(not M.target,"known hidden pooled children do not turn an empty container into unknown content")
restrictedAura.IsVisible=function() error("restricted") end;M:Poll()
assert(M.target==restrictedAura,"restricted native child evidence recovers after the next snapshot")
auraShell:Hide();M:Poll();assert(not M.target,"known hidden container remains excluded despite native child evidence")
auraShell:Show()
local shellChildren=auraShell.GetChildren
local shellRegions=auraShell.GetRegions;auraShell.GetRegions=function() error("restricted own content") end
auraShell.GetChildren=function() return {secret=true} end
auraShell.GetRect=function() error("restricted geometry") end
scene({auraShell});M:Poll()
assert(M.target==auraShell and M.data.contentUnverified,"unreadable hierarchy and geometry remain unknown, not proven empty")
local shellReport=M:Report()
assert(shellReport:find("nativeType=Frame",1,true) and shellReport:find("nativeRect=geometry-unreadable",1,true),"report preserves native type and geometry failure")
auraShell.GetRect=shellRect;auraShell.left=200;M:Poll()
assert(M.target==auraShell and M.data.contentUnverified,"parent rect is not a clipping rect for unverified child content")
auraShell.left=nil;auraShell.GetChildren=shellChildren;auraShell.GetRegions=shellRegions
local resourceOwner=frame(UIParent,"ResourceOwner")
local secretText=frame(resourceOwner,"NativeResourceText");secretText.kind="FontString"
secretText.GetText=function() return {secret=true} end
secretText.location="Interface/AddOns/EllesmereUIResourceBars/EllesmereUIResourceBars.lua:1869"
nativeTarget=secretText;scene({secretText});M:Poll()
assert(M.target==secretText and M.data.contentUnverified and not v.outline:IsShown(),"native restricted text is source evidence, not an empty region")
local secretRect=secretText.GetRect;secretText.GetRect=function() return {secret=true},0,100,100 end
M:Poll();assert(M.target==secretText and M.data.contentUnverified and not v.outline:IsShown(),"native unreadable geometry permits only source information")
secretText.GetRect=secretRect
secretText.GetText=function() return "100" end;M:Poll()
assert(M.target==secretText and not M.data.contentUnverified and v.outline:IsShown(),"same object gains outline when visible content becomes readable")
local emptySourceFrame=frame(UIParent,"EmptySourceAnchor");emptySourceFrame.location=auraShell.location
nativeTarget=emptySourceFrame;scene({emptySourceFrame});M:Poll()
assert(not M.target,"source metadata alone must not admit empty anchors")
nativeTarget=nil
local aura=frame(UIParent,"GeneratedAura");aura.location="Interface/AddOns/AnotherAuraAddon/Icons.lua:9"
local textButton=frame(UIParent,"TextOnlyButton");textButton.kind="Button"
textButton.IsMouseClickEnabled=function() return true end
local buttonText=frame(textButton);buttonText.kind="FontString";buttonText.text="RS"
buttonText.left=65;buttonText.bottom=40;buttonText.width=20;buttonText.height=20
textButton.visualRegions={buttonText};nativeTarget=textButton;scene({textButton});M:Poll()
assert(M.target==textButton,"visible text button padding belongs to the clickable button, not just its glyph bounds")
local buttonClip=frame(UIParent);buttonClip.clips=true;buttonClip.width=60;textButton.parent=buttonClip
M:Poll();assert(not M.target,"button padding cannot borrow text fully outside an ancestor clip")
buttonClip.width=75;M:Poll();assert(M.target==textButton,"partly visible button text still supports its click padding")
buttonClip.scale=2;textButton.scale=0.5;buttonClip.width=30;M:Poll();assert(not M.target,"ancestor clipping uses its own effective scale")
buttonClip.width=38;M:Poll();assert(M.target==textButton,"scaled partial clip retains visible content")
textButton.parent=UIParent;textButton.scale=1
local textRect=buttonText.GetRect;buttonText.GetRect=function() return nil end
M:Poll();assert(M.data and M.data.contentUnverified and not v.outline:IsShown(),"unreadable button content bounds cannot prove visibility")
buttonText.GetRect=textRect
buttonText:Hide();M:Poll();assert(not M.target,"an empty invisible button must still be excluded")
buttonText:Show();textButton.kind="Frame";M:Poll();assert(not M.target,"noninteractive empty overlay cannot borrow off-pointer text")
nativeTarget=nil
-- Rurutia ChatBar keeps a 24x18 button fixed while its centered text scales 1 -> 1.2.
local hoverButton=frame(UIParent,"HoverTextButton");hoverButton.kind="Button"
hoverButton.IsMouseClickEnabled=function() return true end
hoverButton.left,hoverButton.bottom,hoverButton.width,hoverButton.height=200,200,24,18
local hoverText=frame(hoverButton);hoverText.kind="FontString";hoverText.text="钥";hoverText.width,hoverText.height=18,18
hoverButton.visualRegions={hoverText};cursorX,cursorY=210,210;nativeTarget=hoverButton;scene({hoverButton})
for _,scale in ipairs({1,1.2,1,1.2}) do
    hoverText.scale=scale;hoverText.left=212/scale-9;hoverText.bottom=209/scale-9
    M:Poll();assert(M.target==hoverButton,"independently scaled hover text remains selectable in screen coordinates")
end
local clippedChat=frame(UIParent,"ClippedChatTextContainer");clippedChat.clips=true
local clippedChatText=frame(clippedChat);clippedChatText.kind="FontString";clippedChatText.text="chat"
nativeTarget=clippedChatText;scene({clippedChatText,hoverButton});M:Poll()
assert(M.target==hoverButton,"fallback reaches scaled chat button after native clipped chat text is rejected")
nativeTarget=hoverButton;scene({hoverButton})
-- The same geometry occurs on noninteractive cooldown/aura decorative regions.
hoverButton.kind="Frame";M:Poll();assert(M.target==hoverButton,"scaled regions do not require button padding to hit")
hoverButton.kind="Button";cursorX,cursorY=223,209;M:Poll()
assert(M.target==hoverButton,"text protruding beyond button height still proves visible click padding")
hoverText.left=300;M:Poll();assert(not M.target,"fully detached paint cannot support button padding")
hoverText.left=212/1.2-9
hoverText.GetEffectiveScale=function() return {secret=true} end
M:Poll();assert(M.data and M.data.contentUnverified and not v.outline:IsShown(),"secret region scale must not borrow parent geometry for a visible selection")
hoverText.GetEffectiveScale=nil;hoverText:Hide();M:Poll();assert(not M.target,"scaled hidden paint is still rejected")
nativeTarget=nil;cursorX,cursorY=50,50
local solidOwner=frame(UIParent,"ResourceBackgroundOwner")
local solidPaint=frame(solidOwner);solidPaint.kind="Texture";solidPaint:SetColorTexture(0,0,0,0.5)
solidOwner.visualRegions={solidPaint}
local hiddenCountOverlay=frame(solidOwner);hiddenCountOverlay:Hide();nativeTarget=hiddenCountOverlay;scene({hiddenCountOverlay,solidOwner})
M:Poll();assert(M.target==solidOwner,"solid-color resource background without file or atlas remains visible")
solidPaint:SetColorTexture(0,0,0,0);M:Poll();assert(not M.target,"fully transparent solid fill is filtered")
solidPaint.solid=false;solidPaint.colorAlpha=1;M:Poll();assert(not M.target,"unset texture is not confused with a solid fill")
solidPaint.solid=true;solidPaint.IsObjectLoaded=function() return true end
M:Poll();assert(M.target==solidOwner and M.data.contentUnverified and not v.outline:IsShown(),"ambiguous non-file texture provides native source evidence without a visible outline")
solidPaint.IsObjectLoaded=function() return {secret=true} end
M:Poll();assert(M.target==solidOwner and M.data.contentUnverified,"unreadable texture metadata must not become confirmed paint")
nativeTarget=nil
local verifiedOwner=frame(UIParent,"VerifiedUnderlay")
local verifiedPaint=frame(verifiedOwner);verifiedPaint.kind="Texture";verifiedPaint.texture="visible"
verifiedOwner.visualRegions={verifiedPaint}
nativeTarget=solidOwner;scene({solidOwner,verifiedOwner});M:Poll()
assert(M.target==solidOwner and M.data.contentUnverified,"readable underlay must not replace an unrefuted native highlight")
verifiedPaint:Hide();solidOwner:Hide();M:Poll();assert(not M.target,"hidden verified and unknown targets are both rejected")
solidOwner:Show();nativeTarget=nil
local delayed={secretText};secretText.GetText=function() return {secret=true} end
for i=1,20 do delayed[#delayed+1]=frame(UIParent,"EmptyPending"..i) end
verifiedPaint:Show();delayed[#delayed+1]=verifiedPaint
nativeTarget=secretText;scene(delayed)
local evidenceClock=0;debugprofilestop=function() evidenceClock=evidenceClock+0.8;return evidenceClock end
M:Stop();M:Start();assert(M.target==secretText and not M:SelectionState().pending,"restricted native hit returns immediately without scanning a readable underlay")
for i=1,55 do M:Poll() end
assert(M.target==secretText and M.data.contentUnverified,"native restricted source stays stable without waiting for fallback")
nativeTarget=nil;debugprofilestop=function() return 0 end
local rotatingWidget=frame(UIParent,"LayeredAuraOrResource")
local overlayA=frame(rotatingWidget,"OverlayA")
local overlayB=frame(rotatingWidget,"OverlayB")
local visibleChild=frame(rotatingWidget,"ActualVisibleChild")
local visiblePaint=frame(visibleChild);visiblePaint.kind="Texture";visiblePaint.texture="icon"
visibleChild.visualRegions={visiblePaint};rotatingWidget.children={overlayA,overlayB,visibleChild}
local rotatingClock=0
debugprofilestop=function() rotatingClock=rotatingClock+0.8;return rotatingClock end
scene({overlayA,overlayB,visibleChild})
for i=1,20 do nativeTarget=i%2==0 and overlayA or overlayB;M:Poll() end
assert(M.target==visibleChild,"changing native overlay at the same pointer must not restart and starve the sweep")
for i=1,30 do M:Poll();assert(M.target==visibleChild,"a validated descendant must survive new sweep seeding") end
visiblePaint:Hide();M:Poll();assert(not M.target,"stability must not retain hidden content")
nativeTarget=nil;debugprofilestop=function() return 0 end
local emptySweep={}
for i=1,10 do emptySweep[i]=frame(UIParent,"EmptySweep"..i) end
scene(emptySweep)
local sweepClock=0
debugprofilestop=function() sweepClock=sweepClock+0.8;return sweepClock end
M:Poll()
local stableHint=v.confidence:GetText()
for i=1,30 do
    M:Poll()
    assert(v.confidence:GetText()==stableHint,"pending and complete sweeps must not alternate the visible empty-state hint")
end
-- Shift during a failed pending sweep must finish at its original point, not
-- freeze forever or start inspecting the copy button when the pointer moves.
M:Stop();M:Start()
assert(M:SelectionState().pending)
shift=true;M:Poll()
local frozenNativeReads=nativeReads
cursorX,cursorY=1500,900
for i=1,30 do M:Poll() end
assert(not M:SelectionState().pending and M:SelectionState().x==50 and M:SelectionState().y==50 and nativeReads==frozenNativeReads,
    "diagnostic sweep must finish at the frozen pointer without native resampling")
assert(M:PickReport():find("Candidate | filter | creation source",1,true) and M:SelectionState().detailsCount==10,
    "completed diagnostic includes per-object failures instead of just aggregates")
shift=false;cursorX,cursorY=50,50;M:Poll()
assert(not M:SelectionState().ready,"normal sweeps must stop detailed diagnostic recording")
debugprofilestop=function() return 0 end
M:Poll();assert(not M:SelectionState().pending and not M:SelectionState().ready)
shift=true;M:Poll()
assert(not M:SelectionState().pending and M:SelectionState().ready and M:SelectionState().detailsCount==10,"Shift must also explain an already-completed snapshot")
shift=false;M:Poll()
local budgetList={}
for i=1,20 do budgetList[i]=frame(UIParent,"EmptyBudgetCarrier"..i) end
budgetList[21]=cdmIcon
local budgetClock=0
debugprofilestop=function() budgetClock=budgetClock+0.8;return budgetClock end
scene(budgetList)
for i=1,40 do M:Poll() end
assert(M.target==cdmIcon,"budget exhaustion must resume rather than starve the end of the native stack")
cursorX,cursorY=1000,1000;M:Poll()
assert(not M.target,"moving the pointer must discard the previous sweep winner")
cursorX,cursorY=50,50;debugprofilestop=function() return 0 end
local longRegions=frame(UIParent,"PooledTextContainer");longRegions.visualRegions={}
for i=1,40 do
    local region=frame(longRegions);region.kind="FontString";region.text=""
    longRegions.visualRegions[i]=region
end
longRegions.visualRegions[40].text="visible menu entry"
nativeTarget=longRegions;scene({longRegions});M:Poll()
assert(M.target==longRegions and M.data.contentUnverified,"bounded self-content read keeps native container source without expanding regions")
longRegions.visualRegions[40].GetText=function() return {secret=true} end
M:Poll()
assert(M.target==longRegions and M.data.contentUnverified,"unreadable later region does not remove native container source")
scene({longRegions.visualRegions[40]});nativeTarget=longRegions.visualRegions[40];M:Poll()
assert(M.target==nativeTarget and M:PickReport():find("text-unreadable",1,true),"direct native restricted text has its own diagnostic evidence")
nativeTarget=nil
-- Real reported native targets are full-size carriers with no paint under the
-- pointer: raidMarkerHolder / countTextOverlay / AuraKit text and border hosts.
local widget=frame(UIParent,"VisibleWidget")
local carrier=frame(widget,"EmptyOverlay");carrier.level=25
local bar=frame(widget,"VisibleBar");bar.location="Interface/AddOns/Example/Bar.lua:1"
local barPaint=frame(bar);barPaint.kind="Texture";barPaint.texture="bar"
bar.visualRegions={barPaint};widget.children={carrier,bar}
nativeTarget=carrier;scene({carrier,bar});M:Poll()
assert(M.target==bar,"empty native overlay must recover the visible sibling beneath it")
barPaint:Hide();M:Poll();assert(not M.target,"local recovery must not accept an empty or hidden widget")
barPaint:Show();widget:Hide();M:Poll();assert(not M.target,"hidden parent cannot be recovered")
widget:Show()
local localBaseReads=stackReads
collectgarbage("collect");local localBase=collectgarbage("count");collectgarbage("stop")
local localStart=os.clock()
for i=1,100 do M:Poll();assert(M.target==bar) end
local localMs=(os.clock()-localStart)*1000;local localAllocation=collectgarbage("count")-localBase
collectgarbage("restart")
assert(localAllocation<1024 and stackReads-localBaseReads<=100,"unified recovery reads at most one native snapshot per poll")
print(string.format("UnifiedRecovery100 cpu_ms=%.2f allocated_KiB=%.1f",localMs,localAllocation))
local realChildren=bar.GetChildren
local localVisits=0
bar.GetChildren=function(self) localVisits=localVisits+1;return self,self,self,self end
barPaint:Hide();M:Poll();assert(not M.target and localVisits<=64,"cyclic child providers remain bounded")
bar.GetChildren=realChildren;barPaint:Show()
local chatClip=frame(UIParent,"FontStringContainer");chatClip.clips=true;chatClip.left=500
local clippedLine=frame(chatClip);clippedLine.kind="FontString";clippedLine.text="offscreen pooled chat line"
nativeTarget=clippedLine;scene({clippedLine});M:Poll()
assert(not M.target,"a region's direct parent clip must reject offscreen chat text")
chatClip.left=0;M:Poll();assert(M.target==clippedLine,"visible text inside the clip remains inspectable")
clippedLine.alpha=0;M:Poll();assert(not M.target,"fully faded chat text remains excluded")
nativeTarget=nil
local engineIcon=frame(UIParent,"EssentialCooldownViewer.Item")
engineIcon.location="Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua:1"
local engineTexture=frame(engineIcon);engineTexture.kind="Texture";engineTexture.texture="spell"
engineTexture.location=engineIcon.location;engineIcon.visualRegions={engineTexture}
local addonOverlay=frame(engineIcon);addonOverlay.location="Interface/AddOns/EllesmereUICooldownManager/EllesmereUICdmHooks.lua:3096"
engineIcon.children={addonOverlay};nativeTarget=engineIcon;scene({engineIcon});M:Poll()
assert(M.target==engineIcon and M.data.title=="EllesmereUICooldownManager" and M.data.confidence=="关联插件 · 内部控件来源",
    "engine cooldown frame must expose the addon-created overlay without claiming addon ownership")
local auraButton=frame(UIParent,"EngineAuraButton");auraButton.location=engineIcon.location
local auraPaint=frame(auraButton);auraPaint.kind="Texture";auraPaint.texture="aura"
auraPaint.location="Interface/AddOns/EllesmereUI/EllesmereUI_AuraKit.lua:1006"
auraButton.visualRegions={auraPaint};nativeTarget=auraButton;scene({auraButton});M:Poll()
assert(M.data.title=="EllesmereUI" and M.data.relatedSources[1].location==auraPaint.location,
    "engine aura button must expose its dynamically created addon artwork")
assert(M.data.location==auraButton.location,"associated artwork must not overwrite the selected object's creation source")
assert(M:Report():find(auraPaint.location,1,true),"copy report retains the concrete related source evidence")
local relatedReads=sourceReads;M:Poll();assert(sourceReads==relatedReads,"unchanged target does not rescan associated controls")
local hiddenDecoration=frame(engineIcon);hiddenDecoration.location="Interface/AddOns/HiddenAddon/Art.lua:1";hiddenDecoration:Hide()
engineIcon.children={addonOverlay,hiddenDecoration}
local related=M:RelatedSources(engineIcon)
assert(#related==1 and related[1].folder=="EllesmereUICooldownManager","hidden decoration is not an associated visible source")
hiddenDecoration:Show();hiddenDecoration.alpha=0
assert(#M:RelatedSources(engineIcon)==1,"transparent decoration does not add another associated addon")
hiddenDecoration.alpha=1
related=M:RelatedSources(engineIcon);assert(#related==2,"multiple related addons are retained rather than inventing a unique owner")
local originalLocation=engineIcon.location;engineIcon.location="Interface/AddOns/ActualCreator/Frame.lua:1"
local actual=M:Analyze(engineIcon);assert(actual.title=="ActualCreator" and not actual.relatedSources,"direct creation source wins over internal decoration")
engineIcon.location=originalLocation;engineIcon.children={addonOverlay}
local beforeRootReads=sourceReads;assert(not M:RelatedSources(UIParent) and sourceReads==beforeRootReads,"never scan the global UI root")
local bounded=frame(UIParent,"BoundedEngineWidget");bounded.children={}
for i=1,32 do
    local internal=frame(bounded);internal.visualRegions={};bounded.children[i]=internal
    for j=1,32 do internal.visualRegions[j]=frame(internal) end
end
local beforeRelated=sourceReads;local _,relatedTruncated=M:RelatedSources(bounded)
assert(sourceReads-beforeRelated<=64 and relatedTruncated,"internal evidence traversal has a strict object bound")
nativeTarget=nil
local hoverArt=frame(GameTooltip);hoverArt.kind="Texture";hoverArt.texture="tooltip-background"
GameTooltip.visualRegions={hoverArt};GameTooltip.shown=true
nativeTarget=hoverArt;scene({GameTooltip,hoverArt,cdmIcon});M:Poll()
assert(M.target==cdmIcon,"GameTooltip artwork cannot become the inspected addon even when present in a native snapshot")
GameTooltip:Hide();nativeTarget=nil
AuraButtonTooltip=frame(UIParent,"AuraButtonTooltip")
local auraTipPaint=frame(AuraButtonTooltip);auraTipPaint.kind="Texture";auraTipPaint.texture="tooltip"
nativeTarget=auraTipPaint;scene({auraTipPaint,cdmIcon});M:Poll()
assert(M.target==cdmIcon,"independent aura tooltip cannot become the inspected addon")
nativeTarget=nil
local auraIcon=frame(aura);auraIcon.kind="Texture";auraIcon.texture="aura-icon";aura.visualRegions={auraIcon}
scene({aura});M:Poll()
assert(M.target==aura and M.data.title=="AnotherAuraAddon","Buff/Debuff icon ownership is discovered without an addon-name mapping")
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
scene({aura});M:Poll();assert(M.data and M.data.contentUnverified and not v.outline:IsShown(),"secret geometry is not compared or drawn")
auraIcon.GetRect=oldRect
local ownIcon=frame(v.frame);ownIcon.kind="Texture";ownIcon.texture="own"
v.frame.visualRegions={ownIcon};scene({v.frame});M:Poll();assert(not M.target,"fallback cannot pick inspector artwork")
v.frame.visualRegions=nil
aura.level=10;scene({aura,cdm});M:Poll();assert(M.target==aura,"higher frame level wins independently of enumeration order")
cdm.strata="DIALOG";scene({aura,cdm});M:Poll();assert(M.target==cdm,"frame strata precedes frame level")
cdm.strata=nil
cursorX,cursorY=500,500;M:Poll();assert(not M.target,"moving away never keeps an old result")
aura.scale=2;auraIcon.left=100;auraIcon.bottom=100;cursorX,cursorY=250,250
scene({aura});M:Poll();assert(M.target==aura,"region effective scale includes the owning frame scale")
aura.scale=1;auraIcon.left=0;auraIcon.bottom=0;cursorX,cursorY=50,50
-- Real regressions: the empty high-strata anchor must not obscure lower artwork.
emptyAnchor.strata="TOOLTIP";cursorAnchor.strata="TOOLTIP"
scene({emptyAnchor,cursorAnchor,cdmIcon});M:Poll();assert(M.target==cdmIcon,"empty top anchors cannot cover a visible cooldown icon")
nativeTarget=emptyAnchor;M:Poll();assert(M.target==cdmIcon,"empty native highlight is filtered before using the visible fallback")
nativeTarget=nil
cdm:Hide();M:Poll();assert(not M.target,"native lists containing hidden regions are filtered")
cdm:Show();cdm.alpha=0;M:Poll();assert(not M.target,"zero-alpha ancestors filter direct regions")
cdm.alpha=1
scene({v.frame,v.outline,ownIcon,cdmIcon});M:Poll();assert(M.target==cdmIcon,"our outline and UI cannot trap native picking")
scene({});foci={a};M:Poll();assert(not M.target,"an authoritative empty native list must not resurrect an input focus")
foci={};scene({cdmIcon});M:Poll()
shift=true;local frozenReads,frozenNative=stackReads,nativeReads;M:Poll()
assert(stackReads==frozenReads and nativeReads==frozenNative and M.target==cdmIcon,"Shift performs no native sampling")
shift=false
local many={}
for i=1,127 do many[i]=emptyAnchor end
many[128]=auraIcon;scene(many);M:Poll();assert(M.target==auraIcon,"visible region is found after empty native candidates")
-- Rank wins over native list order, without requesting a second native snapshot.
scene({auraIcon,cdmIcon});M:Poll();assert(M.target==auraIcon,"higher frame level wins for native region lists")
scene(many)
debugprofilestop=realProfileClock
collectgarbage("collect");local scanBase=collectgarbage("count");collectgarbage("stop")
local scanStart=os.clock();local maxBatch=0;local samples=100
for i=1,samples do local t=os.clock();M:Poll();maxBatch=math.max(maxBatch,(os.clock()-t)*1000) end
local scanMs=(os.clock()-scanStart)*1000;local scanAllocated=collectgarbage("count")-scanBase
assert(scanAllocated<1024 and frames==warmFrames and regions==warmRegions and enumerations==0,"native sampling stays bounded and creates no UI")
M:Stop();collectgarbage("restart");collectgarbage("collect")
local scanGrowth=collectgarbage("count")-scanBase
assert(scanGrowth<64 and not M:SelectionState().object,"stop releases native candidates")
local stoppedReads,stoppedNative=stackReads,nativeReads;M:Poll();M:UpdatePointer();assert(stackReads==stoppedReads and nativeReads==stoppedNative,"stopped inspector does not sample")
GameTooltip:Show();assert(GameTooltip:IsVisible(),"normal hover returns after inspection stops")
M.stackTooltip:Show();assert(not M.stackTooltip:IsVisible(),"late Show after stop stays hidden")
print(string.format("NativeStack128 samples=%d cpu_ms=%.2f max_sample_ms=%.2f allocated_KiB=%.1f retained_growth_KiB=%.1f new_frames=0",samples,scanMs,maxBatch,scanAllocated,math.max(0,scanGrowth)))
debugprofilestop=function() return 0 end
-- Per-poll limits yield; only the total 512-object cap truncates a sweep.
local overflow=frame(UIParent,"BeyondCandidateBudget")
local overflowReads=0
overflow.IsVisible=function() overflowReads=overflowReads+1;return true end
many={}
for i=1,511 do many[i]=frame(UIParent,"BoundedCandidate"..i) end
many[512]=auraIcon;many[513]=overflow
scene(many);M:Start();assert(M.timer.delay==0.1 and M:SelectionState().pending)
for i=1,5 do M:Poll() end
assert(M.target==auraIcon and M:SelectionState().capped,"capped sweep still reaches its last admitted candidate")
assert(overflowReads==0 and tooltipTouches==0,"candidate cap and isolation from global tooltips")
nativeTarget=emptyAnchor;scene({emptyAnchor});M:Poll()
assert(not M.target and v.hasDiagnostic and M:Report():find("nativeFilter=",1,true),"failed selection has a copyable filter report")
shift=true;M:Poll()
assert(v.copy.frame:IsShown(),"Shift exposes report copying even without a selected target")
assert(M:SelectionState().ready and not M:SelectionState().pending and not v.copy.frame.disabled,"single-poll completed diagnostics must enable Copy")
assert(not v.sourceLabel:IsShown() and not v.parentLabel:IsShown(),"missing target has no empty detail groups")
shift=false;nativeTarget=nil;M:Poll()
local savedNative=C_System.GetFrameStack
C_System.GetFrameStack=function() error("native access unavailable") end
foci={a};M:Poll();assert(M.target==a,"native API failure retains guarded input-focus compatibility")
a:Hide();M:Poll();assert(not M.target,"compatibility path excludes hidden mouse foci")
a:Show();a.alpha=0;M:Poll();assert(not M.target,"compatibility path excludes transparent mouse foci")
a.alpha=1;C_System.GetFrameStack=savedNative
M:Stop();C_System=nil;debugprofilestop=realProfileClock
scene({});foci={a};M:Start()
scene({});cursorX,cursorY=960,540;foci={a};M:Poll()
local forbidden=frame(UIParent,"Forbidden");forbidden.forbidden=true
foci={WorldFrame,forbidden,a};M:Poll()
assert(M.target==a,"invalid first mouse focus must not hide later valid targets")
M:Stop();shift=true;foci={WorldFrame};M:Start()
assert(not M.target and v.frame:GetHeight()==120 and not v.details:IsShown(),"Shift without a target must not expand empty details")
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
UIParent:SetSize(400,220);M:Poll();assert(v.scale>0 and v.frame:GetWidth()*v.scale<=368 and v.frame:GetHeight()*v.scale<=188,"small viewport fits popup")
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
assertOutlineBehindPanel()
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
v.outline:Hide();v.outline:Show();assertOutlineBehindPanel()
assert(v.reportScroll.scrollChild==v.edit and v.edit:GetParent()==v.reportScroll,"report text belongs to a native clipping scroll child")
assert(v.reportHost:IsShown() and not v.confidence:IsShown() and not v.sourceLabel:IsShown() and not v.parent.frame:IsShown(),"report is a separate page")
-- Supply native measured content height; the production UI must use its scroll range,
-- not report byte length (which differs with fonts, locales and wrapping).
v.edit:SetHeight(2400);v.edit.scripts.OnSizeChanged(v.edit)
assert(v.reportBar.frame:IsShown() and v.reportOffset==0)
v.reportScroll.scripts.OnMouseWheel(v.reportScroll,-1);assert(v.reportOffset==36)
v:ScrollTo(99999);assert(v.reportOffset==2140 and v.reportScroll:GetVerticalScroll()==2140)
v:ScrollTo(-999);assert(v.reportOffset==0)
v.edit.scripts.OnCursorChanged(v.edit,0,-2000,8,16);assert(v.reportOffset==1756,"keyboard selection scrolls into view")
assert(60+v.reportHost:GetHeight()<v.frame:GetHeight()-68,"long report viewport cannot reach action row")
UIParent:SetSize(400,220);v:Place(nil,true)
assert(v.scale<1 and v.anchorTop-v.frame:GetHeight()*v.scale>=16,"expanded report fits small viewport")
UIParent:SetSize(1920,1080)
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
combat=true;GameTooltip:Show();assert(GameTooltip:IsVisible(),"tooltip suppression does no protected work on combat entry")
v.frame.scripts.OnEvent(v.frame,"PLAYER_REGEN_DISABLED")
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
M:Start();M.handle:SetAvailability(false)
assert(not M.running and not M.enabled and not M.timer and not v.frame:IsShown())
M.handle:SetAvailability(true)
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
assert(GameTooltip.hookCount==1,"repeated inspection must not accumulate tooltip hooks")
do
    local savedSystem=C_System
    local savedClock=debugprofilestop
    debugprofilestop=function() return 0 end -- Functional scene swaps complete synchronously; real budgets are tested above.
    C_System={GetFrameStack=nativeStack}
    local ring=frame(UIParent,"SC_CursorFrame")
    local paint=frame(ring);paint.kind="Texture";paint.texture="ring"
    ring.visualRegions={paint}
    local gcd=frame(ring,"SC_GCDFrame")
    local swipe=frame(gcd);swipe.kind="Texture";swipe.texture="swipe";gcd.visualRegions={swipe}
    local target=frame(UIParent);target.kind="Texture";target.texture="icon"
    target.location="Interface/AddOns/Example/Main.lua:1"
    SC_CursorFrame=ring
    foci={};cursorX,cursorY=50,50;nativeTarget=ring;scene({ring,paint,gcd,swipe,target})
    M:Start()
    assert(M.target==target,"cursor addon is excluded on the first stationary sample without creation-source records")
    nativeTarget=swipe;M:Poll()
    assert(M.target==target,"anonymous cooldown descendants cannot reclaim the hit")
    scene({ring,paint,gcd,swipe});M:Poll()
    assert(not M.target,"excluded cursor over blank world gives no target")
    RSC_SettingsPanel=frame(UIParent,"RSC_SettingsPanel")
    local setting=frame(RSC_SettingsPanel);setting.kind="Texture";setting.texture="setting"
    assert(not M:CheckFocus(setting),"the explicitly excluded plugin's settings descendants are excluded too")
    SC_EventFrame=frame(nil,"SC_EventFrame")
    assert(not M:CheckFocus(SC_EventFrame),"the plugin's event root is excluded")
    SC_CursorFrame=nil;RSC_SettingsPanel=nil;SC_EventFrame=nil
    assert(M:CheckFocus(ring)==ring,"missing addon globals do not blacklist unrelated objects by name")
    scene({ring,paint,target});nativeTarget=ring;M:Poll()
    assert(M.target==ring,"other cursor overlays keep the ordinary picker behavior")
    SC_CursorFrame=ring;M:Poll()
    assert(M.target==target,"late-created addon root takes effect without restarting inspection")
    M:Stop();C_System=savedSystem;nativeTarget=nil;SC_CursorFrame=nil;scene({})
    debugprofilestop=savedClock
end
-- Opening the search surface must stop picking, its timer and tooltip suppression.
I.NotifyPaletteVisibility(false)
M:Start();assert(M.running and M.timer)
I.NotifyPaletteVisibility(true)
assert(not M.running and not M.timer and not M.target,"search opening stops inspection")
I.NotifyPaletteVisibility(false)

print(string.format("Addon inspector PASS exact/guess/parent/secret/avoidance/copy/Esc/combat/stale/disabled frames=%d regions=%d retained_KiB=%.1f cycles100_ms=%.2f allocated_KiB=%.1f growth_KiB=%.1f idle_work=0",frames-beforeFrames,regions-beforeRegions,retained,elapsed,allocated,math.max(0,growth)))
