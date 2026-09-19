local EMPTY_UI_PROPS = {}
local L = _G.LycheeInternal.Locale
local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ResultList = {}
ResultList.__index = ResultList

local Theme = Lychee.UI.Theme
local EMPTY_ITEMS = {}
local UI_LOCALE = GetLocale and GetLocale() or "enUS"
local UI_CHINESE = UI_LOCALE == "zhCN" or UI_LOCALE == "zhTW"

local function setText(fontString, value)
    value = value or ""
    if fontString and fontString:GetText() ~= value then fontString:SetText(value) end
end

local function setShown(object, shown)
    if object and type(object.IsShown) == "function" and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function cropIcon(texture)
    if texture and type(texture.SetTexCoord) == "function" then texture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
end

local function extensionID(item) return item and (item._ext) end
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

local function labelText(value)
    if type(value) == "table" then value = L:Resolve(value) end
    if type(value) == "string" and value ~= "" then return value end
end

local function kindText(item)
    local record = item and item.searchRecord
    local title = labelText(item and item.kindTitle) or labelText(record and record.kindTitle)
    if title then return title end
    local category = item and (item.category or item.categoryLabel) or record and record.category
    if type(category) == "table" then category = category.title or category.id end
    return labelText(category) or labelText(item and item.sourceTitle) or (UI_CHINESE and L["内容"] or "Content")
end

local function hideTooltip() Lychee.UI.Components:HideTooltip() end

local scoreHeaders
local function showTooltip(owner,title,detail)
    local kind, description, clickHint, dragHint
    if type(detail) == "table" then
        kind = kindText(detail)
        description = detail.description or detail.summary or detail.subtext
        local interaction = detail.interaction
        local actions = interaction and interaction.actions
        local primary = type(actions) == "table" and actions[1]
        if primary and interaction.primaryActionID then
            for index = 1, #actions do
                if actions[index].id == interaction.primaryActionID then primary = actions[index]; break end
            end
        end
        if actionEnabled(primary) then
            clickHint = (UI_CHINESE and L["点击  "] or "Click  ") .. actionLabel(primary)
        end
        if interaction and interaction.drag then
            local drag = interaction.drag
            local title = drag.title or (drag.type == "spell" and (UI_CHINESE and L["放到动作条"] or "Place on an action bar")) or (UI_CHINESE and L["拖动"] or "Drag")
            dragHint = (UI_CHINESE and L["拖动  "] or "Drag  ") .. title
        end
    elseif detail and detail ~= "" and detail ~= title then
        description = detail
    end
    local rows=type(detail)=="table" and detail.searchRecord and detail.searchRecord.tooltipRows
    if rows and not scoreHeaders then scoreHeaders={L["当季副本"],L["成绩"],L["分数"]} end
    Lychee.UI.Components:ShowTooltip(owner,{title=title,meta=kind,description=description,hint=clickHint,dragHint=dragHint,
        rows=rows,headers=scoreHeaders})
end

function ResultList:HideTooltip() hideTooltip() end
function ResultList:ShowTextTooltip(title, owner) showTooltip(owner, title) end

local function primaryAction(interaction)
    local actions = interaction and interaction.actions
    if type(actions) ~= "table" then return nil end
    if type(interaction.primaryActionID) == "string" then
        for index = 1, #actions do if actions[index].id == interaction.primaryActionID then return actions[index] end end
    end
    return actions[1]
end

local function renderRowState(row)
    if Lychee.UI.Motion then
        Theme:SetColorTexture(row.bg,"surfaceSelected")
        Lychee.UI.Motion:Selection(row.bg,row._selected==true)
        Lychee.UI.Motion:Selection(row.accent,row._selected==true)
    else
        Theme:SetColorTexture(row.bg,row._selected and "surfaceSelected" or "surface")
        setShown(row.accent,row._selected==true)
    end
    setShown(row.dragHighlight, row._selected and row._dragHovered == true or false)
end

