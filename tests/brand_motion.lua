-- Lifecycle/object budget tests. Native interpolation is approximated here;
-- this is not evidence of WoW's easing, rendering cost, or protected execution.
Lychee={UI={}};LycheeDB={palette={}}
local combat=false
function InCombatLockdown() return combat end
function CreateFrame() error("brand motion must not create a frame or driver") end
local groups,animations,setters=0,0,0
local Animation={}
function Animation:SetOrder(v) self.order=v end
function Animation:SetDuration(v) self.duration=v end
function Animation:SetSmoothing(v) self.smoothing=v end
function Animation:SetScale(x,y) self.x,self.y=x,y;setters=setters+1 end
function Animation:SetOffset(x,y) self.x,self.y=x,y;setters=setters+1 end
function Animation:SetOrigin(point,x,y) self.origin,self.originX,self.originY=point,x,y;setters=setters+1 end
local Group={}
function Group:SetLooping(v) assert(v=="NONE");self.looping=v end
function Group:IsPlaying() return self.playing end
function Group:Stop() self.playing=false;self.sx,self.sy,self.y=1,1,0 end
function Group:Play() self.playing=true;self.plays=self.plays+1;self.sx,self.sy,self.y=1,1,0 end
function Group:CreateAnimation(kind)
    assert(kind=="Scale" or kind=="Translation")
    animations=animations+1
    local animation=setmetatable({kind=kind},{__index=Animation})
    self.animations[#self.animations+1]=animation
    return animation
end
function Group:At(elapsed)
    local sx,sy,y,start=1,1,0,0
    for order=1,5 do
        local scale,translation
        for _,a in ipairs(self.animations) do
            if a.order==order then if a.kind=="Scale" then scale=a else translation=a end end
        end
        assert(scale and translation and scale.duration==translation.duration)
        local u=math.max(0,math.min(1,(elapsed-start)/scale.duration))
        sx=sx*(1+(scale.x-1)*u);sy=sy*(1+(scale.y-1)*u)
        y=y+translation.y*u;start=start+scale.duration
    end
    self.sx,self.sy,self.y=sx,sy,y
    if elapsed>=start then self:Stop() end
    return sx,sy,y
end
local function createGroup()
    groups=groups+1
    return setmetatable({animations={},playing=false,plays=0,sx=1,sy=1,y=0},{__index=Group})
end
local icon={height=42,shown=true,visible=true}
function icon:IsShown() return self.shown end
function icon:IsVisible() return self.visible end
function icon:GetHeight() return self.height end
function icon:CreateAnimationGroup() return createGroup() end
dofile("package/Lychee/UI/Motion.lua")
local M=Lychee.UI.Motion
function M:StopPresence() end
assert(groups==0 and animations==0)
LycheeDB.palette.reduceMotion=true;assert(not M:Brand(icon))
LycheeDB.palette.reduceMotion=false;combat=true;assert(not M:Brand(icon));combat=false
icon.visible=false;assert(not M:Brand(icon));icon.visible=true
assert(groups==0,"ineligible first plays must not allocate")
collectgarbage("collect");local cold=collectgarbage("count")
assert(M:Brand(icon));local coldGrowth=collectgarbage("count")-cold
assert(coldGrowth<32,"cold Lua substitute budget")
local g=icon._lycheeBrand.group
assert(groups==1 and animations==10 and #M.groups==1)
local initialSetters=setters
for i=1,100 do assert(not M:Brand(icon)) end
assert(g.plays==1 and setters==initialSetters,"hover must not reset or reconfigure an active animation")
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a).." ~= "..tostring(b)) end
-- Independent accepted-preview pose expectations, including Y-axis conversion.
local poses={{.168,1.075,.925,0},{.504,.96,1.045,7*42/128},{.840,1.035,.965,0},{1.092,.99,1.012,42/128},{1.386,1,1,0}}
for _,p in ipairs(poses) do local x,y,offset=g:At(p[1]);near(x,p[2]);near(y,p[3]);near(offset,p[4]) end
near(g.animations[1].originY,42*25/128)
g:At(1.4)
assert(not g:IsPlaying(),"one-shot sequence ends without a timer or OnFinished callback")
assert(M:Brand(icon));g:At(.3);M:StopAll()
assert(not g:IsPlaying() and g.y==0 and g.sx==1 and g.sy==1)
assert(M:Brand(icon));M:SetReduced(true);assert(not g:IsPlaying())
assert(not M:Brand(icon));M:SetReduced(false)
assert(M:Brand(icon));combat=true;M:StopAll();assert(not g:IsPlaying());assert(not M:Brand(icon));combat=false
icon.height=84;assert(M:Brand(icon));local _,_,offset=g:At(.504);near(offset,7*84/128)
M:Cancel(icon,true);icon.height=42;M:Brand(icon);M:Cancel(icon,true)
local warmSetters=setters
collectgarbage("collect");collectgarbage("stop");local before=collectgarbage("count")
for i=1,1000 do M:Brand(icon);M:Brand(icon);M:Cancel(icon,true) end
local temporary=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-before
assert(groups==1 and animations==10 and setters==warmSetters,"replays must reuse objects and geometry parameters")
assert(temporary<64 and retained<8,"replay allocation/retention budget")
assert(not M.driver and not M.presenceDriver,"logo must add no Lua per-frame work")
local blocked={height=42,shown=true,visible=true,_lycheeBrand=false}
setmetatable(blocked,{__index=icon});M.limit=1
assert(not M:Brand(blocked) and not blocked._lycheeBrand,"shared animation pool cap applies")
print(string.format("Brand motion PASS: 1 group / 10 animations; cold %.2f KiB; 1000 replays temporary %.2f KiB, retained %.2f KiB (Lua substitutes)",coldGrowth,temporary,retained))

-- Real Palette/Components/Motion wiring against the existing business harness.
dofile("tests/interaction_smoke.lua")
local p=LycheeInternal.Host.PaletteController
local motion=Lychee.UI.Motion
LycheeDB.palette.reduceMotion=false
p:Hide("brand-test");p:FinishHide("brand-test")
p.brandMark.CreateAnimationGroup=createGroup
assert(p:Show());local native=p.brandMark._lycheeBrand.group
assert(native:IsPlaying(),"opening the real palette must start the logo")
local plays=native.plays
p.settingsButton.scripts.OnEnter();assert(native.plays==plays,"hover during opening is coalesced")
native:At(1.4);p.settingsButton.scripts.OnEnter();assert(native.plays==plays+1,"idle hover replays once")
p:Hide("brand-test");assert(not native:IsPlaying(),"close cancels before the window fade ends")
p.settingsButton.scripts.OnEnter();assert(not native:IsPlaying(),"closing header cannot restart logo")
assert(p:Show());assert(native:IsPlaying(),"rapid reopen reuses the animation")
p.brandComponent.frame.scripts.OnHide();assert(not native:IsPlaying(),"component hide cancels")
p.brandComponent:PlayMotion();motion:SetReduced(true);assert(not native:IsPlaying())
motion:SetReduced(false);p:Hide("brand-test");p:FinishHide("brand-test")
assert(p.brandMark.texture=="Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga","original asset preserved")
print("Brand palette integration PASS: open, hover, close, reopen, component hide, reduced motion")
