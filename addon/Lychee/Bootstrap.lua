local addonName,namespace = ...
local I = namespace or _G.LycheeInternal or {}
_G.LycheeInternal = I
-- Client locale is immutable during a session; zhTW uses Simplified Chinese fallback.
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
local L = setmetatable({ code = locale }, { __index = function(_, key) return key end })
I.Locale = L
function L:IsChinese() return self.code == "zhCN" or self.code == "zhTW" end
function L:Add(entries)
    if self:IsChinese() then return end
    for key, value in pairs(entries) do self[key] = value end
end
function L:Format(key, ...) return string.format(self[key], ...) end
function L:Resolve(value, fallback)
    if I.Search and I.Search.Normalizer and I.Search.Normalizer.Display then
        return I.Search.Normalizer:Display(value, fallback)
    end
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return fallback or "" end
    local family = self:IsChinese() and "zhCN" or "enUS"
    if value.text then return value.text end
    if value[self.code] or value[family] or value.default or value.enUS then
        return value[self.code] or value[family] or value.default or value.enUS
    end
    local exact, related, default, english
    for index = 1, #value do
        local entry = value[index]
        if type(entry) == "string" then default = default or entry
        elseif type(entry) == "table" then
            local text = entry.text or entry.title
            if entry.locale == self.code then exact = exact or text
            elseif entry.locale == family then related = related or text
            elseif entry.locale == nil or entry.locale == "default" then default = default or text
            elseif entry.locale == "enUS" then english = english or text end
        end
    end
    return exact or related or default or english or fallback or ""
end
L.name = L:IsChinese() and "|cffd53c49荔枝|r启动器" or "|cffd53c49Lychee|r Launcher"

I.VERSION = { api = "1.0.0" }

local function wireRegistryLifecycle()
    if I._registryLifecycleWired or not I.Registry then return end
    I._registryLifecycleWired = true
    I.Registry:OnChange(function(entry, state)
        if state ~= "disabled" and state ~= "retiring" and state ~= "removed" then return end
        if I.Search and I.Search.Session then I.Search.Session:Invalidate("extension-" .. state)
        elseif I.Search and I.Search.Query and I.Search.Query.Cancel then I.Search.Query:Cancel("extension-" .. state) end
        local palette = I.Host and I.Host.PaletteController
        if palette and palette.InvalidateExtension then palette:InvalidateExtension(entry.id, state) end
    end)
end

local function onLogin()
    I.CharacterStore:Initialize()
    if I.UserPreferences then I.UserPreferences:Initialize() end
    local settings = I.CharacterStore:Data()
    if type(GetBindingKey)=="function" and type(GetBindingAction)=="function" and type(SetBinding)=="function" and type(SaveBindings)=="function" and type(GetCurrentBindingSet)=="function" and not settings.defaultBindingAttempted and not (InCombatLockdown and InCombatLockdown()) then
        settings.defaultBindingAttempted = true
        local existingAction = GetBindingAction("ALT-SPACE")
        if not GetBindingKey("TOGGLELYCHEE") and (existingAction == nil or existingAction == "") then
            SetBinding("ALT-SPACE", "TOGGLELYCHEE")
            SaveBindings(GetCurrentBindingSet())
        end
    end
    wireRegistryLifecycle()
    if I.Registry then I.Registry:SetReady(true) end
    local palette = I.Host and I.Host.PaletteController
    if palette then I.WirePalette(palette) end
end

function I.WirePalette(palette)
    if not palette or not I.Search or not I.Search.Session or not I.ResultActionExecutor or I._paletteWired then return false end
    I._paletteWired = true
    I.Search.Session:BindPalette(palette)
    I.ResultActionExecutor:BindPalette(palette)
    palette:SetQueryCallback(function(raw) return I.Search.Session:Input(raw) end)
    return true
end

local frame = CreateFrame and CreateFrame("Frame")
function I.SetAddonLoadWatch(enabled)
    if not frame then return end
    if enabled then frame:RegisterEvent("ADDON_LOADED") else frame:UnregisterEvent("ADDON_LOADED") end
end
if frame then
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event,name)
        if event=="ADDON_LOADED" and I.DeliverAddonLoaded then I.DeliverAddonLoaded(name)
        elseif event == "PLAYER_LOGIN" then onLogin()
        elseif event == "PLAYER_REGEN_DISABLED" and I.Host and I.Host.PaletteController then I.Host.PaletteController:Hide("combat")
        elseif event == "PLAYER_REGEN_ENABLED" then
            if I.Host and I.Host.SecureBroker then I.Host.SecureBroker:Flush() end
            onLogin()
        end
    end)
end

I.OnLogin = onLogin