local function clearRow(row)
    row.snapshotOwner = nil
    _G.LycheeInternal.InteractionBinding:Bind(row, nil, nil, nil)
    row._matchTitle,row._matchSubtitle,row._matchQuery=nil,nil,nil
    row._matchRenderedTitle,row._matchRenderedSubtitle=nil,nil
    if Lychee.UI.Motion then
        Lychee.UI.Motion:Cancel(row.title,true);Lychee.UI.Motion:Cancel(row.subtext,true)
        Lychee.UI.Motion:Cancel(row.bg,true);Lychee.UI.Motion:Cancel(row.accent,true)
        if row.bg then row.bg._lycheeSelectedMotion=nil end
        if row.accent then row.accent._lycheeSelectedMotion=nil end
    end
    row.item, row.index, row.session, row.generation, row.extensionID, row.stableID = nil, nil, nil, nil, nil, nil
    row.primaryAction, row.dragDescriptor = nil, nil
    row._hovered, row._dragHovered, row._selected, row._pressed = false, false, false, false
    if row.textProps then
        row.textProps.title,row.textProps.subtext,row.textProps.category=nil,nil,nil
        if row.ui.active then row.ui:Update(EMPTY_UI_PROPS);row.ui:Release("unbind") end
    else
        -- Home tiles share action invalidation with results but keep their own
        -- native layout and do not own a result-text binding view.
        cachedText(row,"title",row.title,"");cachedText(row,"subtext",row.subtext,"");cachedText(row,"category",row.category,"")
    end
    cachedText(row, "primaryHint", row.primaryHint, "")
    if row._icon ~= nil and row.icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(nil) end
    row._icon = nil
    setShown(row.icon, false); setShown(row.dragger, false); renderRowState(row); setShown(row, false)
end

function ResultList:SelectRow(row)
    if self.frozen then return end
    if row and row.index then self:Select(row.index) end
end

function ResultList:SetHover(row, hovered)
    if self.frozen then return end
    if not row or row._hovered == (hovered == true) then return end
    row._hovered = hovered == true
    if hovered then self:SelectRow(row) end
    renderRowState(row)
end

function ResultList:ShowItemTooltip(item, owner)
    if item then showTooltip(owner, item.text, item) end
end

function ResultList:ShowActionTooltip(action, owner)
    showTooltip(owner, actionLabel(action), UI_CHINESE and L["点击施放"] or "Click to cast")
end

function ResultList:ShowTooltip(row, owner)
    showTooltip(owner or row, row.item and row.item.text or row.title:GetText(), row.item)
end

