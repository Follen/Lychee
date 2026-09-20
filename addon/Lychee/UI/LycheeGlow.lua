local I = _G.LycheeInternal
local G = {}
I.LycheeGlow = G
local frame, timer, owner, activeKey
local EMPTY = {}
local function number(value, fallback, low, high)
    if type(value)~="number" or value~=value then return fallback end
    return math.max(low,math.min(high,value))
end
local function stop()
    owner,activeKey=nil,nil
    if timer then timer:Cancel();timer=nil end
    if not frame then return end
    for _,dot in ipairs(frame.dots) do dot.group:Stop() end
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
end
-- Position along a rectangle, clockwise from the upper-left corner.
local function position(distance,w,h)
    local perimeter=2*(w+h)
    distance=distance%perimeter
    if distance<w then return distance,0,1 end
    if distance<w+h then return w,-(distance-w),2 end
    if distance<2*w+h then return 2*w+h-distance,-h,3 end
    return 0,distance-perimeter,4
end
local function layout()
    if not owner then return end
    local w,h=frame:GetWidth(),frame:GetHeight()
    if w<=0 or h<=0 then stop();return end
    for index,dot in ipairs(frame.dots) do
        dot.group:Stop()
        local tail=(index-1)%4
        local phase=math.floor((index-1)/4)*0.5-tail*0.035
        local x,y,edge=position(phase*2*(w+h),w,h)
        dot.texture:ClearAllPoints()
        dot.texture:SetPoint("CENTER",frame,"TOPLEFT",x,y)
        dot.points[1]:SetOffset(0,0)
        for step=1,4 do
            local corner=(edge+step-2)%4+1
            local cx=(corner==1 or corner==2) and w or 0
            local cy=(corner==2 or corner==3) and -h or 0
            dot.points[step+1]:SetOffset(cx-x,cy-y)
        end
        dot.points[6]:SetOffset(0,0)
        if not frame.reduced then dot.group:Play() end
    end
end
local function create()
    frame=CreateFrame("Frame",nil,UIParent)
    frame:Hide();frame:EnableMouse(false)
    frame.dots={}
    for index=1,8 do
        local texture=frame:CreateTexture(nil,"OVERLAY")
        texture:SetTexture("Interface\\Cooldown\\star4")
        texture:SetBlendMode("ADD")
        local group=texture:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local path=group:CreateAnimation("Path")
        path:SetCurveType("NONE");path:SetSmoothing("NONE")
        local points={}
        for order=1,6 do points[order]=path:CreateControlPoint(nil,nil,order) end
        frame.dots[index]={texture=texture,group=group,path=path,points=points}
    end
    frame:SetScript("OnHide",stop)
    frame:SetScript("OnEvent",stop)
    frame:SetScript("OnSizeChanged",layout)
end
-- One active target by design. No LibStub, target fields, hooks or Lua OnUpdate.
-- options: key, color RGBA, frequency (circuits/sec), scale, xOffset/yOffset,
-- frameLevel, duration, cancelEvent, reducedMotion. Start replaces the old lease.
function G:Start(target,options)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not target or not target.IsVisible or not target:IsVisible() then return false end
    options=options or EMPTY
    local key=options.key or ""
    if type(key)~="string" or #key>64 then return false end
    stop()
    if not frame then create() end
    local frequency=number(options.frequency,0.65,0.1,2)
    local scale=number(options.scale,1,0.5,2)
    local color=type(options.color)=="table" and options.color or EMPTY
    local r,g,b,a=number(color[1],1,0,1),number(color[2],0.78,0,1),number(color[3],0.35,0,1),number(color[4],1,0,1)
    local motion=_G.Lychee and _G.Lychee.UI and _G.Lychee.UI.Motion
    frame.reduced=options.reducedMotion==true or motion and motion:IsReduced()
    for index,dot in ipairs(frame.dots) do
        local tail=(index-1)%4
        local size=(16-tail*3)*scale
        dot.texture:SetSize(size,size)
        dot.texture:SetVertexColor(r,g,b,a*(1-tail*0.23))
        dot.path:SetDuration(1/frequency)
    end
    frame:SetParent(target)
    frame:SetFrameLevel(target:GetFrameLevel()+number(options.frameLevel,5,1,20))
    local dx,dy=number(options.xOffset,1,-4,12),number(options.yOffset,1,-4,12)
    frame:SetPoint("TOPLEFT",target,"TOPLEFT",-dx,dy)
    frame:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",dx,-dy)
    owner,activeKey=target,key
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    if options.cancelEvent then frame:RegisterEvent(options.cancelEvent) end
    frame:Show();layout()
    if not owner then return false end
    timer=C_Timer.NewTimer(number(options.duration,3,0.2,10),stop)
    return true
end
function G:Stop(target,key)
    if not owner or target and target~=owner or key and key~=activeKey then return false end
    stop();return true
end
