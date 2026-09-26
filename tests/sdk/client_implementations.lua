local interface, build = 120100, "70000"
function GetBuildInfo() return "fixture",build,"",interface end
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
dofile("tests/support/runtime.lua").Load("provider", {"Core/AddonDiscovery.lua"})
local I, SDK = LycheeInternal, Lychee.SDK
I.Registry:SetReady(true)
local function range(product, lo, hi, blo, bhi)
    return {product=product,minInterface=lo,maxInterface=hi,minBuild=blo or 1,maxBuild=bhi or 9999999}
end
local declarations={
    {id="modern",ranges={range("retail",120100,120199,70000,71000),range("forever",16001,16099)}},
    {id="legacy",ranges={range("classic",50504,50599)}},
}
assert(SDK.SupportsFeature("client-implementations",1))
assert(not SDK.SupportsFeature("client-implementations",2))
for _,case in ipairs({{120100,"70000","modern"},{120199,"71000","modern"},{120099,"70000"},
    {120200,"70000"},{120100,"69999"},{120100,"71001"},{120100,"unavailable"},
    {16001,"70009","modern"},{16099,"70009","modern"},{16100,"70009"},{50504,"70000","legacy"}}) do
    interface,build=case[1],case[2];I.Search.RuntimeIdentity:Refresh()
    local id,scope=SDK.SelectClientImplementation(declarations)
    assert(id==case[3],tostring(case[1])..":"..case[2])
    if id then
        assert(I.Search.RuntimeIdentity:MatchesScope(scope))
        scope.products[1]="changed"
        assert(declarations[1].ranges[1].product=="retail","result must not alias input")
    else assert(scope.code=="UNSUPPORTED_CLIENT") end
end
interface,build=16001,"70009";I.Search.RuntimeIdentity:Refresh()
assert(SDK:GetClient().product=="forever")
assert(SDK:SelectClientImplementation(declarations)=="modern")
-- Ambiguity anywhere in the declaration is an error, even off this client.
local ambiguous={{id="a",ranges={range("retail",120100,120199)}},{id="b",ranges={range("retail",120199,120299)}}}
local id,err=SDK.SelectClientImplementation(ambiguous)
assert(not id and err.code=="AMBIGUOUS_CLIENT_IMPLEMENTATION")
ambiguous[2].ranges[1].minInterface=120200
assert(not SDK.SelectClientImplementation(ambiguous)) -- valid, but no Forever range
for _,bad in ipairs({{}, {[2]=declarations[1]}, {declarations[1],declarations[1]},
    {{id="x",ranges={range("not-a-client",1,2)}}},
    {{id="x",ranges={range("retail",2,1)}}},
    {{id="x",ranges={range("retail",1,2)},factory=function() error("never execute") end}},
    setmetatable({}, {__index=function() error("never execute") end})}) do
    local ok,result=pcall(SDK.SelectClientImplementation,bad)
    assert(ok and not result,"invalid declarations must not throw or execute code")
end
-- Scope matching has identical semantics in discovery and loaded registration.
assert(I.ClientSupport:Matches(range("forever",16001,16001,70009,70009),SDK.GetClient()))
local matches,reason=I.ClientSupport:Matches(range("forever",16001,16001,70010,70011),SDK.GetClient())
assert(not matches and reason=="UNSUPPORTED_BUILD")
local handle=assert(Lychee:RegisterProvider({id="test.forever",apiVersion="1.0.0",version="1",title="Forever",
    scope={product="forever"},entries={{id="one",title="Forever entry"}}}))
assert(I.Providers:Resolve({providerID="test.forever",entryID="one"}))
assert(handle:Unregister())
collectgarbage("collect")
local before=collectgarbage("count")
for n=1,1000 do assert(SDK.SelectClientImplementation(declarations)=="modern") end
collectgarbage("collect")
print("Client implementations PASS: five-product ranges, edge bounds, ambiguity, invalid input, isolation; retained delta KiB",collectgarbage("count")-before)
