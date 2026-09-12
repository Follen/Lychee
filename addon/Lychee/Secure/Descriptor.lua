local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Descriptor = {}
local function finiteNumber(value) return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge end

function Descriptor.Validate(value)
    if type(value) == "table" and value.kind == "item" then
        if finiteNumber(value.itemID) and value.itemID > 0 and value.itemID == math.floor(value.itemID) then return true end
        return false, "INVALID_SECURE_DESCRIPTOR"
    end
    if type(value) ~= "table" or value.kind ~= "spell" or not finiteNumber(value.spellID) or value.spellID <= 0 then return false, "INVALID_SECURE_DESCRIPTOR" end
    if value.unit ~= nil and type(value.unit) ~= "string" then return false, "INVALID_SECURE_DESCRIPTOR" end
    return true
end
function Descriptor.FromAction(action)
    if type(action) == "table" and action.kind == "secure-item" then
        local d={kind="item",itemID=action.itemID}
        local ok,err=Descriptor.Validate(d)
        if not ok then return nil,err end
        return d
    end
    if type(action) ~= "table" or action.kind ~= "secure-spell" then return nil, "INVALID_SECURE_DESCRIPTOR" end
    local d = { kind = "spell", spellID = action.spellID }
    if action.unit then d.unit = action.unit end
    local ok, err = Descriptor.Validate(d)
    if not ok then return nil, err end
    return d
end
Lychee.Secure.Descriptor = Descriptor
