local addonName, namespace = ...
local I = _G.LycheeInternal or {}
_G.LycheeInternal = I
I.LycheeSDK=I.LycheeSDK or {}
if type(namespace)=="table" then namespace.LycheeSDK=I.LycheeSDK end
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
I.Modules = I.Modules or {}
-- SavedVariables are restored by WoW after files load. This bootstrap owns no
-- account schema: leave existing (including unknown-version) data untouched.
-- Individual storage owners validate and migrate only their own fields.

local function wireRegistryLifecycle()
    if I._registryLifecycleWired or not I.Registry then return end
    I._registryLifecycleWired = true
    I.Registry:OnChange(function(entry, state)
        local palette = I.Host and I.Host.PaletteController
        if palette and palette.SourcesChanged then palette:SourcesChanged(entry.id,state) end
        if state ~= "disabled" and state ~= "retiring" and state ~= "removed" then return end
        if I.Search and I.Search.Session then I.Search.Session:Invalidate("extension-" .. state)
        elseif I.Search and I.Search.Query and I.Search.Query.Cancel then I.Search.Query:Cancel("extension-" .. state) end
    end)
end

local bindingNeedsSave = false
local function initializeDefaultBinding(settings)
    if settings.defaultBindingComplete or (InCombatLockdown and InCombatLockdown()) then return end
    if type(GetBindingKey)~="function" or type(GetBindingAction)~="function" or type(SetBinding)~="function"
        or type(SaveBindings)~="function" or type(GetCurrentBindingSet)~="function" then return end
    local ok, key = pcall(GetBindingKey,"TOGGLELYCHEE")
    local actionOK, action = pcall(GetBindingAction,"ALT-SPACE")
    if not ok or not actionOK or (issecretvalue and (issecretvalue(key) or issecretvalue(action))) then return end
    if (type(key)=="string" and key~="" and (key~="ALT-SPACE" or not bindingNeedsSave)) or (type(action)=="string" and action~="" and action~="TOGGLELYCHEE") then
        -- An existing custom binding or conflicting action is a user choice.
        settings.defaultBindingComplete=true
        bindingNeedsSave=false
        return
    end
    if action~=nil and type(action)~="string" then return end
    if action~="TOGGLELYCHEE" then
        local assigned, result=pcall(SetBinding,"ALT-SPACE","TOGGLELYCHEE")
        if not assigned or result==false then return end
        local readOK, applied=pcall(GetBindingAction,"ALT-SPACE")
        if not readOK or (issecretvalue and issecretvalue(applied)) or applied~="TOGGLELYCHEE" then return end
    end
    bindingNeedsSave=true
    local setOK, set=pcall(GetCurrentBindingSet)
    if not setOK or (issecretvalue and issecretvalue(set)) or (set~=1 and set~=2) then return end
    local saved, result=pcall(SaveBindings,set)
    if not saved or result==false then return end
    bindingNeedsSave=false
    -- The legacy attempted flag was written before SetBinding and cannot prove
    -- success. Repair an unbound/free legacy installation once; thereafter an
    -- intentional unbind is respected. No polling or extra event is introduced.
    settings.defaultBindingComplete=true
    settings.defaultBindingAttempted=true
end

local function onLogin()
    I.CharacterStore:Initialize()
    if I.UserPreferences then I.UserPreferences:Initialize() end
    local settings = I.CharacterStore:Data()
    initializeDefaultBinding(settings)
    wireRegistryLifecycle()
    if I.ProjectProviders then I.ProjectProviders:InitializeSystemSources() end
    if I.ProviderModules and I.ProviderModules.Init then I.ProviderModules:Init() end
    if I.Registry then I.Registry:SetReady(true) end
    local palette = I.Host and I.Host.PaletteController
    if palette then I.WirePalette(palette) end
end

function I.WirePalette(palette)
    if not palette or not I.Search or not I.Search.Session or not I.ResultActionExecutor or I._paletteWired then return false end
    I._paletteWired = true
    wireRegistryLifecycle()
    if I.ProjectProviders then I.ProjectProviders:InitializeSystemSources() end
    I.Search.Session:BindPresenter(palette)
    I.ResultActionExecutor:BindPalette(palette)
    palette:SetQueryCallback(function(raw) return I.Search.Session:Input(raw) end)
    return true
end

local frame = CreateFrame and CreateFrame("Frame")
if frame then
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then if I.DeliverAddonLoaded then I.DeliverAddonLoaded(name) end
        elseif event == "PLAYER_LOGIN" then onLogin()
        elseif event == "PLAYER_LOGOUT" then
            if I.Invocations then I.Invocations:CancelAll("CHARACTER_CHANGED") end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if I.Invocations then I.Invocations:CancelAll("COMBAT_LOCKED") end
            if I.Host and I.Host.PaletteController then I.Host.PaletteController:Hide("combat") end
        elseif event == "PLAYER_REGEN_ENABLED" then
            local palette=I.Host and I.Host.PaletteController
            if palette then palette:FinishCombatCleanup() end
            if I.Host and I.Host.SecureBroker then I.Host.SecureBroker:Flush() end
            onLogin()
        end
    end)
end

I.OnLogin = onLogin

function I.SetAddonLoadWatch(enabled)
    if not frame then return end
    if enabled then frame:RegisterEvent("ADDON_LOADED") else frame:UnregisterEvent("ADDON_LOADED") end
end
