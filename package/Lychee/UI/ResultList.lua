local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ResultList = {}
ResultList.__index = ResultList

local GRID_COLUMNS = 1
local DEFAULT_TILES = 8
local TILE_WIDTH, TILE_HEIGHT = 608, 58
local EMPTY_ITEMS = {}
local UI_LOCALE = GetLocale and GetLocale() or "enUS"
local UI_CHINESE = UI_LOCALE == "zhCN" or UI_LOCALE == "zhTW"
local FALLBACK = {
    row = { 0.075, 0.078, 0.09, 0.96 }, rowHover = { 0.105, 0.108, 0.122, 0.98 },
    rowSelected = { 0.145, 0.105, 0.115, 0.98 }, outline = { 0.30, 0.19, 0.21, 0.85 },
    accent = { 0.91, 0.20, 0.30, 1 }, action = { 0.13, 0.135, 0.15, 1 },
    actionHover = { 0.20, 0.205, 0.23, 1 }, text = { 0.96, 0.945, 0.91, 1 },
    muted = { 0.62, 0.63, 0.67, 1 }, dim = { 0.45, 0.46, 0.50, 1 },
}
local THEME_KEY = {
    row = "surface", rowHover = "surfaceHover", rowSelected = "surfaceSelected", rowPressed = "surface",
    outline = "accentMuted", action = "surfaceHover", actionHover = "surfaceSelected", muted = "textMuted", dim = "textDim",
}

local function color(name)
    local theme = Lychee.UI and Lychee.UI.Theme
    local colors = theme and (theme.colors or theme.Colors or theme)
    local value = colors and colors[THEME_KEY[name] or name]
    if type(value) == "table" then
        return value[1] or value.r or 1, value[2] or value.g or 1, value[3] or value.b or 1, value[4] or value.a or 1
    end
    local fallback = FALLBACK[name]
    return fallback[1], fallback[2], fallback[3], fallback[4]
end

local function setText(fontString, value)
    value = value or ""
    if fontString and fontString:GetText() ~= value then fontString:SetText(value) end
end

local function setTextColor(fontString, name)
    if not fontString or type(fontString.SetTextColor) ~= "function" then return end
    local theme, key = Lychee.UI and Lychee.UI.Theme, THEME_KEY[name] or name
    if theme and type(theme.SetTextColor) == "function" then theme:SetTextColor(fontString, key); return end
    local token = FALLBACK[name]
    if fontString._lycheeResultTextToken ~= token then
        fontString:SetTextColor(color(name))
        fontString._lycheeResultTextToken = token
    end
end

local function setCategoryTextColor(fontString, item)
    local theme = Lychee.UI and Lychee.UI.Theme
    local category = item and item.searchRecord and item.searchRecord.category
    local value = item and item.categoryColor or (type(category) == "table" and category.color)
    if value and type(fontString.SetTextColor) == "function" then
        if type(theme.SetTextColor) == "function" then theme:SetTextColor(fontString, value)
        elseif fontString._lycheeResultTextToken ~= value then
            fontString:SetTextColor(value[1], value[2], value[3], value[4] or 1)
            fontString._lycheeResultTextToken = value
        end
    else
        setTextColor(fontString, "muted")
    end
end

local function setShown(object, shown)
    if object and type(object.IsShown) == "function" and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function cropIcon(texture)
    if texture and type(texture.SetTexCoord) == "function" then texture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
end

local function setTextureColor(texture, name)
    if not texture or type(texture.SetColorTexture) ~= "function" then return end
    local theme, key = Lychee.UI and Lychee.UI.Theme, THEME_KEY[name] or name
    if theme and type(theme.SetColorTexture) == "function" then theme:SetColorTexture(texture, key); return end
    local token = FALLBACK[name]
    if texture._lycheeResultColorToken ~= token then
        texture:SetColorTexture(color(name))
        texture._lycheeResultColorToken = token
    end
end

local function singleLine(fontString)
    if type(fontString.SetWordWrap) == "function" then fontString:SetWordWrap(false) end
    if type(fontString.SetNonSpaceWrap) == "function" then fontString:SetNonSpaceWrap(false) end
    if type(fontString.SetMaxLines) == "function" then fontString:SetMaxLines(1) end
end

local function extensionID(item) return item and (item._ext or (item.command and item.command._ext)) end
local function stableItemID(item) return item and (item.stableID or item.id or item.itemID or item) or nil end
local function actionEnabled(action) return action and action.id and action.enabled ~= false and action.disabled ~= true end
local function actionLabel(action) return action and (action.title or action.label or action.id) or "" end

