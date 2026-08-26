-- Offline interaction contract smoke. This harness exercises host-owned UI guards
-- without pretending to validate the real WoW secure-click implementation.
_G = _G or {}
UIParent = { width = 800, height = 600 }
function GetLocale() return "zhCN" end
function InCombatLockdown() return _G.__combat == true end
function geterrorhandler() return function(err) return err end end
function IsPlayerSpell(id) return id == 31884 end
function PickupSpell() _G.__pickup = (_G.__pickup or 0) + 1 end

local function object(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, width = 800, height = 600, scripts = {}, attrs = {} }
    function o:SetAllPoints() end
    function o:SetPoint() end
    function o:ClearAllPoints() end
    function o:SetSize(w, h) self.width, self.height = w, h end
    function o:SetHeight(h) self.height = h end
    function o:SetWidth(w) self.width = w end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:SetFrameStrata() end
    function o:SetFrameLevel() end
    function o:SetBackdrop() end
    function o:EnableMouse() end
    function o:SetAutoFocus() end
    function o:SetTextInsets() end
    function o:RegisterForClicks() end
    function o:RegisterForDrag() end
    function o:SetJustifyH() end
    function o:SetShown(v) self.shown = not not v end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
    function o:UnregisterEvent(name) if self.events then self.events[name] = nil end end
    function o:CreateTexture() return object("Texture", self) end
    function o:CreateFontString() return object("FontString", self) end
    function o:SetTexture(v) self.texture = v end
    function o:SetColorTexture() end
    function o:SetText(v) self.text = v end
    function o:GetText() return self.text or "" end
    function o:ClearFocus() self.focused = false end
    function o:SetFocus() self.focused = true end
    function o:SetAttribute(k, v) self.attrs[k] = v end
    function o:GetAttribute(k) return self.attrs[k] end
    function o:SetParent(parentValue) self.parent = parentValue end
    function o:GetParent() return self.parent end
    function o:SetScrollChild(child) self.scrollChild = child end
    function o:GetScrollChild() return self.scrollChild end
    function o:SetPropagateKeyboardInput() end
    return o
end
function CreateFrame(kind, name, parent) return object(kind, parent or UIParent) end

local root = "package/Lychee/"
local files = {
    "Bootstrap.lua", "Core/ContextStore.lua", "Search/Normalizer.lua", "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua", "Core/IntentRouter.lua",
    "Core/Scheduler.lua", "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "PublicAPI/SDK.lua",
    "Secure/Descriptor.lua", "Secure/Policy.lua", "Secure/SecureActionBroker.lua",
    "UI/FocusController.lua", "UI/Input.lua", "UI/ResultList.lua", "UI/ViewHost.lua", "UI/Palette.lua",
}
for i = 1, #files do dofile(root .. files[i]) end

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
local palette = I.Host.PaletteController
assert(palette)
assert(type(palette.onQuery) == "function", "palette query callback was not wired")
I.Search.Query.generation = 100
palette.generation = 1
palette.session = 1
palette.visible = true
palette.onQuery("stale-generation", 2, palette.session)
assert(palette.generation == I.Search.Query.generation, "palette and query generations diverged")
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
palette.frame.scripts.OnEvent(palette.frame, "PLAYER_REGEN_DISABLED")
assertEq(palette.visible, false, "combat event closes palette")
assertEq(palette.frame:IsShown(), false, "combat event hides palette frame")
_G.__combat = false
assert(palette:Show())
palette:SetQueryMode("")
assertEq(palette.homeView.frame:IsShown(), true, "empty query shows home view")
assertEq(palette.list.frame:IsShown(), false, "empty query hides search view")
palette:SetQueryMode("技能")
assertEq(palette.homeView.frame:IsShown(), false, "non-empty query hides home view")
assertEq(palette.list.frame:IsShown(), true, "non-empty query shows search view")
palette:SetQueryMode("")
I.Registry:SetReady(true)

