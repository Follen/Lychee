local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.Secure = Lychee.Secure or {}

local Policy = {}
local function collectedMount(spellID)
    if not C_MountJournal or type(C_MountJournal.GetMountFromSpell) ~= "function"
        or type(C_MountJournal.GetMountInfoByID) ~= "function" then return false end
    local mountID = C_MountJournal.GetMountFromSpell(spellID)
    if type(mountID) ~= "number" then return false end
    local _, mountSpellID, _, _, _, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(mountID)
    return mountSpellID == spellID and collected == true and not hidden, mountID
end
function Policy:CanConfigure() return not (InCombatLockdown and InCombatLockdown()) end
function Policy:IsSpellAvailable(spellID)
    if type(spellID) ~= "number" then return false end
    local known
    if C_SpellBook and C_SpellBook.IsSpellKnown and Enum and Enum.SpellBookSpellBank then
        known = C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)
    elseif IsPlayerSpell then
        known = IsPlayerSpell(spellID)
    end
    if known == false then
        -- Collection spells need not be present in the player's spellbook.
        -- Validate the live collection, rather than trusting a Provider flag.
        local ok, available = pcall(collectedMount, spellID)
        if not ok or not available then return false end
    end
    -- Usability changes with cooldown, resources and destination state. It must
    -- not prevent preparing the secure button; the hardware click applies the
    -- game's current usability rules.
    local isPassive = C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell
    if isPassive and isPassive(spellID) then return false end
    return true
end
function Policy:Check(descriptor)
    if not self:CanConfigure() then return false, "COMBAT_LOCKED" end
    if descriptor.kind == "item" then
        if not C_Item or not C_Item.GetItemCount or C_Item.GetItemCount(descriptor.itemID, false) <= 0 then return false, "ITEM_NOT_FOUND" end
        return true
    end
    local ok, available, mountID = pcall(collectedMount, descriptor.spellID)
    if ok and available then return true, nil, mountID end
    if not self:IsSpellAvailable(descriptor.spellID) then return false, "ACTION_UNAVAILABLE" end
    return true
end
Lychee.Secure.Policy = Policy
