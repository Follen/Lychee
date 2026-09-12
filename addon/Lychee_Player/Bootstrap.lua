-- Project package composition; not a public SDK contract.
local addonName,I=...
I.name=addonName
I.Modules,I.ProviderLocaleData={},{}
local SDK=assert(_G.Lychee and _G.Lychee.SDK,"LYCHEE_SDK_UNAVAILABLE")
I.SDK=SDK
I.Search={Normalizer=SDK.Normalizer,RuntimeIdentity=SDK.RuntimeIdentity}
I.Locale={code=type(GetLocale)=="function" and GetLocale() or "enUS"}
function I.Locale:IsChinese() return self.code=="zhCN" or self.code=="zhTW" end
I.ProviderLocales={}
local translators={}
local translatorMeta
function I.ProviderLocales:ForProvider(id)
    local resources=I.ProviderLocaleData[id]
    local cached=translators[id]
    if cached and cached.resources==resources and rawget(cached,"_en")==resources.enUS and rawget(cached,"_zh")==resources.zhCN and rawget(cached,"_tw")==resources.zhTW and rawget(cached,"_locale")==I.Locale.code then return cached end
    local translator,err=SDK.CompileLocales(resources)
    if not translator then error(err and err.code or "INVALID_LOCALES") end
    translator.resources=resources
    translator._en,translator._zh,translator._tw,translator._locale=resources.enUS,resources.zhCN,resources.zhTW,I.Locale.code
    if not translatorMeta then
        local methods=getmetatable(translator).__index
        translatorMeta={__index=function(self,key) return methods[key] or self.dictionary[key] or key end}
    end
    setmetatable(translator,translatorMeta)
    translators[id]=translator
    return translator
end
local S={}
I.Modules.Support=S
function S:Scope(id)
    for _,definition in ipairs(I.Modules.Definitions) do if definition.id==id then return definition.scope end end
    error("Unknown Provider: "..tostring(id))
end
function S:Available(definition,product)
    local supported=false
    for _,value in ipairs(definition.scope.products) do if value==product then supported=true;break end end
    if not supported then return false end
    for _,symbol in ipairs(definition.requires or {}) do
        local value=_G
        for part in symbol:gmatch("[^.]+") do value=type(value)=="table" and value[part] or nil end
        if type(value)~="function" then return false end
    end
    return true
end
local function less(a,b)
    if a.confidence~=b.confidence then return a.confidence>b.confidence end
    local ac=type(a.entry.category)=="table" and a.entry.category.order or 0
    local bc=type(b.entry.category)=="table" and b.entry.category.order or 0
    if ac~=bc then return ac<bc end
    return a.entry.id<b.entry.id
end
function S:Register(definition)
    local metadata=I.Modules.Presentation[definition.id]
    definition.source,definition.description,definition.icon,definition.order=
        metadata.source,metadata.description,metadata.icon,metadata.order
    definition.searchGlobal=definition.searchGlobal~=false
    definition.searchPrefixes=definition.searchPrefixes or metadata.prefixes or {}
    definition.searchKeywords=definition.searchKeywords or {}
    local initial,query,resolve,start,stop=definition.catalog,definition.query,definition.resolve,definition.onEnable,definition.onDisable
    definition.catalog=nil
    local actual,enabled,catalog=nil,false,nil
    local handle={}
    for _,method in ipairs({"GetState","Resources","GetDiagnostics","Text","SetAvailability","Invalidate","Unregister"}) do
        local name=method
        handle[name]=function(_,...) return actual[name](actual,...) end
    end
    handle.id=definition.id
    if initial then
        local err
        catalog,err=SDK.CreateCatalog({id=definition.id,title=definition.title,scope=definition.scope,i18n=definition.i18n,
            actions=definition.actions,drags=definition.drags,views=definition.views,
            active=function() return enabled end,
            changed=function() if actual and enabled then actual:Invalidate() end end})
        if not catalog then return nil,err end
        handle.catalog=catalog
    end
    definition.query=function(request,reply,context)
        if catalog and not query then assert(catalog:Query(request,reply));return end
        local base=catalog and assert(catalog:Search(request)) or {}
        if not query then reply(base);return end
        return query(request,function(entries)
            local hits,err=SDK.Score(request,entries,definition.scope)
            if not hits then error(err and err.code or "INVALID_RESULT") end
            local seen={}
            for _,hit in ipairs(base) do seen[hit.entry.id]=true end
            for _,hit in ipairs(hits) do if not seen[hit.entry.id] then base[#base+1]=hit;seen[hit.entry.id]=true end end
            table.sort(base,less)
            while #base>256 do base[#base]=nil end
            return reply(base)
        end,context)
    end
    if catalog or resolve then
        definition.resolve=function(id,context) return (catalog and catalog:Resolve(id)) or (resolve and resolve(id,context)) end
    end
    definition.onEnable=function(owner)
        actual,enabled=owner,true
        if catalog and #initial>0 then assert(catalog:Update({replace=initial})) end
        local cleanup=start and start(handle)
        return function(reason)
            enabled=false
            if cleanup then cleanup(reason) end
            if catalog then
                if reason=="unregister" then catalog:Close() else catalog:Clear() end
            end
        end
    end
    definition.onDisable=stop
    local result,err=_G.Lychee:RegisterProvider(definition)
    if not result then if catalog then catalog:Close() end;return nil,err end
    actual=result
    return handle
end
function I:Initialize()
    if self.initialized then return end
    self.initialized=true
    local product=self.Search.RuntimeIdentity:Current().product
    for _,definition in ipairs(self.Modules.Definitions) do
        local module=self.Modules[definition.module]
        if module and type(module.Init)=="function" and S:Available(definition,product) then module:Init() end
    end
end
