local function package(name,providerIDs)
    local metadata={ ["X-Lychee-Protocol"]="1",["X-Lychee-Package"]=name,["X-Lychee-Providers"]=table.concat(providerIDs,",") }
    for _,providerID in ipairs(providerIDs) do
        metadata["X-Lychee-Provider-"..providerID]="title="..providerID..";global=1;ranges=retail:120100:120199:0:9999999;requires=Lychee"
    end
    return {name=name,metadata=metadata,ids=providerIDs}
end
local function setup(packages)
    local env={now=0,timers={},sv={},loads={},behavior={},events=0}
    local map={Lychee={name="Lychee",metadata={},loaded=true}}
    for _,row in ipairs(packages) do map[row.name]=row end
    _G.LycheeInternal={Providers={entries={},QueryTime=function() return env.now end},Search={RuntimeIdentity={Current=function() return {product="retail",interface=120100,build=70000,locale="enUS"} end}}}
    local I=LycheeInternal
    UnitGUID=function(unit) assert(unit=="player");return "Player-1-ABC" end
    CreateFrame=function() error("loader may not create a frame") end
    C_Timer={NewTimer=function(delay,callback)
        local token={at=env.now+delay,callback=callback,Cancel=function(self) self.cancelled=true end}
        env.timers[#env.timers+1]=token;return token
    end}
    C_AddOns={GetNumAddOns=function() return #packages end,
        GetAddOnInfo=function(value) local row=type(value)=="number" and packages[value] or map[value];return row and row.name end,
        GetAddOnMetadata=function(name,key) return map[name] and map[name].metadata[key] end,
        GetAddOnEnableState=function(name,character) assert(character=="Player-1-ABC");return map[name] and not map[name].disabled and 2 or 0 end,
        IsAddOnLoadable=function(name,character,demand) assert(character=="Player-1-ABC" and demand);return not map[name].reason,map[name].reason end,
        IsAddOnLoaded=function(name) local row=map[name];return row and (row.loaded or row.loading) or false,row and row.loaded or false end,
        EnableAddOn=function() error("must never enable a user-disabled addon") end}
    Lychee={SDK={}}
    I.PublicAPI=Lychee
    function Lychee.SDK.WhenSavedVariablesReady(name,callback)
        local token={callback=callback,name=name}
        function token:Cancel()
            if self.callback then env.events=env.events-1 end
            self.callback=nil
            if env.cancelHook then local hook=env.cancelHook;env.cancelHook=nil;hook() end
        end
        if map[name].loaded then token.callback=nil;callback();return token end
        env.events=env.events+1;env.sv[#env.sv+1]=token;return token
    end
    function env:Saved(name)
        map[name].loaded=true;map[name].loading=nil
        local pending={}
        for _,token in ipairs(self.sv) do if token.name==name and token.callback then pending[#pending+1]=token end end
        for _,token in ipairs(pending) do local callback=token.callback;token:Cancel();callback() end
    end
    function env:Advance(value)
        self.now=value
        local pending=self.timers;self.timers={}
        for _,token in ipairs(pending) do
            if not token.cancelled and token.at<=value then token.callback()
            elseif not token.cancelled then self.timers[#self.timers+1]=token end
        end
    end
    function env:ActiveTimers()
        local count=0;for _,timer in ipairs(self.timers) do if not timer.cancelled then count=count+1 end end;return count
    end
    dofile("addon/Lychee/Core/AddonDiscovery.lua")
    dofile("addon/Lychee/Core/AddonLoader.lua")
    function Lychee:RegisterProvider(def)
        local accepted,err=I.AddonDiscovery:ValidateRegistration(def)
        if not accepted then return nil,err end
        if I.Providers.entries[def.id] then return nil,{code="DUPLICATE_PROVIDER"} end
        local entry={id=def.id,definition=def}
        I.Providers.entries[def.id]=entry
        I.AddonDiscovery:Registered(def.id,entry)
        return entry
    end
    function env:Publish(name,providerID)
        return Lychee:RegisterProvider({id=providerID,addon=name,title=providerID,apiVersion="1.0.0",version="1",query=function() end,
            scope={products={"retail"},minInterface=120100,maxInterface=120199,minBuild=0,maxBuild=9999999},i18n={enUS={NAME=providerID}}})
    end
    function C_AddOns.LoadAddOn(name)
        env.loads[name]=(env.loads[name] or 0)+1
        map[name].loading=true
        if env.behavior[name] then return env.behavior[name]() end
        for _,providerID in ipairs(map[name].ids) do assert(env:Publish(name,providerID)) end
        env:Saved(name)
        return true
    end
    env.map=map
    return I.AddonLoader,env,I
end
local function clean(loader,env)
    assert(loader.requestCount==0 and not next(loader.requests) and not next(loader.operations),"all loader ownership must be released")
    assert(env.events==0 and env:ActiveTimers()==0,"no active SV waiters or timers after terminal state")
end

local L,env,I=setup({package("ABC_Lychee",{"abc.one","abc.two"})})
local result,calls
calls=0
local token=assert(L:Ensure({"abc.one","abc.two"},5,function(value) result=value;calls=calls+1 end))
assert(result.ready["abc.one"] and result.ready["abc.two"] and not next(result.failed) and calls==1 and env.loads.ABC_Lychee==1)
token:Cancel();clean(L,env)
L:Ensure({"abc.one"},5,function(value) assert(value.ready["abc.one"]);calls=calls+1 end)
assert(calls==2 and env.loads.ABC_Lychee==1,"warm registered provider must not reload")
clean(L,env)

L,env,I=setup({package("ABC_Lychee",{"abc.one","abc.two"})})
env.behavior.ABC_Lychee=function() assert(env:Publish("ABC_Lychee","abc.one"));return true end
local a,b
L:Ensure({"abc.one"},5,function(value) a=value end)
L:Ensure({"abc.two"},5,function(value) b=value end)
assert(not a and not b and env.loads.ABC_Lychee==1 and env.events==1,"registration does not imply SV readiness; package requests coalesce")
env:Saved("ABC_Lychee")
assert(a and a.ready["abc.one"] and not b,"ready sibling never waits for unrequested provider")
assert(env:Publish("ABC_Lychee","abc.two"));assert(b and b.ready["abc.two"]);clean(L,env)

L,env,I=setup({package("ABC_Lychee",{"abc.one","abc.two"})})
env.behavior.ABC_Lychee=function() assert(env:Publish("ABC_Lychee","abc.one"));env:Saved("ABC_Lychee");return true end
result=nil;L:Ensure({"abc.one","abc.two"},4,function(value) result=value end)
assert(not result);env:Advance(4)
assert(result.ready["abc.one"] and result.failed["abc.two"]=="LOAD_TIMEOUT");clean(L,env)

for _,reason in ipairs({"ADDON_DISABLED","DEPENDENCY_MISSING","DEPENDENCY_DISABLED","INTERFACE_VERSION"}) do
    L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
    if reason=="ADDON_DISABLED" then env.map.ABC_Lychee.disabled=true
    elseif reason=="DEPENDENCY_MISSING" then env.map.Lychee=nil
    elseif reason=="DEPENDENCY_DISABLED" then env.map.Lychee.disabled=true
    else env.map.ABC_Lychee.reason=reason end
    result=nil;L:Ensure({"abc.one"},5,function(value) result=value end)
    assert(result.failed["abc.one"]==reason and not env.loads.ABC_Lychee);clean(L,env)
end
for _,throw in ipairs({false,true}) do
    L,env,I=setup({package("ABC_Lychee",{"abc.one"}),package("Other_Lychee",{"other.one"})})
    env.behavior.ABC_Lychee=function() if throw then error("load fault") end;return nil,"MISSING_FILE" end
    result=nil;L:Ensure({"abc.one","other.one"},5,function(value) result=value end)
    assert(result.ready["other.one"] and result.failed["abc.one"]==(throw and "ADDON_LOAD_ERROR" or "MISSING_FILE"));clean(L,env)
end

L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
env.behavior.ABC_Lychee=function() return true end
calls=0
token=assert(L:Ensure({"abc.one"},5,function() calls=calls+1 end))
local stale=env.timers[1]
token:Cancel();stale.callback();assert(env:Publish("ABC_Lychee","abc.one"));env:Saved("ABC_Lychee")
assert(calls==0);clean(L,env)

-- Native LoadAddOn can synchronously reenter Ensure before registration returns.
L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
calls=0
env.behavior.ABC_Lychee=function()
    L:Ensure({"abc.one"},5,function(value) assert(value.ready["abc.one"]);calls=calls+1 end)
    assert(env:Publish("ABC_Lychee","abc.one"));env:Saved("ABC_Lychee");return true
end
L:Ensure({"abc.one"},5,function(value) assert(value.ready["abc.one"]);calls=calls+1 end)
assert(calls==2 and env.loads.ABC_Lychee==1);clean(L,env)

-- Cancellation cleanup itself can synchronously create a new request.
L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
env.behavior.ABC_Lychee=function() return true end
calls=0
token=L:Ensure({"abc.one"},5,function() error("cancelled request") end)
env.cancelHook=function() L:Ensure({"abc.one"},5,function(value) assert(value.ready["abc.one"]);calls=calls+1 end) end
token:Cancel();assert(L.requestCount==1 and env.loads.ABC_Lychee==1,"an already-started native load is never requested twice")
assert(env:Publish("ABC_Lychee","abc.one"));env:Saved("ABC_Lychee")
assert(calls==1);clean(L,env)

-- Completion reentry creates a new lifetime without old cleanup closing it.
L,env,I=setup({package("ABC_Lychee",{"abc.one"}),package("Other_Lychee",{"other.one"})})
calls=0
L:Ensure({"abc.one"},5,function()
    calls=calls+1
    L:Ensure({"other.one"},5,function(value) assert(value.ready["other.one"]);calls=calls+1 end)
end)
assert(calls==2);clean(L,env)

local many={}
for index=1,80 do many[index]={name="Irrelevant"..index,metadata={}} end
many[80]=package("ABC_Lychee",{"abc.one"})
L,env,I=setup(many)
calls=0;token=L:Ensure({"abc.one"},1,function() calls=calls+1 end)
assert(not env.loads.ABC_Lychee and not I.AddonDiscovery.complete)
token:Cancel();env:Advance(0);env:Advance(1)
assert(calls==0 and not env.loads.ABC_Lychee);clean(L,env)
L,env,I=setup(many)
result=nil;L:Ensure({"abc.one"},1,function(value) result=value end)
env:Advance(1)
assert(result.failed["abc.one"]=="LOAD_TIMEOUT" and not env.loads.ABC_Lychee);clean(L,env)

L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
env.behavior.ABC_Lychee=function() env.now=6;assert(env:Publish("ABC_Lychee","abc.one"));env:Saved("ABC_Lychee");return true end
result=nil;L:Ensure({"abc.one"},5,function(value) result=value end)
assert(result.failed["abc.one"]=="LOAD_TIMEOUT","a synchronous load cannot extend the absolute deadline");clean(L,env)

L,env,I=setup({})
assert(Lychee:RegisterProvider({id="old.provider",title="Legacy"}))
L:Ensure({"old.provider","missing.provider"},5,function(value) assert(value.ready["old.provider"] and value.failed["missing.provider"]=="UNKNOWN_PROVIDER") end)
clean(L,env)
local invalid,err=L:Ensure({[2]="hole"},5,function() end);assert(not invalid and err.code=="INVALID_SCHEMA")

L,env,I=setup({package("ABC_Lychee",{"abc.one"})})
C_Timer.NewTimer=function() return nil end
L:Ensure({"abc.one"},5,function(value) assert(value.failed["abc.one"]=="SCHEDULER_UNAVAILABLE") end);clean(L,env)
print("addon_loading: public cold load, coalescing, readiness, cancellation, reentry and deadline passed")
