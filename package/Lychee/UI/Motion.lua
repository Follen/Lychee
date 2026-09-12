local UI = _G.Lychee.UI
local Motion = {groups={}, limit=96, durations={enter=0.44, exit=0.32, page=0.14, feedback=0.10, resize=0.22}}
UI.Motion=Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
function Motion:IsReduced()
    local store = _G.LycheeInternal and _G.LycheeInternal.CharacterStore
    if store then return store:Palette().reduceMotion==true end
    return self.reduced==true
end
function Motion:Cancel(region,settle)
    if self.brandState and self.brandState.region==region then self:StopBrand() end
    local state=region and (region._lycheeMotion or region._lycheeSlide)
    if not state then return end
    local current=state.to
    if state.playing then current=state.from+(state.to-state.from)*state.alpha:GetSmoothProgress() end
    state.playing=false;state.finished=nil
    state.group:Stop()
    if not combat() then
        if state.slide then
            local x=settle and state.to or current
            region:ClearAllPoints();region:SetPoint("LEFT",state.parent,"LEFT",x,0);region._slideX=x
        else region:SetAlpha(settle and state.to or current) end
    end
end
-- Translation owns only the knob's visual position; no per-frame Lua callback.
function Motion:Slide(region,parent,target,instant)
    if combat() then return end
    local state=region._lycheeSlide
    if state and state.playing and state.group.IsPlaying and not state.group:IsPlaying() then state.playing=false end
    if state and state.playing and state.to==target and not instant and not self:IsReduced() then return end
    if state and state.playing then self:Cancel(region,false) end
    local current=region._slideX or target
    if instant or self:IsReduced() or not region.CreateAnimationGroup or math.abs(current-target)<0.001 then
        if state then state.from,state.to=target,target end
        if region._slideX~=target then
            region:ClearAllPoints();region:SetPoint("LEFT",parent,"LEFT",target,0);region._slideX=target
        end
        return
    end
    if not state then
        if #self.groups>=self.limit then self:Slide(region,parent,target,true);return end
        local group=region:CreateAnimationGroup()
        local animation=group:CreateAnimation("Translation");animation:SetSmoothing("OUT")
        state={region=region,parent=parent,group=group,alpha=animation,slide=true}
        region._lycheeSlide=state;self.groups[#self.groups+1]=state
        group:SetScript("OnFinished",function() if state.playing then self:Cancel(region,true) end end)
    end
    state.from,state.to=current,target
    state.alpha:SetOffset(target-current,0);state.alpha:SetDuration(0.18)
    state.playing=true;state.group:Play()
end
function Motion:Alpha(region,target,duration,finished,initial,smoothing)
    if not region or not region.SetAlpha then if finished then finished() end;return false end
    local state=region._lycheeMotion
    if state and state.playing and state.group.IsPlaying and not state.group:IsPlaying() then
        -- Native interruption can outlive the engine's playback, but not our flag.
        state.playing=false;state.finished=nil
    end
    if state and state.playing and state.to==target and not finished and duration~=0 and not self:IsReduced() and not combat() then return true end
    local current=region.GetAlpha and region:GetAlpha() or 1
    if state and state.playing then
        current=state.from+(state.to-state.from)*state.alpha:GetSmoothProgress()
        self:Cancel(region,false)
    elseif initial then current=initial end
    if combat() or self:IsReduced() or not region.CreateAnimationGroup or duration==0 then
        if state then state.from,state.to,state.playing,state.finished=target,target,false,nil end
        if not combat() then region:SetAlpha(target) end
        if finished then finished() end
        return false
    end
    if math.abs(current-target)<0.001 then
        if state then state.from,state.to,state.playing,state.finished=target,target,false,nil end
        region:SetAlpha(target);if finished then finished() end;return false
    end
    if not state then
        if #self.groups>=self.limit then region:SetAlpha(target);if finished then finished() end;return false end
        local group=region:CreateAnimationGroup()
        local alpha=group:CreateAnimation("Alpha")
        alpha:SetSmoothing("OUT")
        state={region=region,group=group,alpha=alpha,from=current,to=target}
        region._lycheeMotion=state
        self.groups[#self.groups+1]=state
        group:SetScript("OnFinished",function()
            if not state.playing then return end
            state.playing=false
            local callback=state.finished;state.finished=nil
            if not combat() then region:SetAlpha(state.to) end
            if callback then callback() end
        end)
    end
    state.from,state.to,state.finished=current,target,finished
    if math.abs(current-target)<0.001 then region:SetAlpha(target);if finished then finished() end;return false end
    region:SetAlpha(1)
    state.alpha:SetSmoothing(smoothing or "OUT")
    state.alpha:SetFromAlpha(current);state.alpha:SetToAlpha(target);state.alpha:SetDuration(duration or self.durations.feedback)
    state.playing=true;state.group:Play()
    return true
end
function Motion:Reveal(region,kind)
    return self:Alpha(region,1,self.durations[kind or "page"],nil,kind=="enter" and 0 or 0.90)
end
function Motion:Selection(region,selected)
    if not region or not region.SetAlpha then return end
    if region._lycheeSelectedMotion==selected then return end
    region._lycheeSelectedMotion=selected
    if not selected and not region._lycheeMotion then region:SetAlpha(0);region:Hide();return end
    region:Show()
    self:Alpha(region,selected and 1 or 0,self.durations.feedback,nil,selected and 0 or nil)
end
-- Video 20260912-114435 invalidated native Scale/Translation composition here.
-- Own the texture's LOCAL geometry instead. Never transform its parent or text.
-- End time, scale X/Y, upward offset in source pixels, SVG scale/move beziers.
local brandPoses={
    {0.168,1.075,0.925,0,.42,0,.70,1,.42,0,.75,1},
    {0.504,0.960,1.045,7,.16,.6,.25,1,.16,.6,.25,1},
    {0.840,1.035,0.965,0,.30,0,.60,1,.42,0,.60,1},
    {1.092,0.990,1.012,1,.16,.7,.30,1,.16,.7,.30,1},
    {1.386,1,1,0,.20,.7,.30,1,.20,.7,.30,1},
}
local function brandEase(u,x1,y1,x2,y2)
    if u<=0 then return 0 elseif u>=1 then return 1 end
    local low,high,t=0,1,u
    for index=1,16 do
        t=(low+high)*.5
        local v=1-t
        if 3*v*v*t*x1+3*v*t*t*x2+t*t*t<u then low=t else high=t end
    end
    local v=1-t
    return 3*v*v*t*y1+3*v*t*t*y2+t*t*t
end
local function applyBrand(job)
    local fromTime,fromX,fromY,fromOffset=0,1,1,0
    for _,pose in ipairs(brandPoses) do
        if job.elapsed<=pose[1] then
            local u=(job.elapsed-fromTime)/(pose[1]-fromTime)
            local scale=brandEase(u,pose[5],pose[6],pose[7],pose[8])
            local move=brandEase(u,pose[9],pose[10],pose[11],pose[12])
            local sx,sy=fromX+(pose[2]-fromX)*scale,fromY+(pose[3]-fromY)*scale
            local width,height=job.size*sx,job.size*sy
            -- SVG pivot (64,103), source size 128; local CENTER stays at x=size/2.
            local y=job.size/128*(39*(sy-1)+fromOffset+(pose[4]-fromOffset)*move)
            if job.lastWidth~=width or job.lastHeight~=height then
                job.region:SetSize(width,height);job.lastWidth,job.lastHeight=width,height
            end
            if job.lastY~=y then
                job.region:SetPoint("CENTER",job.parent,"LEFT",job.size/2,y);job.lastY=y
            end
            return
        end
        fromTime,fromX,fromY,fromOffset=pose[1],pose[2],pose[3],pose[4]
    end
end
function Motion:StopBrand()
    self.brand=nil
    if self.brandDriver then self.brandDriver:SetScript("OnUpdate",nil);self.brandDriver:Hide() end
    local job=self.brandState
    if not job or not job.region then return end
    job.clock=nil
    -- A protected hierarchy is already hidden by the secure combat handler.
    -- Retain only this bounded reset until the next safe StopAll/Brand call.
    if combat() then return end
    job.region:SetSize(job.size,job.size)
    job.region:ClearAllPoints();job.region:SetPoint("LEFT",job.parent,"LEFT",0,0)
    job.region,job.parent=nil,nil
end
local function brandTick(_,elapsed)
    local job=Motion.brand
    if not job then return end
    if combat() or Motion:IsReduced() or not job.region:IsShown()
        or (job.region.IsVisible and not job.region:IsVisible()) then Motion:StopBrand();return end
    job.elapsed=job.clock and math.max(0,job.clock()-job.started) or job.elapsed+elapsed
    if job.elapsed>=1.386 then Motion:StopBrand() else applyBrand(job) end
end
function Motion:Brand(region,parent,size)
    if not region or not parent then return false end
    if combat() or self:IsReduced() or not region:IsShown()
        or (region.IsVisible and not region:IsVisible()) then
        self:Cancel(region,true);return false
    end
    if self.brand and self.brand.region==region then return false end
    self:StopBrand()
    if not self.brandDriver then self.brandDriver=CreateFrame("Frame");self.brandDriver:Hide() end
    self.brandState=self.brandState or {}
    local job=self.brandState;self.brand=job
    job.region,job.parent,job.size,job.elapsed=region,parent,size or region:GetWidth(),0
    job.clock=type(GetTimePreciseSec)=="function" and GetTimePreciseSec or nil
    job.started=job.clock and job.clock() or 0
    job.lastWidth,job.lastHeight,job.lastY=nil,nil,nil
    region:ClearAllPoints();applyBrand(job)
    self.brandDriver:SetScript("OnUpdate",brandTick);self.brandDriver:Show()
    return true
end
local function heightTick(driver,elapsed)
    local job=Motion.height
    if not job then driver:SetScript("OnUpdate",nil);driver:Hide();return end
    if combat() or not job.region:IsShown() then Motion:StopHeight(false);return end
    job.elapsed=math.min(job.duration,job.elapsed+elapsed)
    local t=job.elapsed/job.duration
    local revision=Motion.heightRevision
    local value=job.from+(job.to-job.from)*(1-(1-t)^3)
    if math.abs(job.region:GetHeight()-value)>0.1 or t==1 then job.region:SetHeight(value) end
    if t==1 and Motion.heightRevision==revision then Motion:StopHeight(false) end
end
function Motion:StopHeight(settle)
    local job=self.height;self.height=nil
    self.heightRevision=(self.heightRevision or 0)+1
    local region,target=job and job.region,job and job.to
    if job then job.region=nil end
    if self.driver then self.driver:SetScript("OnUpdate",nil);self.driver:Hide() end
    if settle and region and not combat() then region:SetHeight(target) end
end
function Motion:Height(region,target)
    if combat() then return end
    if self.height and self.height.region==region and self.height.to==target then return end
    if self:IsReduced() or not region.CreateAnimationGroup or not region:IsShown() then
        self:StopHeight(false);region:SetHeight(target);return
    end
    if math.abs(region:GetHeight()-target)<0.1 then self:StopHeight(false);return end
    if not self.driver then self.driver=CreateFrame("Frame");self.driver:Hide() end
    self.heightState=self.heightState or {}
    local job=self.heightState;self.height=job
    self.heightRevision=(self.heightRevision or 0)+1
    job.region,job.from,job.to,job.elapsed,job.duration=region,region:GetHeight(),target,0,self.durations.resize
    self.driver:SetScript("OnUpdate",heightTick);self.driver:Show()
end
function Motion:StopAll(except)
    if self.brandState and self.brandState.region~=except then self:StopBrand() end
    self:StopHeight(false)
    if self.presence and self.presence.region~=except then self:StopPresence(false) end
    for _,state in ipairs(self.groups) do if state.region~=except then self:Cancel(state.region,true) end end
end
function Motion:SetReduced(reduced)
    local store = _G.LycheeInternal and _G.LycheeInternal.CharacterStore
    if store then store:Palette().reduceMotion=reduced==true else self.reduced=reduced==true end
    self:StopBrand()
    self:StopHeight(true)
    self:StopPresence(true,true)
    -- Settling an exit must also release its window. Ordinary cancellation
    -- intentionally drops callbacks; changing this preference completes them.
    for _,state in ipairs(self.groups) do
        local finished=state.finished
        self:Cancel(state.region,true)
        if finished then finished() end
    end
end
