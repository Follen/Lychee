-- Window presence is a separate channel from control feedback. The persistent
-- text/hit-test tree never changes geometry; only an empty decorative shell does.
local Motion = _G.Lychee.UI.Motion
local function combat() return InCombatLockdown and InCombatLockdown() end
Motion.Presets = Motion.Presets or {}
Motion.Presets.palette = {
    enter=0.44, exit=0.32, widthFrom=0.90, heightFrom=0.82, offsetY=24,
    opaqueAt=0.30, contentFrom=0.20, contentTo=0.88, launchVelocity=2.6,
}
function Motion:ConfigurePresence(layout, surface, content, preset, viewport)
    layout._presenceSpec={surface=surface,content=content,preset=preset or self.Presets.palette,viewport=viewport}
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
    local alpha=smooth(position/preset.opaqueAt)
    if spec then
        local surface=spec.surface
        local width=region:GetWidth()*(preset.widthFrom+(1-preset.widthFrom)*position)
        local height=region:GetHeight()*(preset.heightFrom+(1-preset.heightFrom)*position)
        if job.lastWidth~=width or job.lastHeight~=height then
            surface:SetSize(width,height)
            if Motion.presenceRevision~=revision then return false end
            if spec.viewport then
                spec.viewport:SetSize(width,height)
                if Motion.presenceRevision~=revision then return false end
            end
            job.lastWidth,job.lastHeight=width,height
        end
        local offset=-preset.offsetY*(1-position)
        if job.lastOffset~=offset then
            surface:SetPoint("CENTER",region,"CENTER",0,offset)
            if Motion.presenceRevision~=revision then return false end
            if spec.viewport then
                spec.viewport:SetPoint("CENTER",region,"CENTER",0,offset)
                if Motion.presenceRevision~=revision then return false end
            end
            job.lastOffset=offset
        end
        local contentAlpha=smooth((position-preset.contentFrom)/(preset.contentTo-preset.contentFrom))
        if job.lastContentAlpha~=contentAlpha then
            for index=1,#spec.content do
                spec.content[index]:SetAlpha(contentAlpha)
                if Motion.presenceRevision~=revision then return false end
            end
            job.lastContentAlpha=contentAlpha
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
            spec.surface:SetSize(region:GetWidth(),region:GetHeight())
            spec.surface:SetPoint("CENTER",region,"CENTER",0,0)
            if spec.viewport then
                spec.viewport:SetSize(region:GetWidth(),region:GetHeight())
                spec.viewport:SetPoint("CENTER",region,"CENTER",0,0)
            end
            for index=1,#spec.content do spec.content[index]:SetAlpha(1) end
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
    job.lastWidth,job.lastHeight,job.lastOffset,job.lastAlpha,job.lastContentAlpha=nil,nil,nil,nil,nil
    if not applyPresence(job) then return false end
    self.presenceDriver:SetScript("OnUpdate",presenceTick);self.presenceDriver:Show()
    return true
end
