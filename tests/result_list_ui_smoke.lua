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
    }
    created[#created + 1] = value
    function value:SetAllPoints() self.allPoints = true end
    function value:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function value:SetSize(width, height) self.width, self.height = width, height end
    function value:SetHeight(height) self.height = height end
    function value:SetWidth(width) self.width = width end
    function value:GetHeight() return self.height end
    function value:GetWidth() return self.width end
    function value:SetShown(shown) self.shown = not not shown end
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
    function value:SetText(text) self.text = text end
    function value:GetText() return self.text or "" end
    function value:SetTextColor(...) self.textColor = { ... } end
    function value:SetTexture(texture) self.texture = texture end
    function value:SetColorTexture(...) self.color = { ... } end
    function value:GetParent() return self.parent end
    function value:CreateTexture() return object("Texture", self) end
    function value:CreateFontString() return object("FontString", self) end
    return value
end

UIParent = object("UIParent")
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

assert(#list.rows == 6, "six result rows are precreated")
assert(list.frame:GetHeight() == 356, "result list has fixed six-row height")
for index = 1, 6 do
    local row = list.rows[index]
    assert(row:GetHeight() == 56, "row height remains fixed")
    assert(#row.actions == 4, "four action slots are precreated")
    assert(not row:IsShown(), "new row starts cleared")
end

local frameCount = #created
local rowOne, rowTwo = list.rows[1], list.rows[2]
local actionOne = rowOne.actions[1]
local titlePointCount = #rowOne.title.points

local longText = string.rep("很长的本地化技能说明", 20)
local items = {
    {
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
assert(rowOne.title:GetText() == longText and rowOne.subtext:GetText() == longText, "long localized text is retained for native clipping")
assert(#rowOne.title.points == titlePointCount and rowOne:GetHeight() == 56, "long text cannot mutate row geometry")
assert(rowOne.title.maxLines == 1 and rowOne.title.wordWrap == false, "title is constrained to one line")
assert(rowOne.category:GetText() == "技能" and rowOne.categoryBG:IsShown(), "category badge is rendered")
assert(rowOne.icon:IsShown() and rowOne.icon.texture == 4578416, "icon is rendered in reserved slot")
assert(rowOne.source:GetText() == "builtin.player-spells:records", "source is rendered")
assert(rowOne.evidence:GetText():find("98%%"), "confidence evidence is rendered")
assert(rowOne.dragger:IsShown() and rowOne.dragger.dragDescriptor.spellID == 393256, "drag area binds descriptor")
assert(rowOne.actions[4]:IsShown() and rowOne.actions[3]._state == "disabled", "four stable action slots expose disabled state")

assert(list.selected == 1 and rowOne._selected, "first result is keyboard-selected")
rowTwo.scripts.OnEnter(rowTwo)
assert(list.selected == 1 and rowOne._selected and rowTwo._hovered and not rowTwo._selected, "hover does not replace keyboard selection")
rowTwo.scripts.OnLeave(rowTwo)
list:Move(1)
assert(list.selected == 2 and rowTwo._selected and not rowOne._selected, "keyboard movement changes selection")

rowOne.actions[1].scripts.OnEnter(rowOne.actions[1])
assert(GameTooltip.shown and GameTooltip.text == "施放技能", "action hover shows tooltip")
rowOne.actions[1].scripts.OnMouseDown(rowOne.actions[1])
assert(rowOne.actions[1]._state == "pressed", "action pressed state is explicit")
rowOne.actions[1].scripts.OnClick(rowOne.actions[1])
assert(activatedAction and activatedAction[1] == rowOne and activatedAction[2] == "cast", "action delegates stable action ID")
rowOne.dragger.scripts.OnDragStart(rowOne.dragger)
assert(draggedRow == rowOne, "drag area delegates its owning row")
rowOne.scripts.OnClick(rowOne)
assert(activatedRow == rowOne and list.selected == 1, "row click selects and delegates activation")

list:SetItems({ items[2] }, 12, 24)
assert(#created == frameCount and list.rows[1] == rowOne and rowOne.actions[1] == actionOne, "shorter update reuses row and action objects")
assert(not rowTwo:IsShown() and rowTwo.item == nil and rowTwo.session == nil and rowTwo.generation == nil, "shorter update clears stale row bindings")
assert(rowTwo.title:GetText() == "" and rowTwo.icon.texture == nil and not rowTwo.dragger:IsShown(), "shorter update clears stale visuals and drag")
for index = 1, 4 do
    assert(rowTwo.actions[index].actionID == nil and rowTwo.actions[index].action == nil and not rowTwo.actions[index]:IsShown(), "shorter update clears stale action")
end

assert(list:InvalidateRow(rowOne), "visible row can be invalidated")
assert(not rowOne:IsShown() and rowOne.item == nil and rowOne.extensionID == nil, "invalidate clears identity and visibility")
assert(rowOne.title:GetText() == "" and rowOne.source:GetText() == "" and rowOne.evidence:GetText() == "", "invalidate clears all text")
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
