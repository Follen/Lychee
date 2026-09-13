-- Real Provider -> Query -> Session -> Palette; substitute only native objects
-- and timer delivery. Do not write searchPending to construct a passing state.
local timers = {}
C_Timer = {NewTimer=function(seconds, callback)
    local timer = {seconds=seconds, callback=callback}
    function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer
    return timer
end}
dofile("tests/support/palette.lua")
local Fixture=dofile("tests/support/provider_fixture.lua")
local I=LycheeInternal
I.Registry:SetReady(true)
local p=Lychee.UI.Palette
p:Show()
local session,query,motion=I.Search.Session,I.Search.Query,Lychee.UI.Motion
local replies={}
local function rows(count, prefix)
    local out={}
    for i=1,count do out[i]={id=prefix..i,title=prefix..i} end
    return out
end
local sync=assert(Fixture:Register({id="publication.sync",apiVersion="1.0.0",version="1",title="Sync",
    query=function(request, reply)
        assert(reply(rows(request.normalized=="large" and 4 or request.normalized=="empty" and 0 or 1,"sync")))
    end}))
local delayed=assert(Fixture:Register({id="publication.delayed",apiVersion="1.0.0",version="1",title="Delayed",
    query=function(request, reply) replies[request.normalized]=reply end}))
motion:StopAll()
p.frame.CreateAnimationGroup=function() error("height uses the existing driver") end
p.frame:SetHeight(164)
local publications={}
local apply=p.ApplySearchState
p.ApplySearchState=function(self,s,g,pending,items)
    if items then publications[#publications+1]={session=s,generation=g,pending=pending,count=#items} end
    return apply(self,s,g,pending,items)
end
local function input(text)
    p.input:SetText(text)
    assert(session:Input(text))
    p:SetQueryMode(text)
    assert(p.searchPending and not p.emptyState:IsShown())
    assert(query:Flush())
    local state=publications[#publications]
    assert(state.session==session.session and state.generation==session.generation)
    assert(state.pending==p.searchPending and state.count==#p.list.items)
end
input("large")
assert(p.searchPending and #p.list.items==4 and p.list.frame:IsShown())
assert(p.status:GetText()==I.Locale["搜索中…"] and motion.height and motion.height.to>164)
motion:StopHeight(true)
assert(replies.large(rows(4,"async")))
assert(not p.searchPending and #p.list.items==8 and p.status:GetText()~=I.Locale["搜索中…"])
motion:StopHeight(true)
local largeHeight=p.frame:GetHeight()
input("small")
assert(p.searchPending and #p.list.items==1 and p.frame:GetHeight()==largeHeight,
    "new partial results cannot contract the previous height")
local stale=replies.small
input("newest")
local generation=session.generation
local before=#publications
assert(not stale(rows(10,"stale")))
assert(#publications==before and p.generation==generation and p.searchPending)
assert(replies.newest({}))
assert(not p.searchPending and #p.list.items==1)
assert(motion.height and motion.height.to<largeHeight,"final short results may contract")
motion:StopHeight(true)
input("empty")
assert(#p.list.items==0 and p.searchPending and not p.emptyState:IsShown())
assert(replies.empty({}))
assert(not p.searchPending and p.emptyState:IsShown(),"terminal empty reply publishes the empty state")

-- A filtered query has no debounce, but its delayed completion must travel
-- through the same publication seam as text input and source refresh.
p.input:SetText("")
assert(p:ActivateHomeFilter({sourceID="publication.delayed:records"}))
assert(p.searchPending)
assert(replies[""](rows(1,"filtered")))
assert(not p.searchPending and #p.list.items==1 and p.list.items[1].id=="filtered1")
session:SourceChanged("test")
assert(session:RefreshSource())
assert(p.searchPending)
assert(replies[""](rows(1,"refreshed")))
assert(not p.searchPending and p.list.items[1].id=="refreshed1")
input("close")
local late=replies.close
p:Hide("publication-test")
before=#publications
assert(not late(rows(1,"late")))
assert(not p.visible and #publications==before and not p.searchPending)
assert(not I.Providers:HasPendingQuery() and not query.timer and not query.pending)
p.ApplySearchState=apply
assert(delayed:Unregister());assert(sync:Unregister())
print("Search publication PASS: mixed progress, geometry, final empty, stale reply, filter, refresh and close")

-- Resolving an alias is external code. It may finish another Provider while
-- Query is still merging an older partial result from the same operation.
p:Show()
for _,phase in ipairs({"initial", "asynchronous"}) do
    local finishFirst,finishLast,armed
    local first=assert(Fixture:Register({id="publication.first",apiVersion="1.0.0",version="1",title="First",
        query=function(_,reply) finishFirst=reply end}))
    local last=assert(Fixture:Register({id="publication.last",apiVersion="1.0.0",version="1",title="Last",
        query=function(_,reply) finishLast=reply end,
        resolve=function(id)
            if armed then
                armed=false
                assert(finishLast(rows(1,"last")))
                if phase=="initial" then assert(finishFirst(rows(1,"first"))) end
            end
            return {id=id,title="Resolved alias"}
        end}))
    assert(I.Search.Personalization:SetAlias({providerID="publication.last",entryID="alias"},"nested","Alias"))
    armed=phase=="initial"
    p.input:SetText("nested");assert(session:Input("nested"));p:SetQueryMode("nested")
    assert(query:Flush())
    if phase=="asynchronous" then armed=true;assert(finishFirst(rows(1,"first"))) end
    assert(not I.Providers:HasPendingQuery())
    assert(not p.searchPending and #p.list.items==3,"nested completion wins over the older "..phase.." merge")
    assert(I.Search.Personalization:SetAlias({providerID="publication.last",entryID="alias"},""))
    assert(last:Unregister());assert(first:Unregister())
end
p:Hide("nested-publication-end")
print("Nested query publication PASS: alias resolution cannot roll back results or progress")
