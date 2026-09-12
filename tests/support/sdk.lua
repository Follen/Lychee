-- API 1.0.0 end-to-end behavior; game time is the only scheduled external input.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
local timers={}
C_Timer={NewTimer=function(seconds,callback)
 local t={seconds=seconds,callback=callback};function t:Cancel() self.cancelled=true end
 timers[#timers+1]=t;return t
end}
dofile("tests/support/runtime.lua").Load("provider",{"Core/Scheduler.lua"})
return {timers=timers}
