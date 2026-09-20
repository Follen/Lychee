local I = _G.LycheeInternal
local G = {}
I.LycheeGlow = G
local frame, timer, owner, activeKey
local EMPTY = {}
local PARTICLES = 32
local function number(value, fallback, low, high)
    if type(value)~="number" or value~=value then return fallback end
    return math.max(low,math.min(high,value))
end
local function stop()
    owner,activeKey=nil,nil
    if timer then timer:Cancel();timer=nil end
    if not frame then return end
    if frame.proc then
        frame.burstGroup:Stop();frame.loopGroup:Stop()
        frame.burst:Hide();frame.loop:Hide()
    else
        for _,dot in ipairs(frame.dots) do dot.group:Stop() end
    end
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
    if frame.proc then
        frame.burst:SetSize(w*2.2*frame.scale,h*2.2*frame.scale)
        frame.loop:SetSize(w*1.35*frame.scale,h*1.35*frame.scale)
        return
    end
    for index,dot in ipairs(frame.dots) do
        dot.group:Stop()
        local phase=(index-1)/PARTICLES
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
local function flipbook(texture,period,repeatAnimation)
    local group=texture:CreateAnimationGroup()
    if repeatAnimation then group:SetLooping("REPEAT") end
    local animation=group:CreateAnimation("FlipBook")
    animation:SetDuration(period)
    animation:SetFlipBookRows(6);animation:SetFlipBookColumns(5)
    animation:SetFlipBookFrames(30)
    animation:SetFlipBookFrameWidth(0);animation:SetFlipBookFrameHeight(0)
    return group,animation
end
local function create()
    frame=CreateFrame("Frame",nil,UIParent)
    frame:Hide();frame:EnableMouse(false)
    frame.proc=WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID==WOW_PROJECT_MAINLINE
    if frame.proc then
        frame.burst=frame:CreateTexture(nil,"OVERLAY")
        frame.burst:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
        frame.burst:SetBlendMode("ADD");frame.burst:SetPoint("CENTER")
        frame.loop=frame:CreateTexture(nil,"OVERLAY")
        frame.loop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
        frame.loop:SetPoint("CENTER")
        frame.burstGroup=flipbook(frame.burst,0.3,false)
        frame.loopGroup,frame.loopAnimation=flipbook(frame.loop,0.85,true)
        frame.burstGroup:SetScript("OnFinished",function()
            if not owner or not frame:IsShown() or frame.reduced then return end
            frame.burst:Hide();frame.loop:Show();frame.loopGroup:Play()
        end)
    else
    frame.dots={}
    for index=1,PARTICLES do
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
    end
    frame:SetScript("OnHide",stop)
    frame:SetScript("OnEvent",stop)
    frame:SetScript("OnSizeChanged",layout)
end
-- One active target by design. No LibStub, target fields, hooks or Lua OnUpdate.
-- options: key, color RGBA, frequency (cycles/sec), scale, xOffset/yOffset,
-- frameLevel, duration, cancelEvent, reducedMotion. Start replaces the old lease.
function G:Start(target,options)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not target or not target.IsVisible or not target:IsVisible() then return false end
    options=options or EMPTY
    local key=options.key or ""
    if type(key)~="string" or #key>64 then return false end
    stop()
    if not frame then create() end
    local frequency=number(options.frequency,0.55,0.1,2)
    local scale=number(options.scale,1,0.5,2)
    local color=type(options.color)=="table" and options.color or EMPTY
    local r,g,b,a=number(color[1],1,0,1),number(color[2],0.78,0,1),number(color[3],0.35,0,1),number(color[4],1,0,1)
    local motion=_G.Lychee and _G.Lychee.UI and _G.Lychee.UI.Motion
    frame.reduced=options.reducedMotion==true or motion and motion:IsReduced()
    frame.scale=scale
    if frame.proc then
        frame.burst:SetVertexColor(1,1,1,a)
        frame.loop:SetVertexColor(1,1,1,a)
        if options.color then
            frame.burst:SetDesaturated(true);frame.loop:SetDesaturated(true)
            frame.burst:SetVertexColor(r,g,b,a);frame.loop:SetVertexColor(r,g,b,a)
        else
            frame.burst:SetDesaturated(false);frame.loop:SetDesaturated(false)
        end
        frame.loopAnimation:SetDuration(options.frequency and 1/frequency or 0.85)
    else
    for index,dot in ipairs(frame.dots) do
        local accent=index%4==1
        local size=(accent and 10 or 7)*scale
        dot.texture:SetSize(size,size)
        dot.texture:SetVertexColor(r,g,b,a*(accent and 1 or 0.8))
        dot.path:SetDuration(1/frequency)
    end
    end
    frame:SetParent(target)
    frame:SetFrameLevel(target:GetFrameLevel()+number(options.frameLevel,5,1,20))
    local dx,dy=number(options.xOffset,frame.proc and 0 or 1,-4,12),number(options.yOffset,frame.proc and 0 or 1,-4,12)
    frame:SetPoint("TOPLEFT",target,"TOPLEFT",-dx,dy)
    frame:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",dx,-dy)
    owner,activeKey=target,key
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    if options.cancelEvent then frame:RegisterEvent(options.cancelEvent) end
    frame:Show();layout()
    if not owner then return false end
    if frame.proc then
        if frame.reduced then
            frame.burst:Hide();frame.loop:SetTexCoord(0,0.2,0,1/6);frame.loop:Show()
        else
            frame.loop:Hide();frame.burst:Show();frame.burstGroup:Play()
        end
    end
    timer=C_Timer.NewTimer(number(options.duration,3,0.2,10),stop)
    return true
end
function G:Stop(target,key)
    if not owner or target and target~=owner or key and key~=activeKey then return false end
    stop();return true
end
