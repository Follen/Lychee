local I = _G.LycheeInternal
local Q = { active = false, last = nil, pending = nil, timer = nil, timerToken = 0, limit = 20, debounceSeconds = 0.04 }
I.Search.Query = Q
local EMPTY = {} -- private read-only empty view

local function resultLess(left, right)
    local lc, rc = left._preferenceRank or left.confidence or 0, right._preferenceRank or right.confidence or 0
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
    if item.ref and item.ref.kind then key = I.Search.RuntimeIdentity:ReferenceKey(item.ref)
    elseif item.searchRecord then key = "record:" .. tostring(item._ext or item.sourceID or "") .. ":" .. tostring(item.id)
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

function Q:_BuildRequest(raw, context, generation)
    local text, filter, rawOffset = tostring(raw or ""), context and context.searchFilter, 0
    if I.Search.ProviderPolicy then
        text,filter,rawOffset=I.Search.ProviderPolicy:Route(text,filter)
    else
    -- Fixed aliases select an existing source; ordinary text takes no parser
    -- allocation and unknown prefixes retain their original search meaning.
    local first,last=text:find(":",1,true)
    local wide,wideLast=text:find("：",1,true)
    if wide and (not first or wide<first) then first,last=wide,wideLast end
    if first then
        local prefix=I.Search.Normalizer:Normalize(text:sub(1,first-1))
        local source=self.categoryPrefixes and self.categoryPrefixes[prefix]
        if source then text=text:sub(last+1); filter={sourceID=source..":records"} end
    end
    end
    local normalized = I.Search.Normalizer:Normalize(text)
    local request = { generation = generation, raw = text, originalRaw=tostring(raw or ""), rawOffset=rawOffset, normalized = normalized, preferenceKey=I.Search.Normalizer:Normalize(raw),
        tokens = I.Search.Normalizer:Terms(normalized), limit = self.limit,
        contextToken = context and context.token, session = context and context.session,
        visible = context and context.visible, filter = filter }
    if I.Search.Personalization then request._preferences=I.Search.Personalization:Snapshot(request) end
    return request
end

