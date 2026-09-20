-- Offline storage experiment only; not a production index or a runtime latency test.
-- lua tests/performance/performance_posting_storage.lua
-- Both container measurements exclude the shared ordinal maps and source records.
dofile('tests/performance/performance_memory.lua')
local index=LycheeInternal.Search.StaticIndex
local ids,keys={},{}
for key in pairs(index.entries) do keys[#keys+1]=key end
table.sort(keys)
assert(#keys < 16777216, "three-byte ordinal capacity exceeded")
for id,key in ipairs(keys) do ids[key]=id end
local function packed(set)
 local list={}
 if type(set)=='string' then list[1]=ids[set] else for key in pairs(set) do if key~=0 then list[#list+1]=ids[key] end end end
 table.sort(list)
 local chars={}
 for i,id in ipairs(list) do chars[i]=string.char(math.floor(id/65536)%256,math.floor(id/256)%256,id%256) end
 return table.concat(chars)
end
local function contains(value,id)
 local lo,hi=1,#value/3
 while lo<=hi do
  local mid=math.floor((lo+hi)/2);local a,b,c=value:byte(mid*3-2,mid*3);local current=a*65536+b*256+c
  if current==id then return true elseif current<id then lo=mid+1 else hi=mid-1 end
 end
 return false
end
collectgarbage('collect');local initial=collectgarbage('count')
local plain={}
for gram,set in pairs(index.grams) do
 if type(set)=='string' then plain[gram]=set else local copy={};for k,v in pairs(set) do copy[k]=v end;plain[gram]=copy end
end
collectgarbage('collect');local hashKB=collectgarbage('count')-initial
plain=nil;collectgarbage('collect');initial=collectgarbage('count')
local compressed={}
for gram,set in pairs(index.grams) do compressed[gram]=packed(set) end
collectgarbage('collect');local packedKB=collectgarbage('count')-initial
local probes,expected={},{}
for gram,set in pairs(index.grams) do
 for id=1,#keys,17 do
  probes[#probes+1]={gram,id};expected[#expected+1]=type(set)=='string' and set==keys[id] or type(set)=='table' and set[keys[id]]==true
 end
end
for i,p in ipairs(probes) do assert(contains(compressed[p[1]],p[2])==expected[i],'membership mismatch') end
local start=os.clock();local matches=0
for round=1,4 do for _,p in ipairs(probes) do local set=index.grams[p[1]];if type(set)=='string' and set==keys[p[2]] or type(set)=='table' and set[keys[p[2]]] then matches=matches+1 end end end
local hashMS=(os.clock()-start)*1000
start=os.clock();local packedMatches=0
for round=1,4 do for _,p in ipairs(probes) do if contains(compressed[p[1]],p[2]) then packedMatches=packedMatches+1 end end end
assert(matches==packedMatches)
print(string.format('POSTING_EXPERIMENT entries=%d probes=%d hash_KiB=%.2f packed_KiB=%.2f hash_ms=%.2f packed_ms=%.2f',#keys,#probes*4,hashKB,packedKB,hashMS,(os.clock()-start)*1000))
print('LIMITS: frozen snapshot only; excludes ordinal maps, updates and complete search; not runtime implementation')