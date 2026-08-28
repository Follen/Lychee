local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ResultList = {}
ResultList.__index = ResultList

local ROWS = 6
local ROW_HEIGHT = 56
local ROW_GAP = 4
local ACTIONS = 4
local EMPTY_ITEMS = {}

local FALLBACK = {
    row = { 0.075, 0.078, 0.09, 0.96 },
    rowHover = { 0.105, 0.108, 0.122, 0.98 },
    rowSelected = { 0.145, 0.105, 0.115, 0.98 },
    outline = { 0.30, 0.19, 0.21, 0.85 },
    accent = { 0.91, 0.20, 0.30, 1 },
    badge = { 0.16, 0.17, 0.20, 1 },
    action = { 0.13, 0.135, 0.15, 1 },
    actionHover = { 0.20, 0.205, 0.23, 1 },
    actionPressed = { 0.10, 0.105, 0.12, 1 },
    actionDisabled = { 0.09, 0.092, 0.10, 0.62 },
    text = { 0.96, 0.945, 0.91, 1 },
    muted = { 0.62, 0.63, 0.67, 1 },
    dim = { 0.45, 0.46, 0.50, 1 },
}

local THEME_KEY = {
    row = "surface",
    rowHover = "surfaceHover",
    rowSelected = "surfaceSelected",
    outline = "borderStrong",
    badge = "surfaceHover",
    actionPressed = "surface",
    actionDisabled = "disabled",
    muted = "textMuted",
    dim = "textDim",
}

local function color(name)
    local theme = Lychee.UI and Lychee.UI.Theme
    local colors = theme and (theme.colors or theme.Colors or theme)
    local value = colors and colors[THEME_KEY[name] or name]
    if type(value) == "table" then
        return value[1] or value.r or 1, value[2] or value.g or 1,
            value[3] or value.b or 1, value[4] or value.a or 1
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
    local theme = Lychee.UI and Lychee.UI.Theme
    local key = THEME_KEY[name] or name
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
    local categoryID = item and item.categoryID or (type(category) == "table" and category.id)
    local value = categoryID and theme and type(theme.GetCategoryColor) == "function" and theme:GetCategoryColor(categoryID)
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

local function setTextureColor(texture, name)
    if not texture or type(texture.SetColorTexture) ~= "function" then return end
    local theme = Lychee.UI and Lychee.UI.Theme
    local key = THEME_KEY[name] or name
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

local function extensionID(item)
    return item and (item._ext or (item.command and item.command._ext))
end

local function stableItemID(item)
    if not item then return nil end
    return item.stableID or item.id or item.itemID or item
end

local function cachedText(row, key, fontString, value)
    value = value or ""
    local rendered = row._rendered
    if not rendered then
        rendered = {}
        row._rendered = rendered
    end
    if rendered[key] == value then return end
    setText(fontString, value)
    rendered[key] = value
end

local function categoryText(item)
    local categoryValue = item.category or item.categoryLabel
    local category = categoryValue
    if type(categoryValue) == "table" then
        local title = categoryValue.title
        if type(title) == "table" then
            local activeLocale = GetLocale and GetLocale() or "enUS"
            category = title[activeLocale] or title.default or title.enUS or categoryValue.id
        else
            category = title or categoryValue.id
        end
    end
    return category or "其他"
end

local function categoryColorID(item)
    local category = item and item.searchRecord and item.searchRecord.category
    return item and item.categoryID or (type(category) == "table" and category.id)
end

local function evidenceText(item)
    local evidence = item and item.evidence
    if type(evidence) ~= "table" then return "" end
    local field = tostring(evidence.matchedField or "")
    local matchType = tostring(evidence.matchType or "")
    if field == "" and matchType == "" then return "" end
    local confidence = tonumber(item.confidence)
    if confidence then return string.format("命中 %s/%s %.0f%%", field, matchType, confidence * 100) end
    return "命中 " .. field .. "/" .. matchType
end

local function hideTooltip()
    if GameTooltip and type(GameTooltip.Hide) == "function" then GameTooltip:Hide() end
end

local function showTooltip(owner, title, detail)
    if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if type(GameTooltip.SetText) == "function" then GameTooltip:SetText(title or "") end
    if detail and detail ~= "" and detail ~= title and type(GameTooltip.AddLine) == "function" then
        GameTooltip:AddLine(detail, 0.78, 0.78, 0.82, true)
    end
    if type(GameTooltip.Show) == "function" then GameTooltip:Show() end
end

