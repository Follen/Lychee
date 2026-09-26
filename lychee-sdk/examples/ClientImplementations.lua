-- Optional selection helper. This example only returns a key and a normal Scope;
-- the addon owns its adapter factories, dependencies and registration lifecycle.
-- These are illustrative ranges, not a claim that a business feature was tested.
local function SelectImplementation(SDK)
    if not SDK or not SDK.SupportsFeature or not SDK.SupportsFeature("client-implementations", 1) then
        return nil, {code="UNSUPPORTED_API"}
    end
    return SDK.SelectClientImplementation({
        {id="retail",ranges={{product="retail",minInterface=120100,maxInterface=120199,minBuild=1,maxBuild=9999999}}},
        {id="forever",ranges={{product="forever",minInterface=16001,maxInterface=16099,minBuild=1,maxBuild=9999999}}},
    })
end
return SelectImplementation
