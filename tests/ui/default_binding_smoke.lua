local function runCase(existingKey, existingAction)
    _G = _G or {}
    _G.LycheeInternal = nil
    LycheeDB = nil; LycheeCharacterDB = nil

    local setCalls = 0
    local saveCalls = 0

    function InCombatLockdown() return false end
    function GetBindingKey(action)
        assert(action == "TOGGLELYCHEE")
        return existingKey
    end
    function GetBindingAction(key)
        assert(key == "ALT-SPACE")
        return existingAction
    end
    function SetBinding(key, action)
        assert(key == "ALT-SPACE" and action == "TOGGLELYCHEE")
        setCalls = setCalls + 1
        return true
    end
    function SaveBindings(bindingSet)
        assert(bindingSet == 1)
        saveCalls = saveCalls + 1
        return true
    end
    function GetCurrentBindingSet() return 1 end
    function CreateFrame()
        return {
            RegisterEvent = function() end,
            SetScript = function() end,
        }
    end

    dofile("addon/Lychee/Bootstrap.lua"); dofile("addon/Lychee/Core/CharacterStore.lua")
    _G.LycheeInternal.OnLogin()

    return setCalls, saveCalls
end

local setCalls, saveCalls = runCase(nil, "")
assert(setCalls == 1 and saveCalls == 1, "an empty binding action must receive the default binding")

setCalls, saveCalls = runCase(nil, "SOME_OTHER_ACTION")
assert(setCalls == 0 and saveCalls == 0, "an occupied key must not be overwritten")

setCalls, saveCalls = runCase("ALT-SPACE", "")
assert(setCalls == 0 and saveCalls == 0, "an existing Lychee binding must be preserved")

print("Lychee default binding smoke PASS")
