local I = _G.LycheeInternal
local Preferences = {}
I.UserPreferences = Preferences

local function db()
    local saved = I.CharacterStore:Data()
    saved.pinned = type(saved.pinned) == "table" and saved.pinned or {}
    return saved
end
local function matches(left, right)
    return type(left) == "table" and type(right) == "table"
        and left.providerID == right.providerID and left.entryID == right.entryID
end
function Preferences:Initialize() db() end
function Preferences:GetPins() return db().pinned end
function Preferences:CanPin(item)
    return item and item.ref and item.ref.providerID ~= "lychee.settings"
        and I.Providers and I.Providers:CanRemember(item) == true
end
function Preferences:PinIndex(ref)
    for index, pin in ipairs(self:GetPins()) do if matches(pin, ref) then return index end end
end
function Preferences:Pin(item)
    if not self:CanPin(item) then return false, "PIN_UNAVAILABLE" end
    local pins, ref = self:GetPins(), item.ref
    if self:PinIndex(ref) then return true end
    if #pins >= 64 then return false, "PIN_LIMIT" end
    pins[#pins + 1] = { providerID=ref.providerID, entryID=ref.entryID, sourceID=ref.sourceID,
        title=item.text, icon=item.icon, sourceTitle=item.sourceTitle }
    return true
end
function Preferences:Remove(index)
    local pins = self:GetPins()
    if type(index) ~= "number" or index < 1 or index > #pins then return false end
    return table.remove(pins, index)
end
function Preferences:Restore(pin, index)
    local pins = self:GetPins()
    if (type(pin) ~= "table" and type(pin) ~= "string") or self:PinIndex(pin) or #pins >= 64 then return false end
    table.insert(pins, math.max(1, math.min(index or #pins + 1, #pins + 1)), pin)
    return true
end
function Preferences:Move(from, to)
    local pins = self:GetPins()
    if type(from) ~= "number" or type(to) ~= "number" or from < 1 or from > #pins then return false end
    to = math.max(1, math.min(#pins, to))
    if from == to then return true end
    local pin = table.remove(pins, from)
    table.insert(pins, to, pin)
    return true
end
function Preferences:Resolve(pin)
    if type(pin) ~= "table" then return nil end
    return I.Providers and I.Providers:Resolve(pin, I.Context and I.Context:Snapshot() or {})
end
