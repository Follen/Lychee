local I = _G.LycheeInternal
local P = { entries = {}, jobs = {}, diagnostics = {}, queryEpoch = 0, entryLimit = 4096, queryLimit = 256 }
I.Providers = P

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function failure(code, field, owner)
    return nil, { code = code, field = field, providerID = owner, retryable = false }
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
local function records(entry, input, limit)
    limit = limit or P.entryLimit
    local ok, err = I.Boundary:Validate(input, "entries", { maxFields = limit, maxDepth = 10 })
    if not ok then return nil, err end
    ok, err = array(input, limit, "entries"); if not ok then return nil, err end
    local list, map = {}, {}
    for index = 1, #input do
        if type(input[index]) ~= "table" then return failure("INVALID_SCHEMA", "entries") end
        local record = copy(input[index])
        if record._extensionID ~= nil then return failure("INVALID_SCHEMA", "entry._extensionID") end
        if record.title == nil or record.title == "" then return failure("INVALID_SCHEMA", "entry.title") end
        if record.payload ~= nil and type(record.payload) ~= "table" then return failure("INVALID_SCHEMA", "entry.payload") end
        if record.icon ~= nil and not (type(record.icon) == "string" and record.icon ~= "")
            and not (type(record.icon) == "number" and record.icon > 0 and record.icon == math.floor(record.icon)) then return failure("INVALID_SCHEMA", "entry.icon") end
        if record.scope ~= nil then
            ok, err = I.Boundary:ValidateSchema(record.scope, { product="string?", locale="string?", minInterface="integer?", maxInterface="integer?", minBuild="integer?", maxBuild="integer?" }, "entry.scope")
            if not ok then return nil, err end
        end
        if record.drag ~= nil and type(record.drag) ~= "table" then return failure("INVALID_SCHEMA", "entry.drag") end
        if record.kind == nil then record.kind = "entry" end
        if record.actions == nil then record.actions = {} end
        ok, err = array(record.actions, 16, "entry.actions"); if not ok then return nil, err end
        for actionIndex = 1, #record.actions do
            local action = record.actions[actionIndex]
            if type(action) == "string" then
                local definition = entry.definition.actions and entry.definition.actions[action]
                if not definition then return failure("UNKNOWN_ACTION", "entry.actions", entry.id) end
                record.actions[actionIndex] = { id = action, title = definition.title, kind = "provider" }
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
        ok, err = I.Boundary:ValidateSearchRecord(record, "entries[" .. index .. "]")
        if not ok then return nil, err end
        if map[record.id] then return failure("DUPLICATE_ID", "entry.id", entry.id) end
        -- Categories are presentation metadata. Namespace local category IDs here.
        if type(record.category) == "string" then record.category = { title = record.category }
        elseif record.category and record.category.id then record.category.id = entry.id .. ":" .. record.category.id end
        list[index], map[record.id] = record, record
    end
    return list, map
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
    if job.timer then job.timer:Cancel(); job.timer = nil end
    local cancel = job.cancel; job.cancel = nil
    if cancel then
        local ok = pcall(cancel, reason)
        if not ok then report(job.entry, "CALLBACK_ERROR", "query.cancel") end
    end
