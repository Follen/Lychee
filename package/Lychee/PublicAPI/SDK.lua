local I = _G.LycheeInternal
local facade = _G.Lychee or {}
facade.API_VERSION = I.VERSION.api
facade.API_REVISION = I.VERSION.revision
function facade:Supports(api, revision)
    return api == self.API_VERSION and (revision or 1) <= self.API_REVISION
end
function facade:RegisterExtension(desc)
    if type(desc)~="table" then return nil,{code="INVALID_SCHEMA",field="descriptor",retryable=false} end
    if not self:Supports(desc.apiVersion or 0, desc.minApiRevision or 1) then
        return nil, { code = "UNSUPPORTED_API" }
    end
    return I.Registry:Begin(desc,{public=true})
end
function facade:RegisterReady(fn)
    if type(fn) ~= "function" then return nil, { code = "INVALID_CALLBACK" } end
    return I.Registry:RegisterReady(function(info) pcall(fn, info) end)
end
function facade:IsReady() return I.Registry.ready end
function facade:RegisterSearchSource(desc)
    return nil, { code = "INVALID_SCHEMA", field = "searchSource", hint = "REGISTER_ON_EXTENSION_DRAFT" }
end
_G.Lychee = facade
I.PublicAPI = facade
