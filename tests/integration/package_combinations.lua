-- Each manifest case runs in a fresh Lua process with actual delivered TOCs.
local selection=arg[1] or "host"
local packages={"Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"}
local names={}
if selection=="reverse" then for n=#packages,1,-1 do names[#names+1]=packages[n] end
elseif selection~="host" then
    local valid=false;for _,name in ipairs(packages) do if name==selection then valid=true end end
    assert(valid,"unknown package selection");names[1]=selection
end
local frames,timers,errors={},{},{}
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:UnregisterEvent(event) self.events[event]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(event,fn) self[event]=fn end
    function f:Show() end
    function f:Hide() end
    frames[#frames+1]=f;return f
end
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0","70000","",120100 end
function InCombatLockdown() return false end
function geterrorhandler() return function(err) errors[#errors+1]=err end end
WOW_PROJECT_ID=1
C_Timer={NewTimer=function(_,fn) local t={fn=fn};function t:Cancel() self.cancelled=true end;timers[#timers+1]=t;return t end}
local Loader=dofile("tests/support/package_loader.lua")
local host=Loader:Load("Lychee")
local allowed={}
for _,name in ipairs(names) do
    local ns=Loader:Load(name)
    for _,definition in ipairs(ns.Modules.Definitions) do allowed[definition.id]=true end
end
assert(not LycheePlayerCharacterDB and next(host.Providers.entries)==nil)
Loader:Ready("Unrelated")
assert(not LycheePlayerCharacterDB and next(host.Providers.entries)==nil)
-- Simulate restoration after file execution; a saved explicit opt-out survives activation.
LycheeCharacterDB={disabledProviders={["lychee.game-menus"]=true}}
local restored={schemaVersion=1,settings={}}
if Loader.namespaces.Lychee_Player then LycheePlayerCharacterDB=restored end
host.OnLogin() -- Login may precede a late-loaded child's readiness.
for _,name in ipairs(names) do Loader:Ready(name) end
local function drain()
    local count=0
    while #timers>0 do count=count+1;assert(count<1000,"bounded activation");local t=table.remove(timers,1);if not t.cancelled then t.fn() end end
end
drain()
local registered={}
for id,entry in pairs(host.Providers.entries) do assert(allowed[id],"absent package registered "..id);registered[id]=entry end
for _,name in ipairs(names) do Loader:Ready(name) end
host.OnLogin();drain()
for id,entry in pairs(registered) do assert(host.Providers.entries[id]==entry,"duplicate delivery must not replace provider instances") end
assert(#errors==0,table.concat(errors,"; "))
assert(host.Modules==nil and host.ProviderLocaleData==nil and next(host.Search.StaticIndex.entries)==nil)
assert(not (host.Host and host.Host.PaletteController),"activation creates no palette")
if Loader.namespaces.Lychee_Player then
    assert(LycheePlayerCharacterDB==restored,"restored root remains authoritative")
    assert(host.Providers.entries["lychee.game-menus"] and not host.Registry:IsEnabled("lychee.game-menus"),"saved opt-out survives late activation")
else assert(LycheePlayerCharacterDB==nil,"absent Player package must not create its business DB") end
if selection=="host" then assert(next(registered)==nil) end
assert(not frames[1].events.ADDON_LOADED,"Host releases its SV readiness watcher")
-- BlizzardSettings legitimately watches ADDON_LOADED for Settings UI availability.
for _,frame in ipairs(frames) do assert(not frame.OnUpdate,"activation creates no resident per-frame work") end
print("Package combination PASS: "..selection..", real TOCs, late readiness, opt-out, duplicate events, private DB and idle ownership")
