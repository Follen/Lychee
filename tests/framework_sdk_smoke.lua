-- Private registry boundary regressions. WoW is a bounded external test adapter;
-- the public Provider facade is covered separately in provider_sdk_smoke.lua.
_G = _G or {}
UIParent = {}
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "12345", "today", 120100 end
function InCombatLockdown() return false end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end, Hide = function() end, Show = function() end }
end
local root = "addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"Core/Scheduler.lua"})
local I, SDK = _G.LycheeInternal, _G.Lychee
local readyCalls = 0
local readyToken = assert(SDK:RegisterReady(function() readyCalls = readyCalls + 1 end))
assert(type(readyToken.Cancel) == "function" and readyToken:Cancel(), "ready subscription is cancellable")
I.Registry:SetReady(true)
assert(readyCalls == 0, "cancelled ready callback does not run")
local function descriptor(id)
    return {id=id,title="SDK contract",version="1",apiVersion=3,minApiRevision=1}
end
local function register(id)
    local draft=assert(I.Registry:Begin(descriptor(id),{public=true}))
    assert(draft.RegisterSearchSource==nil,"registry no longer accepts catalog declarations")
    assert(draft:RegisterPanelFactory({id="detail",stateSchema={id="string"},create=function() return {} end}))
    return assert(draft:Commit()),draft
end
local old,draft=register("registry.reused")
assert(not draft:Commit() and not draft:RegisterPanelFactory({}),"closed draft rejects mutations")
local factory=assert(I.Registry:GetPanel("registry.reused","detail"))
assert(old:Unregister() and not I.Registry:GetPanel("registry.reused","detail"))
local fresh=register("registry.reused")
assert(not old:SetEnabled(false),"old handle cannot disable replacement")
assert(fresh:GetState().effectiveEnabled)
assert(old:Unregister() and I.Registry:GetPanel("registry.reused","detail")~=factory)
assert(fresh:SetEnabled(false) and not I.Registry:IsEnabled("registry.reused"))
assert(fresh:SetEnabled(true) and I.Registry:IsEnabled("registry.reused"))
assert(fresh:Unregister())
local aborted=assert(I.Registry:Begin(descriptor("registry.aborted"),{public=true}))
assert(aborted:Abort() and not aborted:Commit())
local replacement=register("registry.aborted");assert(replacement:Unregister())
local invalid=assert(I.Registry:Begin(descriptor("registry.invalid"),{public=true}))
assert(not invalid:RegisterPanelFactory({id="detail",create=function()end}),"public panel requires state schema")
assert(not invalid:Commit());assert(invalid:Abort())
local copied=descriptor("registry.owned")
local owned=assert(I.Registry:Begin(copied,{public=true}));copied.title="Mutated"
local committed=assert(owned:Commit());assert(I.Registry.entries[copied.id].descriptor.title=="SDK contract")
assert(committed:Unregister())
local fixture=dofile("tests/support/provider_fixture.lua")
local a=assert(fixture:Register({id="registry.catalog",title="Catalog",version="1",apiVersion=3,catalog={}}))
local input={id="owned",title="Original",payload={value=1}}
assert(a.catalog:Update({replace={input}}));input.payload.value=99
assert(a.catalog:Resolve("owned").payload.value==1)
local many={};for n=1,129 do many[n]={id=tostring(n),title="Bulk "..n} end
assert(a.catalog:Update({replace=many}) and a.catalog:GetState().entries==129)
assert(a:Unregister());local b=assert(fixture:Register({id="registry.catalog",title="New",version="1",apiVersion=3,catalog={}}))
for _,delta in ipairs({{replace=many},{upsert={input}},{remove={"owned"}}}) do assert(not a.catalog:Update(delta),"retired catalog cannot write into replacement") end
assert(not a:Invalidate() and not a:GetState() and b.catalog:GetState().entries==0)
assert(b:Unregister())
local ok,supported=pcall(SDK.Supports,SDK,3,"bad")
assert(ok and not supported and SDK:Supports(3,1) and not SDK:Supports(2,1))
print("Registry boundary PASS: panels, draft closure/abort, replacement, owner isolation, private catalogs, capacity and retired handles")