-- SearchRecord actions stay declarative and route ordinary intents through the host router.
local actionDraft = I.Registry:Begin({ id = "interaction.actions", apiVersion = 1, minApiRevision = 1, title = "Actions", version = "1.0.0" })
assert(actionDraft)
assert(actionDraft:RegisterSearchSource({
    id = "records", version = 1, revision = 1, priority = 50, scope = {},
    records = {
        {
            id = "spell:interaction-action", kind = "spell",
            category = { id = "spells", title = { default = "Spells", zhCN = "技能" } },
            title = "动作技能", aliases = { { text = "动作", locale = "zhCN" } },
            description = { { text = "可执行普通动作。", locale = "zhCN" } },
            actions = {
                { id = "open", title = { zhCN = "打开", enUS = "Open" }, kind = "intent", intent = { type = "interaction.actions.open", version = 1, payload = {} } },
                { id = "panel", title = "面板", kind = "open-panel", panel = "detail", state = { itemID = 7 } },
                { id = "drag", title = "拖拽", kind = "drag-spell", spellID = 31884 },
            },
        },
    },
}))
assert(actionDraft:RegisterSearchSource({
    id = "secondary", version = 1, revision = 1, priority = 40, scope = {}, records = {},
}))
for sourceIndex = 1, 20 do
    assert(actionDraft:RegisterSearchSource({
        id = string.format("overflow-%02d", sourceIndex), version = 1, revision = 1,
        priority = 20, scope = {}, records = {},
    }))
