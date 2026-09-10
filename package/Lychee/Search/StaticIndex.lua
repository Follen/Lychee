local I = _G.LycheeInternal
I.Search = I.Search or {}

local Index = {
    sources = {},
    entries = {},
    exact = {},
    prefix = {},
    tokens = {},
    grams = {},
    categories = {},
    version = 0,
    sourceGeneration = 0,
    candidateLimit = 200,
    resultLimit = 20,
    fuzzyLimit = 48,
    fuzzyBudgetMS = 1.5,
    diagnostics = {},
    previousQuery = nil,
    previousCandidates = nil,
    previousFilterKey = nil,
    listeners = {},
}
I.Search.StaticIndex = Index

local function wipeTable(value)
    for key in pairs(value) do value[key] = nil end
end

local function copyPlain(value, seen)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then return value end
    if kind ~= "table" or getmetatable(value) ~= nil then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local copy = {}
    for key, child in pairs(value) do
        local copiedKey, copiedChild = copyPlain(key, seen), copyPlain(child, seen)
        if copiedKey == nil or (child ~= nil and copiedChild == nil) then seen[value] = nil; return nil end
        copy[copiedKey] = copiedChild
    end
    seen[value] = nil
    return copy
end

local function addSet(map, key, entryKey)
    if not key or key == "" then return end
    local set = map[key]
    if not set then map[key] = entryKey
    elseif type(set) == "string" then
        if set ~= entryKey then map[key] = { [set] = true, [entryKey] = true, [0] = 2 } end
    elseif not set[entryKey] then set[entryKey] = true; set[0] = set[0] + 1 end
end

local function removeSet(map, key, entryKey)
    local set = key and map[key]
    if not set then return end
    if type(set) == "string" then
        if set == entryKey then map[key] = nil end
        return
    end
    if not set[entryKey] then return end
    set[entryKey], set[0] = nil, set[0] - 1
    if set[0] == 1 then
        for remaining in pairs(set) do if remaining ~= 0 then map[key] = remaining; break end end
    end
end

