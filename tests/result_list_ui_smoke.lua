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
    function value:ClearAllPoints() self.points = {} end
    function value:SetParent(parentValue) self.parent = parentValue end
    function value:SetFrameStrata(strata) self.strata = strata end
    function value:SetClampedToScreen(enabled) self.clamped = enabled end
    function value:EnableMouse(enabled) self.mouseEnabled = enabled end
    function value:GetStringHeight() return self.measuredHeight or 15 end
    function value:SetFont(path, size, flags) self.font = {path, size, flags}; return true end
    function value:SetShadowOffset(x, y) self.shadow = {x, y} end
    function value:SetVertexColor() end
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

STANDARD_TEXT_FONT = "Fonts/test.ttf"
UIParent = object("UIParent")
function GetLocale() return "zhCN" end
function CreateFrame(kind, _, parent) return object(kind, parent or UIParent) end

local tooltip = { shown = false }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:SetText(text, ...) self.text = text; self.titleColor = { ... }; self.lines = {}; self.detail = "" end
function tooltip:AddLine(text, ...) self.lines[#self.lines + 1] = { text = text, color = { ... } }; self.detail = self.detail .. text .. "\n" end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false; self.owner = nil end
GameTooltip = tooltip

dofile("package/Lychee/UI/Theme.lua")
dofile("package/Lychee/UI/Components.lua")
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

assert(#list.rows == 8, "eight visible result rows are precreated")
assert(list.gridColumns == 1 and list.frame:GetHeight() == 478, "result list uses a compact single column")
for index = 1, 8 do
    local row = list.rows[index]
    assert(row:GetHeight() == 58, "row height remains fixed")
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
        kindTitle = "自定义类型",
        description = longText,
        category = "技能",
        categoryColor = { 0.455, 0.670, 0.925, 1 },
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
assert(rowOne.title:GetText() == longText and rowOne.subtext:GetText() == longText, "name and description remain separately constrained")
assert(#rowOne.title.points == titlePointCount and rowOne:GetHeight() == 58, "long text cannot mutate row geometry")
assert(rowOne.title.maxLines == 1 and rowOne.title.wordWrap == false, "title is constrained to one line")
assert(rowOne.category:GetText() == "自定义类型", "type label takes precedence over category")
assert(rowOne.category._lycheeTextToken == Lychee.UI.Theme.Colors.textDim and rowTwo.category._lycheeTextToken == Lychee.UI.Theme.Colors.textDim,
    "all result labels use the same subdued theme color, including colored provider categories")
assert(rowOne.icon:IsShown() and rowOne.icon.texture == 4578416, "icon is rendered in reserved slot")
assert(rowOne.dragger:IsShown() and rowOne.dragDescriptor.spellID == 393256, "drag area binds descriptor")
assert(rowOne.primaryAction.id == "cast" and rowOne.primaryHint:GetText() == "", "primary action label stays out of the compact row")
assert(rowOne.secondaryAction.id == "detail" and rowOne.secondary:IsShown(), "first non-primary action is exposed as secondary")
assert(rowOne._categoryInset == 42, "visible secondary button keeps label clear")
assert(rowTwo._categoryInset == 12, "label without visible secondary button matches icon inset")

assert(list.selected == 1 and rowOne._selected, "first result is keyboard-selected")
rowTwo.scripts.OnEnter(rowTwo)
assert(list.selected == 2 and not rowOne._selected and rowTwo._selected, "hover moves the single current selection")
assert(not rowOne.accent:IsShown() and rowTwo.accent:IsShown(), "only the hovered current row has an accent")
rowTwo.scripts.OnLeave(rowTwo)
list:Move(-1)
assert(list.selected == 1 and rowOne._selected and not rowTwo._selected, "keyboard movement uses the same selection")

rowOne.scripts.OnEnter(rowOne)
list:Move(1)
assert(not rowOne.accent:IsShown() and rowTwo.accent:IsShown(), "keyboard navigation leaves no second hover highlight")
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
local tip = Lychee.UI.ResultList.tooltip
assert(tip:IsShown() and tip.labels[1]:GetText() == longText, "hover keeps the item title")
assert(tip.labels[2]:GetText() == "自定义类型", "tooltip keeps useful type without internal search diagnostics")
assert(tip.labels[4]:GetText():find("施放",1,true), "tooltip shows the declared primary action")
assert(not GameTooltip.shown and GameTooltip.text == nil, "result tooltip never changes the global tooltip")
assert(tip.clamped and not tip.mouseEnabled, "tooltip stays on screen without intercepting clicks")
assert(tip.labels[1].font[2] > tip.labels[2].font[2] and tip.labels[1].shadow[1] == 0, "owned fonts preserve hierarchy without inherited shadows")
frameCount = #created
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(#created == frameCount and Lychee.UI.ResultList.tooltip == tip, "repeat hover reuses all tooltip objects")
tip.labels[3].measuredHeight = 60
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
local expandedHeight = tip:GetHeight()
assert(tip.labels[4]._y >= tip.labels[3]._y + 60, "wrapped description cannot overlap actions")
tip.labels[3].measuredHeight = 15
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(tip:GetHeight() < expandedHeight, "tooltip shrinks again when measured content shortens")
rowOne.primaryTarget.scripts.OnLeave(rowOne.primaryTarget)
assert(not tip:IsShown() and tip._owner == nil, "leave hides tooltip and releases owner")
rowOne.secondary.scripts.OnClick(rowOne.secondary)
assert(activatedAction and activatedAction[1] == rowOne and activatedAction[2] == "detail", "secondary action delegates stable action ID")
rowOne.dragger.scripts.OnDragStart(rowOne.dragger)
assert(draggedRow == rowOne, "drag area delegates its owning row")
rowOne.primaryTarget.scripts.OnClick(rowOne.primaryTarget)
assert(activatedRow == rowOne and list.selected == 1, "row click selects and delegates activation")

rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(tip:IsShown(), "stale tooltip fixture starts visible")
list:SetItems({ items[2] }, 14, 26)
assert(not tip:IsShown(), "result replacement hides stale tooltip")
assert(#created == frameCount and list.rows[1] == rowOne and rowOne.primaryTarget == primaryTarget, "shorter update reuses row and primary target")
assert(not rowTwo:IsShown() and rowTwo.item == nil and rowTwo.session == nil and rowTwo.generation == nil, "shorter update clears stale row bindings")
assert(rowTwo.title:GetText() == "" and rowTwo.icon.texture == nil and not rowTwo.dragger:IsShown(), "shorter update clears stale visuals and drag")
assert(rowTwo.primaryAction == nil and rowTwo.secondaryAction == nil and rowTwo.dragDescriptor == nil, "shorter update clears stale interactions")

assert(list:InvalidateRow(rowOne), "visible row can be invalidated")
assert(not rowOne:IsShown() and rowOne.item == nil and rowOne.extensionID == nil, "invalidate clears identity and visibility")
assert(rowOne.title:GetText() == "" and rowOne.subtext:GetText() == "" and rowOne.category:GetText() == "", "invalidate clears all text")
assert(not rowOne.accent:IsShown(), "invalidate clears selected visuals")
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

-- Mirror the home view's clipping ScrollFrame. Screen top is 900, so this
-- fixture isolates ancestor clipping from screen-edge clamping.
local viewport = CreateFrame("ScrollFrame", nil, UIParent)
viewport.clipTop = 600
local scrollContent = CreateFrame("Frame", nil, viewport)
local recentOwner = CreateFrame("Button", nil, scrollContent)
recentOwner.top = 556
Lychee.UI.ResultList:ShowItemTooltip(items[1], recentOwner)
local recentTip = Lychee.UI.ResultList.tooltip
local tooltipTop = recentOwner.top + 8 + recentTip:GetHeight()
local clipTop = 900
local ancestor = recentTip:GetParent()
while ancestor do
    if ancestor.clipTop then clipTop = math.min(clipTop, ancestor.clipTop) end
    ancestor = ancestor:GetParent()
end
local visibleLines = 0
for index = 1, 5 do
    local label = recentTip.labels[index]
    if label:IsShown() and tooltipTop - label._y <= clipTop then visibleLines = visibleLines + 1 end
end
assert(visibleLines == 5, "recent tooltip clipped by scroll ancestor: only " .. visibleLines .. "/5 lines visible")
assert(recentTip:GetParent() == UIParent, "tooltip keeps a non-clipping root parent")
list.frame.scripts.OnHide(list.frame)
assert(not recentTip:IsShown() and recentTip._owner == nil, "hiding the result view clears the root-owned tooltip")
Lychee.UI.ResultList:HideTooltip()

local mixedTypes = {
    {text="技能结果",kindTitle="技能",category="旧分类",categoryColor={0.455,0.670,0.925,1}},
    {text="首领结果",kindTitle="首领"},
    {text="菜单结果",kindTitle="游戏菜单"},
    {text="纹章结果",kindTitle="角色货币"},
    {text="第三方结果",sourceTitle="第三方工具"},
    {text="本地化类型",kindTitle={default="Item",zhCN="装备"}},
    {text="仅分类结果",category={id="tasks",title={default="Tasks",zhCN="任务"}}},
    {text="无类型结果"},
}
local expectedTypes={"技能","首领","游戏菜单","角色货币","第三方工具","装备","任务","内容"}
local createdBeforeTypes=#created
list:SetItems(mixedTypes,50,60)
for index=1,#expectedTypes do
    local label=list.rows[index].category
    assert(label:GetText()==expectedTypes[index], "mixed Provider type label "..index)
    assert(label._lycheeTextToken==Lychee.UI.Theme.Colors.textDim and label.font[2]==11, "consistent type-label style")
end
assert(#created==createdBeforeTypes, "type labels reuse existing rows and regions")
list:Clear()

dofile("package/Lychee/UI/Components.lua")
local menuOwner = {}
Lychee.UI.Components:StyleActionMenuOwner(menuOwner)
local menuFrame = object("Frame")
local attachments = {}
function menuFrame:AttachTexture()
    local texture = object("Texture", self)
    function texture:SetDrawLayer(layer, level) self.layer, self.level = layer, level end
    attachments[#attachments + 1] = texture
    return texture
end
menuOwner.menuMixin.Generate(menuFrame)
assert(#attachments == 2 and attachments[2].color[4] == 1, "menu has an opaque pooled background")
assert(menuOwner.menuMixin:GetInset().left == menuOwner.menuMixin:GetInset().right, "menu padding is symmetric")
local menuInitializer, menuEnter, menuLeave
Lychee.UI.Components:StyleActionMenuButton({AddInitializer=function(_, fn) menuInitializer=fn end, SetOnEnter=function(_, fn) menuEnter=fn end, SetOnLeave=function(_, fn) menuLeave=fn end})
local menuButton = object("Button")
menuButton.fontString = object("FontString", menuButton)
function menuButton.fontString:GetStringWidth() return self.measuredWidth or 100 end
menuButton.highlight = object("Texture", menuButton)
function menuButton.highlight:SetBlendMode(mode) self.blendMode = mode end
local menuWidth, menuHeight = menuInitializer(menuButton)
assert(menuWidth == 156 and menuHeight == 32, "single action retains comfortable menu dimensions")
assert(menuButton.fontString.font[2] == 12 and menuButton.fontString.wordWrap == false, "menu uses readable single-line body text")
assert(menuButton.highlight.blendMode == "BLEND", "menu removes additive gold highlight")
menuButton.fontString.measuredWidth = 600
local longMenuWidth = menuInitializer(menuButton)
assert(longMenuWidth == 280, "long action text cannot create an unbounded menu")
menuEnter(menuButton)
assert(menuButton.fontString.textColor[1] == Lychee.UI.Theme.Colors.accentHover[1], "menu hover changes text")
menuLeave(menuButton)
assert(menuButton.fontString.textColor[1] == Lychee.UI.Theme.Colors.text[1], "menu leave restores text")
assert(menuButton.highlight.color[4] == 0, "menu never adds a hover background")

-- Real pointer-to-range behavior, including scale and release outside the track.
local cursorY, mouseDown, combat = 0, true, false
function GetCursorPosition() return 0, cursorY end
function IsMouseButtonDown() return mouseDown end
function InCombatLockdown() return combat end
local value, changes, bar = 0, 0
bar = Lychee.UI.Components:CreateScrollbar(parent, function(nextValue)
    value=nextValue; changes=changes+1; bar:SetRange(1000,200,value)
end)
bar.frame.height=200
function bar.frame:GetTop() return 400 end
function bar.frame:GetEffectiveScale() return 2 end
bar:SetRange(210,200,10)
assert(bar._height==48 and bar._offset==152, "slight overflow keeps a short thumb and reaches the track end")
bar:SetRange(1000,200,0)
assert(bar.frame:IsShown() and bar._height==40 and bar.travel==160, "proportional thumb with bounded hit area")
assert(bar.frame.scripts.OnUpdate==nil, "scrollbar has no idle update")
cursorY=780 -- ten units below track top
bar.frame.scripts.OnMouseDown(bar.frame,"LeftButton")
cursorY=620 -- move down eighty units
bar.frame.scripts.OnUpdate()
assert(value==400 and changes==1, "drag converts scaled cursor distance to scroll range")
bar.frame.scripts.OnUpdate()
assert(changes==1, "stationary drag has no redundant refresh")
mouseDown=false;bar.frame.scripts.OnUpdate()
assert(bar.frame.scripts.OnUpdate==nil, "release outside stops drag")
mouseDown=true;cursorY=410
bar.frame.scripts.OnMouseDown(bar.frame,"LeftButton")
assert(value==800, "track click clamps at the end")
bar:SetRange(100,200,value)
assert(not bar.frame:IsShown() and bar.value==0 and bar.frame.scripts.OnUpdate==nil, "shortened content hides and cancels drag")
bar:SetRange(1000,200,0);cursorY=780
bar.frame.scripts.OnMouseDown(bar.frame,"LeftButton")
combat=true;bar.frame.scripts.OnUpdate()
assert(bar.frame.scripts.OnUpdate==nil, "combat stops active drag")
combat=false;bar.frame.scripts.OnMouseDown(bar.frame,"LeftButton")
bar.frame.scripts.OnHide()
assert(bar.frame.scripts.OnUpdate==nil, "hidden viewport stops drag")
print("Lychee result list UI smoke PASS")