end
function P:CancelQueries(reason, owner)
    if not owner then self.queryEpoch = self.queryEpoch + 1 end
    local pending = {}
    for job in pairs(self.jobs) do if not owner or job.entry == owner then pending[#pending + 1] = job end end
    for index = 1, #pending do finish(pending[index], reason or "cancelled") end
end

function P:Register(definition)
    local ok, err = I.Boundary:Validate(definition, "provider", {
        maxFields = P.entryLimit, maxDepth = 12,
        callbacks = { query = true, resolve = true, run = true, begin = true, create = true, onEnable = true, onDisable = true },
    })
    if not ok then return nil, err end
    if type(definition) ~= "table" then return failure("INVALID_SCHEMA", "provider") end
    ok, err = keys(definition, { id=true, apiVersion=true, minApiRevision=true, version=true, title=true,
        entries=true, query=true, resolve=true, actions=true, drags=true, views=true, scope=true, onEnable=true, onDisable=true }, "provider")
    if not ok then return nil, err end
    if not validID(definition.id) or type(definition.version) ~= "string" or definition.version == "" then return failure("INVALID_SCHEMA", "provider.id/version") end
    if not _G.Lychee:Supports(definition.apiVersion, definition.minApiRevision) then return failure("UNSUPPORTED_API", "apiVersion") end
    if definition.scope ~= nil and type(definition.scope) ~= "table" then return failure("INVALID_SCHEMA", "scope") end
    ok, err = I.Boundary:ValidateSchema(definition.scope or {}, {
        product="string?", locale="string?", minInterface="integer?", maxInterface="integer?", minBuild="integer?", maxBuild="integer?",
    }, "scope")
    if not ok then return nil, err end
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
    definition = copy(definition)
    local entry = { id = definition.id, definition = definition, revision = 1, dynamic = {}, resolved = {}, dynamicEpoch = 0 }
    local initial, map = records(entry, definition.entries or {})
    if not initial then return nil, map end
    entry.records, entry.recordMap = initial, map
    entry.recordOrder = {}
    for index, record in ipairs(initial) do entry.recordOrder[record.id] = index end
    definition.entries = nil
    local handle, internal, enabledBeforeCommit
    local function start()
        if not internal then enabledBeforeCommit = true; return end
        if not active(entry) then return end
        if definition.onEnable then
            local called, cleanup = pcall(definition.onEnable, handle)
            if not called then report(entry, "CALLBACK_ERROR", "onEnable")
            elseif type(cleanup) == "function" then
                if active(entry) then entry.cleanup = cleanup
                elseif not pcall(cleanup, "cancelled-enable") then report(entry, "CALLBACK_ERROR", "cleanup") end
            elseif cleanup ~= nil then report(entry, "INVALID_CALLBACK", "onEnable.cleanup") end
        end
    end
    local function stop(reason)
        P:CancelQueries(reason, entry)
        entry.dynamic, entry.resolved = {}, {}
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        local cleanup = entry.cleanup; entry.cleanup = nil
        if cleanup and not pcall(cleanup, reason) then report(entry, "CALLBACK_ERROR", "cleanup") end
        if definition.onDisable and not pcall(definition.onDisable, reason) then report(entry, "CALLBACK_ERROR", "onDisable") end
    end
    local draft
    draft, err = I.Registry:Begin({ id = entry.id, title = definition.title, version = definition.version,
        apiVersion = 2, minApiRevision = definition.minApiRevision or 1,
        onEnabled = start, onDisabled = stop }, { public = true })
    if not draft then return nil, err end
    ok, err = draft:RegisterSearchSource({ id = "records", title = definition.title, version = 2, revision = 1,
        priority = 0, scope = definition.scope or {}, snapshot = function() return entry.records end })
    if not ok then draft:Abort(); return nil, err end
    for id, view in pairs(definition.views or {}) do
        ok, err = draft:RegisterPanelFactory({ id = id, create = view.create, stateSchema = view.stateSchema })
        if not ok then draft:Abort(); return nil, err end
    end
    internal, err = draft:Commit()
    if not internal then return nil, err end
    self.entries[entry.id] = entry
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
            local committed, commitError, _, changed = source:CommitSnapshot(nextList)
            entry.updating = nil
            if not committed then return nil, commitError end
            if not changed then return true end
            entry.records, entry.recordMap, entry.recordOrder = nextList, nextMap, {}
            for index, record in ipairs(nextList) do entry.recordOrder[record.id] = index end
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
            local committed, commitError, _, changed = source:ApplyDelta(additions, delta.remove or {})
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
                local index = entry.recordOrder[record.id] or #entry.records + 1
                entry.records[index], entry.recordMap[record.id], entry.recordOrder[record.id] = record, record, index
            end
        end
        entry.revision = entry.revision + 1
        if not (C_Timer and C_Timer.NewTimer) and I.Search.Session then I.Search.Session:RefreshSource() end
        return true
    end
    function handle:GetState()
        if P.entries[entry.id] ~= entry then return failure("STALE_HANDLE", nil, entry.id) end
        local state = internal:GetState()
        return { enabled = active(entry), lifecycle = state.lifecycle, revision = entry.revision, lastError = copy(entry.lastError) }
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
            entry.records, entry.recordMap, entry.recordOrder, entry.dynamic, entry.resolved = {}, {}, {}, {}, {}
            definition.actions, definition.drags, definition.views, definition.query, definition.resolve = nil, nil, nil, nil, nil
            definition.onEnable, definition.onDisable = nil, nil
        end
        return removed, removeError
    end
    if enabledBeforeCommit then start() end
    return handle
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
        and (item._providerRecord == entry.recordMap[item.id] or item._providerRecord == entry.dynamic[item.id] or item._providerRecord == entry.resolved[item.id])
end
local function materialize(entry, record)
    local item = I.Search.Query:Materialize({ record = record, sourceID = entry.id .. ":records",
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
        return I.Search.Query:Materialize({ record = indexed.record, sourceID = source.id, sourceExtensionID = ref.providerID,
            sourceTitle = source.title or source.extensionTitle, sourceGeneration = source.generation, sourceRevision = source.revision, stableID = indexed.stableID })
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
        record = restored[1]; entry.resolved[record.id] = record
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
function P:Search(request, context, onChange)
    local output, collecting, epoch = {}, true, self.queryEpoch
    local function gather()
        local result = {}
        for _, list in pairs(output) do for _, item in ipairs(list) do if P:IsCurrent(item) then result[#result + 1] = item end end end
        return result
    end
    local ids = {}
    for id, entry in pairs(self.entries) do
        if active(entry) and entry.definition.query and (not request.filter or not request.filter.sourceID or request.filter.sourceID == id .. ":records") then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if epoch ~= self.queryEpoch then break end
        local entry = self.entries[id]
        if entry and active(entry) then
        entry.dynamic, entry.resolved = {}, {}
        entry.dynamicEpoch = entry.dynamicEpoch + 1
        local job = { entry = entry, epoch = epoch }
        self.jobs[job] = true
        local function reply(input)
            if job.done or not active(entry) or job.epoch ~= P.queryEpoch then return failure("STALE_REQUEST", "query", id) end
            local list, map = records(entry, input, P.queryLimit)
            if not list then report(entry, map.code, "query"); finish(job, "invalid"); return nil, map end
            entry.dynamic = map
            local items = {}
            for index = 1, #list do
                local record = list[index]
                local category = type(record.category) == "table" and record.category.id or record.category
                local identity = I.Search.RuntimeIdentity
                if (not request.filter or not request.filter.categoryID or request.filter.categoryID == category)
                    and (not identity or identity:MatchesScope(record.scope or entry.definition.scope)) then
                    local item = materialize(entry, record)
                    local match = I.Search.Normalizer:MatchText(request.normalized, item.text, "title", { allowFuzzy = false })
                    if match then item.confidence, item.evidence = match.confidence, match end
                    items[#items + 1] = item
                end
            end
            output[id] = items
            finish(job, "complete")
            if not collecting and onChange then onChange(gather()) end
            return true
        end
        local ok, cancel = pcall(entry.definition.query, copy(request), reply, copy(context or {}))
        if not ok then
            output[id], entry.dynamic = nil, {}
            report(entry, "CALLBACK_ERROR", "query"); finish(job, "error")
        elseif cancel ~= nil and type(cancel) ~= "function" then report(entry, "INVALID_CALLBACK", "query.cancel"); finish(job, "error")
        elseif job.done then
            if cancel and not pcall(cancel, job.reason) then report(entry, "CALLBACK_ERROR", "query.cancel") end
        else
            job.cancel = cancel
            if C_Timer and C_Timer.NewTimer then job.timer = C_Timer.NewTimer(5, function() report(entry, "QUERY_TIMEOUT", "query"); finish(job, "timeout") end) end
        end
        end
    end
    collecting = false
    return gather()
end