function ResultList:Create(parent, controller)
    local metrics = Theme.Metrics
    local columns = metrics.resultColumns
    local tiles, rowHeight, rowGap = metrics.resultTiles, metrics.rowHeight, metrics.rowGap
    local tileWidth = metrics.resultTileWidth - 12
    local iconSize = metrics.iconSize
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetScript("OnHide", hideTooltip)
    local inset=metrics.listInset
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -10); frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -10)
    local gridRows = math.ceil(tiles / columns)
    frame:SetHeight(gridRows * rowHeight + math.max(0, gridRows - 1) * rowGap)
    local self = setmetatable({ frame = frame, controller = controller, rows = {}, items = EMPTY_ITEMS, selected = 1,
        rowHeight = rowHeight, rowGap = rowGap, tileWidth = tileWidth, gridColumns = columns, maxRows = tiles, offset = 0 }, ResultList)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    frame:SetScript("OnMouseWheel", function(_, delta) self:Scroll(delta > 0 and -1 or 1) end)
    self.scrollbar = Lychee.UI.Components:CreateScrollbar(frame, function(value)
        self:Scroll(math.floor(value + 0.5) - self.offset)
    end)
    -- Keep the scrollbar in the content gutter, outside the indented rows.
    self.scrollbar.frame:ClearAllPoints()
    self.scrollbar.frame:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-12)
    self.scrollbar.frame:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",inset,2)

    for index = 1, tiles do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(tileWidth, rowHeight)
        row.ownerView = self
        local binding = _G.LycheeInternal.InteractionBinding
        binding:Attach(row, row)
        local column = (index - 1) % columns
        local gridRow = math.floor((index - 1) / columns)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", column * (tileWidth + rowGap), -gridRow * (rowHeight + rowGap))
        row:RegisterForClicks("LeftButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetPoint("TOPLEFT",row,"TOPLEFT",0,-metrics.selectionInsetY)
        row.bg:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,metrics.selectionInsetY)
        row.accent = row:CreateTexture(nil, "ARTWORK"); row.accent:SetSize(metrics.selectionWidth, metrics.selectionHeight); row.accent:SetPoint("LEFT", row, "LEFT", 0, 0); Theme:SetColorTexture(row.accent, "accent")

        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(iconSize, iconSize); row.icon:SetPoint("LEFT", row, "LEFT", metrics.listIconInset, 0)
        row.dragHighlight = row:CreateTexture(nil, "BORDER"); row.dragHighlight:SetSize(iconSize + 4, iconSize + 4); row.dragHighlight:SetPoint("CENTER", row.icon, "CENTER"); Theme:SetColorTexture(row.dragHighlight, "surfaceSelected")
        row.dragger = CreateFrame("Button", nil, row); row.dragger:SetSize(iconSize + 6, iconSize + 6); row.dragger:SetPoint("CENTER", row.icon, "CENTER")
        binding:Attach(row.dragger, row)
        row.dragger:SetScript("OnDragStart", function(button)
            if not binding:Consume(button, button:GetParent(), "LeftButton") then return end
            if button:GetParent().dragDescriptor and self.controller then self.controller:BeginRowDrag(button:GetParent()) end
        end)
        row.dragger:SetScript("OnEnter", function(button)
            if self.controller and self.controller.DeferRowHover and self.controller:DeferRowHover(button) then return end
            local owner = button:GetParent(); owner._dragHovered = true; self:SetHover(owner, true); renderRowState(owner)
            showTooltip(button, owner.item and owner.item.text, owner.item)
        end)
        row.dragger:SetScript("OnLeave", function(button)
            local owner = button:GetParent(); owner._dragHovered = false; self:SetHover(owner, false); renderRowState(owner); hideTooltip()
        end)

        row.primaryTarget = CreateFrame("Button", nil, row)
        row.primaryTarget:SetAllPoints(row); row.primaryTarget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        binding:Attach(row.primaryTarget, row)
        row.primaryTarget:SetScript("OnClick", function(button, mouseButton)
            if not binding:Consume(button, button:GetParent(), mouseButton) then return end
            local owner = button:GetParent(); self:SelectRow(owner)
            if mouseButton == "RightButton" and self.controller and self.controller.ShowRowActions then self.controller:ShowRowActions(owner); return end
            if self.controller then self.controller:ActivateRow(owner) end
        end)
        row.primaryTarget:SetScript("OnEnter", function(button)
            if self.controller and self.controller.DeferRowHover and self.controller:DeferRowHover(button) then return end
            local owner = button:GetParent(); self:SetHover(owner, true); showTooltip(button, owner.item and owner.item.text, owner.item)
        end)
        row.primaryTarget:SetScript("OnLeave", function(button) self:SetHover(button:GetParent(), false); hideTooltip() end)

        row.ui=Lychee.UI:Create(row,{type="Fragment",children={
            {type="Text",key="category",props={role="meta",color="textDim",width=metrics.sourceLabelWidth,height=16,justifyH="RIGHT",maxLines=1,wordWrap=false,nonSpaceWrap=false,point={"RIGHT",row,"RIGHT",-12,0}},bind={text="category"}},
            {type="Text",key="title",props={role="body",color="text",height=18,maxLines=1,wordWrap=false,nonSpaceWrap=false,points={{"TOPLEFT",row,"TOPLEFT",metrics.listTitleInset,-6},{"RIGHT","category","LEFT",-14,0}}},bind={text="title"}},
            {type="Text",key="subtext",props={role="body",color="textMuted",height=14,maxLines=1,wordWrap=false,nonSpaceWrap=false,points={{"TOPLEFT","title","BOTTOMLEFT",0,-2},{"RIGHT","category","LEFT",-14,0}}},bind={text="subtext"}},
        }})
        row.textProps={}
        assert(row.ui:Update(EMPTY_UI_PROPS));row.category,row.title,row.subtext=row.ui:Get("category"),row.ui:Get("title"),row.ui:Get("subtext")
        row.description = row.subtext
        row.primaryHint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.primaryHint:Hide()

        row:SetScript("OnClick", function(button) if not binding:Consume(button, button, "LeftButton") then return end; self:SelectRow(button); if self.controller then self.controller:ActivateRow(button) end end)
        row:SetScript("OnMouseDown", function(button, mouseButton) binding:Press(button, button, mouseButton); button._pressed = true; renderRowState(button) end)
        row:SetScript("OnMouseUp", function(button) button._pressed = false; renderRowState(button) end)
        row:SetScript("OnEnter", function(button)
            if self.controller and self.controller.DeferRowHover and self.controller:DeferRowHover(button) then return end
            self:SetHover(button, true)
        end)
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
    count = math.max(0, math.min(tonumber(count) or 0, self.maxRows or Theme.Metrics.resultTiles))
    local gridRows = count > 0 and math.ceil(count / self.gridColumns) or 0
    local height = gridRows > 0 and (gridRows * self.rowHeight + (gridRows - 1) * self.rowGap) or 0
    if self.frame and self.frame.GetHeight and self.frame:GetHeight() ~= height then self.frame:SetHeight(height) end
    return height
