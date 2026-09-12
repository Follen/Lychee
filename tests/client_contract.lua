-- Real runtime + public SDK, client metadata/API surface are fixture inputs.
local locale,interface,project="enUS",120100,1
function GetLocale() return locale end
function GetBuildInfo() return "fixture","70000","",interface end
function InCombatLockdown() return false end
CreateFrame=nil
WOW_PROJECT_MAINLINE=1;WOW_PROJECT_MISTS_CLASSIC=19;WOW_PROJECT_WRATH_CLASSIC=11;WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
for _,file in ipairs({"Bootstrap.lua", "Core/CharacterStore.lua","Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua","Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua"}) do dofile("package/Lychee/"..file) end
local I=LycheeInternal
I.Registry:SetReady(true)
local sequence=0
for _,client in ipairs({{"retail",1,120100},{"classic",19,50504},{"titan",11,38002},{"anniversary",5,20506},{"unknown",11,30403},{"unknown",2,11508},{"unknown",1,50504}}) do
    for _,lang in ipairs({"enUS","enGB","zhCN","zhTW"}) do
        locale,interface,WOW_PROJECT_ID=lang,client[3],client[2]
        I.Locale.code=locale;I.Search.Normalizer.locale=locale;I.Search.RuntimeIdentity:Refresh()
        assert(I.Search.RuntimeIdentity.product==client[1],"client identity")
        local chinese=lang=="zhCN" or lang=="zhTW"
        sequence=sequence+1
        local id="matrix."..sequence
        local enabled,disabled=0,0
        local handle=assert(Lychee:RegisterProvider({id=id,apiVersion=2,minApiRevision=2,version="1",title={key="name"},
            scope={products={"retail","classic","titan","anniversary"},minBuild=60000,maxBuild=80000},
            i18n={enUS={name="Shared launcher",entry="Test entry",run="Run",message="Found %d"},zhCN={name="共享启动器",entry="测试条目",run="执行",message="找到 %d"}},
            entries={{id="entry",title={key="entry"},actions={"run"}}},
            actions={run={title={key="run"},run=function() return {ok=true} end}},
            onEnable=function() enabled=enabled+1 end,onDisable=function() disabled=disabled+1 end}))
        assert(enabled==(client[1]=="unknown" and 0 or 1),"unsupported clients must not run onEnable")
        assert(handle:Text("message",3)==(chinese and "找到 3" or "Found 3"))
        local _,results=I.Search.Query:Query(chinese and "测试条目" or "Test entry",{visible=true})
        if client[1]=="unknown" then assert(#results==0) else
            assert(#results==1 and results[1].text==(chinese and "测试条目" or "Test entry"))
            assert(results[1].interaction.actions[1].title==(chinese and "执行" or "Run"))
        end
        local updated,updateError=handle:Update({upsert={{id="updated",title={key="entry"}}}})
        assert(updated or (client[1]=="unknown" and updateError.code=="PROVIDER_DISABLED"), tostring(updateError and updateError.code))
        local item=I.Providers:Resolve({providerID=id,entryID="updated"})
        assert((item~=nil)==(client[1]~="unknown"),"updates/resolve respect client scope")
        assert(handle:Unregister());assert(not handle:Text("name"),"unregistered dictionary handle is stale")
        assert(disabled==(client[1]=="unknown" and 0 or 1),"never-started providers must not execute onDisable")
    end
end
locale="enGB";interface=120100;WOW_PROJECT_ID=1;I.Locale.code=locale;I.Search.Normalizer.locale=locale;I.Search.RuntimeIdentity:Refresh()
assert(I.Search.Normalizer:Display({enUS="English",zhCN="中文"})=="English")
assert(I.Search.Normalizer:Display({enGB="British"})=="British")
assert(not I.Search.RuntimeIdentity:MatchesScope({locale="enUS"}),"explicit locale scope does not become fallback")
locale="zhTW";I.Search.Normalizer.locale=locale;I.Search.RuntimeIdentity:Refresh()
assert(I.Search.Normalizer:Display({zhCN="中文",enUS="English"})=="中文")
assert(I.Search.Normalizer:Display({zhTW="繁體"})=="繁體")
for _,scope in ipairs({{products={}},{products={"retail","retail"}},{products={"wrong"}},{product="retail",products={"retail"}},{minBuild=100,maxBuild=10}}) do assert(not I.Boundary:ValidateScope(scope,"scope")) end
assert(not Lychee:RegisterProvider({id="missing.scope",apiVersion=2,minApiRevision=2,version="1",title="No",entries={},i18n={enUS={}}}))
assert(not Lychee:RegisterProvider({id="missing.locales",apiVersion=2,minApiRevision=2,version="1",title="No",entries={},scope={products={"retail"}}}))
print("Client/locale public registration matrix PASS 7 identities x 4 locales, updates/resolve/disable/namespace release")

locale="enUS";I.Locale.code=locale;I.Search.Normalizer.locale=locale;I.Search.RuntimeIdentity:Refresh()
local function descriptor(id)
    return {id=id,apiVersion=2,minApiRevision=2,version="1",title={key="name"},scope={products={"retail"}},i18n={enUS={name="Name"}},entries={}}
end
local malformed=descriptor("malformed.actions")
malformed.entries={{id="one",title={key="name"},actions=3}}
local safe,bad,why=pcall(Lychee.RegisterProvider,Lychee,malformed)
assert(safe and not bad and why.code=="INVALID_SCHEMA","malformed actions must return an error without throwing")
local lifecycle=descriptor("lifecycle.locale")
local starts,stops=0,0
lifecycle.onEnable=function() starts=starts+1 end
lifecycle.onDisable=function() stops=stops+1 end
local h=assert(Lychee:RegisterProvider(lifecycle))
safe,bad,why=pcall(h.Update,h,{upsert={{id="one",title={key="name"},actions=3}}})
assert(safe and not bad and why.code=="INVALID_SCHEMA")
assert(h:SetEnabled(false));assert(h:SetEnabled(false))
assert(starts==1 and stops==1)
assert(h:SetEnabled(true));assert(h:SetEnabled(true))
assert(starts==2 and stops==1)
assert(h:Unregister());assert(stops==2)
print("Provider locale/error/lifecycle regressions PASS")

local missingTitle=descriptor("missing.title")
missingTitle.title=nil
local bad,why=Lychee:RegisterProvider(missingTitle)
assert(not bad and why.code=="INVALID_SCHEMA")
local emptyTitle=descriptor("empty.translation")
emptyTitle.i18n.enUS.empty=""
emptyTitle.entries={{id="one",title={key="empty"}}}
bad,why=Lychee:RegisterProvider(emptyTitle)
assert(not bad and why.code=="INVALID_SCHEMA")