local function renderRowState(row)
    local background = row._selected and "rowSelected" or (row._hovered and "rowHover" or "row")
    setTextureColor(row.bg, background)
    setShown(row.accent, row._selected == true)
    setShown(row.outline, row._selected == true)
end

local function renderActionState(button, state)
    if not button._enabled then state = "disabled" end
    button._state = state
    local key = state == "hover" and "actionHover"
        or state == "pressed" and "actionPressed"
        or state == "disabled" and "actionDisabled"
        or "action"
    setTextureColor(button.bg, key)
    setTextColor(button.label, state == "disabled" and "dim" or "text")
end

local function clearAction(button)
    button.actionID, button.action, button.tooltip = nil, nil, nil
    button._enabled = false
    setText(button.label, "")
    renderActionState(button, "disabled")
    setShown(button, false)
end

local function clearRow(row)
    row.item, row.index, row.session, row.generation, row.extensionID = nil, nil, nil, nil, nil
    row.stableID = nil
    row._hovered, row._selected = false, false
    cachedText(row, "title", row.title, "")
    cachedText(row, "subtext", row.subtext, "")
    cachedText(row, "category", row.category, "")
    cachedText(row, "source", row.source, "")
    cachedText(row, "evidence", row.evidence, "")
    if row._icon ~= nil and row.icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(nil) end
    row._icon = nil
    if row._categoryColorID ~= nil then setTextColor(row.category, "muted") end
    row._categoryColorID = nil
    setShown(row.icon, false)
    setShown(row.categoryBG, false)
    for index = 1, ACTIONS do clearAction(row.actions[index]) end
    row.dragger.dragDescriptor = nil
    row.dragger._enabled = false
    setShown(row.dragger, false)
    renderRowState(row)
    setShown(row, false)
end

local function createAction(row, self, index)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(42, 28)
    button:SetPoint("RIGHT", row, "RIGHT", -((ACTIONS - index) * 46 + 10), 0)
    button:RegisterForClicks("LeftButtonUp")
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetAllPoints()
    button.label:SetJustifyH("CENTER")
    singleLine(button.label)
    button:SetScript("OnClick", function(clicked)
        if clicked._enabled and clicked.actionID and self.controller then
            self.controller:ActivateRowAction(clicked:GetParent(), clicked.actionID)
        end
    end)
    button:SetScript("OnEnter", function(entered)
        renderActionState(entered, "hover")
        showTooltip(entered, entered.tooltip or (entered.action and entered.action.title), entered.action and entered.action.description)
    end)
    button:SetScript("OnLeave", function(left)
        hideTooltip()
        renderActionState(left, "normal")
    end)
    button:SetScript("OnMouseDown", function(pressed)
        if pressed._enabled then renderActionState(pressed, "pressed") end
    end)
    button:SetScript("OnMouseUp", function(released) renderActionState(released, "hover") end)
    clearAction(button)
    return button
end

-- Defined before Create so an early cursor transition cannot observe a partial method table.
function ResultList:SelectRow(row)
    if row and row.index then self:Select(row.index) end
end

