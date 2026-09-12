-- Native animation boundary simulator: engine interpolation is not a game FPS test.
Lychee={UI={}};LycheeDB={palette={}}
local frames,groups,combat=0,0,false
function InCombatLockdown() return combat end
local methods={}
local function region() return setmetatable({alphaValue=1,width=640,height=200,shown=true,scripts={}},{__index=methods}) end
function methods:GetWidth() return self.width end
function methods:SetSize(w,h) assert(not combat);self.width,self.height=w,h;if self.onSize then self.onSize(w,h) end end
function methods:SetScale(v) assert(not combat);self.scale=v end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetAlpha(v) assert(not combat);self.alphaValue=v end
function methods:GetAlpha() return self.alphaValue end
function methods:SetHeight(v) assert(not combat);self.height=v;if self.onHeight then self.onHeight(v) end end
function methods:GetHeight() return self.height end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:ClearAllPoints() end
function methods:SetPoint(_,_,_,x,y) self.x,self.y=x,y;if self.onPoint then self.onPoint(x,y) end end
function CreateFrame() frames=frames+1;return region() end
local nativeGroup=dofile("tests/native_animation.lua")
function methods:CreateAnimationGroup()
    groups=groups+1
    return nativeGroup()
end
dofile("package/Lychee/UI/Motion.lua")
dofile("package/Lychee/UI/Presence.lua")
local M=Lychee.UI.Motion
assert(frames==0 and groups==0,"cold motion has zero engine objects")
local knob,parent=region(),region()
M:Slide(knob,parent,2,true)
assert(groups==0 and knob.x==2,"binding is immediate and does not allocate animations")
M:Slide(knob,parent,16)
local slide=knob._lycheeSlide
slide.alpha.progress=0.5
M:Slide(knob,parent,2)
assert(knob.x==9 and slide.from==9 and slide.alpha.x==-7,"rapid reversal preserves displayed position")
slide.group.scripts.OnFinished()
assert(knob.x==2 and not slide.playing)
M:Slide(knob,parent,16);M:Slide(knob,parent,2,true)
slide.group.scripts.OnFinished()
assert(knob.x==2 and not slide.playing,"rebind cancels old movement")
M:Slide(knob,parent,16);M:SetReduced(true)
assert(knob.x==16 and not slide.playing,"reduced motion settles thumb")
M:SetReduced(false)
M:Slide(knob,parent,2)
slide.group:Stop()
M:Slide(knob,parent,2)
assert(slide.group:IsPlaying(),"interrupted slide must restart for the same target")
M:Cancel(knob,true)
local groupBaseline=groups
local r=region()
M:Selection(r,false);assert(groups==groupBaseline and not r:IsShown())
M:Selection(r,true);local s=r._lycheeMotion
assert(groups==groupBaseline+1 and s.from==0 and s.to==1)
s.alpha.progress=0.4
M:Selection(r,false);assert(math.abs(s.from-0.4)<0.001 and s.to==0,"reverse starts from displayed alpha")
s.group.scripts.OnFinished();assert(r:GetAlpha()==0 and not s.playing)
M:Selection(r,true);s.group.scripts.OnFinished()
M:Selection(r,true);assert(not s.playing,"same selected state does not replay")
local called=0
M:Alpha(r,0,0.1)
M:Alpha(r,0,0)
assert(r:GetAlpha()==0 and not s.playing,"instant same-target request must settle a running fade")
M:Alpha(r,1,0)
M:Alpha(r,0,0.1)
s.group:Stop()
M:Alpha(r,0,0.1)
assert(s.group:IsPlaying(),"native interruption must not leave same-target requests stuck")
M:Alpha(r,1,0)
M:Alpha(r,0,0.1,function() called=called+1 end)
M:Cancel(r,true);s.group.scripts.OnFinished();assert(called==0,"cancel discards completion")
M:Height(r,400);M.driver.scripts.OnUpdate(M.driver,0.1)
local mid=r:GetHeight();assert(mid>200 and mid<400)
M:Height(r,250);assert(r:GetHeight()==mid,"retarget preserves actual height")
M.driver.scripts.OnUpdate(M.driver,0.3)
assert(r:GetHeight()==250 and not M.height and not M.driver.scripts.OnUpdate and not M.driver:IsShown())
r.onHeight=function(v) if v==400 then M:Height(r,450) end end
M:Height(r,400);M.driver.scripts.OnUpdate(M.driver,0.3)
assert(M.height and M.height.to==450,"completion must preserve a resize started by its size callback")
r.onHeight=nil;M.driver.scripts.OnUpdate(M.driver,0.3)
assert(r:GetHeight()==450 and not M.height)
r.onHeight=function(v) if v==400 then M:Height(r,475) end end
M:Height(r,400);M:StopHeight(true)
assert(M.height and M.height.region==r and M.height.to==475,"settling must not clear a reentrant task's region")
r.onHeight=nil;M.driver.scripts.OnUpdate(M.driver,0.3)
assert(r:GetHeight()==475 and not M.height)
M:Height(r,500);combat=true;M.driver.scripts.OnUpdate(M.driver,0.1)
assert(not M.height and not M.driver.scripts.OnUpdate,"combat cancels without setters")
combat=false;M:Height(r,500);M:SetReduced(true)
assert(r:GetHeight()==500 and not M.height,"reduce motion settles geometry")
M:Reveal(r);assert(r:GetAlpha()==1 and not s.playing)
M:SetReduced(false)
local objectCount=groups
collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count");local start=os.clock()
for i=1,2000 do M:Selection(r,i%2==0) end
local allocation=collectgarbage("count")-before
local alphaCPU=(os.clock()-start)*1000
collectgarbage("restart")
assert(groups==objectCount and allocation<512,"retargeting has bounded allocation")
M:StopAll();assert(not s.playing and not M.height)
M:Height(r,600);M:StopHeight(false)
collectgarbage("collect");collectgarbage("stop")
before=collectgarbage("count");start=os.clock()
for i=1,2000 do
    M:Height(r,i%2==0 and 250 or 500)
    if M.height then M.driver.scripts.OnUpdate(M.driver,0.3) end
