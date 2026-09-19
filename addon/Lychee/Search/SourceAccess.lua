local I=_G.LycheeInternal
local Access={}
I.Search.SourceAccess=Access

local function cancel(token)
    if token and type(token.Cancel)=="function" then pcall(token.Cancel,token) end
end
function Access:Cancel()
    local state=self.state
    self.state=nil
    if not state then return end
    state.current=false
    for token in pairs(state.tokens) do cancel(token) end
    cancel(state.refresh)
end
function Access:HasFailure()
    return self.state~=nil and self.failures and next(self.failures)~=nil or false
end
function Access:IsPending()
    return self.state~=nil and self.state.pending>0
end
function Access:Begin(raw,context,refresh)
    context=context or {}
    local session,generation=context and context.session,context and context.generation
    if not self.failures or self.raw~=raw or self.session~=session or self.generation~=generation then
        self.failures={};self.raw,self.session,self.generation=raw,session,generation
    end
    local state={current=true,tokens={},pending=0}
    self.state=state
    local beginning=true
    local function changed()
        if beginning or not state.current or state.refresh then return end
        local function deliver()
            state.refresh=nil
            if state.current then refresh() end
        end
        local ok,timer=false,nil
        if C_Timer and type(C_Timer.NewTimer)=="function" then ok,timer=pcall(C_Timer.NewTimer,0,deliver) end
        if ok and timer then state.refresh=timer
        else self.failures.scheduler="SCHEDULER_UNAVAILABLE";deliver() end
    end
    -- A rejected request has no callback. A synchronously completed request
    -- can still return a token; neither case may leave a pending subscription.
    local function request(start,complete,fallback)
        local done,token=false,nil
        state.pending=state.pending+1
        local function finish(result)
            if done or not state.current then return end
            done=true
            if token then state.tokens[token]=nil end
            state.pending=state.pending-1
            complete(result)
        end
        local err
        token,err=start(finish)
        if not state.current then cancel(token)
        elseif not done then
            if token then state.tokens[token]=true
            else finish({error=err and err.code or fallback}) end
        end
    end
    local function selected(id,definition,filter)
        if not I.Search.ProviderPolicy:IsParticipating(id) then return false end
        if filter and filter.excludedSources and filter.excludedSources[id..":records"] then return false end
        if filter and filter.sourceID then return filter.sourceID==id..":records" end
        return I.Search.ProviderPolicy:Configuration(id,definition)==true
    end
    local function prepare(id)
        local entry=I.Providers.entries[id]
        if not state.current or not entry or not entry.definition.prepare or self.failures[id] then return end
        local slots=I.Preparation.jobs[id]
        local key="search\31"..I.Search.RuntimeIdentity:Current().locale
        local ready=slots and slots[key]
        if ready and ready.status=="ready" and ready.entry==entry and ready.revision==entry.revision then return end
        local synchronous=true
        request(function(done)
            return I.Preparation:Ensure({id},{scope="search",intent="query"},context.deadline or I.Providers:QueryTime()+5,done)
        end,function(result)
            local failure=result.error or result.failed and result.failed[id]
            if failure then self.failures[id]=failure end
            if not synchronous then changed() end
        end,"PREPARATION_FAILED")
        synchronous=false
    end
    local wasComplete=not I.AddonDiscovery or I.AddonDiscovery.complete
    local function discovered(result)
        if not state.current then return end
        if result.error then self.failures.discovery=result.error end
        if not wasComplete then I.Search.ProviderPolicy:Invalidate() end
        local _,filter=I.Search.ProviderPolicy:Route(raw,context and context.searchFilter)
        for id,entry in pairs(I.Providers.entries) do
            if selected(id,entry.definition,filter) then prepare(id) end
        end
        for _,row in ipairs(I.AddonDiscovery and I.AddonDiscovery:Definitions() or {}) do
            if not state.current then return end
            if row.selected and not row.reason and not I.Providers.entries[row.id] and not self.failures[row.id] and selected(row.id,row,filter) then
                local id=row.id
                request(function(done)
                    return I.AddonLoader:Ensure({id},context.deadline or I.Providers:QueryTime()+5,done)
                end,function(result)
                    if result.ready and result.ready[id] then prepare(id)
                    else self.failures[id]=result.error or result.failed and result.failed[id] or "LOAD_FAILED" end
                    changed()
                end,"LOAD_FAILED")
            end
        end
        if not wasComplete then changed() end
    end
    if I.AddonDiscovery then
        request(function(done) return I.AddonDiscovery:Scan(done) end,discovered,"DISCOVERY_UNAVAILABLE")
    else discovered({}) end
    beginning=false
end

function Access:QueryReady(entry)
    if not entry.definition.prepare then return true end
    local slots=I.Preparation and I.Preparation.jobs[entry.id]
    local key="search\31"..I.Search.RuntimeIdentity:Current().locale
    local job=slots and slots[key]
    return job and job.status=="ready" and job.entry==entry and job.revision==entry.revision
end
