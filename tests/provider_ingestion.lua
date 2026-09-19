-- Real public SDK ingestion, with only access APIs supplied by this fixture.
-- wowdoc sourceId=wow-ui-source product=retail requestedRef=latest
-- resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34 (12.1.0)
-- Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua
-- :48 canaccesstable: caller permissions to index the table and its contents.
-- :65 canaccessvalue: whether the calling function may access the value.
-- :263 issecretvalue: whether the supplied value is secret.
-- Offline sentinels exercise rejection paths; they do not emulate WoW taint.
dofile("tests/provider_sdk_smoke.lua")
local I=LycheeInternal
local function definition(id, entries)
    return {id=id,title=id,version="1",apiVersion="1.0.0",entries=entries,
        actions={open={title="Open",run=function(record)
            record.aliases[1]="callback mutation"
            record.actions[1]="callback mutation"
            record.category.title="callback mutation"
            return {ok=true}
        end}}}
end
local function record(id)
    return {id=id,title="Shared metadata "..id,aliases={"same alias"},keywords={"same keyword"},
        category={id="group",title="Group"},payload={nested={value=id}},actions={"open"}}
end
local input={record("a"),record("b")}
local calls=0
local validate=I.Boundary.ValidateSearchRecord
I.Boundary.ValidateSearchRecord=function(self,...)
    calls=calls+1
    return validate(self,...)
end
local handle=assert(Lychee:RegisterProvider(definition("ingestion.shared",input)))
assert(calls==2,"a validated owned batch must not be traversed again at Registry reception")
local source="ingestion.shared:records"
local function current(id) return I.Search.StaticIndex:GetRecord(source,id or "a") end
local a,b=current("a"),current("b")
assert(a.aliases==b.aliases and a.keywords==b.keywords and a.actions==b.actions and a.category==b.category)
assert(a.payload~=b.payload and a.payload.nested~=b.payload.nested)
assert(not I.Boundary:_HasRecordReceipt(I.Providers.entries[handle.id].records),"receipt must be consumed after publication")
input[1].aliases[1]="external mutation";input[1].payload.nested.value="external mutation"
assert(a.aliases[1]=="same alias" and a.payload.nested.value=="a")
local item=assert(I.Providers:Resolve({providerID=handle.id,entryID="a"},{}))
assert(I.Providers:Execute(item,"open",{}).ok)
assert(a.aliases[1]=="same alias" and a.actions[1].title=="Open" and b.category.title=="Group")
calls=0
assert(handle:Update({upsert={record("a")}}))
assert(calls==1,"single-record updates must perform one canonical schema validation")
I.Boundary.ValidateSearchRecord=validate

local oldSecret,oldAccess,oldTable=issecretvalue,canaccessvalue,canaccesstable
local secret,denied,badTable="fixture secret","fixture denied",{}
local accesses=0
issecretvalue=function(value) accesses=accesses+1; return value==secret end
canaccessvalue=function(value) return value~=denied end
canaccesstable=function(value) return value~=badTable end
local accessAction,accessError=I.Boundary:ValidateSearchAction({id="x",kind="open-panel",panel="main",state={value=secret}})
assert(not accessAction and accessError.code=="SECRET_VALUE","standalone action validation still performs its own safety walk")
local accessText,textError=I.Boundary:ValidateText({{text="alias",scope={locale=secret}}})
assert(not accessText and textError.code=="SECRET_VALUE","standalone text validation does not inherit private trust")
local function rejected(value, code)
    local before,revision=current(),I.Providers.entries[handle.id].revision
    local ok,result,err=pcall(handle.Update,handle,{upsert={value}})
    assert(ok,"invalid public input must return a structured failure")
    assert(not result and err and err.code==(code or "INVALID_SCHEMA"),"unexpected rejection: "..tostring(err and err.code))
    assert(current()==before and I.Providers.entries[handle.id].revision==revision,"failed ingestion must be atomic")
