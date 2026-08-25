local I = _G.LycheeInternal
local Index = { buckets = {}, entries = {}, version = 0 }
I.Search.StaticIndex = Index

local function codepointStarts(text)
    local starts = {}
    for index = 1, #text do
        local byte = text:byte(index)
        if byte < 128 or byte >= 192 then starts[#starts + 1] = index end
    end
    starts[#starts + 1] = #text + 1
    return starts
end

local function indexText(self, text, entry)
    local normalized = I.Search.Normalizer:Normalize(text)
    if normalized == "" then return end
    entry.texts[#entry.texts + 1] = normalized
    local starts, count = codepointStarts(normalized), 0
    count = #starts - 1
    local seen = {}
    for first = 1, count do
        local last = math.min(count, first + 2)
        for finish = first, last do
            local gram = normalized:sub(starts[first], starts[finish + 1] - 1)
            if not seen[gram] then
                seen[gram] = true
                local bucket = self.buckets[gram]
                if not bucket then bucket = {}; self.buckets[gram] = bucket end
                bucket[#bucket + 1] = entry
            end
        end
    end
end

function Index:New()
    return setmetatable({ buckets = {}, entries = {}, version = 0 }, { __index = self })
end

function Index:Clear()
    self.buckets, self.entries = {}, {}
    self.version = self.version + 1
end

function Index:Add(key, item, fields)
    fields = fields or {}
    local entry = { key = key, item = item, texts = {} }
    self.entries[key] = entry
    indexText(self, item.title or item.text, entry)
    local collections = { fields.aliases, fields.keywords }
    for collectionIndex = 1, #collections do
        local collection = collections[collectionIndex]
        if type(collection) == "table" then
            for index = 1, #collection do
                local alias = collection[index]
                local locale = type(alias) == "table" and alias.locale
                if not locale or locale == "default" or locale == I.Search.Normalizer.locale then
                    local text = I.Search.Normalizer:AliasText(alias)
                    if text then indexText(self, text, entry) end
                end
            end
        end
    end
    self.version = self.version + 1
end

function Index:Lookup(query, limit)
    local normalized = I.Search.Normalizer:Normalize(query)
    if normalized == "" then return {} end
    local starts = codepointStarts(normalized)
    local gramLength = math.min(#starts - 1, 3)
    local gram = normalized:sub(starts[1], starts[gramLength + 1] - 1)
    local candidates = self.buckets[gram]
    if not candidates then return {} end
    local out, seen, maximum = {}, {}, limit or 20
    for index = 1, #candidates do
        local entry = candidates[index]
        if not seen[entry.key] then
            for textIndex = 1, #entry.texts do
                if entry.texts[textIndex]:find(normalized, 1, true) then
                    seen[entry.key] = true
                    out[#out + 1] = entry.item
                    break
                end
            end
            if #out >= maximum then break end
        end
    end
    return out
end
