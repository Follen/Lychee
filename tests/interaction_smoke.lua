-- Offline interaction contract smoke. This harness exercises host-owned UI guards
-- without pretending to validate the real WoW secure-click implementation.
_G = _G or {}
UIParent = { width = 800, height = 600 }
function GetLocale() return "zhCN" end
function InCombatLockdown() return _G.__combat == true end
function geterrorhandler() return function(err) return err end end
function IsPlayerSpell(id) return id == 31884 end
function PickupSpell() _G.__pickup = (_G.__pickup or 0) + 1 end

local createdFrames = 0
local homeGeometryCalls = { ClearAllPoints = 0, SetPoint = 0, SetVerticalScroll = 0 }
local function protect(o)
    while o and o ~= UIParent do o.protected = true; o = o.parent end
end
local function mutation(o, name)
    assert(not (o.protected and InCombatLockdown() and not _G.__secureSnippet), "insecure combat mutation: " .. name)
end
local function object(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, width = 800, height = 600, scripts = {}, attrs = {} }
    function o:SetAllPoints() mutation(self, "SetAllPoints") end
    function o:SetPoint(...) mutation(self, "SetPoint"); self.point = { ... }; homeGeometryCalls.SetPoint = homeGeometryCalls.SetPoint + 1 end
    function o:ClearAllPoints() mutation(self, "ClearAllPoints"); homeGeometryCalls.ClearAllPoints = homeGeometryCalls.ClearAllPoints + 1 end
    function o:SetSize(w, h) mutation(self, "SetSize"); self.width, self.height = w, h end
    function o:SetHeight(h) mutation(self, "SetHeight"); self.height = h end
    function o:SetWidth(w) mutation(self, "SetWidth"); self.width = w end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:SetAlpha(value) mutation(self,"SetAlpha");self.alpha=value end
    function o:GetAlpha() return self.alpha or 1 end
    function o:GetStringHeight() return 15 end
    function o:SetClampedToScreen(enabled) self.clamped = enabled end
    function o:SetFrameStrata() end
    function o:SetFrameLevel(value) mutation(self, "SetFrameLevel"); self.frameLevel = value end
    function o:GetFrameLevel() return self.frameLevel or 0 end
    function o:SetBackdrop() end
    function o:EnableMouse() end
    function o:SetAutoFocus() end
    function o:SetTextInsets() end
    function o:RegisterForClicks() end
    function o:RegisterForDrag(...) mutation(self, "RegisterForDrag"); self.dragButtons = { ... } end
    function o:SetWordWrap(value) self.wordWrap = value end
    function o:SetMaxLines(value) self.maxLines = value end
    function o:SetJustifyH() end
    function o:SetShown(v) mutation(self, "SetShown"); self.shown = not not v end
    function o:Show() mutation(self, "Show"); self.shown = true end
    function o:Hide() mutation(self, "Hide"); self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
    function o:UnregisterEvent(name) if self.events then self.events[name] = nil end end
    function o:UnregisterAllEvents() self.events = {} end
    function o:CreateTexture() return object("Texture", self) end
    function o:CreateFontString() return object("FontString", self) end
    function o:SetTexture(v) self.texture = v end
    function o:SetRotation(radians) self.rotation = radians end
    function o:SetColorTexture() end
    function o:SetTextColor(...) self.textColor = { ... } end
    function o:SetText(v) self.text = v end
    function o:GetText() return self.text or "" end
    function o:ClearFocus() self.focused = false end
    function o:SetFocus() self.focused = true end
    function o:SetAttribute(k, v) mutation(self, "SetAttribute"); self.attrs[k] = v end
    function o:GetAttribute(k) return self.attrs[k] end
    function o:SetParent(parentValue) mutation(self, "SetParent"); self.parent = parentValue; if self.protected then protect(parentValue) end end
    function o:GetParent() return self.parent end
    function o:SetScrollChild(child) self.scrollChild = child end
    function o:GetScrollChild() return self.scrollChild end
    function o:SetVerticalScroll(value)
        homeGeometryCalls.SetVerticalScroll = homeGeometryCalls.SetVerticalScroll + 1
        self.verticalScroll = value
    end
    function o:SetPropagateKeyboardInput() end
    return o
end
UISpecialFrames = {}
function CreateFrame(kind, name, parent, template)
    createdFrames = createdFrames + 1
    local frame = object(kind, parent or UIParent)
    if name then _G[name] = frame end
    if template and template:find("Secure") then protect(frame) end
    return frame
