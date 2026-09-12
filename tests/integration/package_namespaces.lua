local Loader=dofile("tests/support/package_loader.lua")
local frames={}
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(name) self.events[name]=true end
    function f:UnregisterEvent(name) self.events[name]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:Hide() end
    function f:Show() end
    function f:SetScript(name,fn) self[name]=fn end
    frames[#frames+1]=f;return f
end
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
WOW_PROJECT_ID=1
local host=Loader:Load("Lychee")
for _,name in ipairs({"Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"}) do
    local package=Loader:Load(name)
    assert(package~=host and package.Modules~=nil)
    assert(package.ProviderLocaleData~=host.ProviderLocaleData)
    assert(package.savedVariablesReady==nil,"SV cannot be marked ready by mere file loading")
end
assert(host.Modules==nil and host.ProviderLocaleData==nil,"pure Host owns no business namespace")
assert(next(host.Providers.entries)==nil,"no registration before child SV readiness")
assert(LycheePlayerCharacterDB==nil,"no premature SV creation")
assert(Loader.namespaces.Lychee_Player.Modules.Achievements)
assert(Loader.namespaces.Lychee_Encounters.Modules.LDT)
assert(not Loader.namespaces.Lychee_Player.Modules.LDT)
assert(not Loader.namespaces.Lychee_Integrations.Modules.Achievements)
assert(not (host.Host and host.Host.PaletteController),"TOC load creates no search UI")
print("Five package namespaces PASS: real TOC order, private ownership, no pre-restoration DB or business startup; frames="..#frames)

local timers={}
C_Timer={NewTimer=function(_,fn) local t={fn=fn};function t:Cancel()self.cancelled=true end;timers[#timers+1]=t;return t end}
local errors={}
function geterrorhandler() return function(err) errors[#errors+1]=err end end
for name in pairs(Loader.namespaces) do host.DeliverAddonLoaded(name) end
host.OnLogin()
local steps=0;while #timers>0 do steps=steps+1;assert(steps<1000);local t=table.remove(timers,1);if not t.cancelled then t.fn() end end
assert(#errors==0,table.concat(errors,"; "))
assert(LycheePlayerCharacterDB and Loader.namespaces.Lychee_Player.savedVariablesReady)
assert(host.Registry:IsEnabled("lychee.game-menus") and host.Registry:IsEnabled("lychee.bosses"))
for id,entry in pairs(host.Providers.entries) do assert(not entry.lastError,id..":"..tostring(entry.lastError and entry.lastError.code)) end
assert(not (host.Host and host.Host.PaletteController),"login does not instantiate the palette")
print("Real package activation PASS: ADDON_LOADED, restored SV, PLAYER_LOGIN, default registrations, no callback errors")
