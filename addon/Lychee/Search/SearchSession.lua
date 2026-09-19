local I = _G.LycheeInternal

local Session = {
    session = 0,
    generation = 0,
    visible = false,
}
I.Search.Session = Session

local function contextSnapshot(session, generation, filter)
    local source = I.Context and I.Context:Snapshot() or {}
    local context = {}
    for key,value in pairs(source) do context[key]=value end
    context.deadline = (I.Providers and I.Providers:QueryTime() or GetTime and GetTime() or 0)+5
    context.session = session
    context.generation = generation
    context.visible = true
    if type(filter) == "table" then
        context.searchFilter = { categoryID = filter.categoryID, sourceID = filter.sourceID }
    end
    return context
end

-- One delivery owns identity, progress and optional results. Identity-only
-- transitions invalidate old actions without repainting the current page.
function Session:_Publish(results, pending, incomplete)
    self.pending = pending == true
    self.incomplete = incomplete == true
    local palette = self.palette
    if not palette then return false end
    return palette:ApplySearchState(self.session, self.generation, self.pending, results,self.incomplete)
end

function Session:BindPalette(palette)
    if not palette then return false end
    self.palette = palette
    self:_Publish(nil, self.pending,self.incomplete)
    return true
end

function Session:Start()
    if self.visible then return self.session, self.generation end
    self.visible = true
    self.inputSuspended = nil
    self.session = self.session + 1
    self.generation = self.generation + 1
    self:_Publish(nil, false)
    self.homeWarmStarted=nil
    return self.session, self.generation
end

function Session:Invalidate(reason)
    self.generation = self.generation + 1
    local session, generation = self.session, self.generation
    self:CancelHome(reason or "invalidated")
    if session ~= self.session or generation ~= self.generation then return self.generation end
    self:CancelSourceRefresh()
    local query = I.Search.Query
    if query and type(query.Cancel) == "function" and not query:Cancel(reason, generation) then return self.generation end
    if session ~= self.session or generation ~= self.generation then return self.generation end
    self.lastInvalidation = reason
    local palette = self.palette
    self:_Publish(self.visible and palette and palette.visible and {} or nil, false)
    return self.generation
end

function Session:Stop(reason)
    self.inputSuspended = nil
    if not self.visible then
        self:CancelHome(reason or "hidden")
        if I.Search.Query and (I.Search.Query.pending or I.Search.Query.timer) then self:Invalidate(reason or "hidden") end
        return self.session, self.generation
    end
    self.visible = false
    self.session = self.session + 1
    self:Invalidate(reason or "hidden")
    return self.session, self.generation
end

function Session:IsCurrent(session, generation)
    if not self.visible or self.inputSuspended then return false, "STALE_GENERATION" end
    if session and session ~= self.session then return false, "STALE_GENERATION" end
    if generation and generation ~= self.generation then return false, "STALE_GENERATION" end
    return true
end

function Session:_Accept(results, generation, session, pending, incomplete)
    local current = self:IsCurrent(session, generation)
    if not current then return false end
    local palette = self.palette
    if not palette or not palette.visible then return false end
    if pending == nil then pending = I.Providers and I.Providers:HasPendingQuery() or false end
    if incomplete == nil then incomplete = I.Providers and I.Providers.HasQueryFailure and I.Providers:HasQueryFailure() or false end
    return self:_Publish(results, pending,incomplete)
end

-- Preedit is not a query. Cancel outstanding work without replacing the view.
function Session:SuspendInput()
    if not self.visible or self.inputSuspended then return false end
    self.inputSuspended = true
    self.generation = self.generation + 1
    local session, generation = self.session, self.generation
    self:CancelHome("ime-composition")
    if session ~= self.session or generation ~= self.generation then return false end
    self:CancelSourceRefresh()
    local query = I.Search.Query
    if query and not query:Cancel("ime-composition", generation) then return false end
    if session ~= self.session or generation ~= self.generation then return false end
    self:_Publish(nil, false)
    return true
