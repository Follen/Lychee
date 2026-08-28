local I = _G.LycheeInternal

local Session = {
    session = 0,
    generation = 0,
    visible = false,
}
I.Search.Session = Session

local function contextSnapshot(session, generation)
    local source = I.Context and I.Context:Snapshot() or {}
    local context = {}
    for key, value in pairs(source) do context[key] = value end
    context.session = session
    context.generation = generation
    context.visible = true
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

    local session = self.session
    local generation = self.generation + 1
    self.generation = generation
    self:_SyncPalette()
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

if I.Search.StaticIndex and type(I.Search.StaticIndex.OnChange) == "function" then
    I.Search.StaticIndex:OnChange(function(_, reason)
        Session:Invalidate("source-" .. tostring(reason or "changed"))
    end)
end
