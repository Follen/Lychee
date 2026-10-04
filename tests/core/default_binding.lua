local settings, binding, other, blocked, saveFails, saves, sets, locked
local frame
function GetLocale() return "enUS" end
function CreateFrame()
    frame={RegisterEvent=function() end,UnregisterEvent=function() end,
        SetScript=function(self,_,fn) self.event=fn end}
    return frame
end
function GetBindingKey(action) assert(action=="TOGGLELYCHEE");return binding end
function GetBindingAction(key) assert(key=="ALT-SPACE");return binding==key and "TOGGLELYCHEE" or other or "" end
function GetCurrentBindingSet() return 2 end
function SetBinding(key,action)
    sets=sets+1
    if blocked then return false end
    assert(key=="ALT-SPACE" and action=="TOGGLELYCHEE");binding=key;return true
end
function SaveBindings(set)
    saves=saves+1;assert(set==2)
    if saveFails then return false end
    return true
end
function InCombatLockdown() return locked end
local function fresh()
    LycheeInternal=nil;settings={};binding=nil;other=nil;blocked=false;saveFails=false;saves=0;sets=0;locked=false
    assert(loadfile("addon/Lychee/Bootstrap.lua"))("Lychee",{})
    LycheeInternal.CharacterStore={Initialize=function() end,Data=function() return settings end}
end
local function login() frame.event(frame,"PLAYER_LOGIN") end
fresh();blocked=true;login();assert(not binding)
blocked=false;login()
assert(binding=="ALT-SPACE" and saves==1,"failed first login must retry default binding")
fresh();login();assert(binding=="ALT-SPACE" and saves==1 and settings.defaultBindingComplete)
login();assert(sets==1 and saves==1,"successful initialization is idempotent")
binding=nil;login();assert(not binding and sets==1,"intentional unbind must remain unbound")
fresh();other="OTHER_ACTION";login();assert(sets==0 and saves==0 and other=="OTHER_ACTION")
other=nil;frame.event(frame,"UPDATE_BINDINGS")
assert(binding=="ALT-SPACE" and saves==1,"freeing a first-install conflict must retry the default binding")
fresh();binding="CTRL-L";login();assert(sets==0 and saves==0 and binding=="CTRL-L")
fresh();saveFails=true;login();assert(binding=="ALT-SPACE" and not settings.defaultBindingComplete)
saveFails=false;login();assert(saves==2 and sets==1 and settings.defaultBindingComplete)
fresh();locked=true;login();assert(sets==0 and not settings.defaultBindingComplete)
locked=false;frame.event(frame,"PLAYER_REGEN_ENABLED");assert(binding=="ALT-SPACE")
fresh();settings.defaultBindingAttempted=true;login();assert(binding=="ALT-SPACE","legacy failed attempts can recover")
fresh();blocked=true;login();assert(not settings.defaultBindingComplete and saves==0)
local previous=SetBinding;SetBinding=function() error("restricted") end
assert(pcall(login) and not settings.defaultBindingComplete);SetBinding=previous
fresh();SetBinding=function() return true end
login();assert(not settings.defaultBindingComplete and saves==0,"assignment must be confirmed by readback")
SetBinding=previous
fresh();local previousSave=SaveBindings
SaveBindings=function(set) assert(set==2);saves=saves+1 end
login();assert(settings.defaultBindingComplete and saves==1,"native save without a return value is accepted")
SaveBindings=previousSave
print("Default binding PASS: first install, legacy repair, assignment/save failure retry, combat, conflicts, custom binding and intentional unbind")
