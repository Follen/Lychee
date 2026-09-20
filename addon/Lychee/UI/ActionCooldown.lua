local I=_G.LycheeInternal
local C={bindings={},groups={},count=0,limit=64}
I.ActionCooldown=C
local events={"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES","BAG_UPDATE_COOLDOWN","SPELLS_CHANGED","PLAYER_REGEN_DISABLED"}
local function visible(owner) return not owner.IsVisible or owner:IsVisible() end
local function current(slot)
    local source=slot.source
    return visible(slot.owner) and source and source._bindingRevision==slot.revision
        and source._bindingIdentity==slot.identity
end
local function render(slot,state)
    local frame=slot.frame
    if state.mode=="duration" and frame.SetCooldownFromDurationObject then
        frame:Show();frame:SetCooldownFromDurationObject(state.durationObject,true)
        slot.start,slot.duration,slot.rate=nil,nil,nil
    elseif state.mode=="numeric" and state.duration>0 then
        frame:Show()
        if slot.start~=state.start or slot.duration~=state.duration or slot.rate~=state.rate then
            frame:SetCooldown(state.start,state.duration,state.rate)
            slot.start,slot.duration,slot.rate=state.start,state.duration,state.rate
        end
    else frame:Hide() end
end
function C:Interest()
    if self.count==0 then
        self.queueToken=(self.queueToken or 0)+1
        if self.timer then self.timer:Cancel();self.timer=nil end
        if self.frame then self.frame:UnregisterAllEvents() end
        self.listening=false
    elseif not self.listening then
        if not self.frame then
            self.frame=CreateFrame("Frame")
            self.frame:SetScript("OnEvent",function(_,event)
                if event=="PLAYER_REGEN_DISABLED" then self:ReleaseAll();return end
                self:Queue()
            end)
        end
        for _,event in ipairs(events) do self.frame:RegisterEvent(event) end
        self.listening=true
    end
end
function C:Release(owner)
    local slot=self.bindings[owner]
    if not slot then return end
    self.bindings[owner]=nil;self.count=self.count-1
    local group=self.groups[slot.key]
    group.count=group.count-1
    if group.count==0 then self.groups[slot.key]=nil end
    slot.frame:Hide()
    slot.frame:SetCooldown(0,0,1)
    slot.start,slot.duration,slot.rate=nil,nil,nil
    slot.source,slot.identity,slot.revision,slot.key=nil,nil,nil,nil
    self:Interest()
end
function C:ReleaseAll()
    for owner in pairs(self.bindings) do self:Release(owner) end
end
local function hidden(owner) C:Release(owner) end
function C:Bind(owner,anchor,action,source)
    local kind,id=I.ActionStatus:Reference(action)
    source=source or owner
    if not kind or not anchor or not source._bindingIdentity or not visible(owner)
        or (InCombatLockdown and InCombatLockdown()) then self:Release(owner);return false end
    local product=I.Search.RuntimeIdentity:Current().product
    local key=product..":"..kind..":"..id
    local old=self.bindings[owner]
    if old and old.key==key and old.source==source and old.revision==source._bindingRevision
        and old.identity==source._bindingIdentity then return true end
    self:Release(owner)
    if self.count>=self.limit then self.lastError="VISIBLE_ACTION_LIMIT";return false end
    local slot=owner._lycheeCooldown
    if not slot then
        local frame=CreateFrame("Cooldown",nil,owner,"CooldownFrameTemplate")
        frame:EnableMouse(false)
        frame:SetHideCountdownNumbers(false)
        slot={owner=owner,frame=frame};owner._lycheeCooldown=slot
        owner:HookScript("OnHide",hidden)
    end
    slot.frame:ClearAllPoints();slot.frame:SetAllPoints(anchor)
    slot.source,slot.identity,slot.revision,slot.key=source,source._bindingIdentity,source._bindingRevision,key
    local group=self.groups[key]
    if not group then
        group={kind=kind,id=id,count=0,state={}};self.groups[key]=group
        local ok=pcall(I.ActionStatus.Read,I.ActionStatus,kind,id,group.state)
        if not ok then group.state.mode=nil;group.state.state="unknown";self.lastError="COOLDOWN_READ_FAILED" end
    end
    group.count=group.count+1;self.bindings[owner]=slot;self.count=self.count+1
    local ok=pcall(render,slot,group.state)
    if not ok then slot.frame:Hide();self.lastError="COOLDOWN_RENDER_FAILED" end
    self:Interest()
    return true
end
function C:Refresh()
    -- Invalidate first, then read each remaining visible reference once.
    for owner,slot in pairs(self.bindings) do if not current(slot) then self:Release(owner) end end
    local stats=self.statistics
    if stats then stats.refreshes=stats.refreshes+1 end
    for _,group in pairs(self.groups) do
        local ok=pcall(I.ActionStatus.Read,I.ActionStatus,group.kind,group.id,group.state)
        if stats then stats.reads=stats.reads+1 end
        if not ok then group.state.mode=nil;group.state.state="unknown";self.lastError="COOLDOWN_READ_FAILED" end
    end
    for _,slot in pairs(self.bindings) do
        local ok=pcall(render,slot,self.groups[slot.key].state)
        if not ok then slot.frame:Hide();self.lastError="COOLDOWN_RENDER_FAILED" end
    end
end
function C:Queue()
    if self.count==0 or self.timer then return end
    if not C_Timer or not C_Timer.NewTimer then self.lastError="SCHEDULER_UNAVAILABLE";return end
    self.queueToken=(self.queueToken or 0)+1
    local token=self.queueToken
    local ok,timer=pcall(C_Timer.NewTimer,0,function()
        if self.queueToken~=token then return end
        self.timer=nil;self:Refresh()
    end)
    if ok then self.timer=timer else self.lastError="SCHEDULER_UNAVAILABLE" end
end
function C:BindRow(row)
    return self:Bind(row,row.icon,I.ActionStatus:Primary(row.item),row)
end
function C:BindMenu(button,action,source)
    if not I.ActionStatus:Reference(action) then self:Release(button.frame);return false end
    if not button.cooldownAnchor then
        button.cooldownAnchor=CreateFrame("Frame",nil,button.frame)
        button.cooldownAnchor:SetSize(20,20);button.cooldownAnchor:SetPoint("RIGHT",button.frame,"RIGHT",-8,0)
    end
    return self:Bind(button.frame,button.cooldownAnchor,action,source)
end
function C:GetDiagnostics()
    local groups=0;for _ in pairs(self.groups) do groups=groups+1 end
    return {bindings=self.count,groups=groups,scheduled=self.timer~=nil,listening=self.listening==true,lastError=self.lastError}
end
function C:SetDiagnostics(enabled) self.statistics=enabled and {refreshes=0,reads=0} or nil end