end
function RegisterStateDriver(frame, state, condition)
    frame.stateDriver = { state = state, condition = condition }
end

local function tooltipText()
    local tip = Lychee.UI.ResultList.tooltip
    local lines = {}
    for index = 1, 5 do lines[index] = tip.labels[index]:GetText() end
    return table.concat(lines, "\n")
end

local root = "package/Lychee/"
local files = {
    "Bootstrap.lua", "Core/ContextStore.lua", "Search/Normalizer.lua", "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua", "Core/CapabilityBroker.lua", "Core/Boundary.lua", "Core/IntentRouter.lua",
    "Core/Scheduler.lua", "Core/ExtensionRegistry.lua", "Search/QueryOrchestrator.lua", "Search/SearchSession.lua", "Core/ProviderRuntime.lua", "PublicAPI/SDK.lua",
    "Core/UserPreferences.lua", "Secure/Descriptor.lua", "Secure/Policy.lua", "Secure/SecureActionBroker.lua",
    "UI/FocusController.lua", "UI/Theme.lua", "UI/Motion.lua", "UI/Components.lua", "UI/Input.lua", "UI/ResultList.lua", "UI/ViewHost.lua", "Core/ResultActionExecutor.lua", "UI/SettingsView.lua", "UI/Palette.lua",
}
for i = 1, #files do
    local before = createdFrames
    dofile(root .. files[i])
    if files[i] == "UI/Palette.lua" then assert(createdFrames == before, "loading Palette creates no hidden UI") end
end

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
    local before=createdFrames
    local result=Lychee.UI.Palette:Create()
    print("Lazy Palette: "..(createdFrames-before).." frame creations deferred until first open")
    return result
end)()
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
assertEq(palette.frame:GetAttribute("_onstate-combat"), 'if newstate == "hide" then self:Hide() end', "combat secure hide snippet")
_G.__secureSnippet = true
palette.frame:Hide()
_G.__secureSnippet = false
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

-- Fixed row/custom-panel Commands and catalog dynamic-list use the production executor.
local foreignDraft = I.Registry:Begin({ id = "interaction.foreign", apiVersion = 2, minApiRevision = 1, title = "Foreign", version = "1.0.0" })
assert(foreignDraft)
local foreignCommandCalls, foreignActionCalls, foreignOnlyCommandCalls, foreignOnlyActionCalls = 0, 0, 0, 0
assert(foreignDraft:RegisterIntentHandler({
    type = "interaction.commands.execute", version = 1, schema = {},
    handle = function() foreignCommandCalls = foreignCommandCalls + 1; return { ok = true } end,
}))
assert(foreignDraft:RegisterIntentHandler({
    type = "interaction.actions.open", version = 1, schema = {},
    handle = function() foreignActionCalls = foreignActionCalls + 1; return { ok = true } end,
}))
assert(foreignDraft:RegisterIntentHandler({
    type = "interaction.foreign.command", version = 1, schema = {},
    handle = function() foreignOnlyCommandCalls = foreignOnlyCommandCalls + 1; return { ok = true } end,
}))
assert(foreignDraft:RegisterIntentHandler({
    type = "interaction.foreign.action", version = 1, schema = {},
    handle = function() foreignOnlyActionCalls = foreignOnlyActionCalls + 1; return { ok = true } end,
}))
local foreignHandle = assert(foreignDraft:Commit())

local commandDraft = I.Registry:Begin({ id = "interaction.commands", apiVersion = 2, minApiRevision = 1, title = "Commands", version = "1.0.0" })
assert(commandDraft)
local fixedCommandCalls = 0
assert(commandDraft:RegisterIntentHandler({
    type = "interaction.commands.execute", version = 1, schema = {},
    handle = function() fixedCommandCalls = fixedCommandCalls + 1; return { ok = true } end,
}))
local fixedPanelMounted = false
assert(commandDraft:RegisterPanelFactory({
    id = "settings", stateSchema = {},
    create = function()
        return { Mount = function() fixedPanelMounted = true; return true end, Unmount = function() end, Dispose = function() end }
    end,
}))
assert(commandDraft:RegisterCommand({
    id = "execute", title = "执行固定命令", presentation = "row",
    intent = { type = "interaction.commands.execute", version = 1, payload = {} },
}))
assert(commandDraft:RegisterCommand({
    id = "settings", title = "打开固定面板", presentation = "custom-panel", panel = "settings",
}))
assert(commandDraft:RegisterCommand({
    id = "foreign", title = "越权固定命令", presentation = "row",
    intent = { type = "interaction.foreign.command", version = 1, payload = {} },
}))
assert(commandDraft:RegisterCommand({
    id = "dynamic", title = "动态目录入口", presentation = "dynamic-list", match = { type = "catalog" },
    resolve = function()
        return { { id = "dynamic-result", text = "动态目录结果", payload = {} } }
    end,
    itemIntent = function()
        return { type = "interaction.commands.execute", version = 1, payload = {} }
    end,
}))
local commandHandle = assert(commandDraft:Commit())