end

-- Retain native text/texture regions only, never the previous result's capability.
function ResultList:FreezePresentation()
    if self.frozen then return end
    self.frozen = true
    hideTooltip()
    self.scrollbar:StopDrag(); self.scrollbar.frame:EnableMouse(false)
    Lychee.UI.Motion:Cancel(self.frame, true)
    self.frame:SetAlpha(0.8)
    local binding = _G.LycheeInternal.InteractionBinding
    local executor = _G.LycheeInternal.ResultActionExecutor
    for _, row in ipairs(self.rows) do
        row.snapshotOwner = row.extensionID
        binding:Bind(row, nil, nil, nil)
        binding:Cancel(row); binding:Cancel(row.primaryTarget); binding:Cancel(row.dragger)
        row.item, row.primaryAction, row.dragDescriptor = nil, nil, nil
        row.session, row.generation, row.extensionID = nil, nil, nil
        row._hovered, row._dragHovered, row._pressed = nil, nil, nil
        if executor then executor:ConfigureDragTarget(row.dragger, nil) end
        row:EnableMouse(false); row.primaryTarget:EnableMouse(false)
        row.dragger:Hide(); row.dragHighlight:Hide()
    end
    self.items = EMPTY_ITEMS
end

function ResultList:Clear()
    if self.frozen then
        self.frozen = nil
        self.frame:SetAlpha(1); self.scrollbar.frame:EnableMouse(true)
    end
    hideTooltip()
    for index = 1, #self.rows do clearRow(self.rows[index]) end
    self.items = EMPTY_ITEMS; self.session, self.generation, self.selected, self.offset = nil, nil, 1, 0
    self.scrollbar:SetRange(0, #self.rows, 0)
end

function ResultList:SetItems(items, session, generation, offset)
    local wasFrozen = self.frozen
    self.frozen = nil
    if wasFrozen then
        self.frame:SetAlpha(1); self.scrollbar.frame:EnableMouse(true)
        self.selected = 1
    end
    hideTooltip()
    local highlight=Lychee.UI.TextHighlight
    local controller=self.controller
    local raw=controller and controller.input and controller.input:GetText() or ""
    local query=_G.LycheeInternal.Search and _G.LycheeInternal.Search.Query
    local request=highlight and query and query:_BuildRequest(raw)
    local highlightQuery=request and request.normalized or raw
    local selectedRow = self.rows[self.selected or 1]
    local selectedID = not wasFrozen and selectedRow and selectedRow.stableID
    self.items, self.session, self.generation = items or EMPTY_ITEMS, session, generation
    self.offset = math.max(0, math.min(offset or 0, math.max(0, #self.items - #self.rows)))
    local count = math.min(#self.items - self.offset, #self.rows)
    self:Resize(count)
    self.scrollbar:SetRange(#self.items, #self.rows, self.offset)
    for index = 1, count do
        local item, row = self.items[index + self.offset], self.rows[index]
        if type(item) == "table" then
        _G.LycheeInternal.InteractionBinding:Bind(row, item, session, generation)
        row.item, row.index, row.snapshotOwner = item, index, nil
        row:EnableMouse(true)
        local changedIdentity=row.stableID~=stableItemID(item)
        row.session, row.generation, row.extensionID, row.stableID = session, generation, extensionID(item), stableItemID(item)
        local title=item.text
        local subtitle=item.subtext ~= "" and item.subtext or item.description or item.summary or ""
        if highlight then
            if row._matchTitle~=title or row._matchSubtitle~=subtitle or row._matchQuery~=highlightQuery then
                row._matchTitle,row._matchSubtitle,row._matchQuery=title,subtitle,highlightQuery
                row._matchRenderedTitle=highlight:Format(title,highlightQuery)
                row._matchRenderedSubtitle=highlight:Format(subtitle,highlightQuery)
            end
            title,subtitle=row._matchRenderedTitle,row._matchRenderedSubtitle
        end
        row.textProps.title,row.textProps.subtext,row.textProps.category=title,subtitle,kindText(item)
        row.ui:Update(row.textProps)
        local single=row.subtext:GetText()==""
        if row._singleTitle~=single then
            row.title:ClearAllPoints()
            row.title:SetPoint(single and "LEFT" or "TOPLEFT",row,single and "LEFT" or "TOPLEFT",Lychee.UI.Theme.Metrics.listTitleInset,single and 0 or -6)
            row.title:SetPoint("RIGHT",row.category,"LEFT",-14,0)
            row._singleTitle=single
        end
        local icon = item.icon
        if row._icon ~= icon and type(row.icon.SetTexture) == "function" then row.icon:SetTexture(icon); cropIcon(row.icon); row._icon = icon end
        setShown(row.icon, icon ~= nil)
        local interaction = item.interaction
        row.primaryAction, row.dragDescriptor = primaryAction(interaction), interaction and interaction.drag
        if row.primaryTarget and type(row.primaryTarget.EnableMouse) == "function" then row.primaryTarget:EnableMouse(true) end
        cachedText(row, "primaryHint", row.primaryHint, "")
        setShown(row.dragger, row.dragDescriptor ~= nil)
        renderRowState(row); setShown(row, true)
        if changedIdentity and not wasFrozen and Lychee.UI.Motion then Lychee.UI.Motion:Reveal(row.title,"feedback");Lychee.UI.Motion:Reveal(row.subtext,"feedback") end
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
    hideTooltip()
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
    if self.frozen then return end
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
    if self.frozen then return end
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
    if self.frozen then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local offset = math.max(0, math.min(self.offset + delta, math.max(0, #self.items - #self.rows)))
    if offset == self.offset then return false end
    if not self.controller or not self.controller.ApplyResults then return false end
    return self.controller:ApplyResults(self.items, self.generation, self.session, offset)
end

function ResultList:ActivateSelected()
    if self.frozen then return end
    local row = self.rows[self.selected]
    if row and row:IsShown() and self.controller then self.controller:ActivateRow(row) end
end

Lychee.UI.ResultList = ResultList
