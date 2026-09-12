-- One shared timeline owns geometry and opacity. Opening plays forwards;
-- closing rewinds the identical path, including when interrupted midway.
local Motion = _G.Lychee.UI.Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
Motion.Presets = Motion.Presets or {}
Motion.Presets.palette = {enter=0.42, distance=64, enterAlpha=0.10}
function Motion:ConfigurePresence(layout, anchor, preset)
    anchor.preset=preset or self.Presets.palette
    layout._presenceSpec=anchor
end
local function applyPresence(job)
    local revision=Motion.presenceRevision
    local region,layout=job.region,job.layout
    local spec=layout and layout._presenceSpec
    local preset=spec and spec.preset or Motion.Presets.palette
    local phase=job.phase
    -- Exactly the previously accepted full entrance: 2u-u^2. The reverse
    -- changes only the direction of time, never its spatial or opacity curve.
    local position=phase*(2-phase)
    job.position=position
    job.velocity=job.direction*2*(1-phase)/job.timeSpan
    local u=math.min(1,phase*job.timeSpan/job.fadeDuration)
    local alpha=u*(2-u)
    if spec then
        local scale=job.pixelScale
        local offset=math.floor(-preset.distance*(1-position)*scale+0.5)/scale
        local x,y=spec.x,spec.y+offset
        if job.lastX~=x or job.lastY~=y then
            region:SetPoint(spec.point,spec.relative,spec.relativePoint,x,y)
            if Motion.presenceRevision~=revision then return false end
            job.lastX,job.lastY=x,y
        end
    end
    if job.lastAlpha~=alpha then
        region:SetAlpha(alpha)
        if Motion.presenceRevision~=revision then return false end
        job.lastAlpha=alpha
    end
    return true
end
function Motion:StopPresence(settle,complete)
    local job=self.presence
    if not job then return nil end
    self.presence=nil
    self.presenceRevision=(self.presenceRevision or 0)+1
    local revision=self.presenceRevision
    self.presenceDriver:SetScript("OnUpdate",nil);self.presenceDriver:Hide()
    local phase=job.phase
    local finished=complete and job.finished
    if settle and not combat() then job.phase=job.target;applyPresence(job) end
    if self.presenceRevision~=revision then return phase end
    job.region,job.layout,job.finished,job.clock=nil,nil,nil,nil
    if finished then finished() end
    return phase
end
local function presenceTick(_,elapsed)
    local job=Motion.presence
    if not job then return end
    if combat() or not job.region:IsShown() then Motion:StopPresence(false);return end
    job.elapsed=math.min(job.duration,job.clock and math.max(0,job.clock()-job.started) or job.elapsed+elapsed)
    job.phase=math.max(0,math.min(1,job.from+job.direction*job.elapsed/job.timeSpan))
    if job.elapsed==job.duration then Motion:StopPresence(true,true) else applyPresence(job) end
end
function Motion:Presence(region,shown,finished,initialPhase,layout)
    local target=shown and 1 or 0
    local phase=initialPhase
    if self.presence then
        local revision=self.presenceRevision
        phase=self:StopPresence(false)
        if self.presenceRevision~=revision+1 then return false end
    end
    if phase==nil then phase=shown and 0 or 1 end
    if combat() then return false end
    if phase==target or self:IsReduced() or not region.CreateAnimationGroup or not region.SetScale then
        region:SetAlpha(target)
        if layout and layout._presenceSpec then
            local spec=layout._presenceSpec
            region:SetPoint(spec.point,spec.relative,spec.relativePoint,spec.x,spec.y)
        end
        if finished then finished() end
        return false
    end
    if not self.presenceDriver then self.presenceDriver=CreateFrame("Frame");self.presenceDriver:Hide() end
    self.presenceState=self.presenceState or {}
    local job=self.presenceState;self.presence=job
    self.presenceRevision=(self.presenceRevision or 0)+1
    job.region,job.layout,job.finished=region,layout,finished
    local preset=layout and layout._presenceSpec and layout._presenceSpec.preset or self.Presets.palette
    job.timeSpan,job.fadeDuration=preset.enter,preset.enterAlpha
    job.phase,job.from,job.target,job.direction=phase,phase,target,shown and 1 or -1
    job.elapsed,job.duration=0,math.abs(target-phase)*job.timeSpan
    job.clock=type(GetTimePreciseSec)=="function" and GetTimePreciseSec or nil
    job.started=job.clock and job.clock() or 0
    job.pixelScale=region.GetEffectiveScale and region:GetEffectiveScale() or 1
    if job.pixelScale<=0 then job.pixelScale=1 end
    job.lastX,job.lastY,job.lastAlpha=nil,nil,nil
    if not applyPresence(job) then return false end
    self.presenceDriver:SetScript("OnUpdate",presenceTick);self.presenceDriver:Show()
    return true
end
