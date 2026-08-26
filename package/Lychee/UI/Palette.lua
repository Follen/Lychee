local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local locale = GetLocale and GetLocale() or "enUS"
_G.BINDING_HEADER_LYCHEE = "Lychee"
_G.BINDING_NAME_TOGGLELYCHEE = locale == "zhCN" and "打开/关闭 Lychee" or "Open/Close Lychee"

local Palette = {}
Palette.__index = Palette

local function paletteDB()
    LycheeDB = LycheeDB or {}
    LycheeDB.palette = LycheeDB.palette or {}
    local db = LycheeDB.palette
    db.recent = type(db.recent) == "table" and db.recent or {}
    db.pinned = type(db.pinned) == "table" and db.pinned or {}
    return db
end

local function stableItemID(item)
    if type(item) ~= "table" then return nil end
    local record = item.searchRecord
    return (record and record.id) or item.id
end

local function localized(value, fallback)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return fallback or "" end
    local current = GetLocale and GetLocale() or "enUS"
    local internal = _G.LycheeInternal
    local normalizer = internal and internal.Search and internal.Search.Normalizer
    if normalizer and normalizer.Localized then
        local entries = normalizer:Localized(value)
        local defaultText, englishText
        for index = 1, #entries do
            local entry = entries[index]
            local identity = internal.Search.RuntimeIdentity
            if not identity or identity:MatchesScope(nil, entry) then
                if entry.locale == current then return entry.text end
                if entry.locale == "default" and defaultText == nil then defaultText = entry.text end
                if entry.locale == "enUS" and englishText == nil then englishText = entry.text end
            end
        end
        return defaultText or englishText or fallback or ""
    end
    return value[current] or value.default or value.enUS or fallback or ""
end

local function homeLabel(value, fallback)
    if type(value) == "table" then return value.default or value.zhCN or fallback end
    return value or fallback
end

local function setShown(object, shown)
    if object and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function createHomeView(parent, controller)
    local frame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -48)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -48)
    frame:SetHeight(350)
    frame:Hide()
    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(592, 1)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame:SetScrollChild(content)
    local view = { frame = frame, content = content, controller = controller, tiles = {}, sections = {} }
    function view:AcquireTile(index)
        local existing = self.tiles[index]
        if existing then return existing end
        local tile = CreateFrame("Button", nil, self.content)
        tile:SetSize(142, 70)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        tile:SetPoint("TOPLEFT", self.content, "TOPLEFT", column * 150, -row * 80)
        tile:RegisterForClicks("LeftButtonUp")
        tile.bg = tile:CreateTexture(nil, "BACKGROUND")
        tile.bg:SetAllPoints()
        tile.bg:SetColorTexture(0.10, 0.11, 0.14, 0.92)
        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetSize(24, 24)
        tile.icon:SetPoint("LEFT", 8, 0)
        tile.title = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tile.title:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 7, -2)
        tile.title:SetPoint("RIGHT", tile, "RIGHT", -6, 0)
        tile.title:SetJustifyH("LEFT")
        tile.meta = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.meta:SetPoint("BOTTOMLEFT", tile.icon, "BOTTOMRIGHT", 7, 2)
        tile.meta:SetPoint("RIGHT", tile, "RIGHT", -6, 0)
        tile.meta:SetJustifyH("LEFT")
        tile:SetScript("OnClick", function(button)
            local section = button.section
            if section and controller and controller.onHomeSelect then controller.onHomeSelect(section) end
        end)
        tile:SetScript("OnEnter", function(button) button.bg:SetColorTexture(0.16, 0.20, 0.28, 1) end)
        tile:SetScript("OnLeave", function(button) button.bg:SetColorTexture(0.10, 0.11, 0.14, 0.92) end)
        self.tiles[index] = tile
        return tile
    end
    function view:SetSections(sections)
        self.sections = sections or {}
        local count = #self.sections
        for i = 1, count do
            local section, tile = self.sections[i], self:AcquireTile(i)
            tile.section = section
            local title = homeLabel(section.title or section.text, "Lychee")
            if tile._title ~= title then tile.title:SetText(title); tile._title = title end
            local meta = homeLabel(section.meta or section.source, "")
            if tile._meta ~= meta then tile.meta:SetText(meta); tile._meta = meta end
            if section.icon then
                if tile._icon ~= section.icon then tile.icon:SetTexture(section.icon); tile._icon = section.icon end
                setShown(tile.icon, true)
            else
                tile._icon = nil
                setShown(tile.icon, false)
            end
            setShown(tile, true)
        end
        for i = count + 1, #self.tiles do
            local tile = self.tiles[i]
            tile.section = nil
            setShown(tile, false)
        end
        local rows = math.ceil(count / 4)
        local height = math.max(1, rows > 0 and (rows * 80 - 10) or 1)
        if self.content:GetHeight() ~= height then self.content:SetHeight(height) end
    end
    function view:ShowSections(sections) self:SetSections(sections); self.frame:Show() end
    function view:Hide() self.frame:Hide() end
    return view
