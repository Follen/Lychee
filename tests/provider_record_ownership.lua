-- Exercise the public seam; private transfer must never weaken caller isolation.
dofile("tests/provider_sdk_smoke.lua")
local I=LycheeInternal
local original={id="entry",title="Original",payload={nested={value=1}},aliases={"original alias"}}
local handle=assert(Lychee:RegisterProvider({id="ownership.transfer",apiVersion=2,version="1",title="Ownership",entries={original}}))
local function current() return I.Search.StaticIndex:GetRecord("ownership.transfer:records","entry") end
original.title="caller mutation";original.payload.nested.value=99;original.aliases[1]="caller alias"
assert(current().title=="Original" and current().payload.nested.value==1 and current().aliases[1]=="original alias")
local replacement={id="entry",title="Replace",payload={nested={value=2}}}
assert(handle:Update({replace={replacement}}));replacement.payload.nested.value=99
assert(current().payload.nested.value==2)
local addition={id="entry",title="Delta",payload={nested={value=3}}}
assert(handle:Update({upsert={addition}}));addition.payload.nested.value=99
assert(current().payload.nested.value==3)
local before=current()
local ok=handle:Update({upsert={{id="entry",title="Bad A"},{id="entry",title="Bad B"}}})
assert(not ok and current()==before,"duplicate IDs must not partially commit")
local apply=I.Search.StaticIndex.ApplyDelta
I.Search.StaticIndex.ApplyDelta=function() return nil,"INJECTED_FAILURE" end
ok=handle:Update({upsert={{id="entry",title="Failed update",payload={nested={value=4}}}}})
I.Search.StaticIndex.ApplyDelta=apply
assert(not ok and current()==before and I.Providers.entries[handle.id].records[1]==before,"failed transfer must leave both owners unchanged")
assert(handle:Update({upsert={{id="entry",title="Recovered",payload={nested={value=5}}}}}))
assert(current().payload.nested.value==5,"failed transfer must not poison retry")
-- A field on public data cannot manufacture the private ownership capability.
local bad,err=Lychee:RegisterProvider({id="ownership.forged",apiVersion=2,version="1",title="Bad",entries={},_ownedRecords=true})
assert(not bad and err.code=="INVALID_SCHEMA")
assert(Lychee._OwnRecords==nil,"private ownership must not enter the SDK facade")
local reentered=false
I.Search.StaticIndex:OnChange(function(source)
    if source=="ownership.transfer:records" and not reentered then
        reentered=true
        local nested,why=handle:Update({replace={}})
        assert(not nested and why.code=="UPDATE_IN_PROGRESS")
    end
end)
assert(handle:Update({upsert={{id="entry",title="Reentry",payload={nested={value=6}}}}}))
assert(reentered and current().payload.nested.value==6)
assert(handle:Unregister())
assert(not I.Search.StaticIndex:GetRecord("ownership.transfer:records","entry"))
print("Provider record ownership PASS: register/replace/delta isolation, duplicate rollback, failed commit/retry, forged field and update reentry")
