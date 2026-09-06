local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ResultList = {}
ResultList.__index = ResultList

local DEFAULT_ROWS = 6
local EMPTY_ITEMS = {}
local UI_LOCALE = GetLocale and GetLocale() or "enUS"
local UI_CHINESE = UI_LOCALE == "zhCN" or UI_LOCALE == "zhTW"
local MATCH_FIELD_NAMES = UI_CHINESE and {
    title = "名称", alias = "别名", description = "描述", keywords = "关键词", tokens = "关键词", filter = "分类",
} or {
    title = "name", alias = "alias", description = "description", keywords = "keyword", tokens = "keyword", filter = "filter",
}
local MATCH_TYPE_NAMES = UI_CHINESE and {
    exact = "精确", prefix = "前缀", substring = "包含", fuzzy = "模糊", token = "关键词", filter = "筛选",
} or {
    exact = "exact", prefix = "prefix", substring = "contains", fuzzy = "fuzzy", token = "keyword", filter = "filter",
}

local FALLBACK = {
    row = { 0.075, 0.078, 0.09, 0.96 }, rowHover = { 0.105, 0.108, 0.122, 0.98 },
    rowSelected = { 0.145, 0.105, 0.115, 0.98 }, outline = { 0.30, 0.19, 0.21, 0.85 },
    accent = { 0.91, 0.20, 0.30, 1 }, action = { 0.13, 0.135, 0.15, 1 },
    actionHover = { 0.20, 0.205, 0.23, 1 }, text = { 0.96, 0.945, 0.91, 1 },
    muted = { 0.62, 0.63, 0.67, 1 }, dim = { 0.45, 0.46, 0.50, 1 },
}
local THEME_KEY = {
    row = "surface", rowHover = "surfaceHover", rowSelected = "surfaceSelected", rowPressed = "surface",
    outline = "borderStrong", action = "surfaceHover", actionHover = "surfaceSelected", muted = "textMuted", dim = "textDim",
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
    return item and item.categoryID or (type(category) == "table" and category.id)
end

local function evidenceText(item)
    local evidence = item and item.evidence
    if type(evidence) ~= "table" then return "" end
    local field = MATCH_FIELD_NAMES[tostring(evidence.matchedField or "")] or ""
    local matchType = MATCH_TYPE_NAMES[tostring(evidence.matchType or "")] or ""
    if field == "" and matchType == "" then return "" end
    local detail = matchType ~= "" and (field == "" and matchType or field .. " · " .. matchType) or field
    local confidence = tonumber(item.confidence)
    if confidence then return (UI_CHINESE and "匹配 " or "Match ") .. detail .. string.format(" %.0f%%", confidence * 100) end
    return (UI_CHINESE and "匹配 " or "Match ") .. detail
end

local function sourceText(item)
    if type(item) ~= "table" then return "" end
    if type(item.sourceLabel) == "string" and item.sourceLabel ~= "" then return item.sourceLabel end
    if type(item.sourceTitle) == "string" and item.sourceTitle ~= "" then return item.sourceTitle end
    return tostring(item.source or ""):sub(1, 7) == "builtin" and (UI_CHINESE and "Lychee 内置" or "Lychee built-in")
        or (UI_CHINESE and "第三方插件" or "Extension")
end

local function rowTooltipDetail(item)
    if type(item) ~= "table" then return "" end
    local parts, description = {}, item.description or item.summary or item.subtext
    if type(description) == "string" and description ~= "" then parts[#parts + 1] = description end
    local evidence = evidenceText(item)
    if evidence ~= "" then parts[#parts + 1] = evidence end
    local source = sourceText(item)
    if source ~= "" then parts[#parts + 1] = source end
    return table.concat(parts, "\n")
end

local function hideTooltip()
    if GameTooltip and type(GameTooltip.Hide) == "function" then GameTooltip:Hide() end
end

local function showTooltip(owner, title, detail)
    if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if type(GameTooltip.SetText) == "function" then GameTooltip:SetText(title or "") end
    if detail and detail ~= "" and detail ~= title and type(GameTooltip.AddLine) == "function" then GameTooltip:AddLine(detail, 0.78, 0.78, 0.82, true) end
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
    local background = row._pressed and "rowPressed" or (row._selected and "rowSelected" or (row._hovered and "rowHover" or "row"))
    setTextureColor(row.bg, background)
    setShown(row.accent, row._selected == true)
    setShown(row.outline, row._hovered == true and row._selected ~= true)
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

function ResultList:Create(parent, controller)
    local theme = Lychee.UI and Lychee.UI.Theme
    local metrics = theme and theme.Metrics or {}
    local rows, rowHeight, rowGap = metrics.resultRows or DEFAULT_ROWS, metrics.rowHeight or 52, metrics.rowGap or 4
    local iconSize = metrics.iconSize or 32
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10); frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    frame:SetHeight(rows * rowHeight + (rows - 1) * rowGap)
    local self = setmetatable({ frame = frame, controller = controller, rows = {}, items = EMPTY_ITEMS, selected = 1,
        rowHeight = rowHeight, rowGap = rowGap, maxRows = rows }, ResultList)

    for index = 1, rows do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(index - 1) * (rowHeight + rowGap))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(index - 1) * (rowHeight + rowGap))
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
        row.primaryTarget:SetPoint("TOPLEFT", row, "TOPLEFT", 56, 1); row.primaryTarget:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -46, -1); row.primaryTarget:RegisterForClicks("LeftButtonUp")
        row.primaryTarget:SetScript("OnClick", function(button)
            local owner = button:GetParent(); self:SelectRow(owner)
            if self.controller then self.controller:ActivateRow(owner) end
        end)
        row.primaryTarget:SetScript("OnEnter", function(button)
            local owner = button:GetParent(); self:SetHover(owner, true); showTooltip(button, owner.title:GetText(), rowTooltipDetail(owner.item))
        end)
        row.primaryTarget:SetScript("OnLeave", function(button) self:SetHover(button:GetParent(), false); hideTooltip() end)

        row.category = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.category:SetPoint("TOPLEFT", row, "TOPLEFT", 58, -7); row.category:SetWidth(42); row.category:SetJustifyH("LEFT"); singleLine(row.category)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 103, -6); row.title:SetPoint("RIGHT", row, "RIGHT", -82, 0); row.title:SetHeight(16); row.title:SetJustifyH("LEFT"); singleLine(row.title); setTextColor(row.title, "text")
        row.subtext = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.subtext:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2); row.subtext:SetPoint("RIGHT", row, "RIGHT", -82, 0); row.subtext:SetHeight(13); row.subtext:SetJustifyH("LEFT"); singleLine(row.subtext); setTextColor(row.subtext, "muted")
        row.description = row.subtext
        row.primaryHint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.primaryHint:SetPoint("RIGHT", row, "RIGHT", -42, 0); row.primaryHint:SetWidth(34); row.primaryHint:SetJustifyH("RIGHT"); singleLine(row.primaryHint); setTextColor(row.primaryHint, "muted")

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
        row:SetScript("OnEnter", function(button) self:SetHover(button, true); showTooltip(button, button.title:GetText(), rowTooltipDetail(button.item)) end)
        row:SetScript("OnLeave", function(button) self:SetHover(button, false); hideTooltip() end)
        row._rendered = {}
        self.rows[index] = row
        clearRow(row)
    end
    return self
