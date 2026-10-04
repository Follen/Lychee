local bindings,overrides,settings,failSet,failSave,combat,alt,ctrl,shift,meta,saves,frame
function GetLocale() return "enUS" end
function CreateFrame()
    frame={events={},RegisterEvent=function(self,key) self.events[key]=true end,
        UnregisterEvent=function(self,key) self.events[key]=nil end,SetScript=function(self,_,fn) self.event=fn end}
    return frame
end
function GetBindingKey(action)
    local first,second
    for _,key in ipairs({"ALT-SPACE","CTRL-L","CTRL-K","SHIFT-L"}) do
        if bindings[key]==action then if not first then first=key else second=key end end
    end
    return first,second
end
function GetBindingAction(key,override) return override and overrides[key] or bindings[key] or "" end
function GetCurrentBindingSet() return 2 end
function SetBinding(key,action)
    if failSet and action then return false end
    bindings[key]=action
    if frame.events.UPDATE_BINDINGS then frame.event(frame,"UPDATE_BINDINGS") end
    return true
end
function SaveBindings() saves=saves+1;return not failSave end
function InCombatLockdown() return combat end
function IsAltKeyDown() return alt end
function IsControlKeyDown() return ctrl end
function IsShiftKeyDown() return shift end
function IsMetaKeyDown() return meta end
local function fresh()
    bindings={SPACE="JUMP"};overrides={};settings={};failSet=false;failSave=false;combat=false;saves=0
    alt=false;ctrl=false;shift=false;meta=false;LycheeInternal=nil
    dofile("addon/Lychee/Bootstrap.lua")
    LycheeInternal.CharacterStore={Initialize=function() end,Data=function() return settings end}
    return LycheeInternal.LauncherBinding
end
local b=fresh()
assert(b:CaptureKey("SPACE")==nil and b:CaptureKey("W")==nil)
assert(b:CaptureKey("LALT")==nil)
local key,reason=b:CaptureKey("ESCAPE");assert(not key and reason=="cancel")
alt=true;assert(b:CaptureKey("SPACE")=="ALT-SPACE")
ctrl=true;shift=true;assert(b:CaptureKey("L")=="ALT-CTRL-SHIFT-L")
alt=false;ctrl=false;shift=false;meta=true;assert(b:CaptureKey("L")=="META-L")
assert(not b:SetKey("SPACE") and bindings.SPACE=="JUMP")
bindings["ALT-SPACE"]="OTHER";assert(not b:SetKey("ALT-SPACE") and saves==0)
overrides["CTRL-L"]="CLICK Other:LeftButton";assert(not b:SetKey("CTRL-L") and saves==0)
overrides={};settings.defaultBindingComplete=true -- old conflict or deliberate unbind remains untouched until user requests a key
assert(b:SetKey("CTRL-L") and bindings["CTRL-L"]=="TOGGLELYCHEE" and saves==1)
bindings["SHIFT-L"]="TOGGLELYCHEE"
assert(b:SetKey("CTRL-K") and not bindings["CTRL-L"] and bindings["SHIFT-L"]=="TOGGLELYCHEE")
failSave=true
assert(not b:SetKey("CTRL-L") and not bindings["CTRL-L"] and bindings["CTRL-K"]=="TOGGLELYCHEE" and bindings["SHIFT-L"]=="TOGGLELYCHEE")
failSave=false;combat=true;assert(not b:SetKey("CTRL-L") and not bindings["CTRL-L"])
b=fresh();bindings["ALT-SPACE"]="OTHER";LycheeInternal.OnLogin()
assert(frame.events.UPDATE_BINDINGS and not settings.defaultBindingComplete)
bindings["ALT-SPACE"]=nil
assert(b:SetKey("CTRL-L") and not bindings["ALT-SPACE"],"synchronous UPDATE_BINDINGS cannot insert a default during a manual transaction")
assert(not frame.events.UPDATE_BINDINGS and settings.defaultBindingComplete)
bindings["CTRL-L"]=nil;LycheeInternal.OnLogin();assert(not bindings["ALT-SPACE"],"an intentional unbind remains unbound")
b=fresh();failSet=true;assert(not b:SetKey("CTRL-L") and not bindings["CTRL-L"] and saves==0)
print("Launcher binding PASS: modifiers, reserved keys, ordinary/override conflicts, secondary slot, save rollback, combat, old installs and reentrant updates")
