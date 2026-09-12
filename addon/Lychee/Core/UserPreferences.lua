local I = _G.LycheeInternal
local Preferences = {}
I.UserPreferences = Preferences

local LIMIT, BYTES = 64, 65536
local fields = {providerID=1024,entryID=1024,sourceID=1024,title=4096,sourceTitle=4096,icon=1024}
local owner, original, active, size, recovery
local EMPTY = {}
local function matches(left, right)
    return type(left) == "table" and type(right) == "table"
        and left.providerID == right.providerID and left.entryID == right.entryID
end
local function pinBytes(pin)
    if type(pin) ~= "table" or getmetatable(pin) ~= nil then return end
    if type(pin.providerID) ~= "string" or pin.providerID == "" or type(pin.entryID) ~= "string" or pin.entryID == "" then return end
    local bytes, count = 16, 0
    for key,value in next,pin do
        count = count + 1
        local limit = fields[key]
        if count > 6 or not limit then return end
        if key == "icon" and type(value) == "number" then
            if value ~= value or value < 0 or value == math.huge or value % 1 ~= 0 then return end
            bytes = bytes + 16
        elseif type(value) == "string" and #value <= limit then bytes = bytes + #value + 16
        else return end
    end
    return bytes
end
local function validate(pins)
    if type(pins) ~= "table" or getmetatable(pins) ~= nil then return end
    local count, bytes = 0, 0
    for key in next,pins do
        count = count + 1
        if count > LIMIT or type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > LIMIT then return end
    end
    for index=1,count do
        local pin = rawget(pins,index)
        local cost = pinBytes(pin)
        if not cost then return end
        bytes = bytes + cost
        if bytes > BYTES then return end
        for prior=1,index-1 do if matches(pins[prior],pin) then return end end
    end
    return bytes
end
local function pins()
    local saved = I.CharacterStore:Data()
    if saved.pinned == nil then saved.pinned = {} end
    if saved ~= owner or saved.pinned ~= original then
        owner, original = saved, saved.pinned
        size = validate(original)
        recovery = size == nil and "PIN_DATA_INVALID" or nil
        active = not recovery and original or EMPTY
    end
    return active
end
function Preferences:Initialize() pins() end
function Preferences:GetPins() return pins() end
function Preferences:GetRecoveryError() pins(); return recovery end
function Preferences:CanPin(item)
    return item and item.ref
        and I.Providers and I.Providers:CanRemember(item) == true
end
function Preferences:PinIndex(ref)
    for index,pin in ipairs(pins()) do if matches(pin,ref) then return index end end
end
local function insert(pin,index)
    local list = pins()
    if recovery then return false,recovery end
    local cost = pinBytes(pin)
    if not cost then return false,"PIN_DATA_INVALID" end
    if #list >= LIMIT or size + cost > BYTES then return false,"PIN_LIMIT" end
    table.insert(list,index or #list+1,pin); size = size + cost
    return true
end
function Preferences:Pin(item)
    if not self:CanPin(item) then return false,"PIN_UNAVAILABLE" end
    if self:GetRecoveryError() then return false,recovery end
    local ref = item.ref
    if self:PinIndex(ref) then return true end
    return insert({providerID=ref.providerID,entryID=ref.entryID,sourceID=ref.sourceID,
        title=item.text,icon=item.icon,sourceTitle=item.sourceTitle})
end
local function indexValid(index)
    return type(index) == "number" and index == index and index % 1 == 0
end
function Preferences:Remove(index)
    local list = pins()
    if recovery or not indexValid(index) or index < 1 or index > #list then return false end
    local pin = table.remove(list,index); size = size - pinBytes(pin)
    return pin
end
function Preferences:Restore(pin,index)
    local list = pins()
    if self:PinIndex(pin) or (index ~= nil and not indexValid(index)) then return false end
    return insert(pin,math.max(1,math.min(index or #list+1,#list+1)))
end
function Preferences:Move(from,to)
    local list = pins()
    if recovery or not indexValid(from) or not indexValid(to) or from < 1 or from > #list then return false end
    to = math.max(1,math.min(#list,to))
    if from == to then return true end
    table.insert(list,to,table.remove(list,from))
    return true
end
function Preferences:Resolve(pin)
    if type(pin) ~= "table" then return nil end
    return I.Providers and I.Providers:Resolve(pin,I.Context and I.Context:Snapshot() or {})
end