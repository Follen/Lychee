-- Real Host/catalog/API 1.0.0; deterministic WoW adapters for package providers.
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "today", 120100 end
local state = {combat=false}
function InCombatLockdown() return state.combat end
STANDARD_TEXT_FONT = "test.ttf"
local frames, calls = {}, {}
local Frame = {}
Frame.__index = Frame
function Frame:SetScript(event, fn) self.scripts[event]=fn end
function Frame:RegisterEvent(event) self.events[event]=true end
function Frame:UnregisterAllEvents() self.events={} end
function Frame:Show() local old=self.shown; self.shown=true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown end
function Frame:IsEnabled() return not self.disabled end
function Frame:GetID() return self.tabID end
function Frame:SetText(text) self.text=text; self.sets=(self.sets or 0)+1 end
function Frame:SetTexture(texture) self.texture=texture end
function Frame:SetParent(parent) self.parent=parent end
function Frame:GetWidth() return 600 end
function Frame:GetHeight() return 360 end
for _, name in ipairs({"SetPoint","SetAllPoints","ClearAllPoints","SetSize","SetWidth","SetHeight","SetJustifyH","SetFont","SetTextColor","SetShadowOffset","SetTexCoord"}) do Frame[name]=function() end end
function CreateFrame(_, name, parent)
    local frame=setmetatable({scripts={},events={},parent=parent,shown=false},Frame)
    frames[#frames+1]=frame
    if name then _G[name]=frame end
    return frame
end
function Frame:CreateFontString() return CreateFrame() end
function Frame:CreateTexture() return CreateFrame() end
UIParent=CreateFrame()
local root="addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"../Lychee_Player/Achievements/Locales.lua", "../Lychee_Inspector/Locales.lua", "../Lychee_Player/Bags/Locales.lua", "../Lychee_Player/BlizzardSettings/Locales.lua", "../Lychee_Encounters/Bosses/Locales.lua", "../Lychee_Player/Crests/Locales.lua", "../Lychee_Player/EquipmentSets/Locales.lua", "../Lychee_Player/GameMenus/Locales.lua", "../Lychee_Player/GreatVault/Locales.lua", "../Lychee_Player/Keystones/Locales.lua", "../Lychee_Player/Mounts/Locales.lua", "../Lychee_Player/PlayerSpells/Locales.lua", "../Lychee_Player/TalentLoadouts/Locales.lua", "../Lychee_Player/Runtime/CatalogProvider.lua", "../Lychee_Player/Runtime/CatalogLedger.lua", "../Lychee_Player/Runtime/InterfaceActions.lua", "../Lychee_Encounters/Runtime/CatalogProvider.lua", "../Lychee_Encounters/Runtime/CatalogLedger.lua", "../Lychee_Encounters/Runtime/InterfaceActions.lua", "Search/ProviderPolicy.lua", "Core/Scheduler.lua", "UI/Theme.lua", "UI/TextHighlight.lua", "UI/ViewHost.lua", "Core/ResultActionExecutor.lua", "../Lychee_Encounters/Bosses/JournalCatalog.lua", "../Lychee_Player/Crests/Provider.lua", "../Lychee_Player/GameMenus/Provider.lua", "../Lychee_Encounters/Bosses/Provider.lua", })
return {frames=frames,calls=calls,state=state}
