local carrier = {}; assert(loadfile("tools/performance-test/NativeCalls.lua"))("fixture", carrier)
local originalMixin = ColorMixin; ColorMixin = {}
-- Models native raw lookup, not an assertion about undocumented engine internals.
local function nativeColor(value)
    if rawget(getfenv(2), "ColorMixin") == nil then error("unable to find mixin or metatable (ColorMixin)") end
    return {r = 1, g = 0.5, b = 0.25}, nil, value
end
local originalClass, originalChallenge = C_ClassColor, C_ChallengeMode
C_ClassColor = {GetClassColor = nativeColor}
C_ChallengeMode = {GetDungeonScoreRarityColor = nativeColor, GetSpecificDungeonScoreRarityColor = nativeColor}
local env = setmetatable({}, {__index = _G}); env._G = env
local report = {}
assert(carrier.PrepareNativeCalls(env, report))
for _, item in pairs(report.nativeCalls.samples) do
    assert(item.real.ok and not item.inherited.ok and item.explicitMixin.ok and item.bridged.ok and item.matchesReal)
end
assert(C_ClassColor.GetClassColor == nativeColor and C_ChallengeMode.GetDungeonScoreRarityColor == nativeColor)
local function invoke(fn) local a, b, c = fn(27); return a, b, c end
setfenv(invoke, env)
local color, hole, value = invoke(env.C_ClassColor.GetClassColor)
assert(color.r == 1 and hole == nil and value == 27, "bridge changed native return values")
local failures = {}
local broken = carrier.BridgeNativeCall(function() error("native sentinel") end, "fixture.failure", failures)
assert(not pcall(broken) and #failures == 1 and failures[1].api == "fixture.failure")
for n = 1, 30 do pcall(broken) end
assert(#failures == 16, "failure buffer unbounded")
ColorMixin = originalMixin; C_ClassColor = originalClass; C_ChallengeMode = originalChallenge
print("Native bridge: inherited raw lookup fails / real-environment bridge succeeds / return values and globals preserved / bounded errors PASS (simulation; client comparison pending)")
