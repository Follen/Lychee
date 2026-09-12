local I = _G.LycheeInternal
local Boundary = { MAX_DEPTH = 8, MAX_FIELDS = 128 }
I.Boundary = Boundary
-- Immutable validation vocabulary; never allocate it per record/action.
local DEFAULT_OPTIONS = {}
local ACTION_KEYS = { id=true, title=true, kind=true, panel=true, state=true, spellID=true, itemID=true }
local ACTION_KIND_KEYS = {
    provider={id=true,title=true,kind=true},
    ["open-panel"]={id=true,title=true,kind=true,panel=true,state=true},
    ["secure-item"]={id=true,title=true,kind=true,itemID=true},
    ["secure-spell"]={id=true,title=true,kind=true,spellID=true},
    ["drag-spell"]={id=true,title=true,kind=true,spellID=true},
}
local RECORD_KEYS = {
    id=true,kind=true,kindTitle=true,category=true,title=true,subtitle=true,subtext=true,
    aliases=true,keywords=true,description=true,icon=true,scope=true,actions=true,
    primaryActionID=true,drag=true,payload=true,availability=true,_extensionID=true,
}
local TEXT_FIELDS = { "kindTitle", "title", "subtitle", "subtext", "aliases", "keywords", "description" }
local CATEGORY_KEYS = {id=true,title=true,order=true,color=true}

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

