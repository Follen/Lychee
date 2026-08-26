local I = _G.LycheeInternal
local Boundary = { MAX_DEPTH = 8, MAX_FIELDS = 128 }
I.Boundary = Boundary

local function failure(code, field)
    return nil, { code = code, field = field, retryable = false }
end

local function access(value, field)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok then return failure("INACCESSIBLE_VALUE", field) end
        if secret then return failure("SECRET_VALUE", field) end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok or accessible == false then return failure("INACCESSIBLE_VALUE", field) end
    end
    return true
end

local function visit(value, options, seen, depth, field, parentKey)
    local ok, why = access(value, field)
    if not ok then return nil, why end
    local kind = type(value)
    if kind == "function" then
        if options.callbacks and type(parentKey) == "string" and options.callbacks[parentKey] then return true end
        return failure("INVALID_SCHEMA", field)
    end
    if kind == "nil" or kind == "boolean" or kind == "string" then return true end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return failure("INVALID_SCHEMA", field) end
        return true
    end
    if kind ~= "table" then return failure("INVALID_SCHEMA", field) end
    if type(canaccesstable) == "function" then
        local tableOK, accessible = pcall(canaccesstable, value)
        if not tableOK or accessible == false then return failure("INACCESSIBLE_VALUE", field) end
    end
    if getmetatable(value) ~= nil or seen[value] or depth >= (options.maxDepth or Boundary.MAX_DEPTH) then
        return failure("INVALID_SCHEMA", field)
    end
    seen[value] = true
    local count = 0
    for key, child in next, value do
        count = count + 1
        if count > (options.maxFields or Boundary.MAX_FIELDS) then seen[value] = nil; return failure("INVALID_SCHEMA", field) end
        local keyOK, keyErr = visit(key, options, seen, depth + 1, field, nil)
        if not keyOK then seen[value] = nil; return nil, keyErr end
        local childOK, childErr = visit(child, options, seen, depth + 1, field, key)
        if not childOK then seen[value] = nil; return nil, childErr end
    end
    seen[value] = nil
    return true
end

function Boundary:Validate(value, field, options)
    return visit(value, options or {}, {}, 0, field, nil)
end

local function schemaValue(boundary, value, schema, field)
    if schema == nil or schema == "any" then return true end
    local optional = false
    if type(schema) == "string" and schema:sub(-1) == "?" then
        optional = true
        schema = schema:sub(1, -2)
    end
    if value == nil then return optional and true or failure("INVALID_SCHEMA", field) end
    if type(schema) == "string" then
        local kind = type(value)
        if schema == "integer" then return kind == "number" and value == math.floor(value) and true or failure("INVALID_SCHEMA", field) end
        return kind == schema and true or failure("INVALID_SCHEMA", field)
    end
    if type(schema) ~= "table" or type(value) ~= "table" then return failure("INVALID_SCHEMA", field) end
    if schema.kind == "array" then
        local count = 0
        for key in pairs(value) do if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return failure("INVALID_SCHEMA", field) end; count=count+1 end
        if count ~= #value then return failure("INVALID_SCHEMA", field) end
        if count > (schema.maxItems or Boundary.MAX_FIELDS) then return failure("RESULT_LIMIT", field) end
        for i=1,count do local ok,why=schemaValue(boundary,value[i],schema.items,field); if not ok then return nil,why end end
        return true
    end
    for key, childSchema in pairs(schema) do
        local ok,why=schemaValue(boundary,value[key],childSchema,field)
        if not ok then return nil,why end
    end
    for key in pairs(value) do if schema[key] == nil then return failure("INVALID_SCHEMA",field) end end
    return true
end

function Boundary:ValidateSchema(value, schema, field)
    local ok, why = self:Validate(value, field)
    if not ok then return nil, why end
    return schemaValue(self, value, schema, field)
end

local function schemaFailure(field)
    return nil, { code = "INVALID_SCHEMA", field = field, retryable = false }
end

local function stableID(value, maximum)
    return type(value) == "string" and #value > 0 and #value <= (maximum or 128)
        and value:match("^[A-Za-z0-9][A-Za-z0-9%._:%-/]*$") ~= nil
end

local function positiveInteger(value)
    return type(value) == "number" and value == math.floor(value) and value > 0
end

local function allowedKeys(value, keys, field)
    for key in pairs(value) do
        if type(key) ~= "string" or not keys[key] then return schemaFailure(field .. "." .. tostring(key)) end
    end
    return true
end

local function validateIntent(value, field)
    if type(value) ~= "table" then return schemaFailure(field) end
    local ok, why = Boundary:Validate(value, field)
    if not ok then return nil, why end
    if type(value.type) ~= "string" or value.type == "" or
        type(value.version) ~= "number" or value.version ~= math.floor(value.version) then
        return schemaFailure(field)
    end
    if value.payload ~= nil and type(value.payload) ~= "table" then return schemaFailure(field .. ".payload") end
    return true
end

