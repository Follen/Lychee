local I = _G.LycheeInternal
I.Search = I.Search or {}
local N = { locale = (GetLocale and GetLocale()) or "enUS", cache = {}, cacheKeys = {}, cacheCursor = 0, cacheLimit = 1024 }
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
    local slot = self.cacheCursor % self.cacheLimit + 1
    local previous = self.cacheKeys[slot]
    if previous then self.cache[previous] = nil end
    self.cacheKeys[slot], self.cacheCursor = raw, slot
    self.cache[raw] = normalized
    return normalized
end

function N:ClearCache()
    self.cache, self.cacheKeys, self.cacheCursor = {}, {}, 0
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

local distanceA, distanceB = {}, {}
local function boundedDistance(left, right, ceiling)
    local leftEnd, rightEnd, first = #left, #right, 1
    if math.abs(leftEnd - rightEnd) > ceiling then return ceiling + 1 end
    while first <= leftEnd and first <= rightEnd and left:byte(first) == right:byte(first) do first = first + 1 end
    while leftEnd >= first and rightEnd >= first and left:byte(leftEnd) == right:byte(rightEnd) do
        leftEnd, rightEnd = leftEnd - 1, rightEnd - 1
    end
    local rows, columns = leftEnd-first+1, rightEnd-first+1
    if rows == 0 then return columns end
    if columns == 0 then return rows end
    local previous, current, infinity = distanceA, distanceB, ceiling+1
    for column = 0, columns do previous[column] = column <= ceiling and column or infinity end
    for row = 1, rows do
        local low, high = math.max(1, row-ceiling), math.min(columns, row+ceiling)
        current[0] = row <= ceiling and row or infinity
        if low > 1 then current[low-1] = infinity end
        current[high+1] = infinity
        local minimum = infinity
        local leftByte = left:byte(first+row-1)
        for column = low, high do
            local cost = leftByte == right:byte(first+column-1) and 0 or 1
            local value = math.min(current[column-1]+1, previous[column]+1, previous[column-1]+cost)
            current[column] = value
            if value < minimum then minimum = value end
        end
        if minimum > ceiling then return infinity end
        previous, current = current, previous
    end
    return previous[columns]
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

-- The index already owns normalized fields. Scoring its candidates must not
-- allocate evidence/options tables for every failed field comparison.
function N:ScoreNormalized(normalizedQuery, normalizedText, field, allowFuzzy, fuzzyDistance)
    if normalizedQuery == "" or normalizedText == "" then return nil end
    field = field or "title"
    if normalizedText == normalizedQuery then return score(field, "exact"), "exact" end
    local position = normalizedText:find(normalizedQuery, 1, true)
    if position == 1 then return score(field, "prefix"), "prefix" end
    if position then return score(field, "substring"), "substring" end
    if allowFuzzy ~= false and #normalizedQuery <= 32 and #normalizedText <= 64 then
        local ceiling = tonumber(fuzzyDistance) or 2
        local distance = boundedDistance(normalizedQuery, normalizedText, ceiling)
        if distance <= ceiling then
            return score(field, "fuzzy", distance), "fuzzy", distance
        end
    end
    return nil
end

function N:MatchText(query, text, field, options)
    local confidence, matchType, distance = self:ScoreNormalized(self:Normalize(query), self:Normalize(text),
        field, not options or options.allowFuzzy, options and options.fuzzyDistance)
    if confidence then return {matchedField=field or "title",matchedText=text,confidence=confidence,matchType=matchType,distance=distance} end
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
