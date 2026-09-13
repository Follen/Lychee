local I = _G.LycheeInternal
local R = { limit = 64 }
I.Resources = R
local states = setmetatable({}, {__mode="k"})
local Methods = {}
local meta = {__index=Methods, __metatable="Lychee resources"}
local hub, subscriptions = nil, {}

local failure=I.Boundary.Failure
local function keyOK(key)
    local ok = I.Boundary:Validate(key,"resource.key")
    return ok and type(key)=="string" and #key>0 and #key<=96
end
local function alive(state)
    return state and not state.closed and (not state.valid or state.valid())
end
local function report(state, field)
    if state.report then state.report("CALLBACK_ERROR",field) end
    state.errors = state.errors + 1
end
local function invoke(state, callback, ...)
    local ok, value = pcall(callback,...)
    if not ok then report(state,"resources") end
    return ok, value
end
local cancel
cancel = function(resource, reason)
    local state = resource.owner
    if not state then return true end
    resource.owner = nil
    if state.items[resource.key]==resource then state.items[resource.key]=nil end
    state.root.count = state.root.count - 1
    local cleanup=resource.cleanup
    resource.cleanup=nil
    if cleanup then invoke(state,cleanup,reason or "cancelled") end
    return true
end
local function own(scope,key,cleanup)
    local state=states[scope]
    if not alive(state) then return failure("RESOURCE_CLOSED") end
    if type(key)~="string" or #key>160 or type(cleanup)~="function" then return failure("INVALID_SCHEMA") end
    local old=state.items[key]
    if old then
        cancel(old,"replaced")
        if not alive(state) then return failure("RESOURCE_CLOSED") end
        if state.items[key] then return failure("RESOURCE_REENTRANT") end
    end
    if state.root.count>=R.limit then return failure("RESOURCE_LIMIT") end
    local resource={owner=state,key=key,cleanup=cleanup}
    state.items[key]=resource;state.root.count=state.root.count+1
    local token={Cancel=function(_,reason) return cancel(resource,reason) end}
    return token,resource
end
function R:Create(valid,onError,parent)
    local scope=setmetatable({},meta)
    local state={items={},errors=0,valid=valid,report=onError}
    state.root=parent and states[parent] and states[parent].root or {count=0}
    states[scope]=state
    if parent then
        local parentState=states[parent]
        if not alive(parentState) then state.closed=true;return scope end
        parentState.serial=(parentState.serial or 0)+1
        local token,err=own(parent,"child:"..parentState.serial,function(reason) R:Close(scope,reason) end)
        if not token then state.closed=true;return nil,err end
        state.parentToken=token
    end
    return scope
end
function R:Close(scope,reason)
    local state=states[scope]
    if not state or state.closed then return true end
    state.closed=true
    local items=state.items;state.items={}
    for _,resource in pairs(items) do cancel(resource,reason or "closed") end
    local parent=state.parentToken;state.parentToken=nil
    if parent then parent:Cancel(reason) end
    state.valid,state.report=nil,nil
    states[scope]=nil
    return true
end
function R:IsActive(scope) return alive(states[scope])==true end
function Methods:IsActive() return R:IsActive(self) end
function Methods:Own(key,cleanup)
    if not keyOK(key) then return failure("INVALID_SCHEMA") end
    local token,err=own(self,"own:"..key,cleanup)
    return token,token and nil or err
end
function R:OwnCache(scope,key,cleanup) return own(scope,"cache:"..key,cleanup) end
local function newTimer(delay,callback)
    local ok,timer=pcall(C_Timer.NewTimer,delay,callback)
    if not ok or not timer then return failure("RESOURCE_UNAVAILABLE") end
    return timer
end
function Methods:After(key,delay,callback)
    if not keyOK(key) or type(callback)~="function" or not I.Boundary:Validate(delay,"delay")
        or type(delay)~="number" or delay<0 or delay>3600 then return failure("INVALID_SCHEMA") end
    if not C_Timer or type(C_Timer.NewTimer)~="function" then return failure("RESOURCE_UNAVAILABLE") end
    local timer,fn= nil,callback
    local token,resource=own(self,"timer:"..key,function()
        local pending=timer;timer,fn=nil,nil
        if pending then pending:Cancel() end
    end)
    if not token then return nil,resource end
    local state=states[self]
    timer=newTimer(delay,function()
        local send=fn
        local current=resource.owner and alive(state)
        timer=nil;cancel(resource,"complete")
        if current and send then invoke(state,send) end
    end)
    if not timer then token:Cancel("timer-failed");return failure("RESOURCE_UNAVAILABLE") end
    return token
