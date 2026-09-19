local I = _G.LycheeInternal
local definitions = I.Builtin.Definitions
local byID = {}
for _, definition in ipairs(definitions) do byID[definition.id] = definition end
local S = {}
I.Builtin.Support = S
local dependencies = {
    ["builtin.ellesmere"]={addon="EllesmereUI",global="EllesmereUI"},
    ["builtin.exwind"]={addon="ExwindCore",global="ExwindTools"},
}
local detected = {} -- Two session-local booleans; never persist automatic defaults.

function S:DefaultSearchEnabled(id)
    local definition = byID[id]
    if definition and not I.Search.RuntimeIdentity:MatchesScope(definition.scope) then return false end
    local dependency = dependencies[id]
    if not dependency then return true end
    if detected[id] ~= nil then return detected[id] end
    if not C_AddOns or type(C_AddOns.GetAddOnInfo) ~= "function"
        or type(C_AddOns.GetAddOnEnableState) ~= "function" then
        return type(_G[dependency.global]) == "table"
    end
    local character = type(UnitGUID) == "function" and UnitGUID("player")
    if not character or character == "" then return false end
    local ok, name = pcall(C_AddOns.GetAddOnInfo, dependency.addon)
    if not ok then return false end
    if not name then detected[id]=false;return false end
    local enabled, state = pcall(C_AddOns.GetAddOnEnableState, dependency.addon, character)
    if not enabled or type(state) ~= "number" then return false end
    detected[id] = state > 0
    return detected[id]
end

function S:Scope(id)
    local definition = assert(byID[id], "Unknown built-in Provider: " .. tostring(id))
    return definition.scope
end

function S:Known(id)
    return byID[id] ~= nil
end

function S:Available(definition, product)
    local supported = false
    for _, candidate in ipairs(definition.scope.products) do
        if candidate == product then supported = true; break end
    end
    if not supported then return false end
    if I.Search.RuntimeIdentity:Current().product == product
        and not I.Search.RuntimeIdentity:MatchesScope(definition.scope) then return false end
    -- Evaluated only during startup, before business frames/events/tasks exist.
    for _, symbol in ipairs(definition.requires) do
        local value = _G
        for part in symbol:gmatch("[^.]+") do
            value = type(value) == "table" and value[part] or nil
        end
        if type(value) ~= "function" then return false end
    end
    return true
end
