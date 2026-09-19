function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
-- Offline interaction contract smoke. This harness exercises host-owned UI guards
-- without pretending to validate the real WoW secure-click implementation.
local requestedLocale = ...
_G = _G or {}
UIParent = { width = 800, height = 600 }
function UIParent:GetWidth() return self.width end
function UIParent:GetHeight() return self.height end
function UIParent:GetEffectiveScale() return self.scale or 1 end
function GetCursorPosition() return 200, 300 end
function GetLocale() return requestedLocale or "zhCN" end
function InCombatLockdown() return _G.__combat == true end
function geterrorhandler() return function(err) return err end end
function IsPlayerSpell(id) return id == 31884 end
function PickupSpell() _G.__pickup = (_G.__pickup or 0) + 1 end

local env = {createdFrames=0}
local homeGeometryCalls = { ClearAllPoints = 0, SetPoint = 0, SetVerticalScroll = 0 }
local function protect(o)
    while o and o ~= UIParent do o.protected = true; o = o.parent end
end
local function mutation(o, name)
    assert(not (o.protected and InCombatLockdown() and not _G.__secureSnippet), "insecure combat mutation: " .. name)
end
local function object(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, width = 800, height = 600, scripts = {}, attrs = {} }
    function o:SetMaxBytes(value) self.maxBytes=value end
    function o:GetScript(event) return self.scripts[event] end
    function o:HookScript(key,fn) local old=self.scripts[key];self.scripts[key]=function(...) if old then old(...) end;fn(...) end end
    function o:SetJustifyV(value) self.justifyV=value end
    function o:SetWordWrap(value) self.wordWrap=value end
    function o:SetNonSpaceWrap(value) self.nonSpaceWrap=value end
    function o:GetStringWidth() return #(self.text or "")*6 end
    function o:SetMaxLines(value) self.maxLines=value end
    function o:SetAllPoints(target) mutation(self, "SetAllPoints");self.allPoints=target or self.parent end
    function o:SetClipsChildren(value) self.clipsChildren=value end
    function o:SetPoint(...) mutation(self, "SetPoint"); self.point = { ... }; homeGeometryCalls.SetPoint = homeGeometryCalls.SetPoint + 1 end
    function o:GetPoint() if self.point then return unpack(self.point) end end
    function o:ClearAllPoints() mutation(self, "ClearAllPoints"); homeGeometryCalls.ClearAllPoints = homeGeometryCalls.ClearAllPoints + 1 end
    function o:SetSize(w, h) mutation(self, "SetSize"); self.width, self.height = w, h end
    function o:SetHeight(h) mutation(self, "SetHeight"); self.height = h end
    function o:SetWidth(w) mutation(self, "SetWidth"); self.width = w end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:UpdateScrollChildRect() mutation(self,"UpdateScrollChildRect");self.rectUpdates=(self.rectUpdates or 0)+1 end
    function o:SetAlpha(value) mutation(self,"SetAlpha");self.alpha=value end
    function o:SetScale(value) mutation(self,"SetScale");self.scale=value end
    function o:SetIgnoreParentScale(value) mutation(self,"SetIgnoreParentScale");self.ignoreParentScale=value end
    function o:GetEffectiveScale()
        return (self.scale or 1)*(not self.ignoreParentScale and self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1)
    end
    function o:GetAlpha() return self.alpha or 1 end
    function o:GetStringHeight() return 15 end
    function o:SetClampedToScreen(enabled) self.clamped = enabled end
    function o:SetFrameStrata() end
    function o:SetFrameLevel(value) mutation(self, "SetFrameLevel"); self.frameLevel = value end
    function o:GetFrameLevel() return self.frameLevel or 0 end
    function o:SetBackdrop() end
    function o:EnableMouse() end
    function o:SetAutoFocus() end
    function o:EnableMouseWheel(value) self.mouseWheel=value end
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
    function o:SetVertexColor(...) self.vertexColor={...} end
    function o:SetTextColor(...) self.textColor = { ... } end
    function o:SetText(v) self.text = v end
    function o:GetText() return self.text or "" end
    function o:HasFocus() return self.focused == true end
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
function SecureHandlerSetFrameRef(frame,key,child)
    frame.refs=frame.refs or {};frame.refs[key]=child
    frame.GetFrameRef=function(self,name) return self.refs[name] end
end
function RunPaletteCombatSnippet(frame)
    local callback=assert(loadstring("return function(self,newstate) "..frame:GetAttribute("_onstate-combat").." end"))()
    _G.__secureSnippet=true;callback(frame,"hide");_G.__secureSnippet=false
end
function CreateFrame(kind, name, parent, template)
    env.createdFrames = env.createdFrames + 1
    local frame = object(kind, parent or UIParent)
    if name then _G[name] = frame end
    if template and template:find("Secure") then protect(frame) end
    return frame
end
function RegisterStateDriver(frame, state, condition)
    frame.stateDriver = { state = state, condition = condition }
end

local function tooltipText()
    local tip = Lychee.UI.Components.tooltip
    local lines = {}
    for index = 1, 5 do lines[index] = tip.labels[index]:GetText() end
    return table.concat(lines, "\n")
end

dofile("tests/support/runtime.lua").Load("provider", {"Core/Preparation.lua","Builtin/Achievements/Locales.lua", "Builtin/AddonInspector/Locales.lua", "Builtin/Bags/Locales.lua", "Builtin/BlizzardSettings/Locales.lua", "Builtin/Bosses/Locales.lua", "Builtin/Crests/Locales.lua", "Builtin/EquipmentSets/Locales.lua", "Builtin/GameMenus/Locales.lua", "Builtin/GreatVault/Locales.lua", "Builtin/Keystones/Locales.lua", "Builtin/Mounts/Locales.lua", "Builtin/PlayerSpells/Locales.lua", "Builtin/TalentLoadouts/Locales.lua", "Builtin/Shared/CatalogProvider.lua", "Builtin/Shared/CatalogLedger.lua", "Builtin/Shared/InterfaceActions.lua", "Builtin/Shared/CatalogProvider.lua", "Builtin/Shared/CatalogLedger.lua", "Builtin/Shared/InterfaceActions.lua", "Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Search/SearchSession.lua", "Core/UserPreferences.lua", "Search/Personalization.lua", "Secure/Descriptor.lua", "Secure/Policy.lua", "Secure/SecureActionBroker.lua", "UI/FocusController.lua", "UI/Theme.lua", "UI/TextHighlight.lua", "UI/Motion.lua", "UI/Presence.lua", "UI/Runtime.lua", "UI/Components.lua", "UI/Input.lua", "UI/ResultList.lua", "UI/ViewHost.lua", "Core/ResultActionExecutor.lua", "UI/AliasSettings.lua", "UI/ProviderSettings.lua", "UI/SocialLinks.lua", "UI/SettingsView.lua", "UI/HomeView.lua", "UI/Palette.lua"}, {load=function(path)
    assert(loadfile("addon/Lychee/"..path))("Lychee",_G.LycheeInternal)
    if path=="UI/Palette.lua" then assert(not (LycheeInternal.Host and LycheeInternal.Host.PaletteController),"loading Palette creates no hidden UI") end
end})

return {state=env,geometry=homeGeometryCalls,tooltipText=tooltipText}
