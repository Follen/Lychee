-- SearchSession owns session/generation and rejects stale asynchronous work.
_G = _G or {}
function GetLocale() return "zhCN" end
function InCombatLockdown() return _G.__combat == true end

local timers = {}
C_Timer = {
    NewTimer = function(_, callback)
        local timer = { callback = callback, cancelled = false }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

local root = "package/Lychee/"
for _, file in ipairs({
    "Bootstrap.lua",
    "Core/ContextStore.lua",
    "Search/Normalizer.lua",
    "Search/StaticIndex.lua",
    "Core/CommandCatalog.lua",
    "Search/QueryOrchestrator.lua",
    "Search/SearchSession.lua",
}) do
    dofile(root .. file)
end

local I = _G.LycheeInternal
assert(I.Search.StaticIndex:RegisterSource({ id = "session-fixture", priority = 10 }))
assert(I.Search.StaticIndex:CommitSnapshot("session-fixture", {
    { id = "old", kind = "fixture", title = "旧查询" },
    { id = "new", kind = "fixture", title = "新查询" },
}, 1))

local accepted = {}
local palette = { visible = true }
function palette:ApplyResults(results, generation, session)
    accepted[#accepted + 1] = {
        results = results,
        generation = generation,
        session = session,
    }
    return true
end

local session = I.Search.Session
assert(session:BindPalette(palette))
local firstSession, initialGeneration = session:Start()
assert(firstSession > 0 and initialGeneration > 0)

assert(session:Input("旧查询"))
local oldTimer = timers[#timers]
local oldGeneration = session.generation
assert(session:Input("新查询"))
local newTimer = timers[#timers]
local newGeneration = session.generation
assert(oldTimer.cancelled == true and newGeneration > oldGeneration)

oldTimer.callback()
assert(#accepted == 0, "cancelled input must not publish")
newTimer.callback()
assert(#accepted == 1 and accepted[1].generation == newGeneration)
assert(#accepted[1].results >= 1 and accepted[1].results[1].id == "new")

local beforeSourceInvalidation = session.generation
assert(I.Search.StaticIndex:Invalidate("session-fixture", "fixture-refresh"))
assert(session.generation > beforeSourceInvalidation, "source changes must invalidate the active session")
assert(#accepted == 2 and #accepted[2].results == 0, "source changes must clear visible stale results")

assert(session:Input("旧查询"))
local hiddenTimer = timers[#timers]
local hiddenGeneration = session.generation
session:Stop("hidden")
palette.visible = false
assert(hiddenTimer.cancelled == true and session.generation > hiddenGeneration)
hiddenTimer.callback()
assert(#accepted == 2, "hidden session must reject late callback")

palette.visible = true
local resumedSession = session:Start()
assert(resumedSession > firstSession)
assert(session:Input("新查询"))
local invalidatedTimer = timers[#timers]
session:Invalidate("source-invalidated")
local acceptedAfterInvalidation = #accepted
invalidatedTimer.callback()
assert(#accepted == acceptedAfterInvalidation, "invalidated generation must reject late callback")

_G.__combat = true
local combatOK, combatErr = session:Input("新查询")
assert(combatOK == false and combatErr == "COMBAT_LOCKED")

print("Lychee search session smoke PASS")
