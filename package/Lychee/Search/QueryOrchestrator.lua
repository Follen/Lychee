local I = _G.LycheeInternal
local Q = { generation = 0, active = false, last = nil, pending = nil, timer = nil, timerToken = 0, ambientEnabled = {}, limit = 20, catalogLimit = 8, ambientLimit = 12, debounceSeconds = 0.04 }
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
    local payload = item.payload
    local canonical = item.stableID or (item.searchRecord and item.searchRecord.id) or item.id or item.key
    if item.searchRecord and item.searchRecord.kind == "spell" and payload and payload.spellID then canonical = "spell:" .. tostring(payload.spellID) end
    if item.searchRecord and item.searchRecord.kind == "creature" and payload and payload.creatureID then canonical = "creature:" .. tostring(payload.creatureID) end
    local key
    if item.searchRecord then key = "record:" .. tostring(canonical)
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
        subtext = displayText(record.subtitle or record.subtext),
        description = displayText(record.description),
        payload = record.payload or record,
        icon = record.icon,
        category = displayText(record.category and record.category.title or record.category),
        source = hit.sourceID,
        sourceID = hit.sourceID,
        sourceGeneration = hit.sourceGeneration,
        sourceRevision = hit.sourceRevision,
        _ext = record._extensionID,
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
    return item
end

function Q:_BeginGeneration(externalGeneration)
    local generation = externalGeneration or (self.generation + 1)
    if generation > self.generation then self.generation = generation end
    return generation
end

function Q:_BuildRequest(raw, context, generation)
    local normalized = I.Search.Normalizer:Normalize(raw)
    return { generation = generation, raw = raw or "", normalized = normalized, tokens = I.Search.Normalizer:Terms(normalized), limit = self.limit, contextToken = context and context.token, session = context and context.session, visible = context and context.visible }
end

function Q:_IsCurrent(generation, context)
    if generation ~= self.generation then return false, "STALE_GENERATION" end
    if context and context.visible == false then return false, "HIDDEN" end
    if context and context.generation and context.generation ~= generation then return false, "STALE_CONTEXT" end
    return true
end

function Q:_AmbientCommands(normalized)
    local commands = {}
    if normalized == "" or not I.Catalog then return commands end
    for key, command in pairs(I.Catalog.commands) do
        local match = command.match
        local minimum, maximum = match and match.minLength or 0, match and match.maxLength or math.huge
        if command._enabled ~= false and command.entitySearch ~= false and match and match.type == "ambient" and self.ambientEnabled[key] ~= false
            and #normalized >= minimum and #normalized <= maximum and type(command.resolve) == "function" then
            commands[#commands + 1] = command
        end
    end
    table.sort(commands, function(left, right)
        local lp, rp = left.priority or 0, right.priority or 0
        return lp > rp or (lp == rp and left._key < right._key)
    end)
    return commands
end

function Q:_Execute(raw, context, generation)
    local request = self:_BuildRequest(raw, context, generation)
    local catalogBudget, ambientBudget = math.min(self.catalogLimit, self.limit), math.min(self.ambientLimit, self.limit - math.min(self.catalogLimit, self.limit))
    local catalogResults = I.Catalog and I.Catalog:Query(request, catalogBudget) or {}
    local out, seen = {}, {}
    for index = 1, #catalogResults do appendUnique(out, seen, catalogResults[index]) end
    if I.Search and I.Search.StaticIndex then
        local indexed = I.Search.StaticIndex:Search(request.normalized, math.min(ambientBudget, self.limit - #out))
        for index = 1, #indexed do
            local item = searchRecordItem(indexed[index])
            if item then appendUnique(out, seen, item) end
        end
    end
    local ambientCommands, ambientAdded = self:_AmbientCommands(request.normalized), 0
    for commandIndex = 1, #ambientCommands do
        if ambientAdded >= ambientBudget or #out >= self.limit then break end
        request.limit = math.min(ambientBudget - ambientAdded, self.limit - #out)
        local ok, items = pcall(ambientCommands[commandIndex].resolve, request, context or {})
        if ok and type(items) == "table" then
            for itemIndex = 1, #items do
                if appendUnique(out, seen, items[itemIndex], ambientCommands[commandIndex]) then
                    ambientAdded = ambientAdded + 1
                    if ambientAdded >= ambientBudget or #out >= self.limit then break end
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
    if generation ~= self.generation then return false end
    self.last = { generation = generation, results = results }
    return true
end

function Q:_CancelTimer()
    local timer = self.timer
    self.timer = nil
    self.timerToken = self.timerToken + 1
    if timer and type(timer.Cancel) == "function" then pcall(timer.Cancel, timer) end
end

function Q:Query(raw, context, externalGeneration)
    local generation = self:_BeginGeneration(externalGeneration)
    if externalGeneration and externalGeneration < self.generation then return generation, {} end
    local current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    self.active = true
    local results = self:_Execute(raw, context, generation)
    self.active = false
    current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    if not self:_Commit(generation, results) then return generation, {} end
    return generation, results
end

function Q:Schedule(raw, context, externalGeneration, callback, delay)
    local generation = self:_BeginGeneration(externalGeneration)
    if externalGeneration and externalGeneration < self.generation then return generation, false end
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
    if not pending or (expectedGeneration and pending.generation ~= expectedGeneration) or pending.generation ~= self.generation then return false end
    self.pending = nil
    local generation, results = self:Query(pending.raw, pending.context, pending.generation)
    if generation ~= self.generation then return false end
    if type(pending.callback) == "function" then pending.callback(results, generation) end
    return true, generation, results
end

function Q:Invalidate()
    self:_CancelTimer()
    self.generation, self.last, self.pending, self.active = self.generation + 1, { generation = self.generation + 1, results = {}, cancelled = "INVALIDATED" }, nil, false
end

function Q:SetAmbientEnabled(key, enabled) self.ambientEnabled[key] = enabled end
