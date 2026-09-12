-- Public SDK roundtrip plus independent set oracle; no layout-derived expected records.
dofile("tests/provider_sdk_smoke.lua")
local I=LycheeInternal
local S=I.Search.Storage
local function equal(a,b)
 if type(a)~="table" then return a==b end
 if type(b)~="table" then return false end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local original={id="future",title="Title",kind="entry",description="Sparse",subtitle=false,
 futureExtension={nested={1,false,"text"}},futureFlag=false,payload={custom={color="red",[27]="value"}}}
local packed=S:PackRecord(original)
assert(S:IsPacked(packed) and S:PackRecord(packed)==packed)
assert(equal(S:Copy(packed),original) and S:Equal(packed,original) and S:Equal(original,packed))
packed.title="Changed";packed.futureFlag=true;packed.description=nil
local plain=S:Copy(packed)
assert(plain.title=="Changed" and plain.futureFlag and plain.description==nil and not getmetatable(plain))
plain.payload.custom.color="blue";assert(packed.payload.custom.color=="red")
local numeric={id="numeric",[1]="extension"};assert(S:PackRecord(numeric)==numeric)
assert(not S:Equal({id="numeric",[1]="numeric"},S:PackRecord({id="numeric"})))
-- Row allocations cannot hide a source-lifecycle leak.
local weak=setmetatable({}, {__mode="v"})
local function callback(record)
 assert(getmetatable(record)==nil and record.id=="item" and record.description=="Description")
 assert(record.payload.custom[27]=="value" and record.payload.custom.flag==false)
 for key in pairs(record) do assert(type(key)=="string","numeric layout leaked into SDK") end
 record.payload.custom.flag=true
 return {ok=true}
end
local input={id="item",title="Storage item",description="Description",subtext="Sparse subtext",
 payload={custom={[27]="value",flag=false}},actions={"open"}}
local handle=assert(Lychee:RegisterProvider({id="compact.sdk",apiVersion=2,version="1",title="Storage",
 entries={input},actions={open={title="Open",run=callback}}}))
local canonical=I.Search.StaticIndex:GetRecord("compact.sdk:records","item")
assert(S:IsPacked(canonical));weak[1]=canonical
assert(not Lychee:RegisterProvider({id="compact.forged",apiVersion=2,version="1",title="Bad",entries={canonical}}),"private layout cannot bypass public validation")
input.payload.custom.flag=true;assert(canonical.payload.custom.flag==false)
local item=assert(I.Providers:Resolve({providerID="compact.sdk",entryID="item"},{}))
assert(I.Providers:Execute(item,"open",{}));assert(canonical.payload.custom.flag==false)
local snapshot=I.Search.StaticIndex:ExportSnapshot()
local saved=snapshot.records["compact.sdk:records"][1]
assert(getmetatable(saved)==nil and saved.subtext=="Sparse subtext" and saved.payload.custom.flag==false)
assert(equal(saved,S:Copy(canonical)))
local before=canonical
assert(handle:Update({upsert={S:Copy(canonical)}})==nil,"host ownership fields must not become public input")
assert(I.Search.StaticIndex:GetRecord("compact.sdk:records","item")==before)
item=nil;canonical=nil;before=nil;assert(handle:Unregister());collectgarbage("collect")
assert(weak[1]==nil,"unregister retained packed records")
-- 6000 deterministic mixed mutations against an ordinary independent set.
local map,oracle={},{}
local seed=71
for step=1,6000 do
 seed=(seed*48271)%2147483647
 local term="term"..(seed%17);local key=string.format("entry-%03d",math.floor(seed/17)%241)
 oracle[term]=oracle[term] or {}
 if seed%3==0 then S.RemovePosting(map,term,key);oracle[term][key]=nil
 else S.AddPosting(map,term,key);oracle[term][key]=true end
 if step%37==0 then for t,expected in pairs(oracle) do
  local actual=map[t];local found={}
  if type(actual)=="string" then found[actual]=true
  elseif actual then for i,k in ipairs(actual) do assert(not found[k] and (i==1 or actual[i-1]<k));found[k]=true end end
  assert(equal(found,expected),"posting membership differs from set oracle")
  for k in pairs(expected) do assert(S.HasPosting(actual,k)) end
 end end
end
for term,expected in pairs(oracle) do for key in pairs(expected) do S.RemovePosting(map,term,key) end end
assert(next(map)==nil,"empty posting roots retained")
-- Saturated typo candidates have a stable order across input permutations/rebuilds.
debugprofilestop=function() return 0 end
local Index=I.Search.StaticIndex
local function make(reverse)
 local index=Index:New();assert(index:RegisterSource({id="stable"}))
 local rows={};for n=1,160 do local id=reverse and 161-n or n;rows[n]={id=string.format("%03d",id),kind="entry",title="frostbolx"} end
 assert(index:CommitSnapshot("stable",rows));return index
end
local uncategorized=Index:New()
assert(uncategorized:AddRecord("category",{id="title-only",kind="entry",title="Title",category={title="Group"}}))
assert(uncategorized.entries["category:title-only"].categoryID==nil and next(uncategorized.categories)==nil,"a category without ID must not index its table identity")
local left,right=make(false),make(true)
local stableEntry=right.entries["stable:001"]
local compiled=stableEntry.fields
local memberships={};for k,v in pairs(right.grams) do memberships[k]=v end
assert(right:ApplyDelta("stable",{{id="001",kind="entry",title="frostbolx",subtitle="metadata only"}},{}))
assert(right.entries["stable:001"].fields==compiled and right.entries["stable:001"]~=stableEntry,"metadata updates reuse search data but replace result identity")
for k,v in pairs(memberships) do assert(right.grams[k]==v,"metadata update needlessly rebuilt postings") end
local function ids(index)
 local out={};for _,hit in ipairs(index:Search("frostbolt",20)) do out[#out+1]=hit.record.id end
 assert(#out>0);return table.concat(out,",")
end
local expected=ids(left);assert(ids(right)==expected)
right:Rebuild();assert(ids(right)==expected)
assert(right:TouchSource("stable",false));assert(#right:Search("frostbolt",20)==0)
assert(right:TouchSource("stable",true));assert(ids(right)==expected)
assert(right:ApplyDelta("stable",{{id="001",kind="entry",title="frostbolx",description="updated"}},{}))
assert(ids(right)==expected)
print("Compact storage PASS sparse/future-field roundtrip, SDK plain callbacks, snapshot, rollback, GC roots, 6000 posting mutations, stable bounded fuzzy order")