Q.categoryPrefixes={
    ["技能"]="builtin.player-spells",spell="builtin.player-spells",spells="builtin.player-spells",
    ["坐骑"]="builtin.mounts",mounts="builtin.mounts",
    ["背包"]="builtin.bags",["物品"]="builtin.bags",bags="builtin.bags",
    ["天赋"]="builtin.talent-loadouts",["天赋方案"]="builtin.talent-loadouts",talents="builtin.talent-loadouts",
    ["装备"]="builtin.equipment-sets",["装备方案"]="builtin.equipment-sets",gear="builtin.equipment-sets",
    ["设置"]="builtin.blizzard-settings",["暴雪设置"]="builtin.blizzard-settings",settings="builtin.blizzard-settings",
    ["钥匙"]="builtin.keystones",key="builtin.keystones",keys="builtin.keystones",
    ["成就"]="builtin.achievements",achievement="builtin.achievements",achievements="builtin.achievements",
    ["团本首领"]="builtin.bosses",["首领"]="builtin.bosses",bosses="builtin.bosses",["菜单"]="builtin.game-menus",
    ["玩家技能"]="builtin.player-spells",["背包物品"]="builtin.bags",["队伍钥匙"]="builtin.keystones",
    ["游戏菜单"]="builtin.game-menus",["纹章"]="builtin.crests",["宏伟宝库"]="builtin.great-vault",["宝库"]="builtin.great-vault",
}

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
    if I.Search and I.Search.StaticIndex then
        local preferred=I.Search.Personalization and I.Search.Personalization:Preferred(request)
        local preferredKey=preferred and (not preferred.kind or preferred.kind=="legacy-entry") and preferred.entryID and (preferred.providerID..":records:"..preferred.entryID)
        local indexed = I.Search.StaticIndex:Search(request.normalized, self.limit, request.filter, true, preferredKey, request._preferences and request._preferences.indexRanking)
        for index = 1, #indexed do
            local item = I.Search.ResultSnapshot:Materialize(indexed[index])
            if item and I.Providers then I.Providers:Stamp(item) end
            if item then
                if filtered then out[#out+1]=item -- index already guarantees unique static records
                else appendUnique(out, seen, item) end
            end
        end
    end
    request.limit = self.limit
    if I.Search.Personalization then I.Search.Personalization:AddAliases(out,request,context) end
    if I.Search.Personalization then for _,item in ipairs(out) do item._preferenceRank=I.Search.Personalization:Rank(request,item.ref,item.confidence) end end
    table.sort(out, resultLess)
    if I.Search.Personalization then I.Search.Personalization:Promote(out,request) end
    while #out > self.limit do out[#out] = nil end
    return out
end

function Q:_Commit(generation, results)
    self.last = { generation = generation, results = results, incomplete=I.Providers and I.Providers.HasQueryFailure and I.Providers:HasQueryFailure() or false }
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
function Q:_BeginOperation(keepAccess)
    if I.Providers then I.Providers.materializationFailed=nil end
    self.operation = (self.operation or 0) + 1
    local operation = self.operation
    self.pending, self.active = nil, false
    self:_CancelTimer()
    if self.operation ~= operation then return operation end
    if not keepAccess and I.Search.SourceAccess then I.Search.SourceAccess:Cancel() end
    if self.operation ~= operation then return operation end
    if I.Invocations then I.Invocations:CancelSearch("query-replaced") end
    return operation
end

function Q:Query(raw, context, externalGeneration, callback, keepAccess)
    context=context or {}
    if not context.deadline then
        local owned={};for key,value in pairs(context) do owned[key]=value end
        owned.deadline=(I.Providers and I.Providers:QueryTime() or GetTime and GetTime() or 0)+5;context=owned
    end
    local generation = self:_ResolveGeneration(externalGeneration, context)
    local operation = self:_BeginOperation(keepAccess)
    if self.operation ~= operation then return generation, {} end
    if I.Providers then I.Providers:CancelQueries("query-replaced") end
    if self.operation ~= operation then return generation, {} end
    local current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    self.active = true
    if I.Search.SourceAccess and raw~="" and not keepAccess then
        local accessOperation=operation
        I.Search.SourceAccess:Begin(raw,context,function()
            if self.operation~=accessOperation or not self:_IsCurrent(generation,context) then return end
            local gen,items,op,pending,partial=self:Query(raw,context,generation,callback,true)
            if op and op==self.operation then
                accessOperation=op
                if callback then callback(items,gen,pending,partial) end
            end
        end)
    end
    if self.operation ~= operation then return generation, {} end
    local request=self:_BuildRequest(raw,context,generation)
    if request.normalized == "" and not (request.filter and (request.filter.sourceID or request.filter.categoryID)) then
        self.active=false
        local results={}
        self:_Commit(generation,results)
        return generation,results,operation
    end
    local results = self:_Execute(raw, context, generation, request)
    if self.operation ~= operation then return generation, {} end
    if I.Providers and raw ~= "" and (not I.Providers.HasQuery or I.Providers:HasQuery(request.filter)) then
        local base = results
        local function merge(dynamic, replacements)
            if #dynamic==0 and not next(replacements or EMPTY) then return base end
            local combined, seen = {}, {}
            for _, item in ipairs(base) do
                if not (replacements and replacements[item.providerID or item._ext]) then appendUnique(combined,seen,item) end
            end
            for _, item in ipairs(dynamic) do appendUnique(combined, seen, item) end
            if I.Search.Personalization then for _,item in ipairs(combined) do item._preferenceRank=I.Search.Personalization:Rank(request,item.ref,item.confidence) end end
            table.sort(combined, resultLess)
            if I.Search.Personalization then I.Search.Personalization:Promote(combined,request) end
            while #combined > self.limit do combined[#combined] = nil end
            return combined
        end
        local dynamic, replacements = I.Providers:Search(request, context, function(items, replaced)
            if self.operation ~= operation or not self:_IsCurrent(generation, context) then return end
            local combined = merge(items, replaced)
            self:_Commit(generation, combined)
            if callback then callback(combined, generation,I.Providers:HasPendingQuery(),I.Providers:HasQueryFailure()) end
        end)
        results = merge(dynamic, replacements)
    end
    if self.operation ~= operation then return generation, {} end
    self.active = false
    current, reason = self:_IsCurrent(generation, context)
    if not current then self.last = { generation = generation, results = {}, cancelled = reason }; return generation, {} end
    if not self:_Commit(generation, results) then return generation, {} end
    return generation, results, operation, I.Providers and I.Providers:HasPendingQuery() or false, I.Providers and I.Providers.HasQueryFailure and I.Providers:HasQueryFailure() or false
end

function Q:Schedule(raw, context, externalGeneration, callback, delay)
    local generation = self:_ResolveGeneration(externalGeneration, context)
    local operation = self:_BeginOperation()
    if self.operation ~= operation then return generation, false end
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
    local generation, results, operation, waiting, partial = self:Query(pending.raw, pending.context, pending.generation, pending.callback)
    if operation and self.operation == operation and type(pending.callback) == "function" then pending.callback(results, generation, waiting, partial) end
    return true, generation, results
end

function Q:Cancel(reason, generation)
    local operation = self:_BeginOperation()
    if self.operation ~= operation then return true end
    if I.Search.StaticIndex and I.Search.StaticIndex.ClearQueryCache then I.Search.StaticIndex:ClearQueryCache() end
    self.last = { generation = generation, results = {}, cancelled = reason or "INVALIDATED" }
    if I.Providers then I.Providers:CancelQueries(reason) end
    return true
end
