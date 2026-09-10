-- Optional helper; not an AddOn and never a second Host implementation.
local API = { API_VERSION=2, API_REVISION=4, ERROR_CODES={} }
for _, code in ipairs({ "INVALID_LOCALES", "INVALID_LOCALE_KEY", "INVALID_LOCALE_FORMAT", "LOCALE_LIMIT", "SDK_UNAVAILABLE", "UNSUPPORTED_API", "INVALID_SCHEMA", "DUPLICATE_ID", "RESULT_LIMIT",
    "UNKNOWN_ACTION", "UNKNOWN_VIEW", "UNKNOWN_DRAG", "STALE_HANDLE", "PROVIDER_DISABLED", "STALE_REQUEST",
    "STALE_RESULT", "UPDATE_IN_PROGRESS", "CALLBACK_ERROR", "INVALID_CALLBACK", "INVALID_RESULT", "QUERY_TIMEOUT", "ACTION_FAILED",
    "ACTION_UNAVAILABLE", "COMBAT_LOCKED", "ACTION_REQUIRES_HARDWARE_CLICK", "MENU_UNAVAILABLE", "NO_ACTION" }) do
    API.ERROR_CODES[code]=code
end
function API.GetFacade() return _G.Lychee end
function API.Supports(facade, apiVersion, minRevision)
    if type(facade)~="table" or type(facade.Supports)~="function" then return false,{code="SDK_UNAVAILABLE",retryable=true} end
    if apiVersion==nil then apiVersion=API.API_VERSION end
    if minRevision==nil then minRevision=API.API_REVISION end
    local ok,supported=pcall(facade.Supports,facade,apiVersion,minRevision)
    if not ok or not supported then return false,{code="UNSUPPORTED_API",retryable=false} end
    return true
end
function API.RegisterProvider(facade, definition)
    if type(facade)~="table" or type(facade.RegisterProvider)~="function" then return nil,{code="SDK_UNAVAILABLE",retryable=true} end
    return facade:RegisterProvider(definition)
end
return API
