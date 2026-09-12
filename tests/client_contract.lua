local Fixture=dofile("tests/support/provider_fixture.lua")
-- Real runtime + public SDK, client metadata/API surface are fixture inputs.
local locale,interface,project="enUS",120100,1
function GetLocale() return locale end
function GetBuildInfo() return "fixture","70000","",interface end
function InCombatLockdown() return false end
CreateFrame=nil
WOW_PROJECT_MAINLINE=1;WOW_PROJECT_MISTS_CLASSIC=19;WOW_PROJECT_WRATH_CLASSIC=11;WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
dofile("tests/support/runtime.lua").Load("provider", {"Core/Scheduler.lua"})
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
        local handle=assert(Fixture:Register({id=id,apiVersion=3,minApiRevision=1,version="1",title={key="name"},
            scope={products={"retail","classic","titan","anniversary"},minBuild=60000,maxBuild=80000},
            i18n={enUS={name="Shared launcher",entry="Test entry",run="Run",message="Found %d"},zhCN={name="共享启动器",entry="测试条目",run="执行",message="找到 %d"}},
            catalog={{id="entry",title={key="entry"},actions={"run"}}},
            actions={run={title={key="run"},run=function() return {ok=true} end}},
            onEnable=function() enabled=enabled+1 end,onDisable=function() disabled=disabled+1 end}))
        assert(enabled==(client[1]=="unknown" and 0 or 1),"unsupported clients must not run onEnable")
        assert(handle:Text("message",3)==(chinese and "找到 3" or "Found 3"))
        local _,results=I.Search.Query:Query(chinese and "测试条目" or "Test entry",{visible=true})
        if client[1]=="unknown" then assert(#results==0) else
            assert(#results==1 and results[1].text==(chinese and "测试条目" or "Test entry"))
            assert(results[1].interaction.actions[1].title==(chinese and "执行" or "Run"))
        end
        local updated,updateError=handle.catalog:Update({upsert={{id="updated",title={key="entry"}}}})
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
assert(not Lychee:RegisterProvider({id="missing.scope",apiVersion=3,minApiRevision=1,version="1",title="No",query=function(_,reply) reply({}) end,i18n={enUS={}}}))
assert(not Lychee:RegisterProvider({id="missing.locales",apiVersion=3,minApiRevision=1,version="1",title="No",query=function(_,reply) reply({}) end,scope={products={"retail"}}}))
print("Client/locale public registration matrix PASS 7 identities x 4 locales, updates/resolve/disable/namespace release")

locale="enUS";I.Locale.code=locale;I.Search.Normalizer.locale=locale;I.Search.RuntimeIdentity:Refresh()
local function descriptor(id)
    return {id=id,apiVersion=3,minApiRevision=1,version="1",title={key="name"},scope={products={"retail"}},i18n={enUS={name="Name"}},catalog={}}
end
local malformed=assert(Lychee.SDK.CreateCatalog({id="malformed.actions",scope={products={"retail"}},i18n={enUS={name="Name"}}}))
local safe,bad,why=pcall(malformed.Update,malformed,{replace={{id="one",title={key="name"},actions=3}}})
assert(safe and not bad and why.code=="INVALID_SCHEMA","malformed actions must return an error without throwing")
assert(malformed:Close())
local lifecycle=descriptor("lifecycle.locale")
local starts,stops=0,0
lifecycle.onEnable=function() starts=starts+1 end
lifecycle.onDisable=function() stops=stops+1 end
local h=assert(Fixture:Register(lifecycle))
safe,bad,why=pcall(h.catalog.Update,h.catalog,{upsert={{id="one",title={key="name"},actions=3}}})
assert(safe and not bad and why.code=="INVALID_SCHEMA")
assert(h:SetAvailability(false));assert(h:SetAvailability(false))
assert(starts==1 and stops==1)
assert(h:SetAvailability(true));assert(h:SetAvailability(true))
assert(starts==2 and stops==1)
assert(h:Unregister());assert(stops==2)
print("Provider locale/error/lifecycle regressions PASS")

local missingTitle=descriptor("missing.title")
missingTitle.title=nil
local bad,why=Fixture:Register(missingTitle)
assert(not bad and why.code=="INVALID_SCHEMA")
local emptyTitle=assert(Lychee.SDK.CreateCatalog({id="empty.translation",i18n={enUS={empty=""}}}))
bad,why=emptyTitle:Update({replace={{id="one",title={key="empty"}}}})
assert(not bad and why.code=="INVALID_SCHEMA")
assert(emptyTitle:Close())
