local I = _G.LycheeInternal
local Q = { active = false, last = nil, pending = nil, timer = nil, timerToken = 0, ambientEnabled = {}, limit = 20, catalogLimit = 8, ambientLimit = 12, debounceSeconds = 0.04 }
I.Search.Query = Q

local function resultLess(left, right)
    local lc, rc = left.confidence or 0, right.confidence or 0
    if lc ~= rc then return lc > rc end
    local lp = left.sourcePriority or (left.command and left.command.priority) or 0
    local rp = right.sourcePriority or (right.command and right.command.priority) or 0
    if lp ~= rp then return lp > rp end
    local lco, rco = left.categoryOrder or 0, right.categoryOrder or 0
    if lco ~= rco then return lco < rco end
    return tostring(left.stableID or left._ext or "") .. ":" .. tostring(left.id or "") < tostring(right.stableID or right._ext or "") .. ":" .. tostring(right.id or "")
end

local function appendUnique(out, seen, item, command)
    if type(item) ~= "table" then return false end
    if command then item._ext, item.command = command._ext, command end
    local canonical = item.stableID or (item.searchRecord and item.searchRecord.id) or item.id or item.key
    local key
    if item.searchRecord then key = "record:" .. tostring(item._ext or item.sourceID or "") .. ":" .. tostring(item.id)
    else key = tostring(item._ext or (item.command and item.command._ext) or "") .. ":" .. tostring(canonical or item.text or #out + 1) end
    if seen[key] then return false end
    seen[key] = true; out[#out + 1] = item
    return true
end

local function displayText(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return "" end
    local normalizer = I.Search.Normalizer
    local locale = normalizer.locale
    local entries = normalizer:Localized(value)
    local defaultText, englishText
    for index = 1, #entries do
        local entry = entries[index]
        local identity = I.Search.RuntimeIdentity
        if not identity or identity:MatchesScope(nil, entry) then
            if entry.locale == locale then return entry.text end
            if entry.locale == "default" and defaultText == nil then defaultText = entry.text end
            if entry.locale == "enUS" and englishText == nil then englishText = entry.text end
        end
    end
    return defaultText or englishText or ""
end

local function displayActions(actions)
    if type(actions) ~= "table" then return actions end
    local displayed = {}
    for index = 1, #actions do
        local action = actions[index]
        if type(action) == "table" then
            local copy = {}
            for key, value in pairs(action) do copy[key] = value end
            copy.title = displayText(action.title)
            displayed[index] = copy
        end
    end
    return displayed
end

local function searchRecordItem(hit)
    local record = hit and hit.record
    if not record or not hit.sourceID or hit.sourceID == "legacy" then return nil end
    local item = {
        id = record.id,
        text = displayText(record.title),
        kindTitle = displayText(record.kindTitle),
        subtext = displayText(record.subtitle or record.subtext),
        description = displayText(record.description),
        payload = record.payload or record,
        icon = record.icon,
        category = displayText(record.category and record.category.title or record.category),
        categoryColor = record.category and record.category.color,
        source = hit.sourceID,
        sourceID = hit.sourceID,
        sourceTitle = displayText(hit.sourceTitle),
        sourceGeneration = hit.sourceGeneration,
        sourceRevision = hit.sourceRevision,
        _ext = record._extensionID or hit.sourceExtensionID,
        searchRecord = record,
        confidence = hit.confidence,
        evidence = hit.evidence,
        sourcePriority = hit.sourcePriority,
        categoryOrder = hit.categoryOrder,
        stableID = hit.stableID,
    }
    if type(record.actions) == "table" then
        item.interaction = {
            primaryActionID = record.primaryActionID or (record.actions[1] and record.actions[1].id),
            actions = displayActions(record.actions),
            drag = record.drag,
        }
    elseif record.interaction then
        local interaction = {}
        for key, value in pairs(record.interaction) do interaction[key] = value end
        interaction.actions = displayActions(record.interaction.actions)
        item.interaction = interaction
    end
    return I.Providers and I.Providers:Stamp(item) or item
end

function Q:Materialize(hit) return searchRecordItem(hit) end

function Q:_ResolveGeneration(externalGeneration, context)
    if type(externalGeneration) == "number" then return externalGeneration end
    if context and type(context.generation) == "number" then return context.generation end
    local session = I.Search and I.Search.Session
    return session and session.generation or 0
end

-- Resolve saved identities without running a fuzzy query or changing the active
-- search generation. Materialization stays identical to normal search results.
function Q:ResolveRecent(refs, limit)
    local out = {}
    for index = 1, #refs do
        local item = I.Providers and I.Providers:Resolve(refs[index], I.Context and I.Context:Snapshot() or {})
        if item then out[#out + 1] = item end
        if #out >= (limit or 5) then break end
    end
    return out
end

function Q:_BuildRequest(raw, context, generation)
    local normalized = I.Search.Normalizer:Normalize(raw)
    return { generation = generation, raw = raw or "", normalized = normalized,
        tokens = I.Search.Normalizer:Terms(normalized), limit = self.limit,
        contextToken = context and context.token, session = context and context.session,
        visible = context and context.visible, filter = context and context.searchFilter }
end

function Q:_IsCurrent(generation, context)
    if context and context.visible == false then return false, "HIDDEN" end
    if context and context.generation and context.generation ~= generation then return false, "STALE_CONTEXT" end
    local session = I.Search and I.Search.Session
    if session and context and context.session then
        return session:IsCurrent(context.session, generation)
    end
    return true
end

function Q:_AmbientCommands(normalized)
    if normalized == "" or not I.Catalog or type(I.Catalog.GetAmbientView) ~= "function" then return {} end
    return I.Catalog:GetAmbientView(normalized, self.ambientEnabled)
end

function Q:_Execute(raw, context, generation)
    local request = self:_BuildRequest(raw, context, generation)
    local filtered = type(request.filter) == "table"
    local catalogBudget = filtered and 0 or math.min(self.catalogLimit, self.limit)
    local ambientBudget = self.limit
    local catalogResults = not filtered and I.Catalog and I.Catalog:Query(request, catalogBudget) or {}
    local out, seen, catalogDynamic = {}, {}, {}
    for index = 1, #catalogResults do
        local result = catalogResults[index]
        if result.command and result.command.presentation == "dynamic-list" then
            catalogDynamic[#catalogDynamic + 1] = result.command
        else
            appendUnique(out, seen, result)
        end
    end
    ambientBudget = math.max(0, self.limit - #out)
    if I.Search and I.Search.StaticIndex then
        local indexed = I.Search.StaticIndex:Search(request.normalized, math.min(ambientBudget, self.limit - #out), request.filter)
        for index = 1, #indexed do
            local item = searchRecordItem(indexed[index])
            if item then appendUnique(out, seen, item) end
        end
    end
    local resolvedAdded = 0
    for commandIndex = 1, #catalogDynamic do
        if resolvedAdded >= ambientBudget or #out >= self.limit then break end
        local command = catalogDynamic[commandIndex]
        request.limit = math.min(ambientBudget - resolvedAdded, self.limit - #out)
        local ok, items = pcall(command.resolve, request, context or {})
        if ok and type(items) == "table" then
            for itemIndex = 1, #items do
                if appendUnique(out, seen, items[itemIndex], command) then
                    resolvedAdded = resolvedAdded + 1
                    if resolvedAdded >= ambientBudget or #out >= self.limit then break end
                end
            end
        end
    end
    local ambientCommands, ambientAdded = filtered and {} or self:_AmbientCommands(request.normalized), 0
    for commandIndex = 1, #ambientCommands do
        if resolvedAdded + ambientAdded >= ambientBudget or #out >= self.limit then break end
        request.limit = math.min(ambientBudget - resolvedAdded - ambientAdded, self.limit - #out)
        local schedulable = ambientCommands[commandIndex]
        local ok, items = pcall(schedulable.resolve, request, context or {})
        if ok and type(items) == "table" then
            for itemIndex = 1, #items do
                if appendUnique(out, seen, items[itemIndex], schedulable.command) then
                    ambientAdded = ambientAdded + 1
                    if resolvedAdded + ambientAdded >= ambientBudget or #out >= self.limit then break end
                end
            end
        end
    end
    request.limit = self.limit
    table.sort(out, resultLess)
    while #out > self.limit do out[#out] = nil end
    return out
end

function Q:_Commit(generation, results)
    self.last = { generation = generation, results = results }
    return true
end

function Q:_CancelTimer()
    local timer = self.timer
    self.timer = nil
    self.timerToken = self.timerToken + 1
    if timer and type(timer.Cancel) == "function" then pcall(timer.Cancel, timer) end
end

function Q:Query(raw, context, externalGeneration, callback)
    if I.Providers then I.Providers:CancelQueries("query-replaced") end
    local generation = self:_ResolveGeneration(externalGeneration, context)
    local current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    self.active = true
    local results = self:_Execute(raw, context, generation)
    if I.Providers and raw ~= "" then
        local base = results
        local function merge(dynamic)
            local combined, seen = {}, {}
            for _, item in ipairs(base) do appendUnique(combined, seen, item) end
            for _, item in ipairs(dynamic) do appendUnique(combined, seen, item) end
            table.sort(combined, resultLess)
            while #combined > self.limit do combined[#combined] = nil end
            return combined
        end
        local dynamic = I.Providers:Search(self:_BuildRequest(raw, context, generation), context, function(items)
            if not self:_IsCurrent(generation, context) then return end
            local combined = merge(items)
            self:_Commit(generation, combined)
            if callback then callback(combined, generation) end
        end)
        results = merge(dynamic)
    end
    self.active = false
    current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    if not self:_Commit(generation, results) then return generation, {} end
    return generation, results
end

function Q:Schedule(raw, context, externalGeneration, callback, delay)
    if I.Providers then I.Providers:CancelQueries("input-changed") end
    local generation = self:_ResolveGeneration(externalGeneration, context)
    self:_CancelTimer()
    self.pending = { raw = raw, context = context, generation = generation, callback = callback }
    local wait = delay
    if wait == nil then wait = self.debounceSeconds end
    local timerToken = self.timerToken
    if wait <= 0 then
        self:Flush(generation)
    elseif C_Timer and type(C_Timer.NewTimer) == "function" then
        local timer
        timer = C_Timer.NewTimer(wait, function()
            if self.timerToken ~= timerToken or self.timer ~= timer then return end
            self.timer = nil
            self:Flush(generation)
        end)
        self.timer = timer
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(wait, function()
            if self.timerToken == timerToken then self:Flush(generation) end
        end)
    end
    return generation, true
end

function Q:Flush(expectedGeneration)
    self:_CancelTimer()
    local pending = self.pending
    if not pending or (expectedGeneration and pending.generation ~= expectedGeneration) then return false end
    self.pending = nil
    local generation, results = self:Query(pending.raw, pending.context, pending.generation, pending.callback)
    if type(pending.callback) == "function" then pending.callback(results, generation) end
    return true, generation, results
end

function Q:Cancel(reason, generation)
    if I.Providers then I.Providers:CancelQueries(reason) end
    self:_CancelTimer()
    self.last = { generation = generation, results = {}, cancelled = reason or "INVALIDATED" }
    self.pending, self.active = nil, false
    return true
end

function Q:SetAmbientEnabled(key, enabled) self.ambientEnabled[key] = enabled end
