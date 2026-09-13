local I = _G.LycheeInternal
local facade = _G.Lychee or {}
facade.API_VERSION = I.VERSION.api
function facade:Supports(api, ...)
    return select("#", ...) == 0 and type(api) == "string" and api == self.API_VERSION
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

-- Optional shared SDK services. Factories return caller-owned state; this
-- facade never keeps a list of catalogs or copies Provider business data.
local SDK={VERSION="1.0.0",Normalizer={},RuntimeIdentity={}}
setmetatable(SDK.Normalizer,{__index=function(_,key)
    if key=="locale" then return I.Search.Normalizer.locale end
end})
function SDK.CreateCatalog(options) return I.CatalogFactory:Create(options) end
function SDK.Score(request,entries,scope) return I.CatalogFactory:Score(request,entries,scope) end
function SDK.CreateRanker(request) return I.CatalogFactory:CreateRanker(request) end
function SDK.SortHits(request,hits,limit) return I.CatalogFactory:SortHits(request,hits,limit) end
function SDK.CompileLocales(resources) return I.ProviderLocales:Compile(resources) end
for name,fn in pairs(I.Search.Normalizer) do
    if type(fn)=="function" then
        local method=fn
        SDK.Normalizer[name]=function(_,...) return method(I.Search.Normalizer,...) end
    end
end
function SDK.RuntimeIdentity:Current()
    local source=I.Search.RuntimeIdentity:Current()
    return {product=source.product,locale=source.locale,build=source.build,interface=source.interface,version=source.version,signature=source.signature}
end
facade.SDK=SDK
local pendingAddons={}
function SDK.WhenSavedVariablesReady(name,callback)
    if type(name)~="string" or #name==0 or #name>128 or type(callback)~="function" then return nil,{code="INVALID_SCHEMA"} end
    if #pendingAddons>=64 then return nil,{code="RESOURCE_LIMIT"} end
    local row={name=name,callback=callback}
    local token={}
    function token:Cancel()
        row.callback=nil
        for at,value in ipairs(pendingAddons) do if value==row then table.remove(pendingAddons,at);break end end
        if #pendingAddons==0 then I.SetAddonLoadWatch(false) end
        return true
    end
    local _,loaded
    if C_AddOns and C_AddOns.IsAddOnLoaded then _,loaded=C_AddOns.IsAddOnLoaded(name) end
    if loaded then row.callback=nil;callback();return token end
    pendingAddons[#pendingAddons+1]=row;row.token=token
    if #pendingAddons==1 then I.SetAddonLoadWatch(true) end
    return token
end
function I.DeliverAddonLoaded(name)
    local ready={}
    for _,row in ipairs(pendingAddons) do if row.name==name then ready[#ready+1]=row end end
    for _,row in ipairs(ready) do
        local callback=row.callback;row.token:Cancel()
        if callback then
            local ok,err=pcall(callback)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
    end
end
function facade:OpenSettings()
    local palette=I.Host and I.Host.PaletteController
    if not palette then return false,"HOST_UNAVAILABLE" end
    palette:Create()
    return palette:OpenSettings()
end
local visibilityListeners={}
function facade:ObservePalette(callback)
    if type(callback)~="function" then return nil,{code="INVALID_CALLBACK"} end
    if #visibilityListeners>=64 then return nil,{code="RESOURCE_LIMIT"} end
    local row={callback=callback};visibilityListeners[#visibilityListeners+1]=row
    return {Cancel=function()
        row.callback=nil
        for at,value in ipairs(visibilityListeners) do if value==row then table.remove(visibilityListeners,at);break end end
        return true
    end}
end
function I.NotifyPaletteVisibility(visible)
    -- Snapshot membership to keep callback removal/reentry finite.
    local callbacks={}
    for at,row in ipairs(visibilityListeners) do callbacks[at]=row end
    for _,row in ipairs(callbacks) do if row.callback then pcall(row.callback,visible) end end
end
