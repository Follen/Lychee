-- Native animation boundary simulator: engine interpolation is not a game FPS test.
Lychee={UI={}};LycheeDB={palette={}}
local frames,groups,combat=0,0,false
function InCombatLockdown() return combat end
local methods={}
local function region() return setmetatable({alphaValue=1,height=200,shown=true,scripts={}},{__index=methods}) end
function methods:SetAlpha(v) assert(not combat);self.alphaValue=v end
function methods:GetAlpha() return self.alphaValue end
function methods:SetHeight(v) assert(not combat);self.height=v;if self.onHeight then self.onHeight(v) end end
function methods:GetHeight() return self.height end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:ClearAllPoints() end
function methods:SetPoint(_,_,_,x) self.x=x end
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
dofile("package/Lychee/UI/Palette.lua")
function methods:RegisterEvent() end
function methods:UnregisterEvent() end
local input={text="key"}
function input:SetText(v) self.text=v end
function input:GetText() return self.text end
function input:SetEnabled(v) self.enabled=v end
function input:ClearFocus() end
function input:Focus() end
function input:Show() end
function input:Hide() end
local p=setmetatable({frame=r,input=input,visible=true,list={Clear=function() end},
    focus={Restore=function() end,Clear=function() end},settingsTitle=region(),settingsBack={frame=region()}},Lychee.UI.Palette)
function p:Create() end
function p:ApplyBoundedScale() end
function p:ResizeForMode() end
function p:RefreshHomeSections() end
function p:SetQueryMode() end
r:Show();r:SetAlpha(1)
p:Hide("close")
assert(not p.visible and not input.enabled and p._motionClosing and r:IsShown(),"exit invalidates interaction before fading")
p:Show()
assert(p.visible and input.enabled and not p._motionClosing,"reopen cancels old exit")
s.group.scripts.OnFinished()
assert(p.visible and r:IsShown(),"old exit cannot hide new open")
p:Hide("close");s.group.scripts.OnFinished()
assert(not p.visible and not r:IsShown() and not p._motionClosing,"completed exit releases the window")
print("Palette animated close/reopen PASS")
-- Exercise the actual reusable switch, not just the motion primitive.
function methods:CreateTexture() return region() end
function methods:SetSize() end
function methods:SetWidth() end
function methods:SetAllPoints() end
function methods:SetTexture() end
function methods:SetColorTexture() end
function methods:SetVertexColor() end
dofile("package/Lychee/UI/Theme.lua")
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
