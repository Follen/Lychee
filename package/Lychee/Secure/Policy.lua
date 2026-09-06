local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Policy = {}
function Policy:CanConfigure() return not (InCombatLockdown and InCombatLockdown()) end
function Policy:IsSpellAvailable(spellID)
    if type(spellID) ~= "number" then return false end
    local known = IsPlayerSpell and IsPlayerSpell(spellID)
    if known == false then return false end
    -- Usability changes with cooldown, resources and destination state. It must
    -- not prevent preparing the secure button; the hardware click applies the
    -- game's current usability rules.
    if IsPassiveSpell and IsPassiveSpell(spellID) then return false end
    return true
end
function Policy:Check(descriptor)
    if not self:CanConfigure() then return false, "COMBAT_LOCKED" end
    if not self:IsSpellAvailable(descriptor.spellID) then return false, "ACTION_UNAVAILABLE" end
    return true
end
Lychee.Secure.Policy = Policy