function Boundary:ValidateSearchAction(action, field)
    field = field or "action"
    if type(action) ~= "table" then return schemaFailure(field) end
    local ok, why = self:Validate(action, field)
    if not ok then return nil, why end
    local keyOK, keyErr = allowedKeys(action, {
        id = true, title = true, kind = true, intent = true, panel = true, state = true, spellID = true,
    }, field)
    if not keyOK then return nil, keyErr end
    if not stableID(action.id, 64) then return schemaFailure(field .. ".id") end
    local kind = action.kind
    if kind ~= "intent" and kind ~= "open-panel" and kind ~= "secure-spell" and kind ~= "drag-spell" then
        return schemaFailure(field .. ".kind")
    end
    if action.title ~= nil and type(action.title) ~= "string" and type(action.title) ~= "table" then
        return schemaFailure(field .. ".title")
    end
    if kind == "intent" and action.intent == nil then return schemaFailure(field .. ".intent") end
    if kind == "open-panel" and not stableID(action.panel, 96) then return schemaFailure(field .. ".panel") end
    if kind == "open-panel" and action.state ~= nil then
        local stateOK, stateErr = self:Validate(action.state, field .. ".state")
        if not stateOK then return nil, stateErr end
    end
    if (kind == "secure-spell" or kind == "drag-spell") and not positiveInteger(action.spellID) then
        return schemaFailure(field .. ".spellID")
    end
    if action.intent ~= nil then
        local intentOK, intentErr = validateIntent(action.intent, field .. ".intent")
        if not intentOK then return nil, intentErr end
    end
    return true
end

local function validateTextField(value, field)
    if value == nil or type(value) == "string" then return true end
    if type(value) ~= "table" then return schemaFailure(field) end
    for key, item in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            if type(key) ~= "string" then return schemaFailure(field) end
            if type(item) ~= "string" then return schemaFailure(field .. "." .. key) end
        elseif type(item) ~= "string" and type(item) ~= "table" then
            return schemaFailure(field .. "[" .. key .. "]")
        end
        if type(item) == "table" then
            local ok, why = Boundary:Validate(item, field .. "[" .. key .. "]")
            if not ok then return nil, why end
            if type(item.text) ~= "string" or item.text == "" then return schemaFailure(field .. "[" .. key .. "].text") end
        end
    end
    return true
end

function Boundary:ValidateSearchRecord(record, field)
    field = field or "record"
    if type(record) ~= "table" then return schemaFailure(field) end
    local ok, why = self:Validate(record, field)
    if not ok then return nil, why end
    local keyOK, keyErr = allowedKeys(record, {
        id = true, kind = true, category = true, title = true, subtitle = true, subtext = true,
        aliases = true, keywords = true, description = true, icon = true, scope = true,
        actions = true, primaryActionID = true, drag = true, payload = true,
        availability = true,
        _extensionID = true,
    }, field)
    if not keyOK then return nil, keyErr end
    if not stableID(record.id) or type(record.kind) ~= "string" or record.kind == "" then
        return schemaFailure(field)
    end
    if not record.title and not record.aliases and not record.keywords and not record.description and not record.category then
        return schemaFailure(field .. ".content")
    end
    for _, name in ipairs({ "title", "subtitle", "subtext", "aliases", "keywords", "description" }) do
        local textOK, textErr = validateTextField(record[name], field .. "." .. name)
        if not textOK then return nil, textErr end
    end
    if record.category ~= nil then
        if type(record.category) ~= "string" and type(record.category) ~= "table" then return schemaFailure(field .. ".category") end
        if type(record.category) == "table" and record.category.id ~= nil and not stableID(record.category.id, 64) then return schemaFailure(field .. ".category.id") end
    end
    if record.actions ~= nil then
        if type(record.actions) ~= "table" or #record.actions > 4 then return schemaFailure(field .. ".actions") end
        local seen = {}
        for index = 1, #record.actions do
            local action = record.actions[index]
            local actionOK, actionErr = self:ValidateSearchAction(action, field .. ".actions[" .. index .. "]")
            if not actionOK then return nil, actionErr end
            if seen[action.id] then return schemaFailure(field .. ".actions.id") end
            seen[action.id] = true
        end
        if record.primaryActionID ~= nil and (type(record.primaryActionID) ~= "string" or not seen[record.primaryActionID]) then
            return schemaFailure(field .. ".primaryActionID")
        end
    elseif record.primaryActionID ~= nil then
        return schemaFailure(field .. ".primaryActionID")
    end
    if record.drag ~= nil then
        if type(record.drag) ~= "table" or record.drag.type ~= "spell" or not positiveInteger(record.drag.spellID) then
            return schemaFailure(field .. ".drag")
        end
        local dragOK, dragErr = self:Validate(record.drag, field .. ".drag")
        if not dragOK then return nil, dragErr end
        for key in pairs(record.drag) do if key ~= "type" and key ~= "spellID" then return schemaFailure(field .. ".drag." .. tostring(key)) end end
    end
    if record.availability ~= nil then
        if type(record.availability) ~= "table" or type(record.availability.contextKey) ~= "string" then
            return schemaFailure(field .. ".availability")
        end
        for key in pairs(record.availability) do
            if key ~= "contextKey" and key ~= "equals" then return schemaFailure(field .. ".availability." .. tostring(key)) end
        end
    end
    return true
end

return Boundary
