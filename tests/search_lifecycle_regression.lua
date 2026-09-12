local Fixture=dofile("tests/support/provider_fixture.lua")
-- Real Host lifecycle; only game APIs and timer delivery are substituted.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "12345", "fixture", 120100 end
function InCombatLockdown() return false end
function CreateFrame() return { RegisterEvent=function() end, SetScript=function() end, Hide=function() end, Show=function() end } end
UIParent = {}
local timers = {}
C_Timer = { NewTimer=function(seconds, callback)
    local timer = { seconds=seconds, callback=callback }
    function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer
    return timer
end }
dofile("tests/support/runtime.lua").Load("provider", {"Search/ProviderPolicy.lua", "Core/Scheduler.lua", "Search/SearchSession.lua"})
local I = LycheeInternal
local Q, S = I.Search.Query, I.Search.Session
I.Registry:SetReady(true)
local palette = {visible=true, applied=0}
function palette:ApplyResults(items)
    self.items, self.applied=items, self.applied+1
    return true
end
S:BindPalette(palette)
S:Start()
local function register(id, query)
    return assert(Fixture:Register({id=id, apiVersion=3, version="1", title=id, query=query}))
end
local function fire(timer)
    assert(timer and not timer.cancelled, "expected a live timer")
    timer.fired=true
    timer.callback()
end
local function input(text)
    assert(S:Input(text))
    fire(Q.timer)
end
local function idle()
    assert(not I.Providers:HasPendingQuery(), "terminal query leaves no Provider jobs")
    assert(not Q.pending and not Q.timer and not Q.active, "terminal query leaves no Host work")
    assert(palette.searchPending==false, "terminal query releases waiting state")
end

-- All three top-level operations may invoke external cancellation. A newly
-- scheduled Session input must survive the older operation returning.
for _,operation in ipairs({"schedule", "query", "cancel"}) do
    local armed, entered, cancellations=false, false, 0
    local handle=register("lifecycle.reentry", function(request, reply)
        if request.normalized=="newest" then assert(reply({{id="newest",title="Newest"}})) end
        return function()
            cancellations=cancellations+1
            if armed and not entered then entered=true; assert(S:Input("newest")) end
        end
    end)
    input("seed")
    armed=true
    if operation=="schedule" then S:Input("older")
    elseif operation=="query" then
        Q:Query("older", {visible=true, session=S.session, generation=S.generation}, S.generation)
    else Q:Cancel("old-cancel", S.generation) end
    assert(entered and S.raw=="newest" and Q.pending and Q.pending.raw=="newest", operation.." overwrote newest input")
    assert(Q.pending.generation==S.generation, "pending query owns the current Session generation")
    fire(Q.timer)
    assert(#palette.items==1 and palette.items[1].id=="newest", "newest result must publish")
    idle()
    assert(cancellations==2, "seed and completed newest each cancel exactly once")
    assert(handle:Unregister())
end

-- A delayed invalid response must terminate waiting while preserving results
-- from other Providers; a duplicate/late reply cannot publish again.
local invalidReply, validReply, cancellations
cancellations=0
local invalid=register("lifecycle.invalid", function(_,reply)
    invalidReply=reply
    return function() cancellations=cancellations+1 end
end)
local valid=register("lifecycle.valid", function(_,reply) validReply=reply end)
input("live")
assert(palette.searchPending)
local ok,err=invalidReply({{id="invalid"}})
assert(not ok and err.code=="INVALID_SCHEMA")
assert(palette.searchPending, "other pending Provider still owns waiting state")
assert(validReply({{id="live",title="Live"}}))
assert(#palette.items==1 and palette.items[1].id=="live")
idle()
local applied=palette.applied
ok,err=invalidReply({{id="late",title="Late"}})
assert(not ok and err.code=="STALE_REQUEST" and palette.applied==applied)
assert(cancellations==1)
assert(valid:Unregister())
input("only-invalid")
ok,err=invalidReply({{id="invalid"}})
assert(not ok and err.code=="INVALID_SCHEMA")
idle()
assert(#palette.items==0 and cancellations==2)
assert(invalid:Unregister())

-- Normal synchronous completion, asynchronous completion and timeout all
-- terminate through the same lifecycle without retaining deadline work.
local sync=register("lifecycle.sync",function(_,reply) assert(reply({{id="sync",title="Sync"}})) end)
input("sync"); idle(); assert(palette.items[1].id=="sync")
assert(sync:Unregister())
local delayedReply, cancelReason, cancelCount
cancelCount=0
local delayed=register("lifecycle.delayed",function(_,reply)
    delayedReply=reply
    return function(reason) cancelReason=reason;cancelCount=cancelCount+1 end
end)
input("later")
local job=next(I.Providers.jobs)
local deadline=job.timer
assert(delayedReply({{id="later",title="Later"}}))
idle(); assert(deadline.cancelled and cancelReason=="complete" and cancelCount==1)
input("timeout")
job=next(I.Providers.jobs)
fire(job.timer)
idle(); assert(cancelReason=="timeout" and cancelCount==2)
applied=palette.applied
ok,err=delayedReply({{id="late",title="Late"}})
assert(not ok and err.code=="STALE_REQUEST" and palette.applied==applied)

input("close")
job=next(I.Providers.jobs);deadline=job.timer
S:Stop("hidden");palette.visible=false
applied=palette.applied
ok,err=delayedReply({{id="late",title="Late"}})
assert(not ok and err.code=="STALE_REQUEST" and palette.applied==applied)
assert(deadline.cancelled and not Q.pending and not Q.timer and not I.Providers:HasPendingQuery())
assert(cancelReason=="hidden" and cancelCount==3)
-- Even delivery of a cancelled deadline cannot reopen a hidden session.
deadline.callback()
assert(palette.applied==applied)
assert(delayed:Unregister())
print("Search lifecycle PASS: operation reentry, invalid replies, sync/async completion, timeout and close")
