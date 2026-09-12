local I = _G.LycheeInternal
local facade = _G.Lychee or {}
facade.API_VERSION = I.VERSION.api
facade.API_REVISION = I.VERSION.revision
function facade:Supports(api, revision)
    revision = revision == nil and 1 or revision
    return type(api) == "number" and api == self.API_VERSION
        and type(revision) == "number" and revision >= 1 and revision < math.huge
        and revision == math.floor(revision) and revision <= self.API_REVISION
end
function facade:RegisterProvider(desc)
    return I.Providers:Register(desc)
end
function facade:RegisterReady(fn)
    if type(fn) ~= "function" then return nil, { code = "INVALID_CALLBACK" } end
    return I.Registry:RegisterReady(fn)
end
function facade:IsReady() return I.Registry.ready end
facade.RegisterExtension, facade.RegisterSearchSource = nil, nil
_G.Lychee = facade
I.PublicAPI = facade
