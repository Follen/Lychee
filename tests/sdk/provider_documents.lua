local f=dofile("tests/support/settings_fixture.lua").Load()
local I=f.I;I.Registry:SetReady(true)
local calls,mode,handle=0,"ok"
local documents={};for n=1,100 do documents[n]={id="row:"..n,title="Document "..n} end
local raw={id="row:1",title="Document 1",aliases={"alias"},payload={value=1},actions={"open"}}
handle=assert(Lychee:RegisterProvider({id="documents.test",title="Documents",apiVersion="1.0.0",version="1.0.0",entryMode="documents",entries=documents,
 actions={open={title="Open",run=function(record) assert(record.payload.value==1);return {ok=true} end}},
 readEntry=function(id,context)
  calls=calls+1;assert(context.reason=="query" or context.reason=="resolve")
  if mode=="invalidate" then handle:Invalidate() end
  if mode=="missing" then return nil end
  if mode=="error" then return nil,"bad error" end
  if mode=="wrong" then return {id="wrong",title="Wrong"} end
  raw.id=id;return raw
 end}))
assert(calls==0)
local _,hits=I.Search.Query:Query("document",{visible=true})
assert(#hits==20 and calls==20)
local item=hits[1];assert(I.Providers:IsCurrent(item))
assert(I.Providers:Execute(item,"open",{}).ok)
raw.payload.value=2
assert(item.payload.value==1,"reader's retained graph mutated owned result")
assert(I.Providers:PublicRecord(item.searchRecord,"documents.test").actions[1]=="open")
assert(handle:Update({upsert={{id=item.id,title="Changed"}}}))
assert(not I.Providers:IsCurrent(item),"updated directory left an old action executable")
for _,testMode in ipairs({"missing","error","wrong","invalidate"}) do
 mode=testMode
 local _,result,_,_,partial=I.Search.Query:Query("changed",{visible=true})
 assert(#result==0 and partial,"reader failure was reported as complete: "..testMode)
end
mode="ok";raw.payload.value=1
local restored=assert(I.Providers:Resolve({providerID="documents.test",entryID="row:1000"}))
assert(restored.id=="row:1000" and I.Providers:IsCurrent(restored))
assert(handle:Unregister());assert(not I.Providers:IsCurrent(restored))
assert(not Lychee:RegisterProvider({id="documents.invalid",apiVersion="1.0.0",version="1.0.0",entryMode="documents",entries={}}))
print("Provider documents PASS: top-K read, isolation, actions, update, failure, reentry, restore and unregister")
