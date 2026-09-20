local scenario=arg and arg[1] or "absent"
local other=scenario=="classic"
local reads=0
function GetLocale() return "enUS" end
function GetBuildInfo() return other and "5.5.4" or "12.1.0","69587","fixture",other and 50504 or 120100 end
function UnitGUID() return "Player-1-fixture" end
function InCombatLockdown() return false end
C_AddOns={GetAddOnInfo=function(name)
    reads=reads+1
    if scenario=="error" then error("unavailable metadata") end
    if scenario~="absent" then return name end
end,GetAddOnEnableState=function(_,character)
    assert(character==UnitGUID("player"),"detection must use current character")
    return scenario=="disabled" and 0 or 2
end}
dofile("tests/support/runtime.lua").Load("provider",{"Search/ProviderPolicy.lua",
    "Providers/Ellesmere/Locales.lua","Providers/Ellesmere/Adapter.lua","Providers/Ellesmere/Provider.lua",
    "Providers/Exwind/Locales.lua","Providers/Exwind/Provider.lua"})
local I=LycheeInternal
I.Registry:SetReady(true)
I.ProviderModules.Ellesmere:Init();I.ProviderModules.Exwind:Init()
local enabled=scenario=="installed"
local management=I.ProviderManagement
for _,id in ipairs({"builtin.ellesmere","builtin.exwind"}) do
    assert(I.Registry.entries[id].userEnabled==enabled,"dependency-aware default: "..id.." / "..scenario)
    assert(I.CharacterStore:DisabledProviders()[id]==nil,"computed defaults must not become saved opt-outs")
    assert(I.Search.ProviderPolicy:IsParticipating(id)==enabled,"search routing must share the displayed default")
    local token=management:GetInstance(id)
    if other then
        assert(not token,"unsupported client must not expose settings detail")
    else
        assert(token and management:Read(id,token,{}).userEnabled==enabled)
        assert(management:SetUserEnabled(id,token,true))
        local module=id=="builtin.ellesmere" and I.ProviderModules.Ellesmere or I.ProviderModules.Exwind
        assert(module.handle:Unregister());module:Init()
        assert(I.Registry.entries[id].userEnabled,"explicit enable survives re-registration without dependency")
        token=assert(management:GetInstance(id))
        assert(management:SetUserEnabled(id,token,false))
        assert(module.handle:Unregister());module:Init()
        assert(not I.Registry.entries[id].userEnabled,"explicit disable survives re-registration")
    end
end
local function register(id,scope)
    return assert(Lychee:RegisterProvider({id=id,title=id,version="1",apiVersion="1.0.0",scope=scope,
        i18n={enUS={},zhCN={}},entries={{id="sample",title="Scoped sample"}}}))
end
local scope={products={other and "classic" or "retail"}}
register("defaults.visible",scope)
I.CharacterStore:DisabledProviders()["defaults.future"]=false
register("defaults.future",{products=scope.products,minBuild=70000})
register("defaults.expired",{products=scope.products,maxBuild=69000})
register("defaults.interface",{products=scope.products,minInterface=130000})
register("defaults.other",{products={other and "retail" or "classic"}})
local visible={}
for _,row in ipairs(management:FillList({})) do visible[row.id]=true end
assert(visible["defaults.visible"])
for _,id in ipairs({"defaults.future","defaults.expired","defaults.interface","defaults.other"}) do
    assert(not visible[id] and not management:GetInstance(id),"scope must hide list and detail: "..id)
    assert(not I.Registry.entries[id].userEnabled,"unsupported scope defaults off: "..id)
    assert(not I.Search.ProviderPolicy:IsParticipating(id),"unsupported scope excluded from search")
end
assert(not other or not visible["builtin.ellesmere"] and not visible["builtin.exwind"])
assert(I.CharacterStore:DisabledProviders()["defaults.future"]==false,"unsupported scope must preserve the saved preference")
local baseline=reads
for _=1,100 do
    management:FillList({});I.Search.ProviderPolicy:Invalidate();I.Search.ProviderPolicy:Snapshot()
end
assert(reads==baseline,"warm management/search must not rescan installed addons")
print("Provider defaults PASS "..scenario..": actual adapters, preferences, scopes, routing, bounded detection")
