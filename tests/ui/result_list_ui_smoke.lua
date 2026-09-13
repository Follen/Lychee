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
    function value:SetScale(scale) self.scale=scale end
    function value:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function value:HookScript(key,fn) local old=self.scripts[key];self.scripts[key]=function(...) if old then old(...) end;fn(...) end end
    function value:SetFrameStrata(strata) self.strata = strata end
    function value:SetClampedToScreen(enabled) self.clamped = enabled end
    function value:EnableMouse(enabled) self.mouseEnabled = enabled end
    function value:GetStringHeight() return self.measuredHeight or 15 end
    function value:GetStringWidth()
        local width = 0
        for char in (self:GetText()):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            width = width + (#char > 1 and 11 or 6)
        end
        return width
    end
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
local cursorX, cursorY = 100, 200
function GetCursorPosition() return cursorX, cursorY end
function GetLocale() return "zhCN" end
function CreateFrame(kind, _, parent) return object(kind, parent or UIParent) end

local tooltip = { shown = false }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:SetText(text, ...) self.text = text; self.titleColor = { ... }; self.lines = {}; self.detail = "" end
function tooltip:AddLine(text, ...) self.lines[#self.lines + 1] = { text = text, color = { ... } }; self.detail = self.detail .. text .. "\n" end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false; self.owner = nil end
GameTooltip = tooltip

local frameFactory=CreateFrame
CreateFrame=nil
dofile("addon/Lychee/Bootstrap.lua"); dofile("addon/Lychee/Core/CharacterStore.lua")
CreateFrame=frameFactory
dofile("addon/Lychee/UI/Theme.lua")
dofile("addon/Lychee/UI/Runtime.lua")
dofile("addon/Lychee/UI/Components.lua")
dofile("addon/Lychee/Core/InteractionBinding.lua")
dofile("addon/Lychee/UI/ResultList.lua")

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
local barTop,barBottom=list.scrollbar.frame.points[1],list.scrollbar.frame.points[2]
assert(barTop[2]==parent and barTop[4]==0,"scrollbar right edge belongs to outer content gutter")
assert(barBottom[2]==list.frame and barBottom[4]==Lychee.UI.Theme.Metrics.listInset,"scrollbar compensates for row inset")
assert(list.gridColumns == 1 and list.frame:GetHeight() == 410, "result list uses a compact single column")
for index = 1, 8 do
    local row = list.rows[index]
    assert(row:GetHeight() == 46, "row height remains fixed")
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
        source = "lychee.player-spells:records",
        icon = 4578416,
        _ext = "lychee.player-spells",
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
assert(rowOne.session == 11 and rowOne.generation == 23 and rowOne.extensionID == "lychee.player-spells", "freshness fields bind to row")
assert(rowOne.title:GetText() == longText and rowOne.subtext:GetText() == longText, "name and description remain separately constrained")
assert(#rowOne.title.points == titlePointCount and rowOne:GetHeight() == 46, "long text cannot mutate row geometry")
assert(rowOne.title.maxLines == 1 and rowOne.title.wordWrap == false, "title is constrained to one line")
assert(rowOne.category:GetText() == "自定义类型", "type label takes precedence over category")
assert(rowOne.category.nonSpaceWrap == false and rowOne.category.wordWrap == false and rowOne.category.maxLines == 1,
    "source labels must disable both word and non-space wrapping")
assert(rowOne.category._lycheeTextToken == Lychee.UI.Theme.Colors.textDim and rowTwo.category._lycheeTextToken == Lychee.UI.Theme.Colors.textDim,
    "all result labels use the same subdued theme color, including colored provider categories")
assert(rowOne.icon:IsShown() and rowOne.icon.texture == 4578416, "icon is rendered in reserved slot")
assert(rowOne.dragger:IsShown() and rowOne.dragDescriptor.spellID == 393256, "drag area binds descriptor")
assert(rowOne.primaryAction.id == "cast" and rowOne.primaryHint:GetText() == "", "primary action label stays out of the compact row")
assert(rowOne.secondaryAction.id == "detail" and rowOne.secondary:IsShown(), "first non-primary action is exposed as secondary")
assert(rowOne._categoryInset == 42, "visible secondary button keeps label clear")
assert(rowTwo._categoryInset == 12, "label without visible secondary button matches icon inset")

assert(list.selected == 1 and rowOne._selected, "first result is keyboard-selected")
assert(rowOne.bg._lycheeColorToken==Lychee.UI.Theme.Colors.surfaceSelected,"selected row uses the shared subtle fill")
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
local tip = Lychee.UI.Components.tooltip
assert(tip:IsShown() and tip.labels[1]:GetText() == longText, "hover keeps the item title")
assert(tip.labels[2]:GetText() == "自定义类型", "tooltip keeps useful type without internal search diagnostics")
assert(tip.labels[4]:GetText():find("施放",1,true), "tooltip shows the declared primary action")
assert(not GameTooltip.shown and GameTooltip.text == nil, "result tooltip never changes the global tooltip")
assert(tip.clamped and not tip.mouseEnabled, "tooltip stays on screen without intercepting clicks")
local beforeMove = tip.points[1]
local beforeX, beforeY = beforeMove[4], beforeMove[5]
cursorX, cursorY = 140, 230
if tip.scripts.OnUpdate then tip.scripts.OnUpdate(tip, 0.016) end
local afterMove = tip.points[1]
assert(afterMove[4] ~= beforeX and afterMove[5] ~= beforeY, "tooltip must follow cursor movement within the same hovered entry")
assert(afterMove[2] == UIParent and afterMove[4] == cursorX / tip:GetEffectiveScale() + 12,
    "cursor position uses tooltip effective scale outside the scroll tree")
tip.scripts.OnUpdate(tip, 0.016)
assert(tip.points[1] == afterMove, "stationary cursor does not repeat anchor setters")
UIParent:SetScale(0.75)
tip.scripts.OnUpdate(tip, 0.016)
assert(tip.points[1][4] == cursorX / tip:GetEffectiveScale() + 12, "root UI scale changes refresh cursor coordinates")
UIParent:SetScale(1)
tip.scripts.OnUpdate(tip, 0.016)
local trackingObjects = #created
collectgarbage("collect"); collectgarbage("stop")
local trackingMemory = collectgarbage("count")
for _ = 1, 1000 do tip.scripts.OnUpdate(tip, 0.016) end
local trackingAllocation = collectgarbage("count") - trackingMemory
collectgarbage("restart")
assert(trackingAllocation < 64 and #created == trackingObjects, "stationary tracking stays bounded without new UI objects")
print(string.format("Tooltip tracking: 1000 stationary frames %.2f KiB allocation, 0 new objects", trackingAllocation))
cursorX, cursorY = 710, 490
tip.scripts.OnUpdate(tip, 0.016)
local edge = tip.points[1]
assert(edge[4] + tip:GetWidth() < cursorX / tip:GetEffectiveScale()
    and edge[5] + tip:GetHeight() < cursorY / tip:GetEffectiveScale(), "screen edge flips tooltip away from pointer")
cursorX, cursorY = 140, 230
tip.scripts.OnUpdate(tip, 0.016)
assert(tip.labels[1].font[2] > tip.labels[2].font[2] and tip.labels[1].shadow[1] == 0, "owned fonts preserve hierarchy without inherited shadows")
frameCount = #created
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(#created == frameCount and Lychee.UI.Components.tooltip == tip, "repeat hover reuses all tooltip objects")
tip.labels[3].measuredHeight = 60
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
local expandedHeight = tip:GetHeight()
assert(tip.labels[4]._y >= tip.labels[3]._y + 60, "wrapped description cannot overlap actions")
tip.labels[3].measuredHeight = 15
rowOne.primaryTarget.scripts.OnEnter(rowOne.primaryTarget)
assert(tip:GetHeight() < expandedHeight, "tooltip shrinks again when measured content shortens")
rowOne.primaryTarget.scripts.OnLeave(rowOne.primaryTarget)
assert(not tip:IsShown() and tip._owner == nil, "leave hides tooltip and releases owner")
assert(tip.scripts.OnUpdate == nil, "leave stops cursor updates")
list:Select(1)
rowOne.secondary.scripts.OnMouseDown(rowOne.secondary,"LeftButton")
rowOne.secondary.scripts.OnClick(rowOne.secondary)
assert(activatedAction and activatedAction[1] == rowOne and activatedAction[2] == "detail", "secondary action delegates stable action ID")
rowOne.dragger.scripts.OnMouseDown(rowOne.dragger,"LeftButton")
rowOne.dragger.scripts.OnDragStart(rowOne.dragger)
assert(draggedRow == rowOne, "drag area delegates its owning row")
rowOne.primaryTarget.scripts.OnMouseDown(rowOne.primaryTarget,"LeftButton")
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
local recentTip = Lychee.UI.Components.tooltip
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
Lychee.UI.Components:HideTooltip(rowOne)
assert(recentTip:IsShown(), "stale owner leave cannot close the current tooltip")
recentOwner:Hide()
recentTip.scripts.OnUpdate(recentTip, 0.016)
assert(not recentTip:IsShown() and not recentTip.scripts.OnUpdate, "hidden owner stops root-owned tooltip tracking")
recentOwner:Show()
Lychee.UI.ResultList:ShowItemTooltip(items[1], recentOwner)
local originalCombat = InCombatLockdown
InCombatLockdown = function() return true end
recentTip.scripts.OnUpdate(recentTip, 0.016)
assert(not recentTip:IsShown() and not recentTip.scripts.OnUpdate, "combat interrupts cursor tracking")
InCombatLockdown = originalCombat
Lychee.UI.ResultList:ShowItemTooltip(items[1], recentOwner)
recentTip.scripts.OnHide(recentTip)
assert(not recentTip._owner and not recentTip.scripts.OnUpdate, "direct hide releases tracking and owner")
recentTip:Hide()
Lychee.UI.ResultList:ShowItemTooltip(items[1], recentOwner)
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

dofile("addon/Lychee/UI/Runtime.lua")

-- Artwork is not a state glyph: hovering/pressing a labelled skill changes text only.
local skillButton=Lychee.UI.Components:CreateNavigationButton(parent,{text="萨拉塔斯的赠礼"})
skillButton.icon=object("Texture",skillButton.frame)
local artworkTints=0
function skillButton.icon:SetVertexColor() artworkTints=artworkTints+1 end
skillButton.frame.scripts.OnEnter()
assert(skillButton.label._lycheeTextToken==Lychee.UI.Theme.Colors.accentHover,"hover highlights the skill name")
skillButton.frame.scripts.OnMouseDown()
skillButton.frame.scripts.OnLeave()
skillButton.frame.scripts.OnHide()
assert(artworkTints==0,"hover, press and leave must preserve the original skill artwork colors")
skillButton.feedbackIcon=object("Texture",skillButton.frame)
local glyphTints=0
function skillButton.feedbackIcon:SetVertexColor() glyphTints=glyphTints+1 end
skillButton.frame.scripts.OnEnter()
assert(glyphTints==1 and artworkTints==0,"only an explicitly designated navigation glyph receives state tint")
assert(skillButton.feedbackIcon._lycheeVertexToken==Lychee.UI.Theme.Colors.accentHover)
skillButton.frame.scripts.OnLeave()
assert(skillButton.feedbackIcon._lycheeVertexToken==Lychee.UI.Theme.Colors.text and artworkTints==0,"navigation glyph returns to warm white without tinting artwork")

-- Real owned menu: a global native reskin must never receive its frame.
local menuOwner=object("Frame")
local nativeOpens=0
MenuUtil={CreateContextMenu=function() nativeOpens=nativeOpens+1;error("global menu reskin reached") end}
function GetCursorPosition() return 100,200 end
local actions=0
local function populate(_,root)
    root:CreateButton("Action",function() actions=actions+1;return true end)
    root:CreateButton(string.rep("Long title ",50),function() actions=actions+10 end)
end
local menu=Lychee.UI.Components:ShowActionMenu(menuOwner,populate)
assert(nativeOpens==0 and menu.owner==menuOwner and menu:IsShown())
assert(menu.heading:GetText():find("菜单",1,true) and menu.heading:GetText():find("game-menu.tga",1,true), "menu has a distinct localized identity")
assert(menu:GetWidth()<=296 and menu.count==2 and menu.buttons[2].label.wordWrap==false)
local button=menu.buttons[1]
button.frame.scripts.OnClick();assert(actions==0,"click requires a physical press")
button.frame.scripts.OnMouseDown(nil,"LeftButton")
assert(button.frame.scripts.OnClick() and actions==1)
assert(not menu.owner and not menu:IsShown() and not button.callback,"closing releases all captured actions")
local allocated=#created
for _=1,20 do
    assert(Lychee.UI.Components:ShowActionMenu(menuOwner,populate)==menu)
    button.frame.scripts.OnMouseDown(nil,"LeftButton")
    Lychee.UI.Components:ShowActionMenu(menuOwner,populate)
    button.frame.scripts.OnClick();assert(actions==1,"reopening cancels stale presses")
    menuOwner.scripts.OnHide();assert(not menu.owner,"owner hide closes menu")
end
assert(#created==allocated,"menu and buttons are reused")
Lychee.UI.Components:ShowActionMenu(menuOwner,function(_,root)
    for _=1,18 do root:CreateButton("Action",function() end) end
end)
assert(menu.count==18 and menu:GetHeight()*menu.scale<=UIParent:GetHeight()-32,"all supported actions fit the viewport")
Lychee.UI.Components:HideActionMenu()

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
local scores={}
for index=1,8 do scores[index]={"副本"..index,"限时 +12","|cffaa00ff329.0|r"} end
local keyItem={text="角色 · 副本 +12",kindTitle="分数 2500",providerID="lychee.keystones",searchRecord={tooltipRows=scores}}
local beforeScores=#created
Lychee.UI.ResultList:ShowItemTooltip(keyItem,parent)
assert(tip:GetWidth()==416 and #tip.scoreLabels==9,"eight dungeon rows and column header")
assert(#created-beforeScores==27,"only bounded FontStrings are created on first score hover")
assert(tip.scoreLabels[3][2]:GetText()=="限时 +12" and tip.scoreLabels[3][3]:GetText()=="|cffaa00ff329.0|r")
local afterScores=#created
Lychee.UI.ResultList:ShowItemTooltip(keyItem,parent)
assert(#created==afterScores,"score hover reuses labels")
Lychee.UI.ResultList:ShowItemTooltip(items[1],parent)
assert(tip:GetWidth()==280,"ordinary tooltip width restored")
for _,labels in ipairs(tip.scoreLabels) do
    for _,label in ipairs(labels) do assert(not label:IsShown() and label:GetText()=="","old scores released") end
end
assert(rowOne.accent:GetWidth()==2 and rowOne.accent:GetHeight()==22,"selection matches recent list")
local measuredLabel=list.rows[1].category
local measures=0
measuredLabel.GetStringWidth=function() measures=measures+1;return 0 end
measuredLabel.GetUnboundedStringWidth=measuredLabel.GetStringWidth
list:SetItems({{id="long-kind",text="首领名称",kindTitle="荔枝大米助手 · 首领",
    interaction={actions={{id="open",title="打开"},{id="more",title="更多"}}}}},12,24)
local sourceLabel=list.rows[1].category
assert(sourceLabel:GetWidth()==160 and measures==0,"source column is ready before native font metrics exist")
assert(sourceLabel:GetWidth()<=160,"source column cannot consume unbounded title space")
assert(list.rows[1]._categoryInset==42,"selected secondary action remains outside source text")
list:SetItems({{id="huge-kind",text="名称",kindTitle=string.rep("很长的来源",50)}},12,25)
assert(list.rows[1].category:GetWidth()<=160 and list.rows[1].category.maxLines==1,"overlong source clips on one line")
list:SetItems({{id="short-kind",text="名称",kindTitle="成就"}},12,26)
assert(sourceLabel:GetWidth()==160 and measures==0,"short source does not move the title boundary or measure text")
print("Lychee result list UI smoke PASS")
