local I = _G.LycheeInternal
local L = { operations = {}, requests = {}, requestCount = 0 }
I.AddonLoader = L
local MAX_REQUESTS, MAX_IDS = 64, 256
local function time() return I.Providers:QueryTime() end
local function cancel(token) if token and type(token.Cancel)=="function" then pcall(token.Cancel,token) end end
local function loaded(name)
    if not C_AddOns or type(C_AddOns.IsAddOnLoaded)~="function" then return false end
    local ok,started,complete=pcall(C_AddOns.IsAddOnLoaded,name)
    return ok and complete==true,ok and started==true
end
local function current(providerID)
    return I.Providers and I.Providers.entries and I.Providers.entries[providerID]
end
local function closeOperation(operation)
    if next(operation.requests) then return end
    -- A synchronous native load is not interruptible. Keep its identity until
    -- it returns so cancellation followed by reentry cannot load it twice.
    if operation.loading then return end
    if L.operations[operation.addon]==operation then L.operations[operation.addon]=nil end
    operation.retired=true
    local token=operation.svToken;operation.svToken=nil
    cancel(token)
end
local function release(request)
    if request.done then return end
    request.done=true
    L.requests[request]=nil;L.requestCount=L.requestCount-1
    local timer,scan=request.timer,request.scan
    request.timer,request.scan=nil,nil
    local operations=request.operations;request.operations={}
    for operation in pairs(operations) do operation.requests[request]=nil end
    cancel(timer);cancel(scan)
    for operation in pairs(operations) do closeOperation(operation) end
    request.ids,request.waiting=nil,nil
end
local function finish(request)
    if request.done then return end
    local callback,result=request.callback,{ready=request.ready,failed=request.failed}
    request.callback,request.ready,request.failed=nil,nil,nil
    release(request)
    if callback then pcall(callback,result) end
end
local function failRemaining(request,reason)
    if request.done then return end
    for _,providerID in ipairs(request.ids) do if not request.ready[providerID] and not request.failed[providerID] then request.failed[providerID]=reason end end
    finish(request)
end
local function check(request)
    if request.done or request.attaching then return end
    if time()>=request.deadline then failRemaining(request,"LOAD_TIMEOUT");return end
    local pending=false
    for _,providerID in ipairs(request.ids) do
        if not request.ready[providerID] and not request.failed[providerID] then
            local operation=request.waiting[providerID]
            if operation and operation.error then request.failed[providerID]=operation.error
            elseif operation and operation.svReady and not operation.loading and current(providerID) then
                request.ready[providerID]=true
            else pending=true end
        end
    end
    if not pending then finish(request) end
