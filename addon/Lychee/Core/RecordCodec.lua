local I = _G.LycheeInternal
local R = {}
I.RecordCodec = R
local localizedRecordFields = {"title","kindTitle","subtitle","subtext","description","aliases","keywords"}
local copy=I.Boundary.CopyPlain
local failure=I.Boundary.Failure
local array=I.Boundary.Array

-- Validated presentation metadata is shared only within its owner. Values are weak and the
-- auxiliary FIFO has at most 128 keys of <=256 bytes; unique/large metadata
-- stays on its record and never grows an unbounded interning dictionary.
local weakValues = { __mode = "v" }
local function sameMetadata(left, right)
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key, value in pairs(right) do if left[key] ~= value then return false end end
    return true
end
local function internMetadata(entry, key, value)
    if #key > 256 then return value end
    local pool = entry.metadataPool
    if not pool then
        pool = { values = setmetatable({}, weakValues), keys = {}, cursor = 0 }
        entry.metadataPool = pool
    end
    local previous = pool.values[key]
    if previous then return sameMetadata(previous, value) and previous or value end
    local slot = pool.cursor % 128 + 1
    local expired = pool.keys[slot]
    if expired then pool.values[expired] = nil end
    pool.keys[slot], pool.cursor, pool.values[key] = key, slot, value
    return value
end
local function internStrings(entry, field, value)
    if type(value) ~= "table" or #value > 16 then return value end
    local count = 0
    for key, text in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key ~= math.floor(key)
            or type(text) ~= "string" or #text > 256 then return value end
        count = count + 1
    end
    if count ~= #value then return value end
    return internMetadata(entry, field .. ":" .. count .. ":" .. table.concat(value, "\0"), value)
end
local function shareMetadata(entry, record)
    record.aliases = internStrings(entry, "aliases", record.aliases)
    record.keywords = internStrings(entry, "keywords", record.keywords)
    local category = record.category
    if type(category) == "table" and (category.id == nil or type(category.id) == "string")
        and (category.title == nil or type(category.title) == "string")
        and (category.order == nil or type(category.order) == "number") and category.color == nil then
        record.category = internMetadata(entry, "category:" .. tostring(category.id) .. "\0"
            .. tostring(category.title) .. "\0" .. tostring(category.order), category)
    end
    local actions = record.actions
    if #actions == 1 and entry.actionRecords and entry.actionRecords[actions[1].id] == actions[1] then
        local lists = entry.actionLists
        if not lists then lists = {}; entry.actionLists = lists end
        local id = actions[1].id
        if lists[id] then record.actions = lists[id] else lists[id] = actions end
    end
end
local function prepareRecord(entry, record, index)
    if type(record) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
    local ok, err
    if record._extensionID ~= nil then return failure("INVALID_SCHEMA", "entry._extensionID") end
    if record.title == nil or record.title == "" then return failure("INVALID_SCHEMA", "entry.title") end
    if record.payload ~= nil and type(record.payload) ~= "table" then return failure("INVALID_SCHEMA", "entry.payload") end
    if record.icon ~= nil and not (type(record.icon) == "string" and record.icon ~= "")
        and not (type(record.icon) == "number" and record.icon > 0 and record.icon == math.floor(record.icon)) then return failure("INVALID_SCHEMA", "entry.icon") end
    if record.scope ~= nil then
        ok, err = I.Boundary:ValidateScope(record.scope,"entry.scope")
        if not ok then return nil, err end
    end
    if record.actions ~= nil then
        ok, err = array(record.actions, 16, "entry.actions"); if not ok then return nil, err end
    end
    if entry.localizer then
        for _,field in ipairs(localizedRecordFields) do
            local value=record[field]
            if type(value)=="table" and value.key then
                record[field],err=entry.localizer:Resolve(value)
                if not record[field] then return nil,err end
            elseif (field=="aliases" or field=="keywords") and type(value)=="table" then
                for index,alias in ipairs(value) do
                    value[index],err=entry.localizer:Resolve(alias)
                    if not value[index] then return nil,err end
                end
            end
        end
        if type(record.category)=="table" then
            local title=record.category.title
            record.category.title,err=entry.localizer:Resolve(title)
            if title and not record.category.title then return nil,err end
        end
        if type(record.drag)=="table" and record.drag.title then
            record.drag.title,err=entry.localizer:Resolve(record.drag.title)
            if not record.drag.title then return nil,err end
        end
        for _,action in ipairs(record.actions or {}) do
            if type(action)=="table" and action.title then
                action.title,err=entry.localizer:Resolve(action.title)
                if not action.title then return nil,err end
            end
        end
    end
    if record.title == nil or record.title == "" then return failure("INVALID_SCHEMA", "entry.title") end
    if record.drag ~= nil and type(record.drag) ~= "table" then return failure("INVALID_SCHEMA", "entry.drag") end
    if record.kind == nil then record.kind = "entry" end
    if record.actions == nil then record.actions = {} end
    ok, err = array(record.actions, 16, "entry.actions"); if not ok then return nil, err end
    for actionIndex = 1, #record.actions do
        local action = record.actions[actionIndex]
        if type(action) == "string" then
            local definition = entry.definition.actions and entry.definition.actions[action]
            if not definition then return failure("UNKNOWN_ACTION", "entry.actions", entry.id) end
            local templates = entry.actionRecords
            if not templates then templates = {}; entry.actionRecords = templates end
            if not templates[action] then templates[action] = { id = action, title = definition.title, kind = "provider" } end
            record.actions[actionIndex] = templates[action]
        elseif type(action) == "table" and action.kind == "open-panel" then
            if not (entry.definition.views and entry.definition.views[action.panel]) then return failure("UNKNOWN_VIEW", "entry.actions", entry.id) end
            ok, err = I.Boundary:ValidateSchema(action.state or {}, entry.definition.views[action.panel].stateSchema, "entry.actions.state")
            if not ok then return nil, err end
        elseif type(action) == "table" and (action.kind == "provider" or action.kind == "intent") then
            return failure("INVALID_SCHEMA", "entry.actions", entry.id)
        end
    end
    if record.drag and record.drag.type == "provider" then
        if not (entry.definition.drags and entry.definition.drags[record.drag.handler]) then return failure("UNKNOWN_DRAG", "entry.drag", entry.id) end
    end
    -- The receiving boundary certifies this final, namespaced representation.
    if type(record.category) == "string" then record.category = { title = record.category }
    elseif type(record.category) == "table" and type(record.category.id) == "string" then
        local id = record.category.id
        if #id == 0 or #id > 192 or not id:match("^[A-Za-z0-9][A-Za-z0-9%._:%-/]*$") then
            return failure("INVALID_SCHEMA", "entries[" .. index .. "].category.id")
        end
        record.category.id = entry.id .. ":" .. id
    end
    return record
end
function R:Receive(entry,input,limit)
    return I.Boundary:ReceiveRecords(input,prepareRecord,entry,limit or 256,shareMetadata)
end
function R:Public(record,owner)
    local result=copy(record)
    result._extensionID=nil
    for index,action in ipairs(result.actions or {}) do
        if type(action)=="table" and action.kind=="provider" then result.actions[index]=action.id end
    end
    local category=result.category
    if type(category)=="table" and type(category.id)=="string" then category.id=category.id:sub(#owner+2) end
    return result
end
