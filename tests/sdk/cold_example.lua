-- Exercise the shipped example and real Host boundary, not a copied definition.
local example="lychee-sdk/examples/ColdProvider/"
local stdout=print
local metadata={}
for line in io.lines(example.."ColdProvider.toc") do
    local key,value=line:match("^## ([^:]+):%s*(.-)%s*$")
    if key then metadata[key]=value end
end
assert(metadata.LoadOnDemand=="1" and metadata.Dependencies=="Lychee")
assert(metadata.SavedVariables=="ColdProviderDB" and metadata["X-Lychee-Package"]=="ColdProvider")
local fallback=assert(io.open(example.."ColdProvider.toc","rb"));local bytes=fallback:read("*a");fallback:close()
local mainline=assert(io.open(example.."ColdProvider_Mainline.toc","rb"));assert(bytes==mainline:read("*a"));mainline:close()
local function setup(locale,saved,ready,mutate)
    LycheeInternal=nil;Lychee=nil;LycheeDB=nil;LycheeCharacterDB=nil;ColdProviderDB=nil
    CreateFrame=nil
    GetLocale=function() return locale end
    GetBuildInfo=function() return "12.1.0","70000","",120100 end
    InCombatLockdown=function() return false end
    UnitGUID=function() return "Player-1-ABC" end
    local env={loaded=false,loads=0,timers={},errors={},messages={}}
    local rows={};for key,value in pairs(metadata) do rows[key]=value end
    if mutate then mutate(rows) end
    print=function(message) env.messages[#env.messages+1]=message end
    geterrorhandler=function() return function(err) env.errors[#env.errors+1]=err end end
    C_Timer={NewTimer=function(delay,callback)
        local token={delay=delay,callback=callback,Cancel=function(self) self.cancelled=true end}
        env.timers[#env.timers+1]=token;return token
    end}
    C_AddOns={GetNumAddOns=function() return 1 end,
        GetAddOnInfo=function(value) return value==1 and "ColdProvider" or value end,
        GetAddOnMetadata=function(name,key) return name=="ColdProvider" and rows[key] or nil end,
        GetAddOnEnableState=function() return 2 end,
        IsAddOnLoadable=function() return true end,
        IsAddOnLoaded=function(name)
            if name=="Lychee" then return true,true end
            return env.loading or env.loaded,env.loaded
        end}
    dofile("tests/support/runtime.lua").Load("provider",{"Core/AddonDiscovery.lua","Core/AddonLoader.lua","Search/ProviderPolicy.lua"})
    local I=LycheeInternal
    function C_AddOns.LoadAddOn(name)
        assert(name=="ColdProvider");env.loads=env.loads+1;env.loading=true
        assert(loadfile(example.."ColdProvider.lua"))(name,{})
        assert(ColdProviderDB==nil,"example must not initialize SV during file loading")
        ColdProviderDB=saved;env.loaded=true;env.loading=false
        I.DeliverAddonLoaded(name)
        return true
    end
    if ready then I.Registry:SetReady(true) end
    return I,env
end
for _,locale in ipairs({"enUS","zhCN","zhTW","enGB"}) do
    local I,env=setup(locale,nil,true)
    local D=I.AddonDiscovery
    D:Scan();local row=assert(D:Get("example.cold"))
    assert(not env.loaded and env.loads==0 and not I.Providers.entries["example.cold"],"metadata discovery cannot execute addon Lua")
    assert(row.searchGlobal==false and row.searchPrefixes[1]=="cold")
    local result
    assert(I.AddonLoader:Ensure({"example.cold"},5,function(value) result=value end))
    assert(result and result.ready["example.cold"] and env.loads==1)
    assert(#env.errors==0 and #env.messages==0 and ColdProviderDB.acknowledged==false)
    local expected=(locale=="zhCN" or locale=="zhTW") and "测试冷加载动作" or "Test cold-loaded action"
    local _,items=I.Search.Query:Query("cold:",{visible=true})
    assert(#items==1 and items[1].text==expected,"the actual example must be searchable after cold registration")
    assert(not ColdProviderDB.acknowledged,"search must not execute the business action")
    assert(I.Providers:Execute(items[1],"acknowledge",{}))
    assert(ColdProviderDB.acknowledged and #env.messages==1)
    I.AddonLoader:Ensure({"example.cold"},5,function(value) assert(value.ready["example.cold"]) end)
    assert(env.loads==1,"warm demand must not reload the package")
    assert(I.AddonLoader.requestCount==0 and not next(I.AddonLoader.operations))
end
-- Ready can follow SV readiness, as when the addon was manually loaded early.
local saved={schemaVersion=1,acknowledged=true}
local I,env=setup("enUS",saved,false)
C_AddOns.LoadAddOn("ColdProvider")
assert(not I.Providers.entries["example.cold"])
I.Registry:SetReady(true)
assert(I.Providers.entries["example.cold"] and ColdProviderDB==saved and saved.acknowledged)
-- Corrupt/unknown SV is preserved, never silently reset by this example.
local invalid={schemaVersion=99,untouched="original"}
I,env=setup("enUS",invalid,true)
C_AddOns.LoadAddOn("ColdProvider")
assert(ColdProviderDB==invalid and invalid.untouched=="original" and #env.errors==1)
assert(not I.Providers.entries["example.cold"])
-- Declaration/resource disagreement must reject the shipped registration.
I,env=setup("enUS",nil,true,function(rows)
    local key="X-Lychee-Provider-example.cold"
    rows[key]=rows[key]:gsub("file:134400","file:134401")
end)
C_AddOns.LoadAddOn("ColdProvider")
assert(#env.errors==1 and not I.Providers.entries["example.cold"])
I,env=setup("enUS",nil,true,function(rows) rows["X-Lychee-Package"]="RenamedProvider" end)
C_AddOns.LoadAddOn("ColdProvider")
assert(#env.errors==1 and not I.Providers.entries["example.cold"])
print=stdout
print("ColdProvider example PASS: real cold metadata/registration, four locale variants, SV ordering, action isolation, warm reuse and rejected mismatch")
