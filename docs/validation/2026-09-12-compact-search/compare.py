from pathlib import Path
import sys,time,json,statistics,os
HERE=Path(__file__).resolve().parent
os.chdir(HERE.parents[2])
sys.path.insert(0,str(Path("analyze/tools/python").resolve()))
from lupa.lua51 import LuaRuntime
results=[]
for round in range(7):
 for mode in (["before","after"] if round%2==0 else ["after","before"]):
  r=LuaRuntime(unpack_returned_tuples=True);r.globals().arg=r.table_from([])
  r.globals().BASELINE_INDEX=(HERE/"StaticIndex-before.lua").as_posix()
  r.globals().BASELINE_PROVIDER=(HERE/"ProviderRuntime-before.lua").as_posix()
  if mode=="before":
   r.execute('local native=dofile;dofile=function(p) if p=="package/Lychee/Search/Storage.lua" then return nil elseif p=="package/Lychee/Search/StaticIndex.lua" then p=BASELINE_INDEX elseif p=="package/Lychee/Core/ProviderRuntime.lua" then p=BASELINE_PROVIDER end;return native(p) end')
  lines=[]
  r.globals().print=lambda *args:lines.append(" ".join(str(v) for v in args))
  build_start=time.perf_counter()
  r.eval("dofile")("tests/performance_memory.lua")
  harness_ms=(time.perf_counter()-build_start)*1000
  r.execute('debugprofilestop=function() return 0 end')
  r.execute(r"""local Q=LycheeInternal.Search.Query
   local queries={"死","死亡","死亡矿井","巫妖王","纹章","星","星光","星光云端","无敌","午夜","not-found","翡翠"}
   function bench() for n=1,10 do for _,q in ipairs(queries) do Q:Query(q,{visible=true}) end end end
   local function encode(v)
    if type(v)~="table" then return type(v)..":"..tostring(v) end
    local keys={};for key in pairs(v) do keys[#keys+1]=key end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={};for _,key in ipairs(keys) do out[#out+1]=encode(key).."="..encode(v[key]) end;return "{"..table.concat(out,"|").."}"
   end
   function fingerprint() local out={};for _,q in ipairs(queries) do local _,items=Q:Query(q,{visible=true});for _,v in ipairs(items) do
    local shape={};for _,key in ipairs({"id","text","kindTitle","subtext","description","icon","category","categoryColor","sourceID","confidence","evidence","interaction"}) do shape[key]=v[key] end
    out[#out+1]=q..":"..encode(shape)
   end end;return table.concat(out,"\n") end
   local I=LycheeInternal
   local function copy(value)
    if type(value)~="table" then return value end
    local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
   end
   function delta100()
    for n=1,100 do
     local record=I.Search.StaticIndex:GetRecord("builtin.mounts:records","mount:1");local value=I.Search.Storage and I.Search.Storage:Copy(record) or copy(record);value._extensionID=nil;value.subtitle="changed "..n
     assert(I.Builtin.Mounts.handle:Update({upsert={value}}))
    end
   end
   function rebuild() I.Search.StaticIndex:Rebuild() end
   function toggle() assert(I.Registry:SetUserEnabled("builtin.mounts",false));assert(I.Registry:SetUserEnabled("builtin.mounts",true)) end
  """)
  fn=r.globals().bench;fn();r.eval('collectgarbage')("collect")
  start=time.perf_counter();fn();ms=(time.perf_counter()-start)*1000
  fingerprint=r.globals().fingerprint()
  phases={}
  for name in ("delta100","rebuild","toggle"):
   start=time.perf_counter();r.globals()[name]();phases[name+"_ms"]=(time.perf_counter()-start)*1000
  results.append({**phases,"round":round,"mode":mode,"hot120_ms":ms,"whole_fixture_ms":harness_ms,"memory_line":next(v for v in lines if v.startswith("MEMORY ")),"fingerprint":fingerprint})
base=results[0]["fingerprint"]
assert all(v["fingerprint"]==base for v in results),"business query differences"
for v in results: del v["fingerprint"]
summary={mode:{"median_ms":statistics.median(v["hot120_ms"] for v in results if v["mode"]==mode),"max_ms":max(v["hot120_ms"] for v in results if v["mode"]==mode)} for mode in ("before","after")}
(HERE/"comparison.json").write_text(json.dumps({"environment":"64-bit Lua 5.1 via Lupa; fixed fuzzy clock; 7 alternating rounds, 120 queries each; offline", "equivalence":True,"summary":summary,"samples":results},indent=2))
print(json.dumps(summary));print("ratio",summary["after"]["median_ms"]/summary["before"]["median_ms"])

assert summary["after"]["median_ms"] <= summary["before"]["median_ms"]*1.15, "Hot query median regressed beyond 15% gate"