end
function Methods:Run(key,work,handlers)
    if not keyOK(key) or type(work)~="function" then return failure("INVALID_SCHEMA") end
    local options,err=I.Boundary:Copy(handlers==nil and {} or handlers,"task",{callbacks={complete=true,error=true,combat=true}})
    if err then return nil,err end
    if type(options)~="table" then return failure("INVALID_SCHEMA") end
    for name,value in pairs(options) do
        if (name~="complete" and name~="error" and name~="combat") or type(value)~="function" then return failure("INVALID_SCHEMA") end
    end
    if not C_Timer or type(C_Timer.NewTimer)~="function" then return failure("RESOURCE_UNAVAILABLE") end
    local thread,timer=coroutine.create(work),nil
    local token,resource=own(self,"task:"..key,function()
        local pending=timer;timer,thread,options=nil,nil,nil
        if pending then pending:Cancel() end
    end)
    if not token then return nil,resource end
    local state=states[self]
    local function finish(kind,value)
        local callback=options and options[kind]
        cancel(resource,kind)
        if callback and alive(state) then invoke(state,callback,value) end
    end
    local function step()
        timer=nil
        if not resource.owner or not alive(state) then cancel(resource,"inactive");return end
        if options.combat and InCombatLockdown and InCombatLockdown() then finish("combat");return end
        local current=thread
        local ok,value=coroutine.resume(current)
        if not resource.owner or not alive(state) then cancel(resource,"inactive");return end
        if not ok then report(state,"task");finish("error",value)
        elseif coroutine.status(current)=="dead" then finish("complete",value)
        else
            timer=newTimer(0,step)
            if not timer then report(state,"task.timer");finish("error",{code="RESOURCE_UNAVAILABLE",retryable=false}) end
        end
    end
    timer=newTimer(0,step)
    if not timer then token:Cancel("timer-failed");return failure("RESOURCE_UNAVAILABLE") end
    return token
end
function Methods:OnEvent(event,callback)
    if not keyOK(event) or type(callback)~="function" then return failure("INVALID_SCHEMA") end
    local resource
    local token,err=own(self,"event:"..event,function()
        local list=subscriptions[event]
        if list then
            list[resource]=nil
            if not next(list) then subscriptions[event]=nil;hub:UnregisterEvent(event) end
        end
        if hub and not next(subscriptions) then hub:SetScript("OnEvent",nil);hub:Hide() end
    end)
    if not token then return nil,err end
    resource=err
    if not hub then
        local ok,frame=pcall(CreateFrame,"Frame")
        if not ok or not frame then token:Cancel("frame-failed");return failure("RESOURCE_UNAVAILABLE") end
        hub=frame;hub:Hide()
    end
    local list=subscriptions[event]
    if not list then
        local ok,registered=pcall(hub.RegisterEvent,hub,event)
        if not ok or registered==false then token:Cancel("invalid-event");return failure("INVALID_EVENT") end
        list={};subscriptions[event]=list
    end
    list[resource]={callback=callback,state=states[self]}
    hub:SetScript("OnEvent",function(_,name,...)
        local listeners=subscriptions[name]
        if not listeners then return end
        -- External callbacks may subscribe/remove/reenter; this event has a finite snapshot.
        local pending={}
        for item,listener in pairs(listeners) do pending[#pending+1]={item,listener} end
        for _,pair in ipairs(pending) do
            if pair[1].owner and alive(pair[2].state) then invoke(pair[2].state,pair[2].callback,name,...) end
        end
    end)
    return token
end
function Methods:GetDiagnostics()
    local state=states[self]
    local count=0
    if state then for _ in pairs(state.items) do count=count+1 end end
    return {active=alive(state)==true,resources=count,providerResources=state and state.root.count or 0,errors=state and state.errors or 0,limit=R.limit}
end
function Methods:Cache(key,options) return I.ProviderData:Cache(self,key,options) end
function R:GetState(scope) return states[scope] end
