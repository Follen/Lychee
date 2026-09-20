-- Public-handle fixture intentionally provides no I.Providers registry.
-- Budget: one frame, one effective timer, <=4096 retained identity keys;
-- no retained record payloads, no disabled work, no growth over repeated cycles.
local timers,frames,notices={},0,0
local definition,cleanup,combat,failCommit
local records,commits={},0
LycheeInternal={ProviderModules={},ProviderLocales={Module=function() return {resources={enUS={}}} end},
    Search={Session={SourceChanged=function() notices=notices+1 end}}}
LycheeDB={}
function InCombatLockdown() return combat end
function debugprofilestop() return 0 end
function CreateFrame()
    frames=frames+1
    local f={events={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(_,fn) self.callback=fn end
    return f
end
C_Timer={NewTimer=function(_,fn)
    local t={callback=fn};function t:Cancel() self.cancelled=true end
    for _,old in ipairs(timers) do assert(old.cancelled,"one effective task") end
    timers[#timers+1]=t;return t
end}
local handle={}
function handle:GetState() return {} end
function handle:Update(delta)
    if failCommit then return nil,{code="FIXTURE_FAILURE"} end
    commits=commits+1
    for _,id in ipairs(delta.remove) do records[id]=nil end
    for _,record in ipairs(delta.upsert) do records[record.id]=record.title end
    return true
end
Lychee={RegisterProvider=function(_,d) definition=d;return handle end}
local function enable() cleanup=definition.onEnable(handle) end
local function disable(reason) cleanup(reason or "disable") end
local function drain()
    local n=0
    while #timers>0 do
        n=n+1;assert(n<100)
        local t=table.remove(timers,1)
        if not t.cancelled then t.callback() end
    end
end
LycheeInternal.ProviderModules.Support={Scope=function() return {products={"retail"}} end}
dofile("addon/Lychee/Providers/Shared/CatalogLedger.lua")
dofile("addon/Lychee/Providers/Shared/CatalogProvider.lua")
local values={a="A",b="B"}
local m=LycheeInternal.ProviderModules.CatalogProvider:New("fixture","Fixture",{"DATA_CHANGED"},
    function(_,put,checkpoint)
        for id,title in pairs(values) do put({id=id,title=title},title);checkpoint() end
    end,{})
assert(m:Init());assert(frames==0 and #timers==0)
m.onReady=function() end
enable();drain();assert(records.a=="A" and records.b=="B" and notices==1)
disable();assert(not next(m.frame.events) and not m.job and not m.timer)
values={b="B changed",c="C"};enable();drain()
assert(not records.a and records.b=="B changed" and records.c=="C")
local before=commits;m:MarkDirty();drain();assert(commits==before,"unchanged skips commits")
failCommit=true;values={c="C changed"};m:MarkDirty();drain()
assert(m.lastError and records.b and records.c=="C","failed commit retains committed snapshot")
failCommit=false;m:MarkDirty();drain();assert(not records.b and records.c=="C changed")
m:MarkDirty();local stale=m.timer;disable();stale.callback();drain()
assert(not m.active and not m.timer and not m.job)
enable();drain();combat=true;m:MarkDirty()
assert(not m.timer and m.frame.events.PLAYER_REGEN_ENABLED)
combat=false;m.frame.callback(m.frame,"PLAYER_REGEN_ENABLED");drain()
-- A completion callback may disable the provider; no stale ready notification.
m.onReady=function() disable();return false end
before=notices;m:MarkDirty();drain();assert(notices==before)
m.onReady=nil
before=notices;enable();drain();disable();assert(notices==before,"ordinary catalogue adds no ready broadcast")
collectgarbage("collect");local memory=collectgarbage("count")
for i=1,100 do enable();drain();disable() end
collectgarbage("collect");local growth=collectgarbage("count")-memory
assert(frames==1 and #timers==0 and growth<16,"bounded lifecycle retention")
-- A successful commit must remain known if Update synchronously disables us.
values={c="C changed",new="N"}
local originalUpdate=handle.Update
handle.Update=function(self,delta)
    local ok,err=originalUpdate(self,delta)
    if ok then cleanup("disable") end
    return ok,err
end
enable();drain()
assert(records.new=="N","new row really committed before disable")
handle.Update=originalUpdate
values={};enable();drain()
assert(not records.new and not next(records),"re-enable removes identities committed during disable")
-- A new registration owns a different ledger, even when our fixture reuses its
-- handle object. The retiring commit must not publish identities into it.
handle.Update=function(self,delta)
    local ok,err=originalUpdate(self,delta)
    if ok then
        cleanup("unregister")
        records={};values={replacement="Replacement"}
        assert(m:Init());enable()
        handle.Update=originalUpdate
    end
    return ok,err
end
values={retired="Retired"};m:MarkDirty();drain()
assert(records.replacement=="Replacement" and not records.retired)
assert(m.signatures.retired==nil,"retiring delta cannot write into new registration ledger")
disable("unregister");assert(not next(m.signatures) and not m.handle)
print(string.format("Catalog lifecycle PASS private_registry=absent frames=1 idle_tasks=0 cycles=100 retained_growth_KiB=%.2f",growth))
