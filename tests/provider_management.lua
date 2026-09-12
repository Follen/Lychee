-- Exercise the real Host management seam. Only the game combat flag is mocked.
local combat=false
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
function InCombatLockdown() return combat end
dofile("tests/support/runtime.lua").Load("provider", {"Search/ProviderPolicy.lua", "Core/ProviderManagement.lua"})
local I, M = LycheeInternal, LycheeInternal.ProviderManagement
local function definition(id)
    return {id=id,title="Management fixture",version="1",apiVersion=2,minApiRevision=6,
        scope={products={"retail"}},i18n={enUS={},zhCN={}},
        searchGlobal=true,searchPrefixes={"fixture"},searchKeywords={},
        entries={{id="one",title="Example record"}}}
end
local function expect(code, result, err)
    assert(not result and type(err)=="table" and err.code==code, "expected "..code)
end
local pending=assert(Lychee:RegisterProvider(definition("management.pending")))
local pendingToken=assert(M:GetInstance("management.pending"))
local pendingInfo=assert(M:Read("management.pending",pendingToken,{}))
assert(pendingInfo.status=="pending" and not pendingInfo.effectiveEnabled)
assert(M:SetUserEnabled("management.pending",pendingToken,false))
assert(M:Read("management.pending",pendingToken,pendingInfo).status=="pending", "not-ready status precedes user preference")
I.Registry:SetReady(true)
assert(M:Read("management.pending",pendingToken,pendingInfo).status=="user-disabled")
assert(pending:Unregister())
local handle=assert(Lychee:RegisterProvider(definition("management.fixture")))
local token=assert(M:GetInstance("management.fixture"))
assert(type(token)=="number" and M:IsCurrent("management.fixture",token))
local rows=M:FillList({})
assert(#rows==1 and rows[1].instanceToken==token and rows[1].effectiveEnabled)
for _,field in ipairs({"entry","definition","records","provider","state"}) do assert(rows[1][field]==nil) end
local first=rows[1]
for index=1,100 do assert(M:FillList(rows)==rows and rows[1]==first) end
collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count")
for index=1,1000 do M:FillList(rows) end
local allocated=collectgarbage("count")-before
collectgarbage("restart")
assert(allocated<8, "warm management list filling must reuse its records")
local detail=assert(M:Read("management.fixture",token,{}))
assert(detail.sample=="Example record" and detail.products[1]=="retail")
local products=detail.products
assert(M:Read("management.fixture",token,detail)==detail and detail.products==products)
detail.products[1]="corrupted"
assert(M:Read("management.fixture",token,detail).products[1]=="retail", "detail does not expose definition scope")
assert(M:SetUserEnabled("management.fixture",token,false))
M:FillList(rows);M:Read("management.fixture",token,detail)
assert(rows[1].status=="user-disabled" and detail.status==rows[1].status)
assert(not detail.userEnabled and detail.ownerEnabled and not detail.effectiveEnabled)
assert(M:IsCurrent("management.fixture",token), "disable preserves registration identity")
assert(M:ToggleUserEnabled("management.fixture",token))
assert(handle:SetEnabled(false));M:Read("management.fixture",token,detail)
assert(detail.status=="owner-disabled" and detail.userEnabled and not detail.ownerEnabled)
assert(handle:SetEnabled(true))

assert(M:SetConfiguration("management.fixture",token,false,{"fixture"},{"showfixture"}))
local global,prefixes,keywords=M:GetConfiguration("management.fixture",token)
assert(global==false and prefixes[1]=="fixture" and keywords[1]=="showfixture")
assert(M:SetConfiguration("management.fixture",token,true,prefixes,keywords))
-- Saving one editor re-reads siblings, so an intervening global toggle survives.
global,prefixes,keywords=M:GetConfiguration("management.fixture",token)
assert(M:SetConfiguration("management.fixture",token,global,{"changedfixture"},keywords))
global,prefixes,keywords=M:GetConfiguration("management.fixture",token)
assert(global and prefixes[1]=="changedfixture" and keywords[1]=="showfixture")
local ok=M:SetConfiguration("management.fixture",token,false,{}, {})
assert(not ok and M:GetConfiguration("management.fixture",token)==true, "invalid change leaves committed configuration")
assert(M:ResetConfiguration("management.fixture",token))
global,prefixes,keywords=M:GetConfiguration("management.fixture",token)
assert(global and prefixes[1]=="fixture" and #keywords==0)
combat=true
expect("COMBAT_LOCKED",M:ToggleUserEnabled("management.fixture",token))
expect("COMBAT_LOCKED",M:SetConfiguration("management.fixture",token,false,{"fixture"},{}))
combat=false
assert(handle:Unregister())
expect("STALE_HANDLE",M:Read("management.fixture",token,detail))
handle=assert(Lychee:RegisterProvider(definition("management.fixture")))
local nextToken=assert(M:GetInstance("management.fixture"))
assert(nextToken~=token and not M:IsCurrent("management.fixture",token))
expect("STALE_HANDLE",M:SetUserEnabled("management.fixture",token,false))
expect("STALE_HANDLE",M:SetConfiguration("management.fixture",token,false,{"wrong"},{}))
expect("STALE_HANDLE",M:ResetConfiguration("management.fixture",token))
assert(M:Read("management.fixture",nextToken,detail).userEnabled)
assert(handle:Unregister())

-- An owner callback may replace itself during a UI write. The old request must
-- return stale instead of letting its caller continue editing the replacement.
local reentrant,replacement
local d=definition("management.reentrant")
d.onDisable=function()
    assert(reentrant:Unregister())
    replacement=assert(Lychee:RegisterProvider(definition("management.reentrant")))
end
reentrant=assert(Lychee:RegisterProvider(d))
local reentrantToken=assert(M:GetInstance("management.reentrant"))
expect("STALE_HANDLE",M:SetUserEnabled("management.reentrant",reentrantToken,false))
assert(replacement and not M:IsCurrent("management.reentrant",reentrantToken))
assert(replacement:Unregister())
assert(#M:FillList(rows)==0)
print(string.format("Provider management PASS: private snapshots, 1000 warm fills %.1f KiB, pending/effective/user/owner states, configuration, combat, stale and reentrant instances",allocated))