function ResultList:Create(parent, controller)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    frame:SetHeight(ROWS * ROW_HEIGHT + (ROWS - 1) * ROW_GAP)
    local self = setmetatable({ frame = frame, controller = controller, rows = {}, items = EMPTY_ITEMS, selected = 1 }, ResultList)

    for index = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + ROW_GAP))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(index - 1) * (ROW_HEIGHT + ROW_GAP))
        row:RegisterForClicks("LeftButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.outline = CreateFrame("Frame", nil, row)
        row.outline:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
        row.outline:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
        row.outline.edges = {}
        for edgeIndex = 1, 4 do
            local edge = row.outline:CreateTexture(nil, "BORDER")
            if edgeIndex == 1 then
                edge:SetPoint("TOPLEFT", row.outline, "TOPLEFT", 0, 0)
                edge:SetPoint("TOPRIGHT", row.outline, "TOPRIGHT", 0, 0)
                edge:SetHeight(1)
            elseif edgeIndex == 2 then
                edge:SetPoint("BOTTOMLEFT", row.outline, "BOTTOMLEFT", 0, 0)
                edge:SetPoint("BOTTOMRIGHT", row.outline, "BOTTOMRIGHT", 0, 0)
                edge:SetHeight(1)
            elseif edgeIndex == 3 then
                edge:SetPoint("TOPLEFT", row.outline, "TOPLEFT", 0, 0)
                edge:SetPoint("BOTTOMLEFT", row.outline, "BOTTOMLEFT", 0, 0)
                edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT", row.outline, "TOPRIGHT", 0, 0)
                edge:SetPoint("BOTTOMRIGHT", row.outline, "BOTTOMRIGHT", 0, 0)
                edge:SetWidth(1)
            end
            setTextureColor(edge, "outline")
            row.outline.edges[edgeIndex] = edge
        end
        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetWidth(3)
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        setTextureColor(row.accent, "accent")

        row.categoryBG = row:CreateTexture(nil, "ARTWORK")
        row.categoryBG:SetSize(50, 18)
        row.categoryBG:SetPoint("LEFT", row, "LEFT", 10, 0)
        setTextureColor(row.categoryBG, "badge")
        row.category = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.category:SetPoint("CENTER", row.categoryBG, "CENTER", 0, 0)
        row.category:SetWidth(44)
        row.category:SetJustifyH("CENTER")
        singleLine(row.category)
        setTextColor(row.category, "muted")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(34, 34)
        row.icon:SetPoint("LEFT", row, "LEFT", 70, 0)

        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 114, -6)
        row.title:SetPoint("RIGHT", row, "RIGHT", -200, 0)
        row.title:SetHeight(16)
        row.title:SetJustifyH("LEFT")
        singleLine(row.title)
        setTextColor(row.title, "text")

        row.subtext = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.subtext:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -1)
        row.subtext:SetPoint("RIGHT", row, "RIGHT", -200, 0)
        row.subtext:SetHeight(13)
        row.subtext:SetJustifyH("LEFT")
        singleLine(row.subtext)
        setTextColor(row.subtext, "muted")
        row.description = row.subtext

        row.evidence = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.evidence:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 114, 5)
        row.evidence:SetPoint("RIGHT", row, "RIGHT", -320, 0)
        row.evidence:SetHeight(11)
        row.evidence:SetJustifyH("LEFT")
        singleLine(row.evidence)
        setTextColor(row.evidence, "dim")

        row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.source:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -200, 5)
        row.source:SetWidth(116)
        row.source:SetHeight(11)
        row.source:SetJustifyH("RIGHT")
        singleLine(row.source)
        setTextColor(row.source, "dim")

        row.actions = {}
        for actionIndex = 1, ACTIONS do row.actions[actionIndex] = createAction(row, self, actionIndex) end

        row.dragger = CreateFrame("Button", nil, row)
        row.dragger:SetSize(28, 28)
        row.dragger:SetPoint("RIGHT", row, "RIGHT", -198, 0)
        row.dragger:RegisterForDrag("LeftButton")
        row.dragger.bg = row.dragger:CreateTexture(nil, "BACKGROUND")
        row.dragger.bg:SetAllPoints()
        setTextureColor(row.dragger.bg, "action")
        row.dragger.label = row.dragger:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.dragger.label:SetAllPoints()
        row.dragger.label:SetJustifyH("CENTER")
        setText(row.dragger.label, "拖")
        setTextColor(row.dragger.label, "muted")
        row.dragger:SetScript("OnDragStart", function(button)
            if button._enabled and self.controller then self.controller:BeginRowDrag(button:GetParent()) end
        end)
        row.dragger:SetScript("OnEnter", function(button)
            setTextureColor(button.bg, "actionHover")
            showTooltip(button, "拖到动作条", "按住并拖动此技能")
        end)
        row.dragger:SetScript("OnLeave", function(button)
            hideTooltip()
            setTextureColor(button.bg, "action")
        end)

        row:SetScript("OnClick", function(button)
            self:SelectRow(button)
            if self.controller then self.controller:ActivateRow(button) end
        end)
        row:SetScript("OnEnter", function(button)
            button._hovered = true
            renderRowState(button)
        end)
        row:SetScript("OnLeave", function(button)
            button._hovered = false
            renderRowState(button)
        end)
        row._rendered = {}
        self.rows[index] = row
        clearRow(row)
    end
    return self
end

function ResultList:Clear()
    hideTooltip()
    for index = 1, #self.rows do clearRow(self.rows[index]) end
    self.items = EMPTY_ITEMS
    self.session, self.generation = nil, nil
    self.selected = 1
end

