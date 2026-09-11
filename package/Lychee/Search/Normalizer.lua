local I = _G.LycheeInternal
I.Search = I.Search or {}
local N = { locale = (GetLocale and GetLocale()) or "enUS", cache = {}, cacheKeys = {}, cacheCursor = 0, cacheLimit = 1024, cacheTextLimit = 256 }
I.Search.Normalizer = N

local function lower(value) return string.lower(tostring(value or "")) end

function N:IsBlank(value)
    return not tostring(value or ""):find("%S")
end

function N:Normalize(value)
    local raw = lower(value)
    local cacheable = #raw <= self.cacheTextLimit
    local cached = cacheable and self.cache[raw]
    if cached then return cached end
    -- Lua 5.1's locale-aware %p can classify UTF-8 bytes as punctuation.
    -- Normalize only ASCII punctuation/control bytes so Chinese text survives.
    -- Explicit byte ranges preserve UTF-8 and avoid a table/string per byte.
    local normalized = raw:gsub("[%z\1-\47\58-\64\91-\96\123-\127]+", " ")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    -- Long descriptions remain searchable without retaining arbitrary text.
    -- At most 1024 keys plus values of <=256 bytes: <=512 KiB of text payload.
    if not cacheable then return normalized end
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

function N:LocaleRank(locale)
    if locale==self.locale then return 1 end
    if (self.locale=="zhTW" and locale=="zhCN") or (self.locale=="enGB" and locale=="enUS") then return 2 end
    if locale==nil or locale=="default" then return 3 end
    if locale=="enUS" then return 4 end
end
function N:Display(value,fallback)
    if type(value)=="string" then return value end
    if type(value)~="table" then return fallback or "" end
    local best,rank
    for _,entry in ipairs(self:Localized(value)) do
        local candidate=self:LocaleRank(entry.locale)
        local identity=I.Search.RuntimeIdentity
        if candidate and (not rank or candidate<rank) and (not identity or identity:MatchesScope(nil,entry)) then best,rank=entry.text,candidate end
    end
    return best or fallback or ""
end

function N:Localized(value, scope)
    local out = {}
    if type(value) == "string" then
        out[1] = { text = value, locale = "default", scope = scope }
    elseif type(value) == "table" then
        if value.text or value.title then
            out[1] = { text = self:AliasText(value), locale = value.locale or "default", scope = value.scope or scope }
        elseif value.default or value.zhCN or value.zhTW or value.enUS or value.enGB then
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

local function letter(byte) return byte and byte>=97 and byte<=122 end
local function shortFirstTerm(query)
    local a,b,c=query:byte(1,3)
    return letter(a) and (not b or b==32 or letter(b) and (not c or c==32))
