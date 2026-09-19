local I = _G.LycheeInternal
local Store = {}
I.CharacterStore = Store

-- WoW owns the root and replaces it after loading this character's SV.
-- Do not capture it in a module closure or initialize it at file load time.
function Store:Data()
    if type(LycheeCharacterDB) ~= "table" then LycheeCharacterDB = {} end
    return LycheeCharacterDB
end
function Store:Palette()
    local data = self:Data()
    if type(data.palette) ~= "table" then data.palette = {} end
    return data.palette
end
function Store:DisabledProviders()
    local data = self:Data()
    if type(data.disabledProviders) ~= "table" then data.disabledProviders = {} end
    return data.disabledProviders
end
function Store:ProviderSearchEnabled(id, defaultEnabled)
    local disabled = self:DisabledProviders()[id]
    if disabled ~= nil then return not disabled end
    return defaultEnabled ~= false
end
function Store:Initialize()
    local data = self:Data()
    if data.settingsVersion == 1 then return end
    -- The former account preferences have no character owner. Transfer once
    -- to the upgrading character; later characters start with their own defaults.
    -- Pins already have an explicit owner and must never be imported here.
    if type(LycheeDB) == "table" and type(LycheeDB.palette) == "table" then
        local old = LycheeDB.palette
        old.pinned = nil
        if type(data.palette) ~= "table" then data.palette = old
        else
            for key, value in pairs(old) do
                if data.palette[key] == nil then data.palette[key] = value end
            end
        end
        LycheeDB.palette = nil
    end
    -- Old account flags mix automatic opt-outs with user intent. They cannot
    -- define this character's defaults. Explicit character choices always win.
    self:Palette()
    self:DisabledProviders()
    data.settingsVersion = 1
end
