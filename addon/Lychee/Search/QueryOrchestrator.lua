local I = _G.LycheeInternal
local Q = { active = false, last = nil, pending = nil, timer = nil, timerToken = 0, limit = 20, debounceSeconds = 0.04 }
I.Search.Query = Q
local EMPTY = {} -- private read-only empty view

local function resultLess(left, right)
    local lc, rc = left.confidence or 0, right.confidence or 0
    if lc ~= rc then return lc > rc end
    local lp = left.sourcePriority or 0
    local rp = right.sourcePriority or 0
    if lp ~= rp then return lp > rp end
    local lco, rco = left.categoryOrder or 0, right.categoryOrder or 0
    if lco ~= rco then return lco < rco end
    return tostring(left.stableID or left._ext or "") .. ":" .. tostring(left.id or "") < tostring(right.stableID or right._ext or "") .. ":" .. tostring(right.id or "")
end

local function appendUnique(out, seen, item)
    if type(item) ~= "table" then return false end
    local canonical = item.stableID or (item.searchRecord and item.searchRecord.id) or item.id or item.key
    local key
    if item.searchRecord then key = "record:" .. tostring(item._ext or item.sourceID or "") .. ":" .. tostring(item.id)
    else key = tostring(item._ext or "") .. ":" .. tostring(canonical or item.text or #out + 1) end
    if seen[key] then return false end
    seen[key] = true; out[#out + 1] = item
    return true
end

function Q:_ResolveGeneration(externalGeneration, context)
    if type(externalGeneration) == "number" then return externalGeneration end
    if context and type(context.generation) == "number" then return context.generation end
    local session = I.Search and I.Search.Session
    return session and session.generation or 0
end

-- Resolve saved identities without running a fuzzy query or changing the active
-- search generation. Materialization stays identical to normal search results.
function Q:ResolveRecent(refs, limit)
    local out = {}
    for index = 1, #refs do
        local item = I.Providers and I.Providers:Resolve(refs[index], I.Context and I.Context:Snapshot() or {})
        if item then out[#out + 1] = item end
        if #out >= (limit or 5) then break end
    end
    return out
end

function Q:_BuildRequest(raw, context, generation)
    local text, filter = tostring(raw or ""), context and context.searchFilter
    if I.Search.ProviderPolicy then
        text,filter=I.Search.ProviderPolicy:Route(text,filter)
    end
    local normalized = I.Search.Normalizer:Normalize(text)
    return { generation = generation, raw = text, normalized = normalized, preferenceKey=I.Search.Normalizer:Normalize(raw),
        tokens = I.Search.Normalizer:Terms(normalized), limit = self.limit,
        contextToken = context and context.token, session = context and context.session,
        visible = context and context.visible, filter = filter }
end


function Q:_IsCurrent(generation, context)
    if context and context.visible == false then return false, "HIDDEN" end
    if context and context.generation and context.generation ~= generation then return false, "STALE_CONTEXT" end
    local session = I.Search and I.Search.Session
    if session and context and context.session then
        return session:IsCurrent(context.session, generation)
    end
    return true
end

function Q:_Execute(raw, context, generation, request)
    request = request or self:_BuildRequest(raw, context, generation)
    local filtered = type(request.filter) == "table" and (request.filter.sourceID or request.filter.categoryID)
    local out, seen = {}, filtered and EMPTY or {}
    request.limit = self.limit
    if I.Search.Personalization then I.Search.Personalization:AddAliases(out,request,context) end
    table.sort(out, resultLess)
    if I.Search.Personalization then I.Search.Personalization:Promote(out,request) end
    while #out > self.limit do out[#out] = nil end
    return out
end

function Q:_Commit(generation, results, pending)
    self.last = { generation = generation, results = results, pending = pending == true }
    return true
end

function Q:_CancelTimer()
    local timer = self.timer
    self.timer = nil
    self.timerToken = self.timerToken + 1
    if timer and type(timer.Cancel) == "function" then pcall(timer.Cancel, timer) end
end

-- Detach old Host work before invoking Provider cancellation. Cancellation is
-- external code and may start a newer operation, even within one generation.
function Q:_BeginOperation()
    self.operation = (self.operation or 0) + 1
    local operation = self.operation
    self.pending, self.active = nil, false
    self:_CancelTimer()
    return operation
end

function Q:Query(raw, context, externalGeneration, callback)
    local generation = self:_ResolveGeneration(externalGeneration, context)
    local operation = self:_BeginOperation()
    if I.Providers then I.Providers:CancelQueries("query-replaced") end
    if self.operation ~= operation then return generation, {} end
    local current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    self.active = true
    local request=self:_BuildRequest(raw,context,generation)
    if request.normalized == "" and not (request.filter and (request.filter.sourceID or request.filter.categoryID)) then
        self.active=false
        local results={}
        self:_Commit(generation,results)
        return generation,results,operation,false
    end
    local results, pending = {}, false
    if self.operation ~= operation then return generation, {} end
    if I.Providers and (not I.Providers.HasQuery or I.Providers:HasQuery(request.filter)) then
        local publication = 0
        local function merge(dynamic)
            local combined, seen = {}, {}
            local aliases=self:_Execute(raw,context,generation,request)
            for _, item in ipairs(aliases) do appendUnique(combined, seen, item) end
            for _, item in ipairs(dynamic) do appendUnique(combined, seen, item) end
            table.sort(combined, resultLess)
            if I.Search.Personalization then I.Search.Personalization:Promote(combined,request) end
            while #combined > self.limit do combined[#combined] = nil end
            return combined
        end
        local dynamic, waiting = I.Providers:Search(request, context, function(items, waiting)
            if self.operation ~= operation or not self:_IsCurrent(generation, context) then return end
            publication = publication + 1
            local revision = publication
            local combined = merge(items)
            -- Alias resolution may call external code and publish newer results.
            if self.operation ~= operation or publication ~= revision or not self:_IsCurrent(generation, context) then return end
            self:_Commit(generation, combined, waiting)
            if callback then callback(combined, generation, waiting) end
        end)
        local revision = publication
        results = merge(dynamic)
        pending = waiting == true
        if self.operation == operation and publication ~= revision then
            results, pending = self.last.results, self.last.pending
        end
    end
    if self.operation ~= operation then return generation, {} end
    self.active = false
    current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    if not self:_Commit(generation, results, pending) then return generation, {} end
    return generation, results, operation, pending
end

function Q:Schedule(raw, context, externalGeneration, callback, delay)
    local generation = self:_ResolveGeneration(externalGeneration, context)
    local operation = self:_BeginOperation()
    if I.Providers then I.Providers:CancelQueries("input-changed") end
    if self.operation ~= operation then return generation, false end
    self.pending = { raw = raw, context = context, generation = generation, callback = callback }
    local wait = delay
    if wait == nil then wait = self.debounceSeconds end
    local timerToken = self.timerToken
    if wait <= 0 then
        self:Flush(generation)
    elseif C_Timer and type(C_Timer.NewTimer) == "function" then
        local timer
        timer = C_Timer.NewTimer(wait, function()
            if self.timerToken ~= timerToken or self.timer ~= timer then return end
            self.timer = nil
            self:Flush(generation)
        end)
        self.timer = timer
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(wait, function()
            if self.timerToken == timerToken then self:Flush(generation) end
        end)
    end
    return generation, true
end

function Q:Flush(expectedGeneration)
    local pending = self.pending
    if not pending or (expectedGeneration and pending.generation ~= expectedGeneration) then return false end
    self:_CancelTimer()
    self.pending = nil
    local generation, results, operation, waiting = self:Query(pending.raw, pending.context, pending.generation, pending.callback)
    if operation and self.operation == operation and type(pending.callback) == "function" then pending.callback(results, generation, waiting) end
    return true, generation, results
end

function Q:Cancel(reason, generation)
    local operation = self:_BeginOperation()
    self.last = { generation = generation, results = {}, cancelled = reason or "INVALIDATED" }
    if I.Providers then I.Providers:CancelQueries(reason) end
    return self.operation == operation
end
