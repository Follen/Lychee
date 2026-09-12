-- Private registry boundary regressions. WoW is a bounded external test adapter;
-- the public Provider facade is covered separately in provider_sdk_smoke.lua.
_G = _G or {}
UIParent = {}
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "12345", "today", 120100 end
function InCombatLockdown() return false end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end, Hide = function() end, Show = function() end }
end
local root = "package/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"Core/Scheduler.lua"})
local I, SDK = _G.LycheeInternal, _G.Lychee
local readyCalls = 0
local readyToken = assert(SDK:RegisterReady(function() readyCalls = readyCalls + 1 end))
assert(type(readyToken.Cancel) == "function" and readyToken:Cancel(), "ready subscription is cancellable")
I.Registry:SetReady(true)
assert(readyCalls == 0, "cancelled ready callback does not run")
local function descriptor(id)
    return { id = id, title = "SDK contract", version = "1.0.0", apiVersion = 2, minApiRevision = 1, invalidationKeys = { "refresh" } }
end
local function register(id, title)
    local draft = assert(I.Registry:Begin(descriptor(id), { public = true }))
    assert(draft.descriptor == nil and draft.sources == nil and draft.state == nil, "public draft hides mutable registration state")
    assert(draft:RegisterSearchSource({ id = "records", version = 1, revision = 1, priority = 10, scope = {},
        records = { { id = "entry", kind = "custom", title = title } } }))
    local handle = assert(draft:Commit())
    assert(handle._entry == nil, "public handle hides the registry entry")
    return handle, assert(handle:GetSearchSource("records"))
end

local oldExtension, oldSource = register("sdk.reused", "Old instance")
assert(oldExtension:Unregister())
local newExtension, newSource = register("sdk.reused", "New instance")
local overwritten, staleError = oldSource:CommitSnapshot({ { id = "entry", kind = "custom", title = "Stale overwrite" } })
assert(not overwritten and type(staleError) == "table", "retired source handle must reject writes into a replacement instance")
assert(not oldSource:Upsert({ id = "ghost", kind = "custom", title = "Ghost" }), "old upsert cannot reach replacement source")
assert(not oldSource:Remove("entry"), "old remove cannot reach replacement source")
assert(not oldSource:BeginSnapshot(), "old batch cannot reach replacement source")
assert(not oldSource:Invalidate("refresh"), "old invalidation cannot reach replacement source")
assert(not oldSource:GetState(), "old source state cannot expose replacement state")
assert(not oldExtension:Invalidate("refresh"), "old extension invalidation cannot reach replacement source")
assert(not oldExtension:GetSearchSource("records"), "retired extension cannot mint replacement source handles")
local _, staleResults = I.Search.Query:Query("Stale overwrite", { visible = true })
assert(#staleResults == 0, "new instance remains unchanged by old handles")
assert(newSource:CommitSnapshot({ { id = "entry", kind = "custom", title = "Current owner" } }), "current handle remains usable")
assert(newExtension:SetEnabled(false))
assert(not newSource:Upsert({ id = "disabled", kind = "custom", title = "Disabled" }), "disabled source rejects writes")
assert(newExtension:SetEnabled(true))
assert(newSource:Upsert({ id = "enabled", kind = "custom", title = "Enabled" }), "same source handle resumes after enable")
assert(newExtension:Unregister())

local queued = {}
C_Timer = { After = function(_, callback) queued[#queued + 1] = callback end }
local timedExtension, timedSource = register("sdk.timer", "Old timed source")
assert(timedSource:Upsert({ id = "entry", kind = "custom", title = "Late timer" }))
assert(timedExtension:Unregister())
local replacement = register("sdk.timer", "Replacement timed source")
for index = 1, #queued do queued[index]() end
local _, timerResults = I.Search.Query:Query("Late timer", { visible = true })
assert(#timerResults == 0, "deferred commits cannot publish into a replacement instance")
assert(replacement:Unregister())
C_Timer = nil

local inputRecord = { id = "owned", kind = "custom", title = "Owned original", payload = { value = 1 } }
local inputSource = { id = "records", version = 1, revision = 1, priority = 10, scope = {}, records = { inputRecord } }
local ownedDraft = assert(I.Registry:Begin(descriptor("sdk.owned"), { public = true }))
assert(ownedDraft:RegisterSearchSource(inputSource))
inputRecord.title = "Changed after declaration"
local ownedHandle = assert(ownedDraft:Commit())
assert(inputRecord._extensionID == nil and inputSource._sourceID == nil, "Host does not stamp caller-owned tables")
local _, ownedResults = I.Search.Query:Query("Owned original", { visible = true })
assert(#ownedResults == 1, "published source uses the validated declaration copy")
local ownedSource = assert(ownedHandle:GetSearchSource("records"))
local update = { id = "owned", kind = "custom", title = "Owned update", payload = { value = 2 } }
assert(ownedSource:Upsert(update))
update.title = "Changed after update"; update.payload.value = 99
local _, updatedResults = I.Search.Query:Query("Owned update", { visible = true })
assert(#updatedResults == 1 and updatedResults[1].payload.value == 2, "nested update data is isolated from caller mutation")
assert(update._extensionID == nil, "updates leave caller records unchanged")
assert(ownedHandle:Unregister())

local supportOK, supported = pcall(SDK.Supports, SDK, 2, "bad")
assert(supportOK and supported == false, "Supports treats malformed version input as unsupported")
assert(SDK:Supports(2, 1) and not SDK:Supports(2, -1), "version compatibility validates positive revisions")

local many = {}
for index = 1, 129 do many[index] = { id = "entry-" .. index, kind = "custom", title = "Bulk entry " .. index } end
for _, mode in ipairs({ "records", "snapshot" }) do
    local draft = assert(I.Registry:Begin(descriptor("sdk.bulk-" .. mode), { public = true }))
    local source = { id = "records", version = 1, revision = 1, priority = 10, scope = {} }
    if mode == "records" then source.records = many else source.snapshot = function() return many end end
    local token, reason = draft:RegisterSearchSource(source)
    assert(token, "initial records and snapshot have the same capacity: " .. tostring(reason and reason.code))
    local handle = assert(draft:Commit())
    assert(handle:Unregister())
end
print("Lychee registry boundary smoke PASS")
