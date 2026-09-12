local I = _G.LycheeInternal
local definitions = I.Builtin.Definitions
local byID = {}
for _, definition in ipairs(definitions) do byID[definition.id] = definition end
local S = {}
I.Builtin.Support = S

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
