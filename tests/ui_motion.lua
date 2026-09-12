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
function methods:CreateAnimationGroup()
    groups=groups+1
    local g={scripts={},playing=false}
    function g:SetScript(k,v) self.scripts[k]=v end
    function g:Stop() self.playing=false end
    function g:IsPlaying() return self.playing end
    function g:Play() self.playing=true;self.a.progress=0 end
    function g:CreateAnimation(kind)
        assert(kind=="Alpha" or kind=="Translation")
        local a={progress=0}
        function a:SetSmoothing(s) self.smoothing=s end
        function a:GetSmoothProgress() return self.progress end
        function a:SetFromAlpha(v) self.from=v end
        function a:SetToAlpha(v) self.to=v end
        function a:SetDuration(v) self.duration=v end
        function a:SetOffset(x,y) self.x,self.y=x,y end
        self.a=a;return a
    end
    return g
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
    if M.presenceDriver and M.presenceDriver.scripts.OnUpdate then
        local width,height,scale=r.width,r.height,r.scale
        M.presenceDriver.scripts.OnUpdate(M.presenceDriver,seconds)
        assert(r.width==width and r.height==height and r.scale==scale,
            "presence cannot resize or rescale the window while moving its input and background")
        local pixels=(r.y-p._presenceSpec.y)*(r.scale or 1)
        assert(math.abs(pixels-math.floor(pixels+0.5))<0.000001,
            "translation preserves the resting font raster phase on physical pixels")
    end
end
p._scale,p._topInset=0.8,24
M:ConfigurePresence(p,{point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=0})
p:ApplyBoundedScale()
r:Show();r:SetAlpha(1)
p:Hide("close")
assert(not p.visible and not input.enabled and p._motionClosing and r:IsShown(),"exit invalidates interaction before motion")
advance(0.05)
local x,v=M.presence.position,M.presence.velocity
local exitAlpha=r:GetAlpha()
p:Show()
assert(r:GetAlpha()==exitAlpha,"opening midway through exit must not flash opacity")
assert(p.visible and input.enabled and not p._motionClosing,"reopen cancels old exit")
assert(M.presence.position==x and M.presence.velocity==v,"reversal preserves position AND velocity")
advance(1)
assert(p.visible and r:IsShown() and r.scale==0.8 and r:GetAlpha()==1,"opening lands precisely")
assert(math.abs(r.y*r.scale+24)<0.001,"search top edge is fixed through scale")
p:Hide("close");advance(0.12)
assert(M.presence and M.presence.position>0.4 and r:GetAlpha()>=0.8,"exit midpoint retains the complete moving panel")
assert(math.abs(M.presence.position-0.5)<0.000001 and r.scale==p._scale and math.abs((r.y-p._presenceSpec.y)*r.scale+26)<0.000001,
    "close translates the complete window by half its distance on physical pixels")
