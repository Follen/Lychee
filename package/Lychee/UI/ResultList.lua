local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local ResultList = {}
ResultList.__index = ResultList

local ROWS = 12
local EMPTY_ITEMS = {}

local function setText(fontString, value)
    value = value or ""
    if fontString and fontString:GetText() ~= value then fontString:SetText(value) end
end

local function setShown(object, shown)
    if object and type(object.IsShown) == "function" and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function extensionID(item)
    return item and (item._ext or (item.command and item.command._ext))
end

function ResultList:Create(parent, controller)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -48)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -48)
    frame:SetHeight(300)
    local self = setmetatable({ frame = frame, controller = controller, rows = {}, items = {}, selected = 1 }, ResultList)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(34)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * 35)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(i - 1) * 35)
        row:RegisterForClicks("LeftButtonUp")
        row:RegisterForDrag("LeftButton")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 6, 0)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
        row.title:SetPoint("RIGHT", row, "RIGHT", -92, 0)
        row.title:SetJustifyH("LEFT")
        row.subtext = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.subtext:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
        row.subtext:SetPoint("RIGHT", row, "RIGHT", -92, 0)
        row.subtext:SetJustifyH("LEFT")
        row.actions = {}
        for actionIndex = 1, 4 do
            local action = CreateFrame("Button", nil, row)
            action:SetSize(24, 24)
            action:SetPoint("RIGHT", row, "RIGHT", -((4 - actionIndex) * 26 + 4), 0)
            action:RegisterForClicks("LeftButtonUp")
            action.label = action:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            action.label:SetAllPoints()
            action.label:SetJustifyH("CENTER")
            action:SetScript("OnClick", function(button)
                if self.controller then self.controller:ActivateRowAction(button:GetParent(), button.actionID) end
            end)
            row.actions[actionIndex] = action
        end
        row.dragger = CreateFrame("Button", nil, row)
        row.dragger:SetSize(28, 28)
        row.dragger:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.dragger:RegisterForDrag("LeftButton")
        row.dragger:SetScript("OnDragStart", function(button)
            if self.controller then self.controller:BeginRowDrag(button:GetParent()) end
        end)
        row:SetScript("OnClick", function(button)
            if self.controller then self.controller:ActivateRow(button) end
        end)
        row:SetScript("OnEnter", function(button)
            if self.controller then self.controller:SelectRow(button) end
        end)
        self.rows[i] = row
    end
    return self
end

function ResultList:Clear()
    for i = 1, #self.rows do
        local row = self.rows[i]
        row.item, row.index, row.session, row.generation, row.extensionID = nil, nil, nil, nil, nil
        setShown(row, false)
        for j = 1, 4 do row.actions[j].actionID = nil; setShown(row.actions[j], false) end
    end
    self.items = EMPTY_ITEMS
    self.selected = 1
end

function ResultList:SetItems(items, session, generation)
    self.items = items or EMPTY_ITEMS
    self.session, self.generation = session, generation
    local count = math.min(#self.items, #self.rows)
    for i = 1, count do
        local item, row = self.items[i], self.rows[i]
        row.item = item
        row.index = i
        row.session, row.generation, row.extensionID = session, generation, extensionID(item)
        setText(row.title, item.text)
        setText(row.subtext, item.subtext)
        if item.icon and row.icon.SetTexture then
            if row._icon ~= item.icon then row.icon:SetTexture(item.icon); row._icon = item.icon end
            setShown(row.icon, true)
        else
            row._icon = nil
            setShown(row.icon, false)
        end
        local interaction = item.interaction
        local actions = interaction and interaction.actions
        for j = 1, 4 do
            local button, action = row.actions[j], actions and actions[j]
            if action then
                button.actionID = action.id
                setText(button.label, action.title)
                setShown(button, true)
            else
                button.actionID = nil
                setShown(button, false)
            end
        end
        setShown(row.dragger, interaction and interaction.drag ~= nil or false)
        setShown(row, true)
    end
    for i = count + 1, #self.rows do
        local row = self.rows[i]
        row.item, row.index, row.session, row.generation, row.extensionID = nil, nil, nil, nil, nil
        setShown(row, false)
        for j = 1, 4 do row.actions[j].actionID = nil; setShown(row.actions[j], false) end
    end
    self.selected = math.max(1, math.min(self.selected or 1, math.max(count, 1)))
    self:Select(self.selected)
end


function ResultList:InvalidateRow(row)
    if not row then return false end
    local index = row.index
    row.item, row.index, row.session, row.generation, row.extensionID = nil, nil, nil, nil, nil
    setShown(row, false)
    setShown(row.dragger, false)
    for j = 1, 4 do row.actions[j].actionID = nil; setShown(row.actions[j], false) end
    if index and self.items[index] then self.items[index] = false end
    return true
end

function ResultList:Select(index)
    if #self.items == 0 then return end
    index = math.max(1, math.min(index or 1, #self.rows))
    self.selected = index
    for i = 1, #self.rows do
        local row = self.rows[i]
        if row:IsShown() then
            local selected = i == index
            if row._selected ~= selected then
                row.bg:SetColorTexture(selected and 0.15 or 0, 0.5, 0.8, selected and 0.28 or 0)
                row._selected = selected
            end
        end
    end
end

function ResultList:SelectRow(row) self:Select(row.index) end
function ResultList:GetSelected() return self.rows[self.selected] and self.rows[self.selected].item end
function ResultList:Move(delta) self:Select(self.selected + (delta or 0)); return self:GetSelected() end
function ResultList:ActivateSelected() local row = self.rows[self.selected]; if row and row:IsShown() and self.controller then self.controller:ActivateRow(row) end end

Lychee.UI.ResultList = ResultList
