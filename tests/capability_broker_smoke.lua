-- CapabilityBroker ownership, ordering, schema, and failure isolation smoke.
_G = _G or {}
_G.LycheeInternal = {}

dofile("package/Lychee/Core/Boundary.lua")
dofile("package/Lychee/Core/CapabilityBroker.lua")

local I = _G.LycheeInternal
local enabled = {}
I.Registry = {
    IsEnabled = function(_, extensionID) return enabled[extensionID] == true end,
}

local function reset()
    I.Broker.providers = {}
    I.Broker.byExt = {}
    I.Broker.nextSequence = 0
    enabled = {}
end

local requestSchema = { text = "string", limit = "integer?" }
local resultSchema = {
    kind = "array",
    items = { itemID = "integer", name = "string" },
    maxItems = 2,
}

-- Equal priorities use stable extension/provider identity, independent of registration order.
local calls = {}
enabled["z.extension"] = true
enabled["a.extension"] = true
assert(I.Broker:Add("z.extension", {
    id = "alpha", type = "fixture.items", priority = 10,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() calls[#calls + 1] = "z.extension:alpha"; return {} end,
}))
assert(I.Broker:Add("a.extension", {
    id = "zulu", type = "fixture.items", priority = 10,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() calls[#calls + 1] = "a.extension:zulu"; return {} end,
}))
local ordered, orderedErr, orderedInfo = I.Broker:Query("fixture.items", { text = "x" }, {})
assert(ordered and not orderedErr and #ordered == 0)
assert(calls[1] == "a.extension:zulu")
assert(orderedInfo.extensionID == "a.extension" and orderedInfo.providerID == "zulu" and orderedInfo.version == 1)

-- Provider ID is the final stable identity component within one extension.
reset()
enabled["same.extension"] = true
local sameExtensionCalls = {}
for _, providerID in ipairs({ "zulu", "alpha" }) do
    assert(I.Broker:Add("same.extension", {
        id = providerID, type = "fixture.same-owner", priority = 10,
        requestSchema = requestSchema, resultSchema = resultSchema,
        query = function() sameExtensionCalls[#sameExtensionCalls + 1] = providerID; return {} end,
    }))
end
assert(I.Broker:Query("fixture.same-owner", { text = "x" }, {}))
assert(sameExtensionCalls[1] == "alpha")

-- Broker-owned records are not affected by descriptor mutation after Add.
reset()
enabled["owner.extension"] = true
local descriptor = {
    id = "owned", type = "fixture.owned", priority = 5, version = 3,
    requestSchema = { text = "string", limit = "integer?" },
    resultSchema = {
        kind = "array",
        items = { itemID = "integer", name = "string" },
        maxItems = 2,
    },
    query = function() return { { itemID = 1, name = "original" } } end,
}
assert(I.Broker:Add("owner.extension", descriptor))
descriptor.id = "mutated"
descriptor.priority = -100
descriptor.requestSchema.text = "number"
descriptor.resultSchema.items.name = "number"
descriptor.query = function() error("mutated callback must not run") end
local owned, ownedErr, ownedInfo = I.Broker:Query("fixture.owned", { text = "x" }, {})
assert(owned and not ownedErr and owned[1].name == "original")
assert(ownedInfo.providerID == "owned" and ownedInfo.version == 3)

-- Version ranges filter before priority while preserving priority order among compatible providers.
reset()
enabled["high.extension"] = true
enabled["low.extension"] = true
local versionCalls = {}
assert(I.Broker:Add("high.extension", {
    id = "v3", type = "fixture.versioned", version = 3, priority = 100,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() versionCalls[#versionCalls + 1] = 3; return { { itemID = 3, name = "v3" } } end,
}))
assert(I.Broker:Add("low.extension", {
    id = "v1", type = "fixture.versioned", version = 1, priority = 1,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() versionCalls[#versionCalls + 1] = 1; return { { itemID = 1, name = "v1" } } end,
}))
local exact, exactErr, exactInfo = I.Broker:Query({
    type = "fixture.versioned", minVersion = 1, maxVersion = 1, request = { text = "x" },
}, {})
assert(exact and not exactErr and exact[1].itemID == 1 and exactInfo.version == 1)
assert(#versionCalls == 1 and versionCalls[1] == 1, "higher-priority incompatible provider was called")
local ranged, rangedErr, rangedInfo = I.Broker:Query({
    type = "fixture.versioned", minVersion = 2, maxVersion = 4, request = { text = "x" },
}, {})
assert(ranged and not rangedErr and ranged[1].itemID == 3 and rangedInfo.version == 3)
local _, unavailableVersion = I.Broker:Query({
    type = "fixture.versioned", minVersion = 4, maxVersion = 5, request = { text = "x" },
}, {})
assert(unavailableVersion and unavailableVersion.code == "PROVIDER_UNAVAILABLE")
for _, invalidRange in ipairs({
    { minVersion = "1", maxVersion = 3 },
    { minVersion = 1.5, maxVersion = 3 },
    { minVersion = 4, maxVersion = 3 },
}) do
    invalidRange.type = "fixture.versioned"
    invalidRange.request = { text = "x" }
    local _, rangeErr = I.Broker:Query(invalidRange, {})
    assert(rangeErr and rangeErr.code == "INVALID_SCHEMA" and rangeErr.field == "versionRange")
end

-- Disabled owners are skipped, and a callback failure cannot poison a healthy fallback.
reset()
enabled["disabled.extension"] = false
enabled["broken.extension"] = true
enabled["healthy.extension"] = true
assert(I.Broker:Add("disabled.extension", {
    id = "disabled", type = "fixture.fallback", priority = 100,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() error("disabled provider ran") end,
}))
assert(I.Broker:Add("broken.extension", {
    id = "broken", type = "fixture.fallback", priority = 50,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() error("provider failure") end,
}))
assert(I.Broker:Add("healthy.extension", {
    id = "healthy", type = "fixture.fallback", priority = 1,
    requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() return { { itemID = 7, name = "fallback" } } end,
}))
local fallback, fallbackErr, fallbackInfo = I.Broker:Query("fixture.fallback", { text = "x" }, {})
assert(fallback and not fallbackErr and fallback[1].itemID == 7)
assert(fallbackInfo.extensionID == "healthy.extension")
enabled["broken.extension"] = false
enabled["healthy.extension"] = false
local _, disabledErr = I.Broker:Query("fixture.fallback", { text = "x" }, {})
assert(disabledErr and disabledErr.code == "PROVIDER_UNAVAILABLE")
enabled["broken.extension"] = true
enabled["healthy.extension"] = true

-- Request, callback, invalid result, and result-limit failures remain distinguishable.
local _, requestErr = I.Broker:Query("fixture.fallback", { text = 42 }, {})
assert(
    requestErr and requestErr.code == "INVALID_SCHEMA" and requestErr.field == "request",
    "unexpected request error: " .. tostring(requestErr and requestErr.code) .. "/" .. tostring(requestErr and requestErr.field)
)

reset()
enabled["broken.extension"] = true
assert(I.Broker:Add("broken.extension", {
    id = "throws", type = "fixture.error", requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() error("private details") end,
}))
local _, callbackErr = I.Broker:Query("fixture.error", { text = "x" }, {})
assert(callbackErr and callbackErr.code == "PROVIDER_ERROR" and callbackErr.cause == "CALLBACK_ERROR")
assert(callbackErr.extensionID == "broken.extension" and callbackErr.providerID == "throws")

reset()
enabled["invalid.extension"] = true
assert(I.Broker:Add("invalid.extension", {
    id = "invalid-result", type = "fixture.invalid", requestSchema = requestSchema, resultSchema = resultSchema,
    query = function() return { { itemID = "bad", name = "invalid" } } end,
}))
local _, resultErr = I.Broker:Query("fixture.invalid", { text = "x" }, {})
assert(resultErr and resultErr.code == "INVALID_RESULT" and resultErr.cause == "INVALID_SCHEMA")

reset()
enabled["limit.extension"] = true
assert(I.Broker:Add("limit.extension", {
    id = "too-many", type = "fixture.limit", requestSchema = requestSchema, resultSchema = resultSchema,
    query = function()
        return {
            { itemID = 1, name = "one" },
            { itemID = 2, name = "two" },
            { itemID = 3, name = "three" },
        }
    end,
}))
local _, limitErr = I.Broker:Query("fixture.limit", { text = "x" }, {})
assert(limitErr and limitErr.code == "RESULT_LIMIT" and limitErr.cause == "RESULT_LIMIT")

-- RemoveExtension removes only records owned by that extension.
reset()
enabled["one.extension"] = true
enabled["two.extension"] = true
for _, extensionID in ipairs({ "one.extension", "two.extension" }) do
    assert(I.Broker:Add(extensionID, {
        id = "items", type = "fixture.remove", requestSchema = requestSchema, resultSchema = resultSchema,
        query = function() return { { itemID = extensionID == "one.extension" and 1 or 2, name = extensionID } } end,
    }))
end
I.Broker:RemoveExtension("one.extension")
local remaining, remainingErr, remainingInfo = I.Broker:Query("fixture.remove", { text = "x" }, {})
assert(remaining and not remainingErr and remaining[1].itemID == 2)
assert(remainingInfo.extensionID == "two.extension")
I.Broker:RemoveExtension("two.extension")
local _, missingErr = I.Broker:Query("fixture.remove", { text = "x" }, {})
assert(missingErr and missingErr.code == "CAPABILITY_NOT_FOUND")

-- The public Extension handle forwards the complete capability envelope unchanged.
dofile("package/Lychee/Core/ExtensionRegistry.lua")
local Registry = I.Registry
local forwardedRequest, forwardedContext
local brokerQuery = I.Broker.Query
I.Broker.Query = function(_, request, context)
    forwardedRequest, forwardedContext = request, context
    return { { itemID = 9, name = "forwarded" } }, nil, { version = 2 }
end
local publicHandle = Registry:_Handle({
    id = "consumer.extension", state = "enabled", ownerEnabled = true,
    descriptor = {}, sources = {},
})
local publicRequest = {
    type = "fixture.public", minVersion = 2, maxVersion = 4,
    request = { text = "needle", limit = 1 },
}
local publicContext = { generation = 7 }
local publicResult, publicErr, publicInfo = publicHandle:QueryCapability(publicRequest, publicContext)
assert(publicResult and not publicErr and publicInfo.version == 2)
assert(forwardedRequest == publicRequest and forwardedContext == publicContext)
I.Broker.Query = brokerQuery

print("Lychee capability broker PASS")