end
local function notify(operation)
    local snapshot={}
    for request in pairs(operation.requests) do snapshot[#snapshot+1]=request end
    for _,request in ipairs(snapshot) do check(request) end
end
local function start(operation)
    if operation.started or operation.retired then return end
    operation.started=true
    local SDK=I.PublicAPI and I.PublicAPI.SDK
    if not SDK or type(SDK.WhenSavedVariablesReady)~="function" then operation.error="SDK_UNAVAILABLE";notify(operation);return end
    -- Publish the operation and its subscribers before any external code runs.
    operation.loading=true
    local ok,token,err=pcall(SDK.WhenSavedVariablesReady,operation.addon,function()
        if operation.retired then return end
        operation.svReady=true
        operation.svToken=nil
        if not operation.loading then notify(operation) end
    end)
    if not ok or not token then
        operation.loading=false;operation.error=type(err)=="table" and err.code or "SV_WAIT_FAILED"
        notify(operation);return
    end
    if operation.retired or operation.svReady then cancel(token) else operation.svToken=token end
    if operation.retired or not next(operation.requests) then operation.loading=false;closeOperation(operation);return end
    local complete,inProgress=loaded(operation.addon)
    if not complete and not inProgress then
        if not C_AddOns or type(C_AddOns.LoadAddOn)~="function" then operation.error="UNSUPPORTED_CLIENT"
        else
            local called,success,reason=pcall(C_AddOns.LoadAddOn,operation.addon)
            if not called then operation.error="ADDON_LOAD_ERROR"
            elseif not success then operation.error=type(reason)=="string" and reason~="" and reason or "ADDON_LOAD_FAILED" end
        end
    elseif complete then operation.svReady=true end
    operation.loading=false
    if operation.retired then return end
    if operation.error then local waiter=operation.svToken;operation.svToken=nil;cancel(waiter) end
    notify(operation)
    closeOperation(operation)
end
local function attach(request,result)
    if request.done then return end
    request.scan=nil
    if result.error then failRemaining(request,result.error);return end
    if time()>=request.deadline then failRemaining(request,"LOAD_TIMEOUT");return end
    request.attaching=true
    local operations={}
    for _,providerID in ipairs(request.ids) do
        local row=I.AddonDiscovery:Get(providerID)
        if not row then
            if current(providerID) then request.ready[providerID]=true else request.failed[providerID]="UNKNOWN_PROVIDER" end
        else
            local available,reason=I.AddonDiscovery:Availability(row)
            if not available then request.failed[providerID]=reason
            else
                local operation=L.operations[row.addon]
                if not operation then operation={addon=row.addon,requests={}};L.operations[row.addon]=operation end
                if not request.operations[operation] then operations[#operations+1]=operation end
                request.operations[operation]=true;operation.requests[request]=true;request.waiting[providerID]=operation
            end
        end
    end
    request.attaching=false
    -- All of this request's package subscriptions exist before the first load.
    for _,operation in ipairs(operations) do
        if request.done then break end
        if time()>=request.deadline then failRemaining(request,"LOAD_TIMEOUT");break end
        start(operation)
    end
    check(request)
end
function L:Ensure(providerIDs,deadline,callback)
    if type(providerIDs)~="table" or #providerIDs>MAX_IDS or type(callback)~="function"
        or type(deadline)~="number" or deadline~=deadline or deadline==math.huge or deadline==-math.huge then return nil,{code="INVALID_SCHEMA"} end
    local ids,seen={},{}
    for key,value in pairs(providerIDs) do
        if type(key)~="number" or key%1~=0 or key<1 or key>#providerIDs or type(value)~="string" or #value==0 or #value>64 then return nil,{code="INVALID_SCHEMA"} end
    end
    for _,providerID in ipairs(providerIDs) do if not seen[providerID] then ids[#ids+1]=providerID;seen[providerID]=true end end
    if self.requestCount>=MAX_REQUESTS then return nil,{code="RESOURCE_LIMIT"} end
    local request={ids=ids,deadline=math.min(deadline,time()+5),callback=callback,ready={},failed={},waiting={},operations={}}
    self.requests[request]=true;self.requestCount=self.requestCount+1
    local token={}
    function token:Cancel()
        request.callback=nil
        release(request)
        request.ready,request.failed=nil,nil
        return true
    end
    if #ids==0 then finish(request);return token end
    if request.deadline<=time() then failRemaining(request,"LOAD_TIMEOUT");return token end
    local ready=true
    for _,id in ipairs(ids) do
        local entry=current(id)
        if not entry or entry.definition.addon then ready=false;break end
    end
    if ready then
        for _,id in ipairs(ids) do request.ready[id]=true end
        finish(request);return token
    end
    if not C_Timer or type(C_Timer.NewTimer)~="function" then failRemaining(request,"SCHEDULER_UNAVAILABLE");return token end
    local ok,timer=pcall(C_Timer.NewTimer,request.deadline-time(),function() failRemaining(request,"LOAD_TIMEOUT") end)
    if not ok or not timer or type(timer.Cancel)~="function" then failRemaining(request,"SCHEDULER_UNAVAILABLE");return token end
    if request.done then cancel(timer);return token end
    request.timer=timer
    local scan,err=I.AddonDiscovery:Scan(function(result) attach(request,result) end)
    if not scan then failRemaining(request,err and err.code or "DISCOVERY_UNAVAILABLE")
    elseif request.done or I.AddonDiscovery.complete then cancel(scan)
    else request.scan=scan end
    return token
end
function L:Registered(providerID)
    local row=I.AddonDiscovery:Get(providerID)
    local operation=row and self.operations[row.addon]
    if operation then notify(operation) end
end
