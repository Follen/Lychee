-- Offline fixed-geometry ResultList fixture. It validates renderer state only;
-- secure action execution remains covered by interaction_smoke.lua.
_G = _G or {}

local created = {}
local function object(kind, parent)
    local value = {
        kind = kind,
        parent = parent,
        shown = true,
        width = 720,
        height = 500,
        scripts = {},
        points = {},
        children = {},
        setterCalls = {},
    }
    if parent and parent.children then parent.children[#parent.children + 1] = value end
    created[#created + 1] = value
    local function setter(name)
        value.setterCalls[name] = (value.setterCalls[name] or 0) + 1
    end
    function value:SetAllPoints() self.allPoints = true end
    function value:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function value:SetSize(width, height) self.width, self.height = width, height end
    function value:SetHeight(height) self.height = height end
    function value:SetWidth(width) self.width = width end
    function value:GetHeight() return self.height end
    function value:GetWidth() return self.width end
    function value:SetShown(shown) setter("SetShown"); self.shown = not not shown end
    function value:IsShown() return self.shown end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:SetScript(name, callback) self.scripts[name] = callback end
    function value:RegisterForClicks() end
    function value:RegisterForDrag() end
    function value:SetJustifyH(justification) self.justification = justification end
    function value:SetWordWrap(enabled) self.wordWrap = enabled end
    function value:SetNonSpaceWrap(enabled) self.nonSpaceWrap = enabled end
    function value:SetMaxLines(lines) self.maxLines = lines end
    function value:SetText(text) setter("SetText"); self.text = text end
    function value:GetText() return self.text or "" end
    function value:SetTextColor(...) setter("SetTextColor"); self.textColor = { ... } end
    function value:SetTexture(texture) setter("SetTexture"); self.texture = texture end
    function value:SetColorTexture(...) setter("SetColorTexture"); self.color = { ... } end
    function value:GetParent() return self.parent end
    function value:CreateTexture() return object("Texture", self) end
    function value:CreateFontString() return object("FontString", self) end
    return value
end

local SETTER_NAMES = { "SetShown", "SetText", "SetTextColor", "SetTexture", "SetColorTexture" }
local function setterCounts(root)
    local counts = {}
    for index = 1, #SETTER_NAMES do counts[SETTER_NAMES[index]] = 0 end
    local function visit(value)
        for index = 1, #SETTER_NAMES do
            local name = SETTER_NAMES[index]
            counts[name] = counts[name] + (value.setterCalls[name] or 0)
        end
        for index = 1, #value.children do visit(value.children[index]) end
    end
    visit(root)
    return counts
end

local function setterFingerprint(root)
    local counts = setterCounts(root)
    local parts = {}
    for index = 1, #SETTER_NAMES do
        local name = SETTER_NAMES[index]
        parts[index] = name .. ":" .. counts[name]
    end
    return table.concat(parts, "|")
end

UIParent = object("UIParent")
function GetLocale() return "zhCN" end
function CreateFrame(kind, _, parent) return object(kind, parent or UIParent) end

local tooltip = { shown = false }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:SetText(text) self.text = text end
function tooltip:AddLine(text) self.detail = text end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false; self.owner = nil end
GameTooltip = tooltip

dofile("package/Lychee/UI/Theme.lua")
dofile("package/Lychee/UI/ResultList.lua")

local activatedRow, activatedAction, draggedRow
local controller = {
    ActivateRow = function(_, row) activatedRow = row end,
    ActivateRowAction = function(_, row, actionID) activatedAction = { row, actionID } end,
    BeginRowDrag = function(_, row) draggedRow = row end,
}
local parent = CreateFrame("Frame", nil, UIParent)
parent:SetSize(720, 500)
local list = _G.Lychee.UI.ResultList:Create(parent, controller)

assert(#list.rows == 12, "twelve result tiles are precreated")
assert(list.gridColumns == 4 and list.frame:GetHeight() == 232, "result list uses a four-column grid")
for index = 1, 12 do
    local row = list.rows[index]
    assert(row:GetHeight() == 72, "tile height remains fixed")
    assert(row.primaryTarget and row.secondary, "primary and secondary interaction targets are precreated")
    assert(not row:IsShown(), "new row starts cleared")
end

local frameCount = #created
local rowOne, rowTwo = list.rows[1], list.rows[2]
local primaryTarget = rowOne.primaryTarget
local titlePointCount = #rowOne.title.points

local longText = string.rep("很长的本地化技能说明", 20)
local items = {
    {
        stableID = "spell:393256",
        text = longText,
        description = longText,
        category = "技能",
        source = "builtin.player-spells:records",
        icon = 4578416,
        _ext = "builtin.player-spells",
        confidence = 0.98,
        evidence = { matchedField = "alias", matchType = "exact" },
        interaction = {
            actions = {
                { id = "cast", title = "施放", tooltip = "施放技能" },
                { id = "detail", title = "详情" },
                { id = "disabled", title = "不可用", enabled = false },
                { id = "pin", title = "固定" },
            },
            drag = { type = "spell", spellID = 393256 },
        },
    },
    {
        stableID = "fixture:second",
        text = "第二项",
        subtext = "使用副标题作为详情",
        categoryLabel = "任务",
        sourceLabel = "第三方来源",
        _ext = "fixture.extension",
        interaction = { actions = { { id = "open", title = "打开" } } },
    },
}

list:SetItems(items, 11, 23)
assert(#created == frameCount, "query update does not create frames or regions")
assert(rowOne:IsShown() and rowTwo:IsShown() and not list.rows[3]:IsShown(), "only populated rows are shown")
assert(rowOne.session == 11 and rowOne.generation == 23 and rowOne.extensionID == "builtin.player-spells", "freshness fields bind to row")
assert(rowOne.title:GetText() == longText and rowOne.subtext:GetText() == "", "description stays out of the compact row")
assert(#rowOne.title.points == titlePointCount and rowOne:GetHeight() == 72, "long text cannot mutate tile geometry")
assert(rowOne.title.maxLines == 1 and rowOne.title.wordWrap == false, "title is constrained to one line")
assert(rowOne.category:GetText() == "技能", "category label is rendered")
assert(rowOne.icon:IsShown() and rowOne.icon.texture == 4578416, "icon is rendered in reserved slot")
assert(rowOne.dragger:IsShown() and rowOne.dragDescriptor.spellID == 393256, "drag area binds descriptor")
assert(rowOne.primaryAction.id == "cast" and rowOne.primaryHint:GetText() == "", "primary action label stays out of the compact row")
assert(rowOne.secondaryAction.id == "detail" and rowOne.secondary:IsShown(), "first non-primary action is exposed as secondary")

assert(list.selected == 1 and rowOne._selected, "first result is keyboard-selected")
rowTwo.scripts.OnEnter(rowTwo)
assert(list.selected == 1 and rowOne._selected and rowTwo._hovered and not rowTwo._selected, "hover does not replace keyboard selection")
rowTwo.scripts.OnLeave(rowTwo)
list:Move(1)
assert(list.selected == 2 and rowTwo._selected and not rowOne._selected, "keyboard movement changes selection")

rowOne.scripts.OnEnter(rowOne)
local unchangedRowOne = setterFingerprint(rowOne)
local unchangedRowTwo = setterFingerprint(rowTwo)
list:SetItems(items, 12, 24)
assert(setterFingerprint(rowOne) == unchangedRowOne and setterFingerprint(rowTwo) == unchangedRowTwo, "identical items cause zero native setter churn")
assert(rowOne.session == 12 and rowOne.generation == 24, "identical visuals still refresh source freshness")
assert(list.selected == 2 and rowTwo._selected and rowOne._hovered, "identical diff preserves keyboard selection and hover")

local rowOneBeforeChange = setterFingerprint(rowOne)
local rowTwoBeforeChange = setterFingerprint(rowTwo)
local rowTwoCountsBeforeChange = setterCounts(rowTwo)
local titleCallsBeforeChange = rowTwo.title.setterCalls.SetText or 0
items[2].text = "第二项（更新）"
list:SetItems(items, 13, 25)
assert(setterFingerprint(rowOne) == rowOneBeforeChange, "changing the second item does not touch the first row")
assert((rowTwo.title.setterCalls.SetText or 0) == titleCallsBeforeChange + 1, "changed title updates exactly once")
assert(setterFingerprint(rowTwo) ~= rowTwoBeforeChange and rowTwo.title:GetText() == "第二项（更新）", "only the affected row is rendered")
local rowTwoCountsAfterChange = setterCounts(rowTwo)
assert(rowTwoCountsAfterChange.SetText == rowTwoCountsBeforeChange.SetText + 1, "changed title is the only text setter call")
for index = 1, #SETTER_NAMES do
    local name = SETTER_NAMES[index]
    if name ~= "SetText" then
        assert(rowTwoCountsAfterChange[name] == rowTwoCountsBeforeChange[name], "changed title does not churn " .. name)
    end
end
assert(list.selected == 2 and rowTwo._selected and rowOne._hovered, "changed fields preserve independent selection and hover state")

rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(GameTooltip.shown and GameTooltip.text == longText and GameTooltip.detail:find("类型", 1, true) and GameTooltip.detail:find("匹配", 1, true), "primary hover exposes typed diagnostic tooltip")
rowOne.secondary.scripts.OnClick(rowOne.secondary)
assert(activatedAction and activatedAction[1] == rowOne and activatedAction[2] == "detail", "secondary action delegates stable action ID")
rowOne.dragger.scripts.OnDragStart(rowOne.dragger)
assert(draggedRow == rowOne, "drag area delegates its owning row")
rowOne.primaryTarget.scripts.OnClick(rowOne.primaryTarget)
assert(activatedRow == rowOne and list.selected == 1, "row click selects and delegates activation")

list:SetItems({ items[2] }, 14, 26)
assert(#created == frameCount and list.rows[1] == rowOne and rowOne.primaryTarget == primaryTarget, "shorter update reuses row and primary target")
assert(not rowTwo:IsShown() and rowTwo.item == nil and rowTwo.session == nil and rowTwo.generation == nil, "shorter update clears stale row bindings")
assert(rowTwo.title:GetText() == "" and rowTwo.icon.texture == nil and not rowTwo.dragger:IsShown(), "shorter update clears stale visuals and drag")
assert(rowTwo.primaryAction == nil and rowTwo.secondaryAction == nil and rowTwo.dragDescriptor == nil, "shorter update clears stale interactions")

assert(list:InvalidateRow(rowOne), "visible row can be invalidated")
assert(not rowOne:IsShown() and rowOne.item == nil and rowOne.extensionID == nil, "invalidate clears identity and visibility")
assert(rowOne.title:GetText() == "" and rowOne.subtext:GetText() == "" and rowOne.category:GetText() == "", "invalidate clears all text")
assert(not rowOne.accent:IsShown() and not rowOne.outline:IsShown(), "invalidate clears selected visuals")
assert(list:GetSelected() == nil, "invalidated final row leaves no selected item")

list:SetItems(items, 31, 41)
list:Clear()
assert(list.session == nil and list.generation == nil and #list.items == 0, "clear resets list freshness")
for index = 1, #list.rows do
    assert(not list.rows[index]:IsShown() and list.rows[index].item == nil, "clear wipes every pooled row")
end
for index = 1, #created do
    assert(created[index].scripts.OnUpdate == nil, "renderer creates no OnUpdate scripts")
end

print("Lychee result list UI smoke PASS")
