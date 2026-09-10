-- Native animation boundary simulator: engine interpolation is not a game FPS test.
Lychee={UI={}};LycheeDB={palette={}}
local frames,groups,combat=0,0,false
function InCombatLockdown() return combat end
local methods={}
local function region() return setmetatable({alphaValue=1,height=200,shown=true,scripts={}},{__index=methods}) end
function methods:SetAlpha(v) assert(not combat);self.alphaValue=v end
function methods:GetAlpha() return self.alphaValue end
function methods:SetHeight(v) assert(not combat);self.height=v end
function methods:GetHeight() return self.height end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetScript(k,v) self.scripts[k]=v end
function CreateFrame() frames=frames+1;return region() end
function methods:CreateAnimationGroup()
    groups=groups+1
    local g={scripts={},playing=false}
    function g:SetScript(k,v) self.scripts[k]=v end
    function g:Stop() self.playing=false end
    function g:Play() self.playing=true;self.a.progress=0 end
    function g:CreateAnimation(kind)
        assert(kind=="Alpha")
        local a={progress=0}
        function a:SetSmoothing(s) self.smoothing=s end
        function a:GetSmoothProgress() return self.progress end
        function a:SetFromAlpha(v) self.from=v end
        function a:SetToAlpha(v) self.to=v end
        function a:SetDuration(v) self.duration=v end
        self.a=a;return a
    end
    return g
end
dofile("package/Lychee/UI/Motion.lua")
local M=Lychee.UI.Motion
assert(frames==0 and groups==0,"cold motion has zero engine objects")
local r=region()
M:Selection(r,false);assert(groups==0 and not r:IsShown())
M:Selection(r,true);local s=r._lycheeMotion
assert(groups==1 and s.from==0 and s.to==1)
s.alpha.progress=0.4
M:Selection(r,false);assert(math.abs(s.from-0.4)<0.001 and s.to==0,"reverse starts from displayed alpha")
s.group.scripts.OnFinished();assert(r:GetAlpha()==0 and not s.playing)
M:Selection(r,true);s.group.scripts.OnFinished()
M:Selection(r,true);assert(not s.playing,"same selected state does not replay")
local called=0
M:Alpha(r,0,0.1,function() called=called+1 end)
M:Cancel(r,true);s.group.scripts.OnFinished();assert(called==0,"cancel discards completion")
M:Height(r,400);M.driver.scripts.OnUpdate(M.driver,0.1)
local mid=r:GetHeight();assert(mid>200 and mid<400)
M:Height(r,250);assert(r:GetHeight()==mid,"retarget preserves actual height")
M.driver.scripts.OnUpdate(M.driver,0.3)
assert(r:GetHeight()==250 and not M.height and not M.driver.scripts.OnUpdate and not M.driver:IsShown())
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
for i=1,100 do M:Reveal(region()) end
assert(groups==96 and #M.groups==96,"native groups have a hard capacity")
M:StopAll()
for _,state in ipairs(M.groups) do assert(not state.playing and state.finished==nil) end