local function cachedText(row, key, fontString, value)
    value = value or ""
    row._rendered = row._rendered or {}
    if row._rendered[key] == value then return end
    setText(fontString, value)
    row._rendered[key] = value
end

local function categoryText(item)
    local category = item and (item.category or item.categoryLabel)
    if type(category) == "table" then
        local title, locale = category.title, GetLocale and GetLocale() or "enUS"
        category = type(title) == "table" and (title[locale] or title.default or title.enUS or category.id) or (title or category.id)
    end
    return category or ""
end

local function categoryColorID(item)
    local category = item and item.searchRecord and item.searchRecord.category
    return item and item.categoryColor or (type(category) == "table" and category.color)
end

local function kindText(item)
    local record = item and item.searchRecord
    local title = item and item.kindTitle or record and record.kindTitle
    if type(title) == "string" and title ~= "" then return title end
    local kind = item and (item.kind or item.type) or record and (record.kind or record.type)
    return tostring(kind or (UI_CHINESE and "内容" or "Content"))
end

local function hideTooltip()
    if GameTooltip and type(GameTooltip.Hide) == "function" then GameTooltip:Hide() end
end

local function showTooltip(owner, title, detail)
    if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if type(GameTooltip.SetText) == "function" then GameTooltip:SetText(title or "", 0.96, 0.95, 0.94, 1, true) end
    if type(detail) == "table" and type(GameTooltip.AddLine) == "function" then
        GameTooltip:AddLine(kindText(detail), 0.58, 0.58, 0.62)
        local description = detail.description or detail.summary or detail.subtext
        if type(description) == "string" and description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(description, 0.82, 0.82, 0.85, true)
        end
        local interaction = detail.interaction
        local actions = interaction and interaction.actions
        local primary = type(actions) == "table" and actions[1]
        if primary and interaction.primaryActionID then
            for index = 1, #actions do
                if actions[index].id == interaction.primaryActionID then primary = actions[index]; break end
            end
        end
        if actionEnabled(primary) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine((UI_CHINESE and "点击 · " or "Click · ") .. actionLabel(primary), 0.90, 0.35, 0.40, true)
        end
    elseif detail and detail ~= "" and detail ~= title and type(GameTooltip.AddLine) == "function" then
        GameTooltip:AddLine(detail, 0.78, 0.78, 0.82, true)
    end
    if type(GameTooltip.Show) == "function" then GameTooltip:Show() end
end

local function primaryAction(interaction)
    local actions = interaction and interaction.actions
    if type(actions) ~= "table" then return nil end
    if type(interaction.primaryActionID) == "string" then
        for index = 1, #actions do if actions[index].id == interaction.primaryActionID then return actions[index] end end
    end
    return actions[1]
end

local function secondaryAction(interaction)
    local actions, primary = interaction and interaction.actions, primaryAction(interaction)
    if type(actions) ~= "table" then return nil end
    for index = 1, #actions do
        local action = actions[index]
        if action ~= primary and action.kind ~= "secure-spell" then return action end
    end
end

local function renderRowState(row)
    local background = row._selected and "rowSelected" or ((row._pressed or row._hovered) and "rowHover" or "row")
    setTextureColor(row.bg, background)
    -- Red stays inside the selected row; the search field has no boxed focus ring.
    setShown(row.accent, false)
    setShown(row.outline, row._hovered == true or row._selected == true)
    setShown(row.secondary, row.secondaryAction and (row._hovered or row._selected) or false)
    setShown(row.dragHighlight, row._dragHovered == true)
end

local function clearRow(row)
    row.item, row.index, row.session, row.generation, row.extensionID, row.stableID = nil, nil, nil, nil, nil, nil
    row.primaryAction, row.secondaryAction, row.dragDescriptor = nil, nil, nil
    row._hovered, row._dragHovered, row._selected, row._pressed = false, false, false, false
    cachedText(row, "title", row.title, "")
    cachedText(row, "subtext", row.subtext, "")
    cachedText(row, "category", row.category, "")
    cachedText(row, "primaryHint", row.primaryHint, "")
    if row._icon ~= nil and row.icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(nil) end
    row._icon, row._categoryColorID = nil, nil
    if row.secondary then row.secondary.actionID, row.secondary.action, row.secondary.tooltip = nil, nil, nil end
    setShown(row.icon, false); setShown(row.dragger, false); renderRowState(row); setShown(row, false)
end

function ResultList:SelectRow(row)
    if row and row.index then self:Select(row.index) end
end

function ResultList:SetHover(row, hovered)
    if not row or row._hovered == (hovered == true) then return end
    row._hovered = hovered == true
    renderRowState(row)