end

function Palette:Create()
    if self.frame then return self end
    local frame = CreateFrame("Frame", "LycheePalette", UIParent, "BackdropTemplate")
    frame:SetSize(620, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if frame.SetBackdropColor then frame:SetBackdropColor(0.035, 0.045, 0.065, 0.98) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.25, 0.31, 0.42, 1) end
    end
    frame:Hide()
    frame:SetScript("OnHide", function() if self.visible then self:Hide("external") end end)
    frame:SetScript("OnKeyDown", function(_, key) if key == "ESCAPE" then self:Hide("escape") end end)
    self.frame = frame
    self.session = 0
    self.generation = 0
    self.visible = false
    self.focus = Lychee.UI.FocusController:New()
    self.input = Lychee.UI.Input:Create(frame, self.focus)
    self.list = Lychee.UI.ResultList:Create(frame, self)
    self.homeView = createHomeView(frame, self)
    self.homeView:SetSections({})
    self.onHomeSelect = function(section)
        if section and section.query then self.input:SetText(section.query)
        elseif section and section.id and self.onHomeCategory then self.onHomeCategory(section.id) end
    end
    self.viewHost = Lychee.UI.ViewHost:Create(frame)
    self.input:SetChangedCallback(function(text)
        self.generation = self.generation + 1
        self:SetQueryMode(text)
        if self.onQuery then self.onQuery(text, self.generation, self.session) end
    end)
    self.input:SetSubmitCallback(function() self:ActivateSelected() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(_, event) if event == "PLAYER_REGEN_DISABLED" and self.visible then self:Hide("combat") end end)
    local internal = _G.LycheeInternal
    if internal then
        internal.Host = internal.Host or {}
        internal.Host.PaletteController = self
        local broker = internal.Host.SecureBroker
        if broker and broker.BindPalette then broker:BindPalette(self) end
        if internal.Registry and internal.Registry.OnChange and not internal._paletteLifecycleWired then
            internal._paletteLifecycleWired = true
            internal.Registry:OnChange(function(entry, state)
                if state == "disabled" or state == "retiring" or state == "removed" then
                    self:InvalidateExtension(entry and entry.id)
                end
            end)
        end
        if not internal.Host.ClosePalette then internal.Host.ClosePalette = function(reason) return self:Hide(reason) end end
        if not internal.Host.TogglePalette then internal.Host.TogglePalette = function() return self:Toggle() end end
        if internal.WirePalette then internal.WirePalette(self) end
    end
    return self
end

function Palette:SetQueryCallback(callback) self.onQuery = callback end
function Palette:SetActivateCallback(callback) self.onActivate = callback end
function Palette:SetDragCallback(callback) self.onDrag = callback end
function Palette:SetHomeSections(sections)
    if self.homeView then self.homeView:SetSections(sections or {}) end
end
function Palette:SetHomeCategoryCallback(callback) self.onHomeCategory = callback end
function Palette:TouchRecent(item)
    local id = stableItemID(item)
    if not id then return false end
    local db = paletteDB()
    for index = #db.recent, 1, -1 do
        if db.recent[index] == id then table.remove(db.recent, index) end
    end
    table.insert(db.recent, 1, id)
    while #db.recent > 8 do db.recent[#db.recent] = nil end
    return true
end

