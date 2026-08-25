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

assert(palette:Show())
local interactionItem = { interaction = {
    primaryActionID = "cast",
    actions = { { id = "cast", kind = "secure-spell", spellID = 31884 } },
    drag = { type = "not-spell", spellID = 31884 },
} }
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
