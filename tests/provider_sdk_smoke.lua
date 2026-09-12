-- Exercise the public Provider API against the real Host modules.
-- Only WoW and its timers/menu are replaced with deterministic external adapters.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "12345", "today", 120100 end
function InCombatLockdown() return false end
UIParent = {}
function CreateFrame()
    return { RegisterEvent=function() end, SetScript=function() end, Hide=function() end, Show=function() end }
end
local timers = {}
C_Timer = { NewTimer = function(seconds, callback)
    local timer = { seconds=seconds, callback=callback }
    function timer:Cancel() self.cancelled=true end
    timers[#timers+1] = timer
    return timer
end }
local root = "addon/Lychee/"
dofile("tests/support/runtime.lua").Load("provider", {"Core/Scheduler.lua", "Core/ResultActionExecutor.lua"})
local I, SDK = LycheeInternal, Lychee
assert(SDK:Supports(2,1) and not SDK:Supports(1,1))
assert(SDK.RegisterExtension == nil and SDK.RegisterSearchSource == nil)
local readyCalls = 0
local subscription = assert(SDK:RegisterReady(function() readyCalls=readyCalls+1 end))
subscription:Cancel()
I.Registry:SetReady(true)
assert(readyCalls == 0)

local function definition(id, entries)
    return { id=id, title=id, version="1.0.0", apiVersion=2, entries=entries or {} }
end
local function query(text, callback)
    local _, items = I.Search.Query:Query(text, { visible=true }, nil, callback)
    return items
end
local function errorCode(result, err, code)
    assert(result == nil or result == false, "expected failure " .. code)
    assert(type(err) == "table" and err.code == code, "expected " .. code .. ", got " .. tostring(type(err)=="table" and err.code or err))
end
local function expect(code, fn) local result, err=fn(); errorCode(result,err,code) end
local original = { id="same", title="Shared entity", payload={count=1}, actions={"open"}, drag={type="provider",handler="move",title="Move in my addon"} }
local calls, drags, cleaned = 0, 0, 0
local a = definition("test.alpha", {original, {id="unchanged",title="Unchanged entity"}})
a.actions = { open={title="Open",run=function(entry)
    calls=calls+1; assert(entry.payload.count==1); entry.payload.count=100; return {ok=true}
end} }
a.drags = { move={title="Move",begin=function() drags=drags+1; return {ok=true} end} }
a.onEnable = function() return function() cleaned=cleaned+1 end end
local first = assert(SDK:RegisterProvider(a))
local second = assert(SDK:RegisterProvider(definition("test.beta", {{id="same",title="Shared entity"}})))
original.title="Mutated"; original.payload.count=9
local matches=query("Shared entity")
assert(#matches==2 and matches[1].ref.providerID ~= matches[2].ref.providerID, "same local IDs remain distinct")
local alpha = matches[1].providerID=="test.alpha" and matches[1] or matches[2]
assert(alpha.payload.count==1, "Host owns a validated input copy")
assert(I.Providers.entries["test.alpha"].recordMap.same == I.Search.StaticIndex:GetRecord("test.alpha:records","same"),
    "Provider and index share one Host-owned record")
assert(I.Providers:Execute(alpha,"open",{}).ok and calls==1 and drags==0)
assert(I.Providers:Execute(alpha,"move",{},true).ok and drags==1 and calls==1)
assert(query("Shared entity")[1].payload.count~=100, "callbacks cannot mutate indexed records")
local recent=I.Search.Query:ResolveRecent({{providerID="test.beta",entryID="same"},{providerID="test.alpha",entryID="same"}},5)
assert(#recent==2 and recent[1].providerID=="test.beta" and recent[2].providerID=="test.alpha")
assert(#I.Search.Query:ResolveRecent({"same"},5)==0, "bare historical IDs are not migrated")
local untouched=I.Search.StaticIndex.entries["test.alpha:records:unchanged"]
expect("UNKNOWN_ACTION",function() return first:Update({upsert={{id="invalid",title="Invalid",actions={"missing"}}},remove={"same"}}) end)
assert(#query("Shared entity")==2, "invalid delta did not partially remove records")
assert(first:Update({upsert={{id="new",title="New entity"}}}))
assert(I.Providers.entries["test.alpha"].recordMap.new == I.Search.StaticIndex:GetRecord("test.alpha:records","new"), "delta adopts canonical records")
assert(I.Search.StaticIndex.entries["test.alpha:records:unchanged"]==untouched, "incremental updates preserve unrelated compiled entries")
local beforeNoop=first:GetState().revision
assert(first:Update({upsert={{id="new",title="New entity"}}}))
assert(first:GetState().revision==beforeNoop, "identical updates do not invalidate active results")
local reentered=false
I.Search.StaticIndex:OnChange(function(sourceID)
    if sourceID=="test.alpha:records" and not reentered then
        reentered=true
        expect("UPDATE_IN_PROGRESS",function() return first:Update({remove={"new"}}) end)
    end
end)
assert(first:Update({upsert={{id="one",title="One"},{id="two",title="Two"},{id="three",title="Three"}}}))
assert(reentered)
assert(first:Update({remove={"one","two"},upsert={{id="four",title="Four"}}}))
local alphaRecords=I.Providers.entries["test.alpha"]
assert(not alphaRecords.recordMap.one and not alphaRecords.recordMap.two and alphaRecords.recordMap.three and alphaRecords.recordMap.four)
for index, record in ipairs(alphaRecords.records) do assert(alphaRecords.recordOrder[record.id]==index) end
expect("STALE_RESULT",function() return I.Providers:Execute(alpha,"open",{}) end)
expect("INVALID_SCHEMA",function() return first:Update({replace={},remove={"same"}}) end)
assert(first:SetEnabled(false) and cleaned==1)
expect("PROVIDER_DISABLED",function() return first:Update({replace={}}) end)
assert(first:SetEnabled(true))
assert(first:Unregister() and cleaned==2)
local replacement=assert(SDK:RegisterProvider(definition("test.alpha",{{id="same",title="Replacement"}})))
expect("STALE_HANDLE",function() return first:Update({replace={}}) end)
assert(first:Unregister() and #query("Replacement")==1, "retired unregister leaves replacement intact")

local invalid=definition("test.invalid",{{id="x",title="Unknown adapter",actions={{id="bad",kind="secure-anything"}}}})
expect("INVALID_SCHEMA",function() return SDK:RegisterProvider(invalid) end)
assert(not I.Registry.entries[invalid.id] and not I.Registry.drafts[invalid.id], "invalid registration has no residue")
for _, malformed in ipairs({ false, 42, "wrong" }) do
    for _, field in ipairs({ "entries", "actions", "views", "drags", "scope", "query", "resolve", "onEnable" }) do
        local desc=definition("test.malformed"); desc[field]=malformed
        local ok, result, err=pcall(SDK.RegisterProvider,SDK,desc)
        assert(ok and result==nil and type(err)=="table", "malformed " .. field .. " returns a structured error")
    end
    for _, field in ipairs({ "actions", "drag", "payload" }) do
        local item={id="malformed",title="Malformed"}; item[field]=malformed
        local ok, result, err=pcall(SDK.RegisterProvider,SDK,definition("test.malformed",{item}))
        assert(ok and result==nil and type(err)=="table", "malformed entry " .. field .. " does not throw")
    end
end
expect("UNSUPPORTED_API",function() local d=definition("test.api"); d.apiVersion=1; return SDK:RegisterProvider(d) end)
local callbackBad=definition("test.callback",{{id="x",title="Bad",payload={run=function() end}}})
expect("INVALID_SCHEMA",function() return SDK:RegisterProvider(callbackBad) end)
local readOnly=assert(SDK:RegisterProvider(definition("test.info",{{id="info",title="Information only"}})))
local info=query("Information only")[1]
assert(#info.interaction.actions==0 and info.interaction.drag==nil)

local completed, cancellations, notifications = {}, {}, 0
local dynamic=definition("test.dynamic")
dynamic.query=function(request,reply)
    completed[request.raw]=reply
    return function(reason) cancellations[#cancellations+1]=reason end
end
dynamic.resolve=function(id) if id=="remote" then return {id=id,title="Restored current data",payload={fresh=true},actions={"open"}} end end
dynamic.actions={open={title="Open remote",run=function(entry) assert(entry.payload.fresh==true); return {ok=true} end}}
local delayed=assert(SDK:RegisterProvider(dynamic))
query("first",function() notifications=notifications+1 end)
query("second",function(items) notifications=notifications+1; assert(#items==1 and items[1].id=="remote") end)
expect("STALE_REQUEST",function() return completed.first({{id="late",title="Late data"}}) end)
assert(cancellations[1]=="query-replaced")
assert(completed.second({{id="remote",title="Delayed current data",actions={"open"}}}))
assert(notifications==1 and cancellations[2]=="complete")
expect("STALE_REQUEST",function() return completed.second({}) end)
local remote=I.Search.Query.last.results[1]
assert(I.Providers:CanRemember(remote))
local restored=I.Search.Query:ResolveRecent({remote.ref},5)
assert(#restored==1 and restored[1].text=="Restored current data")
assert(I.Providers:Execute(restored[1],"open",{}).ok)
query("timeout")
local deadline=timers[#timers]
assert(deadline.seconds==5)
deadline.callback()
expect("STALE_REQUEST",function() return completed.timeout({}) end)
assert(cancellations[#cancellations]=="timeout")
query("hidden")
I.Search.Query:Cancel("hidden")
expect("STALE_REQUEST",function() return completed.hidden({}) end)
assert(next(I.Providers.jobs)==nil, "no pending jobs after close")
for _, timer in ipairs(timers) do assert(timer.cancelled, "query deadline released") end
query("retired")
assert(delayed:Unregister())
local renewed=assert(SDK:RegisterProvider(definition("test.dynamic",{{id="new",title="Renewed"}})))
expect("STALE_REQUEST",function() return completed.retired({{id="remote",title="Ghost"}}) end)
assert(#query("Ghost")==0)

local transient=definition("test.transient")
transient.query=function(_,reply) reply({{id="volatile",title="Temporary"}}) end
local transientHandle=assert(SDK:RegisterProvider(transient))
local temporary=query("anywhere")[1]
assert(temporary.id=="volatile" and not I.Providers:CanRemember(temporary))
local wrongScope=definition("test.scope")
wrongScope.scope={product="classic"}
wrongScope.query=function() error("wrong product must not be queried") end
local scoped=assert(SDK:RegisterProvider(wrongScope))
query("scoped")
assert(I.Providers.diagnostics[#I.Providers.diagnostics].code=="QUERY_TIMEOUT", "wrong scope never invokes callback")

local menuActions, menuCalls={},0
MenuUtil={CreateContextMenu=function(_,generator)
    generator(nil,{CreateButton=function(_,title,callback) menuActions[#menuActions+1]={title=title,callback=callback} end})
end}
local menuDefinition=definition("test.menu",{{id="menu",title="Menu entity",actions={"one","two","three"}}})
menuDefinition.actions={}
for _, id in ipairs({"one","two","three"}) do menuDefinition.actions[id]={title=id,run=function() menuCalls=menuCalls+1; return {ok=true} end} end
local menuHandle=assert(SDK:RegisterProvider(menuDefinition))
local menuItem=query("Menu entity")[1]
local palette={visible=true,session=1,generation=1,ReportActionResult=function() end,RejectRow=function(_,_,reason) return false,reason end}
I.ResultActionExecutor:BindPalette(palette)
local row={item=menuItem,session=1,generation=1,extensionID=menuItem.providerID,IsVisible=function() return true end}
assert(I.ResultActionExecutor:ShowActions(row) and #menuActions==3)
assert(menuActions[3].callback().ok and menuCalls==1)
row.item=info
assert(not menuActions[1].callback() and menuCalls==1, "menu callback cannot act on a recycled row")
local infoRow={item=info,session=1,generation=1,extensionID=info.providerID,IsVisible=function() return true end}
local infoOK,infoError=I.ResultActionExecutor:ExecutePrimary(infoRow)
assert(infoOK==false and infoError=="NO_ACTION")

for _, handle in ipairs({second,replacement,readOnly,renewed,transientHandle,scoped,menuHandle}) do assert(handle:Unregister()) end
local cleanupAfterSelfRemoval=0
local selfRemoving=definition("test.self-removing")
selfRemoving.onEnable=function(handle)
    handle:Unregister()
    return function() cleanupAfterSelfRemoval=cleanupAfterSelfRemoval+1 end
end
assert(SDK:RegisterProvider(selfRemoving))
assert(cleanupAfterSelfRemoval==1 and not I.Providers.entries["test.self-removing"], "self-removal during enable still cleans returned resources")
local deferredFactory=dofile("lychee-sdk/examples/DeferredProvider.lua")
local deferredEntry={id="delayed",title="Deferred example",actions={"open"},payload={value=17}}
local example=assert(deferredFactory(SDK,"test.deferred-example",{deferredEntry},function(entry)
    assert(entry.actions[1]=="open" and entry.payload.value==17, "callbacks receive the public Entry shape")
    return {ok=true}
end))
assert(#query("Deferred example")==0)
local dataTimer=timers[#timers-1]
assert(dataTimer.seconds==0.1)
dataTimer.callback()
local exampleItem=I.Search.Query.last.results[1]
assert(exampleItem.id=="delayed" and I.Providers:Execute(exampleItem,"open",{}).ok)
assert(dataTimer.cancelled and timers[#timers].cancelled, "example releases both its timer and Host deadline")
assert(example:Unregister())
local fullBudgetEntries={}
for index=1,32 do fullBudgetEntries[index]={id="entry-"..index,title="Budget stable entry"} end
local fullBudget=assert(SDK:RegisterProvider(definition("test.budget",fullBudgetEntries)))
assert(#query("Budget stable entry")==20, "Provider-only search uses the complete result budget")
assert(fullBudget:Unregister())
local cancelledPeer=definition("test.cancel-b")
cancelledPeer.query=function() error("retired peer must not be queried") end
local peer=assert(SDK:RegisterProvider(cancelledPeer))
local cancelling=definition("test.cancel-a")
cancelling.query=function(_,reply) peer:Unregister(); reply({}) end
local cancellingHandle=assert(SDK:RegisterProvider(cancelling))
assert(#query("cancel peer")==0)
assert(cancellingHandle:Unregister())
local scopedEntry=assert(SDK:RegisterProvider(definition("test.scoped-entry",{{id="entry",title="Other client",scope={product="classic"}}})))
assert(#I.Search.Query:ResolveRecent({{providerID="test.scoped-entry",entryID="entry"}},5)==0)
assert(scopedEntry:Unregister())
local swapping, swapped
local swapDefinition=definition("test.swap-action",{{id="entry",title="Swap action",actions={"swap"}}})
swapDefinition.actions={swap={title="Swap",run=function()
    swapping:Unregister()
    swapped=assert(SDK:RegisterProvider(definition("test.swap-action",{{id="entry",title="New owner"}})))
    return {ok=true,view="detail"}
end}}
swapping=assert(SDK:RegisterProvider(swapDefinition))
local swapItem=query("Swap action")[1]
expect("STALE_RESULT",function() return I.Providers:Execute(swapItem,"swap",{}) end)
assert(#query("New owner")==1 and swapped:Unregister())
local helper=dofile("lychee-sdk/LycheeAPI.lua")
assert(helper.Supports(SDK) and not helper.Supports(SDK,2,false))
assert(next(I.Providers.jobs)==nil)
assert(LycheeDB.searchIndex==nil, "executable search data is not persisted")
print("Lychee Provider API 2 contract PASS")

do
    local starts, stops = 0, 0
    LycheeCharacterDB.disabledProviders = {["test.user-preference"]=true}
    local def = definition("test.user-preference", {{id="item",title="User preference fixture"}})
    def.onEnable = function() starts=starts+1; return function() stops=stops+1 end end
    local handle = assert(SDK:RegisterProvider(def))
    assert(not handle:GetState().enabled and not handle:GetState().userEnabled and starts==0)
    assert(#query("User preference fixture")==0, "saved disable applies before initial publication")
    assert(I.Registry:SetUserEnabled(handle.id,true))
    assert(starts==1 and #query("User preference fixture")==1)
    assert(handle:SetEnabled(false) and stops==1)
    assert(I.Registry:SetUserEnabled(handle.id,false))
    assert(handle:SetEnabled(true))
    assert(not handle:GetState().enabled and starts==1, "owner enable cannot override user disable")
    assert(I.Registry:SetUserEnabled(handle.id,true) and starts==2)
    assert(I.Registry:SetUserEnabled(handle.id,true) and starts==2, "repeat toggle does not restart provider")
    assert(I.Registry:SetUserEnabled(handle.id,false) and stops==2)
    assert(handle:Unregister())
    local restored=assert(SDK:RegisterProvider(def))
    assert(not restored:GetState().enabled and starts==2, "disable survives re-registration")
    assert(restored:Unregister())
    I.Registry:SetReady(false)
    local pending=assert(SDK:RegisterProvider(definition("test.pending-preference",{{id="item",title="Pending preference"}})))
    LycheeCharacterDB.disabledProviders["test.pending-preference"]=true
    I.Registry:SetReady(true)
    assert(not pending:GetState().enabled and not pending:GetState().userEnabled, "publication reads restored SavedVariables")
    assert(pending:Unregister())
    expect("REQUIRED_PROVIDER",function() return I.Registry:SetUserEnabled("lychee.settings",false) end)
    print("Lychee persistent Provider preference PASS")
end

;(function()
    local def=definition("test.resolved-memory")
    def.resolve=function(id) return {id=id,title="Resolved memory "..id,actions={"open"}} end
    def.actions={open={title="Open",run=function() return {ok=true} end}}
    local handle=assert(SDK:RegisterProvider(def))
    local item=assert(I.Providers:Resolve({providerID=handle.id,entryID="kept"},{}))
    collectgarbage("collect")
    assert(I.Providers:IsCurrent(item) and I.Providers:Execute(item,"open",{}).ok, "visible resolved record survives collection")
    item=nil
    for index=1,500 do I.Providers:Resolve({providerID=handle.id,entryID=tostring(index)},{}) end
    collectgarbage("collect")
    assert(next(I.Providers.entries[handle.id].resolved)==nil, "unreferenced resolved records are collectible")
    assert(handle:Unregister())
    print("Resolved record lifetime PASS")
end)()
