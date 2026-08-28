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
    if not set then set = {}; map[key] = set end
    set[entryKey] = true
end

local function removeSet(map, key, entryKey)
    local set = key and map[key]
    if not set then return end
    set[entryKey] = nil
    if not next(set) then map[key] = nil end
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

local function prefixes(text)
    local starts, out = codepoints(text), {}
    local count = #starts - 1
    for finish = 1, math.min(count, 32) do out[#out + 1] = text:sub(starts[1], starts[finish + 1] - 1) end
    return out
end

local function grams(text)
    local starts, out, seen = codepoints(text), {}, {}
    local count = #starts - 1
    for size = 1, 3 do
        if count >= size then
            for first = 1, count - size + 1 do
                local gram = text:sub(starts[first], starts[first + size] - 1)
                if not seen[gram] then seen[gram] = true; out[#out + 1] = gram end
            end
        end
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
            entry.fields[#entry.fields + 1] = { field = field, text = raw, normalized = normalized }
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
        stableID = record.id,
        fields = {},
        memberships = {},
        membershipSeen = {},
        categoryID = categoryID(record),
        categoryOrder = categoryOrder(record),
    }
    addText(entry, "title", record.title, record.scope or source.scope)
    addText(entry, "alias", record.aliases, record.scope or source.scope)
    addText(entry, "keyword", record.keywords, record.scope or source.scope)
    addText(entry, "description", record.description, record.scope or source.scope)
    local category = record.category
    addText(entry, "category", type(category) == "table" and (category.title or category.id) or category, record.scope or source.scope)
    return entry
end

local function remember(self, entry, mapName, value)
    local membershipKey = mapName .. "\0" .. value
    if entry.membershipSeen[membershipKey] then return end
    entry.membershipSeen[membershipKey] = true
    addSet(self[mapName], value, entry.key)
    entry.memberships[#entry.memberships + 1] = { mapName, value }
end

local function installEntry(self, entry)
    self.entries[entry.key] = entry
    local seen = {}
    for index = 1, #entry.fields do
        local field = entry.fields[index]
        local identity = field.field .. "\0" .. field.normalized
        if not seen[identity] then
            seen[identity] = true
            remember(self, entry, "exact", field.normalized)
            local prefixValues = prefixes(field.normalized)
            for prefixIndex = 1, #prefixValues do remember(self, entry, "prefix", prefixValues[prefixIndex]) end
            local terms = I.Search.Normalizer:Terms(field.normalized)
            for termIndex = 1, #terms do remember(self, entry, "tokens", terms[termIndex]) end
            local gramValues = grams(field.normalized)
            for gramIndex = 1, #gramValues do remember(self, entry, "grams", gramValues[gramIndex]) end
        end
    end
    if entry.categoryID then remember(self, entry, "categories", I.Search.Normalizer:Normalize(entry.categoryID)) end
end

local function removeEntry(self, entry)
    if not entry then return end
    for index = 1, #entry.memberships do
        local membership = entry.memberships[index]
        removeSet(self[membership[1]], membership[2], entry.key)
    end
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
    self.previousQuery, self.previousCandidates = nil, nil
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
    return setmetatable(value, { __index = self })
end

function Index:OnChange(callback)
    if type(callback) ~= "function" then return false end
    self.listeners[#self.listeners + 1] = callback
    return true
end

function Index:Clear()
    self.sources, self.entries = {}, {}
    self.exact, self.prefix, self.tokens, self.grams, self.categories = {}, {}, {}, {}, {}
    self.previousQuery, self.previousCandidates = nil, nil
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
    clearSourceEntries(self, source)
    local ids = {}
    for recordID in pairs(nextRecords) do ids[#ids + 1] = recordID end
    table.sort(ids)
    for index = 1, #ids do
        local entry = buildEntry(source, nextRecords[ids[index]])
        installEntry(self, entry)
        source.entryKeys[entry.key] = true
    end
    source.pending = nil
    local nextRevision, nextGeneration = bump(self, source, revision, "snapshot")
    self:Persist()
    return true, nextGeneration, nextRevision
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
    source.invalidation[tostring(key or "*")] = true
    local revision, generation = bump(self, source, nil, "invalidated")
    return true, generation, revision
end

function Index:GetSourceState(sourceID)
    local source = self.sources[sourceID]
    if not source then return nil end
    return { id = source.id, revision = source.revision, generation = source.generation, enabled = source.enabled }
end

local function addCandidates(out, seen, set, maximum)
    if not set then return false end
    for key in pairs(set) do
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = key
            if #out >= maximum then return true end
        end
    end
    return false
end

local function candidateKeys(self, normalized)
    local out, seen = {}, {}
    if self.previousQuery and self.previousCandidates and normalized:sub(1, #self.previousQuery) == self.previousQuery then
        for index = 1, #self.previousCandidates do
            local key = self.previousCandidates[index]
            if self.entries[key] then seen[key] = true; out[#out + 1] = key end
        end
        self.diagnostics.reusedPrevious = true
        return out, true
    end
    addCandidates(out, seen, self.exact[normalized], self.candidateLimit)
    if #out < self.candidateLimit then addCandidates(out, seen, self.prefix[normalized], self.candidateLimit) end
    local terms = I.Search.Normalizer:Terms(normalized)
    for index = 1, #terms do
        if #out >= self.candidateLimit then break end
        addCandidates(out, seen, self.tokens[terms[index]], self.candidateLimit)
    end
    local gramValues = grams(normalized)
    for index = 1, #gramValues do
        if #out >= self.candidateLimit then break end
        addCandidates(out, seen, self.grams[gramValues[index]], self.candidateLimit)
    end
    if #out >= self.candidateLimit then diagnose(self, "CANDIDATE_LIMIT") end
    return out, false
end

local function better(left, right)
    if not right then return true end
    if left.confidence ~= right.confidence then return left.confidence > right.confidence end
    return tostring(left.evidence.matchedField) < tostring(right.evidence.matchedField)
end

local function resultLess(left, right)
    if left.confidence ~= right.confidence then return left.confidence > right.confidence end
    if left.sourcePriority ~= right.sourcePriority then return left.sourcePriority > right.sourcePriority end
    if left.categoryOrder ~= right.categoryOrder then return left.categoryOrder < right.categoryOrder end
    return left.stableID < right.stableID
end

function Index:Search(query, limit)
    local normalized = I.Search.Normalizer:Normalize(query)
    if normalized == "" then return {} end
    local maximum = math.min(tonumber(limit) or self.resultLimit, self.resultLimit)
    local candidates = candidateKeys(self, normalized)
    local queryTerms = I.Search.Normalizer:Terms(normalized)
    local out, byStableID, fuzzyCount = {}, {}, 0
    local started = nowMS()
    local deadline = started and (started + self.fuzzyBudgetMS) or nil
    for candidateIndex = 1, #candidates do
        local entry = self.entries[candidates[candidateIndex]]
        if entry and entry.source.enabled then
            local best
            local allTokens = #queryTerms > 1
            if allTokens then
                for termIndex = 1, #queryTerms do
                    local tokenFound = false
                    for fieldIndex = 1, #entry.fields do
                        if entry.fields[fieldIndex].normalized:find(queryTerms[termIndex], 1, true) then tokenFound = true; break end
                    end
                    if not tokenFound then allTokens = false; break end
                end
                if allTokens then best = { confidence = 0.82, evidence = { matchedField = "tokens", matchedText = normalized, matchType = "token" } } end
            end
            for fieldIndex = 1, #entry.fields do
                local field = entry.fields[fieldIndex]
                local exactEvidence = I.Search.Normalizer:MatchText(normalized, field.text, field.field, { allowFuzzy = false })
                if exactEvidence then
                    local hit = { confidence = exactEvidence.confidence, evidence = exactEvidence }
                    if better(hit, best) then best = hit end
                end
            end
            if not best or best.confidence < 0.56 then
                if fuzzyCount >= self.fuzzyLimit then diagnose(self, "FUZZY_CANDIDATE_LIMIT")
                elseif deadline and nowMS() and nowMS() >= deadline then diagnose(self, "FUZZY_TIME_BUDGET")
                else
                    fuzzyCount = fuzzyCount + 1
                    for fieldIndex = 1, #entry.fields do
                        local field = entry.fields[fieldIndex]
                        local fuzzyEvidence = I.Search.Normalizer:MatchText(normalized, field.text, field.field, { allowFuzzy = true })
                        if fuzzyEvidence and fuzzyEvidence.matchType == "fuzzy" then
                            local hit = { confidence = fuzzyEvidence.confidence, evidence = fuzzyEvidence }
                            if better(hit, best) then best = hit end
                        end
                    end
                end
            end
            if best then
                local result = {
                    record = entry.record,
                    item = entry.record.payload or entry.record,
                    sourceID = entry.sourceID,
                    sourceExtensionID = entry.source.extensionID,
                    sourcePriority = entry.source.priority,
                    categoryOrder = entry.categoryOrder,
                    stableID = entry.stableID,
                    confidence = best.confidence,
                    evidence = best.evidence,
                    sourceGeneration = entry.source.generation,
                    sourceRevision = entry.source.revision,
                }
                local previous = byStableID[result.stableID]
                if not previous then out[#out + 1] = result; byStableID[result.stableID] = result
                elseif resultLess(result, previous) then
                    for resultIndex = 1, #out do if out[resultIndex] == previous then out[resultIndex] = result; break end end
                    byStableID[result.stableID] = result
                end
            end
        end
    end
    table.sort(out, resultLess)
    while #out > maximum do out[#out] = nil end
    self.previousQuery, self.previousCandidates = normalized, candidates
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
    if type(LycheeDB) ~= "table" then return false end
    LycheeDB.searchIndex = self:ExportSnapshot()
    return true
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