end
local heightAllocation=collectgarbage("count")-before
collectgarbage("restart")
assert(heightAllocation<512 and frames==1 and not M.height and M.heightState.region==nil)
print(string.format("Height motion cycles2000_KiB=%.2f cpu_ms=%.2f idle_callback=%s",heightAllocation,(os.clock()-start)*1000,tostring(M.driver.scripts.OnUpdate)))
print(string.format("UI motion PASS frames=%d groups=%d alpha2000_KiB=%.2f cpu_ms=%.2f",frames,groups,allocation,alphaCPU))
-- Real Palette close/reopen orchestration with the native-animation boundary.
LycheeInternal={Search={}}
Lychee.UI.Theme={Metrics={rowHeight=46}}
Lychee.UI.ResultList={HideTooltip=function() end}
dofile("package/Lychee/Search/Normalizer.lua")
local createFrameForMotion=CreateFrame
CreateFrame=nil
dofile("package/Lychee/Bootstrap.lua")
CreateFrame=createFrameForMotion
dofile("package/Lychee/UI/Palette.lua")
function methods:RegisterEvent() end
function methods:UnregisterEvent() end
local input={text="key"}
function input:SetText(v) self.text=v end
function input:GetText() return self.text end
function input:SetEnabled(v) self.enabled=v end
function input:SetVisualFrozen(v) self.visualFrozen=v end
function input:ClearFocus() end
function input:Focus() end
function input:Show() end
function input:Hide() end
local p=setmetatable({frame=r,input=input,visible=true,list={Clear=function() end},
    focus={Restore=function() end,Clear=function() end},settingsTitle=region(),settingsBack={frame=region()}},Lychee.UI.Palette)
function p:Create() end
function p:ApplyBoundedScale()
    self.frame:SetScale(self._scale)
    self._presenceSpec.y=-self._topInset/self._scale
    self.frame:SetPoint("TOP",UIParent,"TOP",0,self._presenceSpec.y)
