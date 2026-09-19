-- Exercise the real reader/codec path; no persistent cache or weakened boundary.
local f=dofile("tests/support/settings_fixture.lua").Load()
f.I.Registry:SetReady(true)
local providerID="allocation.fixture"
local documents={}
for n=1,500 do documents[n]={id="setting:memory_toggle_"..n,title="Test toggle "..n} end
local handle=assert(Lychee:RegisterProvider({id=providerID,title="Allocation fixture",apiVersion="1.0.0",version="1",
 entryMode="documents",entries=documents,
 resolveTarget=function(target) return {status="ready",target=target,identity=target.key.setting} end,
 actions={set={title="Set",actionVersion=1,schema={value={type="boolean",required=true}},run=function() return {status="succeeded"} end}},
 readEntry=function(id)
  local actions={}
  for n,name in ipairs({"toggle","on","off","default","alternate"}) do
   actions[n]={id=name,title=name,kind="invocation",invocation={kind="invocation",product="retail",providerID=providerID,
    actionID="set",actionVersion=1,target={version=1,key={setting=id}},args={value=n%2==1}}}
  end
  return {id=id,title="Test toggle "..id:match("(%d+)$"),actions=actions,primaryActionID="toggle"}
 end}))
local V,B=f.I.Invocations,f.I.Boundary
local API=Lychee.SDK.Invocation
local schema={items={type="list",maxItems=4,items={type="integer"},default={3,1,3},set=true}}
local input={items={2,1,2}}
local result=assert(API:NormalizeArgs(schema,input))
assert(#result.items==2 and result.items[1]==1 and result.items[2]==2)
result.items[1]=99
assert(input.items[1]==2 and schema.items.default[1]==3)
local defaults=assert(API:NormalizeArgs(schema,{}));defaults.items[1]=99
assert(API:NormalizeArgs(schema,{}).items[1]==1)
schema.items.maxItems=1
assert(not API:NormalizeArgs(schema,input),"mutable public schema incorrectly cached")
assert(API._ValidateStoredRef==nil,"Host-only borrowed validation exposed through SDK")
local ref={kind="invocation",product="retail",providerID=providerID,actionID="setting-boolean",actionVersion=1,
 target={version=1,key={setting="setting:memory_toggle_1"}},args={value=true}}
local owned=assert(API:NormalizeStoredRef(ref));owned.target.key.setting="changed"
assert(ref.target.key.setting=="setting:memory_toggle_1")
-- The former key encoder normalized an isolated copy and removed root labels.
-- Keep that independent oracle so borrowing cannot change identity or input.
local function encode(value)
 local kind=type(value)
 if kind=="string" then return "s"..#value..":"..value end
 if kind=="number" then return "n"..(value==0 and "0" or string.format("%.17g",value))..";" end
 if kind=="boolean" then return value and "b1" or "b0" end
 local keys,out={},{}
 for key in pairs(value) do keys[#keys+1]=key end
 table.sort(keys,function(a,b)
  if type(a)~=type(b) then return type(a)<type(b) end
  if type(a)=="boolean" then return a==false and b==true end
  return a<b
 end)
 out[1]="t"..#keys..":"
 for _,key in ipairs(keys) do out[#out+1]=encode(key);out[#out+1]=encode(value[key]) end
 return table.concat(out)
end
for _,kind in ipairs({"legacy-entry","target","command","invocation"}) do
 for n=1,100 do
  local r={kind=kind,product="retail",providerID=providerID,entryID="entry-"..n,title="display",sourceTitle="source",icon=123}
  if kind~="legacy-entry" then r.target={version=1,key={id=n,nested={title="keep",entryID=n,flag=n%2==0}}} end
  if kind=="command" or kind=="invocation" then r.actionID="setting-boolean";r.actionVersion=1 end
  if kind=="invocation" then r.args={value=n%2==0} end
  local expected=assert(API:NormalizeStoredRef(r));expected.title,expected.icon,expected.sourceTitle=nil,nil,nil
  if kind~="legacy-entry" then expected.entryID=nil end
  assert(f.I.Search.RuntimeIdentity:ReferenceKey(r)=="\0"..encode(expected),"reference key changed")
  assert(r.title=="display" and r.entryID=="entry-"..n,"borrowed encoder mutated input")
 end
end
for _,limits in ipairs({{maxNodes=3,maxBytes=1000},{maxNodes=100,maxBytes=20}}) do
 local value={a={b=1}}
 local _,copyError=B:Copy(value,"budget",limits)
 local _,checkError=B:Validate(value,"budget",limits)
 assert(copyError and checkError and copyError.code==checkError.code and checkError.code=="DATA_LIMIT")
end
local inaccessible={}
canaccessvalue=function(value) return value~=inaccessible end
assert(not V:_ValidateStoredRef(inaccessible));canaccessvalue=nil
local cycle={};cycle.again=cycle
assert(not V:_ValidateStoredRef(cycle))
assert(not V:_ValidateStoredRef(setmetatable({},{__index=function() error("must not read") end})))
local copies,original={},B.Copy
B.Copy=function(self,value,field,...)
 copies[field]=(copies[field] or 0)+1
 return original(self,value,field,...)
end
local record=assert(f.I.Providers:ReadEntry(providerID,"setting:memory_toggle_1"))
assert(#record.actions==5 and record.primaryActionID=="toggle")
B.Copy=original
assert(not copies.reference,"reader copied already-owned invocation references")
assert(not copies.schema,"reader copied read-only action schemas")
assert(copies.args==5,"normalization should copy external args once per action")
collectgarbage("collect");local before=collectgarbage("count")
collectgarbage("stop");local start=os.clock()
for n=1,10 do local _,hits=f.I.Search.Query:Query("test toggle",{visible=true});assert(#hits==20) end
local elapsed=(os.clock()-start)*1000;local allocation=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect")
print(string.format("INVOCATION ALLOCATION 10_queries_KiB=%.2f cpu_ms=%.2f retained_growth_KiB=%.2f",allocation,elapsed,collectgarbage("count")-before))
assert(handle:Unregister())
print("Invocation allocation PASS: isolated public results, no redundant reader reference/schema copies")