function Palette:SetPinned(item, pinned)
    local id = stableItemID(item)
    if not id then return false end
    local db = paletteDB()
    local found
    for index = #db.pinned, 1, -1 do
        if db.pinned[index] == id then found = true; if not pinned then table.remove(db.pinned, index) end end
    end
    if pinned and not found then db.pinned[#db.pinned + 1] = id end
    while #db.pinned > 16 do table.remove(db.pinned, 1) end
    return true
end

function Palette:_IndexedRecordsByID()
    local records, index = {}, {}
    local static = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.StaticIndex
    if not static or type(static.entries) ~= "table" then return records, index end
    for _, entry in pairs(static.entries) do
        local record = entry and entry.record
        if type(record) == "table" and type(record.id) == "string" and not index[record.id] then
            index[record.id] = record
            records[#records + 1] = record
        end
    end
    return records, index
end

function Palette:RefreshHomeSections()
    if not self.homeView then return false end
    local records, byID = self:_IndexedRecordsByID()
    local db = paletteDB()
    local sections = {}
    local function appendSaved(title, meta, ids)
        local count = 0
        for index = 1, #ids do
            local record = byID[ids[index]]
            if record then
                sections[#sections + 1] = {
                    id = "saved:" .. ids[index],
                    title = localized(record.title, ids[index]),
                    meta = title .. "  " .. localized(record.category and record.category.title, meta),
                    icon = record.icon,
                    query = localized(record.title, ids[index]),
                }
                count = count + 1
            end
        end
        if count == 0 then
            sections[#sections + 1] = {
                id = string.lower(meta),
                title = title,
                meta = localized({ zhCN = "暂无记录", enUS = "No items" }, ""),
            }
        end
        return count
    end
    appendSaved("最近使用", "Recent", db.recent)
    appendSaved("固定项目", "Pinned", db.pinned)

    local categoryLabels = {
        { id = "spells", title = "技能", meta = "Spells" },
        { id = "achievements", title = "成就", meta = "Achievements" },
        { id = "quests", title = "任务", meta = "Quests" },
        { id = "dungeons", title = "副本", meta = "Dungeons" },
        { id = "extensions", title = "插件", meta = "Extensions" },
    }
    for i = 1, #categoryLabels do
        local category = categoryLabels[i]
        local representative
        for j = 1, #records do
            local value = records[j].category
            local categoryID = type(value) == "table" and value.id or value
            if categoryID == category.id then representative = records[j]; break end
        end
        sections[#sections + 1] = {
            id = "category:" .. category.id,
            title = category.title,
            meta = category.meta,
            icon = representative and representative.icon,
            query = category.title,
        }
    end

    local internal = _G.LycheeInternal
    local registry = internal and internal.Registry
    local static = internal and internal.Search and internal.Search.StaticIndex
    if registry and static and type(static.sources) == "table" then
        local sourceIDs = {}
        for sourceID, source in pairs(static.sources) do
            local extensionID = source and source.extensionID
            if source.enabled and type(extensionID) == "string" and extensionID:sub(1, 7) ~= "builtin" then
                sourceIDs[#sourceIDs + 1] = sourceID
            end
        end
        table.sort(sourceIDs)
        for index = 1, #sourceIDs do
            local sourceID = sourceIDs[index]
            local source = static.sources[sourceID]
            local entry = registry.entries[source.extensionID]
            local extensionTitle = localized(entry and entry.descriptor and entry.descriptor.title, source.extensionID)
            sections[#sections + 1] = {
                id = "source:" .. sourceID,
                title = extensionTitle,
                meta = source.id:match("([^:]+)$") or source.id,
                query = extensionTitle,
            }
        end
    end
    self:SetHomeSections(sections)
    return true
end
function Palette:SetQueryMode(text)
    local empty = (text or "") == ""
    if not self.homeView or not self.list then return end
    if empty then
        self.list.frame:Hide()
        self:RefreshHomeSections()
        self.homeView.frame:Show()
    else
        self.homeView.frame:Hide()
        self.list.frame:Show()
    end
end
function Palette:IsExtensionEnabled(extensionID)
    if not extensionID then return true end
    local registry = _G.LycheeInternal and _G.LycheeInternal.Registry
    return not registry or registry:IsEnabled(extensionID)
end
function Palette:IsRowCurrent(row, session, generation, item, extensionID)
    if not self.visible or not row or not row.item then return false, "STALE_GENERATION" end
    if row.session ~= self.session or row.generation ~= self.generation then return false, "STALE_GENERATION" end
    if session and session ~= self.session or generation and generation ~= self.generation then return false, "STALE_GENERATION" end
    if item and row.item ~= item then return false, "STALE_GENERATION" end
    extensionID = extensionID or row.extensionID
    if not self:IsExtensionEnabled(extensionID) then return false, "EXTENSION_DISABLED" end
    local rowItem = row.item
    if rowItem.sourceID and rowItem.sourceGeneration then
        local static = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.StaticIndex
        local state = static and static:GetSourceState(rowItem.sourceID)
        if not state or state.enabled == false or state.generation ~= rowItem.sourceGeneration
            or state.revision ~= rowItem.sourceRevision then
            return false, "STALE_GENERATION"
        end
    end
    return true
end
function Palette:IsRecordAvailable(item)
    local availability = item and item.searchRecord and item.searchRecord.availability
    if type(availability) ~= "table" then return true end
    local context = _G.LycheeInternal and _G.LycheeInternal.Context
    context = context and context:Snapshot() or {}
    local value = context[availability.contextKey]
    if value == nil and type(context.values) == "table" then value = context.values[availability.contextKey] end
    return value == availability.equals
end
function Palette:ValidateRowAction(row, session, generation, item, extensionID)
    local current, err = self:IsRowCurrent(row, session, generation, item, extensionID)
    if not current then return false, err end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if not self:IsRecordAvailable(row.item) then return false, "ACTION_UNAVAILABLE" end
    return true
end
function Palette:InvalidateRow(row)
    if self.secureBroker and self.secureBroker.InvalidateRow then self.secureBroker:InvalidateRow(row) end
    if self.list and self.list.InvalidateRow then self.list:InvalidateRow(row) end
end
function Palette:RejectRow(row, err)
    if err == "STALE_GENERATION" or err == "EXTENSION_DISABLED" then self:InvalidateRow(row) end
    return false, err
end
function Palette:InvalidateExtension(extensionID)
    if not extensionID then return false end
    if self.viewHost and self.viewHost.panel and self.viewHost.panel.context
        and self.viewHost.panel.context.extensionID == extensionID then
        self.viewHost:Unmount("extension-disabled")
    end
    if not self.list then return true end
    for i = 1, #self.list.rows do
        local row = self.list.rows[i]
        if row.extensionID == extensionID then self:InvalidateRow(row) end
    end
    return true
end
function Palette:SetResults(items, generation, session)
    if not self.visible then return false end
    if session and session ~= self.session then return false end
    -- Search owns the monotonic generation. Accept a newer result even if an
    -- IME/composition callback advanced the palette locally; reject only stale work.
    if generation and generation < self.generation then return false end
    if generation then self.generation = generation end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.list:SetItems(items or {}, self.session, self.generation)
    if self.secureBroker and self.secureBroker.Prepare then
        for i = 1, #self.list.rows do
            local row = self.list.rows[i]
            local interaction = row.item and row.item.interaction
            local actions = interaction and interaction.actions
            local current = self:IsRowCurrent(row)
            if not current then self:InvalidateRow(row) end
            if current and row:IsShown() and actions then
                for j = 1, math.min(#actions, 4) do
                    local action = actions[j]
                    if action.kind == "secure-spell" then
                        local button = self.secureBroker:Prepare(action, {
                            controller = self, row = row, item = row.item, extensionID = row.extensionID,
                            session = self.session, generation = self.generation,
                        })
                        if button then
                            button:ClearAllPoints()
                            button:SetPoint("CENTER", row.actions[j], "CENTER")
                        end
                    end
                end
            end
        end
    end
    return true
end
function Palette:Show()
    self:Create()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    self.session = self.session + 1
    self.generation = self.generation + 1
    self.visible = true
    self.frame:Show()
    self:SetQueryMode(self.input:GetText())
    self.input:Show(); self.input:Focus()
    return true
end
function Palette:Hide(reason)
    local query = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Query
    if query and (self.visible or query.pending or query.timer) and type(query.Invalidate) == "function" then
        query:Invalidate()
    end
    if not self.frame or not self.visible then return true end
    self.visible = false
    self.session = self.session + 1
    self.generation = self.generation + 1
    self.list:Clear()
    if self.viewHost then self.viewHost:Unmount(reason or "hide") end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.focus:Restore()
    self.input:ClearFocus(); self.input:Hide()
    self.frame:Hide()
    return true
end
function Palette:Toggle()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self.visible then return self:Hide("toggle") end
    return self:Show()
end
function Palette:ActivateRow(row)
    local valid, err = self:IsRowCurrent(row)
    if not valid then return self:RejectRow(row, err) end
    return self:ActivateRowAction(row, row.item.interaction and row.item.interaction.primaryActionID or "default")
end
function Palette:ActivateSelected() return self.list:ActivateSelected() end
function Palette:ActivateRowAction(row, actionID)
    if not self.visible then return false, "INVALID_STATE" end
    local valid, err = self:ValidateRowAction(row)
    if not valid then return self:RejectRow(row, err) end
    local item = row and row.item
    if not item then return false, "ACTION_UNAVAILABLE" end
    self:TouchRecent(item)
    local interaction = item.interaction
    local action
    if interaction and interaction.actions then for i = 1, #interaction.actions do if interaction.actions[i].id == actionID then action = interaction.actions[i]; break end end end
    if action and action.kind == "open-panel" then
        local extensionID = row.extensionID or item._ext
        local panelID = action.panel
        local registry = _G.LycheeInternal and _G.LycheeInternal.Registry
        local factory = registry and registry:GetPanel(extensionID, panelID)
        if not factory then return false, "COMMAND_NOT_FOUND" end
        local state = action.state or item.payload or {}
        local stateOK, stateErr = registry:ValidateSchema(state, factory.stateSchema or {}, "action.state")
        if not stateOK then return false, stateErr and stateErr.code or "INVALID_SCHEMA" end
        return self:OpenView(factory, { extensionID = extensionID, panelID = panelID, session = self.session, generation = self.generation }, state)
    end
    if action and action.kind == "drag-spell" then
        local drag = { type = "spell", spellID = action.spellID }
        if Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(drag.spellID) then return false, "ACTION_UNAVAILABLE" end
        if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(drag.spellID); return true end
        if PickupSpell then PickupSpell(drag.spellID); return true end
        return false, "DRAG_UNSUPPORTED"
    end
    if action and action.kind == "secure-spell" then
        if Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(action.spellID) then return false, "ACTION_UNAVAILABLE" end
        if actionID == (interaction.primaryActionID or "") then return false, "ACTION_REQUIRES_HARDWARE_CLICK" end
        return self.secureBroker and self.secureBroker:ShowFor(row, action, self.session, self.generation, item, row.extensionID) or false
    end
    if self.onActivate then return self.onActivate(item, actionID, self.session, self.generation) end
    return false, "ACTION_UNAVAILABLE"
end
function Palette:BeginRowDrag(row)
    local valid, err = self:ValidateRowAction(row)
    if not valid then return self:RejectRow(row, err) end
    if self.onDrag then return self.onDrag(row.item, self.session, self.generation) end
    local drag = row.item.interaction and row.item.interaction.drag
    if type(drag) ~= "table" or drag.type ~= "spell" or type(drag.spellID) ~= "number" then return false, "DRAG_UNSUPPORTED" end
    if Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(drag.spellID) then return false, "ACTION_UNAVAILABLE" end
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(drag.spellID)
        return true
    end
    if PickupSpell then PickupSpell(drag.spellID); return true end
    return false, "DRAG_UNSUPPORTED"
end
function Palette:OpenView(factory, context, state) return self.viewHost:Mount(factory, context or {}, state) end
function Palette:CloseView(reason) return self.viewHost:Unmount(reason or "close") end

function Lychee_Toggle()
    if InCombatLockdown and InCombatLockdown() then return end
    local internal = _G.LycheeInternal
    local controller = internal and internal.Host and internal.Host.PaletteController
    if not controller then controller = Palette:Create() end
    controller:Toggle()
end

Lychee.UI.Palette = Palette
if not (_G.LycheeInternal and _G.LycheeInternal.Host and _G.LycheeInternal.Host.PaletteController) then Palette:Create() end