end
local actionCalled = false
assert(actionDraft:RegisterIntentHandler({
    type = "interaction.actions.open", version = 1, schema = {},
    handle = function() actionCalled = true; return { ok = true } end,
}))
local panelMounted = false
assert(actionDraft:RegisterPanelFactory({
    id = "detail", stateSchema = { itemID = "integer" },
    create = function(_, state)
        assert(state.itemID == 7)
        return { Mount = function() panelMounted = true; return true end, Unmount = function() end, Dispose = function() end }
    end,
}))
local actionHandle, actionCommitErr = actionDraft:Commit()
assert(actionHandle, "action extension commit: " .. tostring(actionCommitErr and actionCommitErr.code) .. " " .. tostring(actionCommitErr and actionCommitErr.field))
assert(actionHandle:GetState().effectiveEnabled == true)
local actionGeneration, actionResults = I.Search.Query:Query("动作", { visible = true }, palette.generation)
assert(#actionResults > 0, "search returned action record")
local actionItem = actionResults[1]
assertEq(actionItem.category, "技能", "search result category")
assertEq(actionItem.description, "可执行普通动作。", "localized array description")
assertEq(actionItem.interaction.actions[1].title, "打开", "localized action title")
assert(actionItem.sourceID and actionItem.sourceGeneration and actionItem.sourceRevision, "source state retained on result")
assert(actionItem.evidence and actionItem.evidence.matchedField == "alias", "search result evidence")
assert(actionItem.confidence and actionItem.confidence >= 0.85, "search result confidence")
local categoryGeneration, categoryResults = I.Search.Query:Query("技能 动作", { visible = true })
assert(categoryGeneration and #categoryResults > 0 and categoryResults[1].category == "技能", "category filter result")
palette:SetActivateCallback(function(item, actionID)
    local actions = item and item.searchRecord and item.searchRecord.actions or {}
    for index = 1, #actions do
        if actions[index].id == actionID then return I.Router:Execute(actions[index].intent, {}) end
    end
    return false, "ACTION_UNAVAILABLE"
end)
palette:SetResults(actionResults, actionGeneration, palette.session)
local actionRow = palette.list.rows[1]
assert(actionRow.evidence and actionRow.evidence:GetText():find("命中", 1, true), "evidence slot rendered")
assertEq(actionRow.actions[1].label:GetText(), "打开", "localized action title rendered")
assert(palette:TouchRecent(actionItem))
assert(palette:SetPinned(actionItem, true))
palette:RefreshHomeSections()
assert(LycheeDB and LycheeDB.palette and LycheeDB.palette.recent[1] == actionItem.id, "recent stores stable id")
assert(LycheeDB.palette.pinned[1] == actionItem.id, "pinned stores stable id")
local hasRecent, hasPinned, hasCategory, sourceEntries = false, false, false, 0
for sectionIndex = 1, #(palette.homeView.sections or {}) do
    local section = palette.homeView.sections[sectionIndex]
    if section.id == "saved:" .. actionItem.id then hasRecent = true; hasPinned = true end
    if section.id == "category:spells" then hasCategory = true end
    if section.id == "source:interaction.actions:records" or section.id == "source:interaction.actions:secondary" then sourceEntries = sourceEntries + 1 end
end
assert(hasRecent and hasPinned and hasCategory and sourceEntries == 2, "home sections include saved/category/source entries")
assert(#palette.homeView.sections > 16, "home sections exceed the old fixed tile limit")
assert(#palette.homeView.tiles >= #palette.homeView.sections, "home tile pool grows to the section count")
assertEq(palette.homeView.frame:GetScrollChild(), palette.homeView.content, "home uses a scroll child")
assert(palette.homeView.content:GetHeight() > palette.homeView.frame:GetHeight(), "overflow home content is scrollable")
local renderedSources = {}
for tileIndex = 1, #palette.homeView.sections do
    local tile = palette.homeView.tiles[tileIndex]
    assert(tile and tile:IsShown() and tile.section == palette.homeView.sections[tileIndex], "home tile renders section " .. tileIndex)
    if tile.section.id:sub(1, 7) == "source:" then renderedSources[tile.section.id] = true end
end
for sourceIndex = 1, 20 do
    assert(renderedSources[string.format("source:interaction.actions:overflow-%02d", sourceIndex)], "overflow source remains accessible " .. sourceIndex)
end
local homeSetterCalls, restores = 0, {}
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
    countCalls(tile.meta, "SetText")
    countCalls(tile.icon, "SetTexture")
    countCalls(tile.icon, "SetShown")
    countCalls(tile, "SetShown")
end
palette:RefreshHomeSections()
assertEq(homeSetterCalls, 0, "unchanged home refresh skips native setters")
for restoreIndex = 1, #restores do
    local restore = restores[restoreIndex]
    restore[1][restore[2]] = restore[3]
end
local ordinaryResult, ordinaryErr = palette:ActivateRowAction(actionRow, "open")
assert(ordinaryResult and ordinaryResult.ok == true and actionCalled, "ordinary action execution: " .. tostring(ordinaryErr))
local panelResult, panelErr = palette:ActivateRowAction(actionRow, "panel")
assert(panelResult and panelMounted, "direct panel action: " .. tostring(panelErr))
local pickupBefore = _G.__pickup or 0
local dragResult, dragErr = palette:ActivateRowAction(actionRow, "drag")
assert(dragResult and (_G.__pickup or 0) == pickupBefore + 1, "direct drag action: " .. tostring(dragErr))
_G.__combat = true
local combatAction, combatActionErr = palette:ActivateRowAction(actionRow, "open")
assertEq(combatAction, false, "ordinary combat action")
assertEq(combatActionErr, "COMBAT_LOCKED", "ordinary combat action error")
local routedInCombat, routedCombatErr = I.Router:Execute({ type = "interaction.actions.open", version = 1, payload = {} }, {})
assertEq(routedInCombat, nil, "router combat action")
assert(routedCombatErr and routedCombatErr.code == "COMBAT_LOCKED", "router combat guard")
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
local invalidActionDraft = I.Registry:Begin({ id = "interaction.invalid-action", apiVersion = 1, minApiRevision = 1, title = "Invalid action", version = "1.0.0" })
assert(invalidActionDraft)
local invalidDeclaration, invalidDeclarationErr = invalidActionDraft:RegisterSearchSource({
    id = "records", version = 1, revision = 1, priority = 1, scope = {},
    records = { { id = "bad:record", kind = "spell", title = "Bad", actions = {
        { id = "bad", kind = "secure-spell", spellID = 1, script = function() end },
    } } },
})
assertEq(invalidDeclaration, nil, "invalid action declaration")
assert(invalidDeclarationErr and invalidDeclarationErr.code == "INVALID_SCHEMA", "invalid action schema error")

local missingIntentDraft = I.Registry:Begin({ id = "interaction.missing-intent", apiVersion = 1, minApiRevision = 1, title = "Missing intent", version = "1.0.0" })
assert(missingIntentDraft)
assert(missingIntentDraft:RegisterSearchSource({
    id = "records", version = 1, revision = 1, priority = 1, scope = {},
    records = { { id = "bad:missing-intent", kind = "spell", title = "Bad", actions = {
        { id = "bad", kind = "intent" },
    } } },
}))
local missingIntentHandle, missingIntentErr = missingIntentDraft:Commit()
assertEq(missingIntentHandle, nil, "missing intent commit")
assert(missingIntentErr and missingIntentErr.code == "INVALID_SCHEMA", "missing intent schema error")

local missingSourceDraft = I.Registry:Begin({ id = "interaction.missing-source-fields", apiVersion = 1, minApiRevision = 1, title = "Missing source fields", version = "1.0.0" })
assert(missingSourceDraft)
local missingSource, missingSourceErr = missingSourceDraft:RegisterSearchSource({ id = "records", records = {} })
assertEq(missingSource, nil, "missing source metadata")
assert(missingSourceErr and missingSourceErr.code == "INVALID_SCHEMA", "missing source metadata error")

-- Disabled extensions and stale generations invalidate result actions before execution.
assert(actionHandle:SetEnabled(false))
local disabledRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation)
local disabledCurrent, disabledErr = palette:IsRowCurrent(disabledRow)
assertEq(disabledCurrent, false, "disabled extension row")
assertEq(disabledErr, "EXTENSION_DISABLED", "disabled extension error")
assert(actionHandle:SetEnabled(true))
local staleRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation - 1)
local staleCurrent, staleGenerationErr = palette:IsRowCurrent(staleRow)
assertEq(staleCurrent, false, "stale generation row")
assertEq(staleGenerationErr, "STALE_GENERATION", "stale generation error")
local actionSource = assert(actionHandle:GetSearchSource("records"))
assert(actionSource:Upsert({ id = "spell:new-generation", kind = "spell", title = "新代记录" }))
local sourceStaleRow = makeInteractionRow(actionItem, "interaction.actions", palette.session, palette.generation)
local sourceCurrent, sourceCurrentErr = palette:IsRowCurrent(sourceStaleRow)
assertEq(sourceCurrent, false, "stale source row")
assertEq(sourceCurrentErr, "STALE_GENERATION", "stale source row error")
assert(actionHandle:Unregister())

local interactionItem = { interaction = {
    primaryActionID = "cast",
    actions = { { id = "cast", kind = "secure-spell", spellID = 31884 } },
    drag = { type = "not-spell", spellID = 31884 },
} }
assert(palette:Show())
palette:SetResults({ interactionItem }, palette.generation, palette.session)
local interactionRow = palette.list.rows[1]
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
local invalidDragOK, invalidDragErr = palette:BeginRowDrag(interactionRow)
assertEq(invalidDragOK, false, "invalid drag payload")
assertEq(invalidDragErr, "DRAG_UNSUPPORTED", "invalid drag error")
palette:Hide("interaction-smoke")

-- A stale row must not invoke an unregistered extension action.
palette:SetActivateCallback(function(item, actionID)
    local commandValue = item and item.command
    if not commandValue or type(commandValue.itemIntent) ~= "function" then return false, "ACTION_UNAVAILABLE" end
    local intent = commandValue.itemIntent(item, actionID, {})
    local result, err = I.Router:Execute(intent, {})
    if not result then return false, err and err.code or "HANDLER_UNAVAILABLE" end
    return result
end)
local draft = I.Registry:Begin({ id = "interaction.stale", apiVersion = 1, minApiRevision = 1, title = "Stale", version = "1.0.0" })
assert(draft)
local called = false
assert(draft:RegisterCommand({
    id = "stale-command", title = "Stale", presentation = "row", intent = "interaction.stale.open",
    itemIntent = function() called = true; return { type = "interaction.stale.open", version = 1, payload = {} } end,
}))
assert(draft:RegisterIntentHandler({ type = "interaction.stale.open", version = 1, schema = {}, handle = function() return { ok = true } end }))
local handle = draft:Commit()
assert(handle)
local command = I.Catalog.commands["interaction.stale:stale-command"]
assert(handle:Unregister())
assert(palette:Show())
local staleRow = makeInteractionRow({ command = command, interaction = { primaryActionID = "default" } }, "interaction.stale", palette.session, palette.generation)
local staleOK, staleErr = palette:ActivateRowAction(staleRow, "default")
assertEq(staleOK, false, "unregistered stale action")
assert(staleErr == "HANDLER_UNAVAILABLE" or staleErr == "EXTENSION_DISABLED", "unregistered stale action error: " .. tostring(staleErr))

print("Lychee interaction smoke PASS")
