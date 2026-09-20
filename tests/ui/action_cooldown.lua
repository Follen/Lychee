-- Display-only native cooldowns: shared reads, bounded work, and no idle driver.
local frames,timers={},{}
local combat,broken,secret=false,false,{}
local reads,chargeReads,ignoreGCD=0,0
local duration,charges={},nil
local itemStart,itemDuration,itemEnabled=5,20,1
function InCombatLockdown() return combat end
function issecretvalue(value) return value==secret end
function CreateFrame(kind,_,parent)
    local f={kind=kind,parent=parent,shown=true,events={},scripts={},writes=0}
    frames[#frames+1]=f
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:HookScript(event,fn) self.scripts[event]=fn end
    function f:SetScript(event,fn) assert(event~="OnUpdate");self.scripts[event]=fn end
    function f:RegisterEvent(event) self.events[event]=true end
    function f:UnregisterAllEvents() self.events={} end
    function f:EnableMouse() end
    function f:SetHideCountdownNumbers() end
    function f:ClearAllPoints() end
    function f:SetAllPoints() end
    function f:SetPoint() end
    function f:SetSize() end
    function f:SetCooldownFromDurationObject(value,clear) assert(clear);self.value=value;self.writes=self.writes+1 end
    function f:SetCooldown(start,length) self.start,self.length=start,length;self.writes=self.writes+1 end
    return f
end
C_Timer={NewTimer=function(_,fn)
    if broken then error("scheduler unavailable") end
    local timer={callback=fn};function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer;return timer
end}
C_Spell={GetSpellCharges=function() return charges end,
    GetSpellCooldownDuration=function(_,ignore) reads=reads+1;ignoreGCD=ignore;return duration end,
    GetSpellChargeDuration=function() chargeReads=chargeReads+1;return duration end}
C_Container={GetItemCooldown=function() reads=reads+1;return itemStart,itemDuration,itemEnabled end}
LycheeInternal={Search={RuntimeIdentity={Current=function() return {product="retail"} end}}}
dofile("addon/Lychee/Core/ActionStatus.lua")
dofile("addon/Lychee/UI/ActionCooldown.lua")
local C,S=LycheeInternal.ActionCooldown,LycheeInternal.ActionStatus
local spell={kind="secure-spell",spellID=1}
local item={kind="secure-item",itemID=2}
local function row() local f=CreateFrame("Frame");f._bindingIdentity={};f._bindingRevision=1;return f end
local a,b=row(),row()
assert(C:Bind(a,a,spell));assert(C:Bind(b,b,spell));assert(reads==1 and ignoreGCD==true)
assert(C:GetDiagnostics().groups==1 and C.count==2)
for i=1,100 do C:Queue() end
assert(#timers==1);timers[1].callback();assert(reads==2)
charges={isActive=true,currentCharges=secret,maxCharges=2};C:Refresh();assert(chargeReads==1)
assert(a._lycheeCooldown.frame.value==duration)
charges=nil;duration=nil;C:Refresh();assert(not a._lycheeCooldown.frame.shown)
assert(C:Bind(a,a,item));assert(a._lycheeCooldown.frame.length==20)
itemStart=secret;C:Refresh();assert(not a._lycheeCooldown.frame.shown)
itemStart,itemDuration=5,0;C:Refresh();assert(not a._lycheeCooldown.frame.shown)
itemDuration=20;C:Refresh();assert(a._lycheeCooldown.frame.shown)
b._bindingRevision=2;C:Refresh();assert(C.count==1)
a:Hide();assert(C.count==0 and not C.listening and not next(C.groups))
a:Show();C:Bind(a,a,item);C:Queue();local pending=timers[#timers]
C:ReleaseAll();assert(pending.cancelled);pending.callback();assert(C.count==0 and not C.listening)
local frameCount=#frames
collectgarbage("collect");local retained=collectgarbage("count");collectgarbage("stop")
local allocated=collectgarbage("count");local started=os.clock()
for i=1,1000 do C:Bind(a,a,item);C:Refresh();C:ReleaseAll() end
local elapsed=(os.clock()-started)*1000;allocated=collectgarbage("count")-allocated
collectgarbage("restart");collectgarbage("collect");retained=collectgarbage("count")-retained
assert(#frames==frameCount and C.count==0 and not next(C.groups))
broken=true;C:Bind(a,a,item);C:Queue();assert(C.timer==nil and C.lastError=="SCHEDULER_UNAVAILABLE")
broken=false;C:Queue();assert(C.timer);C:ReleaseAll()
combat=true;assert(not C:Bind(a,a,item));combat=false
print(string.format("Cooldown PASS: shared IDs, charges, GCD, unknown/secret, rebind, hide, cancellation; 1000 cycles %.2f ms, %.1f KiB allocated, %.1f KiB retained, 0 new frames",elapsed,allocated,retained))
-- Only confirmed successful outcomes may persist a reference.
local saved=0
LycheeInternal.UserPreferences={TouchRecent=function() saved=saved+1;return true end,
    TouchInvocation=function() saved=saved+1;return true end}
dofile("addon/Lychee/Core/ActionOutcome.lua")
local O=LycheeInternal.ActionOutcome
for _,status in ipairs({"attempted","pending","failed","cancelled","indeterminate"}) do
    assert(not O:RememberEntry(status,{},"use"));assert(not O:RememberInvocation(status,{},{}))
end
assert(saved==0);assert(O:RememberEntry("succeeded",{},"use"));assert(saved==1)
assert(O:Status({ok=true,pending=true})=="pending" and O:Status({ok=true,attempted=true})=="attempted")
print("Action outcome history PASS")
