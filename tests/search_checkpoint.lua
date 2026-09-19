LycheeInternal={}
dofile("tests/support/runtime.lua").Load("search")
local index=LycheeInternal.Search.StaticIndex:New()
assert(index:RegisterSource({id="checkpoint",version=1}))
local records={}
for n=1,1000 do records[n]={id=tostring(n),title="Candidate "..n} end
assert(index:CommitSnapshot("checkpoint",records))
local calls=0
local hits=index:Search("candidate",20,nil,"transfer",nil,nil,function() calls=calls+1;return 0 end)
assert(#hits==20)
assert(calls>=1000,"index ignored cooperative checkpoint during candidate scan")
local ok=pcall(function() index:Search("candidate",20,nil,"transfer",nil,nil,function() error("cancelled") end) end)
assert(not ok,"cancelled scan continued")
print("Search checkpoint PASS: full scan cooperates and cancellation propagates")
