local I=_G.LycheeInternal
local D={}
I.ProviderDefinition=D
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function failure(code, field, owner)
    return nil, { code = code, field = field, providerID = owner, retryable = false }
end
local function validID(id)
    return type(id) == "string" and #id > 0 and #id <= 64 and id:match("^[a-z0-9][a-z0-9%.%-]*$")
end
local function keys(value, allowed, field)
    for key in pairs(value) do if not allowed[key] then return failure("INVALID_SCHEMA", field .. "." .. tostring(key)) end end
    return true
end

function D:Compile(definition,limit)
    local ok, err = I.Boundary:Validate(definition, "provider", {
        maxFields = limit, maxDepth = 12,
        callbacks = { readEntry = true, query = true, resolve = true, resolveTarget=true, describe=true, observe=true, prepare=true, releaseSearch=true, run = true, begin = true, create = true, onEnable = true, onDisable = true },
    })
    if not ok then return nil, err end
    if type(definition) ~= "table" then return failure("INVALID_SCHEMA", "provider") end
    ok, err = keys(definition, { id=true, apiVersion=true, version=true, title=true, addon=true, description=true, icon=true, resource=true, targetView=true,
        entries=true, entryMode=true, readEntry=true, query=true, resolve=true, resolveTarget=true, describe=true, observe=true, prepare=true, releaseSearch=true, searchable=true, searchMode=true, searchGlobal=true, searchPrefixes=true, searchKeywords=true, actions=true, drags=true, views=true, scope=true, i18n=true, onEnable=true, onDisable=true }, "provider")
    if not ok then return nil, err end
    if not validID(definition.id) or type(definition.version) ~= "string" or definition.version == "" then return failure("INVALID_SCHEMA", "provider.id/version") end
    if not _G.Lychee:Supports(definition.apiVersion) then return failure("UNSUPPORTED_API", "apiVersion") end
    if I.Search.ProviderPolicy then
        local valid,field=I.Search.ProviderPolicy:ValidateDefinition(definition)
        if not valid then return failure("INVALID_SCHEMA",field) end
    end
    if definition.searchable~=nil then
        if type(definition.searchable)~="boolean" then return failure("INVALID_SCHEMA","searchable") end
    end
    if definition.scope ~= nil and type(definition.scope) ~= "table" then return failure("INVALID_SCHEMA", "scope") end
    ok, err = I.Boundary:ValidateScope(definition.scope or {},"scope")
    if not ok then return nil, err end
    local localizer
    if definition.i18n~=nil then
        if not I.ProviderLocales then return failure("UNSUPPORTED_API","i18n") end
        localizer,err=I.ProviderLocales:Compile(definition.i18n)
        if not localizer then return nil,err end
    end
    local inputEntries,ownedDefinition=definition.entries,{}
    for key,value in pairs(definition) do if key~="entries" and key~="i18n" then ownedDefinition[key]=copy(value) end end
    definition=ownedDefinition
    -- An omitted product scope targets retail; other clients require an explicit declaration.
    if not definition.scope or (not definition.scope.product and not definition.scope.products) then
        definition.scope=definition.scope or {};definition.scope.product="retail"
    end
    definition.entries=inputEntries
    if localizer then
        definition.title,err=localizer:Resolve(definition.title)
        if not definition.title then
            if err then return nil,err end
            return failure("INVALID_SCHEMA","provider.title")
        end
        if definition.description~=nil then
            definition.description,err=localizer:Resolve(definition.description)
            if not definition.description then return nil,err or {code="INVALID_SCHEMA",field="provider.description"} end
        end
        for _,field in ipairs({"actions","drags"}) do
            if type(definition[field])=="table" then
                for _,action in pairs(definition[field]) do
                    if type(action)=="table" and action.title then
                        action.title,err=localizer:Resolve(action.title)
                        if not action.title then return nil,err end
                    end
                end
            end
        end
    end
    if definition.description~=nil and (type(definition.description)~="string" or #definition.description>4096) then
        return failure("INVALID_SCHEMA","provider.description")
    end
    if definition.entryMode~=nil and definition.entryMode~="entries" and definition.entryMode~="documents" then return failure("INVALID_SCHEMA","entryMode") end
    if (definition.entryMode=="documents")~=(type(definition.readEntry)=="function") then return failure("INVALID_SCHEMA","readEntry") end
    if definition.entries == nil and type(definition.query) ~= "function" and definition.actions == nil then return failure("INVALID_SCHEMA", "entries/query") end
    if definition.entries ~= nil and type(definition.entries) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
    for _, field in ipairs({ "readEntry", "query", "resolve", "resolveTarget", "describe", "observe", "prepare", "releaseSearch", "onEnable", "onDisable" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "function" then return failure("INVALID_SCHEMA", field) end
    end
    for _, field in ipairs({ "actions", "drags", "views" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "table" then return failure("INVALID_SCHEMA", field) end
        for id, value in pairs(definition[field] or {}) do
            local callback = field == "actions" and "run" or field == "drags" and "begin" or "create"
            if not validID(id) or type(value) ~= "table" or type(value[callback]) ~= "function" then return failure("INVALID_SCHEMA", field) end
            local allowed = field == "views" and { create=true, stateSchema=true } or field=="actions" and {title=true,run=true,schema=true,actionVersion=true,execution=true,absolute=true,conflictKey=true,panel=true} or {title=true,[callback]=true}
            ok, err = keys(value, allowed, field .. "." .. id); if not ok then return nil, err end
            if field=="actions" and value.schema~=nil then
                local schema,problem=I.Invocations:ValidateAction(value)
                if not schema then return nil,problem end
                value.schema=schema
            end
            if field ~= "views" and (type(value.title) ~= "string" or value.title == "") then return failure("INVALID_SCHEMA", field .. ".title") end
            if field == "views" and type(value.stateSchema) ~= "table" then return failure("INVALID_SCHEMA", "views.stateSchema") end
            if field == "views" then
                ok, err = I.Boundary:Validate(value.stateSchema, "views.stateSchema")
                if not ok then return nil, err end
            end
        end
    end
    if definition.addon~=nil or I.AddonDiscovery and I.AddonDiscovery:Get(definition.id) then
        local valid,problem=I.AddonDiscovery:ValidateRegistration(definition)
        if not valid then return nil,problem end
    end
    return definition,localizer,inputEntries
end
