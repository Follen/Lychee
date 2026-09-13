local env=dofile("tests/support/palette.lua")
local Fixture=dofile("tests/support/provider_fixture.lua")
local root="addon/Lychee/"
local homeGeometryCalls,tooltipText=env.geometry,env.tooltipText
local I = _G.LycheeInternal
local assertEq = function(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function makeInteractionRow(item, extensionID, session, generation)
    local row = { item = item, extensionID = extensionID, session = session, generation = generation, shown = true, actions = {}, dragger = { shown = true } }
    function row:IsShown() return self.shown end
    function row:SetShown(value) self.shown = not not value end
    function row.dragger:IsShown() return self.shown end
    function row.dragger:SetShown(value) self.shown = not not value end
    for index = 1, 4 do
        local action = { shown = true }
        function action:IsShown() return self.shown end
        function action:SetShown(value) self.shown = not not value end
        row.actions[index] = action
    end
    return row
end

-- Scheduler: first subscriber shows the shared driver; last removal hides it.
local scheduler = I.Scheduler
scheduler:Clear()
assert(not scheduler.frame or not scheduler.frame:IsShown(), "scheduler initially hidden")
assert(scheduler:Add("interaction-smoke", function() return false end))
assertEq(scheduler.frame:IsShown(), true, "scheduler shown with subscriber")
scheduler:_Tick(0.016)
assertEq(scheduler.frame:IsShown(), false, "scheduler hidden after self removal")
assertEq(#scheduler.keys, 0, "scheduler subscriber cleanup")

-- ViewHost: transition state reaches create and unmount/dispose are both called.
local parent = CreateFrame("Frame", nil, UIParent)
local host = _G.Lychee.UI.ViewHost:Create(parent)
local createdState, unmounted, disposed
local factory = {
    create = function(context, state)
        createdState = state
        return {
            Mount = function() return true end,
            Unmount = function() unmounted = true end,
            Dispose = function() disposed = true end,
        }
    end,
}
assert(host:Mount(factory, {}, { itemID = 42 }))
assertEq(createdState.itemID, 42, "panel state passed to create")
host:Unmount("interaction-smoke")
assertEq(unmounted, true, "panel unmount cleanup")
assertEq(disposed, true, "panel dispose cleanup")

-- Palette combat/secure/drag guards.
assert(not Lychee.UI.Palette.frame, "palette remains lazy until first open")
_G.__combat=true;Lychee_Toggle();_G.__combat=false
assert(not Lychee.UI.Palette.frame, "first combat hotkey creates no protected UI")
local palette = (function()
    local before=env.state.createdFrames
    local result=Lychee.UI.Palette:Create()
    print("Lazy Palette: "..(env.state.createdFrames-before).." frame creations deferred until first open")
    return result
end)()
do
    local view=LycheeInternal.Host.PaletteController.homeView
    view.frame:Show()
    local before=view.frame.rectUpdates or 0
    view.frame:SetHeight(300)
    view.frame.scripts.OnSizeChanged(view.frame)
    assert((view.frame.rectUpdates or 0)>before,"expanded recent viewport must refresh native scroll bounds")
    before=view.frame.rectUpdates
    view.frame.scripts.OnSizeChanged(view.frame)
    assert(view.frame.rectUpdates==before,"identical viewport must not refresh native bounds")
    assert(view.frame.scripts.OnShow,"first show must flush scroll bounds built while hidden")
    view.frame.scripts.OnShow(view.frame)
    assert(view.frame.rectUpdates>before)
    before=view.frame.rectUpdates
    view.frame:Hide();view.frame:SetHeight(320)
    view.frame.scripts.OnSizeChanged(view.frame)
    assert(view.frame.rectUpdates==before,"hidden layout waits until shown")
    view.frame:Show();view.frame.scripts.OnShow(view.frame)
    assert(view.frame.rectUpdates>before,"reopening flushes hidden geometry")
    before=view.frame.rectUpdates
    _G.__combat=true;view._scrollRectDirty=true;view:RefreshScrollRect()
    assert(view.frame.rectUpdates==before and view._scrollRectDirty,"combat defers bounds refresh")
    _G.__combat=false;view:RefreshScrollRect()
    assert(view.frame.rectUpdates>before and not view._scrollRectDirty)
    print("Recent scroll bounds lifecycle PASS")
end
assert(palette)
assertEq(palette.frame:GetWidth(), 640, "compact palette width")
assertEq(palette.frame:GetHeight(), 220, "initial palette height")
assert(palette.header and palette.content and palette.footer and palette.emptyState, "palette workbench regions")
assert(palette.headerComponent and palette.footerComponent and palette.contentComponent, "palette uses reusable surface components")
assert(palette.brandComponent and palette.brandComponent.icon.texture == "Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga", "palette logo component is wired")
assert(palette.closeComponent and palette.statusComponent and palette.emptyStateComponent, "palette control components are wired")
assertEq(palette.closeComponent.label._lycheeTextToken, Lychee.UI.Theme.Colors.accent, "Esc uses the red theme token")
local tooltipShows = 0
GameTooltip = { SetOwner = function() end, SetText = function(self, value) self.text = value; self.lines = {} end,
    AddLine = function(self, value) self.lines[#self.lines + 1] = value end,
    Show = function() tooltipShows = tooltipShows + 1 end, Hide = function() end }
palette.close.scripts.OnEnter(palette.close)
assertEq(tooltipShows, 0, "Esc never shows a tooltip")
assertEq(palette.closeComponent.label._lycheeTextToken, Lychee.UI.Theme.Colors.accentHover, "Esc hover brightens red text")
assertEq(palette.closeComponent.bg._lycheeColorToken[4], 0, "Esc hover has no background")
palette.close.scripts.OnMouseDown(palette.close)
assertEq(palette.closeComponent.bg._lycheeColorToken[4], 0, "Esc pressed has no background")
palette.close.scripts.OnMouseUp(palette.close)
palette.close.scripts.OnLeave(palette.close)
assertEq(palette.closeComponent.label._lycheeTextToken, Lychee.UI.Theme.Colors.accent, "Esc leave restores red text")
assertEq(palette.closeComponent.bg._lycheeColorToken[4], 0, "Esc normal has no background")
local logoSetCalls = palette.brandComponent.icon.setterCalls and (palette.brandComponent.icon.setterCalls.SetTexture or 0) or 0
assert(palette.brandComponent:SetTexture("Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga") == false, "brand texture setter is guarded")
assert((palette.brandComponent.icon.setterCalls and (palette.brandComponent.icon.setterCalls.SetTexture or 0) or 0) == logoSetCalls, "guarded logo setter does not repaint")
for _, region in ipairs({ palette.frame, palette.header, palette.content, palette.footer, palette.homeView.frame, palette.list.frame, palette.emptyState }) do
    assert(not region.scripts.OnUpdate, "palette regions do not install OnUpdate")
end
assert(type(palette.onQuery) == "function", "palette query callback was not wired")
assert(palette:Show())
local firstSession, firstGeneration = palette.session, palette.generation
palette.onQuery("stale-generation")
assert(palette.session == firstSession and palette.generation > firstGeneration, "search session did not advance generation")
assert(palette.generation == I.Search.Session.generation, "palette and search session generations diverged")
palette:Hide("session-smoke")
_G.__combat = true
local toggleOK, toggleErr = palette:Toggle()
assertEq(toggleOK, false, "combat toggle result")
assertEq(toggleErr, "COMBAT_LOCKED", "combat toggle error")
local secureBroker = I.Host.SecureBroker
local secureButton, secureErr = secureBroker:Prepare({ kind = "secure-spell", spellID = 31884 }, {})
assertEq(secureButton, nil, "combat secure prepare")
assertEq(secureErr, "COMBAT_LOCKED", "combat secure error")
_G.__combat = false

local originalRefreshHomeSections = palette.RefreshHomeSections
local showHomeRefreshes = 0
palette.RefreshHomeSections = function(self, ...)
    showHomeRefreshes = showHomeRefreshes + 1
    return originalRefreshHomeSections(self, ...)
end
assert(palette:Show())
assertEq(showHomeRefreshes, 1, "empty-query show refreshes home once")
palette.RefreshHomeSections = originalRefreshHomeSections
assert(palette.frame.scripts.OnEvent, "palette combat event handler")
_G.__combat = true
-- The engine evaluates this snippet securely; the Lua event only stops work.
RunPaletteCombatSnippet(palette.frame)
assert(not palette.escapeFrame:IsShown(),"secure combat hide also releases the Escape receiver")
palette.frame.scripts.OnEvent(palette.frame, "PLAYER_REGEN_DISABLED")
assertEq(palette.visible, false, "combat event closes palette")
assertEq(palette.frame:IsShown(), false, "combat event hides palette frame")
_G.__combat = false
palette.frame.scripts.OnEvent(palette.frame, "PLAYER_REGEN_ENABLED")
assertEq(palette.frame:IsShown(), false, "leaving combat does not reopen palette")
assert(palette:Show())
palette:SetQueryMode("")
assertEq(palette.homeView.frame:IsShown(), true, "empty query shows home view")
assertEq(palette.list.frame:IsShown(), false, "empty query hides search view")
palette:SetQueryMode("技能")
assertEq(palette.homeView.frame:IsShown(), false, "non-empty query hides home view")
assertEq(palette.list.frame:IsShown(), false, "non-empty query without results hides search view")
assertEq(palette.emptyState:IsShown(), true, "non-empty query without results shows empty state")
palette:SetQueryMode("")
assertEq(palette.emptyState:IsShown(), false, "home mode hides empty state")
local homeSelection = palette.homeView.selected
palette.input.frame.scripts.OnArrowPressed(palette.input.frame, "DOWN")
if #palette.homeView.sections > 0 then
    assert(palette.homeView.selected >= 1 and palette.homeView.selected <= #palette.homeView.sections, "home keyboard navigation keeps a valid selection")
    if #palette.homeView.sections > 1 then assert(palette.homeView.selected ~= homeSelection, "home keyboard navigation advances selection") end
end
local keyboardSelection = palette.homeView.selected
local hoverTile = palette.homeView.tiles[math.max(1, keyboardSelection - 1)]
hoverTile.scripts.OnEnter(hoverTile)
hoverTile.scripts.OnLeave(hoverTile)
assertEq(palette.homeView.selected, hoverTile.index or keyboardSelection, "home hover shares the current selection")
local palettePanel = {
    create = function()
        return { Mount = function() return true end, Unmount = function() end, Dispose = function() end }
    end,
}
assert(palette:OpenView(palettePanel, {}, {}))
assertEq(palette.viewHost:IsActive(), true, "palette view host active")
assertEq(palette.homeView.frame:IsShown(), false, "panel hides home view")
assertEq(palette.list.frame:IsShown(), false, "panel hides search view")
assertEq(palette.emptyState:IsShown(), false, "panel hides empty state")
assert(palette:SetResults({ { id = "panel-result", text = "Panel result" } }, palette.generation, palette.session))
assertEq(palette.viewHost:IsActive(), true, "result callback keeps active panel mounted")
assertEq(palette.viewHost.frame:IsShown(), true, "result callback keeps panel visible")
assertEq(palette.homeView.frame:IsShown(), false, "result callback does not reveal home behind panel")
assertEq(palette.list.frame:IsShown(), false, "result callback does not reveal results behind panel")
assertEq(palette.emptyState:IsShown(), false, "result callback does not reveal empty state behind panel")
palette:CloseView("fixture-close")
assertEq(palette.homeView.frame:IsShown(), true, "closing panel restores current query mode")
I.Registry:SetReady(true)

-- Public Providers preserve ordinary actions, owned panels and same-ID isolation.
local foreignActionCalls=0
local foreignHandle=assert(Fixture:Register({id="interaction.foreign",title="Foreign",version="1",apiVersion="1.0.0",
    catalog={{id="foreign",title="越权动作",actions={"open"}}},
    actions={open={title="打开",run=function() foreignActionCalls=foreignActionCalls+1;return {ok=true} end}}}))
local actionCalled,panelMounted,openPanel=false,false,false
local actionHandle=assert(Fixture:Register({id="interaction.actions",title="Actions",version="1",apiVersion="1.0.0",
    catalog={{id="spell:interaction-action",kind="spell",category={id="spells",title={default="Spells",zhCN="技能"}},
        title="动作技能",aliases={{text="动作",locale="zhCN"}},description={{text="可执行普通动作。",locale="zhCN"}},
        actions={"open",{id="panel",title="面板",kind="open-panel",panel="detail",state={itemID=7}},
            {id="drag",title="拖拽",kind="drag-spell",spellID=31884}}}},
    actions={open={title="打开",run=function()
        if openPanel then return {ok=true,view="detail",state={itemID=7}} end
        actionCalled=true;return {ok=true}
    end}},
    views={detail={stateSchema={itemID="integer"},create=function(_,state)
        assert(state.itemID==7)
        return {Mount=function() panelMounted=true;return true end,Unmount=function() end,Dispose=function() end}
    end}}}))
local extraHandles={}
for sourceIndex=1,21 do
    extraHandles[#extraHandles+1]=assert(Fixture:Register({id=string.format("overflow-%02d",sourceIndex),apiVersion="1.0.0",title="Additional source",version="1",catalog={}}))
end
local extraHandle={Unregister=function() for _,h in ipairs(extraHandles) do h:Unregister() end end}
assert(actionHandle:GetState().enabled==true)
local actionGeneration, actionResults = I.Search.Query:Query("动作", { visible = true })
assert(#actionResults > 0, "search returned action record")
local actionItem = actionResults[1]
assertEq(actionItem.category, "技能", "search result category")
assertEq(actionItem.description, "可执行普通动作。", "localized array description")
assertEq(actionItem.interaction.actions[1].title, "打开", "localized action title")
assert(actionItem.sourceID and actionItem._providerInstance and actionItem._providerRevision, "source state retained on result")
actionItem.searchRecord._extensionID = nil
actionGeneration, actionResults = I.Search.Query:Query("动作", { visible = true })
actionItem = actionResults[1]
assertEq(actionItem._ext, "interaction.actions", "search result extension ownership")
assert(actionItem.evidence and actionItem.evidence.matchedField == "alias", "search result evidence")
assert(actionItem.confidence and actionItem.confidence >= 0.85, "search result confidence")
local categoryGeneration, categoryResults = I.Search.Query:Query("技能 动作", { visible = true })
assert(categoryGeneration and #categoryResults > 0 and categoryResults[1].category == "技能", "category filter result")
actionItem=categoryResults[1];actionResults=categoryResults;actionGeneration=categoryGeneration
openPanel=true
assert(palette:SetResults({ actionItem }, palette.generation, palette.session))
local routedPanel, routedPanelErr = palette:ActivateRowAction(palette.list.rows[1], "open")
assert(routedPanel and panelMounted, "search record intent mounts owner panel: " .. tostring(routedPanelErr))
openPanel=false
palette:SetResults(actionResults, actionGeneration, palette.session)
local actionRow = palette.list.rows[1]
assert(actionRow.primaryAction and actionRow.primaryAction.id == "open", "primary action is rendered from the generic protocol")
assertEq(actionRow.primaryHint:GetText(), "", "primary action title stays in tooltip")
assert(palette:TouchRecent(actionItem))
assert(palette:SetPinned(actionItem, true))
palette:RefreshHomeSections()
assert(LycheeCharacterDB.palette and LycheeCharacterDB.palette.recent[1].entryID == actionItem.id, "recent stores stable id")
assert(LycheeCharacterDB.pinned[1].entryID == actionItem.id and LycheeCharacterDB.pinned[1].providerID == actionItem.ref.providerID, "pinned stores qualified stable ref")
local hasRecent = false
for sectionIndex = 1, #(palette.homeView.sections or {}) do
    local section = palette.homeView.sections[sectionIndex]
    if section.id == "saved:" .. actionItem.ref.providerID .. ":" .. actionItem.id then hasRecent = true end
end
assert(hasRecent and #palette.homeView.sections == 2, "home contains pins and recent items")
assert(#palette.homeView.tiles >= #palette.homeView.sections, "home tile pool grows to the section count")
assert(#palette.homeView.headers >= 1, "home renders the recent group header")
assertEq(palette.homeView.headers[1].point[4], 12, "recent title has its own horizontal inset")
assertEq(palette.homeView.headers[1].point[5], -10, "recent title clears the header divider")
local groupIDs = {}
for sectionIndex = 1, #palette.homeView.sections do groupIDs[palette.homeView.sections[sectionIndex].groupID] = true end
assert(groupIDs.recent and groupIDs.pinned and not groupIDs.categories and not groupIDs.extensions, "home groups are pins and recent")
assertEq(palette.homeView.frame:GetScrollChild(), palette.homeView.content, "home uses a scroll child")
assert(palette:SetPinned(actionItem, false))
palette:RefreshHomeSections()
assert(palette.homeView.content:GetHeight() >= 1, "home content has measurable height")
local renderedSources = {}
local firstHomeTile = palette.homeView.tiles[1]
for tileIndex = 1, #palette.homeView.sections do
    local tile = palette.homeView.tiles[tileIndex]
    assert(tile and tile:IsShown() and tile.section == palette.homeView.sections[tileIndex], "home tile renders section " .. tileIndex)
    if tile.section.id:sub(1, 7) == "source:" then renderedSources[tile.section.id] = true end
end
local homeSetterCalls, restores = 0, {}
local function resetHomeGeometryCalls()
    homeGeometryCalls.ClearAllPoints = 0
    homeGeometryCalls.SetPoint = 0
    homeGeometryCalls.SetVerticalScroll = 0
end
local function countCalls(objectValue, method)
    local original = objectValue[method]
    restores[#restores + 1] = { objectValue, method, original }
    objectValue[method] = function(self, ...)
        homeSetterCalls = homeSetterCalls + 1
        return original(self, ...)
    end
end
for tileIndex = 1, #palette.homeView.sections do
    local tile = palette.homeView.tiles[tileIndex]
    countCalls(tile.title, "SetText")
    countCalls(tile.icon, "SetTexture")
    countCalls(tile.icon, "SetShown")
    countCalls(tile, "SetShown")
end
resetHomeGeometryCalls()
palette:RefreshHomeSections()
assertEq(homeSetterCalls, 0, "unchanged home refresh skips native setters")
assertEq(homeGeometryCalls.ClearAllPoints, 0, "unchanged home refresh preserves anchors")
assertEq(homeGeometryCalls.SetPoint, 0, "unchanged home refresh skips anchor setters")
assertEq(homeGeometryCalls.SetVerticalScroll, 0, "unchanged home refresh preserves scroll")
assertEq(palette.homeView.tiles[1], firstHomeTile, "unchanged home refresh reuses tile objects")
for restoreIndex = 1, #restores do
    local restore = restores[restoreIndex]
    restore[1][restore[2]] = restore[3]
end

local stableHomeSections = palette.homeView.sections
palette.homeView.scroll = 42
resetHomeGeometryCalls()
palette.homeView:SetSections(stableHomeSections)
assertEq(homeGeometryCalls.ClearAllPoints, 0, "scroll-only refresh preserves anchors")
assertEq(homeGeometryCalls.SetPoint, 0, "scroll-only refresh skips anchor setters")
assert(homeGeometryCalls.SetVerticalScroll == 0 or homeGeometryCalls.SetVerticalScroll == 1, "scroll refresh remains bounded")
palette.homeView:SetSections(stableHomeSections)
assert(homeGeometryCalls.SetVerticalScroll <= 1, "unchanged scroll remains bounded")

local shiftedHomeSections = {}
shiftedHomeSections[1] = {}
for key, value in pairs(stableHomeSections[1]) do shiftedHomeSections[1][key] = value end
shiftedHomeSections[1].id = "layout-test:" .. tostring(stableHomeSections[1].id)
for sectionIndex = 1, #stableHomeSections do shiftedHomeSections[sectionIndex + 1] = stableHomeSections[sectionIndex] end
resetHomeGeometryCalls()
palette.homeView:SetSections(shiftedHomeSections, true)
assert(homeGeometryCalls.ClearAllPoints > 0, "changed Home layout clears affected anchors")
assert(homeGeometryCalls.SetPoint > 0, "changed Home layout applies affected anchors")
palette.homeView.scroll = 0
palette.homeView:SetSections(stableHomeSections, true)

palette.activeFilter = nil
palette:SetQueryMode("")
local scans = 0
local originalResolveRecent = I.Search.Query.ResolveRecent
I.Search.Query.ResolveRecent = function(self, ...)
    scans = scans + 1
    return originalResolveRecent(self, ...)
end
local framesBeforeTyping = env.state.createdFrames
palette.input.frame:SetText("动")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
palette.input.frame:SetText("动作")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
assertEq(env.state.createdFrames, framesBeforeTyping, "input changes never create Home frames")
assertEq(scans, 0, "ordinary keystrokes do not rebuild the Home index")
assert(#palette.list.items > 0, "completed synchronous query produces results")
palette.input.frame:SetText("不存在")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
assertEq(#palette.list.items, 0, "query change clears stale rows before accepting replacement results")
for rowIndex = 1, #palette.list.rows do assertEq(palette.list.rows[rowIndex]:IsShown(), false, "stale row hidden " .. rowIndex) end

palette.input.frame:SetText("")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
scans = 0
assert(actionHandle:Invalidate())
assertEq(scans, 1, "source lifecycle refreshes Home immediately while visible")
palette.input.frame:SetText("动作")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
scans = 0
assert(actionHandle:Invalidate())
assertEq(scans, 0, "source lifecycle only marks Home dirty outside Home mode")
I.Search.Query.ResolveRecent = originalResolveRecent

local steadyColorCalls = 0
local colorTile = palette.homeView.tiles[1]
local originalSetColorTexture = colorTile.bg.SetColorTexture
colorTile.bg.SetColorTexture = function(self, ...)
    steadyColorCalls = steadyColorCalls + 1
    return originalSetColorTexture(self, ...)
end
palette.homeView:RenderTileState(colorTile)
palette.homeView:RenderTileState(colorTile)
assertEq(steadyColorCalls, 0, "unchanged tile state skips native color setters")
colorTile.bg.SetColorTexture = originalSetColorTexture
palette.input.frame:SetText("动作")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
actionRow = palette.list.rows[1]
assert(actionRow and actionRow.item and actionRow.item.id == actionItem.id, "action fixture refreshes after source invalidation")
actionItem = actionRow.item
local ordinaryResult, ordinaryErr = palette:ActivateRowAction(actionRow, "open")
assert(ordinaryResult and ordinaryResult.ok == true and actionCalled, "ordinary action execution: " .. tostring(ordinaryErr))
assertEq(foreignActionCalls, 0, "SearchRecord rejects foreign same-type Handler")
local _,foreignActionResults=I.Search.Query:Query("越权动作",{visible=true})
assert(palette:SetResults(foreignActionResults,palette.generation,palette.session))
assert(palette:ActivateRowAction(palette.list.rows[1],"open"))
assertEq(foreignActionCalls,1,"same action ID executes only its owning Provider")
actionItem=assert(I.Providers:Resolve({providerID="interaction.actions",entryID=actionItem.id}))
assert(palette:SetResults({ actionItem }, palette.generation, palette.session))
actionRow = palette.list.rows[1]
local panelResult, panelErr = palette:ActivateRowAction(actionRow, "panel")
assert(panelResult and panelMounted, "direct panel action: " .. tostring(panelErr))
local pickupBefore = _G.__pickup or 0
local dragResult, dragErr = palette:ActivateRowAction(actionRow, "drag")
assert(dragResult and (_G.__pickup or 0) == pickupBefore + 1, "direct drag action: " .. tostring(dragErr))
_G.__combat = true
local combatAction, combatActionErr = palette:ActivateRowAction(actionRow, "open")
assertEq(combatAction, false, "ordinary combat action")
assertEq(combatActionErr, "COMBAT_LOCKED", "ordinary combat action error")
_G.__combat = false
actionItem.searchRecord.availability = { contextKey = "interactionReady", equals = true }
I.Context:Set("interactionReady", false)
local unavailableToken, unavailableTokenErr = secureBroker:ValidateToken({
    controller = palette, row = actionRow, item = actionItem, extensionID = actionRow.extensionID,
    session = palette.session, generation = palette.generation,
})
assertEq(unavailableToken, false, "secure token availability")
assertEq(unavailableTokenErr, "ACTION_UNAVAILABLE", "secure token availability error")
actionItem.interaction.drag = { type = "spell", spellID = 31884 }
local unavailableDrag, unavailableDragErr = palette:BeginRowDrag(actionRow)
assertEq(unavailableDrag, false, "drag availability")
assertEq(unavailableDragErr, "ACTION_UNAVAILABLE", "drag availability error")
local unavailableAction, unavailableErr = palette:ActivateRowAction(actionRow, "open")
assertEq(unavailableAction, false, "record availability")
assertEq(unavailableErr, "ACTION_UNAVAILABLE", "record availability error")
I.Context:Set("interactionReady", true)
actionItem.searchRecord.availability = nil

-- SearchRecord action payloads are plain-data only; unknown executable fields are rejected.
local invalidDeclaration, invalidDeclarationErr = actionHandle.catalog:Update({upsert={
    {id="bad:record",title="Bad",actions={{id="bad",kind="secure-spell",spellID=1,script=function() end}}},
}})
assertEq(invalidDeclaration, nil, "invalid action declaration")
assert(invalidDeclarationErr and invalidDeclarationErr.code == "INVALID_SCHEMA", "invalid action schema error")

local retired,retiredErr=actionHandle.catalog:Update({upsert={
    {id="bad",title="Bad",actions={{id="bad",kind="intent",intent={type="retired",version=1}}}},
}})
assert(not retired and retiredErr.code=="INVALID_SCHEMA","retired intent declarations rejected")

-- Disabled extensions and stale generations invalidate result actions before execution.
assert(actionHandle:SetAvailability(false))
local disabledRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation)
local disabledCurrent, disabledErr = palette:IsRowCurrent(disabledRow)
assertEq(disabledCurrent, false, "disabled extension row")
assertEq(disabledErr, "EXTENSION_DISABLED", "disabled extension error")
assert(actionHandle:SetAvailability(true))
local staleRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation - 1)
local staleCurrent, staleGenerationErr = palette:IsRowCurrent(staleRow)
assertEq(staleCurrent, false, "stale generation row")
assertEq(staleGenerationErr, "STALE_GENERATION", "stale generation error")
assert(actionHandle.catalog:Update({upsert={{ id = "spell:new-generation", kind = "spell", title = "新代记录" }}}))
local sourceStaleRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation)
local sourceCurrent, sourceCurrentErr = palette:IsRowCurrent(sourceStaleRow)
assertEq(sourceCurrent, false, "stale source row")
assertEq(sourceCurrentErr, "STALE_GENERATION", "stale source row error")
assert(actionHandle:Unregister())
assert(foreignHandle:Unregister())

local interactionItem = { interaction = {
    primaryActionID = "cast",
    actions = { { id = "cast", kind = "secure-spell", spellID = 31884 } },
    drag = { type = "not-spell", spellID = 31884 },
} }
assert(palette:Show())
palette:SetResults({ interactionItem }, palette.generation, palette.session)
local interactionRow = palette.list.rows[1]
local preparedSecure = secureBroker.buttons[1]
assert(preparedSecure and preparedSecure:IsShown(), "secure spell button is prepared for visible row")
assert(preparedSecure:GetFrameLevel() > interactionRow.primaryTarget:GetFrameLevel(), "secure spell button is above its primary target")
_G.__combat = true
interactionRow.item.interaction.drag = { type = "spell", spellID = 31884 }
local combatDragOK, combatDragErr = palette:BeginRowDrag(interactionRow)
assertEq(combatDragOK, false, "combat drag result")
assertEq(combatDragErr, "COMBAT_LOCKED", "combat drag error")
_G.__combat = false
interactionRow.item.interaction.drag = { type = "not-spell", spellID = 31884 }
local actionOK, actionErr = palette:ActivateRowAction(interactionRow, "cast")
assertEq(actionOK, false, "scripted secure click")
assertEq(actionErr, "ACTION_REQUIRES_HARDWARE_CLICK", "scripted secure error")
local primaryOK, primaryErr = palette:ActivateRow(interactionRow)
assertEq(primaryOK, false, "scripted primary secure action")
assertEq(primaryErr, "ACTION_REQUIRES_HARDWARE_CLICK", "scripted primary secure error")
local invalidDragOK, invalidDragErr = palette:BeginRowDrag(interactionRow)
assertEq(invalidDragOK, false, "invalid drag payload")
assertEq(invalidDragErr, "DRAG_UNSUPPORTED", "invalid drag error")
palette:Hide("interaction-smoke")

-- A stale row must not invoke an unregistered extension action.
local called=false
local handle=assert(Fixture:Register({id="interaction.stale",title="Stale",version="1",apiVersion="1.0.0",
    catalog={{id="stale-command",title="Stale",actions={"open"}}},
    actions={open={title="Open",run=function() called=true;return {ok=true} end}}}))
local _,staleItems=I.Search.Query:Query("Stale",{})
local staleItem
for _,item in ipairs(staleItems) do if item.providerID=="interaction.stale" then staleItem=item end end
assert(staleItem and handle:Unregister())
assert(palette:Show())
local staleRow=makeInteractionRow(staleItem,"interaction.stale",palette.session,palette.generation)
local staleOK,staleErr=palette:ActivateRowAction(staleRow,"open")
assert(not staleOK and not called and staleErr=="EXTENSION_DISABLED","unregistered old result cannot execute")

-- Launcher regressions: effective visibility, direct recent clicks, bounded
-- scrolling and secure combat cleanup, using the real host and broker.
palette:Hide("launcher-fixture")
local launcherRecords = {}
for index = 1, 12 do
    launcherRecords[index] = { id = "launcher:" .. index, kind = "spell", title = "入口测试 " .. index,
        actions = { { id = "cast", kind = "secure-spell", spellID = 31884 } },
        drag = { type = "spell", spellID = 31884 } }
end
local launcherHandle=assert(Fixture:Register({id="interaction.launcher",apiVersion="1.0.0",title="Launcher",version="1",catalog=launcherRecords}))
local function effectiveVisibility(self)
    local current = self
    while current do
        if current.IsShown and not current:IsShown() then return false end
        current = current.parent
    end
    return true
end
for _, rows in ipairs({ palette.list.rows, palette.homeView.tiles }) do
    for index = 1, #rows do rows[index].IsVisible = effectiveVisibility end
end
local function typeQuery(text)
    palette.input.frame:SetText(text)
    palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
end
local function boundButton(row)
    for index = 1, #secureBroker.buttons do
        local button = secureBroker.buttons[index]
        if button.busy and button.token and button.token.row == row then return button end
    end
end
assert(palette:Show())
assert(not palette.list.frame:IsShown(), "search list starts with a hidden ancestor")
typeQuery("入口测试")
local launcherRow = palette.list.rows[1]
local launcherButton = assert(boundButton(launcherRow), "first search prepares a secure button before list visibility changes")
assertEq(launcherButton:GetAttribute("useOnKeyDown"), false, "mouse-up action overrides key-down CVar")
assertEq(launcherButton:GetParent(), launcherRow, "secure target inherits row visibility")
assert(launcherRow:IsVisible(), "accepted results are effectively visible")
assert(not launcherRow.dragger:IsShown(), "secure layer owns drag without a click-blocking icon overlay")
local warmFrames = env.state.createdFrames
palette.list:Select(8)
assert(palette.list:Move(1))
assertEq(palette.list.offset, 1, "keyboard reaches results beyond eight visible rows")
assertEq(palette.list.rows[8].item, palette.list.items[9], "scrolled row binds the ninth result")
assertEq(boundButton(palette.list.rows[8]).token.item, palette.list.items[9], "secure click rebinds after scrolling")
palette:InvalidateRow(palette.list.rows[2])
assert(palette.list:Scroll(1), "scrolling tolerates an invalidated false slot")
assertEq(env.state.createdFrames, warmFrames, "scrolling reuses all UI and secure buttons")
typeQuery("入口测试")
launcherRow = palette.list.rows[1]
launcherButton = assert(boundButton(launcherRow))
local clickedID = launcherButton.token.item.id
launcherButton.scripts.OnMouseDown(launcherButton, "LeftButton")
launcherButton.scripts.PreClick(launcherButton)
assert(launcherButton.pendingCast, "physical pre-click arms cast observation")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_FAILED", 31884))
assert(palette.visible and launcherButton.busy and launcherButton:IsShown(), "failed cast remains retryable")
launcherButton.scripts.OnMouseDown(launcherButton, "LeftButton")
launcherButton.scripts.PreClick(launcherButton)
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED", 31884))
assert(not palette.visible and not palette.frame:IsShown(), "successful spell closes launcher")
assertEq(LycheeCharacterDB.palette.recent[1].entryID, clickedID, "successful spell records stable recent ID")
assert(palette:Show())
assertEq(palette.input:GetText(), "", "reopening clears previous query")
assert(palette:IsHomeVisible(), "reopening returns to recent homepage")
assert(palette.frame:GetHeight() < 260, "one-row home contracts around content")
local recentTile = palette.homeView.tiles[1]
local recentButton = assert(boundButton(recentTile), "recent tile has a prepared direct spell click")
assert(recentTile.bg:GetWidth() < recentTile.bg:GetHeight(), "recent list selection uses a side accent")
assertEq(recentTile:GetWidth(), 592, "recent entry is a full-width list row")
local resultRow=palette.list.rows[1]
assertEq(resultRow:GetWidth(),recentTile:GetWidth(),"search uses recent list width")
assertEq(resultRow:GetHeight(),recentTile:GetHeight(),"search uses recent row height")
assertEq(resultRow.icon:GetWidth(),recentTile.icon:GetWidth(),"search uses recent icon size")
assertEq(resultRow.accent:GetWidth(),recentTile.bg:GetWidth(),"selection marker widths match")
assertEq(resultRow.accent:GetHeight(),recentTile.bg:GetHeight(),"selection marker heights match")
assertEq(recentTile.selectionFill._lycheeColorToken,Lychee.UI.Theme.Colors.surfaceSelected,"recent uses same selected fill as search")
assertEq(recentTile.title.wordWrap, false, "recent entry names use one line")
assertEq(recentButton.token.item.id, clickedID, "recent button points to the saved record")
local beforeDrag = _G.__pickup or 0
recentButton.scripts.OnMouseDown(recentButton,"LeftButton")
recentButton.scripts.OnDragStart(recentButton)
assertEq(_G.__pickup, beforeDrag + 1, "recent spell keeps action-bar drag support")

local pendingTimer
C_Timer = { NewTimer = function(_, callback)
    pendingTimer = { callback = callback }
    function pendingTimer:Cancel() self.cancelled = true end
    return pendingTimer
end }
typeQuery("入口测试")
_G.__combat = true
palette.frame.scripts.OnEvent(palette.frame, "PLAYER_REGEN_DISABLED")
assert(pendingTimer.cancelled and not I.Search.Session.visible, "combat cancels asynchronous search")
_G.__secureSnippet = true
palette.frame:Hide()
_G.__secureSnippet = false
palette.frame.scripts.OnHide(palette.frame)
assert(not palette.visible and palette.combatCleanupPending, "combat queues protected cleanup")
assertEq(palette:Show(), false, "Show cannot bypass combat guard")
assertEq(palette:Toggle(), false, "Toggle cannot bypass combat guard")
assertEq(palette:ApplyResults({}, palette.generation, palette.session), false, "late results cannot repaint combat UI")
pendingTimer.callback()
assert(not palette.frame:IsShown(), "late timer does not reopen hidden launcher")
_G.__combat = false
secureBroker:Flush()
palette.frame.scripts.OnEvent(palette.frame, "PLAYER_REGEN_ENABLED")
assert(not palette.frame:IsShown() and not palette.combatCleanupPending, "regen cleans up without reopening")
for index = 1, #secureBroker.buttons do
    local button = secureBroker.buttons[index]
    assert(not button.busy and button.token == nil and button:GetAttribute("type") == nil, "regen removes every active secure binding")
end
C_Timer = nil
assert(launcherHandle:SetAvailability(false))
assertEq(#I.Search.Query:ResolveRecent({ { providerID = "interaction.launcher", entryID = clickedID, sourceID = "interaction.launcher:records" } }, 5), 0, "disabled source is absent from recent launcher")
assert(launcherHandle:Unregister())

-- A mixed source owns actions and drag independently of presentation kind.
local mixedMounts,mixedRuns=0,0
local mixedHandle=assert(Fixture:Register({id="interaction.mixed",title="Mixed",version="1",apiVersion="1.0.0",
    catalog={
    { id = "mixed:cast", kind = "spell", title = "混合入口施放", actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 31884 },
    } },
    { id = "mixed:panel", kind = "spell", kindTitle = "技能", title = "混合入口面板", primaryActionID = "open", actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 31884 },
        { id = "open", title = "打开面板", kind = "open-panel", panel = "detail", state = { itemID = 42 } },
    }, drag = { type = "spell", spellID = 31884 } },
    { id = "mixed:command", kind = "command", title = "混合入口命令", actions = {
        "run",
    } },
},
    actions={run={title="运行命令",run=function() mixedRuns=mixedRuns+1;return {ok=true} end}},
    views={detail={stateSchema={itemID="integer"},create=function(_,state)
        assertEq(state.itemID,42,"provider panel state")
        return {Mount=function() mixedMounts=mixedMounts+1;return true end,Unmount=function() end,Dispose=function() end}
    end}}}))
assert(palette:Show())
typeQuery("混合入口")
local function findEntry(rows, id)
    for index = 1, #rows do if rows[index].item and rows[index].item.id == id then return rows[index] end end
    error("missing mixed entry: " .. id)
end
local castRow = findEntry(palette.list.rows, "mixed:cast")
local panelRow = findEntry(palette.list.rows, "mixed:panel")
local commandRow = findEntry(palette.list.rows, "mixed:command")
local noDragButton = assert(boundButton(castRow))
assertEq(#noDragButton.dragButtons, 0, "pooled secure button clears drag when provider omits it")
local mixedPickups = _G.__pickup or 0
local dragOK, dragErr = palette:BeginRowDrag(castRow)
assert(not dragOK and dragErr == "DRAG_UNSUPPORTED", "spell category does not imply drag")
assertEq(_G.__pickup or 0, mixedPickups, "undeclared drag has no side effect")
assert(not boundButton(panelRow), "spell category does not override the provider's primary panel action")
assertEq(panelRow.dragger.dragButtons[1], "LeftButton", "ordinary result binds declared drag")
panelRow.dragger.scripts.OnMouseDown(panelRow.dragger,"LeftButton")
panelRow.dragger.scripts.OnDragStart(panelRow.dragger)
assertEq(_G.__pickup, mixedPickups + 1, "ordinary result executes declared drag")
palette.list:ShowTooltip(panelRow)
local panelTooltip = tooltipText()
assert(panelTooltip:find("打开面板", 1, true) and panelTooltip:find("拖动", 1, true), "tooltip describes provider primary and drag")
local mixedItems = { castRow.item, panelRow.item, commandRow.item }
LycheeCharacterDB.palette.recent = {}
for index = 1, #mixedItems do palette:TouchRecent(mixedItems[index]) end
typeQuery("")
assertEq(#palette.homeView.sections, 3, "recent mixes spells, panels and commands")
local panelTile = findEntry(palette.homeView.tiles, "mixed:panel")
local castTile = findEntry(palette.homeView.tiles, "mixed:cast")
assert(not boundButton(panelTile), "recent keeps the panel primary action")
assertEq(panelTile.dragButtons[1], "LeftButton", "recent panel binds provider drag")
assertEq(#castTile.dragButtons, 0, "recent does not infer drag from spell kind")
assertEq(#assert(boundButton(castTile)).dragButtons, 0, "recent secure overlay also has no undeclared drag")
assert(panelTile.fallback[1]:IsShown() and not panelTile.icon:IsShown(), "iconless entries have a neutral fallback")
palette.homeView:ShowTooltip(panelTile)
assertEq(tooltipText(), panelTooltip, "home and results share action tooltip")
palette.homeView.frame.scripts.OnHide(palette.homeView.frame)
assert(not Lychee.UI.Components.tooltip:IsShown() and Lychee.UI.Components.tooltip._owner == nil, "hiding recent view clears its root-owned tooltip")
palette.homeView:ShowTooltip(panelTile)
panelTile.scripts.OnMouseDown(panelTile,"LeftButton")
panelTile.scripts.OnDragStart(panelTile)
assertEq(_G.__pickup, mixedPickups + 2, "recent panel executes the same declared drag")
palette.homeView.tiles[2].scripts.OnEnter(palette.homeView.tiles[2])
local highlighted = 0
for index = 1, #palette.homeView.tiles do if palette.homeView.tiles[index].bg:IsShown() then highlighted = highlighted + 1 end end
assertEq(highlighted, 1, "recent has one highlighted icon")
palette.homeView:Move(-1)
assert(palette.homeView.tiles[1].bg:IsShown() and not palette.homeView.tiles[2].bg:IsShown(), "keyboard moves the shared recent selection")
panelTile.scripts.OnMouseDown(panelTile, "LeftButton")
panelTile.scripts.OnClick(panelTile)
assertEq(mixedMounts, 1, "recent click opens the provider panel")
palette:CloseView("mixed-panel")
local commandTile = findEntry(palette.homeView.tiles, "mixed:command")
commandTile.scripts.OnMouseDown(commandTile, "LeftButton")
commandTile.scripts.OnClick(commandTile)
assertEq(mixedRuns, 1, "recent click runs the provider command")
assertEq(LycheeCharacterDB.palette.recent[1].entryID, "mixed:command", "successful ordinary action updates recency")
assert(mixedHandle:Unregister())
-- The distributable API 1.0.0 fixture must work through real Host rendering/view code.
dofile("lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua")
local fixtureProvider = assert(ThirdPartyFixture.GetProvider())
assert(palette:Show())
typeQuery("第三方示例条目")
local fixtureRow = findEntry(palette.list.rows, "fixture-item-12345")
assertEq(fixtureRow.primaryAction.kind, "provider", "ordinary Provider action reaches the shared renderer")
assertEq(fixtureRow.dragger.dragButtons[1], "LeftButton", "custom Provider drag is registered")
fixtureRow.primaryTarget.scripts.OnMouseDown(fixtureRow.primaryTarget, "LeftButton")
fixtureRow.primaryTarget.scripts.OnClick(fixtureRow.primaryTarget, "LeftButton")
local fixturePanel = assert(ThirdPartyFixture.GetPanel())
assertEq(fixturePanel.text:GetText(), "物品 12345", "view Mount receives and renders initial state")
assert(palette.viewHost:Update({ itemID=9 }))
assertEq(fixturePanel.text:GetText(), "物品 9", "view Update receives state directly")
palette:Hide("fixture-close")
assert(not fixturePanel.frame:IsShown() and not palette.viewHost:IsActive(), "view teardown stops display")
assert(not fixturePanel.context and not fixturePanel.active,"SDK sample releases its binding")
do
    local alternate=CreateFrame("Frame",nil,UIParent)
    local originalFrame,originalText=fixturePanel.frame,fixturePanel.text
    local factory=I.Providers.entries["third-party-fixture"].definition.views.detail
    assert(palette.viewHost:Mount(factory,{contentFrame=alternate,extensionID="third-party-fixture"},{itemID=77}))
    assert(fixturePanel.frame==originalFrame and fixturePanel.text==originalText and fixturePanel.parent==alternate,
        "SDK sample reuses controls while changing parent")
    assertEq(fixturePanel.text:GetText(),"物品 77","reused sample binds new business state")
    palette.viewHost:Unmount("sample-reparent")
    assert(not fixturePanel.context and not fixturePanel.active)
    local setAllPoints=fixturePanel.frame.SetAllPoints
    fixturePanel.frame.SetAllPoints=function() error("layout failed after parent changed") end
    assert(not palette.viewHost:Mount(factory,{contentFrame=palette.viewHost:GetFrame()},{itemID=88}))
    assert(not fixturePanel.parent and not fixturePanel.context and not fixturePanel.active,
        "partial layout failure invalidates cached binding")
    fixturePanel.frame.SetAllPoints=setAllPoints
    assert(palette.viewHost:Mount(factory,{contentFrame=alternate},{itemID=99}))
    assert(fixturePanel.frame==originalFrame and fixturePanel.frame:GetParent()==alternate
        and fixturePanel.parent==alternate,"retry rebinds correctly without recreating controls")
    assertEq(fixturePanel.text:GetText(),"物品 99","retry uses the new state")
    palette.viewHost:Unmount("sample-retry")
end
assert(palette:Show())
local fixtureTile = findEntry(palette.homeView.tiles, "fixture-item-12345")
local menuEntries = {}
function GetCursorPosition() return 200,300 end
function UIParent:GetHeight() return self.height end
local showOwnedMenu=Lychee.UI.Components.ShowActionMenu
function Lychee.UI.Components:ShowActionMenu(owner,generator)
    local result=showOwnedMenu(self,owner,generator)
    menuEntries={}
    for index=1,result.count do
        local button=result.buttons[index]
        menuEntries[index]={title=button.label:GetText(),callback=button.callback}
    end
    return result
end
MenuUtil={CreateContextMenu=function() error("owned menus must bypass global native skins") end}
fixtureTile.scripts.OnMouseDown(fixtureTile, "RightButton")
fixtureTile.scripts.OnClick(fixtureTile, "RightButton")
assertEq(#menuEntries, 4, "recent Provider entry exposes all actions, alias and pin")
assert(palette.actionMenu==Lychee.UI.Components.actionMenu, "recent actions use the owned shared menu")
local originalMouseOver = palette.frame.IsMouseOver
palette.frame.IsMouseOver = function() return false end
palette.actionMenu = { IsShown=function() return true end, IsMouseOver=function() return true end }
palette.input:Focus()
palette.input.frame:SetFocus()
palette.input.focused = true -- The frame adapter does not dispatch OnEditFocusGained.
palette.frame.scripts.OnEvent(palette.frame,"GLOBAL_MOUSE_DOWN")
assert(palette.input.frame.focused, "clicking an owned menu preserves search focus")
palette.actionMenu = nil
palette.frame.scripts.OnEvent(palette.frame,"GLOBAL_MOUSE_DOWN")
assert(not palette.input.frame.focused, "outside click still releases keyboard focus")
palette.frame.IsMouseOver = originalMouseOver
palette.input:Focus()
assert(menuEntries[1].callback())
assertEq(fixturePanel.text:GetText(), "物品 12345", "recent restores current state before opening the view")
palette:Hide("fixture-done")
assert(ThirdPartyFixture.Unregister())

local menuRan = 0
local secureMenuProvider = assert(Fixture:Register({id="ui.sdk-menu",apiVersion="1.0.0",version="1.0.0",title="Menu",
    catalog={{id="secure-menu",title="安全菜单入口",actions={{id="cast",title="施放",kind="secure-spell",spellID=31884},"info",
        {id="secondary-cast",title="次要施放",kind="secure-spell",spellID=31884}}}},
    actions={info={title="查看",run=function() menuRan=menuRan+1; return {ok=true} end}},
}))
assert(palette:Show())
typeQuery("安全菜单入口")
local secureMenuRow = findEntry(palette.list.rows, "secure-menu")
local secureMenuButton = assert(boundButton(secureMenuRow))
menuEntries={}
secureMenuButton.scripts.OnMouseDown(secureMenuButton, "RightButton")
assertEq(#menuEntries, 5, "secure overlay exposes the same actions, alias and pin")
assert(not secureMenuButton.pendingCast, "right-button menu does not initiate a protected cast")
assert(menuEntries[2].callback() and menuRan==1)
LycheeCharacterDB.palette.recent={}
local preparedSecondary=(function()
    local original, calls = IsPlayerSpell, 0
    IsPlayerSpell = function(id) calls = calls + 1; return original(id) end
    local result = menuEntries[3].callback()
    IsPlayerSpell = original
    print("Secondary secure action spell checks: " .. calls)
    assert(calls == 1, "secondary preparation checks spell availability once")
    return result
end)()
assert(preparedSecondary.awaitingHardwareClick and #LycheeCharacterDB.palette.recent==0, "arming a secure action is not successful execution")
assert(secureMenuButton:GetParent()==secureMenuRow and secureMenuButton.armedSecondary, "secondary secure action covers the correct row")
assert(palette.status:GetText():find("次要施放",1,true), "status names the prepared action")
secureMenuButton.scripts.OnEnter(secureMenuButton)
assert(Lychee.UI.Components.tooltip.labels[1]:GetText():find("次要施放",1,true), "armed tooltip describes the actual next action")
secureMenuButton.scripts.OnMouseDown(secureMenuButton, "LeftButton")
secureMenuButton.scripts.PreClick(secureMenuButton)
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED",31884))
assertEq(LycheeCharacterDB.palette.recent[1].entryID,"secure-menu","successful cast records recency")
assertEq(#secureBroker.active,0,"released secure buttons leave no active references")
palette:Hide("menu-done")
assert(secureMenuProvider:Unregister())
MenuUtil=nil
-- Collection Provider reaches the real secure row and recent-item drag paths.
local mountCollected=true
local mountPicked
local mountSummoned
C_MountJournal={
    SummonByID=function(id) mountSummoned=id end,
    GetMountIDs=function() return {77} end,
    GetMountInfoByID=function(id)
        assert(id==77)
        return "测试星光龙",90077,123456,false,true,1,false,false,nil,false,mountCollected,77
    end,
    GetMountFromSpell=function(spellID) if spellID==90077 then return 77 end end,
}
C_Spell=C_Spell or {}
local oldPickup=C_Spell.PickupSpell
C_Spell.PickupSpell=function(id) mountPicked=id end
TestPackages.Modules=TestPackages.Modules or {}
TestPackages:File(root.."../Lychee_Player/Mounts/Provider.lua")
assert(TestPackages.Modules.Mounts:Init())
assert(palette:Show())
typeQuery("测试星光龙")
local mountRow=findEntry(palette.list.rows,"mount:77")
local mountButton=assert(boundButton(mountRow), "mount outside player spellbook receives secure button")
assertEq(mountButton:GetAttribute("type"),nil,"collection summon does not cast a spellbook spell")
assertEq(mountButton:GetAttribute("spell"),90077)
assertEq(mountButton.dragButtons[1],"LeftButton")
mountButton.scripts.OnMouseDown(mountButton,"LeftButton")
mountButton.scripts.OnDragStart(mountButton)
assertEq(mountPicked,90077,"mount row drags the summoning spell")
mountButton.scripts.OnMouseDown(mountButton, "LeftButton")
mountButton.scripts.PreClick(mountButton)
assert(mountButton.scripts.PostClick, "mount click has a collection summon handler")
mountButton.scripts.PostClick(mountButton, "LeftButton")
assertEq(mountSummoned,77,"mount click invokes the native collection summon API")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_FAILED",90077) and palette.visible, "failed summon keeps search open")
;(function()
    local summon, recentCount = C_MountJournal.SummonByID, #LycheeCharacterDB.palette.recent
    C_MountJournal.SummonByID = function() error("summon rejected") end
    mountButton.scripts.OnMouseDown(mountButton, "LeftButton")
    mountButton.scripts.PreClick(mountButton)
    mountButton.scripts.PostClick(mountButton, "LeftButton")
    assert(not mountButton.pendingCast and palette.visible, "summon API failure clears pending state without closing")
    assert(#LycheeCharacterDB.palette.recent == recentCount, "rejected summon is not recorded as success")
    C_MountJournal.SummonByID = summon
end)()
mountButton.scripts.OnMouseDown(mountButton, "LeftButton")
mountButton.scripts.PreClick(mountButton)
mountButton.scripts.PostClick(mountButton, "LeftButton")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED",90077))
assert(not palette.visible and LycheeCharacterDB.palette.recent[1].entryID=="mount:77")
assert(palette:Show())
local mountTile=findEntry(palette.homeView.tiles,"mount:77")
mountPicked=nil
assert(boundButton(mountTile)).scripts.OnMouseDown(boundButton(mountTile),"LeftButton")
assert(boundButton(mountTile)).scripts.OnDragStart(boundButton(mountTile))
assertEq(mountPicked,90077,"recent mount supports the same action-bar drag")
mountCollected=false
mountPicked=nil
local mountDragOK,mountDragErr=palette:BeginRowDrag(mountTile)
assert(not mountDragOK and mountDragErr=="ACTION_UNAVAILABLE" and mountPicked==nil, "live collection check blocks a removed mount")
palette:Hide("mount-done")
assert(TestPackages.Modules.Mounts.handle:Unregister())
C_Spell.PickupSpell=oldPickup
C_MountJournal=nil
-- Regression from 20260912-105826.mp4: the search background must not
-- become a darker rectangle when the root fades. Inspect the real surface
-- emitted by Input/Theme, then compose its alpha over the window background.
;(function()
    local surface=palette.input.container._lycheeSurface
    local color=surface and surface.background._lycheeColorToken
    local localAlpha=color and color[4] or 0
    for _,windowAlpha in ipairs({0.25,0.5,0.75,1}) do
        local combined=windowAlpha+localAlpha*windowAlpha*(1-windowAlpha)
        assert(math.abs(combined-windowAlpha)<0.000001,
            "search background stacks opacity during fade: "..combined.." vs "..windowAlpha)
    end
    assert(not palette.input.frame._lycheeSurface,"search EditBox must not add another field backdrop")
end)()
-- Retail CloseSpecialWindows dispatch after the EditBox no longer owns Escape.
;(function()
_G.__combat = false
assert(palette:Show())
palette.input:ClearFocus()
local closedByEscape = false
for _, name in pairs(UISpecialFrames) do
    local frame = _G[name]
    if frame and frame:IsShown() then
        frame:Hide()
        if frame.scripts.OnHide then frame.scripts.OnHide(frame) end
        closedByEscape = true
    end
end
assert(closedByEscape and not palette.frame:IsShown() and not palette.visible, "Escape closes palette after EditBox loses focus")
assert(not palette.frame.events.GLOBAL_MOUSE_DOWN, "Escape closure cleans up outside-click event")
assert(palette:Create() == palette)
local registrations = 0
for _, name in ipairs(UISpecialFrames) do if name == "LycheePaletteEscape" then registrations = registrations + 1 end end
assert(registrations == 1, "Escape registration is not duplicated")
-- Repeat the native dispatcher with animation support: it must hide only the
-- escape receiver, leaving the rendered hierarchy alive until exit completes.
local oldAnimation=palette.frame.CreateAnimationGroup
local oldScale=palette.frame.SetScale
palette.frame.SetScale=function(self,value) mutation(self,"SetScale");self.scale=value end
palette.frame.CreateAnimationGroup=function() error("composite window must move through its parent, never per-region native transforms") end
local motion=Lychee.UI.Motion
local function finishPresence()
    if motion.presence then motion.presenceDriver.scripts.OnUpdate(motion.presenceDriver,1) end
end
local reduced=LycheeCharacterDB.palette.reduceMotion
LycheeCharacterDB.palette.reduceMotion=false
palette:Show();palette.input:ClearFocus()
for tick=1,8 do
    motion.presenceDriver.scripts.OnUpdate(motion.presenceDriver,0.02)
    assert(palette.frame.scale==palette._scale,"presence must keep the whole text and hit-test tree at its final scale")
    assert(palette.header:GetParent()==palette.frame and palette.content:GetParent()==palette.frame and palette.footer:GetParent()==palette.frame,
        "background, input and content must share one motion root without an outer clipping viewport")
    assert(not palette.presenceViewport and not palette.presenceSurface and not palette.presenceContent,
        "presence must not split the window into separately moving or clipped layers")
    assert(math.abs(palette.input.frame:GetEffectiveScale()-1)<0.000001,"search text must keep its effective font scale during opening")
    assert(math.abs(palette.input.placeholder:GetEffectiveScale()-1)<0.000001,"placeholder must share the stable cursor/text scale")
end
finishPresence()
local exitStyle=palette.input._visualState
for _,name in pairs(UISpecialFrames) do
    local receiver=_G[name]
    if receiver and receiver:IsShown() then
        receiver:Hide()
        if receiver.scripts.OnHide then receiver.scripts.OnHide(receiver) end
    end
end
assert(not palette.visible and palette.frame:IsShown() and palette._motionClosing,"unfocused Escape preserves exit animation")
assert(palette.input.visualFrozen and palette.input._visualState==exitStyle,"closing must not flash the input disabled style before the complete window fades")
palette.input.container.scripts.OnLeave()
assert(palette.input._visualState==exitStyle,"hover changes during exit cannot repaint the frozen input")
assert(not palette.input.frame.focused and not palette.input:IsEnabled() and not palette.escapeFrame:IsShown(),"exit releases input and Escape receiver immediately")
for tick=1,8 do
    motion.presenceDriver.scripts.OnUpdate(motion.presenceDriver,0.02)
    assert(math.abs(palette.input.frame:GetEffectiveScale()-1)<0.000001 and math.abs(palette.input.placeholder:GetEffectiveScale()-1)<0.000001,"closing must not rescale the search glyphs or caret")
end
finishPresence()
assert(not palette.frame:IsShown() and not palette._motionClosing,"native Escape eventually hides the rendered window")
assert(not palette.input.visualFrozen,"hidden input releases its visual freeze")
palette:Show();finishPresence();palette.input:Focus()
local focusedStyle=palette.input._visualState
palette.input.frame.scripts.OnEscapePressed()
assert(palette.input.visualFrozen and palette.input._visualState==focusedStyle and not palette.input:IsEnabled(),
    "focused EditBox Escape preserves styling while releasing input")
finishPresence()
palette:Show()
assert(not palette.input.visualFrozen and palette.input:IsEnabled(),"reopening restores live input styling")
_G.__combat=true
RunPaletteCombatSnippet(palette.frame);palette.frame.scripts.OnHide(palette.frame)
assert(not palette.escapeFrame:IsShown(),"combat exit cannot consume a later native Escape")
assert(not palette.visible and not motion.presence and not motion.presenceDriver.scripts.OnUpdate,"secure combat hide cancels entrance without delayed work")
_G.__combat=false
palette:Show();assert(palette.visible and palette.escapeFrame:IsShown(),"reopen restores Escape after combat cleanup")
palette:Hide("animation-test");finishPresence()
palette.frame.CreateAnimationGroup=oldAnimation
palette.frame.SetScale=oldScale
LycheeCharacterDB.palette.reduceMotion=reduced
local calls, originals = 0, {}
for index, button in ipairs(secureBroker.buttons) do
    originals[index] = button.SetAttribute
    button.SetAttribute = function(self, ...) calls = calls + 1; return originals[index](self, ...) end
end
secureBroker:ReleaseAll()
for index, button in ipairs(secureBroker.buttons) do button.SetAttribute = originals[index] end
print("Already released button attribute writes: " .. calls)
assert(calls == 0, "repeated release does not mutate idle pooled buttons")
end)()
print("Lychee interaction smoke PASS (launcher, secure combat, Provider views, menus, recent and scrolling)")

;(function()
    local savedTimers=C_Timer; C_Timer=nil
    local controller=Lychee.UI.Palette
    local prefs=I.UserPreferences
    LycheeCharacterDB.pinned={};LycheeCharacterDB.palette.recent={}
    local source=assert(Fixture:Register({id="settings.fixture",apiVersion="1.0.0",version="1.0.0",title="设置测试来源",
        catalog={{id="a",title="设置固定甲",icon=123,actions={"open"}},{id="b",title="设置固定乙",icon=456,actions={"open"}}},
        actions={open={title="打开",run=function() return {ok=true} end}}}))
    controller:Show()
    local a=assert(prefs:Resolve({providerID=source.id,entryID="a"}))
    local b=assert(prefs:Resolve({providerID=source.id,entryID="b"}))
    assert(controller:SetPinned(a,true) and controller:SetPinned(b,true))
    assert(controller:SetPinned(a,true) and #prefs:GetPins()==2, "pins are idempotent")
    assert(controller:OpenSettings("pins"))
    assert(controller.settingsOpen and not I.Search.Session.visible and not controller.input.container:IsShown())
    assert(not controller:ApplyResults({a},controller.generation,controller.session), "settings suppresses search results")
    local view=controller.settingsView
    assert(view.rows[1].icon.texture==123 and view.rows[2].icon.texture==456, "settings pins use entry icons")
    local moveDown=view.rows[1].down
    moveDown.frame.IsMouseOver=function() return false end
    moveDown.frame.scripts.OnEnter()
    moveDown.frame.scripts.OnMouseDown()
    moveDown.frame.scripts.OnLeave()
    moveDown.frame.scripts.OnMouseUp()
    assert(moveDown._state=="normal", "release outside must not leave reorder button highlighted")
    local moveUp=view.rows[1].up
    moveUp.frame.scripts.OnEnter()
    assert(moveUp._state=="disabled", "disabled reorder button must not enter hover state")
    moveUp.frame.scripts.OnLeave()
    assert(moveUp._state=="disabled", "disabled reorder button must stay disabled after leave")
    moveUp.frame.scripts.OnMouseUp()
    assert(moveUp._state=="disabled", "release must not reactivate disabled reorder button")
    moveUp.frame.scripts.OnClick()
    assert(prefs:GetPins()[1].entryID=="a", "disabled click must not reorder pins")
    local secondUp=view.rows[2].up
    secondUp.frame.IsMouseOver=function() return true end
    secondUp.frame.scripts.OnEnter()
    secondUp.frame.scripts.OnMouseDown()
    secondUp.frame.scripts.OnMouseUp()
    secondUp.frame.scripts.OnClick()
    assert(prefs:GetPins()[1].entryID=="b", "actual reorder click moves the correct pin")
    assert(view.rows[1].icon.texture==456 and view.rows[2].icon.texture==123, "reused rows update icons after reorder")
    assert(secondUp._state=="hover" and view.rows[1].up._state=="disabled", "refresh preserves pointer and boundary states")
    secondUp.frame.scripts.OnHide()
    assert(secondUp._state=="normal", "hidden button discards stale hover")
    secondUp.frame.IsMouseOver=nil
    view.rows[1].remove.frame.scripts.OnClick()
    assert(#prefs:GetPins()==1 and view.undo.frame:IsShown())
    view.undo.frame.scripts.OnClick();assert(prefs:GetPins()[1].entryID=="b" and #prefs:GetPins()==2)
    view:SetTab("providers")
    for _,record in ipairs(view.data) do if record.id==source.id then view.scroll=record.y;view:RenderVisible() end end
    local fixtureRow
    for _,row in ipairs(view.rows) do if row.providerID==source.id then fixtureRow=row end end
    assert(fixtureRow, "settings lists third-party providers")
    assert(fixtureRow.icon.texture=="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga", "provider tab clears old entry icon")
    fixtureRow.toggle.scripts.OnClick()
    assert(not source:GetState().enabled and #prefs:GetPins()==2)
    view:SetTab("pins")
    assert(view.rows[1].icon.texture==456 and view.rows[2].icon.texture==123, "disabled pins retain saved icons")
    assert(controller:CloseSettings(true))
    assert(controller:IsHomeVisible() and I.Search.Session.visible and #controller.homeView.sections==2)
    assert(controller.homeView.tiles[1]:IsShown() and not controller.homeView.tiles[1].item, "disabled pin stays visible")
    assert(I.Registry:SetUserEnabled(source.id,true))
    controller:RefreshHomeSections(true)
    assert(controller.homeView.tiles[1].item and controller.homeView.tiles[1]:GetWidth()==81)
    -- Reusing the same title across layouts must not add an empty line below it.
    local pinTile=controller.homeView.tiles[1]
    local pinTitleHeight=pinTile.title:GetHeight()
    controller.homeView:ConfigureLayout(pinTile,true)
    controller.homeView:SetSections(controller.homeView.sections,true)
    assertEq(pinTile.title:GetHeight(),pinTitleHeight,"same-name pin restores measured title height after recent layout")
    TestPackages:File("addon/Lychee_Player/Runtime/InterfaceActions.lua")
    TestPackages:File("addon/Lychee_Player/GameMenus/Provider.lua")
    assert(TestPackages.Modules.GameMenus:Init())
    typeQuery("荔枝设置")
    local settingRow=findEntry(controller.list.rows,"lychee-settings")
    assert(settingRow and controller:ActivateRow(settingRow) and controller.settingsOpen, "search opens same settings page")
    controller:Hide("settings-test")
    assert(not controller.settingsOpen and not view.frame:IsShown())
    controller:Show();assert(controller:IsHomeVisible() and controller.input.container:IsShown())
    assert(not prefs:CanPin(prefs:Resolve({providerID="lychee.game-menus",entryID="lychee-settings"})))
    controller:Hide("done");assert(source:Unregister());C_Timer=savedTimers
print("Lychee settings and pins interaction PASS")
do
    local controller=LycheeInternal.Host.PaletteController
    controller:OpenSettings("general")
    local view=controller.settingsView
    assert(view.general:IsShown() and not view.scrollFrame:IsShown())
    local general=view.general
    local before=Lychee.UI.Motion:IsReduced()
    view.motion.frame.scripts.OnClick(view.motion.frame)
    assert(Lychee.UI.Motion:IsReduced()~=before,"general setting saves motion preference")
    assert(view.motion.frame._enabled==not Lychee.UI.Motion:IsReduced(),"animation switch matches saved preference")
    assert(view.motion.label:GetText()==(Lychee.UI.Motion:IsReduced() and "关闭" or "开启"))
    view:SetTab("providers")
    assert(not general:IsShown() and view.scrollFrame:IsShown())
    view:SetTab("general")
    assert(view.general==general,"general page reuses controls")
    Lychee.UI.Motion:SetReduced(before)
    print("General settings navigation PASS")
end
do
    local controller=LycheeInternal.Host.PaletteController
    local original=LycheeInternal.ResultActionExecutor.ShowActions
    local row={item={providerID="lychee.bags"}}
    local located=false
    LycheeInternal.ResultActionExecutor.ShowActions=function(_,target)
        assert(target==row);located=true;return true
    end
    assert(controller:ShowRowActions(row) and located,"bag right-click opens actions including locate and alias")
    LycheeInternal.ResultActionExecutor.ShowActions=original
    print("Bag right-click routing PASS")
end
do
    local controller=LycheeInternal.Host.PaletteController
    controller:CloseSettings();controller:Show()
    controller.input:SetText("   ");controller:SetQueryMode("   ")
    assert(controller.homeView.frame:IsShown() and not controller.list.frame:IsShown(),"whitespace uses recent view")
    controller:ApplyResults({},controller.generation,controller.session)
    assert(controller.homeView.frame:IsShown(),"empty reply must not switch whitespace back to search")
    controller:Hide("whitespace-test")
    print("Whitespace home view PASS")
end

do
    local controller=LycheeInternal.Host.PaletteController
    local savedTimers=C_Timer;C_Timer=nil
    controller:Hide("recent-regression-reset")
    local function record(id) return {id=id,title="Recent "..id,kindTitle="Fixture"} end
    local source=assert(Fixture:Register({id="recent.dynamic",apiVersion="1.0.0",version="1.0.0",title="Recent fixture",
        catalog={record("static")},
        query=function(_,reply) reply({record("first"),record("last")}) end,
        resolve=function(id) return record(id) end}))
    LycheeCharacterDB.pinned={}
    LycheeCharacterDB.palette.recent={
        {providerID="recent.dynamic",entryID="first"},
        {providerID="recent.dynamic",entryID="static"},
        {providerID="recent.dynamic",entryID="last"},
    }
    controller.input:SetText("");assert(controller:Show())
    local function assertHome(label)
        local expected=3+#LycheeCharacterDB.pinned
        assert(#controller.homeView.sections==expected,label..": expected all saved entries")
        for i=1,expected do
            local tile=controller.homeView.tiles[i]
            assert(tile:IsShown() and tile.item,label..": missing recent row "..i)
            assert(I.ResultActionExecutor:IsRowCurrent(tile),label..": stale recent row "..i)
        end
    end
    assertHome("initial")
    for _,text in ipairs({"R","Re","R",""}) do
        controller.input.frame:SetText(text)
        controller.input.frame.scripts.OnTextChanged(controller.input.frame,true)
    end
    assertHome("backspace to empty")
    local ref=LycheeCharacterDB.palette.recent[1]
    local first=assert(I.Providers:Resolve(ref))
    local second=assert(I.Providers:Resolve(ref))
    assert(I.Providers:IsCurrent(first) and I.Providers:IsCurrent(second),"resolving one ID must not invalidate another live snapshot")
    LycheeCharacterDB.pinned={ref}
    controller:MarkHomeDirty();assertHome("pin and recent share identity")
    collectgarbage("collect");assertHome("GC keeps visible identities")
    local frames=env.state.createdFrames
    local elapsed,maxCycle=0,0
    collectgarbage("collect");local retainedBefore=collectgarbage("count")
    collectgarbage("stop");local allocatedBefore=collectgarbage("count")
    for cycle=1,100 do
        local started=os.clock()
        for _,text in ipairs({"R","Re","R",""}) do
            controller.input.frame:SetText(text)
            controller.input.frame.scripts.OnTextChanged(controller.input.frame,true)
        end
        local duration=(os.clock()-started)*1000;elapsed=elapsed+duration;maxCycle=math.max(maxCycle,duration)
        assertHome("repeat "..cycle)
    end
    local allocated=collectgarbage("count")-allocatedBefore
    collectgarbage("restart");collectgarbage("collect")
    local growth=collectgarbage("count")-retainedBefore
    assert(env.state.createdFrames==frames,"query/clear reuses existing frames")
    assert(maxCycle<5 and growth<512,string.format("recent lifecycle budget: max %.3f ms, growth %.1f KiB",maxCycle,growth))
    print(string.format("Recent lifecycle: 100 cycles %.3f ms total, %.3f ms max, %.1f KiB allocated, %.1f KiB retained growth, 0 new frames",elapsed,maxCycle,allocated,growth))
    -- Deterministic real scheduler: queue timer callbacks, including cancelled ones.
    local queue={}
    C_Timer={NewTimer=function(_,fn)
        local timer={callback=fn};function timer:Cancel() self.cancelled=true end
        queue[#queue+1]=timer;return timer
    end}
    for _,text in ipairs({"R","Re",""}) do
        controller.input.frame:SetText(text)
        controller.input.frame.scripts.OnTextChanged(controller.input.frame,true)
    end
    for i=1,#queue do queue[i].callback() end
    assertHome("late and cancelled search callbacks")
    C_Timer=nil
    controller:Hide("recent-reopen");controller:Show();assertHome("reopen")
    local tile=controller.homeView.tiles[2]
    controller:InvalidateRow(tile);controller:PrepareHome();assertHome("rebind rejected row")
    local oldItem=controller.homeView.tiles[2].item
    assert(source.catalog:Update({upsert={{id="static",title="Updated static"}}}))
    assertHome("Provider update")
    assert(not I.Providers:IsCurrent(oldItem),"Provider update rejects old resolved snapshot")
    local entry=I.Providers.entries["recent.dynamic"]
    local function resolvedCount() local n=0;for _ in pairs(entry.resolved) do n=n+1 end;return n end
    collectgarbage("collect");local beforeCount=resolvedCount()
    for i=1,200 do I.Providers:Resolve(ref) end
    collectgarbage("collect")
    assert(resolvedCount()==beforeCount,"discarded resolved snapshots are reclaimed")
    oldItem=controller.homeView.tiles[2].item
    assert(source:SetAvailability(false))
    assert(not I.Providers:IsCurrent(oldItem),"disabled Provider rejects old resolved snapshot")
    assert(source:SetAvailability(true));controller:MarkHomeDirty();assertHome("Provider re-enabled")
    controller:Hide("recent-regression-done");source:Unregister();C_Timer=savedTimers
    print("Dynamic recent query lifecycle PASS")
end
dofile(root .. "Search/RuntimeIdentity.lua")
do
    local controller=LycheeInternal.Host.PaletteController
    local P=LycheeInternal.Search.Personalization
    local source=assert(Fixture:Register({id="alias.ui",apiVersion="1.0.0",version="1.0.0",title="Aliases",
        catalog={{id="one",title="别名测试物品"},{id="two",title="第二物品"}}}))
    controller:Show();typeQuery("别名测试物品")
    local row=findEntry(controller.list.rows,"one")
    menuEntries={}
    controller:ShowRowActions(row)
    local aliasAction
    for _,entry in ipairs(menuEntries) do if entry.title=="设置别名" then aliasAction=entry end end
    assert(aliasAction,"search right click offers alias")
    aliasAction.callback()
    local page=controller.settingsView.aliasView
    assert(page and page.editing and page.input.focused,"editor opens and focuses input")
    page.input:SetText("回家神器");page.save.frame.scripts.OnClick()
    assert(not page.editing and not page.input.focused and #page.data==1)
    local settings=controller.settingsView
    assert(not settings.tabs.general.frame:IsShown() and not settings.underline:IsShown(),"alias detail hides parent navigation")
    Lychee.UI.Motion:Cancel(controller.frame,true)
    assert(controller.frame:GetHeight()<Lychee.UI.Theme.Metrics.paletteMaxHeight,"short alias list fits its content")
    page.back.frame.scripts.OnClick()
    Lychee.UI.Motion:Cancel(controller.frame,true)
    assert(settings.tabs.general.frame:IsShown() and settings.tab=="general","back restores general navigation")
    assert(controller.frame:GetHeight()==Lychee.UI.Theme.Metrics.paletteMaxHeight,"back restores settings height")
    settings:OpenAliases();page:Fit(5000);Lychee.UI.Motion:Cancel(controller.frame,true)
    assert(controller.frame:GetHeight()==Lychee.UI.Theme.Metrics.paletteMaxHeight,"long alias lists retain the window height cap")
    page:Render()
    controller:CloseSettings();typeQuery("回家神器")
    assert(findEntry(controller.list.rows,"one"),"saved alias searches original entry")
    controller:OpenSettings("general");controller.settingsView.aliasManage.frame.scripts.OnClick()
    page.scroll:SetHeight(120);page:Render()
    local rectUpdates=page.scroll.rectUpdates
    assert(rectUpdates and rectUpdates>0,"alias viewport updates native scroll bounds")
    page:Render();assert(page.scroll.rectUpdates==rectUpdates,"unchanged alias geometry skips native updates")
    local edit=page.rows[1].edit.frame
    edit.scripts.OnMouseDown();edit.scripts.OnClick()
    assert(page.editing)
    page.input:SetText("不保存");page.cancel.frame.scripts.OnClick()
    assert(P:Find({providerID="alias.ui",entryID="one"}).alias=="回家神器")
    local remove=page.rows[1].remove.frame
    remove.scripts.OnMouseDown()
    P:SetAlias({providerID="alias.ui",entryID="one"},"已更新","别名测试物品");page:ShowList()
    remove.scripts.OnClick();assert(#page.data==1,"stale click cannot delete replacement")
    remove.scripts.OnMouseDown();remove.scripts.OnClick();assert(#page.data==0)
    local before=env.state.createdFrames
    for index=1,20 do controller.settingsView:OpenAliases();page:ShowList() end
    assert(env.state.createdFrames==before,"alias page and row pool reused")
    page:Edit({providerID="alias.ui",entryID="one"},"别名测试物品")
    controller:CloseSettings()
    -- The simple frame adapter does not dispatch inherited OnHide events.
    controller.settingsView.frame.scripts.OnHide()
    page.frame.scripts.OnHide()
    assert(not page.input.focused and not page.editing,"closing releases editor")
    page.input:SetText("过期");page.save.frame.scripts.OnClick()
    assert(P:Find({providerID="alias.ui",entryID="one"})==nil,"hidden save ignored")
    controller:Hide("alias-complete");source:Unregister()
    print("Alias UI PASS: menu, editor, search, settings, cancel, stale delete, reuse, hidden save")
end
do
    local controller=LycheeInternal.Host.PaletteController
    local source=assert(Fixture:Register({id="manage.ui",apiVersion="1.0.0",version="1",title="管理测试",catalog={{id="one",title="管理搜索目标"}}}))
    controller:Show();controller:OpenSettings("providers")
    local view=controller.settingsView
    local row
    for _,candidate in ipairs(view.rows) do if candidate.providerID=="manage.ui" then row=candidate end end
    if row then row.scripts.OnMouseDown();row.scripts.OnClick() else view:OpenProvider("manage.ui",134400) end
    local page=assert(view.providerView)
    local policy=LycheeInternal.Search.ProviderPolicy
    local function edit(input,value) input:SetText(value);input.scripts.OnTextChanged(input,true) end
    assert(page.entry==nil and LycheeInternal.ProviderManagement:IsCurrent(page.id,page.instanceToken),"details use current management identity, not internal entries")
    assert(not view.tabs.providers.frame:IsShown() and page.save==nil and page.cancel==nil,"no second page-level confirmation")
    assert(not page.prefixInput:IsShown() and not page.keywordInput:IsShown() and not page.technical:IsShown())
    assert(page.fields.keyword.edit.frame:IsShown() and not page.fields.keyword.tokens[1].frame:IsShown(),"empty field offers add without placeholder state")
    local function begin(kind) page.fields[kind].edit.frame.scripts.OnClick() end
    local function save(kind,value) begin(kind);edit(page.fields[kind].input,value);page.fields[kind].save.frame.scripts.OnClick() end
    begin("prefix");assert(page.prefixInput:IsShown() and not page.keywordInput:IsShown())
    edit(page.prefixInput,"临时入口");page.fields.prefix.cancel.frame.scripts.OnClick()
    assert(not page.prefixInput:IsShown() and page.editing==nil)
    begin("prefix");assert(page.prefixInput:GetText()=="","cancel does not persist")
    page.prefixInput.scripts.OnEnterPressed();assert(page.editing==nil,"unchanged save also finishes")
    assert(policy:Override("manage.ui")==nil,"unchanged edit does not create an override")
    page.about.frame.scripts.OnClick();assert(page.technical:IsShown())
    page.about.frame.scripts.OnClick();assert(not page.technical:IsShown())
    begin("prefix");edit(page.prefixInput,"草稿")
    page.toggle.scripts.OnClick();assert(page.prefixInput:GetText()=="草稿" and page.editing=="prefix")
    page.toggle.scripts.OnClick();page.back.frame.scripts.OnClick()
    assert(view.tabs.providers.frame:IsShown());view:OpenProvider("manage.ui",134400)
    begin("prefix");assert(page.prefixInput:GetText()~="草稿")
    page.fields.prefix.cancel.frame.scripts.OnClick()
    save("prefix","范围");save("keyword","展示")
    assert(page.fields.keyword.tokens[1].frame:IsShown() and page.fields.keyword.tokens[1].label:GetText()=="展示","saved keyword shows actual configuration")
    local function search(q) local _,items=LycheeInternal.Search.Query:Query(q,{visible=true});return items end
    assert(#search("目标")==1 and #search("范围:目标")==1 and #search("展示")==1,"all routes coexist")
    begin("keyword");edit(page.keywordInput,"展现")
    page.globalToggle.scripts.OnClick()
    assert(page.editing=="keyword" and page.keywordInput:GetText()=="展现","immediate toggle preserves editor")
    page.fields.keyword.save.frame.scripts.OnClick()
    assert(#search("目标")==0 and #search("范围:目标")==1 and #search("展现")==1,"field save preserves committed toggle")
    save("prefix","");save("keyword","")
    assert(not page.fields.prefix.tokens[1].frame:IsShown() and page.fields.prefix.edit.frame:IsShown(),"clearing restores add action")
    assert(page.error:GetText()~="" and page.editing=="keyword" and #search("展现")==1,"invalid edit stays open without changing live search")
    page.keywordInput.scripts.OnEscapePressed();assert(page.editing==nil)
    page.reset.frame.scripts.OnClick();assert(LycheeInternal.ProviderManagement:GetConfiguration(page.id,page.instanceToken),"reset applies immediately")
    page.globalToggle.scripts.OnClick();assert(LycheeInternal.ProviderManagement:GetConfiguration(page.id,page.instanceToken) and page.error:GetText()~="","failed toggle leaves configuration on")
    local fullWords={}
    for index=1,8 do fullWords[index]="managementlongprefix"..index end
    save("prefix",table.concat(fullWords,", "))
    local lastY=0
    for index,chip in ipairs(page.fields.prefix.tokens) do
        assert(chip.frame:IsShown() and chip.label:GetText()==fullWords[index],"all configured words visible")
        assert(chip.x+chip.width<=516 and chip.y>=lastY,"tokens reserve the fixed edit column and wrap")
        lastY=chip.y
    end
    assert(lastY>0,"long word list wraps")
    page.reset.frame.scripts.OnClick()
    local before=env.state.createdFrames
    for index=1,20 do view:OpenProvider("manage.ui",134400);begin("prefix");page.fields.prefix.cancel.frame.scripts.OnClick() end
    assert(before==env.state.createdFrames,"provider detail uses a fixed pool")
    begin("keyword");local saveButton=page.fields.keyword.save.frame
    saveButton.scripts.OnMouseDown();view:OpenProvider("manage.ui",134400);begin("keyword")
    edit(page.keywordInput,"过期");saveButton.scripts.OnClick()
    assert(#search("过期")==0,"rebound save ignored")
    saveButton.scripts.OnMouseDown();page.fields.keyword.cancel.frame.scripts.OnClick();begin("keyword")
    edit(page.keywordInput,"过期");saveButton.scripts.OnClick()
    assert(#search("过期")==0,"reopened editor rejects stale release")
    source:Unregister();saveButton.scripts.OnClick()
    local independent=assert(Fixture:Register({id="manage.independent",apiVersion="1.0.0",version="1",title="独立来源",
        searchGlobal=false,searchKeywords={"independent"},scope={products={"retail"}},i18n={enUS={TITLE="Independent"}},catalog={}}))
    view:OpenProvider("manage.independent",134400)
    assert(page.globalToggle:IsShown(),"all registered providers use the same editable routing controls")
    independent:Unregister();controller:CloseSettings();page.frame.scripts.OnHide()
    assert(not page.prefixInput.focused and not page.keywordInput.focused)
    controller:Hide("management-done")
    print("Provider management UI PASS: detail, mode, prefix, reset, stale click, reuse, release")
end

do
    local input=CreateFrame("EditBox",nil,UIParent)
    local style=Lychee.UI.Components:StyleEditBox(input)
    local edges=input._lycheeSurface.border
    assert(edges[1]:GetHeight()==1 and edges[2]:GetHeight()==1 and edges[3]:GetWidth()==1 and edges[4]:GetWidth()==1,
        "field boundary has visible horizontal and vertical thickness")
    local count=env.state.createdFrames
    assert(Lychee.UI.Components:StyleEditBox(input)==style,"field style is installed once")
    input.scripts.OnEditFocusGained()
    style:SetInvalid(true);input.scripts.OnEditFocusLost()
    assert(style.invalid and not style.focused,"invalid state survives focus loss")
    input.scripts.OnEditFocusGained();style:SetInvalid(false)
    assert(style.focused and not style.invalid,"correction retains focus")
    style:SetInvalid(true);input.scripts.OnHide()
    assert(not style.invalid and not style.focused,"hidden fields release temporary state")
    for index=1,100 do input.scripts.OnEditFocusGained();input.scripts.OnEditFocusLost() end
    assert(env.state.createdFrames==count and not input.scripts.OnUpdate,"field focus has no new frames or driver")
    print("Form field lifecycle PASS: focus, invalid, correction, hide, reuse")
    local p=I.Host.PaletteController
    p:Show();p:Hide("release-test");p:FinishHide("release-test")
    assert(#p.homeView.sections==0,"closed home releases resolved sections")
    for _,tile in ipairs(p.homeView.tiles) do assert(tile.item==nil and tile.section==nil and tile.extensionID==nil,"hidden tile releases business identity") end
    local framesBefore=env.state.createdFrames
    p:Show();p:Hide("release-test");p:FinishHide("release-test")
    assert(env.state.createdFrames==framesBefore,"reopening after release reuses native structures")
    print("Home binding release PASS: no retained section/item identity, native pool reused")
end
end)()
