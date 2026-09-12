local I = _G.LycheeInternal
local P = { entries = {}, jobs = {}, diagnostics = {}, queryEpoch = 0, instanceSequence = 0, entryLimit = 4096, queryLimit = 256 }
I.Providers = P
-- Membership follows each live resolved snapshot, not its ID: pins and recent
-- may resolve the same entry independently. UI/action references keep it alive.
local weakRecords = { __mode = "k" }
local function resolvedRecords() return setmetatable({}, weakRecords) end
local localizedRecordFields = {"title","kindTitle","subtitle","subtext","description","aliases","keywords"}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function failure(code, field, owner)
    return nil, { code = code, field = field, providerID = owner, retryable = false }
end
local function publicQueryRequest(request)
    local result={}
    for key,value in pairs(request) do
        if key=="filter" and type(value)=="table" then
            local filter={}
            for field,setting in pairs(value) do
                if field~="excludedSources" and field~="policyVersion" then filter[field]=copy(setting) end
            end
            if next(filter) then result.filter=filter end
        else result[key]=copy(value) end
    end
    return result
end
local function report(entry, code, field)
    entry.lastError = { providerID = entry.id, code = code, field = field }
    P.diagnostics[#P.diagnostics + 1] = entry.lastError
    if #P.diagnostics > 32 then table.remove(P.diagnostics, 1) end
end
local function validID(id)
    return type(id) == "string" and #id > 0 and #id <= 64 and id:match("^[a-z0-9][a-z0-9%.%-]*$")
end
local function keys(value, allowed, field)
    for key in pairs(value) do if not allowed[key] then return failure("INVALID_SCHEMA", field .. "." .. tostring(key)) end end
    return true
end
local function array(value, limit, field)
    if type(value) ~= "table" then return failure("INVALID_SCHEMA", field) end
    if #value > limit then return failure("RESULT_LIMIT", field) end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key ~= math.floor(key) then return failure("INVALID_SCHEMA", field) end
        count = count + 1
    end
    return count == #value and true or failure("INVALID_SCHEMA", field)
end

-- Only Host-owned presentation metadata is shared. Values are weak and the
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
local function records(entry, input, limit)
    return I.Boundary:ReceiveRecords(input, prepareRecord, entry, limit or P.entryLimit, shareMetadata)
end
local function active(entry)
    local identity = I.Search.RuntimeIdentity
    return P.entries[entry.id] == entry and I.Registry:IsEnabled(entry.id)
        and (not identity or identity:MatchesScope(entry.definition.scope))
end
local function finish(job, reason)
    if job.done then return end
    job.done, job.reason = true, reason
    P.jobs[job] = nil
    local resources,timer=job.resources,job.timer
    job.resources,job.timer=nil,nil
    local cancel = job.cancel; job.cancel = nil
    if timer and not pcall(timer.Cancel,timer) then report(job.entry,"CALLBACK_ERROR","query.timer") end
    if resources then I.Resources:Close(resources, reason) end
    if cancel then
        local ok = pcall(cancel, reason)
        if not ok then report(job.entry, "CALLBACK_ERROR", "query.cancel") end
    end
end
function P:CancelQueries(reason, owner)
    if not owner then self.queryEpoch = self.queryEpoch + 1 end
    local epoch = self.queryEpoch
    local pending = {}
    for job in pairs(self.jobs) do if not owner or job.entry == owner then pending[#pending + 1] = job end end
    for index = 1, #pending do finish(pending[index], reason or "cancelled") end
    return epoch
end

function P:Register(definition)
    local ok, err = I.Boundary:Validate(definition, "provider", {
        maxFields = P.entryLimit, maxDepth = 12,
        callbacks = { query = true, resolve = true, run = true, begin = true, create = true, onEnable = true, onDisable = true },
    })
    if not ok then return nil, err end
    if type(definition) ~= "table" then return failure("INVALID_SCHEMA", "provider") end
    ok, err = keys(definition, { id=true, apiVersion=true, minApiRevision=true, version=true, title=true,
        entries=true, query=true, resolve=true, searchable=true, searchMode=true, searchGlobal=true, searchPrefixes=true, searchKeywords=true, actions=true, drags=true, views=true, scope=true, i18n=true, onEnable=true, onDisable=true }, "provider")
    if not ok then return nil, err end
    if not validID(definition.id) or type(definition.version) ~= "string" or definition.version == "" then return failure("INVALID_SCHEMA", "provider.id/version") end
    if not _G.Lychee:Supports(definition.apiVersion, definition.minApiRevision) then return failure("UNSUPPORTED_API", "apiVersion") end
    if I.Search.ProviderPolicy then
        local valid,field=I.Search.ProviderPolicy:ValidateDefinition(definition)
        if not valid then return failure("INVALID_SCHEMA",field) end
    end
    if definition.searchable~=nil then
        if type(definition.searchable)~="boolean" then return failure("INVALID_SCHEMA","searchable") end
        if (definition.minApiRevision or 1)<3 then return failure("INVALID_SCHEMA","searchable.minApiRevision") end
    end
    if definition.scope ~= nil and type(definition.scope) ~= "table" then return failure("INVALID_SCHEMA", "scope") end
    ok, err = I.Boundary:ValidateScope(definition.scope or {},"scope")
    if not ok then return nil, err end
    if (definition.minApiRevision or 1)>=2 and (not definition.scope or not definition.scope.products or definition.i18n==nil) then
        return failure("INVALID_SCHEMA","scope.products/i18n")
    end
    local localizer
    if definition.i18n~=nil then
        if not I.ProviderLocales then return failure("UNSUPPORTED_API","i18n") end
        localizer,err=I.ProviderLocales:Compile(definition.i18n)
        if not localizer then return nil,err end
    end
    local inputEntries,ownedDefinition=definition.entries,{}
    for key,value in pairs(definition) do if key~="entries" and key~="i18n" then ownedDefinition[key]=copy(value) end end
    definition=ownedDefinition
    -- Unscoped API 2.1 providers predate other clients; do not silently opt them in.
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
    if definition.entries == nil and type(definition.query) ~= "function" then return failure("INVALID_SCHEMA", "entries/query") end
    if definition.entries ~= nil and type(definition.entries) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
    for _, field in ipairs({ "query", "resolve", "onEnable", "onDisable" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "function" then return failure("INVALID_SCHEMA", field) end
    end
    for _, field in ipairs({ "actions", "drags", "views" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "table" then return failure("INVALID_SCHEMA", field) end
        for id, value in pairs(definition[field] or {}) do
            local callback = field == "actions" and "run" or field == "drags" and "begin" or "create"
            if not validID(id) or type(value) ~= "table" or type(value[callback]) ~= "function" then return failure("INVALID_SCHEMA", field) end
            local allowed = field == "views" and { create=true, stateSchema=true } or { title=true, [callback]=true }
            ok, err = keys(value, allowed, field .. "." .. id); if not ok then return nil, err end
            if field ~= "views" and (type(value.title) ~= "string" or value.title == "") then return failure("INVALID_SCHEMA", field .. ".title") end
            if field == "views" and type(value.stateSchema) ~= "table" then return failure("INVALID_SCHEMA", "views.stateSchema") end
            if field == "views" then
                ok, err = I.Boundary:Validate(value.stateSchema, "views.stateSchema")
                if not ok then return nil, err end
            end
        end
    end
    self.instanceSequence = self.instanceSequence + 1
    local entry = { id = definition.id, instanceToken = self.instanceSequence, definition = definition, revision = 1, dynamic = {}, resolved = resolvedRecords(), dynamicEpoch = 0, localizer=localizer }
    local initial, map = records(entry, inputEntries or {})
    if not initial then return nil, map end
    entry.records, entry.recordMap = initial, map
    entry.recordOrder = {}
    for index, record in ipairs(initial) do entry.recordOrder[record.id] = index end
    definition.entries = nil
    local handle, internal, enabledBeforeCommit
    local sourceID = entry.id .. ":records"
    local function canonical(record)
        return I.Search.StaticIndex:GetRecord(sourceID, record.id) or record
    end
    local function adoptRecords()
        for index, record in ipairs(entry.records) do
            local owned = canonical(record)
            entry.records[index], entry.recordMap[record.id] = owned, owned
        end
    end
    local function start()
        if not internal then enabledBeforeCommit = true; return end
        if not active(entry) or entry.started then return end
        entry.started = true
        entry.lifecycleEpoch=(entry.lifecycleEpoch or 0)+1
        local lifecycle=entry.lifecycleEpoch
        if definition.onEnable then
            local called, cleanup = pcall(definition.onEnable, handle)
            if not called then report(entry, "CALLBACK_ERROR", "onEnable")
            elseif type(cleanup) == "function" then
                if active(entry) and entry.lifecycleEpoch==lifecycle then entry.cleanup = cleanup
                elseif not pcall(cleanup, "cancelled-enable") then report(entry, "CALLBACK_ERROR", "cleanup") end
            elseif cleanup ~= nil then report(entry, "INVALID_CALLBACK", "onEnable.cleanup") end
        end
    end
    local function stop(reason)
        local wasStarted = entry.started
        entry.started = nil
        entry.lifecycleEpoch=(entry.lifecycleEpoch or 0)+1
        local lifecycle=entry.lifecycleEpoch
        local resources=entry.resources;entry.resources=nil
        local cleanup = entry.cleanup; entry.cleanup = nil
        local pending={}
        for job in pairs(P.jobs) do if job.entry==entry then pending[#pending+1]=job end end
        entry.dynamic, entry.resolved = {}, resolvedRecords()
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        if resources then I.Resources:Close(resources,reason) end
        for _,job in ipairs(pending) do finish(job,reason) end
        if cleanup and not pcall(cleanup, reason) then report(entry, "CALLBACK_ERROR", "cleanup") end
        if wasStarted and entry.lifecycleEpoch==lifecycle and definition.onDisable
            and not pcall(definition.onDisable, reason) then report(entry, "CALLBACK_ERROR", "onDisable") end
    end
    local draft
    draft, err = I.Registry:Begin({ id = entry.id, title = definition.title, version = definition.version,
        apiVersion = 2, minApiRevision = definition.minApiRevision or 1,
        onHostAttached = adoptRecords, onEnabled = start, onDisabled = stop }, { public = true })
    if not draft then return nil, err end
    ok, err = draft:RegisterSearchSource({ id = "records", title = definition.title, version = 2, revision = 1,
        priority = 0, scope = definition.scope or {}, searchable=definition.searchable,
        snapshot = function() return I.Registry:_OwnRecords(entry.records, entry.id) end })
    if not ok then draft:Abort(); return nil, err end
    for id, view in pairs(definition.views or {}) do
        ok, err = draft:RegisterPanelFactory({ id = id, create = view.create, stateSchema = view.stateSchema })
        if not ok then draft:Abort(); return nil, err end
    end
    internal, err = draft:Commit()
    if not internal then return nil, err end
    self.entries[entry.id] = entry
    if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
    local source = internal:GetSearchSource("records")
    handle = { id = entry.id }
    function handle:Update(delta)
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        if not active(entry) then return failure("PROVIDER_DISABLED", nil, entry.id) end
        local valid, why = I.Boundary:Validate(delta, "update", { maxFields = P.entryLimit, maxDepth = 12 })
        if not valid then return nil, why end
        if type(delta) ~= "table" then return failure("INVALID_SCHEMA", "update") end
        for _, field in ipairs({ "replace", "upsert", "remove" }) do
            if delta[field] ~= nil and type(delta[field]) ~= "table" then return failure("INVALID_SCHEMA", "update." .. field) end
        end
        valid, why = keys(delta, { replace=true, upsert=true, remove=true }, "update"); if not valid then return nil, why end
        if delta.replace ~= nil and (delta.upsert ~= nil or delta.remove ~= nil) then return failure("INVALID_SCHEMA", "update.replace") end
        if delta.replace ~= nil then
            local nextList, nextMap = records(entry, delta.replace)
            if not nextList then return nil, nextMap end
            entry.updating = true
            local committed, commitError, _, changed = source:CommitSnapshot(I.Registry:_OwnRecords(nextList, entry.id))
            entry.updating = nil
            if not committed then return nil, commitError end
            if not changed then return true end
            entry.records, entry.recordMap, entry.recordOrder = nextList, nextMap, {}
            for index, record in ipairs(nextList) do entry.recordOrder[record.id] = index end
            adoptRecords()
        else
            local additions, addedMap = records(entry, delta.upsert or {})
            if not additions then return nil, addedMap end
            valid, why = array(delta.remove or {}, P.entryLimit, "update.remove"); if not valid then return nil, why end
            local removed, count = {}, #entry.records
            for _, id in ipairs(delta.remove or {}) do
                if type(id) ~= "string" or id == "" or addedMap[id] or removed[id] then return failure("INVALID_SCHEMA", "update.remove") end
                removed[id] = true
                if entry.recordMap[id] then count = count - 1 end
            end
            for _, record in ipairs(additions) do if not entry.recordMap[record.id] then count = count + 1 end end
            if count > P.entryLimit then return failure("RESULT_LIMIT", "update") end
            entry.updating = true
            local committed, commitError, _, changed = source:ApplyDelta(I.Registry:_OwnRecords(additions, entry.id), delta.remove or {})
            entry.updating = nil
            if not committed then return nil, commitError end
            if not changed then return true end
            for id in pairs(removed) do
                local index = entry.recordOrder[id]
                if index then
                    local last = entry.records[#entry.records]
                    entry.records[index], entry.recordOrder[last.id] = last, index
                    entry.records[#entry.records] = nil
                    entry.recordOrder[id], entry.recordMap[id] = nil, nil
                end
            end
            for _, record in ipairs(additions) do
                record = canonical(record)
                local index = entry.recordOrder[record.id] or #entry.records + 1
                entry.records[index], entry.recordMap[record.id], entry.recordOrder[record.id] = record, record, index
            end
        end
        entry.revision = entry.revision + 1
        if not (C_Timer and C_Timer.NewTimer) and I.Search.Session then I.Search.Session:RefreshSource() end
        return true
    end
    function handle:Resources()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not active(entry) then return failure("PROVIDER_DISABLED",nil,entry.id) end
        if not entry.resources then
            entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end)
        end
        return entry.resources
    end
    function handle:Settings()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not entry.settings then entry.settings=I.ProviderData:Settings(entry.id,function() return P.entries[entry.id]==entry end) end
        return entry.settings
    end
    function handle:GetDiagnostics()
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        return entry.resources and entry.resources:GetDiagnostics() or {active=false,resources=0,providerResources=0,errors=0,limit=I.Resources.limit}
    end
    function handle:Text(key,...)
        if P.entries[entry.id]~=entry then return failure("STALE_HANDLE",nil,entry.id) end
        if not entry.localizer then return failure("INVALID_LOCALE_KEY","i18n",entry.id) end
        return entry.localizer:Text(key,...)
    end
    function handle:GetState()
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        local state = internal:GetState()
        return { enabled = active(entry), ownerEnabled = state.ownerEnabled, userEnabled = state.userEnabled,
            lifecycle = state.lifecycle, revision = entry.revision, lastError = copy(entry.lastError) }
    end
    function handle:SetEnabled(enabled)
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        if type(enabled) ~= "boolean" then return failure("INVALID_SCHEMA", "enabled") end
        return internal:SetEnabled(enabled)
    end
    function handle:Unregister()
        if P.entries[entry.id] ~= entry then return true end
        if entry.updating then return nil, {code="UPDATE_IN_PROGRESS",providerID=entry.id,retryable=true} end
        local removed, removeError = internal:Unregister()
        if removed then
            P.entries[entry.id] = nil
            if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
            entry.localizer,entry.settings=nil,nil
            entry.metadataPool, entry.actionRecords, entry.actionLists = nil, nil, nil
            entry.records, entry.recordMap, entry.recordOrder, entry.dynamic, entry.resolved = {}, {}, {}, {}, {}
            definition.actions, definition.drags, definition.views, definition.query, definition.resolve = nil, nil, nil, nil, nil
            definition.onEnable, definition.onDisable = nil, nil
        end
        return removed, removeError
    end
    if enabledBeforeCommit then start() end
    return handle
end

function P:CreateViewResources(owner)
    local entry=self.entries[owner]
    if not entry or not active(entry) or (entry.definition.minApiRevision or 1)<7 then return nil end
    if not entry.resources then entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end) end
    return I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end,entry.resources)
end

function P:Stamp(item, dynamic)
    local entry = item and self.entries[item._ext]
    if not entry then
        if item and item._ext and item.sourceID then item.ref = { providerID = item._ext, entryID = item.id, sourceID = item.sourceID } end
        return item
    end
    item.providerID, item.ref = entry.id, { providerID = entry.id, entryID = item.id }
    item._providerInstance, item._providerRevision = entry, entry.revision
    item._providerRecord = entry.recordMap[item.id]
    item._dynamicEpoch = dynamic and entry.dynamicEpoch or nil
    return item
end
function P:IsCurrent(item)
    local entry = item and item._providerInstance
    if not entry then return true end
    local record, identity = item._providerRecord, I.Search.RuntimeIdentity
    return active(entry) and item._providerRevision == entry.revision
        and record ~= nil and (not identity or identity:MatchesScope(record.scope or entry.definition.scope))
        and (not item._dynamicEpoch or item._dynamicEpoch == entry.dynamicEpoch)
        and (item._providerRecord == entry.recordMap[item.id] or item._providerRecord == entry.dynamic[item.id] or entry.resolved[item._providerRecord] == true)
end
local function materialize(entry, record)
    local item = I.Search.ResultSnapshot:Materialize({ record = record, sourceID = entry.id .. ":records",
        sourceExtensionID = entry.id, sourceTitle = entry.definition.title, confidence = 0.75,
        stableID = entry.id .. ":" .. record.id })
    P:Stamp(item, true)
    item._providerRecord = record
    return item
end
function P:CanRemember(item)
    local entry = item and self.entries[item.providerID]
    if entry then return active(entry) and item._providerInstance == entry and (entry.recordMap[item.id] ~= nil or type(entry.definition.resolve) == "function") end
    return item and item.ref and item.sourceID and I.Search.StaticIndex.entries[item.sourceID .. ":" .. item.id] ~= nil
end
function P:Resolve(ref, context)
    if type(ref) ~= "table" or type(ref.providerID) ~= "string" or type(ref.entryID) ~= "string" then return nil end
    local entry = self.entries[ref.providerID]
    if not entry then
        local indexed = type(ref.sourceID) == "string" and I.Search.StaticIndex.entries[ref.sourceID .. ":" .. ref.entryID]
        local source = indexed and indexed.source
        if not source or source.extensionID ~= ref.providerID or not I.Registry:IsEnabled(ref.providerID) or not source.enabled then return nil end
        local item = I.Search.ResultSnapshot:Materialize({ record = indexed.record, sourceID = source.id, sourceExtensionID = ref.providerID,
            sourceTitle = source.title or source.extensionTitle, sourceGeneration = source.generation, sourceRevision = source.revision, stableID = indexed.stableID })
        return self:Stamp(item)
    end
    if not active(entry) then return nil end
    local record = entry.recordMap[ref.entryID]
    if not record and entry.definition.resolve then
        local ok, result = pcall(entry.definition.resolve, ref.entryID, copy(context or {}))
        if not ok then report(entry, "CALLBACK_ERROR", "resolve"); return nil end
        if not active(entry) then return nil end
        if result == nil then return nil end
        local restored, err = records(entry, { result })
        if not restored or restored[1].id ~= ref.entryID then report(entry, err and err.code or "INVALID_SCHEMA", "resolve"); return nil end
        record = restored[1]; entry.resolved[record] = true
    end
    local identity = I.Search.RuntimeIdentity
    if record and identity and not identity:MatchesScope(record.scope or entry.definition.scope) then return nil end
    return record and materialize(entry, record)
end
function P:Execute(item, actionID, context, dragging)
    if not self:IsCurrent(item) then return failure("STALE_RESULT", nil, item and item.providerID) end
    local entry = item and self.entries[item.providerID]
    if not entry then return failure("PROVIDER_DISABLED") end
    local record = item._providerRecord
    local definition = dragging and entry.definition.drags or entry.definition.actions
    local action = definition and definition[actionID]
    if not record or not action then return failure("ACTION_UNAVAILABLE", actionID, entry.id) end
    local publicRecord = copy(record)
    publicRecord._extensionID = nil
    for index, declared in ipairs(publicRecord.actions or {}) do
        if declared.kind == "provider" then publicRecord.actions[index] = declared.id end
    end
    local category = publicRecord.category
    if type(category) == "table" and type(category.id) == "string" then category.id = category.id:sub(#entry.id + 2) end
    local resultOK, result = pcall(dragging and action.begin or action.run, publicRecord, copy(context or {}))
    if not resultOK then report(entry, "CALLBACK_ERROR", actionID); return failure("CALLBACK_ERROR", actionID, entry.id) end
    if not active(entry) then return failure("STALE_RESULT", actionID, entry.id) end
    local valid = I.Boundary:Validate(result, "action.result")
    if not valid or type(result) ~= "table" or type(result.ok) ~= "boolean" then return failure("INVALID_RESULT", actionID, entry.id) end
    if not keys(result, { ok=true, close=true, view=true, state=true, code=true, message=true }, "action.result") then return failure("INVALID_RESULT", actionID, entry.id) end
    if (result.message ~= nil and type(result.message) ~= "string") or (result.code ~= nil and type(result.code) ~= "string")
        or (result.view ~= nil and type(result.view) ~= "string") or (result.close ~= nil and type(result.close) ~= "boolean") then
        return failure("INVALID_RESULT", actionID, entry.id)
    end
    if result.ok == false then
        return nil, { code = type(result.code) == "string" and result.code or "ACTION_FAILED", message = result.message, providerID = entry.id }
    end
    if result.view then result.transition = { panelID = result.view, state = result.state or {} } end
    result.closePalette = result.close == true and not result.view
    return result
end

-- One completion per Provider per query, whether synchronous or delayed.
function P:HasPendingQuery()
    return next(self.jobs) ~= nil
end

function P:HasQuery(filter)
    if type(filter)~="table" or not filter.sourceID then return true end
    if type(filter.sourceID)~="string" then return false end
    local id=filter.sourceID:match("^(.*):records$")
    local entry=id and self.entries[id]
    return entry~=nil and active(entry) and type(entry.definition.query)=="function"
end
function P:Search(request, context, onChange)
    -- Search is also callable without QueryOrchestrator. Supersede old work at
    -- this boundary; a cancel callback may reenter and start an even newer query.
    local epoch = self:CancelQueries("query-replaced")
    if epoch ~= self.queryEpoch then return {} end
    local output, collecting = {}, true
    local function gather()
        local result = {}
        for _, list in pairs(output) do for _, item in ipairs(list) do if P:IsCurrent(item) then result[#result + 1] = item end end end
        return result
    end
    local function settle(job, reason)
        finish(job, reason)
        -- finish may reenter through a Provider cancel callback. Only the
        -- surviving query publishes its terminal state, including invalid replies.
        if epoch == P.queryEpoch and not collecting and onChange then onChange(gather()) end
    end
    local ids = {}
    for id, entry in pairs(self.entries) do
        if active(entry) and entry.definition.query and (not request.filter or not request.filter.sourceID or request.filter.sourceID == id .. ":records")
            and not (request.filter and request.filter.excludedSources and request.filter.excludedSources[id..":records"]) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if epoch ~= self.queryEpoch then break end
        local entry = self.entries[id]
        if entry and active(entry) then
        entry.dynamic, entry.resolved = {}, resolvedRecords()
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        local job = { entry = entry, epoch = epoch, revision = entry.revision, dynamicEpoch = entry.dynamicEpoch }
        self.jobs[job] = true
        local function reply(input)
            if job.done then return failure("STALE_REQUEST", "query", id) end
            if not active(entry) or job.epoch ~= P.queryEpoch or job.revision ~= entry.revision
                or job.dynamicEpoch ~= entry.dynamicEpoch then
                settle(job, "stale")
                return failure("STALE_REQUEST", "query", id)
            end
            local list, map = records(entry, input, P.queryLimit)
            if not list then report(entry, map.code, "query"); settle(job, "invalid"); return nil, map end
            entry.dynamic = map
            local items = {}
            for index = 1, #list do
                local record = list[index]
                local category = type(record.category) == "table" and record.category.id or record.category
                local identity = I.Search.RuntimeIdentity
                if (not request.filter or not request.filter.categoryID or request.filter.categoryID == category)
                    and (not identity or identity:MatchesScope(record.scope or entry.definition.scope)) then
                    local item = materialize(entry, record)
                    local match = I.Search.Normalizer:MatchRecord(request.normalized, record, entry.definition.scope)
                    if match then item.confidence, item.evidence = match.confidence, match end
                    items[#items + 1] = item
                end
            end
            output[id] = items
            settle(job, "complete")
            return true
        end
        local queryContext=copy(context or {})
        local resourceError
        if (entry.definition.minApiRevision or 1)>=7 then
            if not entry.resources then entry.resources=I.Resources:Create(function() return active(entry) end,function(code,field) report(entry,code,field) end) end
            job.resources,resourceError=I.Resources:Create(function() return not job.done and active(entry) and job.epoch==P.queryEpoch end,
                function(code,field) report(entry,code,field) end,entry.resources)
            queryContext.resources=job.resources
        end
        local ok, cancel
        if (entry.definition.minApiRevision or 1)>=7 and not job.resources then
            ok=false
        else ok,cancel=pcall(entry.definition.query, publicQueryRequest(request), reply, queryContext) end
        if not ok then
            if P.entries[id]==entry and epoch==P.queryEpoch and job.dynamicEpoch==entry.dynamicEpoch then
                output[id], entry.dynamic = nil, {}
            end
            report(entry, resourceError and resourceError.code or "CALLBACK_ERROR", "query"); settle(job, "error")
        elseif cancel ~= nil and type(cancel) ~= "function" then report(entry, "INVALID_CALLBACK", "query.cancel"); settle(job, "error")
        elseif job.done then
            if cancel and not pcall(cancel, job.reason) then report(entry, "CALLBACK_ERROR", "query.cancel") end
        else
            job.cancel = cancel
            if C_Timer and C_Timer.NewTimer then
                local scheduled,timer=pcall(C_Timer.NewTimer,5, function()
                if job.done then return end
                report(entry, "QUERY_TIMEOUT", "query"); settle(job, "timeout")
                end)
                if scheduled and timer then job.timer=timer
                else report(entry,"RESOURCE_UNAVAILABLE","query.timer");settle(job,"error") end
            end
        end
        end
    end
    collecting = false
    return gather()
end
