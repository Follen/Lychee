local I = _G.LycheeInternal
I.Search = I.Search or {}
local N = { locale = (GetLocale and GetLocale()) or "enUS", cache = {} }
I.Search.Normalizer = N

local function lower(value) return string.lower(tostring(value or "")) end

function N:Normalize(value)
    local raw = lower(value)
    local cached = self.cache[raw]
    if cached then return cached end
    -- Lua 5.1's locale-aware %p can classify UTF-8 bytes as punctuation.
    -- Normalize only ASCII punctuation/control bytes so Chinese text survives.
    local buffer = {}
    for index = 1, #raw do
        local byte = raw:byte(index)
        if byte <= 32 or byte == 127 or (byte >= 33 and byte <= 47)
            or (byte >= 58 and byte <= 64) or (byte >= 91 and byte <= 96)
            or (byte >= 123 and byte <= 126) then
            buffer[#buffer + 1] = " "
        else
            buffer[#buffer + 1] = raw:sub(index, index)
        end
    end
    local normalized = table.concat(buffer):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    self.cache[raw] = normalized
    return normalized
end

function N:Terms(value)
    local out = {}
    for token in self:Normalize(value):gmatch("%S+") do out[#out + 1] = token end
    return out
end

function N:AliasText(alias)
    if type(alias) == "table" then return alias.text or alias.title or alias.default end
    return alias
end

function N:Localized(value, scope)
    local out = {}
    if type(value) == "string" then
        out[1] = { text = value, locale = "default", scope = scope }
    elseif type(value) == "table" then
        if value.text or value.title then
            out[1] = { text = self:AliasText(value), locale = value.locale or "default", scope = value.scope or scope }
        elseif value.default or value.zhCN or value.enUS then
            for locale, text in pairs(value) do
                if type(text) == "string" then out[#out + 1] = { text = text, locale = locale, scope = scope } end
            end
        else
            for index = 1, #value do
                local entry = value[index]
                if type(entry) == "string" then out[#out + 1] = { text = entry, locale = "default", scope = scope }
                elseif type(entry) == "table" and self:AliasText(entry) then
                    out[#out + 1] = { text = self:AliasText(entry), locale = entry.locale or "default", scope = entry.scope or scope }
                end
            end
        end
    end
    return out
end

local function boundedDistance(left, right, ceiling)
    if math.abs(#left - #right) > ceiling then return ceiling + 1 end
    local previous, current = {}, {}
    for column = 0, #right do previous[column] = column end
    for row = 1, #left do
        current[0] = row
        local minimum = current[0]
        for column = 1, #right do
            local cost = left:sub(row, row) == right:sub(column, column) and 0 or 1
            local value = math.min(current[column - 1] + 1, previous[column] + 1, previous[column - 1] + cost)
            current[column] = value
            if value < minimum then minimum = value end
        end
        if minimum > ceiling then return ceiling + 1 end
        previous, current = current, previous
    end
    return previous[#right] or ceiling + 1
end

local FIELD_SCORES = {
    title = { exact = 1.00, prefix = 0.90, substring = 0.74, fuzzy = 0.44 },
    alias = { exact = 0.98, prefix = 0.86, substring = 0.72, fuzzy = 0.42 },
    category = { exact = 0.80, prefix = 0.78, substring = 0.76, fuzzy = 0.40 },
    keyword = { exact = 0.62, prefix = 0.60, substring = 0.58, fuzzy = 0.38 },
    description = { exact = 0.48, prefix = 0.47, substring = 0.46, fuzzy = 0.30 },
}

local function score(field, matchType, distance)
    local scores = FIELD_SCORES[field] or FIELD_SCORES.title
    local value = scores[matchType]
    if matchType == "fuzzy" then
        value = value - math.max(0, tonumber(distance) or 0) * 0.04
        return math.max(0.30, value)
    end
    return value
end

function N:MatchText(query, text, field, options)
    options = options or {}
    local normalizedQuery, normalizedText = self:Normalize(query), self:Normalize(text)
    if normalizedQuery == "" or normalizedText == "" then return nil end
    field = field or "title"
    local evidence = { matchedField = field, matchedText = text }
    if normalizedText == normalizedQuery then evidence.matchType, evidence.confidence = "exact", score(field, "exact"); return evidence end
    if normalizedText:sub(1, #normalizedQuery) == normalizedQuery then evidence.matchType, evidence.confidence = "prefix", score(field, "prefix"); return evidence end
    if normalizedText:find(normalizedQuery, 1, true) then evidence.matchType, evidence.confidence = "substring", score(field, "substring"); return evidence end
    if options.allowFuzzy ~= false and #normalizedQuery <= 32 and #normalizedText <= 64 then
        local ceiling = tonumber(options.fuzzyDistance) or 2
        local distance = boundedDistance(normalizedQuery, normalizedText, ceiling)
        if distance <= ceiling then
            evidence.matchType = "fuzzy"
            evidence.confidence = score(field, "fuzzy", distance)
            evidence.distance = distance
            return evidence
        end
    end
    return nil
end

function N:MatchFields(query, title, aliases, keywords)
    local fields = { { value = title, name = "title" }, { value = aliases, name = "alias" }, { value = keywords, name = "keyword" } }
    for index = 1, #fields do
        local field = fields[index]
        local entries = self:Localized(field.value)
        for entryIndex = 1, #entries do
            local entry = entries[entryIndex]
            local identity = I.Search.RuntimeIdentity
            if (not identity or identity:MatchesScope(nil, entry)) and (entry.locale == "default" or entry.locale == self.locale) then
                if self:MatchText(query, entry.text, field.name) then return true end
            end
        end
    end
    return false
end
