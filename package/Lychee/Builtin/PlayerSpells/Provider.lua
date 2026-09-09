local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
I.Builtin.PlayerSpells = I.Builtin.PlayerSpells or {}
local P = {
    items = {},
    extensionID = "builtin.player-spells",
    dirty = true,
    descriptionRequests = {},
}

I.Builtin.PlayerSpells.Provider = P
P.aliasDefinitions = (I.BuiltinData and I.BuiltinData.PlayerSpellAliases) or {}

local function addSpell(items, aliasDefinitions, spell)
    if type(spell.id) ~= "number" or type(spell.name) ~= "string" or spell.name == "" then return end
    spell.aliases = spell.aliases or aliasDefinitions[spell.id]
    items[spell.id] = spell
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

local function addKnownAliasSpells(self, items, aliasDefinitions)
    if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then return end
    for spellID in pairs(aliasDefinitions) do
        if not items[spellID] and knownToPlayer(spellID) then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                addSpell(items, aliasDefinitions, {
                    id = spellID, name = info.name, icon = info.iconID,
                    subtext = info.subName, aliases = aliasDefinitions[spellID],
                    description = spellDescription(self, spellID),
                })
            end
        end
    end
end

local function spellIcon(spellID, fallback)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.iconID then return info.iconID end
    end
    return fallback
end

local function addFlyoutSpells(self, items, flyoutID)
    if type(GetFlyoutInfo) ~= "function" or type(GetFlyoutSlotInfo) ~= "function" then return 0 end
    local ok, _, _, count, known = pcall(GetFlyoutInfo, flyoutID)
    if not ok or not known or type(count) ~= "number" or count <= 0 then return 0 end
    local added = 0
    for slot = 1, count do
        local slotOK, spellID, overrideSpellID, isKnown, name = pcall(GetFlyoutSlotInfo, flyoutID, slot)
        if slotOK and isKnown and type(spellID) == "number" and spellID > 0 then
            local resolvedID = spellID
            local iconID = type(overrideSpellID) == "number" and overrideSpellID > 0 and overrideSpellID or spellID
            local resolvedName = type(name) == "string" and name ~= "" and name or spellName(resolvedID)
            if resolvedName then
                addSpell(items, self.aliasDefinitions, {
                    id = resolvedID, name = resolvedName, icon = spellIcon(iconID),
                    aliases = self.aliasDefinitions[resolvedID],
                    description = spellDescription(self, resolvedID),
                })
                added = added + 1
            end
        end
    end
    return added
end

local function isFlyoutItem(itemType)
    local enumValue = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    return itemType == (enumValue or 4)
end

local function commitSnapshot(self, items, source)
    self.items = items
    self.lastRefresh, self.lastError, self.dirty = source, nil, false
end

local function refreshFailed(self, code)
    self.lastError, self.dirty = code, true
    return false, code
end

function P:RefreshFromSpellBook()
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then
        return refreshFailed(self, "SPELLBOOK_API_UNAVAILABLE")
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank == nil then return refreshFailed(self, "SPELLBOOK_BANK_UNAVAILABLE") end
    local ok, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or type(count) ~= "number" or count < 0 then
        return refreshFailed(self, "SPELLBOOK_LINES_UNAVAILABLE")
    end

    local nextItems = {}
    local readableItems = 0
    for line = 1, count do
        local lineOK, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        -- Hidden skill lines can still contain real player spells (teleports,
        -- utility and encounter unlocks). Keep the player-bank boundary, but
        -- do not discard records solely because Blizzard hides their line.
        if lineOK and type(info) == "table" and not info.isGuild then
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
                            addSpell(nextItems, self.aliasDefinitions, {
                                id = item.spellID, name = name, icon = item.iconID,
                                subtext = item.subName, aliases = self.aliasDefinitions[item.spellID],
                                description = spellDescription(self, item.spellID),
                            })
                        end
                    end
                    -- SpellBook flyouts (itemType 4) expose their real spells
                    -- through GetFlyoutSlotInfo rather than item.spellID.
                    if itemOK and C_SpellBook and type(C_SpellBook.GetSpellBookItemType) == "function" then
                        local typeOK, itemType, flyoutID = pcall(C_SpellBook.GetSpellBookItemType, slot, bank)
                        if typeOK and isFlyoutItem(itemType) and type(flyoutID) == "number" then
                            addFlyoutSpells(self, nextItems, flyoutID)
                        end
                    end
                end
            end
        end
    end
    -- A known utility/teleport spell can be omitted from a visible skill line.
    addKnownAliasSpells(self, nextItems, self.aliasDefinitions)
    if readableItems == 0 and next(nextItems) == nil then
        return refreshFailed(self, "SPELLBOOK_ITEMS_UNAVAILABLE")
    end
    commitSnapshot(self, nextItems, "spellbook")
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
                kindTitle = { default = "Spell", zhCN = "技能" },
                category = { id = "spells", title = { default = "Spells", zhCN = "技能" }, order = 10, color = { 0.455, 0.670, 0.925, 1 } },
                title = spell.name,
                aliases = spell.aliases or self.aliasDefinitions[spellID],
                keywords = spell.subtext,
                description = spell.description,
                icon = spell.icon,
                payload = { spellID = spellID },
                -- The search protocol keeps the default interaction explicit.  The
                -- renderer never has to infer spell behavior from `kind`.
                primaryActionID = "cast",
                actions = {
                    { id = "cast", title = "施放", kind = "secure-spell", spellID = spellID },
                },
                drag = { type = "spell", spellID = spellID },
            }
        end
    end
    return records
end

function P:Refresh()
    local refreshed = self:RefreshFromSpellBook()
    if refreshed and self.providerHandle then
        local committed = self.providerHandle:Update({ replace = self:BuildSearchRecords() })
        if not committed then return refreshFailed(self, "SOURCE_COMMIT_FAILED") end
    end
    return refreshed
end

function P:Detach(releaseSource)
    self._active = false
    self._refreshPending = nil
    if self._eventFrame then
        if type(self._eventFrame.UnregisterAllEvents) == "function" then self._eventFrame:UnregisterAllEvents() end
        self._eventFrame:SetScript("OnEvent", nil)
    end
    self._eventFrame = nil
    if releaseSource then self.providerHandle = nil end
end