end
function p:ResizeForMode() end
function p:RefreshHomeSections() end
function p:SetQueryMode() end
local function advance(seconds)
    local width,height,scale,x,y=r.width,r.height,r.scale,r.x,r.y
    if M.presence then M.presence.group:Advance(seconds) end
    assert(r.width==width and r.height==height and r.scale==scale and r.x==x and r.y==y,
        "native visual motion must never mutate the layout or font raster settings")
end
local function visual()
    local j=M.presence
    if not j then return 1,r:GetAlpha() end
    return j.fromScale+(j.toScale-j.fromScale)*j.scale:GetSmoothProgress(),
        j.fromAlpha+(j.toAlpha-j.fromAlpha)*j.alpha:GetSmoothProgress()
end
p._scale,p._topInset=0.8,24
M:ConfigurePresence(p,{point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=0})
p:ApplyBoundedScale()
r:Show();r:SetAlpha(1)
p:Hide("close")
assert(groups==objectCount+1 and frames==1 and #M.presenceState.group.animations==2,
    "presence cold creation is bounded to one group and two tracks, no frame")
assert(M.presenceState.scale.origin=="CENTER" and M.presenceState.group==M.presence.group)
assert(not p.visible and not input.enabled and input.visualFrozen and p._motionClosing and r:IsShown(),"exit invalidates input but preserves its visual state")
advance(0.05)
local x,a=visual()
p:Show()
assert(p.visible and input.enabled and not input.visualFrozen and not p._motionClosing,"reopen restores input")
assert(M.presence.fromScale==x and M.presence.fromAlpha==a,"reversal samples both native tracks before Stop resets them")
advance(1)
assert(p.visible and r:IsShown() and r.scale==0.8 and r:GetAlpha()==1 and not M.presence,"opening lands precisely")
p:Hide("close");advance(0.10)
x,a=visual()
assert(x<1 and x>0.90 and a>0.5 and r:IsShown(),"closing moves while the entire window remains visible")
advance(1)
assert(not p.visible and not r:IsShown() and not p._motionClosing,"completed exit releases the window")
p:Show()
assert(M.presence.fromScale<0.95 and M.presence.fromAlpha==0 and r.scale==p._scale,"fresh opening starts visibly smaller without changing frame scale")
advance(0.12)
x,a=visual()
assert(a==1 and x<0.97,"panel becomes opaque early enough to see the remaining expansion")
p:Hide("escape")
assert(M.presence.fromScale==x and M.presence.fromAlpha==a,"closing samples the opening's current transform")
advance(0.03)
local elapsed=M.presence.group.elapsed
p:Hide("escape")
assert(M.presence.group.elapsed==elapsed,"repeated close does not restart")
M:SetReduced(true)
assert(not p.visible and not r:IsShown() and not M.presence and not p._motionClosing,"reduced motion completes close")
p:Show()
assert(p.visible and r:GetAlpha()==1 and r.scale==0.8 and not M.presence,"reduced opening is immediate")
p:Hide("close");M:SetReduced(false)
p:Show();combat=true;M:StopAll()
assert(not M.presence and not M.presenceState.group:IsPlaying(),"combat cancellation has no protected setters")
combat=false;p:Hide("cleanup");advance(1)
-- Stop may invoke native hooks. A reentrant playback owns its own completion.
p:Show()
local staleFinished=0
M.presence.finished=function() staleFinished=staleFinished+1 end
M.presence.group.onStop=function()
    M.presenceState.group.onStop=nil
    M:Presence(r,true,nil,nil,nil,p)
end
M:StopPresence(true,true)
assert(M.presence and M.presence.toAlpha==1 and staleFinished==0,"stop reentry cannot settle or complete the new animation")
advance(1)
-- A setter can also trigger external code during settle.
p:Hide("reentry");local setAlpha=methods.SetAlpha
r.SetAlpha=function(self,value)
    r.SetAlpha=nil
    setAlpha(self,value)
    M:Presence(r,true,nil,nil,nil,p)
