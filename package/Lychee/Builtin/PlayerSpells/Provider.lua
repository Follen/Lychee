local I = _G.LycheeInternal
local P = {
    items = {},
    queryBuckets = {},
    extensionID = "builtin.player-spells",
    dirty = true,
}

I.Builtin.PlayerSpells.Provider = P
P.aliasDefinitions = (I.BuiltinData and I.BuiltinData.PlayerSpellAliases) or {}

local function normalize(value)
    return I.Search.Normalizer:Normalize(value)
end

local function codepointStarts(text)
    local starts = {}
    for index = 1, #text do
        local byte = text:byte(index)
        if byte < 128 or byte >= 192 then starts[#starts + 1] = index end
    end
    starts[#starts + 1] = #text + 1
    return starts
end

local function addQueryEntry(buckets, aliasText, spellID)
    local normalized = normalize(aliasText)
    if normalized == "" then return end
    local entry = { text = normalized, spellID = spellID }
    local starts = codepointStarts(normalized)
    local gramSeen = {}
    local count = #starts - 1
    for first = 1, count do
        local last = math.min(count, first + 2)
        for finish = first, last do
            local gram = normalized:sub(starts[first], starts[finish + 1] - 1)
            if not gramSeen[gram] then
                gramSeen[gram] = true
                local bucket = buckets[gram]
                if not bucket then bucket = {}; buckets[gram] = bucket end
                bucket[#bucket + 1] = entry
            end
        end
    end
end

local function addAlias(buckets, alias, spellID)
    local text = I.Search.Normalizer:AliasText(alias)
    if not text then return end
    local locale = type(alias) == "table" and alias.locale
    if locale and locale ~= "default" and locale ~= I.Search.Normalizer.locale then return end
    addQueryEntry(buckets, text, spellID)
end

local function addSpell(items, buckets, aliasDefinitions, spell)
    if type(spell.id) ~= "number" or type(spell.name) ~= "string" or spell.name == "" then return end
    local aliases = spell.aliases or aliasDefinitions[spell.id]
    items[spell.id] = spell
    addAlias(buckets, spell.name, spell.id)
    if type(aliases) == "table" then
        for index = 1, #aliases do addAlias(buckets, aliases[index], spell.id) end
    end
end

local function spellName(spellID, item)
    if type(item) == "table" and type(item.name) == "string" and item.name ~= "" then return item.name end
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

local function commitSnapshot(self, items, buckets, source)
    self.items, self.queryBuckets = items, buckets
    self.lastRefresh, self.lastError, self.dirty = source, nil, false
end

local function refreshFailed(self, code)
    self.lastError, self.dirty = code, true
    return false, code
end

function P:AddSpell(spell)
    addSpell(self.items, self.queryBuckets, self.aliasDefinitions, spell)
end

function P:Clear()
    self.items, self.queryBuckets = {}, {}
end

function P:RefreshFromSpellBook()
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then
        return false, "SPELLBOOK_API_UNAVAILABLE"
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank == nil then return refreshFailed(self, "SPELLBOOK_BANK_UNAVAILABLE") end
    local ok, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or type(count) ~= "number" or count < 0 then
        return refreshFailed(self, "SPELLBOOK_LINES_UNAVAILABLE")
    end

    local nextItems, nextBuckets = {}, {}
    for line = 1, count do
        local lineOK, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if not lineOK or type(info) ~= "table" then return refreshFailed(self, "SPELLBOOK_LINE_READ_FAILED") end
        if not info.shouldHide and not info.isGuild then
            local offset, itemCount = info.itemIndexOffset, info.numSpellBookItems
            if type(offset) ~= "number" or type(itemCount) ~= "number" or itemCount < 0 then
                return refreshFailed(self, "SPELLBOOK_LINE_INVALID")
            end
            local first, last = offset + 1, offset + itemCount
            for slot = first, last do
                local itemOK, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                if not itemOK then return refreshFailed(self, "SPELLBOOK_ITEM_READ_FAILED") end
                if type(item) == "table" and type(item.spellID) == "number" and item.spellID > 0
                    and not item.isPassive and not item.isOffSpec then
                    local name = spellName(item.spellID, item)
                    if not name then return refreshFailed(self, "SPELL_NAME_READ_FAILED") end
                    addSpell(nextItems, nextBuckets, self.aliasDefinitions, {
                        id = item.spellID, name = name, icon = item.iconID,
                        subtext = item.subName, aliases = self.aliasDefinitions[item.spellID],
                    })
                end
            end
        end
    end
    commitSnapshot(self, nextItems, nextBuckets, "spellbook")
    return true
end

function P:RefreshOfflineFixture()
    local items, buckets = {}, {}
    addSpell(items, buckets, self.aliasDefinitions, { id = 31884, name = "Avenging Wrath", subtext = "offline fixture", aliases = self.aliasDefinitions[31884], icon = 135875 })
    addSpell(items, buckets, self.aliasDefinitions, { id = 393256, name = "Teleport: Ruby Life Pools", subtext = "offline fixture", aliases = self.aliasDefinitions[393256] })
    addSpell(items, buckets, self.aliasDefinitions, { id = 373274, name = "Teleport: Mechagon", subtext = "offline fixture", aliases = self.aliasDefinitions[373274] })
    commitSnapshot(self, items, buckets, "offline-fixture")
    return true
end

function P:Refresh()
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then return self:RefreshOfflineFixture() end
    return self:RefreshFromSpellBook()
end

function P:Query(request)
    local raw = type(request) == "table" and (request.text or request.normalized) or request
    local query = normalize(raw or "")
    if query == "" then return {} end
    local starts = codepointStarts(query)
    local count, gramLength = #starts - 1, math.min(#starts - 1, 3)
    local gram = query:sub(starts[1], starts[gramLength + 1] - 1)
    local candidates = self.queryBuckets[gram]
    if not candidates then return {} end

    local out, seen = {}, {}
    for index = 1, #candidates do
        local candidate, spellID = candidates[index], candidates[index].spellID
        if not seen[spellID] and candidate.text:find(query, 1, true) then
            local spell = self.items[spellID]
            if spell then
                seen[spellID] = true
                out[#out + 1] = {
                    id = "spell-" .. spellID, text = spell.name, subtext = spell.subtext, icon = spell.icon,
                    payload = { spellID = spellID },
                    interaction = {
                        primaryActionID = "open-detail",
                        actions = {
                            { id = "open-detail", title = "查看详情", kind = "intent" },
                            { id = "cast", title = "施放", kind = "secure-spell", spellID = spellID },
                        },
                        drag = { type = "spell", spellID = spellID },
                    },
                }
            end
        end
    end
    table.sort(out, function(left, right) return left.id < right.id end)
    return out
end
