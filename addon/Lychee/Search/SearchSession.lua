local I = _G.LycheeInternal

local Session = {
    session = 0,
    generation = 0,
    visible = false,
}
I.Search.Session = Session

local function contextSnapshot(session, generation, filter)
    local source = I.Context and I.Context:Snapshot() or {}
    local context = {}
    for key, value in pairs(source) do context[key] = value end
    context.session = session
    context.generation = generation
    context.visible = true
    if type(filter) == "table" then
        context.searchFilter = { categoryID = filter.categoryID, sourceID = filter.sourceID }
    end
    return context
end

-- One delivery owns identity, progress and optional results. Identity-only
-- transitions invalidate old actions without repainting the current page.
function Session:_Publish(results, pending)
    self.pending = pending == true
    local palette = self.palette
    if not palette then return false end
    return palette:ApplySearchState(self.session, self.generation, self.pending, results)
end

function Session:BindPalette(palette)
    if not palette then return false end
    self.palette = palette
    self:_Publish(nil, self.pending)
    return true
end

function Session:Start()
    if self.visible then return self.session, self.generation end
    self.visible = true
    self.session = self.session + 1
    self.generation = self.generation + 1
    self:_Publish(nil, false)
    return self.session, self.generation
end

function Session:Invalidate(reason)
    self:CancelSourceRefresh()
    local query = I.Search.Query
    self.generation = self.generation + 1
    local session, generation = self.session, self.generation
    if query and type(query.Cancel) == "function" and not query:Cancel(reason, generation) then return self.generation end
    if session ~= self.session or generation ~= self.generation then return self.generation end
    self.lastInvalidation = reason
    local palette = self.palette
    self:_Publish(self.visible and palette and palette.visible and {} or nil, false)
    return self.generation
end

function Session:Stop(reason)
    if not self.visible then
        if I.Search.Query and (I.Search.Query.pending or I.Search.Query.timer) then self:Invalidate(reason or "hidden") end
        return self.session, self.generation
    end
    self.visible = false
    self.session = self.session + 1
    self:Invalidate(reason or "hidden")
    return self.session, self.generation
end

function Session:IsCurrent(session, generation)
    if not self.visible then return false, "STALE_GENERATION" end
    if session and session ~= self.session then return false, "STALE_GENERATION" end
    if generation and generation ~= self.generation then return false, "STALE_GENERATION" end
    return true
end

function Session:_Accept(results, generation, session, pending)
    local current = self:IsCurrent(session, generation)
    if not current then return false end
    local palette = self.palette
    if not palette or not palette.visible then return false end
    return self:_Publish(results, pending)
end

function Session:Input(raw)
    if not self.visible then return false, "HIDDEN" end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    local query = I.Search.Query
    if not query then return false, "SEARCH_UNAVAILABLE" end
    self:CancelSourceRefresh()
    self.raw = raw or ""

    local session = self.session
    local generation = self.generation + 1
    self.generation = generation
    self.activeFilter = nil
    self:_Accept({}, generation, session, true)
    local context = contextSnapshot(session, generation)

    if C_Timer and (type(C_Timer.NewTimer) == "function" or type(C_Timer.After) == "function") then
        local scheduledGeneration, scheduled = query:Schedule(raw, context, generation, function(results, completedGeneration, pending)
            self:_Accept(results, completedGeneration, session, pending)
        end)
        return scheduled, scheduledGeneration
    end

    local completedGeneration, results, operation, pending = query:Query(raw, context, generation, function(items, completed, waiting)
        self:_Accept(items, completed, session, waiting)
    end)
    if operation then self:_Accept(results, completedGeneration, session, pending) end
    return true, completedGeneration
end

function Session:Filter(filter)
    if not self.visible then return false, "HIDDEN" end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if type(filter) ~= "table" or (not filter.categoryID and not filter.sourceID) then return false, "INVALID_FILTER" end
    local query = I.Search.Query
    if not query then return false, "SEARCH_UNAVAILABLE" end
    self:CancelSourceRefresh()
    self.raw = ""

    local session = self.session
    local generation = self.generation + 1
    self.generation = generation
    self.activeFilter = { categoryID = filter.categoryID, sourceID = filter.sourceID }
    if type(query.Cancel) == "function" and not query:Cancel("filter-change", generation) then return false, "STALE_GENERATION" end
    if not self:IsCurrent(session, generation) then return false, "STALE_GENERATION" end
    self:_Accept({}, generation, session, true)
    local context = contextSnapshot(session, generation, self.activeFilter)
    local completedGeneration, results, operation, pending = query:Query("", context, generation, function(items, completed, waiting)
        self:_Accept(items, completed, session, waiting)
    end)
    if operation then self:_Accept(results, completedGeneration, session, pending) end
    return true, completedGeneration
end

function Session:CancelSourceRefresh()
    if self.sourceRefreshTimer then self.sourceRefreshTimer:Cancel(); self.sourceRefreshTimer = nil end
    self.sourceRefreshPending = nil
end

function Session:RefreshSource()
    if not self.sourceRefreshPending then return false end
    self.sourceRefreshPending = nil
    if not self.visible or not self.palette or not self.palette.visible or (InCombatLockdown and InCombatLockdown()) then return false end
    local currentSession, generation = self.session, self.generation
    local context = contextSnapshot(currentSession, generation, self.activeFilter)
    local token, results, operation, pending = I.Search.Query:Query(self.raw or "", context, generation, function(items, completed, waiting)
        self:_Accept(items, completed, currentSession, waiting)
    end)
    return operation and self:_Accept(results, token, currentSession, pending) or false
end

function Session:SourceChanged(reason)
    local palette = self.palette
    self.generation = self.generation + 1
    if I.Search.Query and not I.Search.Query:Cancel("source-" .. tostring(reason or "changed"), self.generation) then
        if palette and palette.MarkHomeDirty then palette:MarkHomeDirty() end
        return
    end
    self:_Publish(nil, self.pending)
    if palette and type(palette.MarkHomeDirty) == "function" then palette:MarkHomeDirty() end
    if not self.visible then return end
    self.sourceRefreshPending = true
    if not self.sourceRefreshTimer and C_Timer and C_Timer.NewTimer then
        local timer
        timer = C_Timer.NewTimer(0, function()
            if self.sourceRefreshTimer ~= timer then return end
            self.sourceRefreshTimer = nil
            self:RefreshSource()
        end)
        self.sourceRefreshTimer = timer
    end
end
