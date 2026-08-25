local I = _G.LycheeInternal
local S={active={}}
I.Scheduler=S
function S:Add(key,fn) if type(fn)~="function" then return end; self.active[key]=fn end
function S:Remove(key) self.active[key]=nil end
function S:Clear() self.active={} end
