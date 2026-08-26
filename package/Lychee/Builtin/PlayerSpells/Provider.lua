local I = _G.LycheeInternal
local P = {
    items = {},
    queryBuckets = {},
    extensionID = "builtin.player-spells",
    dirty = true,
    descriptionRequests = {},
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
    addAlias(buckets, spell.description, spell.id)
    if type(aliases) == "table" then
        for index = 1, #aliases do addAlias(buckets, aliases[index], spell.id) end
    end
end

local function usableText(value)
    if type(value) ~= "string" or value == "" then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    return value
end

local function spellDescription(self, spellID)
    if not C_Spell or type(C_Spell.GetSpellDescription) ~= "function" then return nil end
    local ok, description = pcall(C_Spell.GetSpellDescription, spellID)
    description = ok and usableText(description) or nil
    if description then return description end
    if type(C_Spell.RequestLoadSpellData) == "function" and not self.descriptionRequests[spellID] then
        self.descriptionRequests[spellID] = true
        pcall(C_Spell.RequestLoadSpellData, spellID)
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

local function knownToPlayer(spellID)
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known == true then return true end
    end
    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        if bank ~= nil then
            local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
            if ok and known == true then return true end
        end
    end
    return false
end

local function addKnownAliasSpells(self, items, buckets, aliasDefinitions)
    if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then return end
    for spellID in pairs(aliasDefinitions) do
        if not items[spellID] and knownToPlayer(spellID) then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                addSpell(items, buckets, aliasDefinitions, {
                    id = spellID, name = info.name, icon = info.iconID,
                    subtext = info.subName, aliases = aliasDefinitions[spellID],
                    description = spellDescription(self, spellID),
                })
            end
        end
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
    local readableItems = 0
    for line = 1, count do
        local lineOK, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if lineOK and type(info) == "table" and not info.shouldHide and not info.isGuild then
            local offset, itemCount = info.itemIndexOffset, info.numSpellBookItems
            if type(offset) == "number" and type(itemCount) == "number" and itemCount >= 0 then
                local first, last = offset + 1, offset + itemCount
                for slot = first, last do
                    local itemOK, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if itemOK then readableItems = readableItems + 1 end
                    if itemOK and type(item) == "table" and type(item.spellID) == "number" and item.spellID > 0
                        and not item.isPassive and not item.isOffSpec then
                        local name = spellName(item.spellID, item)
                        if name then
                            addSpell(nextItems, nextBuckets, self.aliasDefinitions, {
                                id = item.spellID, name = name, icon = item.iconID,
                                subtext = item.subName, aliases = self.aliasDefinitions[item.spellID],
                                description = spellDescription(self, item.spellID),
                            })
                        end
                    end
                end
            end
        end
    end
    -- A known utility/teleport spell can be omitted from a visible skill line.
    addKnownAliasSpells(self, nextItems, nextBuckets, self.aliasDefinitions)
    if readableItems == 0 and next(nextItems) == nil then
        return refreshFailed(self, "SPELLBOOK_ITEMS_UNAVAILABLE")
    end
    commitSnapshot(self, nextItems, nextBuckets, "spellbook")
    return true
end

function P:RefreshOfflineFixture()
    local items, buckets = {}, {}
    addSpell(items, buckets, self.aliasDefinitions, { id = 31884, name = "Avenging Wrath", subtext = "offline fixture", aliases = self.aliasDefinitions[31884], icon = 135875 })
    addSpell(items, buckets, self.aliasDefinitions, { id = 393256, name = "利爪防御者之路", description = "传送至红玉新生法池入口。", subtext = "offline fixture", aliases = self.aliasDefinitions[393256] })
    addSpell(items, buckets, self.aliasDefinitions, { id = 373274, name = "Teleport: Mechagon", subtext = "offline fixture", aliases = self.aliasDefinitions[373274] })
    commitSnapshot(self, items, buckets, "offline-fixture")
    return true
end

function P:ClearDescriptionRequest(spellID)
    if type(spellID) == "number" then self.descriptionRequests[spellID] = nil end
end

function P:BuildSearchRecords()
    local records, ids = {}, {}
    for spellID in pairs(self.items) do ids[#ids + 1] = spellID end
    table.sort(ids)
    for index = 1, #ids do
        local spellID, spell = ids[index], self.items[ids[index]]
        if type(spell) == "table" and type(spell.name) == "string" and spell.name ~= "" then
            records[#records + 1] = {
                id = "spell:" .. tostring(spellID),
                kind = "spell",
                category = { id = "spells", title = { default = "Spells", zhCN = "技能" }, order = 10 },
                title = spell.name,
                aliases = spell.aliases or self.aliasDefinitions[spellID],
                keywords = spell.subtext,
                description = spell.description,
                icon = spell.icon,
                payload = { spellID = spellID },
                actions = {
                    { id = "open-detail", title = "查看详情", kind = "intent", intent = { type = "builtin.player-spells.open", version = 1, payload = { spellID = spellID, actionID = "open-detail" } } },
                    { id = "cast", title = "施放", kind = "secure-spell", spellID = spellID },
                },
                drag = { type = "spell", spellID = spellID },
            }
        end
    end
    return records
end

function P:Refresh()
    local refreshed
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then
        refreshed = self:RefreshOfflineFixture()
    else
        refreshed = self:RefreshFromSpellBook()
    end
    if refreshed and self.searchSourceID and I.Search and I.Search.StaticIndex then
        self.searchRevision = (self.searchRevision or 1) + 1
        I.Search.StaticIndex:CommitSnapshot(self.searchSourceID, self:BuildSearchRecords(), self.searchRevision)
    end
    return refreshed
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
