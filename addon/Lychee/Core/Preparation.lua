local I=_G.LycheeInternal
local P={jobs={},requests={},requestCount=0,slotCount=0,sequence=0,diagnostics={}}
I.Preparation=P
local priorities={query=1,visible=2,prewarm=3}
local function clock() return I.Providers:QueryTime() end
local function cancel(token,reason) if token and type(token.Cancel)=="function" then pcall(token.Cancel,token,reason) end end
local function current(id) return I.Providers.entries[id] end
local function enabled(id) return I.Registry:IsEnabled(id) end
local function identity() return I.Search.RuntimeIdentity:Current() end
local function diagnostic(job,code)
    P.diagnostics[#P.diagnostics+1]={providerID=job.id,code=code}
    if #P.diagnostics>32 then table.remove(P.diagnostics,1) end
end
local function removeSlot(job)
    local slots=P.jobs[job.id]
    if slots and slots[job.key]==job then
        slots[job.key]=nil;P.slotCount=P.slotCount-1
        if not next(slots) then P.jobs[job.id]=nil end
    end
end
local function valid(job)
    return job.entry and current(job.id)==job.entry and job.entry.revision==job.revision and identity().locale==job.locale and enabled(job.id)
end
local finishJob,finishRequest,pump,schedule
local function closeJob(job,reason)
    local resources,cleanup=job.resources,job.cleanup
    job.resources,job.cleanup,job.context=nil,nil,nil
    if job.status~="ready" then job.entry=nil end
    if resources then I.Resources:Close(resources,reason) end
    if cleanup then pcall(cleanup,reason) end
end
local function reprioritize(job)
    local priority,deadline=3,0
    for request in pairs(job.subscribers) do
        priority=math.min(priority,request.priority)
        deadline=math.max(deadline,request.deadline)
    end
    job.priority=priority
    if job.context then job.context.deadline=deadline end
    if job.status=="active" and priority==3 then
        local optional=0
        for _,slots in pairs(P.jobs) do for _,other in pairs(slots) do
            if other~=job and other.status=="active" and other.priority==3 then optional=optional+1 end
        end end
        -- A query leaving shared work must not silently expand optional work.
        if optional>=2 then finishJob(job,"failed","PREWARM_LIMIT") end
    end
end
local function detach(request,job)
    request.jobs[job]=nil;job.subscribers[request]=nil
    if not next(job.subscribers) and job.status~="ready" then
        removeSlot(job);job.status="cancelled";closeJob(job,"cancelled")
    else reprioritize(job) end
end
local function release(request)
    if request.done then return end
    request.done=true;P.requests[request]=nil;P.requestCount=P.requestCount-1
    local timer=request.timer;request.timer=nil
    local jobs=request.jobs;request.jobs={}
    -- Detach every subscriber before invoking any third-party cancellation.
    for job in pairs(jobs) do job.subscribers[request]=nil end
    cancel(timer)
    for job in pairs(jobs) do
        if not next(job.subscribers) and job.status~="ready" then removeSlot(job);job.status="cancelled";closeJob(job,"cancelled")
        else reprioritize(job) end
    end
    request.ids,request.waiting=nil,nil
end
finishRequest=function(request)
    if request.done or request.attaching or request.remaining>0 then return end
    local callback,result=request.callback,{ready=request.ready,failed=request.failed}
    request.callback,request.ready,request.failed=nil,nil,nil
    release(request)
    if callback then pcall(callback,result) end
end
local function expire(request,reason)
    if request.done then return end
    for id in pairs(request.waiting) do request.failed[id]=reason end
    request.remaining=0;finishRequest(request)
end
finishJob=function(job,status,code)
    if job.status=="ready" or job.status=="failed" or job.status=="cancelled" then return end
    if not valid(job) then status,code="failed","STALE_PREPARATION" end
    job.status=status
    if status~="ready" then removeSlot(job);diagnostic(job,code or "PREPARATION_FAILED") end
    local subscribers=job.subscribers;job.subscribers={}
    -- Close the old scope before any subscriber can reenter with a new task.
    closeJob(job,status=="ready" and "ready" or code)
    if status=="ready" and not valid(job) then
        status,code="failed","STALE_PREPARATION"
        removeSlot(job);job.status="failed";job.entry=nil
    end
    for request in pairs(subscribers) do
        if not request.done and request.waiting[job.id]==job then
            request.jobs[job]=nil;request.waiting[job.id]=nil;request.remaining=request.remaining-1
            if clock()>=request.deadline then request.failed[job.id]="PREPARATION_TIMEOUT"
            elseif status=="ready" then request.ready[job.id]=true
            else request.failed[job.id]=code or "PREPARATION_FAILED" end
            finishRequest(request)
        end
    end
    schedule()
end
local function run(job)
    if job.status~="queued" then return end
    if not valid(job) then finishJob(job,"failed","STALE_PREPARATION");return end
    job.status="active"
    local resources,err=I.Providers:CreateOperationResources(job.id)
    if not resources then finishJob(job,"failed",err and err.code or "RESOURCE_LIMIT");return end
    job.resources=resources
    local client=identity()
    job.context={product=client.product,locale=client.locale,interface=client.interface,build=tonumber(client.build),publicscope=job.scope,resources=resources}
    reprioritize(job)
    local function reply(result)
        if job.status~="active" then return nil,{code="STALE_PREPARATION"} end
        if not I.Boundary:Validate(result,"preparation.result",{maxDepth=1,maxFields=2,maxNodes=5,maxBytes=256,scalarKeys=true}) or type(result)~="table" then finishJob(job,"failed","INVALID_PREPARATION");return nil,{code="INVALID_PREPARATION"} end
        for key in pairs(result) do if key~="status" and key~="code" then finishJob(job,"failed","INVALID_PREPARATION");return nil,{code="INVALID_PREPARATION"} end end
        if (result.status~="ready" and result.status~="failed") or (result.code~=nil and (type(result.code)~="string" or #result.code>96)) then
            finishJob(job,"failed","INVALID_PREPARATION");return nil,{code="INVALID_PREPARATION"}
        end
        finishJob(job,result.status,result.code)
        return true
    end
    local ok,result=pcall(job.entry.definition.prepare,job.context,reply)
    if not ok then if job.status=="active" then finishJob(job,"failed","PREPARATION_ERROR") end
    elseif type(result)=="function" then
        if job.status=="active" then job.cleanup=result else pcall(result,job.status) end
    elseif result~=nil and job.status=="active" then reply(result) end
end
local function nextJob()
    local chosen,prewarm= nil,0
    for _,slots in pairs(P.jobs) do for _,job in pairs(slots) do
        if job.status=="active" and job.priority==3 then prewarm=prewarm+1 end
    end end
    for _,slots in pairs(P.jobs) do for _,job in pairs(slots) do
        if job.status=="queued" and (job.priority<3 or prewarm<2)
            and (not chosen or job.priority<chosen.priority or job.priority==chosen.priority and job.sequence<chosen.sequence) then chosen=job end
    end end
    return chosen
end
schedule=function()
    if P.pumping or P.timer or P.schedulingFailure then return end
    if not nextJob() then return end
    if not C_Timer or type(C_Timer.NewTimer)~="function" then
        P.schedulingFailure=true
        local jobs={}
        for _,slots in pairs(P.jobs) do for _,job in pairs(slots) do if job.status=="queued" then jobs[#jobs+1]=job end end end
        for _,job in ipairs(jobs) do finishJob(job,"failed","SCHEDULER_UNAVAILABLE") end
        P.schedulingFailure=nil
        return
    end
    P.timerEpoch=(P.timerEpoch or 0)+1
    local epoch=P.timerEpoch
    local ok,timer=pcall(C_Timer.NewTimer,0,function() if P.timerEpoch==epoch then P.timer=nil;pump() end end)
    if ok and timer then P.timer=timer
    else
        P.schedulingFailure=true
        local jobs={};for _,slots in pairs(P.jobs) do for _,job in pairs(slots) do if job.status=="queued" then jobs[#jobs+1]=job end end end
        for _,job in ipairs(jobs) do finishJob(job,"failed","SCHEDULER_UNAVAILABLE") end
        P.schedulingFailure=nil
    end
end
pump=function()
    if P.pumping then return end
    P.pumping=true
    local started,count=clock(),0
    while count<32 do
        local job=nextJob();if not job then break end
        run(job);count=count+1
        if clock()-started>=0.001 then break end
    end
    P.pumping=nil;schedule()
end
local function pruneTimer()
    if P.timer and not nextJob() then local timer=P.timer;P.timer=nil;P.timerEpoch=(P.timerEpoch or 0)+1;cancel(timer) end
end
function P:Ensure(ids,context,deadline,callback)
    context=context==nil and {} or context
    if not I.Boundary:Validate(context,"preparation.context",{maxDepth=1,maxFields=2,maxNodes=5,maxBytes=256,scalarKeys=true})
        or type(context)~="table" then return nil,{code="INVALID_SCHEMA"} end
    for key in pairs(context) do if key~="scope" and key~="intent" then return nil,{code="INVALID_SCHEMA"} end end
    if not I.Boundary:Validate(ids,"preparation.ids",{maxDepth=1,maxFields=256,maxNodes=513,maxBytes=32768,scalarKeys=true})
        or not I.Boundary.Access(deadline,"preparation.deadline") then return nil,{code="INVALID_SCHEMA"} end
    local scope,intent=context.scope or "search",context.intent or "query"
    if type(scope)~="string" or #scope==0 or #scope>64 or scope:find("[%c]") or not priorities[intent]
        or type(ids)~="table" or #ids>256 or type(callback)~="function" or type(deadline)~="number" or deadline~=deadline or math.abs(deadline)==math.huge then return nil,{code="INVALID_SCHEMA"} end
    local list,seen={},{}
    for key,value in pairs(ids) do if type(key)~="number" or key%1~=0 or key<1 or key>#ids or type(value)~="string" or #value==0 or #value>64 then return nil,{code="INVALID_SCHEMA"} end end
    for _,id in ipairs(ids) do if not seen[id] then list[#list+1]=id;seen[id]=true end end
    if self.requestCount>=64 then return nil,{code="RESOURCE_LIMIT"} end
    local request={ids=list,scope=scope,intent=intent,priority=priorities[intent],deadline=math.min(deadline,clock()+5),callback=callback,
        jobs={},waiting={},ready={},failed={},remaining=0,attaching=true}
    self.requests[request]=true;self.requestCount=self.requestCount+1
    local token={Cancel=function()
        request.callback=nil;release(request);request.ready,request.failed=nil,nil;pruneTimer();return true
    end}
    local locale=identity().locale
    for _,id in ipairs(list) do
        local entry=current(id)
        if clock()>=request.deadline then request.failed[id]="PREPARATION_TIMEOUT"
        elseif not entry or not enabled(id) then request.failed[id]="PROVIDER_UNAVAILABLE"
        elseif intent~="visible" and I.Search.ProviderPolicy and not I.Search.ProviderPolicy:IsParticipating(id) then request.failed[id]="SEARCH_DISABLED"
        elseif not entry.definition.prepare then request.ready[id]=true
        else
            local slots=self.jobs[id] or {}
            local key=scope.."\31"..locale
            local job=slots[key]
            if job and not valid(job) then
                if job.status=="ready" then removeSlot(job) else finishJob(job,"failed","STALE_PREPARATION") end
                job=nil;slots=self.jobs[id] or {}
            end
            if job and job.status=="ready" then request.ready[id]=true
            else
                if not job then
                    local count=0;for _ in pairs(slots) do count=count+1 end
                    if self.slotCount>=256 or count>=8 then request.failed[id]="RESOURCE_LIMIT"
                    else
                        self.sequence=self.sequence+1
                        job={id=id,key=key,entry=entry,revision=entry.revision,locale=locale,scope=scope,status="queued",subscribers={},sequence=self.sequence,priority=request.priority}
                        self.jobs[id]=slots
                        slots[key]=job;self.slotCount=self.slotCount+1
                    end
                end
                if job then request.jobs[job]=true;request.waiting[id]=job;request.remaining=request.remaining+1;job.subscribers[request]=true;reprioritize(job) end
            end
        end
    end
    request.attaching=nil
    if intent=="prewarm" then schedule() else pump() end
    finishRequest(request)
    if not request.done then
        if not C_Timer or type(C_Timer.NewTimer)~="function" then expire(request,"SCHEDULER_UNAVAILABLE")
        else
            local ok,timer=pcall(C_Timer.NewTimer,math.max(0,request.deadline-clock()),function() expire(request,"PREPARATION_TIMEOUT");pruneTimer() end)
            if not ok or not timer then expire(request,"SCHEDULER_UNAVAILABLE")
            elseif request.done then cancel(timer) else request.timer=timer end
        end
    end
    pruneTimer()
    return token
end
function P:CancelProvider(id,entry,reason)
    local jobs={}
    for _,job in pairs(self.jobs[id] or {}) do if job.entry==entry then jobs[#jobs+1]=job end end
    for _,job in ipairs(jobs) do
        if job.status=="ready" then removeSlot(job) else finishJob(job,"failed",reason or "PROVIDER_UNAVAILABLE") end
    end
    pruneTimer()
end
function P:CancelSearch(id)
    local requests={}
    for request in pairs(self.requests) do if request.intent~="visible" and request.waiting[id] then requests[#requests+1]=request end end
    for _,request in ipairs(requests) do
        if not request.done and request.waiting[id] then
            local job=request.waiting[id];request.waiting[id]=nil;request.remaining=request.remaining-1;request.failed[id]="SEARCH_DISABLED"
            detach(request,job);finishRequest(request)
        end
    end
    pruneTimer()
end
function P:GetDiagnostics() return {requests=self.requestCount,slots=self.slotCount,queued=self.timer~=nil,diagnostics=#self.diagnostics} end
