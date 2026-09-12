LycheeInternal={Builtin={}}
local combat=false
function InCombatLockdown() return combat end
dofile("addon/Lychee/Builtin/Ellesmere/Adapter.lua")
local A=LycheeInternal.Builtin.EllesmereAdapter
assert(not A.Get() and not A.Ready())
local calls=0
EllesmereUI={_modules={Unit={title="Units",pages={"Frames"}}},EnsureLoaded=function(self) calls=calls+1;self._deferredLoaded=true end}
assert(calls==0,"loading the adapter performs no upstream work")
assert(A.Ready()==EllesmereUI and calls==1)
assert(A.Page(EllesmereUI,"Unit","Frames") and not A.Page(EllesmereUI,"Unit","Removed"))
EllesmereUI._modules.Unit.pages[1]="Changed"
assert(not A.Page(EllesmereUI,"Unit","Frames"),"mutable page content is never held in a stale cache")
EllesmereUI.TAB_LABEL_OVERRIDES=42
assert(A.Display(EllesmereUI,"Frames")=="Frames")
EllesmereUI.L=function() error("locale drift") end
assert(A.Translate(EllesmereUI,"Frames")=="Frames")
EllesmereUI.EnsureLoaded=nil;assert(not A.Ready())
EllesmereUI.EnsureLoaded=function() error("load failure") end;assert(not A.Ready())
EllesmereUI.EnsureLoaded=function() end;assert(A.Ready()==EllesmereUI,"failed loading can be retried")
local hooks=0
function hooksecurefunc() hooks=hooks+1;error("hook blocked") end
local owner={Capture=function() end}
EllesmereUI._RegisterSearchEntry=function() end
A.Observe(owner);assert(not owner.hooked)
hooksecurefunc=function() hooks=hooks+1 end
A.Observe(owner);A.Observe(owner)
assert(hooks==2 and owner.hooked==EllesmereUI,"successful attachment is cached, failed attachment is retriable")
assert(not A.Navigate(EllesmereUI,"Unit","Changed"))
local selected,args
EllesmereUI.NavigateToElementSettings=function(self,module,page,section,preSelect,label)
    args={self,module,page,section,label};preSelect();return false
end
assert(A.Navigate(EllesmereUI,"Unit","Changed",{section="Appearance",label="Border",selector="party",setter=function(v) selected=v end}))
assert(args[1]==EllesmereUI and args[2]=="Unit" and args[3]=="Changed" and args[4]=="Appearance" and args[5]=="Border" and selected=="party")
EllesmereUI.NavigateToElementSettings=function() error("navigation failure") end
assert(not A.Navigate(EllesmereUI,"Unit","Changed"))
EllesmereUI.OpenUnlockMode=function(self) self._unlockActive=true end
assert(A.Unlock())
combat=true;assert(not A.Ready() and not A.Unlock());combat=false
print("Ellesmere adapter PASS missing/drift/retry/live pages/legacy returns/exact navigation/combat")
