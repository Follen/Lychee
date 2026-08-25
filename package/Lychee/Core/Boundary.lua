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

return Boundary