local function codepoints(text)
    local out = {}
    for index = 1, #text do
        local byte = text:byte(index)
        if byte < 128 or byte >= 192 then out[#out + 1] = index end
    end
    out[#out + 1] = #text + 1
    return out
end

local function grams(text)
    local starts, out, seen = codepoints(text), {}, {}
    local count = #starts - 1
    -- One posting per unique UTF-8 character is sufficient for a recall-safe
    -- candidate intersection. Scoring still checks whole phrases and tokens.
    for first = 1, count do
        local gram = text:sub(starts[first], starts[first + 1] - 1)
        if gram ~= " " and not seen[gram] then seen[gram] = true; out[#out + 1] = gram end
    end
    return out
end

local function categoryID(record)
    local category = record and record.category
    if type(category) == "table" then return category.id end
    return category
end

local function categoryOrder(record)
    return type(record and record.category) == "table" and tonumber(record.category.order) or 0
end

local function localizedEntries(value, scope)
    local entries = I.Search.Normalizer:Localized(value, scope)
    local identity = I.Search.RuntimeIdentity
    local out = {}
    for index = 1, #entries do
        local entry = entries[index]
        if (entry.locale == "default" or entry.locale == I.Search.Normalizer.locale)
            and (not identity or identity:MatchesScope(scope, entry)) then
            out[#out + 1] = entry
        end
    end
    return out
end

local function addText(entry, field, value, scope)
    local values = localizedEntries(value, scope)
    for index = 1, #values do
        local raw = values[index].text
        local normalized = I.Search.Normalizer:Normalize(raw)
        if normalized ~= "" then
            -- Flat triples avoid a hash table per compiled field. Host-private;
            -- public records and match evidence retain their named fields.
            local fields, offset = entry.fields, #entry.fields
            fields[offset + 1], fields[offset + 2], fields[offset + 3] = field, raw, normalized
        end
    end
end

local function buildEntry(source, record)
    local key = source.id .. ":" .. record.id
    local entry = {
        key = key,
        sourceID = source.id,
        source = source,
        record = record,
        stableID = (source.extensionID or source.id) .. ":" .. record.id,
        fields = {},
        categoryID = categoryID(record),
        categoryOrder = categoryOrder(record),
    }
    if not source.enabled then entry.fields = nil; return entry end
    addText(entry, "title", record.title, record.scope or source.scope)
    addText(entry, "alias", record.aliases, record.scope or source.scope)
    addText(entry, "keyword", record.keywords, record.scope or source.scope)
    addText(entry, "description", record.description, record.scope or source.scope)
    local category = record.category
    addText(entry, "category", type(category) == "table" and (category.title or category.id) or category, record.scope or source.scope)
    return entry
end

local function updateMemberships(self, entry, updateSet)
    -- The posting sets already deduplicate keys. Do not retain a second hash
    -- and a tiny table for every prefix/gram of every record. Reconstruct only
    -- this entry's memberships when it is changed or removed (not on query).
    local seen = {}
    for index = 1, #entry.fields, 3 do
        local identity = entry.fields[index] .. "\0" .. entry.fields[index + 2]
        if not seen[identity] then
            seen[identity] = true
            local gramValues = grams(entry.fields[index + 2])
            for gramIndex = 1, #gramValues do updateSet(self.grams, gramValues[gramIndex], entry.key) end
        end
    end
    if entry.categoryID then updateSet(self.categories, I.Search.Normalizer:Normalize(entry.categoryID), entry.key) end
end

local function installEntry(self, entry)
    self.entries[entry.key] = entry
    if entry.source.enabled then updateMemberships(self, entry, addSet); entry.indexed = true end
end

local function removeEntry(self, entry)
    if not entry then return end
    if entry.indexed then updateMemberships(self, entry, removeSet) end
    self.entries[entry.key] = nil
end

local function clearSourceEntries(self, source)
    if not source or not source.entryKeys then return end
    for key in pairs(source.entryKeys) do removeEntry(self, self.entries[key]) end
    wipeTable(source.entryKeys)
end

local function notifyChange(self, source, reason)
    for index = 1, #self.listeners do
        pcall(self.listeners[index], source.id, reason, {
            revision = source.revision,
            generation = source.generation,
            enabled = source.enabled,
        })
    end
end

local function bump(self, source, revision, reason)
    local requested = tonumber(revision)
    if requested and requested > (source.revision or 0) then source.revision = requested
    else source.revision = (source.revision or 0) + 1 end
    self.sourceGeneration = self.sourceGeneration + 1
    source.generation = self.sourceGeneration
    source._generation = source.generation
    self.version = self.version + 1
    self.previousQuery, self.previousCandidates, self.previousFilterKey = nil, nil, nil
    notifyChange(self, source, reason)
    return source.revision, source.generation
end

local function nowMS()
    if type(debugprofilestop) == "function" then
        local ok, value = pcall(debugprofilestop)
        if ok and type(value) == "number" then return value end
    end
    return nil
end

local function diagnose(self, code)
    self.diagnostics[code] = (self.diagnostics[code] or 0) + 1
end

local function validateSourceDescriptor(descriptor)
    return type(descriptor) == "table" and type(descriptor.id) == "string" and descriptor.id ~= ""
end

function Index:New()
    local value = {}
    for key, item in pairs(self) do
        if type(item) ~= "table" then value[key] = item end
    end
    value.sources, value.entries = {}, {}
    value.exact, value.prefix, value.tokens, value.grams, value.categories = {}, {}, {}, {}, {}
    value.diagnostics = {}
    value.listeners = {}
    value.previousQuery, value.previousCandidates, value.previousFilterKey = nil, nil, nil
    return setmetatable(value, { __index = self })
end

function Index:OnChange(callback)
    if type(callback) ~= "function" then return false end
    self.listeners[#self.listeners + 1] = callback
    return true
end

function Index:ClearQueryCache()
    self.previousQuery, self.previousCandidates, self.previousFilterKey = nil, nil, nil
end

function Index:Clear()
    self.sources, self.entries = {}, {}
    self.exact, self.prefix, self.tokens, self.grams, self.categories = {}, {}, {}, {}, {}
    self.previousQuery, self.previousCandidates, self.previousFilterKey = nil, nil, nil
    self.version = self.version + 1
end

function Index:RegisterSource(descriptor)
    if not validateSourceDescriptor(descriptor) then return nil, "INVALID_SCHEMA" end
    if self.sources[descriptor.id] then return nil, "DUPLICATE_ID" end
    self.sourceGeneration = self.sourceGeneration + 1
    local source = {
        id = descriptor.id,
        version = tonumber(descriptor.version) or 1,
        priority = tonumber(descriptor.priority) or 0,
        scope = descriptor.scope,
        revision = tonumber(descriptor.revision) or 0,
        generation = self.sourceGeneration,
        _generation = self.sourceGeneration,
        enabled = descriptor._enabled ~= false,
        extensionID = descriptor._extensionID or descriptor.extensionID,
        title = descriptor.title,
        extensionTitle = descriptor.extensionTitle,
        entryKeys = {},
        pending = nil,
        invalidation = {},
    }
    self.sources[source.id] = source
    self.version = self.version + 1
    return true, source.generation
end

function Index:UnregisterSource(sourceID)
    local source = self.sources[sourceID]
    if not source then return true end
    clearSourceEntries(self, source)
    bump(self, source, nil, "unregistered")
    self.sources[sourceID] = nil
    self:Persist()
    return true
end

function Index:TouchSource(sourceID, enabled)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    if source.enabled == not not enabled then return true, source.generation, source.revision end
    source.enabled = not not enabled
    for key in pairs(source.entryKeys) do
        local entry = self.entries[key]
        if source.enabled then
            installEntry(self, buildEntry(source, entry.record))
        elseif entry.indexed then
            updateMemberships(self, entry, removeSet)
            entry.indexed, entry.fields = nil, nil
        end
    end
    local revision, generation = bump(self, source, nil, "enabled")
    self:Persist()
    return true, generation, revision
end

function Index:BeginSnapshot(sourceID)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    source.pending = { records = {}, removed = {}, generation = source.generation }
    return source.generation
end

function Index:Upsert(sourceID, record, revision, generation)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    if generation and generation ~= source.generation then return false, "STALE_GENERATION" end
    if not source.pending then
        local entryKey = sourceID .. ":" .. record.id
        removeEntry(self, self.entries[entryKey])
        local entry = buildEntry(source, record)
        installEntry(self, entry)
        source.entryKeys[entry.key] = true
        bump(self, source, revision, "upserted")
        self:Persist()
        return true
    end
    source.pending.records[record.id] = record
    source.pending.removed[record.id] = nil
    return true
end

function Index:Remove(sourceID, recordID, revision, generation)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    if generation and generation ~= source.generation then return false, "STALE_GENERATION" end
    if not source.pending then
        local entryKey = sourceID .. ":" .. recordID
        removeEntry(self, self.entries[entryKey])
        source.entryKeys[entryKey] = nil
        bump(self, source, revision, "removed")
        self:Persist()
        return true
    end
    source.pending.records[recordID] = nil
    source.pending.removed[recordID] = true
    return true
end

local function sameRecord(left, right)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for key, value in pairs(left) do if not sameRecord(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function applyChanges(self, source, replacements, removals, revision, reason)
    if #replacements == 0 and #removals == 0 and (not revision or revision <= source.revision) then
        return true, source.generation, source.revision, false
    end
    for index = 1, #removals do
        local key = removals[index]
        removeEntry(self, self.entries[key]); source.entryKeys[key] = nil
    end
    for index = 1, #replacements do
        local entry = replacements[index]
        if self.entries[entry.key] then removeEntry(self, self.entries[entry.key]) end
        installEntry(self, entry); source.entryKeys[entry.key] = true
    end
    local nextRevision, nextGeneration = bump(self, source, revision, reason)
    self:Persist()
    return true, nextGeneration, nextRevision, true
end

function Index:ApplyDelta(sourceID, records, removedIDs)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    if source.pending then return nil, "INVALID_STATE" end
    local replacements, removals = {}, {}
    for index = 1, #records do
        local record = records[index]
        local old = self.entries[sourceID .. ":" .. record.id]
        if not old or not sameRecord(old.record, record) then replacements[#replacements + 1] = buildEntry(source, record) end
    end
    for index = 1, #removedIDs do
        local key = sourceID .. ":" .. removedIDs[index]
        if self.entries[key] then removals[#removals + 1] = key end
    end
    return applyChanges(self, source, replacements, removals, nil, "delta")
end

function Index:CommitSnapshot(sourceID, records, revision, generation)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    if generation and generation ~= source.generation then return nil, "STALE_GENERATION" end
    local nextRecords = {}
    if type(records) == "table" then
        for index = 1, #records do nextRecords[records[index].id] = records[index] end
    elseif source.pending then
        for key in pairs(source.entryKeys) do
            local old = self.entries[key]
            if old then nextRecords[old.record.id] = old.record end
        end
        for recordID in pairs(source.pending.removed) do nextRecords[recordID] = nil end
        for recordID, record in pairs(source.pending.records) do nextRecords[recordID] = record end
    else
        return nil, "INVALID_SCHEMA"
    end
    local removed, replacements = {}, {}
    for key in pairs(source.entryKeys) do
        local old = self.entries[key]
        if old and not nextRecords[old.record.id] then removed[#removed + 1] = key end
    end
    local ids = {}
    for recordID in pairs(nextRecords) do ids[#ids + 1] = recordID end
    table.sort(ids)
    for index = 1, #ids do
        local record = nextRecords[ids[index]]
        local key = source.id .. ":" .. record.id
        local old = self.entries[key]
        if not old or not sameRecord(old.record, record) then
            replacements[#replacements + 1] = buildEntry(source, record)
        end
    end
    source.pending = nil
    return applyChanges(self, source, replacements, removed, revision, "snapshot")
end

function Index:AddRecord(sourceID, record, descriptor)
    if not self.sources[sourceID] then
        local registered, why = self:RegisterSource(descriptor or { id = sourceID })
        if not registered then return nil, why end
    end
    local source = self.sources[sourceID]
    local entryKey = sourceID .. ":" .. record.id
    removeEntry(self, self.entries[entryKey])
    local entry = buildEntry(source, record)
    installEntry(self, entry)
    source.entryKeys[entry.key] = true
    bump(self, source, nil, "added")
    return true
end

function Index:Invalidate(sourceID, key)
    local source = self.sources[sourceID]
    if not source then return nil, "SOURCE_NOT_FOUND" end
    -- Invalidation already bumps the entire source generation. Retaining every
    -- caller-supplied key adds unbounded history without enabling finer refresh.
    source.invalidation["*"] = true
    local revision, generation = bump(self, source, nil, "invalidated")
    return true, generation, revision
end

function Index:GetSourceState(sourceID)
    local source = self.sources[sourceID]
    if not source then return nil end
    return { id = source.id, revision = source.revision, generation = source.generation, enabled = source.enabled }
end

-- Host-private canonical record lookup. Provider callbacks still receive copies.
function Index:GetRecord(sourceID, recordID)
    local entry = self.entries[sourceID .. ":" .. recordID]
    return entry and entry.record
end

local function addCandidates(out, seen, set, maximum)
    if not set then return false end
    if type(set) == "string" then
        if not seen[set] then seen[set]=true; out[#out+1]=set end
        return #out >= maximum
    end
    for key in pairs(set) do
        if key ~= 0 and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
            if #out >= maximum then return true end
        end
    end
    return false
end

local function filterIdentity(filter)
    if type(filter) ~= "table" then return "" end
    return tostring(filter.categoryID or "") .. "\0" .. tostring(filter.sourceID or "")
end

local function filteredSet(self, filter)
    if type(filter) ~= "table" then return nil end
    if filter.sourceID then
        local source = self.sources[filter.sourceID]
        return source and source.enabled and source.entryKeys or {}
    end
    if filter.categoryID then return self.categories[I.Search.Normalizer:Normalize(filter.categoryID)] or {} end
    return nil
end

local function candidateKeys(self, normalized, filter)
    local out, seen = {}, {}
    local identity = filterIdentity(filter)
    if normalized == "" then
        addCandidates(out, seen, filteredSet(self, filter), self.candidateLimit)
        return out, false
    end
    -- Every literal/token match must contain every gram of each query term.
    -- Start with the smallest posting set, without truncating exact matches.
    -- The old CJK fallback appended the entire catalog to every Chinese query.
    local smallest, smallestCount, missing = nil, math.huge, false
    local terms = I.Search.Normalizer:Terms(normalized)
    local queryGrams = {}
    for index = 1, #terms do
        local values = grams(terms[index])
        for gramIndex = 1, #values do
            local gram = values[gramIndex]
            queryGrams[#queryGrams + 1] = gram
            local set = self.grams[gram]
            if not set then missing = true
            elseif not missing then
                local count = type(set) == "string" and 1 or set[0]
                if count < smallestCount then smallest, smallestCount = set, count end
            end
        end
    end
    if not missing then
        if self.previousQuery and self.previousQuery ~= "" and self.previousCandidates and self.previousFilterKey == identity
            and normalized:sub(1, #self.previousQuery) == self.previousQuery and #self.previousCandidates <= smallestCount then
            for _, key in ipairs(self.previousCandidates) do out[#out+1]=key; seen[key]=true end
            self.diagnostics.reusedPrevious = true
        else addCandidates(out, seen, smallest, math.huge) end
        local write, count = 0, #out
        for read = 1, count do
            local key, matches = out[read], true
            for index = 1, #queryGrams do
                local set = self.grams[queryGrams[index]]
                if (type(set) == "string" and set ~= key) or (type(set) == "table" and not set[key]) then matches=false;break end
            end
            if matches then write=write+1;out[write]=key else seen[key]=nil end
        end
        for index = count, write+1, -1 do out[index]=nil end
    end
    -- Fuzzy candidates are bounded separately, so a large prefix never hides
    -- exact matches and unrelated records do not consume the fuzzy budget.
    local fuzzyMaximum = #out + self.fuzzyLimit
    for index = #queryGrams, 1, -1 do
        if #out >= fuzzyMaximum then break end
        addCandidates(out, seen, self.grams[queryGrams[index]], fuzzyMaximum)
    end
    if #out >= self.candidateLimit then diagnose(self, "CANDIDATE_LIMIT") end
    return out, false
end


local function matchesFilter(entry, filter)
    if type(filter) ~= "table" then return true end
    if filter.sourceID and entry.sourceID ~= filter.sourceID then return false end
    if filter.categoryID and entry.categoryID ~= filter.categoryID then return false end
    return true
end

local function resultLess(left, right)
    if left.confidence ~= right.confidence then return left.confidence > right.confidence end
    local le,re=left.entry,right.entry
    local lp,rp=le and le.source.priority or left.sourcePriority,re and re.source.priority or right.sourcePriority
    if lp ~= rp then return lp > rp end
    local lc,rc=le and le.categoryOrder or left.categoryOrder,re and re.categoryOrder or right.categoryOrder
    if lc ~= rc then return lc < rc end
    return (le and le.stableID or left.stableID) < (re and re.stableID or right.stableID)
end

function Index:Search(query, limit, filter, compact)
    local normalized = I.Search.Normalizer:Normalize(query)
    if normalized == "" and type(filter) ~= "table" then return {} end
    local maximum = math.min(tonumber(limit) or self.resultLimit, self.resultLimit)
    if maximum < 1 then return {} end
    local candidates = candidateKeys(self, normalized, filter)
    local queryTerms = I.Search.Normalizer:Terms(normalized)
    local out, byStableID, fuzzyCount = {}, {}, 0
    local started = nowMS()
    local deadline = started and (started + self.fuzzyBudgetMS) or nil
    for candidateIndex = 1, #candidates do
        local entry = self.entries[candidates[candidateIndex]]
        if entry and entry.source.enabled and matchesFilter(entry, filter) then
            local bestScore, bestField, bestText, bestType, bestDistance
            local allTokens = #queryTerms > 1
            if normalized == "" then bestScore, bestField, bestText, bestType = 1, "filter", "", "filter" end
            if allTokens then
                for termIndex = 1, #queryTerms do
                    local tokenFound = false
                    for fieldIndex = 3, #entry.fields, 3 do
                        if entry.fields[fieldIndex]:find(queryTerms[termIndex], 1, true) then tokenFound = true; break end
                    end
                    if not tokenFound then allTokens = false; break end
                end
                if allTokens then bestScore, bestField, bestText, bestType = 0.82, "tokens", normalized, "token" end
            end
            local normalizer = I.Search.Normalizer
            for fieldIndex = 1, #entry.fields, 3 do
                local field, raw, text = entry.fields[fieldIndex], entry.fields[fieldIndex + 1], entry.fields[fieldIndex + 2]
                local confidence, matchType = normalizer:ScoreNormalized(normalized, text, field, false)
                if confidence and (not bestScore or confidence > bestScore or confidence == bestScore and field < bestField) then
                    bestScore, bestField, bestText, bestType = confidence, field, raw, matchType
                end
            end
            if not bestScore or bestScore < 0.56 then
                local currentTime = deadline and nowMS()
                if fuzzyCount >= self.fuzzyLimit then diagnose(self, "FUZZY_CANDIDATE_LIMIT")
                elseif currentTime and currentTime >= deadline then diagnose(self, "FUZZY_TIME_BUDGET")
                else
                    fuzzyCount = fuzzyCount + 1
                    for fieldIndex = 1, #entry.fields, 3 do
                        local field, raw, text = entry.fields[fieldIndex], entry.fields[fieldIndex + 1], entry.fields[fieldIndex + 2]
                        local confidence, matchType, distance = normalizer:ScoreNormalized(normalized, text, field, true)
                        if matchType == "fuzzy" and (not bestScore or confidence > bestScore or confidence == bestScore and field < bestField) then
                            bestScore, bestField, bestText, bestType, bestDistance = confidence, field, raw, matchType, distance
                        end
                    end
                end
            end
            if bestScore then
                local previous = byStableID[entry.stableID]
                local candidate = previous or (#out >= maximum and out[#out])
                local ce=candidate and candidate.entry
                local cp=ce and ce.source.priority or (candidate and candidate.sourcePriority)
                local co=ce and ce.categoryOrder or (candidate and candidate.categoryOrder)
                local cs=ce and ce.stableID or (candidate and candidate.stableID)
                local wins = not candidate or bestScore > candidate.confidence
                    or bestScore == candidate.confidence and (entry.source.priority > cp
                    or entry.source.priority == cp and (entry.categoryOrder < co
                    or entry.categoryOrder == co and entry.stableID < cs))
                if wins then
                    local result, position = previous, #out + 1
                    if previous then
                        for index = 1, #out do if out[index] == previous then position = index; break end end
                    elseif #out >= maximum then
                        result, position = out[#out], #out
                        byStableID[result.entry and result.entry.stableID or result.stableID] = nil
                    else result = {evidence={}} end
                    if compact then
                        -- Query materializes these before any asynchronous boundary.
                        -- Keep the source once instead of duplicating its metadata.
                        result.entry = entry
                    else
                        result.record = entry.record
                        result.item = entry.record.payload or entry.record
                        result.sourceID, result.sourceExtensionID = entry.sourceID, entry.source.extensionID
                        result.sourceTitle = entry.source.title or entry.source.extensionTitle
                        result.sourceGeneration, result.sourceRevision = entry.source.generation, entry.source.revision
                        result.sourcePriority, result.categoryOrder = entry.source.priority, entry.categoryOrder
                        result.stableID = entry.stableID
                    end
                    result.confidence = bestScore
                    local evidence = result.evidence
                    evidence.matchedField, evidence.matchedText, evidence.matchType = bestField, bestText, bestType
                    evidence.confidence, evidence.distance = bestScore, bestDistance
                    out[position], byStableID[entry.stableID] = result, result
                    while position > 1 and resultLess(out[position], out[position-1]) do
                        out[position], out[position-1] = out[position-1], out[position]
                        position = position-1
                    end
                end
            end
        end
    end
    self.diagnostics.lastCandidates = #candidates
    self.previousQuery, self.previousCandidates, self.previousFilterKey = normalized, candidates, filterIdentity(filter)
    return out
end

function Index:Lookup(query, limit)
    local hits, out = self:Search(query, limit), {}
    for index = 1, #hits do out[index] = hits[index].item or hits[index].record end
    return out
end

function Index:GetDiagnostics()
    local out = {}
    for code, count in pairs(self.diagnostics) do out[code] = count end
    return out
end

function Index:BuildSignature()
    local identity = I.Search.RuntimeIdentity
    local sourceSignatures = {}
    for sourceID, source in pairs(self.sources) do
        if sourceID:find(":records", 1, true) or source.extensionID then
            sourceSignatures[#sourceSignatures + 1] = table.concat({ sourceID, source.version, source.revision }, ":")
        end
    end
    table.sort(sourceSignatures)
    local suffix = table.concat(sourceSignatures, ",")
    return identity and identity:BuildSignature(suffix) or suffix
end

function Index:GetSignature()
    return self:BuildSignature()
end

function Index:ExportSnapshot()
    local records, sources = {}, {}
    for sourceID, source in pairs(self.sources) do
        local sourceRecords = {}
        for key in pairs(source.entryKeys) do
            local entry = self.entries[key]
            if entry and entry.record.kind ~= "command" then
                local plain = copyPlain(entry.record)
                if plain then sourceRecords[#sourceRecords + 1] = plain end
            end
        end
        if #sourceRecords > 0 then
            table.sort(sourceRecords, function(left, right) return left.id < right.id end)
            sources[#sources + 1] = {
                id = sourceID, version = source.version, priority = source.priority, scope = copyPlain(source.scope),
                revision = source.revision, enabled = source.enabled, extensionID = source.extensionID,
                title = copyPlain(source.title), extensionTitle = copyPlain(source.extensionTitle),
            }
            records[sourceID] = sourceRecords
        end
    end
    table.sort(sources, function(left, right) return left.id < right.id end)
    return { schema = "lychee-search-snapshot-1", signature = self:BuildSignature(), sources = sources, records = records }
end

function Index:RestoreSnapshot(snapshot)
    if type(snapshot) ~= "table" or snapshot.schema ~= "lychee-search-snapshot-1" then return nil, "SNAPSHOT_SCHEMA" end
    if snapshot.signature ~= self:BuildSignature() then return nil, "SNAPSHOT_SIGNATURE" end
    if type(snapshot.sources) ~= "table" or type(snapshot.records) ~= "table" then return nil, "SNAPSHOT_SCHEMA" end
    local restored = 0
    for index = 1, #snapshot.sources do
        local descriptor = snapshot.sources[index]
        local source = self.sources[descriptor.id]
        if source and source.version == descriptor.version and source.revision == descriptor.revision then
            local records = snapshot.records[descriptor.id]
            if type(records) ~= "table" then return nil, "SNAPSHOT_SCHEMA" end
            for recordIndex = 1, #records do
                local valid = I.Boundary and I.Boundary:ValidateSearchRecord(records[recordIndex], "snapshot.records[" .. recordIndex .. "]", source.extensionID)
                if not valid then return nil, "SNAPSHOT_SCHEMA" end
            end
            clearSourceEntries(self, source)
            for recordIndex = 1, #records do
                local entry = buildEntry(source, records[recordIndex])
                installEntry(self, entry)
                source.entryKeys[entry.key] = true
                restored = restored + 1
            end
        end
    end
    self.version = self.version + 1
    self.previousQuery, self.previousCandidates = nil, nil
    return true, restored
end

function Index:Persist()
    -- Runtime data and executable descriptors are reconstructed by Providers.
    return false
end

function Index:Rebuild()
    local snapshots = {}
    for sourceID, source in pairs(self.sources) do
        snapshots[#snapshots + 1] = { sourceID = sourceID, source = source, records = {} }
        for key in pairs(source.entryKeys) do
            local entry = self.entries[key]
            if entry then snapshots[#snapshots].records[#snapshots[#snapshots].records + 1] = entry.record end
        end
    end
    self.entries, self.exact, self.prefix, self.tokens, self.grams, self.categories = {}, {}, {}, {}, {}, {}
    for index = 1, #snapshots do
        local item = snapshots[index]
        wipeTable(item.source.entryKeys)
        for recordIndex = 1, #item.records do
            local entry = buildEntry(item.source, item.records[recordIndex])
            installEntry(self, entry)
            item.source.entryKeys[entry.key] = true
        end
    end
    self.version = self.version + 1
    self.previousQuery, self.previousCandidates = nil, nil
end

return Index