advance(0.119)
assert(M.presence and M.presence.position<0.0001 and r:GetAlpha()<0.02,"close reaches the invisible endpoint continuously before hiding")
advance(1)
assert(not p.visible and not r:IsShown() and not p._motionClosing,"completed exit releases the window")
p:Show()
assert(r.scale==p._scale and r:GetAlpha()==0,"fresh opening never rescales the window")
assert(math.abs((r.y-p._presenceSpec.y)*r.scale+51)<0.001,"the complete window starts below its resting anchor")
advance(0.10)
assert(r:GetAlpha()==1 and M.presence.position<1,"arrival is visible and still in motion after 100 ms")
local openingAlpha=r:GetAlpha()
x,v=M.presence.position,M.presence.velocity
p:Hide("escape")
assert(r:GetAlpha()==openingAlpha,"reversal inherits current opacity independently of travel")
assert(M.presence.position==x and M.presence.velocity==v,"close preserves entrance momentum")
advance(0.03)
local elapsed=M.presence.elapsed
p:Hide("escape")
assert(M.presence.elapsed==elapsed,"repeated close does not restart")
M:SetReduced(true)
assert(not p.visible and not r:IsShown() and not M.presence and not p._motionClosing,"reduced motion completes close")
p:Show()
assert(p.visible and r:GetAlpha()==1 and r.scale==0.8 and not M.presence,"reduced opening is immediate")
assert(r.y==p._presenceSpec.y,"reduced motion restores the complete window to its resting anchor")
p:Hide("close");M:SetReduced(false)
-- Closed form must give the same geometry at 30 and 120 Hz.
p:Show();for i=1,3 do advance(1/30) end
local at30=M.presence.position
M:StopPresence(false);M:Presence(r,true,nil,0,0,p)
for i=1,12 do advance(1/120) end
assert(math.abs(M.presence.position-at30)<0.000001,"motion is frame-rate independent")
M:StopPresence(false);M:Presence(r,false,nil,1,0,p)
for i=1,3 do advance(1/30) end
local exit30=M.presence.position
M:StopPresence(false);M:Presence(r,false,nil,1,0,p)
for i=1,12 do advance(1/120) end
assert(math.abs(M.presence.position-exit30)<0.000001,"dismissal is frame-rate independent too")
combat=true;advance(0.01)
assert(not M.presence and not M.presenceDriver.scripts.OnUpdate,"combat stops before protected setters")
combat=false;p:Hide("cleanup")
M:Presence(r,false,nil,1,0,p)
local staleFinished=0
M.presence.finished=function() staleFinished=staleFinished+1 end
r.onPoint=function()
    r.onPoint=nil
    M:Presence(r,true,nil,0,0,p)
end
M:StopPresence(true,true)
assert(M.presence and M.presence.target==1 and staleFinished==0,"settling layout reentry cannot erase a new animation or fire stale completion")
advance(1)
local paletteGroups,paletteFrames=groups,frames
-- A resumed driver's elapsed value must not advance a newly opened panel by
-- time spent hidden. Compare fresh and warm openings on an independent clock.
do
    local now=100
    GetTimePreciseSec=function() return now end
    p:Hide("clock-reset");now=now+1;advance(1)
    p:Show();now=now+0.016;advance(0.016)
    local cold=M.presence and M.presence.position
    assert(cold and cold<0.5)
    p:Hide("clock-close");now=now+1;advance(1)
    now=now+10
    p:Show();now=now+0.016;advance(10.016)
    assert(M.presence and math.abs(M.presence.position-cold)<0.000001,"warm opening must not consume time spent hidden")
    local samples={0.016,0.06,0.12,0.20,0.30,0.45}
    local baseline={}
    for cycle=1,12 do
        p:Hide("repeat-close");now=now+1;advance(1)
        now=now+cycle
        p:Show()
        local epoch=now
        for index,time in ipairs(samples) do
            now=epoch+time
            advance(index==1 and cycle*10 or 0)
            local top=r.y*r.scale
            if cycle==1 then baseline[index]={r.scale,r:GetAlpha(),top}
            else
                local expected=baseline[index]
                assert(math.abs(r.scale-expected[1])<0.000001 and math.abs(r:GetAlpha()-expected[2])<0.000001 and math.abs(top-expected[3])<0.000001,"each fully closed reopening must reproduce the complete cold entrance trajectory")
            end
        end
        assert(not M.presence and r:GetAlpha()==1 and r.scale==p._scale,"every entrance finishes at its exact baseline")
    end
    p:Hide("clock-done");now=now+1;advance(1)
    GetTimePreciseSec=nil
    print("Palette cold/warm openings PASS 12 cycles x 6 samples; hidden elapsed ignored")
end
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
assert(not M.presenceDriver.scripts.OnUpdate and not M.presenceDriver:IsShown() and not M.presenceState.region and not M.presenceState.finished,"idle retains no active job or callback")
print(string.format("Palette motion cycles1000_KiB=%.2f cpu_ms=%.2f frame_growth=0 group_growth=0 idle_callback=nil",paletteAllocated,paletteCPU))
print("Palette spring close/reopen/velocity/scale/reduced/combat PASS")
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
assert(groups==96 and #M.groups==96,"native groups have a hard capacity")
M:StopAll()
for _,state in ipairs(M.groups) do assert(not state.playing and state.finished==nil) end