end

function ResultList:Resize(count)
    count = math.max(0, math.min(tonumber(count) or 0, self.maxRows or DEFAULT_ROWS))
    local height = count > 0 and (count * self.rowHeight + (count - 1) * self.rowGap) or 0
    if self.frame and self.frame.GetHeight and self.frame:GetHeight() ~= height then self.frame:SetHeight(height) end
    return height
end

function ResultList:Clear()
    hideTooltip()
    for index = 1, #self.rows do clearRow(self.rows[index]) end
    self.items = EMPTY_ITEMS; self.session, self.generation, self.selected = nil, nil, 1
end

function ResultList:SetItems(items, session, generation)
    local selectedRow = self.rows[self.selected or 1]
    local selectedID = selectedRow and selectedRow.stableID
    self.items, self.session, self.generation = items or EMPTY_ITEMS, session, generation
    local count = math.min(#self.items, #self.rows)
    self:Resize(count)
    for index = 1, count do
        local item, row = self.items[index], self.rows[index]
        row.item, row.index = item, index
        row.session, row.generation, row.extensionID, row.stableID = session, generation, extensionID(item), stableItemID(item)
        cachedText(row, "title", row.title, item.text)
        cachedText(row, "subtext", row.subtext, item.description or item.summary or item.subtext)
        cachedText(row, "category", row.category, categoryText(item))
        local colorID = categoryColorID(item)
        if row._categoryColorID ~= colorID then setCategoryTextColor(row.category, item); row._categoryColorID = colorID end
        local icon = item.icon
        if row._icon ~= icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(icon); row._icon = icon end
        setShown(row.icon, icon ~= nil)
        local interaction = item.interaction
        row.primaryAction, row.secondaryAction, row.dragDescriptor = primaryAction(interaction), secondaryAction(interaction), interaction and interaction.drag
        cachedText(row, "primaryHint", row.primaryHint, actionLabel(row.primaryAction))
        row.secondary.actionID, row.secondary.action, row.secondary.tooltip = row.secondaryAction and row.secondaryAction.id, row.secondaryAction, actionLabel(row.secondaryAction)
        setShown(row.dragger, row.dragDescriptor ~= nil)
        renderRowState(row); setShown(row, true)
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
    if index and self.items[index] then self.items[index] = false end
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