end

function Session:Input(raw)
    if not self.visible then return false, "HIDDEN" end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    local query = I.Search.Query
    if not query then return false, "SEARCH_UNAVAILABLE" end
    local session, generation = self.session, self.generation + 1
    self.generation = generation
    self:CancelHome("input",true)
    if session~=self.session or generation~=self.generation or not self.visible then return false,"STALE_GENERATION" end
    self.inputSuspended = nil
    self:CancelSourceRefresh()
    self.raw = raw or ""

    self.activeFilter = nil
    self:_Publish({}, true)
    local context = contextSnapshot(session, generation)

    if C_Timer and (type(C_Timer.NewTimer) == "function" or type(C_Timer.After) == "function") then
        local scheduledGeneration, scheduled = query:Schedule(raw, context, generation, function(results, completedGeneration, pending, incomplete)
            self:_Accept(results, completedGeneration, session, pending,incomplete)
        end)
        return scheduled, scheduledGeneration
    end

    local completedGeneration, results, operation, pending, incomplete = query:Query(raw, context, generation, function(items, completed, waiting, partial)
        self:_Accept(items, completed, session, waiting,partial)
    end)
    if operation then self:_Accept(results, completedGeneration, session, pending,incomplete) end
    return true, completedGeneration
end

function Session:Filter(filter)
    if not self.visible then return false, "HIDDEN" end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if type(filter) ~= "table" or (not filter.categoryID and not filter.sourceID) then return false, "INVALID_FILTER" end
    local query = I.Search.Query
    if not query then return false, "SEARCH_UNAVAILABLE" end
    local session, generation = self.session, self.generation + 1
    self.generation = generation
    self:CancelHome("filter",true)
    if session~=self.session or generation~=self.generation or not self.visible then return false,"STALE_GENERATION" end
    self.inputSuspended = nil
    self:CancelSourceRefresh()
    self.raw = ""

    self.activeFilter = { categoryID = filter.categoryID, sourceID = filter.sourceID }
    if type(query.Cancel) == "function" and not query:Cancel("filter-change", generation) then return false, "STALE_GENERATION" end
    if not self:IsCurrent(session, generation) then return false, "STALE_GENERATION" end
    self:_Publish({}, true)
    local context = contextSnapshot(session, generation, self.activeFilter)
    local completedGeneration, results, operation, pending, incomplete = query:Query("", context, generation, function(items, completed, waiting, partial)
        self:_Accept(items, completed, session, waiting,partial)
    end)
    if operation then self:_Accept(results, completedGeneration, session, pending,incomplete) end
    return true, completedGeneration
end

function Session:CancelSourceRefresh()
    if self.sourceRefreshTimer then self.sourceRefreshTimer:Cancel(); self.sourceRefreshTimer = nil end
    self.sourceRefreshPending = nil
end

function Session:RefreshSource()
    if not self.sourceRefreshPending then return false end
    self.sourceRefreshPending = nil
    if not self.visible or self.inputSuspended or not self.palette or not self.palette.visible or (InCombatLockdown and InCombatLockdown()) then return false end
    local currentSession, generation = self.session, self.generation
    local context = contextSnapshot(currentSession, generation, self.activeFilter)
    local token, results, operation, pending = I.Search.Query:Query(self.raw or "", context, generation, function(items, completed, waiting)
        self:_Accept(items, completed, currentSession, waiting)
    end)
    return operation and self:_Accept(results, token, currentSession, pending) or false
end