end

function ResultList:ShowTooltip(row, owner)
    showTooltip(owner or row, row.title:GetText(), row.item)
end

function ResultList:Create(parent, controller)
    local theme = Lychee.UI and Lychee.UI.Theme
    local metrics = theme and theme.Metrics or {}
    local columns = metrics.resultColumns or GRID_COLUMNS
    local tiles, rowHeight, rowGap = metrics.resultTiles or DEFAULT_TILES, metrics.rowHeight or TILE_HEIGHT, metrics.rowGap or 8
    local tileWidth = metrics.resultTileWidth or TILE_WIDTH
    local iconSize = metrics.iconSize or 32
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -10); frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -10)
    local gridRows = math.ceil(tiles / columns)
    frame:SetHeight(gridRows * rowHeight + math.max(0, gridRows - 1) * rowGap)
    local self = setmetatable({ frame = frame, controller = controller, rows = {}, items = EMPTY_ITEMS, selected = 1,
        rowHeight = rowHeight, rowGap = rowGap, tileWidth = tileWidth, gridColumns = columns, maxRows = tiles, offset = 0 }, ResultList)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    frame:SetScript("OnMouseWheel", function(_, delta) self:Scroll(delta > 0 and -1 or 1) end)

    for index = 1, tiles do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(tileWidth, rowHeight)
        row.ownerView = self
        local column = (index - 1) % columns
        local gridRow = math.floor((index - 1) / columns)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", column * (tileWidth + rowGap), -gridRow * (rowHeight + rowGap))
        row:RegisterForClicks("LeftButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
        row.outline = CreateFrame("Frame", nil, row); row.outline:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1); row.outline:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
        row.outline.edges = {}
        for edgeIndex = 1, 4 do
            local edge = row.outline:CreateTexture(nil, "BORDER")
            if edgeIndex == 1 then edge:SetPoint("TOPLEFT", row.outline, "TOPLEFT"); edge:SetPoint("TOPRIGHT", row.outline, "TOPRIGHT"); edge:SetHeight(1)
            elseif edgeIndex == 2 then edge:SetPoint("BOTTOMLEFT", row.outline, "BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT", row.outline, "BOTTOMRIGHT"); edge:SetHeight(1)
            elseif edgeIndex == 3 then edge:SetPoint("TOPLEFT", row.outline, "TOPLEFT"); edge:SetPoint("BOTTOMLEFT", row.outline, "BOTTOMLEFT"); edge:SetWidth(1)
            else edge:SetPoint("TOPRIGHT", row.outline, "TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT", row.outline, "BOTTOMRIGHT"); edge:SetWidth(1) end
            setTextureColor(edge, "outline"); row.outline.edges[edgeIndex] = edge
        end
        row.accent = row:CreateTexture(nil, "ARTWORK"); row.accent:SetWidth(3); row.accent:SetPoint("TOPLEFT", row, "TOPLEFT"); row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT"); setTextureColor(row.accent, "accent")

        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(iconSize, iconSize); row.icon:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.dragHighlight = row:CreateTexture(nil, "BORDER"); row.dragHighlight:SetSize(iconSize + 4, iconSize + 4); row.dragHighlight:SetPoint("CENTER", row.icon, "CENTER"); setTextureColor(row.dragHighlight, "actionHover")
        row.dragger = CreateFrame("Button", nil, row); row.dragger:SetSize(iconSize + 6, iconSize + 6); row.dragger:SetPoint("CENTER", row.icon, "CENTER"); row.dragger:RegisterForDrag("LeftButton")
        row.dragger:SetScript("OnDragStart", function(button)
            if button:GetParent().dragDescriptor and self.controller then self.controller:BeginRowDrag(button:GetParent()) end
        end)
        row.dragger:SetScript("OnEnter", function(button)
            local owner = button:GetParent(); owner._dragHovered = true; self:SetHover(owner, true); renderRowState(owner)
            showTooltip(button, UI_CHINESE and "拖到动作条" or "Drag to action bar", UI_CHINESE and "拖动这个图标到动作条" or "Drag this icon onto an action bar")
        end)
        row.dragger:SetScript("OnLeave", function(button)
            local owner = button:GetParent(); owner._dragHovered = false; self:SetHover(owner, false); renderRowState(owner); hideTooltip()
        end)

        row.primaryTarget = CreateFrame("Button", nil, row)
        row.primaryTarget:SetAllPoints(row); row.primaryTarget:RegisterForClicks("LeftButtonUp")
        row.primaryTarget:SetScript("OnClick", function(button)
            local owner = button:GetParent(); self:SelectRow(owner)
            if self.controller then self.controller:ActivateRow(owner) end
        end)
        row.primaryTarget:SetScript("OnEnter", function(button)
            local owner = button:GetParent(); self:SetHover(owner, true); showTooltip(button, owner.title:GetText(), owner.item)
        end)
        row.primaryTarget:SetScript("OnLeave", function(button) self:SetHover(button:GetParent(), false); hideTooltip() end)

        row.category = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.category:SetPoint("RIGHT", row, "RIGHT", -42, 0); row.category:SetWidth(80); row.category:SetJustifyH("RIGHT"); singleLine(row.category)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 56, -10); row.title:SetPoint("RIGHT", row, "RIGHT", -138, 0); row.title:SetHeight(19); row.title:SetJustifyH("LEFT"); singleLine(row.title); setTextColor(row.title, "text")
        if row.title.SetFont and STANDARD_TEXT_FONT then row.title:SetFont(STANDARD_TEXT_FONT, 15, "") end
        row.subtext = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.subtext:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3); row.subtext:SetPoint("RIGHT", row, "RIGHT", -138, 0); row.subtext:SetHeight(14); row.subtext:SetJustifyH("LEFT"); singleLine(row.subtext); setTextColor(row.subtext, "muted")
        row.description = row.subtext
        row.primaryHint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.primaryHint:Hide()

        row.secondary = CreateFrame("Button", nil, row); row.secondary:SetSize(24, 24); row.secondary:SetPoint("RIGHT", row, "RIGHT", -9, 0); row.secondary:RegisterForClicks("LeftButtonUp")
        row.secondary.bg = row.secondary:CreateTexture(nil, "BACKGROUND"); row.secondary.bg:SetAllPoints(); setTextureColor(row.secondary.bg, "action")
        row.secondary.label = row.secondary:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.secondary.label:SetAllPoints(); row.secondary.label:SetJustifyH("CENTER"); setText(row.secondary.label, "..."); setTextColor(row.secondary.label, "text")
        row.secondary:SetScript("OnClick", function(button)
            local owner = button:GetParent()
            if actionEnabled(owner.secondaryAction) and self.controller then self.controller:ActivateRowAction(owner, owner.secondaryAction.id) end
        end)
        row.secondary:SetScript("OnEnter", function(button)
            local owner = button:GetParent(); self:SetHover(owner, true); setTextureColor(button.bg, "actionHover"); showTooltip(button, actionLabel(owner.secondaryAction), owner.secondaryAction and owner.secondaryAction.description)
        end)
        row.secondary:SetScript("OnLeave", function(button) self:SetHover(button:GetParent(), false); setTextureColor(button.bg, "action"); hideTooltip() end)

        row:SetScript("OnClick", function(button) self:SelectRow(button); if self.controller then self.controller:ActivateRow(button) end end)
        row:SetScript("OnMouseDown", function(button) button._pressed = true; renderRowState(button) end)
        row:SetScript("OnMouseUp", function(button) button._pressed = false; renderRowState(button) end)
        row:SetScript("OnEnter", function(button) self:SetHover(button, true) end)
        row:SetScript("OnLeave", function(button)
            self:SetHover(button, false)
            if not button.IsMouseOver or not button:IsMouseOver() then hideTooltip() end
        end)
        row._rendered = {}
        self.rows[index] = row
        clearRow(row)
    end
    return self
