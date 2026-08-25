local I = _G.LycheeInternal
local facade = _G.Lychee or {}
facade.API_VERSION = I.VERSION.api
facade.API_REVISION = I.VERSION.revision
function facade:Supports(api, revision)
    return api == self.API_VERSION and (revision or 1) <= self.API_REVISION
end
function facade:RegisterExtension(desc)
    if not self:Supports(desc and desc.apiVersion or 1, desc and desc.minApiRevision or 1) then
        return nil, { code = "UNSUPPORTED_API" }
    end
    return I.Registry:Begin(desc)
end
function facade:RegisterReady(fn)
    if type(fn) ~= "function" then return nil, { code = "INVALID_CALLBACK" } end
    if I.Registry.ready then pcall(fn, { apiVersion=self.API_VERSION, apiRevision=self.API_REVISION })
    else I.Registry:OnChange(function(_, state) if state == "registered" then pcall(fn, { apiVersion=self.API_VERSION, apiRevision=self.API_REVISION }) end end) end
    return true
end
function facade:IsReady() return I.Registry.ready end
_G.Lychee = facade
I.PublicAPI = facade
