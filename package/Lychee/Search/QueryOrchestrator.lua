local I = _G.LycheeInternal
local Q = { generation = 0, active = false, last = nil, pending = nil, ambientEnabled = {}, limit = 20, catalogLimit = 8, ambientLimit = 12, debounceSeconds = 0.04 }
I.Search.Query = Q

local function resultLess(left, right)
    local lp, rp = left.command and left.command.priority or 0, right.command and right.command.priority or 0
    if lp ~= rp then return lp > rp end
    return (tostring(left._ext or "") .. ":" .. tostring(left.id or "")) < (tostring(right._ext or "") .. ":" .. tostring(right.id or ""))
end

local function appendUnique(out, seen, item, command)
    if type(item) ~= "table" then return false end
    if command then item._ext, item.command = command._ext, command end
    local key = tostring(item._ext or (item.command and item.command._ext) or "") .. ":" .. tostring(item.id or item.key or item.text or #out + 1)
    if seen[key] then return false end
    seen[key] = true; out[#out + 1] = item
    return true
end

function Q:_BeginGeneration(externalGeneration)
    local generation = externalGeneration or (self.generation + 1)
    if generation > self.generation then self.generation = generation end
    return generation
end

function Q:_BuildRequest(raw, context, generation)
    local normalized = I.Search.Normalizer:Normalize(raw)
    return { generation = generation, raw = raw or "", normalized = normalized, tokens = I.Search.Normalizer:Terms(normalized), limit = self.limit, contextToken = context and context.token }
end

function Q:_AmbientCommands(normalized)
    local commands = {}
    if normalized == "" or not I.Catalog then return commands end
    for key, command in pairs(I.Catalog.commands) do
        local match = command.match
        local minimum, maximum = match and match.minLength or 0, match and match.maxLength or math.huge
        if command._enabled ~= false and match and match.type == "ambient" and self.ambientEnabled[key] ~= false
            and #normalized >= minimum and #normalized <= maximum and type(command.resolve) == "function" then
            commands[#commands + 1] = command
        end
    end
    table.sort(commands, function(left, right)
        local lp, rp = left.priority or 0, right.priority or 0
        return lp > rp or (lp == rp and left._key < right._key)
    end)
    return commands
end

function Q:_Execute(raw, context, generation)
    local request = self:_BuildRequest(raw, context, generation)
    local catalogBudget, ambientBudget = math.min(self.catalogLimit, self.limit), math.min(self.ambientLimit, self.limit - math.min(self.catalogLimit, self.limit))
    local catalogResults = I.Catalog and I.Catalog:Query(request, catalogBudget) or {}
    local out, seen = {}, {}
    for index = 1, #catalogResults do appendUnique(out, seen, catalogResults[index]) end
    local ambientCommands, ambientAdded = self:_AmbientCommands(request.normalized), 0
    for commandIndex = 1, #ambientCommands do
        if ambientAdded >= ambientBudget or #out >= self.limit then break end
        request.limit = math.min(ambientBudget - ambientAdded, self.limit - #out)
        local ok, items = pcall(ambientCommands[commandIndex].resolve, request, context or {})
        if ok and type(items) == "table" then
            for itemIndex = 1, #items do
                if appendUnique(out, seen, items[itemIndex], ambientCommands[commandIndex]) then
                    ambientAdded = ambientAdded + 1
                    if ambientAdded >= ambientBudget or #out >= self.limit then break end
                end
            end
        end
    end
    request.limit = self.limit
    table.sort(out, resultLess)
    while #out > self.limit do out[#out] = nil end
    return out
end

function Q:_Commit(generation, results)
    if generation ~= self.generation then return false end
    self.last = { generation = generation, results = results }
    return true
end

function Q:Query(raw, context, externalGeneration)
    local generation = self:_BeginGeneration(externalGeneration)
    if externalGeneration and externalGeneration < self.generation then return generation, {} end
    self.active = true
    local results = self:_Execute(raw, context, generation)
    self.active = false
    if not self:_Commit(generation, results) then return generation, {} end
    return generation, results
end

function Q:Schedule(raw, context, externalGeneration, callback, delay)
    local generation = self:_BeginGeneration(externalGeneration)
    self.pending = { raw = raw, context = context, generation = generation, callback = callback }
    local wait = delay
    if wait == nil then wait = self.debounceSeconds end
    if wait <= 0 then self:Flush(generation)
    elseif C_Timer and type(C_Timer.After) == "function" then C_Timer.After(wait, function() self:Flush(generation) end) end
    return generation, true
end

function Q:Flush(expectedGeneration)
    local pending = self.pending
    if not pending or (expectedGeneration and pending.generation ~= expectedGeneration) or pending.generation ~= self.generation then return false end
    self.pending = nil
    local generation, results = self:Query(pending.raw, pending.context, pending.generation)
    if generation ~= self.generation then return false end
    if type(pending.callback) == "function" then pending.callback(results, generation) end
    return true, generation, results
end

function Q:Invalidate()
    self.generation, self.last, self.pending, self.active = self.generation + 1, nil, nil, false
end

function Q:SetAmbientEnabled(key, enabled) self.ambientEnabled[key] = enabled end
