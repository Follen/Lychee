local UI = _G.Lychee.UI
local Motion = {groups={}, limit=96, durations={enter=0.22, exit=0.14, page=0.14, feedback=0.10, resize=0.22}}
UI.Motion=Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
function Motion:IsReduced()
    return LycheeDB and LycheeDB.palette and LycheeDB.palette.reduceMotion==true
end
function Motion:Cancel(region,settle)
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
    self:StopHeight(false)
    for _,state in ipairs(self.groups) do if state.region~=except then self:Cancel(state.region,true) end end
end
function Motion:SetReduced(reduced)
    LycheeDB.palette=LycheeDB.palette or {}
    LycheeDB.palette.reduceMotion=reduced==true
    self:StopHeight(true)
    -- Settling an exit must also release its window. Ordinary cancellation
    -- intentionally drops callbacks; changing this preference completes them.
    for _,state in ipairs(self.groups) do
        local finished=state.finished
        self:Cancel(state.region,true)
        if finished then finished() end
    end
end