end
M:StopPresence(true,true)
assert(M.presence and M.presence.toAlpha==1 and r:IsShown(),"settle reentry cannot run a stale exit completion")
advance(1);p._motionClosing=nil;p.visible=true
local paletteGroups,paletteFrames=groups,frames
local samples={0.016,0.06,0.12,0.20,0.30,0.45}
local baseline={}
for cycle=1,12 do
    p:Hide("repeat-close");advance(1)
    -- Idle time cannot affect playback: native Play resets both tracks.
    M.presenceState.group:Advance(1000)
    p:Show()
    local previous=0
    for index,time in ipairs(samples) do
        advance(time-previous);previous=time
        local scale,alpha=visual()
        if cycle==1 then baseline[index]={scale,alpha}
        else
            assert(math.abs(scale-baseline[index][1])<0.000001 and math.abs(alpha-baseline[index][2])<0.000001,
                "warm openings reproduce the full cold entrance after idle")
        end
    end
    assert(not M.presence and r:GetAlpha()==1 and r.scale==p._scale)
end
p:Hide("clock-done");advance(1)
print("Palette cold/warm openings PASS 12 cycles x 6 samples; native playback resets")
collectgarbage("collect");collectgarbage("stop")
local paletteBase=collectgarbage("count")
local started=os.clock()
for i=1,1000 do
    p:Show();advance(0.05);p:Hide("toggle")
    advance(0.03);p:Show();for tick=1,54 do advance(1/120) end
    p:Hide("escape");for tick=1,39 do advance(1/120) end
end
local paletteCPU=(os.clock()-started)*1000
local paletteAllocated=collectgarbage("count")-paletteBase
collectgarbage("restart")
assert(groups==paletteGroups and frames==paletteFrames and paletteAllocated<512 and not M.presence,"warm cycles are bounded")
assert(not M.presenceDriver and not M.presenceState.group:IsPlaying() and not M.presenceState.region and not M.presenceState.finished,"idle retains no active job or callback")
print(string.format("Palette motion cycles1000_KiB=%.2f cpu_ms=%.2f frame_growth=0 group_growth=0 idle_callback=nil",paletteAllocated,paletteCPU))
print("Palette native scale/alpha/reversal/layout/reduced/combat PASS")
-- Exercise the actual reusable switch, not just the motion primitive.
function methods:CreateTexture() return region() end
function methods:SetSize() end
function methods:SetWidth() end
function methods:SetAllPoints() end
function methods:SetTexture() end
function methods:SetColorTexture() end
function methods:SetVertexColor() end
dofile("package/Lychee/UI/Theme.lua")
dofile("package/Lychee/UI/Runtime.lua")
dofile("package/Lychee/UI/Components.lua")
local toggle=Lychee.UI.Components:CreateToggle(parent)
toggle:SetChecked(false,true)
assert(toggle.bg:GetAlpha()==0 and toggle.knob:GetAlpha()==1 and toggle.knob.x==2)
toggle:SetChecked(true)
assert(toggle.knob._lycheeSlide.playing and toggle.bg._lycheeMotion.playing)
toggle.scripts.OnHide()
assert(not toggle.knob._lycheeSlide.playing and not toggle.bg._lycheeMotion.playing)
local switchGroups=groups
collectgarbage("collect");collectgarbage("stop")
before=collectgarbage("count")
for i=1,2000 do toggle:SetChecked(i%2==0) end
local switchAllocation=collectgarbage("count")-before
collectgarbage("restart")
assert(groups==switchGroups and switchAllocation<512)
toggle:FinishMotion()
print(string.format("Switch PASS cycles2000_KiB=%.2f group_growth=0",switchAllocation))
for i=1,100 do M:Reveal(region()) end
assert(groups==97 and #M.groups==96,"native groups have a hard capacity")
M:StopAll()
for _,state in ipairs(M.groups) do assert(not state.playing and state.finished==nil) end
