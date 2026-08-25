local I = _G.LycheeInternal
local P = { items = {}, queryBuckets = {}, extensionID = "builtin.dungeon-guide" }
I.Builtin.DungeonGuide = P

local function codepointStarts(text)
    local starts = {}
    for index = 1, #text do
        local byte = text:byte(index)
        if byte < 128 or byte >= 192 then starts[#starts + 1] = index end
    end
    starts[#starts + 1] = #text + 1
    return starts
end

local function addAlias(buckets, alias, id)
    if type(alias) == "table" and alias.locale and alias.locale ~= "default"
        and alias.locale ~= I.Search.Normalizer.locale then return end
    alias = I.Search.Normalizer:AliasText(alias)
    if not alias then return end
    local normalized = I.Search.Normalizer:Normalize(alias)
    if normalized == "" then return end

    local entry = { text = normalized, id = id }
    local starts, seen = codepointStarts(normalized), {}
    local count = #starts - 1
    for first = 1, count do
        local last = math.min(count, first + 2)
        for finish = first, last do
            local gram = normalized:sub(starts[first], starts[finish + 1] - 1)
            if not seen[gram] then
                seen[gram] = true
                local bucket = buckets[gram]
                if not bucket then bucket = {}; buckets[gram] = bucket end
                bucket[#bucket + 1] = entry
            end
        end
    end
end

function P:Add(item)
    self.items[item.id] = item
    addAlias(self.queryBuckets, item.name, item.id)
    for index = 1, #(item.aliases or {}) do addAlias(self.queryBuckets, item.aliases[index], item.id) end
    for index = 1, #(item.skills or {}) do addAlias(self.queryBuckets, item.skills[index], item.id) end
end

function P:Query(request)
    local raw = type(request) == "table" and (request.text or request.normalized) or request
    local query = I.Search.Normalizer:Normalize(raw or "")
    if query == "" then return {} end
    local starts = codepointStarts(query)
    local gramLength = math.min(#starts - 1, 3)
    local gram = query:sub(starts[1], starts[gramLength + 1] - 1)
    local candidates = self.queryBuckets[gram]
    if not candidates then return {} end

    local out, seen = {}, {}
    for index = 1, #candidates do
        local candidate = candidates[index]
        if not seen[candidate.id] and candidate.text:find(query, 1, true) then
            local item = self.items[candidate.id]
            if item then
                seen[candidate.id] = true
                out[#out + 1] = {
                    id = "creature-" .. candidate.id,
                    text = item.name,
                    subtext = item.subtext,
                    icon = item.icon,
                    payload = { creatureID = candidate.id },
                }
            end
        end
    end
    table.sort(out, function(left, right) return left.id < right.id end)
    return out
end