function ResultList:SetItems(items, session, generation)
    local selectedRow = self.rows[self.selected or 1]
    local selectedID = selectedRow and selectedRow.stableID
    self.items = items or EMPTY_ITEMS
    self.session, self.generation = session, generation
    local count = math.min(#self.items, #self.rows)
    for index = 1, count do
        local item, row = self.items[index], self.rows[index]
        row.item, row.index = item, index
        row.session, row.generation, row.extensionID = session, generation, extensionID(item)
        row.stableID = stableItemID(item)
        cachedText(row, "title", row.title, item.text)
        local detail = item.description or item.summary
        if not detail or detail == "" then detail = item.subtext end
        cachedText(row, "subtext", row.subtext, detail)
        local category = categoryText(item)
        cachedText(row, "category", row.category, category)
        local colorID = categoryColorID(item)
        if row._categoryColorID ~= colorID then
            setCategoryTextColor(row.category, item)
            row._categoryColorID = colorID
        end
        setShown(row.categoryBG, category ~= "")
        cachedText(row, "source", row.source, item.sourceLabel or item.source or row.extensionID)
        cachedText(row, "evidence", row.evidence, evidenceText(item))
        local icon = item.icon or nil
        if row._icon ~= icon and type(row.icon.SetTexture) == "function" then
            row.icon:SetTexture(icon)
            row._icon = icon
        end
        setShown(row.icon, icon ~= nil)

        local interaction = item.interaction
        local actions = interaction and interaction.actions
        for actionIndex = 1, ACTIONS do
            local button, action = row.actions[actionIndex], actions and actions[actionIndex]
            if action then
                local wasEnabled = button._enabled
                button.actionID, button.action = action.id, action
                button.tooltip = action.tooltip or action.title
                button._enabled = action.enabled ~= false and action.disabled ~= true and action.id ~= nil
                setText(button.label, action.title or action.label or action.id)
                if not button._enabled then
                    if button._state ~= "disabled" then renderActionState(button, "disabled") end
                elseif not wasEnabled or button._state == "disabled" then
                    renderActionState(button, "normal")
                end
                setShown(button, true)
            else
                clearAction(button)
            end
        end

        local drag = interaction and interaction.drag
        row.dragger.dragDescriptor = drag
        row.dragger._enabled = drag ~= nil
        setShown(row.dragger, drag ~= nil)
        setShown(row, true)
    end
    for index = count + 1, #self.rows do clearRow(self.rows[index]) end

    local selected = math.max(1, math.min(self.selected or 1, math.max(count, 1)))
    if selectedID ~= nil then
        for index = 1, count do
            if self.rows[index].stableID == selectedID then
                selected = index
                break
            end
        end
    end
    self.selected = selected
    self:Select(self.selected)
end

function ResultList:InvalidateRow(row)
    if not row then return false end
    local index = row.index
    clearRow(row)
    if index and self.items[index] then self.items[index] = false end
    if index == self.selected then
        local nextIndex
        for candidate = index + 1, #self.rows do
            if self.rows[candidate]:IsShown() then nextIndex = candidate; break end
        end
        if not nextIndex then
            for candidate = index - 1, 1, -1 do
                if self.rows[candidate]:IsShown() then nextIndex = candidate; break end
            end
        end
        self.selected = nextIndex or 1
        if nextIndex then self:Select(nextIndex) end
    end
    return true
end

function ResultList:Select(index)
    index = math.max(1, math.min(index or 1, #self.rows))
    if not self.rows[index]:IsShown() then
        local direction = index >= (self.selected or 1) and 1 or -1
        local candidate = index
        repeat candidate = candidate + direction
        until candidate < 1 or candidate > #self.rows or self.rows[candidate]:IsShown()
        if candidate < 1 or candidate > #self.rows then return end
        index = candidate
    end
    self.selected = index
    for rowIndex = 1, #self.rows do
        local row = self.rows[rowIndex]
        local selected = row:IsShown() and rowIndex == index
        if row._selected ~= selected then
            row._selected = selected
            renderRowState(row)
        end
    end
end

function ResultList:GetSelected()
    local row = self.rows[self.selected]
    return row and row:IsShown() and row.item or nil
end

function ResultList:Move(delta)
    local direction = (delta or 0) < 0 and -1 or 1
    local remaining = math.abs(delta or 0)
    local index = self.selected
    if remaining == 0 then return self:GetSelected() end
    while remaining > 0 do
        repeat index = index + direction until index < 1 or index > #self.rows or self.rows[index]:IsShown()
        if index < 1 or index > #self.rows then break end
        remaining = remaining - 1
    end
    if index >= 1 and index <= #self.rows and self.rows[index]:IsShown() then self:Select(index) end
    return self:GetSelected()
end

function ResultList:ActivateSelected()
    local row = self.rows[self.selected]
    if row and row:IsShown() and self.controller then self.controller:ActivateRow(row) end
end

Lychee.UI.ResultList = ResultList