end
local function hasShortTerm(query)
    local first=1
    while first<=#query do
        local last=query:find(" ",first,true) or (#query+1)
        local length=last-first
        if length==1 and letter(query:byte(first)) or length==2 and letter(query:byte(first)) and letter(query:byte(first+1)) then return true end
        first=last+1
    end
    return false
end
-- Shared literal seam for normalized scoring and original-text highlighting.
-- ASCII alphanumerics and UTF-8 bytes continue a word; whitespace/punctuation do not.
function N:FindLiteral(query,text,start)
    local first,last=text:find(query,start or 1,true)
    if not shortFirstTerm(query) then return first,last end
    while first do
        local before=first>1 and text:byte(first-1)
        if not before or before<128 and not letter(before) and not (before>=48 and before<=57) then return first,last end
        first,last=text:find(query,first+1,true)
    end
end

-- The index already owns normalized fields. Scoring its candidates must not
-- allocate evidence/options tables for every failed field comparison.
function N:ScoreNormalized(normalizedQuery, normalizedText, field, allowFuzzy, fuzzyDistance)
    if normalizedQuery == "" or normalizedText == "" then return nil end
    field = field or "title"
    if normalizedText == normalizedQuery then return score(field, "exact"), "exact" end
    local position = self:FindLiteral(normalizedQuery, normalizedText)
    if position == 1 then return score(field, "prefix"), "prefix" end
    if position then return score(field, "substring"), "substring" end
    if allowFuzzy ~= false and #normalizedQuery <= 32 and #normalizedText <= 64 and not hasShortTerm(normalizedQuery) then
        local ceiling = tonumber(fuzzyDistance) or 2
        local distance = boundedDistance(normalizedQuery, normalizedText, ceiling)
        if distance <= ceiling then
            return score(field, "fuzzy", distance), "fuzzy", distance
        end
    end
    return nil
end

-- Compiled fields are flat {field, original, normalized} triples. The same
-- scorer serves indexed records and bounded dynamic-record adapters.
function N:ScoreCompiled(query,fields,terms,allowFuzzy)
    local best,matchedField,matchedText,kind,distance
    if terms and #terms>1 then
        local weakest=1
        for _,term in ipairs(terms) do
            local strongest
            for offset=1,#fields,3 do
                local value=self:ScoreNormalized(term,fields[offset+2],fields[offset],false)
                if value and (not strongest or value>strongest) then strongest=value end
            end
            if not strongest then weakest=nil;break end
            weakest=math.min(weakest,strongest)
        end
        if weakest then best,matchedField,matchedText,kind=weakest*0.9,"tokens",query,"token" end
    end
    for offset=1,#fields,3 do
        local field,raw,text=fields[offset],fields[offset+1],fields[offset+2]
        local value,matchType,edits=self:ScoreNormalized(query,text,field,allowFuzzy)
        if value and (not best or value>best or value==best and field<matchedField) then
            best,matchedField,matchedText,kind,distance=value,field,raw,matchType,edits
        end
    end
    return best,matchedField,matchedText,kind,distance
end
-- Compile directly into caller-owned triples. Localized remains the public
-- materializing helper; indexing and dynamic matching do not need its copies.
local emptyScope = {}
local function appendField(self,fields,field,raw,locale,entryScope,scope)
    if not self:LocaleRank(locale) then return end
    local identity=I.Search.RuntimeIdentity
    if identity then
        if not identity:MatchesScope(scope or emptyScope,emptyScope) then return end
        if entryScope and entryScope~=scope and not identity:MatchesScope(entryScope,emptyScope) then return end
    end
    local text=self:Normalize(raw)
    if text~="" then local n=#fields;fields[n+1],fields[n+2],fields[n+3]=field,raw,text end
end
function N:AppendFields(fields,field,value,scope)
    if type(value)=="string" then
        appendField(self,fields,field,value,"default",scope,scope)
    elseif type(value)=="table" then
        if value.text or value.title then
            appendField(self,fields,field,self:AliasText(value),value.locale or "default",value.scope or scope,scope)
        elseif value.default or value.zhCN or value.zhTW or value.enUS or value.enGB then
            for locale,raw in pairs(value) do
                if type(raw)=="string" then appendField(self,fields,field,raw,locale,scope,scope) end
            end
        else
            for index=1,#value do
                local entry=value[index]
                if type(entry)=="string" then appendField(self,fields,field,entry,"default",scope,scope)
                elseif type(entry)=="table" and self:AliasText(entry) then
                    appendField(self,fields,field,self:AliasText(entry),entry.locale or "default",entry.scope or scope,scope)
                end
            end
        end
    end
end
function N:MatchRecord(query,record,scope)
    local normalized=self:Normalize(query);local fields={};scope=record.scope or scope
    self:AppendFields(fields,"title",record.title,scope);self:AppendFields(fields,"alias",record.aliases,scope)
    self:AppendFields(fields,"keyword",record.keywords,scope);self:AppendFields(fields,"description",record.description,scope)
    local category=record.category;self:AppendFields(fields,"category",type(category)=="table" and (category.title or category.id) or category,scope)
    local confidence,field,text,kind=self:ScoreCompiled(normalized,fields,self:Terms(normalized),false)
    if confidence then return {confidence=confidence,matchedField=field,matchedText=text,matchType=kind} end
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
            if (not identity or identity:MatchesScope(nil, entry)) and self:LocaleRank(entry.locale) then
                if self:MatchText(query, entry.text, field.name) then return true end
            end
        end
    end
    return false
end
