local Fixture=dofile("tests/support/provider_fixture.lua")
local frames=0
function CreateFrame()
    frames=frames+1
    return {SetAllPoints=function() end,Hide=function(self) self.shown=false end,
        Show=function(self) self.shown=true end,GetWidth=function() return 400 end,GetHeight=function() return 300 end}
end
function geterrorhandler() return function() end end
local measureOnly=arg[2]=="--measure"
dofile(arg[1] or "addon/Lychee/UI/ViewHost.lua")
local host=Lychee.UI.ViewHost:Create({})
local log={}
local panel={Mount=function(self,context,state) self.context=context;self.state=state end,
    Update=function(self,state) self.state=state end,
    Unmount=function(self) self.context=nil;self.state=nil end,Dispose=function() end}
local factory={create=function() return panel end}
local context,state={extensionID="owner"},{id=1}
for i=1,10 do host:Mount(factory,context,state);host:Unmount() end
collectgarbage("collect");local base=collectgarbage("count");collectgarbage("stop")
local start=os.clock()
for i=1,1000 do state.id=i;assert(host:Mount(factory,context,state));host:Update(state);host:Unmount() end
local ms,allocation=(os.clock()-start)*1000,collectgarbage("count")-base
collectgarbage("restart");collectgarbage("collect")
local retained=math.max(0,collectgarbage("count")-base)
assert(frames==1 and not panel.context and not panel.state and not host:IsActive())
if not measureOnly then assert(allocation<1000 and retained<16,"warm lifecycle allocation/retention budget") end
print(string.format("ViewLifecycle1000 cpu_ms=%.2f allocated_KiB=%.1f retained_KiB=%.1f frames=%d",ms,allocation,retained,frames))
if measureOnly then return end
local function note(v) log[#log+1]=v end
panel.Mount=function(self,c,s) note("mount");assert(c==context and s==state);return false end
panel.Update=function(self,s,c) note("update");assert(c==context and s==state);return false end
panel.Unmount=function(self,reason) note("unmount:"..reason) end
panel.Dispose=function(self,reason) note("dispose:"..reason) end
factory.create=function(c,s) note("create");assert(c==context and s==state);return panel end
assert(host:Mount(factory,context,state));assert(host:Update(state));host:Unmount("close");host:Unmount("again")
assert(table.concat(log,",")=="create,mount,update,unmount:close,dispose:close","legacy false returns and cleanup order remain compatible")
local attempts=0
panel.Unmount=function()
    if attempts==0 then
        attempts=attempts+1
        local ok,err=host:Mount(factory,context,state)
        assert(not ok and err=="PANEL_BUSY","cleanup reentry must not interleave the same cached instance")
    end
end
assert(host:Mount(factory,context,state));host:Unmount("reenter")
assert(attempts==1 and not host:IsActive() and not host:GetFrame().shown)
for _,phase in ipairs({"create","Mount","Update","Unmount","Dispose"}) do
    local calls={}
    local p={}
    local f={create=function() calls.create=(calls.create or 0)+1;return p end}
    for _,key in ipairs({"Mount","Update","Unmount","Dispose"}) do
        local name=key
        p[name]=function()
            calls[name]=(calls[name] or 0)+1
            if phase==name then
                local ok,err=host:Mount(factory,context,state)
                calls.reentryOK,calls.reentryError=ok,err
                host:Unmount("requested-close")
                error("test error from "..name)
            end
        end
    end
    if phase=="create" then f.create=function() host:Unmount("cancel-create");return p end end
    local ok=host:Mount(f,context,state)
    if phase=="Update" then assert(ok);assert(not host:Update(state))
    elseif phase=="Unmount" or phase=="Dispose" then assert(ok);host:Unmount("close")
    else assert(not ok) end
    assert(not host:IsActive() and not host:GetFrame().shown)
    assert(calls.Unmount==1 and calls.Dispose==1,"each provisional/active instance is released once, even after errors")
    if phase~="create" then assert(calls.reentryOK==false and calls.reentryError=="PANEL_BUSY") end
end
local invalid={create=function() return 42 end}
local ok,err=host:Mount(invalid,context,state)
assert(not ok and err=="PANEL_ERROR","malformed factory instance stays inside the error boundary")
local malformed={create=function() return setmetatable({},{__index=function() error("method lookup") end}) end}
assert(not host:Mount(malformed,context,state))
local ownContext={extensionID="real-owner"}
local mutate={create=function(c) c.extensionID="spoofed";return {} end}
assert(host:Mount(mutate,ownContext,state))
assert(host:IsOwnedBy("real-owner") and not host:IsOwnedBy("spoofed"),"plugin context cannot rewrite host ownership")
host:Unmount()
assert(not host:IsOwnedBy("real-owner"))
local provisionalReleased=0
local pending={create=function(c)
    c.extensionID="modified"
    assert(host:IsOwnedBy("pending-owner"),"ownership is established before factory callbacks")
    host:Unmount("extension-disabled")
    return {Dispose=function() provisionalReleased=provisionalReleased+1 end}
end}
local pendingOK,pendingError=host:Mount(pending,{extensionID="pending-owner"},{})
assert(not pendingOK and pendingError=="PANEL_CANCELLED" and provisionalReleased==1
    and not host:IsOwnedBy("pending-owner") and not host:IsActive(),"disabling during create cancels the provisional panel")
assert(host:Mount({create=function() return {} end,Mount=function() note("factory-override") end},{},{}))
assert(log[#log]=="factory-override","internal factory-level callbacks stay supported")
host:Unmount()
print("View lifecycle PASS legacy order/false returns/cached instance/reentry/cancellation/errors/owner isolation")
