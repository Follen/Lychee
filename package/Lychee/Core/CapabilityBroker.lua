local I = _G.LycheeInternal
local Broker = { providers = {}, byExt = {}, nextSequence = 0 }
I.Broker = Broker

local function failure(code, field, record, cause)
    return {
        code = code,
        field = field,
        extensionID = record and record.extensionID or nil,
        providerID = record and record.providerID or nil,
        cause = cause,
        retryable = false,
    }
end

local function validNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function integer(value)
    return type(value) == "number" and value == math.floor(value)
end

local function copySchema(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil, false end
    seen[value] = true
    local copy = {}
    for key, child in pairs(value) do
        local childCopy, ok = copySchema(child, seen)
        if ok == false then return nil, false end
        copy[key] = childCopy
    end
    seen[value] = nil
    return copy, true
end

local function providerBefore(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    if a.extensionID ~= b.extensionID then return a.extensionID < b.extensionID end
    if a.providerID ~= b.providerID then return a.providerID < b.providerID end
    return a.sequence < b.sequence
end

local function ownerEnabled(record)
    local registry = I.Registry
    if not registry or type(registry.IsEnabled) ~= "function" then return true end
    local ok, enabled = pcall(registry.IsEnabled, registry, record.extensionID)
    return ok and enabled == true
end

local function validateSchema(value, schema, field)
    local boundary = I.Boundary
    if not boundary or type(boundary.ValidateSchema) ~= "function" then
        return nil, failure("INVALID_SCHEMA", field)
    end
    return boundary:ValidateSchema(value, schema, field)
end

function Broker:Add(extensionID, provider)
    if type(extensionID) ~= "string" or extensionID == "" or type(provider) ~= "table" or
        type(provider.type) ~= "string" or provider.type == "" or type(provider.query) ~= "function" or
        (provider.priority ~= nil and not validNumber(provider.priority)) or
        (provider.version ~= nil and not integer(provider.version)) then
        return nil, failure("INVALID_SCHEMA", "provider")
    end

    local providerID = provider.id
    if type(providerID) ~= "string" or providerID == "" then providerID = provider.type end
    local requestSchema, requestSchemaOK = copySchema(provider.requestSchema)
    local resultSchema, resultSchemaOK = copySchema(provider.resultSchema)
    if requestSchemaOK == false or resultSchemaOK == false then
        return nil, failure("INVALID_SCHEMA", "providerSchema")
    end
    self.nextSequence = self.nextSequence + 1
    local record = {
        extensionID = extensionID,
        providerID = providerID,
        capabilityType = provider.type,
        priority = provider.priority or 0,
        version = provider.version or 1,
        requestSchema = requestSchema,
        resultSchema = resultSchema,
        query = provider.query,
        sequence = self.nextSequence,
    }

    local list = self.providers[record.capabilityType]
    if not list then
        list = {}
        self.providers[record.capabilityType] = list
    end
    list[#list + 1] = record
    table.sort(list, providerBefore)

    local owned = self.byExt[extensionID]
    if not owned then
        owned = {}
        self.byExt[extensionID] = owned
    end
    owned[#owned + 1] = record
    return true
end

function Broker:RemoveExtension(extensionID)
    local owned = self.byExt[extensionID]
    if not owned then return end
    for ownedIndex = 1, #owned do
        local record = owned[ownedIndex]
        local list = self.providers[record.capabilityType]
        if list then
            for providerIndex = #list, 1, -1 do
                if list[providerIndex] == record then table.remove(list, providerIndex) end
            end
            if #list == 0 then self.providers[record.capabilityType] = nil end
        end
    end
    self.byExt[extensionID] = nil
end

local function parseQuery(capability, requestOrContext, legacyContext)
    if type(capability) ~= "table" then
        return capability, requestOrContext, legacyContext
    end

    local minimum, maximum = capability.minVersion, capability.maxVersion
    if (minimum ~= nil and not integer(minimum)) or (maximum ~= nil and not integer(maximum)) or
        (minimum ~= nil and maximum ~= nil and minimum > maximum) then
        return nil, nil, nil, nil, nil, failure("INVALID_SCHEMA", "versionRange")
    end
    if type(capability.type) ~= "string" or capability.type == "" or capability.request == nil then
        return nil, nil, nil, nil, nil, failure("INVALID_SCHEMA", "request")
    end
    return capability.type, capability.request, requestOrContext, minimum, maximum
end

function Broker:Query(capability, requestOrContext, legacyContext)
    local capabilityType, request, context, minimum, maximum, queryErr =
        parseQuery(capability, requestOrContext, legacyContext)
    if queryErr then return nil, queryErr end
    local list = self.providers[capabilityType]
    if not list then return nil, failure("CAPABILITY_NOT_FOUND", "type") end

    local firstError
    local eligible = false
    for index = 1, #list do
        local record = list[index]
        local versionCompatible = (minimum == nil or record.version >= minimum) and
            (maximum == nil or record.version <= maximum)
        if versionCompatible and ownerEnabled(record) then
            eligible = true
            local requestOK, requestErr = validateSchema(request, record.requestSchema, "request")
            if not requestOK then
                if not firstError then firstError = requestErr or failure("INVALID_SCHEMA", "request") end
            else
                local callbackOK, result = pcall(record.query, request, context)
                if not callbackOK then
                    if not firstError then firstError = failure("PROVIDER_ERROR", "provider.query", record, "CALLBACK_ERROR") end
                else
                    local resultOK, resultErr = validateSchema(result, record.resultSchema, "result")
                    if resultOK then
                        return result, nil, {
                            extensionID = record.extensionID,
                            providerID = record.providerID,
                            version = record.version,
                        }
                    end
                    local code = resultErr and resultErr.code == "RESULT_LIMIT" and "RESULT_LIMIT" or "INVALID_RESULT"
                    local cause = resultErr and resultErr.code or "INVALID_SCHEMA"
                    if not firstError then firstError = failure(code, "provider.result", record, cause) end
                end
            end
        end
    end

    if firstError then return nil, firstError end
    if not eligible then return nil, failure("PROVIDER_UNAVAILABLE", "provider") end
    return nil, failure("PROVIDER_ERROR", "provider")
end

return Broker
