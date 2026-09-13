local Fixture=dofile("tests/support/provider_fixture.lua")
-- SearchSession owns session/generation and rejects stale asynchronous work.
_G = _G or {}
function GetBuildInfo() return "12.1.0","69587","",120100 end
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

local root = "addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"Search/SearchSession.lua"})
local I = LycheeInternal
local source=assert(Fixture:Register({id="session-fixture",apiVersion="1.0.0",version="1",title="Session",catalog={
    {id="old",title="旧查询"},{id="new",title="新查询"}
}}))
I.Registry:SetReady(true)

local accepted = {}
local palette = { visible = true }
function palette:ApplySearchState(session, generation, pending, results)
    self.session, self.generation, self.searchPending = session, generation, pending
    if not results then return true end
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
assert(palette.searchPending==true,"pending empty results retain the window geometry")
local oldTimer = timers[#timers]
local oldGeneration = session.generation
assert(#accepted == 1 and #accepted[1].results == 0 and accepted[1].generation == oldGeneration,
    "input must clear stale results before debounce")
assert(session:Input("新查询"))
local newTimer = timers[#timers]
local newGeneration = session.generation
assert(oldTimer.cancelled == true and newGeneration > oldGeneration)
assert(#accepted == 2 and #accepted[2].results == 0 and accepted[2].generation == newGeneration,
    "replacement input must clear the previous generation immediately")

oldTimer.callback()
assert(#accepted == 2, "cancelled input must not publish after its immediate clear")
newTimer.callback()
assert(palette.searchPending==false,"completed search releases pending presentation state")
assert(#accepted == 3 and accepted[3].generation == newGeneration)
assert(#accepted[3].results >= 1 and accepted[3].results[1].id == "new")

local beforeSourceInvalidation = session.generation
assert(source:Invalidate("fixture-refresh"))
assert(session.generation > beforeSourceInvalidation, "source changes must invalidate the active session")
assert(#accepted == 3, "source changes retain the current display until the coalesced replacement")
local sourceTimer = timers[#timers]
assert(source:Invalidate("second-refresh"))
assert(timers[#timers] == sourceTimer, "same-frame source updates use one refresh")
sourceTimer.callback()
assert(#accepted == 4 and #accepted[4].results > 0, "source refresh reruns the current search without an empty flash")

assert(session:Input("旧查询"))
local hiddenTimer = timers[#timers]
local hiddenGeneration = session.generation
session:Stop("hidden")
palette.visible = false
assert(hiddenTimer.cancelled == true and session.generation > hiddenGeneration)
hiddenTimer.callback()
assert(#accepted == 5, "hidden session must reject late callback")

palette.visible = true
local resumedSession = session:Start()
assert(resumedSession > firstSession)
assert(session:Input("新查询"))
local invalidatedTimer = timers[#timers]
session:Invalidate("source-invalidated")
local acceptedAfterInvalidation = #accepted
invalidatedTimer.callback()
assert(#accepted == acceptedAfterInvalidation, "invalidated generation must reject late callback")

assert(session:Input("旧查询"))
local pendingBeforeFilter = timers[#timers]
local beforeFilter = #accepted
local filtered, filterGeneration = session:Filter({ sourceID = "session-fixture:records" })
assert(filtered and filterGeneration == session.generation, "filter request must use the active generation")
assert(pendingBeforeFilter.cancelled == true, "filter request must cancel pending text debounce")
assert(#accepted == beforeFilter + 2, "filter must clear then publish through the session owner")
assert(#accepted[#accepted - 1].results == 0 and #accepted[#accepted].results == 2,
    "source filter must publish only indexed source records")
pendingBeforeFilter.callback()
assert(#accepted == beforeFilter + 2, "cancelled text debounce must not publish after filter activation")

_G.__combat = true
local combatOK, combatErr = session:Input("新查询")
assert(combatOK == false and combatErr == "COMBAT_LOCKED")

print("Lychee search session smoke PASS")

_G.__combat=false
local delayedReply
local delayed=assert(Fixture:Register({id="session.delayed",apiVersion="1.0.0",version="1",title="Delayed",
    query=function(_, reply) delayedReply=reply end}))
assert(session:Input("wait"))
I.Search.Query:Flush()
assert(palette.searchPending,"real delayed Provider keeps the publication pending")
assert(delayedReply({}))
assert(not palette.searchPending,"terminal reply carries completion with its results")
assert(delayed:Unregister())
print("Async pending state PASS")