function Session:SourceChanged(reason)
    local palette = self.palette
    if self.homeRefs and self.HomeOwnerChanged then self:HomeOwnerChanged(reason,"updated") end
    self.generation = self.generation + 1
    if I.Search.Query and not I.Search.Query:Cancel("source-" .. tostring(reason or "changed"), self.generation) then
        if palette and palette.MarkHomeDirty then palette:MarkHomeDirty() end
        return
    end
    self:_Publish(nil, self.pending)
    if palette and type(palette.MarkHomeDirty) == "function" then palette:MarkHomeDirty() end
    if not self.visible or self.inputSuspended then return end
    self.sourceRefreshPending = true
    if not self.sourceRefreshTimer and C_Timer and C_Timer.NewTimer then
        local timer
        timer = C_Timer.NewTimer(0, function()
            if self.sourceRefreshTimer ~= timer then return end
            self.sourceRefreshTimer = nil
            self:RefreshSource()
        end)
        self.sourceRefreshTimer = timer
    end
end

function Session:FinishHomeWarm()
    local token=self.homeWarm;self.homeWarm=nil
    if token then token:Cancel() end
end
function Session:CancelHome(reason,keepWarm)
    self.homeEpoch=(self.homeEpoch or 0)+1
    local load,prepare,restore,refresh=self.homeLoad,self.homePrepare,self.homeRestore,self.homeRefresh
    self.homeLoad,self.homePrepare,self.homeRestore,self.homeRefresh=nil,nil,nil,nil
    self.homeRefs,self.homeItems,self.homeStatus=nil,nil,nil
    if not keepWarm then self:FinishHomeWarm() end
    if load then load:Cancel() end
    if prepare then prepare:Cancel() end
    for _,token in ipairs(restore or {}) do if token.Cancel then token:Cancel(reason) end end
    if refresh then refresh:Cancel() end
end
function Session:GetHomeItem(ref)
    local item=self.homeItems and self.homeItems[ref]
    if item and I.Providers:IsCurrent(item) then return item end
end
local homeReasons={
    ADDON_DISABLED="disabled",DISABLED="disabled",
    ADDON_MISSING="missing",UNKNOWN_PROVIDER="missing",MISSING="missing",
    deleted="deleted",TARGET_DELETED="deleted",
    incompatible="incompatible",INCOMPATIBLE_PRODUCT="incompatible",INCOMPATIBLE_ACTION_VERSION="incompatible",
    UNSUPPORTED_CLIENT="incompatible",INTERFACE_VERSION="incompatible",INVALID_STORED_REF="incompatible",
    LOAD_TIMEOUT="timeout",PREPARATION_TIMEOUT="timeout",OPERATION_TIMEOUT="timeout",TIMEOUT="timeout",
    DEPENDENCY_MISSING="dependency",DEPENDENCY_DISABLED="dependency",DEP_MISSING="dependency",DEP_DISABLED="dependency",
    notReady="unavailable",temporarilyUnavailable="unavailable",PROVIDER_UNAVAILABLE="unavailable",
    TARGET_VIEW_UNAVAILABLE="unavailable",ACTION_UNAVAILABLE="unavailable",CAPABILITY_CHANGED="unavailable",
}
local function homeReason(error)
    local code=type(error)=="table" and error.code or error
    return type(code)=="string" and homeReasons[code] or "failed"
end
function Session:GetHomeStatus(ref)
    return self.homeStatus and self.homeStatus[ref]
end
function Session:HomeOwnerChanged(id,state)
    local relevant,restart=false,false
    for _,ref in ipairs(self.homeRefs or {}) do
        if ref.providerID==id then
            relevant=true
            -- A cold package announces enabled inside LoadAddOn. Its existing
            -- load/prepare request already owns completion; do not cancel it.
            if (state~="enabled" and state~="updated") or self:GetHomeStatus(ref)~="pending" then restart=true end
        end
    end
    if not relevant or not restart then return false end
    local items=self.homeItems
    local epoch=(self.homeEpoch or 0)+1
    self:CancelHome("owner-changed",true)
    if self.homeEpoch~=epoch or not self.visible or self.inputSuspended then return false end
    for ref in pairs(items or {}) do if ref.providerID==id then items[ref]=nil end end
    self.homeItems=items
    self:QueueHomeRefresh(epoch)
    return true
