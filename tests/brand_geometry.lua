-- Video 20260912-114435: native Scale/Translation moved the logo outside
-- the header while its parent was stationary. Check actual local geometry,
-- not the old substitute's assumed native transform composition.
Lychee={UI={}};LycheeCharacterDB={palette={}}
LycheeInternal={};dofile("addon/Lychee/Core/CharacterStore.lua")
local combat,now,frames,setters=false,0,0,0
function InCombatLockdown() return combat end
function GetTimePreciseSec() return now end
local function noop() end
function CreateFrame()
    frames=frames+1
    local f={scripts={},shown=false}
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    return f
end
local parent={x=650,y=800,scale=1}
local icon={width=42,height=42,shown=true,visible=true,parent=parent}
function icon:IsShown() return self.shown end
function icon:IsVisible() return self.visible end
function icon:GetWidth() return self.width end
function icon:GetHeight() return self.height end
function icon:CreateAnimationGroup() error("recording regression: native logo transforms must not be used") end
function icon:ClearAllPoints() assert(not combat);self.point=nil;setters=setters+1 end
function icon:SetSize(w,h) assert(not combat);self.width,self.height=w,h;setters=setters+1 end
function icon:SetPoint(point,relative,relativePoint,x,y)
    assert(not combat);assert(relative==parent and relativePoint=="LEFT")
    assert(point=="CENTER" or point=="LEFT")
    self.point,self.x,self.y=point,x,y;setters=setters+1
end
local function center()
    return icon.x+(icon.point=="LEFT" and icon.width/2 or 0),icon.y
end
dofile("addon/Lychee/UI/Motion.lua")
local M=Lychee.UI.Motion
M.StopPresence=noop
assert(frames==0)
LycheeCharacterDB.palette.reduceMotion=true;assert(not M:Brand(icon,parent,42));LycheeCharacterDB.palette.reduceMotion=false
combat=true;assert(not M:Brand(icon,parent,42));combat=false
icon.visible=false;assert(not M:Brand(icon,parent,42));icon.visible=true
assert(frames==0,"ineligible first plays stay lazy")
collectgarbage("collect");local cold=collectgarbage("count")
assert(M:Brand(icon,parent,42));local coldGrowth=collectgarbage("count")-cold
assert(frames==1 and #M.groups==0,"one reusable driver, no native logo groups")
local driver=M.brandDriver
local function tick(seconds)
    now=now+seconds
    if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver,seconds) end
end
local function near(a,b) assert(math.abs(a-b)<.003,tostring(a).." ~= "..tostring(b)) end
local function resting()
    assert(not M.brand and not driver.shown and not driver.scripts.OnUpdate)
    near(icon.width,42);near(icon.height,42);near(icon.x,0);near(icon.y,0)
    assert(icon.point=="LEFT" and not M.brandState.region and not M.brandState.parent)
end
local start=M.brand.started
assert(not M:Brand(icon,parent,42) and M.brand.started==start,"hover cannot restart an active play")
-- Accepted SVG pose endpoints and local center positions, independently fixed.
local poses={{.168,45.15,38.85,-.959765625},{.504,40.32,43.89,2.872734375},{.840,43.47,40.53,-.447890625},{1.092,41.58,42.504,.4816875},{1.386,42,42,0}}
for _,p in ipairs(poses) do
    now=start+p[1];driver.scripts.OnUpdate(driver,0)
    near(icon.width,p[2]);near(icon.height,p[3]);local x,y=center();near(x,21);near(y,p[4])
end
tick(.01);resting()
-- Translation of the parent and screen scaling must never enter local offsets.
local samples=0
for _,fps in ipairs({30,60,144}) do
    for _,screenScale in ipairs({.65,1,1.5}) do
        for _,screenX in ipairs({-1200,0,1400}) do
            parent.x,parent.scale=screenX,screenScale
            assert(M:Brand(icon,parent,42))
            for i=1,math.ceil(1.4*fps) do
                parent.y=800-i*.7;tick(1/fps)
                local x,y=center()
                near(x,21)
                assert(math.abs(y)<4 and icon.width>=40 and icon.width<=46 and icon.height>=38 and icon.height<=44,
                    "every rendered logo pose stays within its local header bounds")
                local actualX=screenX+x*screenScale
                near(actualX,screenX+21*screenScale)
                samples=samples+1
            end
            resting()
        end
    end
end
assert(M:Brand(icon,parent,42));tick(.4);M:Cancel(icon,true);resting()
assert(M:Brand(icon,parent,42));tick(.4);M:SetReduced(true);resting();assert(not M:Brand(icon,parent,42));M:SetReduced(false)
assert(M:Brand(icon,parent,42));tick(.4);icon.visible=false;tick(.01);resting();icon.visible=true
assert(M:Brand(icon,parent,42));tick(.4);combat=true;local beforeStop=setters;M:StopAll()
assert(setters==beforeStop and not M.brand and not driver.scripts.OnUpdate,"combat stops without protected setters")
combat=false;now=now+600;assert(M:Brand(icon,parent,42));tick(.01)
assert(M.brand.elapsed<.02,"hidden wall time is excluded from a warm opening")
M:StopAll();resting()
collectgarbage("collect");collectgarbage("stop");local before=collectgarbage("count");local startCPU=os.clock()
for i=1,1000 do M:Brand(icon,parent,42);for step=1,90 do tick(1/60) end;M:StopAll() end
local cpu=(os.clock()-startCPU)*1000;local temporary=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-before
assert(frames==1 and temporary<64 and retained<8 and coldGrowth<32)
resting()
print(string.format("Brand geometry PASS: %d bounded poses; 1 driver / 0 animation groups; cold %.2f KiB; 1000 plays %.2f ms, allocated %.2f KiB, retained %.2f KiB (offline)",samples,coldGrowth,cpu,temporary,retained))