end
local bad=record("a");bad.payload.nested.value=secret;rejected(bad,"SECRET_VALUE")
bad=record("a");bad.payload[secret]=1;rejected(bad,"SECRET_VALUE")
bad=record("a");bad.payload.nested.value=denied;rejected(bad,"INACCESSIBLE_VALUE")
bad=record("a");bad.payload=badTable;rejected(bad,"INACCESSIBLE_VALUE")
bad=record("a");bad.payload.self=bad.payload;rejected(bad)
bad=record("a");bad.payload=setmetatable({},{});rejected(bad)
bad=record("a");bad.payload.n=0/0;rejected(bad)
bad=record("a");bad.payload.n=math.huge;rejected(bad)
bad=record("a");bad.category.id="";rejected(bad)
bad=record("a");bad.category.id=string.rep("x",192);rejected(bad)
bad=record("a");bad._extensionID=handle.id;rejected(bad)
bad=record("a");bad._receivedRecords=true;rejected(bad)
bad=record("a");bad.actions={{id="open",title="Forged",kind="provider"}};rejected(bad)
bad=record("a");bad.aliases={};for n=1,129 do bad.aliases[n]="alias"..n end;rejected(bad)
bad=record("a");local nested=bad.payload;for n=1,12 do nested.next={};nested=nested.next end;rejected(bad)
local sparse={[1]=record("a"),[3]=record("b")}
assert(not handle:Update({replace=sparse}),"sparse batches remain invalid")
local cycle={};cycle[1]=cycle;assert(not handle:Update({replace=cycle}))
assert(accesses>0,"public inputs must pass native-access checks")
-- A native check reentering public registration must not corrupt traversal state.
local reentered,inner=false
issecretvalue=function(value)
    if value=="reenter trigger" and not reentered then
        reentered=true
        inner=assert(Lychee:RegisterProvider(definition("ingestion.inner",{record("inside")})))
    end
    return value==secret
end
bad=record("a");bad.payload.nested.value="reenter trigger"
assert(handle:Update({upsert={bad}}) and reentered and inner)
assert(inner:Unregister())
issecretvalue,canaccessvalue,canaccesstable=oldSecret,oldAccess,oldTable

-- _OwnRecords denotes ownership only. It is not a schema-validation receipt.
local draft=assert(I.Registry:Begin({id="ingestion.raw",title="Raw",version="1",apiVersion="1.0.0"},{public=true}))
assert(draft:RegisterSearchSource({id="records",title="Raw",version=2,revision=1,priority=0,scope={},
    snapshot=function() return I.Registry:_OwnRecords({{id="bad",kind="entry",title="Bad",actions={{id="x",kind="unknown"}}}},"ingestion.raw") end}))
local accepted,why=draft:Commit()
assert(not accepted and why and why.code=="INVALID_SCHEMA","ownership alone cannot bypass Registry validation")
assert(not I.Search.StaticIndex:GetRecord("ingestion.raw:records","bad"))
assert(Lychee.ReceiveRecords==nil and Lychee._HasRecordReceipt==nil,"ingestion capabilities remain outside public SDK")

-- Concatenation collisions must only miss sharing; they cannot conflate values.
local left,right=record("left"),record("right")
left.aliases={"a\0b","c"};right.aliases={"a","b\0c"}
assert(handle:Update({upsert={left,right}}))
assert(current("left").aliases~=current("right").aliases)
assert(current("left").aliases[1]=="a\0b" and current("right").aliases[2]=="b\0c")
for n=1,600 do
    local value=record("a");value.aliases={"unique alias "..n}
    assert(handle:Update({upsert={value}}))
end
local entry=I.Providers.entries[handle.id]
local pool=entry.metadataPool
assert(#pool.keys<=128,"interning auxiliary keys must remain bounded")
for _,key in ipairs(pool.keys) do assert(#key<=256,"metadata cache also has a byte bound") end
local large=record("a");large.aliases={string.rep("large ",200)}
assert(handle:Update({upsert={large}}) and #current().aliases[1]==1200,"large metadata remains intact")
local live=0;for _ in pairs(pool.values) do live=live+1 end
assert(live<=128)
-- A retained handle/entry must not keep the interner alive after unregister.
local weak=setmetatable({pool,entry.actionRecords,entry.actionLists},{__mode="v"})
pool=nil
assert(handle:Unregister())
collectgarbage("collect")
assert(weak[1]==nil and weak[2]==nil and weak[3]==nil,"unregister releases metadata pool roots")
print("Provider ingestion PASS: one canonical validation/batch member, external access/isolation, reentry, forged ownership, limits, atomic failures and bounded shared metadata")
