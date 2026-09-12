-- Geometry boundary regression derived from 20260912-103056.mp4.
-- Models the observed per-region Scale behavior, not a full WoW renderer.
Lychee={UI={}};LycheeCharacterDB={palette={}}
LycheeInternal={};dofile("addon/Lychee/Core/CharacterStore.lua")
local methods={}
local function node(parent) return setmetatable({parent=parent,points={},width=640,height=508,alpha=1,shown=true,scripts={}},{__index=methods}) end
local function fraction(point)
    local x=point:find('LEFT') and 0 or (point:find('RIGHT') and 1 or 0.5)
    local y=point:find('BOTTOM') and 0 or (point:find('TOP') and 1 or 0.5)
    return x,y
end
function methods:SetPoint(p,relative,rp,x,y) self.points[p]={relative,rp,x or 0,y or 0} end
function methods:GetRect()
    if self.fixed then return unpack(self.fixed) end
    local left,right,bottom,top,cx,cy
    for point,anchor in pairs(self.points) do
        local l,b,w,h=anchor[1]:GetRect()
        local rx,ry=fraction(anchor[2]);local sx,sy=fraction(point)
        local x,y=l+w*rx+anchor[3],b+h*ry+anchor[4]
        if sx==0 then left=x elseif sx==1 then right=x else cx=x end
        if sy==0 then bottom=y elseif sy==1 then top=y else cy=y end
    end
    local w=left and right and right-left or self.width
    local h=bottom and top and top-bottom or self.height
    return left or (right and right-w) or cx-w/2,bottom or (top and top-h) or cy-h/2,w,h
end
function methods:VisualRect()
    local x,y,w,h=self:GetRect()
    local group=self.parent and self.parent.native
    if group and group.playing and group.scale then
        local a=group.scale;local factor=a.from+(a.to-a.from)*a.progress
        return x+w*(1-factor)/2,y+h*(1-factor)/2,w*factor,h*factor
    end
    return x,y,w,h
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetTexture() end
function methods:SetTexCoord() end
function methods:SetColorTexture() end
function methods:SetVertexColor() end
function methods:CreateTexture() return node(self) end
function methods:SetAlpha(a) self.alpha=a end
function methods:GetAlpha() return self.alpha end
function methods:SetScale() error('font/layout scale must remain fixed') end
function methods:GetEffectiveScale() return 1 end
function methods:IsShown() return self.shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:CreateAnimationGroup()
    local g=dofile('tests/support/native_animation.lua')();self.native=g
    local create=g.CreateAnimation
    function g:CreateAnimation(kind)
        local a=create(self,kind)
        if kind=='Scale' then self.scale=a end
        return a
    end
    return g
end
function CreateFrame() return node() end
function InCombatLockdown() return false end
UIParent=node();UIParent.fixed={0,0,1920,1080}
dofile('addon/Lychee/UI/Theme.lua')
dofile('addon/Lychee/UI/Motion.lua')
dofile(arg[1] or 'addon/Lychee/UI/Presence.lua')
local root=node(UIParent)
root:SetPoint('TOP',UIParent,'TOP',0,-200)
local surface=Lychee.UI.Theme:CreateRoundedSurface(root,'background',10)
local content=node(root);content:SetPoint('TOPLEFT',root,'TOPLEFT',12,-56)
local M=Lychee.UI.Motion
local layout={};M:ConfigurePresence(layout,{point='TOP',relative=UIParent,relativePoint='TOP',x=0,y=-200})
local function check()
    local ml,_,mw=surface.regions[1]:VisualRect()
    local ll,_,lw=surface.regions[2]:VisualRect()
    local rl=surface.regions[3]:VisualRect()
    assert(math.abs(ml-(ll+lw))<0.00001,'left background seam split during presence')
    assert(math.abs(ml+mw-rl)<0.00001,'right background seam split during presence')
    local x,y,_,h=root:GetRect();local cx,cy,_,ch=content:GetRect()
    assert(cx==x+12 and cy+ch==y+h-56,'content moved independently of root')
end
for _,opening in ipairs({true,false}) do
    M:Presence(root,opening,nil,nil,layout)
    for i=1,12 do
        if M.presenceDriver then
            if M.presence then M.presenceDriver.scripts.OnUpdate(M.presenceDriver,1/60) end
        elseif M.presence then
            M.presence.scale.progress=i/13;M.presence.alpha.progress=i/13
        end
        check()
    end
    M:StopPresence(true)
end
print('Presence geometry PASS: joined surface edges and content-relative position during both directions')
