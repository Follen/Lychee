-- Public subscriptions: native API responses are inputs, not pre-filled SDK state.
local frames={}
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(name) self.events[name]=true end
    function f:UnregisterEvent(name) self.events[name]=nil end
    function f:SetScript(name,callback) self[name]=callback end
    frames[#frames+1]=f;return f
end
dofile("tests/support/sdk.lua")
local SDK,I=Lychee.SDK,LycheeInternal
local function watching()
    for _,f in ipairs(frames) do if f.events.ADDON_LOADED then return true end end
    return false
end
local loaded,loading=false,true
C_AddOns={IsAddOnLoaded=function() return loading,loaded end}
local called=0
local token=assert(SDK.WhenSavedVariablesReady("Child",function() called=called+1 end))
assert(called==0 and watching(),"loadedOrLoading=true is not restored SV readiness")
I.DeliverAddonLoaded("Unrelated");assert(called==0 and watching())
assert(token:Cancel() and token:Cancel());assert(not watching())
I.DeliverAddonLoaded("Child");assert(called==0,"cancelled callback cannot run")
loaded=true
token=assert(SDK.WhenSavedVariablesReady("AlreadyLoaded",function() called=called+1 end))
assert(called==1 and not watching());token:Cancel()
loaded=false
local errors,order={},{}
function geterrorhandler() return function(err) errors[#errors+1]=err end end
local sibling,newcomer
local first=assert(SDK.WhenSavedVariablesReady("Batch",function()
    order[#order+1]="first";sibling:Cancel()
    newcomer=assert(SDK.WhenSavedVariablesReady("Batch",function() order[#order+1]="next" end))
end))
sibling=assert(SDK.WhenSavedVariablesReady("Batch",function() error("cancelled sibling ran") end))
assert(SDK.WhenSavedVariablesReady("Batch",function() error("intentional failure") end))
assert(SDK.WhenSavedVariablesReady("Batch",function() order[#order+1]="last" end))
I.DeliverAddonLoaded("Batch")
assert(table.concat(order,",")=="first,last" and #errors==1 and watching(),"snapshot delivery isolates removal/addition and failures")
I.DeliverAddonLoaded("Batch")
assert(table.concat(order,",")=="first,last,next" and not watching())
I.DeliverAddonLoaded("Batch");assert(#order==3)
for _,args in ipairs({{"",function() end},{string.rep("x",129),function() end},{"Child",false}}) do
    local value,err=SDK.WhenSavedVariablesReady(unpack(args));assert(not value and err.code=="INVALID_SCHEMA")
end
local pending={}
for n=1,64 do pending[n]=assert(SDK.WhenSavedVariablesReady("Pending",function() called=called+1 end)) end
local value,err=SDK.WhenSavedVariablesReady("Overflow",function() error("overflow ran") end)
assert(not value and err.code=="RESOURCE_LIMIT")
pending[1]:Cancel();pending[1]=assert(SDK.WhenSavedVariablesReady("Replacement",function() end))
for _,handle in ipairs(pending) do handle:Cancel() end
assert(not watching(),"all cancellations return the shared watcher to idle")
I.DeliverAddonLoaded("Pending");assert(called==1)

local events,second,added={},nil,nil
first=assert(Lychee:ObservePalette(function(visible)
    events[#events+1]="first:"..tostring(visible)
    second:Cancel();first:Cancel()
    added=assert(Lychee:ObservePalette(function(v) events[#events+1]="next:"..tostring(v) end))
end))
second=assert(Lychee:ObservePalette(function() error("cancelled visibility observer ran") end))
local broken=assert(Lychee:ObservePalette(function() error("isolated observer failure") end))
local last=assert(Lychee:ObservePalette(function(v) events[#events+1]="last:"..tostring(v) end))
I.NotifyPaletteVisibility(true)
assert(table.concat(events,",")=="first:true,last:true")
I.NotifyPaletteVisibility(false)
assert(table.concat(events,",")=="first:true,last:true,last:false,next:false")
added:Cancel();broken:Cancel();last:Cancel()
for n=1,64 do pending[n]=assert(Lychee:ObservePalette(function() end)) end
value,err=Lychee:ObservePalette(function() end);assert(not value and err.code=="RESOURCE_LIMIT")
for _,handle in ipairs(pending) do assert(handle:Cancel() and handle:Cancel()) end
I.NotifyPaletteVisibility(true);assert(#events==4)
assert(not Lychee:ObservePalette(false))
print("Public notifications PASS: loaded vs loading, unrelated event, cancel, reentry, error isolation, once-only delivery, 64-slot recovery, idle watcher")
