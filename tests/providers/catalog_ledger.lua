local Fixture=dofile("tests/support/provider_fixture.lua")
-- Real ledger + public Host transactions; only the game environment is replaced.
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "fixture", "today", 120100 end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end,Hide=function() end,Show=function() end} end
UIParent={}
dofile("tests/support/runtime.lua").Load("provider")
local namespace={Modules={}};assert(loadfile("addon/Lychee_Player/Runtime/CatalogLedger.lua"))("Fixture",namespace);TestPackages.Modules.CatalogLedger=namespace.Modules.CatalogLedger
local I=LycheeInternal
I.Registry:SetReady(true)
local handle=assert(Fixture:Register({id="ledger.fixture",title="Ledger",version="1",apiVersion="1.0.0",catalog={}}))
local ledger=TestPackages.Modules.CatalogLedger:New()
local function build(values)
    local rows={}
    for id,title in pairs(values) do rows[#rows+1]={id=id,title=title} end
    return rows
end
local commits,largest,failAt=0,0
local update=handle.catalog.Update
handle.catalog.Update=function(self,delta)
    commits=commits+1;largest=math.max(largest,#delta.upsert+#delta.remove)
    if commits==failAt then return nil,{code="TEST_FAILURE"} end
    return update(self,delta)
end
assert(ledger:Reconcile(handle.catalog,{a="A",b="B"},build,{full=true}))
assert(commits==1 and ledger.values.a=="A")
assert(ledger:Reconcile(handle.catalog,{a="A",b="B"},build,{full=true}) and commits==1)
assert(ledger:Reconcile(handle.catalog,{a=false},build) and not ledger.values.a and ledger.values.b=="B")
failAt=commits+1
local ok,err=ledger:Reconcile(handle.catalog,{c="C"},build,{full=true})
assert(not ok and err.code=="TEST_FAILURE" and ledger.values.b=="B" and not ledger.values.c)
assert(handle.catalog:Resolve("b") and not handle.catalog:Resolve("c"))
failAt=nil
assert(ledger:Reconcile(handle.catalog,{c="C"},build,{full=true}))
assert(not ledger.values.b and ledger.values.c=="C")
-- Chunk success is durable; retry must send only the uncommitted remainder.
local desired={};for i=1,40 do desired["new:"..i]="New "..i end
failAt=commits+3;largest=0
ok,err=ledger:Reconcile(handle.catalog,desired,build,{full=true,batchSize=16})
assert(not ok and err.code=="TEST_FAILURE" and not ledger.values.c and largest<=16)
local retained=0;for _ in pairs(ledger.values) do retained=retained+1 end
assert(retained==16,"only the successful first addition chunk is committed")
failAt=nil;local before=commits
assert(ledger:Reconcile(handle.catalog,desired,build,{full=true,batchSize=16}))
assert(commits-before==2 and largest<=16)
local broken={bad="Bad"}
ok,err=ledger:Reconcile(handle.catalog,broken,function() error("build failed") end)
assert(not ok and err.code=="CATALOG_BUILD_FAILED" and not ledger.values.bad)
assert(ledger:Reconcile(handle.catalog,broken,build),"a failed build releases the operation")
-- Full capacity replacement deletes obsolete rows before adding new identities.
local replacement={};for i=1,40 do replacement["replacement:"..i]="Replacement "..i end
local first=true
handle.catalog.Update=function(self,delta)
    if first then assert(#delta.remove>0 and #delta.upsert==0);first=false end
    return update(self,delta)
end
assert(ledger:Reconcile(handle.catalog,replacement,build,{full=true,batchSize=16}))
-- A caller can abandon a yielded diff; its successor must not stay busy.
local cancelled
local job=coroutine.create(function()
    local accepted,why=ledger:Reconcile(handle.catalog,{cancelled="Cancelled"},build,{checkpoint=coroutine.yield})
    cancelled=not accepted and why.code=="CATALOG_CANCELLED"
end)
assert(coroutine.resume(job))
ledger:Invalidate()
assert(coroutine.resume(job) and cancelled and not ledger.values.cancelled)
assert(ledger:Reconcile(handle.catalog,{successor="Successor"},build))
-- The commit callback cannot publish into a newly reset registration ledger.
handle.catalog.Update=function(self,delta)
    local accepted,why=update(self,delta)
    ledger:Invalidate(true)
    return accepted,why
end
ok,err=ledger:Reconcile(handle.catalog,{retired="Retired"},build)
assert(not ok and err.code=="CATALOG_CANCELLED" and not next(ledger.values))
handle.catalog.Update=update
assert(handle:Unregister())
-- Named business snapshots remain ordinary tables; no numeric record layout.
local compact=TestPackages.Modules.CatalogLedger:New({
    same=function(a,b) return a and a.title==b.title end,
    remember=function(v) return {title=v.title} end,
    recordID=function(id) return "record:"..id end,
    key=function(row) return row.payload.id end,
})
handle=assert(Fixture:Register({id="ledger.compact",title="Compact",version="1",apiVersion="1.0.0",catalog={}}))
local function named(values)
    local rows={};for id,v in pairs(values) do rows[#rows+1]={id="record:"..id,title=v.title,payload={id=id}} end
    return rows
end
assert(compact:Reconcile(handle.catalog,{[12]={title="Named",temporary="discard"}},named,{full=true}))
assert(compact.values[12].title=="Named" and compact.values[12].temporary==nil)
assert(compact:Reconcile(handle.catalog,{[12]=false},named) and not next(compact.values))
assert(handle:Unregister())
print("Catalog ledger PASS real Host atomic failure/retry, partial 16-row commits, deletion first, registration isolation and named snapshots")