end
function Session:QueueHomeRefresh(epoch)
    if self.homeEpoch~=epoch or not self.visible or self.inputSuspended or self.homeRefresh then return end
    if not C_Timer or not C_Timer.NewTimer then return end
    local session,generation=self.session,self.generation
    local ok,timer=pcall(C_Timer.NewTimer,0,function()
        if self.homeEpoch~=epoch then return end
        self.homeRefresh=nil
        local palette=self.palette
        if not self:IsCurrent(session,generation) or not palette or not palette.visible then return end
        if palette.IsHomeVisible and not palette:IsHomeVisible() then return end
        if palette.MarkHomeDirty then palette:MarkHomeDirty() end
    end)
    if ok and timer then self.homeRefresh=timer end
end
function Session:WarmLoaded()
    if not I.Preparation or self.homeWarmStarted or not self.visible or self.inputSuspended then return end
    self.homeWarmStarted=true
    local ids={}
    for id,entry in pairs(I.Providers.entries) do
        if entry.definition.prepare and I.Search.ProviderPolicy:IsParticipating(id) then ids[#ids+1]=id end
    end
    if #ids==0 then return end
    table.sort(ids)
    local complete=false
    local token=I.Preparation:Ensure(ids,{scope="search",intent="prewarm"},(I.Providers and I.Providers:QueryTime() or GetTime and GetTime() or 0)+5,function() complete=true;self.homeWarm=nil end)
    if not complete then self.homeWarm=token end
end
-- Aggregate only this viewport's operation tokens. Clear membership before
-- invoking cancellation because provider cleanup may open a new viewport.
local function cancelHomeOperations(group,reason)
    local tokens=group.tokens;group.tokens={}
    for _,token in pairs(tokens) do token:Cancel(reason) end
end
function Session:HomeReferences(refs)
    if not I.Preparation or not I.AddonLoader or not self.visible or self.inputSuspended or type(refs)~="table" then return end
    if self.palette and self.palette.IsHomeVisible and not self.palette:IsHomeVisible() then return end
    local count=math.min(20,#refs)
    local same=self.homeRefs and #self.homeRefs==count
    if same then for index=1,count do if self.homeRefs[index]~=refs[index] then same=false;break end end end
    if same then return end
    local previousItems=self.homeItems
    local expectedEpoch=(self.homeEpoch or 0)+1
    self:CancelHome("viewport-changed",true)
    if self.homeEpoch~=expectedEpoch or not self.visible or self.inputSuspended then return end
    local epoch,session,generation=self.homeEpoch,self.session,self.generation
    local owned,owners,byID,items,seen={},{},{},{},{}
    for index=1,count do
        local ref=refs[index]
        if type(ref)=="table" and type(ref.providerID)=="string" and #ref.providerID<=64 then
            owned[#owned+1]=ref
            local item=previousItems and previousItems[ref]
            local entry=I.Providers.entries[ref.providerID]
            if not item and not ref.kind and ((entry and not entry.definition.prepare and not entry.definition.addon) or (not entry and ref.sourceID)) then
                item=I.Providers:Resolve(ref,contextSnapshot(session,generation))
            end
            if item and I.Providers:IsCurrent(item) then items[ref]=item
            elseif not seen[ref] then
                seen[ref]=true
                local owner=byID[ref.providerID]
                if not owner then owner={id=ref.providerID,refs={}};byID[owner.id]=owner;owners[#owners+1]=owner end
                owner.refs[#owner.refs+1]=ref
            end
        end
    end
    self.homeRefs,self.homeItems,self.homeRestore,self.homeStatus=owned,items,{},{}
    for _,ref in ipairs(owned) do if not items[ref] then self.homeStatus[ref]="pending" end end
    local function alive() return self.homeEpoch==epoch and self:IsCurrent(session,generation) end
    if #owners==0 then self:WarmLoaded();return end
    local deadline=(I.Providers and I.Providers:QueryTime() or GetTime and GetTime() or 0)+5
    local loads={tokens={},pending=#owners,Cancel=cancelHomeOperations}
    local preparations={tokens={},pending=0,Cancel=cancelHomeOperations}
    self.homeLoad=loads
    local remaining,attaching,warmed=#owners,true,false
    local function warm()
        if not attaching and remaining==0 and not warmed and alive() then warmed=true;self:WarmLoaded() end
    end
    local function finishOwner(owner)
        if owner.done or not alive() then return end
        owner.done=true;remaining=remaining-1
        if owner.preparing then
            preparations.pending=preparations.pending-1
            if preparations.pending==0 then self.homePrepare=nil end
        end
        self:QueueHomeRefresh(epoch);warm()
    end
    local function resolved(owner,ref,item,error)
        if not alive() or self.homeStatus[ref]~="pending" then return end
        if I.Providers:QueryTime()>=deadline then self.homeStatus[ref]="timeout"
        elseif item and I.Providers:IsCurrent(item) then self.homeItems[ref]=item;self.homeStatus[ref]=nil
        elseif type(error)=="table" and error.code=="PENDING" then return
        else self.homeStatus[ref]=homeReason(error or "PROVIDER_UNAVAILABLE") end
        owner.remaining=owner.remaining-1
        self:QueueHomeRefresh(epoch)
        if owner.remaining==0 then finishOwner(owner) end
    end
    local function prepared(owner,state)
        if not alive() or owner.prepared then return end
        owner.prepared=true;preparations.tokens[owner.id]=nil
        for _,ref in ipairs(owner.refs) do
            if not alive() then return end
            if self.homeStatus[ref]=="pending" then
                if state.ready[owner.id] and I.Providers:QueryTime()<deadline then
                    local context=contextSnapshot(session,generation)
                    context.deadline,context.searchBound=deadline,true
                    local item,error,token=I.Providers:Resolve(ref,context,function(value,why)
                        resolved(owner,ref,value,why)
                    end)
                    if not alive() then if token and token.Cancel then token:Cancel("stale-home") end;return end
                    resolved(owner,ref,item,error)
                    if token and token.Cancel then self.homeRestore[#self.homeRestore+1]=token end
                else
                    resolved(owner,ref,nil,state.failed and state.failed[owner.id] or "PROVIDER_UNAVAILABLE")
                end
            end
        end
    end
    local function loaded(owner,state)
        if not alive() or owner.loaded then return end
        owner.loaded=true;loads.tokens[owner.id]=nil;loads.pending=loads.pending-1
        if loads.pending==0 then self.homeLoad=nil end
        if not state.ready[owner.id] then
            for _,ref in ipairs(owner.refs) do resolved(owner,ref,nil,state.failed and state.failed[owner.id] or "PROVIDER_UNAVAILABLE") end
            return
        end
        owner.preparing=true;preparations.pending=preparations.pending+1;self.homePrepare=preparations
        local token,error=I.Preparation:Ensure({owner.id},{scope="restore",intent="visible"},deadline,function(result)
            prepared(owner,result)
        end)
        if not alive() then if token then token:Cancel() end
        elseif not owner.prepared then
            if token then preparations.tokens[owner.id]=token
            else prepared(owner,{ready={},failed={[owner.id]=error or "PROVIDER_UNAVAILABLE"}}) end
        end
    end
    self:QueueHomeRefresh(epoch)
    for _,owner in ipairs(owners) do
        if not alive() then break end
        owner.remaining=#owner.refs
        local token,error=I.AddonLoader:Ensure({owner.id},deadline,function(state) loaded(owner,state) end)
        if not alive() then if token then token:Cancel() end
        elseif not owner.loaded then
            if token then loads.tokens[owner.id]=token
            else loaded(owner,{ready={},failed={[owner.id]=error or "PROVIDER_UNAVAILABLE"}}) end
        end
    end
    attaching=false;warm()
end

if I.Search.StaticIndex and I.Search.StaticIndex.OnChange then
    I.Search.StaticIndex:OnChange(function(_, reason) Session:SourceChanged(reason) end)
end