local _, fixedCommandResults = I.Search.Query:Query("执行固定命令", {})
assert(#fixedCommandResults == 1 and fixedCommandResults[1].command, "fixed row Command query")
assert(palette:SetResults(fixedCommandResults, palette.generation, palette.session))
assert(palette:ActivateRow(palette.list.rows[1]))
assertEq(fixedCommandCalls, 1, "fixed row Command execution")
assertEq(foreignCommandCalls, 0, "fixed row Command rejects foreign same-type Handler")

local _, fixedPanelResults = I.Search.Query:Query("打开固定面板", {})
assert(#fixedPanelResults == 1 and fixedPanelResults[1].command, "fixed custom-panel Command query")
assert(palette:SetResults(fixedPanelResults, palette.generation, palette.session))
assert(palette:ActivateRow(palette.list.rows[1]))
assertEq(fixedPanelMounted, true, "fixed custom-panel Command execution")

local _, foreignCommandResults = I.Search.Query:Query("越权固定命令", {})
assert(#foreignCommandResults == 1 and foreignCommandResults[1].command, "foreign-targeting row Command query")
assert(palette:SetResults(foreignCommandResults, palette.generation, palette.session))
local foreignCommandResult, foreignCommandErr = palette:ActivateRow(palette.list.rows[1])
assertEq(foreignCommandResult, nil, "foreign-targeting row Command result")
assertEq(foreignCommandErr, "HANDLER_UNAVAILABLE", "foreign-targeting row Command stable error")
assertEq(foreignOnlyCommandCalls, 0, "foreign-targeting row Command does not invoke foreign Handler")

local _, catalogDynamicResults = I.Search.Query:Query("动态目录入口", {})
assert(#catalogDynamicResults == 1 and catalogDynamicResults[1].text == "动态目录结果", "catalog dynamic-list resolves items")
assert(palette:SetResults(catalogDynamicResults, palette.generation, palette.session))
assert(palette:ActivateRow(palette.list.rows[1]))
assertEq(fixedCommandCalls, 2, "catalog dynamic item execution")
assertEq(foreignCommandCalls, 0, "dynamic Command rejects foreign same-type Handler")
local commandOwnerMismatch, commandOwnerMismatchErr = I.Router:Execute(
    { type = "interaction.commands.execute", version = 1, payload = {} }, {}, "interaction.no-command-handler"
)
assertEq(commandOwnerMismatch, nil, "Command owner mismatch result")
assert(commandOwnerMismatchErr and commandOwnerMismatchErr.code == "HANDLER_UNAVAILABLE", "Command owner mismatch stable error")
assertEq(foreignCommandCalls, 0, "Command owner mismatch does not invoke foreign Handler")
assert(commandHandle:Unregister())

-- SearchRecord actions stay declarative and route ordinary intents through the host router.
local actionDraft = I.Registry:Begin({ id = "interaction.actions", apiVersion = 2, minApiRevision = 1, title = "Actions", version = "1.0.0" })
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
        {
            id = "spell:foreign-action", kind = "spell", title = "越权动作",
            actions = {
                { id = "open", title = "打开", kind = "intent", intent = { type = "interaction.foreign.action", version = 1, payload = {} } },
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
local actionGeneration, actionResults = I.Search.Query:Query("动作", { visible = true })
assert(#actionResults > 0, "search returned action record")
local actionItem = actionResults[1]
assertEq(actionItem.category, "技能", "search result category")
assertEq(actionItem.description, "可执行普通动作。", "localized array description")
assertEq(actionItem.interaction.actions[1].title, "打开", "localized action title")
assert(actionItem.sourceID and actionItem.sourceGeneration and actionItem.sourceRevision, "source state retained on result")
actionItem.searchRecord._extensionID = nil
actionGeneration, actionResults = I.Search.Query:Query("动作", { visible = true })
actionItem = actionResults[1]
assertEq(actionItem._ext, "interaction.actions", "search result extension ownership")
assert(actionItem.evidence and actionItem.evidence.matchedField == "alias", "search result evidence")
assert(actionItem.confidence and actionItem.confidence >= 0.85, "search result confidence")
local categoryGeneration, categoryResults = I.Search.Query:Query("技能 动作", { visible = true })
assert(categoryGeneration and #categoryResults > 0 and categoryResults[1].category == "技能", "category filter result")
local ownerActionHandler
for handlerIndex = 1, #I.Router.handlers["interaction.actions.open"] do
    if I.Router.handlers["interaction.actions.open"][handlerIndex].ext == "interaction.actions" then
        ownerActionHandler = I.Router.handlers["interaction.actions.open"][handlerIndex]
        break
    end
end
assert(ownerActionHandler, "owner action Handler lookup")
local originalActionHandler = ownerActionHandler.handler.handle
ownerActionHandler.handler.handle = function()
    return { ok = true, transition = { type = "custom-panel", panelFactoryID = "detail", state = { itemID = 7 } } }
end
assert(palette:SetResults({ actionItem }, palette.generation, palette.session))
local routedPanel, routedPanelErr = palette:ActivateRowAction(palette.list.rows[1], "open")
assert(routedPanel and panelMounted, "search record intent mounts owner panel: " .. tostring(routedPanelErr))
ownerActionHandler.handler.handle = originalActionHandler
palette:SetResults(actionResults, actionGeneration, palette.session)
local actionRow = palette.list.rows[1]
assert(actionRow.primaryAction and actionRow.primaryAction.id == "open", "primary action is rendered from the generic protocol")
assertEq(actionRow.primaryHint:GetText(), "", "primary action title stays in tooltip")
assert(palette:TouchRecent(actionItem))
assert(palette:SetPinned(actionItem, true))
palette:RefreshHomeSections()
assert(LycheeDB and LycheeDB.palette and LycheeDB.palette.recent[1].entryID == actionItem.id, "recent stores stable id")
assert(LycheeDB.palette.pinned[1].entryID == actionItem.id and LycheeDB.palette.pinned[1].providerID == actionItem.ref.providerID, "pinned stores qualified stable ref")
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
local framesBeforeTyping = createdFrames
palette.input.frame:SetText("动")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
palette.input.frame:SetText("动作")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
assertEq(createdFrames, framesBeforeTyping, "input changes never create Home frames")
assertEq(scans, 0, "ordinary keystrokes do not rebuild the Home index")
assert(#palette.list.items > 0, "completed synchronous query produces results")
palette.input.frame:SetText("不存在")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
assertEq(#palette.list.items, 0, "query change clears stale rows before accepting replacement results")
for rowIndex = 1, #palette.list.rows do assertEq(palette.list.rows[rowIndex]:IsShown(), false, "stale row hidden " .. rowIndex) end

palette.input.frame:SetText("")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
scans = 0
assert(I.Search.StaticIndex:Invalidate("interaction.actions:records", "home-visible-refresh"))
assertEq(scans, 1, "source lifecycle refreshes Home immediately while visible")
palette.input.frame:SetText("动作")
palette.input.frame.scripts.OnTextChanged(palette.input.frame, true)
scans = 0
assert(I.Search.StaticIndex:Invalidate("interaction.actions:records", "search-hidden-home"))
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
local _, foreignActionResults = I.Search.Query:Query("越权动作", { visible = true })
assert(#foreignActionResults == 1, "foreign-targeting SearchRecord query")
assert(palette:SetResults(foreignActionResults, palette.generation, palette.session))
local foreignActionResult, foreignActionErr = palette:ActivateRowAction(palette.list.rows[1], "open")
assertEq(foreignActionResult, false, "foreign-targeting SearchRecord result")
assertEq(foreignActionErr, "HANDLER_UNAVAILABLE", "foreign-targeting SearchRecord stable error")
assertEq(foreignOnlyActionCalls, 0, "foreign-targeting SearchRecord does not invoke foreign Handler")
assert(palette:SetResults({ actionItem }, palette.generation, palette.session))
actionRow = palette.list.rows[1]
local actionOwnerMismatch, actionOwnerMismatchErr = I.Router:Execute(
    { type = "interaction.actions.open", version = 1, payload = {} }, {}, "interaction.no-action-handler"
)
assertEq(actionOwnerMismatch, nil, "SearchRecord owner mismatch result")
assert(actionOwnerMismatchErr and actionOwnerMismatchErr.code == "HANDLER_UNAVAILABLE", "SearchRecord owner mismatch stable error")
assertEq(foreignActionCalls, 0, "SearchRecord owner mismatch does not invoke foreign Handler")
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
local invalidActionDraft = I.Registry:Begin({ id = "interaction.invalid-action", apiVersion = 2, minApiRevision = 1, title = "Invalid action", version = "1.0.0" })
assert(invalidActionDraft)
local invalidDeclaration, invalidDeclarationErr = invalidActionDraft:RegisterSearchSource({
    id = "records", version = 1, revision = 1, priority = 1, scope = {},
    records = { { id = "bad:record", kind = "spell", title = "Bad", actions = {
        { id = "bad", kind = "secure-spell", spellID = 1, script = function() end },
    } } },
})
assertEq(invalidDeclaration, nil, "invalid action declaration")
assert(invalidDeclarationErr and invalidDeclarationErr.code == "INVALID_SCHEMA", "invalid action schema error")

local missingIntentDraft = I.Registry:Begin({ id = "interaction.missing-intent", apiVersion = 2, minApiRevision = 1, title = "Missing intent", version = "1.0.0" })
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

local missingSourceDraft = I.Registry:Begin({ id = "interaction.missing-source-fields", apiVersion = 2, minApiRevision = 1, title = "Missing source fields", version = "1.0.0" })
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
local draft = I.Registry:Begin({ id = "interaction.stale", apiVersion = 2, minApiRevision = 1, title = "Stale", version = "1.0.0" })
assert(draft)
local called = false
assert(draft:RegisterCommand({
    id = "stale-command", title = "Stale", presentation = "row", intent = "interaction.stale.open",
    itemIntent = function() called = true; return { type = "interaction.stale.open", version = 1, payload = {} } end,
}))
assert(draft:RegisterIntentHandler({ type = "interaction.stale.open", version = 1, schema = {}, handle = function() return { ok = true } end }))
local handle = draft:Commit()
assert(handle)
local command = I.Catalog:Get("interaction.stale:stale-command")
assert(handle:Unregister())
assert(palette:Show())
local staleRow = makeInteractionRow({ command = command, interaction = { primaryActionID = "default" } }, "interaction.stale", palette.session, palette.generation)
local staleOK, staleErr = palette:ActivateRowAction(staleRow, "default")
assertEq(staleOK, false, "unregistered stale action")
assert(staleErr == "HANDLER_UNAVAILABLE" or staleErr == "EXTENSION_DISABLED", "unregistered stale action error: " .. tostring(staleErr))

-- Launcher regressions: effective visibility, direct recent clicks, bounded
-- scrolling and secure combat cleanup, using the real host and broker.
palette:Hide("launcher-fixture")
local launcherDraft = assert(I.Registry:Begin({ id = "interaction.launcher", apiVersion = 2, minApiRevision = 1, title = "Launcher", version = "1.0.0" }))
local launcherRecords = {}
for index = 1, 12 do
    launcherRecords[index] = { id = "launcher:" .. index, kind = "spell", title = "入口测试 " .. index,
        actions = { { id = "cast", kind = "secure-spell", spellID = 31884 } },
        drag = { type = "spell", spellID = 31884 } }
end
assert(launcherDraft:RegisterSearchSource({ id = "records", version = 1, revision = 1, priority = 100, scope = {}, records = launcherRecords }))
local launcherHandle = assert(launcherDraft:Commit())
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
local warmFrames = createdFrames
palette.list:Select(8)
assert(palette.list:Move(1))
assertEq(palette.list.offset, 1, "keyboard reaches results beyond eight visible rows")
assertEq(palette.list.rows[8].item, palette.list.items[9], "scrolled row binds the ninth result")
assertEq(boundButton(palette.list.rows[8]).token.item, palette.list.items[9], "secure click rebinds after scrolling")
palette:InvalidateRow(palette.list.rows[2])
assert(palette.list:Scroll(1), "scrolling tolerates an invalidated false slot")
assertEq(createdFrames, warmFrames, "scrolling reuses all UI and secure buttons")
typeQuery("入口测试")
launcherRow = palette.list.rows[1]
launcherButton = assert(boundButton(launcherRow))
local clickedID = launcherButton.token.item.id
launcherButton.scripts.PreClick(launcherButton)
assert(launcherButton.pendingCast, "physical pre-click arms cast observation")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_FAILED", 31884))
assert(palette.visible and launcherButton.busy and launcherButton:IsShown(), "failed cast remains retryable")
launcherButton.scripts.PreClick(launcherButton)
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED", 31884))
assert(not palette.visible and not palette.frame:IsShown(), "successful spell closes launcher")
assertEq(LycheeDB.palette.recent[1].entryID, clickedID, "successful spell records stable recent ID")
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
assert(launcherHandle:SetEnabled(false))
assertEq(#I.Search.Query:ResolveRecent({ { providerID = "interaction.launcher", entryID = clickedID, sourceID = "interaction.launcher:records" } }, 5), 0, "disabled source is absent from recent launcher")
assert(launcherHandle:Unregister())

-- A mixed source owns actions and drag independently of presentation kind.
local mixedDraft = assert(I.Registry:Begin({ id = "interaction.mixed", apiVersion = 2, minApiRevision = 1, title = "Mixed" }))
assert(mixedDraft:RegisterSearchSource({ id = "records", version = 1, revision = 1, priority = 100, scope = {}, records = {
    { id = "mixed:cast", kind = "spell", title = "混合入口施放", actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 31884 },
    } },
    { id = "mixed:panel", kind = "spell", kindTitle = "技能", title = "混合入口面板", primaryActionID = "open", actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 31884 },
        { id = "open", title = "打开面板", kind = "open-panel", panel = "detail", state = { itemID = 42 } },
    }, drag = { type = "spell", spellID = 31884 } },
    { id = "mixed:command", kind = "command", title = "混合入口命令", actions = {
        { id = "run", title = "运行命令", kind = "intent", intent = { type = "interaction.mixed.run", version = 1, payload = {} } },
    } },
} }))
local mixedMounts, mixedRuns = 0, 0
assert(mixedDraft:RegisterPanelFactory({ id = "detail", stateSchema = { itemID = "integer" }, create = function(_, state)
    assertEq(state.itemID, 42, "provider panel state")
    return { Mount = function() mixedMounts = mixedMounts + 1; return true end, Unmount = function() end, Dispose = function() end }
end }))
assert(mixedDraft:RegisterIntentHandler({ type = "interaction.mixed.run", version = 1, schema = {}, handle = function()
    mixedRuns = mixedRuns + 1; return { ok = true }
end }))
local mixedHandle = assert(mixedDraft:Commit())
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
panelRow.dragger.scripts.OnDragStart(panelRow.dragger)
assertEq(_G.__pickup, mixedPickups + 1, "ordinary result executes declared drag")
palette.list:ShowTooltip(panelRow)
local panelTooltip = tooltipText()
assert(panelTooltip:find("打开面板", 1, true) and panelTooltip:find("拖动", 1, true), "tooltip describes provider primary and drag")
local mixedItems = { castRow.item, panelRow.item, commandRow.item }
LycheeDB.palette.recent = {}
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
assert(not Lychee.UI.ResultList.tooltip:IsShown() and Lychee.UI.ResultList.tooltip._owner == nil, "hiding recent view clears its root-owned tooltip")
palette.homeView:ShowTooltip(panelTile)
panelTile.scripts.OnDragStart(panelTile)
assertEq(_G.__pickup, mixedPickups + 2, "recent panel executes the same declared drag")
palette.homeView.tiles[2].scripts.OnEnter(palette.homeView.tiles[2])
local highlighted = 0
for index = 1, #palette.homeView.tiles do if palette.homeView.tiles[index].bg:IsShown() then highlighted = highlighted + 1 end end
assertEq(highlighted, 1, "recent has one highlighted icon")
palette.homeView:Move(-1)
assert(palette.homeView.tiles[1].bg:IsShown() and not palette.homeView.tiles[2].bg:IsShown(), "keyboard moves the shared recent selection")
panelTile.scripts.OnClick(panelTile)
assertEq(mixedMounts, 1, "recent click opens the provider panel")
palette:CloseView("mixed-panel")
local commandTile = findEntry(palette.homeView.tiles, "mixed:command")
commandTile.scripts.OnClick(commandTile)
assertEq(mixedRuns, 1, "recent click runs the provider command")
assertEq(LycheeDB.palette.recent[1].entryID, "mixed:command", "successful ordinary action updates recency")
assert(mixedHandle:Unregister())
-- The distributable API 2 fixture must work through real Host rendering/view code.
dofile("lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua")
local fixtureProvider = assert(ThirdPartyFixture.GetProvider())
assert(palette:Show())
typeQuery("第三方示例条目")
local fixtureRow = findEntry(palette.list.rows, "fixture-item-12345")
assertEq(fixtureRow.primaryAction.kind, "provider", "ordinary Provider action reaches the shared renderer")
assertEq(fixtureRow.dragger.dragButtons[1], "LeftButton", "custom Provider drag is registered")
fixtureRow.primaryTarget.scripts.OnClick(fixtureRow.primaryTarget, "LeftButton")
local fixturePanel = assert(ThirdPartyFixture.GetPanel())
assertEq(fixturePanel.text:GetText(), "Item 12345", "view Mount receives and renders initial state")
assert(palette.viewHost:Update({ itemID=9 }))
assertEq(fixturePanel.text:GetText(), "Item 9", "view Update receives state directly")
palette:Hide("fixture-close")
assert(not fixturePanel.frame:IsShown() and not palette.viewHost:IsActive(), "view teardown stops display")
assert(palette:Show())
local fixtureTile = findEntry(palette.homeView.tiles, "fixture-item-12345")
local menuEntries = {}
MenuUtil = { CreateContextMenu=function(_, generator)
    generator(nil, { CreateButton=function(_, title, callback)
        local entry = {title=title,callback=callback}
        menuEntries[#menuEntries+1] = entry
        return {AddInitializer=function(_, initializer) entry.initializer = initializer end, SetOnEnter=function(_, fn) entry.onEnter=fn end, SetOnLeave=function(_, fn) entry.onLeave=fn end}
    end })
end }
fixtureTile.scripts.OnClick(fixtureTile, "RightButton")
assertEq(#menuEntries, 3, "recent Provider entry exposes all actions and pin")
assert(fixtureTile.menuMixin and menuEntries[1].initializer, "recent action menu receives Lychee styling")
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
assertEq(fixturePanel.text:GetText(), "Item 12345", "recent restores current state before opening the view")
palette:Hide("fixture-done")
assert(ThirdPartyFixture.Unregister())

local menuRan = 0
local secureMenuProvider = assert(Lychee:RegisterProvider({id="ui.sdk-menu",apiVersion=2,version="1.0.0",title="Menu",
    entries={{id="secure-menu",title="安全菜单入口",actions={{id="cast",title="施放",kind="secure-spell",spellID=31884},"info",
        {id="secondary-cast",title="次要施放",kind="secure-spell",spellID=31884}}}},
    actions={info={title="查看",run=function() menuRan=menuRan+1; return {ok=true} end}},
}))
assert(palette:Show())
typeQuery("安全菜单入口")
local secureMenuRow = findEntry(palette.list.rows, "secure-menu")
local secureMenuButton = assert(boundButton(secureMenuRow))
menuEntries={}
secureMenuButton.scripts.OnMouseDown(secureMenuButton, "RightButton")
assertEq(#menuEntries, 4, "secure overlay exposes the same actions and pin")
assert(not secureMenuButton.pendingCast, "right-button menu does not initiate a protected cast")
assert(menuEntries[2].callback() and menuRan==1)
LycheeDB.palette.recent={}
local preparedSecondary=(function()
    local original, calls = IsPlayerSpell, 0
    IsPlayerSpell = function(id) calls = calls + 1; return original(id) end
    local result = menuEntries[3].callback()
    IsPlayerSpell = original
    print("Secondary secure action spell checks: " .. calls)
    assert(calls == 1, "secondary preparation checks spell availability once")
    return result
end)()
assert(preparedSecondary.awaitingHardwareClick and #LycheeDB.palette.recent==0, "arming a secure action is not successful execution")
assert(secureMenuButton:GetParent()==secureMenuRow and secureMenuButton.armedSecondary, "secondary secure action covers the correct row")
assert(palette.status:GetText():find("次要施放",1,true), "status names the prepared action")
secureMenuButton.scripts.OnEnter(secureMenuButton)
assert(Lychee.UI.ResultList.tooltip.labels[1]:GetText():find("次要施放",1,true), "armed tooltip describes the actual next action")
secureMenuButton.scripts.PreClick(secureMenuButton)
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED",31884))
assertEq(LycheeDB.palette.recent[1].entryID,"secure-menu","successful cast records recency")
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
I.Builtin=I.Builtin or {}
dofile(root.."Builtin/Mounts.lua")
assert(I.Builtin.Mounts:Init())
assert(palette:Show())
typeQuery("测试星光龙")
local mountRow=findEntry(palette.list.rows,"mount:77")
local mountButton=assert(boundButton(mountRow), "mount outside player spellbook receives secure button")
assertEq(mountButton:GetAttribute("type"),nil,"collection summon does not cast a spellbook spell")
assertEq(mountButton:GetAttribute("spell"),90077)
assertEq(mountButton.dragButtons[1],"LeftButton")
mountButton.scripts.OnDragStart(mountButton)
assertEq(mountPicked,90077,"mount row drags the summoning spell")
mountButton.scripts.PreClick(mountButton)
assert(mountButton.scripts.PostClick, "mount click has a collection summon handler")
mountButton.scripts.PostClick(mountButton, "LeftButton")
assertEq(mountSummoned,77,"mount click invokes the native collection summon API")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_FAILED",90077) and palette.visible, "failed summon keeps search open")
;(function()
    local summon, recentCount = C_MountJournal.SummonByID, #LycheeDB.palette.recent
    C_MountJournal.SummonByID = function() error("summon rejected") end
    mountButton.scripts.PreClick(mountButton)
    mountButton.scripts.PostClick(mountButton, "LeftButton")
    assert(not mountButton.pendingCast and palette.visible, "summon API failure clears pending state without closing")
    assert(#LycheeDB.palette.recent == recentCount, "rejected summon is not recorded as success")
    C_MountJournal.SummonByID = summon
end)()
mountButton.scripts.PreClick(mountButton)
mountButton.scripts.PostClick(mountButton, "LeftButton")
assert(secureBroker:FinishCast("UNIT_SPELLCAST_SUCCEEDED",90077))
assert(not palette.visible and LycheeDB.palette.recent[1].entryID=="mount:77")
assert(palette:Show())
local mountTile=findEntry(palette.homeView.tiles,"mount:77")
mountPicked=nil
assert(boundButton(mountTile)).scripts.OnDragStart(boundButton(mountTile))
assertEq(mountPicked,90077,"recent mount supports the same action-bar drag")
mountCollected=false
mountPicked=nil
local mountDragOK,mountDragErr=palette:BeginRowDrag(mountTile)
assert(not mountDragOK and mountDragErr=="ACTION_UNAVAILABLE" and mountPicked==nil, "live collection check blocks a removed mount")
palette:Hide("mount-done")
assert(I.Builtin.Mounts.handle:Unregister())
C_Spell.PickupSpell=oldPickup
C_MountJournal=nil
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
for _, name in ipairs(UISpecialFrames) do if name == "LycheePalette" then registrations = registrations + 1 end end
assert(registrations == 1, "Escape registration is not duplicated")
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
    LycheeDB.palette.pinned={};LycheeDB.palette.recent={}
    local source=assert(Lychee:RegisterProvider({id="settings.fixture",apiVersion=2,version="1.0.0",title="设置测试来源",
        entries={{id="a",title="设置固定甲",icon=123,actions={"open"}},{id="b",title="设置固定乙",icon=456,actions={"open"}}},
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
    typeQuery("荔枝设置")
    local settingRow=findEntry(controller.list.rows,"settings")
    assert(settingRow and controller:ActivateRow(settingRow) and controller.settingsOpen, "search opens same settings page")
    controller:Hide("settings-test")
    assert(not controller.settingsOpen and not view.frame:IsShown())
    controller:Show();assert(controller:IsHomeVisible() and controller.input.container:IsShown())
    assert(not prefs:CanPin(prefs:Resolve({providerID="lychee.settings",entryID="settings"})))
    controller:Hide("done");assert(source:Unregister());C_Timer=savedTimers
    print("Lychee settings and pins interaction PASS")
end)()
