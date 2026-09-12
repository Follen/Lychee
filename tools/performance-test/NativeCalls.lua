local _, carrier = ...
local G = _G
local function pack(...) return {n = select("#", ...), ...} end

-- Native APIs may resolve a named mixin in the immediate Lua caller's globals.
-- Keep this frame in the real environment; never tail-call the native function.
local function bridge(fn, name, failures)
    return function(...)
        local values = pack(pcall(fn, ...))
        if not values[1] then
            if #failures < 16 then
                failures[#failures + 1] = {api = name, error = tostring(values[2]):sub(1, 1200),
                    stack = G.debugstack and G.debugstack(2):sub(1, 2400) or "unavailable"}
            end
            error(values[2])
        end
        return unpack(values, 2, values.n)
    end
end
carrier.BridgeNativeCall = bridge

local function caller(env)
    local function invoke(fn, value)
        local result = fn(value)
        return result
    end
    setfenv(invoke, env)
    return invoke
end

local function sample(invoke, fn, argument)
    local ok, color = pcall(invoke, fn, argument)
    if not ok then return {ok = false, error = tostring(color):sub(1, 1200)} end
    local valid, rgb = pcall(function()
        assert(color and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number", "invalid color result")
        return {r = color.r, g = color.g, b = color.b}
    end)
    if not valid then return {ok = false, error = tostring(rgb):sub(1, 1200)} end
    return {ok = true, rgb = rgb}
end

function carrier.PrepareNativeCalls(env, report)
    local result = {status = "verified", samples = {}, failures = {},
        scope = "Three real color APIs: real globals, inherited globals, explicit mixin, and real-environment bridge; no fabricated colors"}
    report.nativeCalls = result
    local inherited = setmetatable({}, {__index = G}); inherited._G = inherited
    local explicit = setmetatable({ColorMixin = G.ColorMixin}, {__index = G}); explicit._G = explicit
    local realCaller, inheritedCaller, explicitCaller = caller(G), caller(inherited), caller(explicit)
    local copied = {}
    for _, spec in ipairs({{"C_ClassColor", "GetClassColor", "PALADIN"},
        {"C_ChallengeMode", "GetDungeonScoreRarityColor", 0},
        {"C_ChallengeMode", "GetSpecificDungeonScoreRarityColor", 0}}) do
        local namespace, key, argument = unpack(spec)
        local fn = G[namespace] and G[namespace][key]
        local name = namespace .. "." .. key
        if type(fn) ~= "function" then
            result.samples[name] = {missing = true}; result.status = "failed"
        else
            local wrapped = bridge(fn, name, result.failures)
            local item = {real = sample(realCaller, fn, argument), inherited = sample(inheritedCaller, fn, argument),
                explicitMixin = sample(explicitCaller, fn, argument), bridged = sample(inheritedCaller, wrapped, argument)}
            item.matchesReal = item.real.ok and item.bridged.ok
            if item.matchesReal then
                for _, channel in ipairs({"r", "g", "b"}) do
                    if item.real.rgb[channel] ~= item.bridged.rgb[channel] then item.matchesReal = false end
                end
            end
            result.samples[name] = item
            if not item.matchesReal then result.status = "failed" end
            if not copied[namespace] then
                local copy = {}; for k, v in pairs(env[namespace] or G[namespace]) do copy[k] = v end
                env[namespace] = copy; copied[namespace] = true
            end
            env[namespace][key] = wrapped
        end
    end
    return result.status == "verified"
end
