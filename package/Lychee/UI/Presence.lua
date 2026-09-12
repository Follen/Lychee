-- Native visual transforms keep the entire window together without changing
-- frame scale, anchors, font sizes or the content's layout/clipping hierarchy.
local Motion = _G.Lychee.UI.Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
Motion.Presets = Motion.Presets or {}
Motion.Presets.palette = {
    enter=0.42, exit=0.24, enterScale=0.88, exitScale=0.90, enterAlpha=0.12,
}
function Motion:ConfigurePresence(layout, anchor, preset)
    anchor.preset=preset or self.Presets.palette
    layout._presenceSpec=anchor
end

-- Read the engine's independent tracks before Stop resets their transforms.
local function sample(job)
    return job.fromScale+(job.toScale-job.fromScale)*job.scale:GetSmoothProgress(),
        job.fromAlpha+(job.toAlpha-job.fromAlpha)*job.alpha:GetSmoothProgress()
end
function Motion:StopPresence(settle,complete)
    local job=self.presence
    if not job then return nil,nil end
    local scale,alpha=sample(job)
    local region,target,finished=job.region,job.toAlpha,complete and job.finished
    self.presence=nil
    self.presenceRevision=(self.presenceRevision or 0)+1
    local revision=self.presenceRevision
    job.region,job.layout,job.finished=nil,nil,nil
    job.group:Stop()
    if self.presenceRevision~=revision then return scale,alpha end
    if settle and not combat() then region:SetAlpha(target) end
    if self.presenceRevision==revision and finished then finished() end
    return scale,alpha
end
local function finishedPresence(group)
    local job=Motion.presence
    if job and job.group==group then Motion:StopPresence(true,true) end
end

function Motion:Presence(region,shown,finished,initialScale,initialAlpha,layout)
    if self.presence then
        local revision=self.presenceRevision
        initialScale,initialAlpha=self:StopPresence(false)
        if self.presenceRevision~=revision+1 then return false end
    end
    if combat() then return false end
    local target=shown and 1 or 0
    local job=self.presenceState
    -- This is a single-window channel with one bounded native group, not a pool
    -- indexed by transient rows or provider identities.
    if self:IsReduced() or not region.CreateAnimationGroup or (job and job.owner~=region) then
        region:SetAlpha(target)
        if finished then finished() end
        return false
    end
    if not job then
        local group=region:CreateAnimationGroup()
        local scale=group:CreateAnimation("Scale")
        local alpha=group:CreateAnimation("Alpha")
        scale:SetOrder(1);alpha:SetOrder(1)
        scale:SetOrigin("CENTER",0,0)
        job={owner=region,group=group,scale=scale,alpha=alpha}
        self.presenceState=job
        group:SetScript("OnFinished",finishedPresence)
    end
    local preset=layout and layout._presenceSpec and layout._presenceSpec.preset or self.Presets.palette
    local fromScale=initialScale or (shown and preset.enterScale or 1)
    local fromAlpha=initialAlpha or (shown and 0 or 1)
    local toScale=shown and 1 or preset.exitScale
    local duration=shown and preset.enter or preset.exit
    local smoothing=shown and "OUT" or "IN"
    job.scale:SetScaleFrom(fromScale,fromScale);job.scale:SetScaleTo(toScale,toScale)
    job.scale:SetDuration(duration);job.scale:SetSmoothing(smoothing)
    job.alpha:SetFromAlpha(fromAlpha);job.alpha:SetToAlpha(target)
    job.alpha:SetDuration(shown and preset.enterAlpha or duration);job.alpha:SetSmoothing(smoothing)
    -- Underlying alpha stays at one; native Alpha supplies the visual opacity.
    -- Completion settles alpha and hides an exiting window in the same callback.
    local revision=self.presenceRevision
    region:SetAlpha(1)
    if self.presenceRevision~=revision then return false end
    self.presenceRevision=(self.presenceRevision or 0)+1
    job.region,job.layout,job.finished=region,layout,finished
    job.fromScale,job.toScale,job.fromAlpha,job.toAlpha=fromScale,toScale,fromAlpha,target
    self.presence=job
    job.group:Play()
    return true
end
