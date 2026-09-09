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

function Session:_SyncPalette()
    local palette = self.palette
    if not palette then return end
    palette.session = self.session
    palette.generation = self.generation
end

function Session:BindPalette(palette)
    if not palette then return false end
    self.palette = palette
    self:_SyncPalette()
    return true
end

function Session:Start()
    if self.visible then return self.session, self.generation end
    self.visible = true
    self.session = self.session + 1
    self.generation = self.generation + 1
    self:_SyncPalette()
    return self.session, self.generation
end

function Session:Invalidate(reason)
    self:CancelSourceRefresh()
    local query = I.Search.Query
    self.generation = self.generation + 1
    if query and type(query.Cancel) == "function" then query:Cancel(reason, self.generation) end
    self.lastInvalidation = reason
    self:_SyncPalette()
    local palette = self.palette
    if self.visible and palette and palette.visible and type(palette.ApplyResults) == "function" then
        palette:ApplyResults({}, self.generation, self.session)
    end
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

function Session:_Accept(results, generation, session)
    local current = self:IsCurrent(session, generation)
    if not current then return false end
    local palette = self.palette
    if not palette or not palette.visible or type(palette.ApplyResults) ~= "function" then return false end
    return palette:ApplyResults(results, generation, session)
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
    self:_SyncPalette()
    self:_Accept({}, generation, session)
    local context = contextSnapshot(session, generation)

    if C_Timer and (type(C_Timer.NewTimer) == "function" or type(C_Timer.After) == "function") then
        local scheduledGeneration, scheduled = query:Schedule(raw, context, generation, function(results, completedGeneration)
            self:_Accept(results, completedGeneration, session)
        end)
        return scheduled, scheduledGeneration
    end

    local completedGeneration, results = query:Query(raw, context, generation)
    self:_Accept(results, completedGeneration, session)
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
    self:_SyncPalette()
    if type(query.Cancel) == "function" then query:Cancel("filter-change", generation) end
    self:_Accept({}, generation, session)
    local context = contextSnapshot(session, generation, self.activeFilter)
    local completedGeneration, results = query:Query("", context, generation)
    self:_Accept(results, completedGeneration, session)
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
    local token, results = I.Search.Query:Query(self.raw or "", context, generation, function(items, completed)
        self:_Accept(items, completed, currentSession)
    end)
    return self:_Accept(results, token, currentSession)
end

function Session:SourceChanged(reason)
    local palette = self.palette
    if palette and type(palette.MarkHomeDirty) == "function" then palette:MarkHomeDirty() end
    self.generation = self.generation + 1
    if I.Search.Query then I.Search.Query:Cancel("source-" .. tostring(reason or "changed"), self.generation) end
    self:_SyncPalette()
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

if I.Search.StaticIndex and type(I.Search.StaticIndex.OnChange) == "function" then
    I.Search.StaticIndex:OnChange(function(_, reason) Session:SourceChanged(reason) end)
end
