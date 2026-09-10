local baseline=arg and arg[1]=='--baseline'
local root=os.getenv('LYCHEE_PERF_SOURCE') or 'package/Lychee'
local combat, frames=false,{}
function InCombatLockdown() return combat end
UIParent={}
function CreateFrame()
    local f={events={},scripts={},attributes={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:RegisterUnitEvent(e,u) self.events[e]=u end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    function f:SetAttribute(k,v) self.attributes[k]=v end
    function f:RegisterForClicks() end
    function f:SetSize() end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    frames[#frames+1]=f; return f
end
Lychee={Secure={Descriptor={FromAction=function(a) return {spellID=a.spellID} end},Policy={Check=function(_,d) if combat then return false,'COMBAT_LOCKED' end return true end}}}
local palette={ValidateRowAction=function() return true end,Hide=function() end,TouchRecent=function() end}
LycheeInternal={Host={PaletteController=palette}}
dofile(root..'/Secure/SecureActionBroker.lua')
local broker=LycheeInternal.Host.SecureBroker
local callbacks=0
local function deliver(event,id)
    if broker.eventFrame.events[event] then
        callbacks=callbacks+1
        broker.eventFrame.scripts.OnEvent(broker.eventFrame,event,'player',nil,id)
    end
end
local function eventCount() local n=0; for _ in pairs(broker.eventFrame.events) do n=n+1 end; return n end
for i=1,100 do
    deliver('UNIT_SPELLCAST_SUCCEEDED',123)
    deliver('UNIT_SPELLCAST_FAILED',123)
    deliver('UNIT_SPELLCAST_INTERRUPTED',123)
end
print(string.format('secure idle: subscriptions=%d delivered callbacks=%d per 300 player events',eventCount(),callbacks))
if baseline then return end
assert(eventCount()==0 and callbacks==0,'idle broker must have zero event subscriptions/callbacks')
local button=assert(broker:Prepare({kind='secure-spell',spellID=123},{controller=palette,row={},item={},session=1,generation=1}))
assert(eventCount()==0,'preparing without click does not observe casts')
button.scripts.PreClick(button)
assert(eventCount()==3 and broker.eventFrame.events.UNIT_SPELLCAST_SUCCEEDED=='player')
deliver('UNIT_SPELLCAST_SUCCEEDED',999)
assert(button.pendingCast and eventCount()==3,'other spell does not finish current cast')
deliver('UNIT_SPELLCAST_FAILED',123)
assert(not button.pendingCast and eventCount()==0,'failure releases event subscriptions')
button.scripts.PreClick(button)
deliver('UNIT_SPELLCAST_SUCCEEDED',123)
assert(not button.busy and eventCount()==0,'success releases subscriptions')
button=assert(broker:Prepare({kind='secure-spell',spellID=123},{controller=palette,row={},item={},session=1,generation=1}))
combat=true; broker:Release(button)
assert(eventCount()==1 and button.pendingRelease,'combat release listens for regeneration')
combat=false; deliver('PLAYER_REGEN_ENABLED')
assert(not button.busy and eventCount()==0,'regeneration flushes and unsubscribes')
broker:Invalidate(); assert(eventCount()==1); broker:Flush(); assert(eventCount()==0)
print('Secure event lifecycle PASS')
