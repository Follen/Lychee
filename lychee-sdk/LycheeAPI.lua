-- Development-only API helper. This file is not loaded by the Lychee Host.
-- Third-party AddOns depend on OptionalDeps: Lychee and consume _G.Lychee.
local API = {
    API_VERSION = 1,
    API_REVISION = 1,
    ERROR_CODES = {
        SDK_UNAVAILABLE = "SDK_UNAVAILABLE",
        UNSUPPORTED_API = "UNSUPPORTED_API",
        INCOMPATIBLE_HOST = "INCOMPATIBLE_HOST",
        INVALID_SCHEMA = "INVALID_SCHEMA",
        INVALID_RESULT = "INVALID_RESULT",
        INVALID_INTERACTION = "INVALID_INTERACTION",
        REGISTRATION_CLOSED = "REGISTRATION_CLOSED",
        CALLBACK_ERROR = "CALLBACK_ERROR",
        CAPABILITY_NOT_FOUND = "CAPABILITY_NOT_FOUND",
        PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE",
        PROVIDER_ERROR = "PROVIDER_ERROR",
        RESULT_LIMIT = "RESULT_LIMIT",
        COMBAT_LOCKED = "COMBAT_LOCKED",
        ACTION_UNAVAILABLE = "ACTION_UNAVAILABLE",
        DRAG_UNSUPPORTED = "DRAG_UNSUPPORTED",
    },
}

function API.GetFacade()
    return _G.Lychee
end

function API.Supports(facade, apiVersion, minRevision)
    if type(facade) ~= "table" or type(facade.Supports) ~= "function" then
        return false, { code = API.ERROR_CODES.SDK_UNAVAILABLE, retryable = true }
    end
    local ok, supported = pcall(facade.Supports, facade, apiVersion or API.API_VERSION, minRevision or 1)
    if not ok or not supported then
        return false, { code = API.ERROR_CODES.UNSUPPORTED_API, retryable = false }
    end
    return true
end

-- This helper intentionally forwards only the public facade. It never creates a
-- sibling AddOn or mutates Host registries.
function API.RegisterExtension(facade, descriptor)
    if type(facade) ~= "table" or type(facade.RegisterExtension) ~= "function" then
        return nil, { code = API.ERROR_CODES.SDK_UNAVAILABLE, retryable = true }
    end
    return facade:RegisterExtension(descriptor)
end

return API
