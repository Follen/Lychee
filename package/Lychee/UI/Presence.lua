-- One rigid window owns the background, text and hit-test tree. Presence changes
-- only its anchor and opacity; no scaling, resizing or outer content clipping.
local Motion = _G.Lychee.UI.Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
Motion.Presets = Motion.Presets or {}
Motion.Presets.palette = {
    enter=0.44, exit=0.32, distance=44, launchVelocity=2.6,
}
function Motion:ConfigurePresence(layout, anchor, preset)
    anchor.preset=preset or self.Presets.palette
    layout._presenceSpec=anchor
end
local function smooth(value)
    value=math.max(0,math.min(1,value))
    return value*value*(3-2*value)
end
local function applyPresence(job)
    local revision=Motion.presenceRevision
    local region,layout=job.region,job.layout
    local spec=layout and layout._presenceSpec
    local preset=spec and spec.preset or Motion.Presets.palette
    local position=job.position
    local alpha=smooth(position)
    if spec then
        -- Preserve the resting glyph raster phase. Move the complete hierarchy
        -- by integral physical pixels instead of rescaling or moving its parts.
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
    if not job then return 0,0 end
    self.presence=nil
    self.presenceRevision=(self.presenceRevision or 0)+1
    local revision=self.presenceRevision
    self.presenceDriver:SetScript("OnUpdate",nil);self.presenceDriver:Hide()
    local position,velocity=job.position,job.velocity
    local finished=complete and job.finished
    if settle and not combat() then job.position,job.velocity=job.target,0;applyPresence(job) end
    if self.presenceRevision~=revision then return position,velocity end
    job.region,job.layout,job.finished,job.clock=nil,nil,nil,nil
    if finished then finished() end
    return position,velocity
end
local function presenceTick(_,elapsed)
    local job=Motion.presence
    if not job then return end
    if combat() or not job.region:IsShown() then Motion:StopPresence(false);return end
    -- Each playback owns its epoch. A resumed driver's elapsed value must not
    -- charge hidden time to a new entrance; fallback supports minimal adapters.
    job.elapsed=math.min(job.duration,job.clock and math.max(0,job.clock()-job.started) or job.elapsed+elapsed)
    local t=job.elapsed
    -- Full-duration Hermite motion, with velocity preserved through reversal.
    local u=t/job.duration
    local u2,u3=u*u,u*u*u
    local delta=job.target-job.from
    job.position=job.from+delta*(3*u2-2*u3)+job.fromVelocity*job.duration*(u3-2*u2+u)
    job.velocity=delta*(6*u-6*u2)/job.duration+job.fromVelocity*(3*u2-4*u+1)
    if job.position<0 or job.position>1 then
        job.position=math.max(0,math.min(1,job.position));job.velocity=0
    end
    if t==job.duration then Motion:StopPresence(true,true) else applyPresence(job) end
end
function Motion:Presence(region,shown,finished,initial,velocity,layout)
    local target=shown and 1 or 0
    local position=initial
    if self.presence then position,velocity=self:StopPresence(false) end
    if position==nil then position=shown and 0 or 1 end
    if combat() then return false end
    if self:IsReduced() or not region.CreateAnimationGroup or not region.SetScale then
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
    local duration=shown and preset.enter or preset.exit
    if shown and position==0 and (velocity or 0)==0 then velocity=preset.launchVelocity/duration end
    job.position,job.velocity,job.from,job.fromVelocity=position,velocity or 0,position,velocity or 0
    job.target,job.elapsed,job.duration=target,0,duration
    job.clock=type(GetTimePreciseSec)=="function" and GetTimePreciseSec or nil
    job.started=job.clock and job.clock() or 0
    job.pixelScale=region.GetEffectiveScale and region:GetEffectiveScale() or 1
    if job.pixelScale<=0 then job.pixelScale=1 end
    job.lastX,job.lastY,job.lastAlpha=nil,nil,nil
    if not applyPresence(job) then return false end
    self.presenceDriver:SetScript("OnUpdate",presenceTick);self.presenceDriver:Show()
    return true
end