end

function ResultList:Resize(count)
    count = math.max(0, math.min(tonumber(count) or 0, self.maxRows or DEFAULT_TILES))
    local gridRows = count > 0 and math.ceil(count / self.gridColumns) or 0
    local height = gridRows > 0 and (gridRows * self.rowHeight + (gridRows - 1) * self.rowGap) or 0
    if self.frame and self.frame.GetHeight and self.frame:GetHeight() ~= height then self.frame:SetHeight(height) end
    return height
end

function ResultList:Clear()
    hideTooltip()
    for index = 1, #self.rows do clearRow(self.rows[index]) end
    self.items = EMPTY_ITEMS; self.session, self.generation, self.selected, self.offset = nil, nil, 1, 0
end

function ResultList:SetItems(items, session, generation, offset)
    local selectedRow = self.rows[self.selected or 1]
    local selectedID = selectedRow and selectedRow.stableID
    self.items, self.session, self.generation = items or EMPTY_ITEMS, session, generation
    self.offset = math.max(0, math.min(offset or 0, math.max(0, #self.items - #self.rows)))
    local count = math.min(#self.items - self.offset, #self.rows)
    self:Resize(count)
    for index = 1, count do
        local item, row = self.items[index + self.offset], self.rows[index]
        if type(item) == "table" then
        row.item, row.index = item, index
        row.session, row.generation, row.extensionID, row.stableID = session, generation, extensionID(item), stableItemID(item)
        cachedText(row, "title", row.title, item.text)
        cachedText(row, "subtext", row.subtext, item.subtext ~= "" and item.subtext or item.description or item.summary or "")
        cachedText(row, "category", row.category, categoryText(item))
        local colorID = categoryColorID(item)
        if row._categoryColorID ~= colorID then setCategoryTextColor(row.category, item); row._categoryColorID = colorID end
        local icon = item.icon
        if row._icon ~= icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(icon); cropIcon(row.icon); row._icon = icon end
        setShown(row.icon, icon ~= nil)
        local interaction = item.interaction
        row.primaryAction, row.secondaryAction, row.dragDescriptor = primaryAction(interaction), secondaryAction(interaction), interaction and interaction.drag
        if row.primaryTarget and type(row.primaryTarget.EnableMouse) == "function" then row.primaryTarget:EnableMouse(true) end
        cachedText(row, "primaryHint", row.primaryHint, "")
        row.secondary.actionID, row.secondary.action, row.secondary.tooltip = row.secondaryAction and row.secondaryAction.id, row.secondaryAction, actionLabel(row.secondaryAction)
        setShown(row.dragger, row.dragDescriptor ~= nil)
        renderRowState(row); setShown(row, true)
        else
            clearRow(row)
        end
    end
    for index = count + 1, #self.rows do clearRow(self.rows[index]) end
    local selected = math.max(1, math.min(self.selected or 1, math.max(count, 1)))
    if selectedID ~= nil then for index = 1, count do if self.rows[index].stableID == selectedID then selected = index; break end end end
    self.selected = selected; self:Select(self.selected)
end

function ResultList:InvalidateRow(row)
    if not row then return false end
    local index = row.index
    clearRow(row)
    if index and self.items[index + self.offset] then self.items[index + self.offset] = false end
    if index == self.selected then
        local nextIndex
        for candidate = index + 1, #self.rows do if self.rows[candidate]:IsShown() then nextIndex = candidate; break end end
        if not nextIndex then for candidate = index - 1, 1, -1 do if self.rows[candidate]:IsShown() then nextIndex = candidate; break end end end
        self.selected = nextIndex or 1
        if nextIndex then self:Select(nextIndex) end
    end
    return true
end

function ResultList:Select(index)
    index = math.max(1, math.min(index or 1, #self.rows))
    if not self.rows[index]:IsShown() then
        local direction, candidate = index >= (self.selected or 1) and 1 or -1, index
        repeat candidate = candidate + direction until candidate < 1 or candidate > #self.rows or self.rows[candidate]:IsShown()
        if candidate < 1 or candidate > #self.rows then return end
        index = candidate
    end
    self.selected = index
    for rowIndex = 1, #self.rows do
        local row, selected = self.rows[rowIndex], self.rows[rowIndex]:IsShown() and rowIndex == index
        if row._selected ~= selected then row._selected = selected; renderRowState(row) end
    end
end

function ResultList:GetSelected()
    local row = self.rows[self.selected]
    return row and row:IsShown() and row.item or nil
end

function ResultList:Move(delta)
    local direction, remaining, index = (delta or 0) < 0 and -1 or 1, math.abs(delta or 0), self.selected
    if remaining == 0 then return self:GetSelected() end
    while remaining > 0 do
        repeat index = index + direction until index < 1 or index > #self.rows or self.rows[index]:IsShown()
        if index < 1 or index > #self.rows then
            if self:Scroll(direction) then
                self:Select(direction > 0 and #self.rows or 1)
                return self:GetSelected()
            end
            break
        end
        remaining = remaining - 1
    end
    if index >= 1 and index <= #self.rows and self.rows[index]:IsShown() then self:Select(index) end
    return self:GetSelected()
end

function ResultList:Scroll(delta)
    if InCombatLockdown and InCombatLockdown() then return false end
    local offset = math.max(0, math.min(self.offset + delta, math.max(0, #self.items - #self.rows)))
    if offset == self.offset then return false end
    if not self.controller or not self.controller.ApplyResults then return false end
    return self.controller:ApplyResults(self.items, self.generation, self.session, offset)
end

function ResultList:ActivateSelected()
    local row = self.rows[self.selected]
    if row and row:IsShown() and self.controller then self.controller:ActivateRow(row) end
end

Lychee.UI.ResultList = ResultList