local function visit(value, options, seen, depth, field, parentKey, copying, budget)
    local ok, why = access(value, field)
    if not ok then return nil, why end
    local kind = type(value)
    if budget then
        budget.nodes = budget.nodes + 1
        budget.bytes = budget.bytes + (kind == "string" and #value or 16)
        if budget.nodes > options.maxNodes or budget.bytes > options.maxBytes then return failure("DATA_LIMIT", field) end
    end
    if kind == "function" then
        if options.callbacks and type(parentKey) == "string" and options.callbacks[parentKey] then return true, nil, value end
        return failure("INVALID_SCHEMA", field)
    end
    if kind == "nil" or kind == "boolean" or kind == "string" then return true, nil, value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return failure("INVALID_SCHEMA", field) end
        return true, nil, value
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
    local owned = copying and {} or nil
    local count = 0
    for key, child in next, value do
        count = count + 1
        if count > (options.maxFields or Boundary.MAX_FIELDS) then seen[value] = nil; return failure("INVALID_SCHEMA", field) end
        local keyOK, keyErr = visit(key, options, seen, depth + 1, field, nil, false, budget)
        if not keyOK then seen[value] = nil; return nil, keyErr end
        if options.scalarKeys and type(key)~="string" and type(key)~="number" then
            seen[value]=nil;return failure("INVALID_SCHEMA",field)
        end
        local childOK, childErr, childCopy = visit(child, options, seen, depth + 1, field, key, copying, budget)
        if not childOK then seen[value] = nil; return nil, childErr end
        if copying then owned[key] = childCopy end
    end
    seen[value] = nil
    return true, nil, owned
end

function Boundary:Validate(value, field, options)
    local ok, why = visit(value, options or DEFAULT_OPTIONS, {}, 0, field, nil)
    if not ok then return nil, why end
    return true
end

-- An owned copy is produced during the safety walk, never by rereading an
-- unchecked graph. Seen state is local to this invocation, including reentry.
function Boundary:Copy(value, field, options)
    options = options or DEFAULT_OPTIONS
    local budget = options.maxNodes and options.maxBytes and {nodes=0,bytes=0} or nil
    local ok, why, owned = visit(value, options, {}, 0, field, nil, true, budget)
    if not ok then return nil, why end
    return owned, nil, budget and budget.bytes
end

-- Host-only receipt: no record field or public SDK option can create it.
-- Failed, dynamic and abandoned batches disappear without retaining their graph.
-- ReceiveRecords callbacks are Host transforms, never public Provider callbacks.
local receivedRecords = setmetatable({}, { __mode = "k" })
function Boundary:_HasRecordReceipt(records) return receivedRecords[records] == true end
function Boundary:_ConsumeRecordReceipt(records) receivedRecords[records] = nil end

function Boundary:ReceiveRecords(input, prepare, context, limit, share)
    local list, why = self:Copy(input, "entries", { maxFields = limit, maxDepth = 10 })
    if why then return nil, why end
    if type(list) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
    if #list > limit then return failure("RESULT_LIMIT", "entries") end
    local count, map = 0, {}
    for key in pairs(list) do
        if type(key) ~= "number" or key < 1 or key > #list or key ~= math.floor(key) then return failure("INVALID_SCHEMA", "entries") end
        count = count + 1
    end
    if count ~= #list then return failure("INVALID_SCHEMA", "entries") end
    for index = 1, #list do
        local record, err = prepare(context, list[index], index)
        if not record then return nil, err end
        -- Prepare may localize/expand actions, so validate the final owned form
        -- with the stricter per-record limits before issuing a batch receipt.
        local ok, invalid = self:ValidateSearchRecord(record, "entries[" .. index .. "]")
        if not ok then return nil, invalid end
        if map[record.id] then return nil, {code="DUPLICATE_ID",field="entry.id",providerID=context.id,retryable=false} end
        if share then share(context, record) end
        list[index], map[record.id] = record, record
    end
    receivedRecords[list] = true
    return list, map
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

local SCOPE_SCHEMA={product="string?",products="table?",locale="string?",minInterface="integer?",maxInterface="integer?",minBuild="integer?",maxBuild="integer?"}
local PRODUCTS={retail=true,classic=true,titan=true,anniversary=true}
local function validateScope(scope,field,checked)
    if not checked then
        local ok,err=Boundary:Validate(scope,field)
        if not ok then return nil,err end
    end
    local ok,err=schemaValue(Boundary,scope,SCOPE_SCHEMA,field)
    if not ok then return nil,err end
    if scope.product and scope.products then return failure("INVALID_SCHEMA",field) end
    if scope.products then
        local count=0
        if #scope.products==0 or #scope.products>4 then return failure("INVALID_SCHEMA",field..".products") end
        local seen={}
        for key,value in pairs(scope.products) do
            if type(key)~="number" or key~=math.floor(key) or key<1 or key>#scope.products or not PRODUCTS[value] or seen[value] then return failure("INVALID_SCHEMA",field..".products") end
            seen[value]=true;count=count+1
        end
        if count~=#scope.products then return failure("INVALID_SCHEMA",field..".products") end
    end
    for _,suffix in ipairs({"Interface","Build"}) do
        local minimum,maximum=scope["min"..suffix],scope["max"..suffix]
        if (minimum and minimum<1) or (maximum and maximum<1) or (minimum and maximum and minimum>maximum) then return failure("INVALID_SCHEMA",field) end
    end
    return true
end

function Boundary:ValidateScope(scope,field) return validateScope(scope,field,false) end

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

local function validateSearchAction(action, field, checked)
    field = field or "action"
    if type(action) ~= "table" then return schemaFailure(field) end
    if not checked then
        local ok, why = Boundary:Validate(action, field)
        if not ok then return nil, why end
    end
    local keyOK, keyErr = allowedKeys(action, ACTION_KEYS, field)
    if not keyOK then return nil, keyErr end
    if not stableID(action.id, 64) then return schemaFailure(field .. ".id") end
    local kind = action.kind
    if kind ~= "provider" and kind ~= "open-panel" and kind ~= "secure-spell" and kind ~= "secure-item" and kind ~= "drag-spell" then
        return schemaFailure(field .. ".kind")
    end
    keyOK, keyErr = allowedKeys(action, ACTION_KIND_KEYS[kind], field)
    if not keyOK then return nil, keyErr end
    if action.title ~= nil and type(action.title) ~= "string" and type(action.title) ~= "table" then
        return schemaFailure(field .. ".title")
    end
    if kind == "open-panel" and not stableID(action.panel, 96) then return schemaFailure(field .. ".panel") end
    if kind == "open-panel" and action.state ~= nil then
        if type(action.state) ~= "table" then return schemaFailure(field .. ".state") end
    end
    if (kind == "secure-spell" or kind == "drag-spell") and not positiveInteger(action.spellID) then
        return schemaFailure(field .. ".spellID")
    end
    if kind == "secure-item" and not positiveInteger(action.itemID) then return schemaFailure(field .. ".itemID") end
    return true
end

function Boundary:ValidateSearchAction(action, field) return validateSearchAction(action,field,false) end

local function validateTextField(value, field, checked)
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
            if not checked then
                local ok, why = Boundary:Validate(item, field .. "[" .. key .. "]")
                if not ok then return nil, why end
            end
            if type(item.text) ~= "string" or item.text == "" then return schemaFailure(field .. "[" .. key .. "].text") end
            if item.scope ~= nil then
                local scopeOK,scopeError=validateScope(item.scope,field..".scope",true)
                if not scopeOK then return nil,scopeError end
            end
        end
    end
    return true
end

function Boundary:ValidateText(value, field)
    return validateTextField(value, field or "text")
end

local function validateColor(value, field)
    if value == nil then return true end
    if type(value) ~= "table" or #value < 3 or #value > 4 then return schemaFailure(field) end
    for index = 1, #value do
        if type(value[index]) ~= "number" or value[index] < 0 or value[index] > 1 then return schemaFailure(field .. "[" .. index .. "]") end
    end
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > 4 or key ~= math.floor(key) then return schemaFailure(field) end
    end
    return true
end

function Boundary:ValidateSearchRecord(record, field)
    field = field or "record"
    if type(record) ~= "table" then return schemaFailure(field) end
    local ok, why = self:Validate(record, field)
    if not ok then return nil, why end
    local keyOK, keyErr = allowedKeys(record, RECORD_KEYS, field)
    if not keyOK then return nil, keyErr end
    if not stableID(record.id) or type(record.kind) ~= "string" or record.kind == "" then
        return schemaFailure(field)
    end
    if not record.title and not record.aliases and not record.keywords and not record.description and not record.category then
        return schemaFailure(field .. ".content")
    end
    for _, name in ipairs(TEXT_FIELDS) do
        local textOK, textErr = validateTextField(record[name], field .. "." .. name, true)
        if not textOK then return nil, textErr end
    end
    if record.category ~= nil then
        if type(record.category) ~= "string" and type(record.category) ~= "table" then return schemaFailure(field .. ".category") end
        if type(record.category) == "table" then
            local categoryKeysOK, categoryKeysErr = allowedKeys(record.category, CATEGORY_KEYS, field .. ".category")
            if not categoryKeysOK then return nil, categoryKeysErr end
            if record.category.id ~= nil and not stableID(record.category.id, 192) then return schemaFailure(field .. ".category.id") end
            local titleOK, titleErr = validateTextField(record.category.title, field .. ".category.title", true)
            if not titleOK then return nil, titleErr end
            if record.category.order ~= nil and (type(record.category.order) ~= "number" or record.category.order ~= math.floor(record.category.order)) then
                return schemaFailure(field .. ".category.order")
            end
            local colorOK, colorErr = validateColor(record.category.color, field .. ".category.color")
            if not colorOK then return nil, colorErr end
        end
    end
    if record.actions ~= nil then
        if type(record.actions) ~= "table" or #record.actions > 16 then return schemaFailure(field .. ".actions") end
        local seen = {}
        for index = 1, #record.actions do
            local action = record.actions[index]
            local actionOK, actionErr = validateSearchAction(action, field .. ".actions[" .. index .. "]", true)
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
        if type(record.drag) ~= "table" or (record.drag.type ~= "spell" and record.drag.type ~= "provider") then
            return schemaFailure(field .. ".drag")
        end
        if record.drag.type == "spell" and not positiveInteger(record.drag.spellID) then return schemaFailure(field .. ".drag.spellID") end
        if record.drag.type == "provider" and not stableID(record.drag.handler, 64) then return schemaFailure(field .. ".drag.handler") end
        if record.drag.type == "spell" and record.drag.handler ~= nil then return schemaFailure(field .. ".drag.handler") end
        if record.drag.type == "provider" and record.drag.spellID ~= nil then return schemaFailure(field .. ".drag.spellID") end
        if record.drag.title ~= nil and type(record.drag.title) ~= "string" then return schemaFailure(field .. ".drag.title") end
        for key in pairs(record.drag) do if key ~= "type" and key ~= "spellID" and key ~= "handler" and key ~= "title" then return schemaFailure(field .. ".drag." .. tostring(key)) end end
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
