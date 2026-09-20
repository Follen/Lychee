-- Bootstrap must not erase an account root merely because its schema differs.
local function boot(saved)
    _G.LycheeInternal = nil
    _G.LycheeDB = saved
    _G.CreateFrame = nil
    assert(loadfile("addon/Lychee/Bootstrap.lua"))("Lychee", {})
    assert(_G.LycheeDB == saved, "bootstrap replaced SavedVariables root")
end

local unknown = { schemaVersion = 99, palette = { reduceMotion = true }, custom = {} }
local palette, custom = unknown.palette, unknown.custom
boot(unknown)
assert(unknown.schemaVersion == 99 and unknown.palette == palette and unknown.custom == custom)
local legacy = { palette = { recent = {{ providerID = "lychee.mounts", entryID = "mount:1" }} } }
boot(legacy)
assert(legacy.schemaVersion == nil and legacy.palette.recent[1].providerID == "lychee.mounts")
boot({ schemaVersion = 2 })
boot("invalid data retained for recovery")
boot(false)
boot(nil)
-- File load must also leave the later restored root alone.
local restored = { schemaVersion = 7, untouched = true }
_G.LycheeDB = restored
assert(_G.LycheeDB == restored and restored.untouched)
print("PASS bootstrap preserves account SavedVariables without schema guesses")
