-- Optional caller-owned search storage. Initial bounded named representation;
-- encoding is deliberately internal and may change after measured comparisons.
local Store={}
local function fail(code,field) return nil,{code=code,field=field,retryable=false} end
local function integer(n) return type(n)=='number' and n==n and n>=1 and n<=9007199254740991 and n%1==0 end
local function access(v)
 if issecretvalue then local ok,value=pcall(issecretvalue,v);if not ok or value then return false end end
 if canaccessvalue then local ok,value=pcall(canaccessvalue,v);if not ok or not value then return false end end
 if type(v)=='table' and canaccesstable then local ok,value=pcall(canaccesstable,v);if not ok or not value then return false end end
 return true
end
local function plain(v) return access(v) and type(v)=='table' and getmetatable(v)==nil end
local function idOK(id) return access(id) and type(id)=='string' and #id>0 and #id<=128 and id:match('^[A-Za-z0-9][A-Za-z0-9%._:/%-]*$') end
local function copy(v,budget,seen,depth,owned)
 if not access(v) then return fail('INACCESSIBLE_VALUE') end
 local kind=type(v);budget.bytes=budget.bytes+(kind=='string' and #v or 16)
 if budget.bytes>budget.limit then return fail('DATA_LIMIT') end
 if kind=='string' or kind=='boolean' or kind=='nil' then return v end
 if kind=='number' then if v==v and v~=math.huge and v~=-math.huge then return v end;return fail('INVALID_SCHEMA') end
 if not plain(v) or seen[v] or depth>=8 then return fail('INVALID_SCHEMA') end
 seen[v]=true;local out,n=owned and v or {},0
 for k,x in pairs(v) do
  n=n+1;if n>128 or not access(k) or type(k)~='string' and type(k)~='number' then return fail('INVALID_SCHEMA') end
  local key,err=copy(k,budget,seen,depth+1,owned);if err then return nil,err end
  local value;value,err=copy(x,budget,seen,depth+1,owned);if err then return nil,err end
  if not owned then out[key]=value end
 end
 seen[v]=nil;return out
end
local function clone(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v) do out[k]=clone(x) end;return out
end
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,x in pairs(a) do if not same(x,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local function array(v,maximum)
 if not plain(v) or #v>maximum then return false end
 local n=0;for k in pairs(v) do if not access(k) or type(k)~='number' or k%1~=0 or k<1 or k>#v then return false end;n=n+1 end
 return n==#v
end
local function create(config,ownedAccess)
 if not plain(config) then return fail('INVALID_SCHEMA','compact') end
 for k in pairs(config) do
  if not access(k) then return fail('INACCESSIBLE_VALUE','compact') end
  if k~='maxEntries' and k~='maxBytes' and k~='maxRecordBytes' and k~='identity' then return fail('INVALID_SCHEMA','compact') end
 end
 for _,key in ipairs({'maxEntries','maxBytes','maxRecordBytes'}) do
  if not access(config[key]) or not integer(config[key]) then return fail('INVALID_SCHEMA','compact.'..key) end
 end
 local maxEntries,maxBytes,maxRecordBytes=config.maxEntries,config.maxBytes,config.maxRecordBytes
 if not plain(config.identity) then return fail('INVALID_SCHEMA','compact.identity') end
 local identity,err=copy(config.identity,{bytes=0,limit=4096},{},0)
 if err or type(identity)~='table' then return nil,err or {code='INVALID_SCHEMA',field='compact.identity'} end
 local records,sizes,count,bytes,revision,closed={}, {},0,0,0,false
 local handle={}
 local function current(expected)
  if closed then return fail('RESOURCE_CLOSED','compact') end
  if not access(expected) then return fail('INACCESSIBLE_VALUE','compact.revision') end
  if expected~=nil and expected~=revision then return fail('STALE_RESULT','compact.revision') end
  return true
 end
 local function update(delta,owned)
  local ok,why=current();if not ok then return nil,why end
  if not plain(delta) then return fail('INVALID_SCHEMA','compact.update') end
  for k,v in pairs(delta) do
   if not access(k) or not access(v) then return fail('INACCESSIBLE_VALUE','compact.update') end
   if k~='replace' and k~='upsert' and k~='remove' then return fail('INVALID_SCHEMA','compact.update') end
  end
  if delta.replace~=nil and (delta.upsert~=nil or delta.remove~=nil) then return fail('INVALID_SCHEMA','compact.replace') end
  for _,field in ipairs({'replace','upsert','remove'}) do
   if delta[field]~=nil and not array(delta[field],maxEntries) then return fail('INVALID_SCHEMA','compact.'..field) end
  end
  local list=delta.replace or delta.upsert or {};local removed=delta.remove or {}
  if not array(list,maxEntries) or not array(removed,maxEntries) then return fail('RESULT_LIMIT','compact.update') end
  local pending,pendingSizes,seen,incomingBytes={}, {},{},0
  local accepted=owned and {} or nil
  for n,raw in ipairs(list) do
   if not plain(raw) or not idOK(raw.id) then return fail('INVALID_SCHEMA','compact.record.id') end
   if seen[raw.id] then return fail('DUPLICATE_ID','compact.record.id') end
   local budget={bytes=0,limit=math.min(maxRecordBytes,maxBytes-incomingBytes)};local record;record,why=copy(raw,budget,{},0,owned)
   if why then return nil,why end
   incomingBytes=incomingBytes+budget.bytes
   -- Index consumers retain unchanged canonical roots. Reuse the same root in
   -- mixed updates so a new equal record cannot create an invisible second graph.
   if records[raw.id] and same(records[raw.id],record) then record=records[raw.id] end
   seen[raw.id]=true;pending[raw.id],pendingSizes[raw.id]=record,budget.bytes
   if accepted then accepted[n]=record end
  end
  local deleted={}
  for _,id in ipairs(removed) do
   if not idOK(id) or deleted[id] or seen[id] then return fail('INVALID_SCHEMA','compact.remove') end
   deleted[id]=true
  end
  local nextCount,nextBytes=delta.replace~=nil and 0 or count,delta.replace~=nil and 0 or bytes
  local different=delta.replace~=nil and #list~=count or false
  if delta.replace==nil then
   for id in pairs(deleted) do if records[id] then nextCount=nextCount-1;nextBytes=nextBytes-sizes[id];different=true end end
  end
  for id,record in pairs(pending) do
   local old=delta.replace==nil and records[id]
   if old then nextBytes=nextBytes-sizes[id] else nextCount=nextCount+1 end
   nextBytes=nextBytes+pendingSizes[id]
   if not same(records[id],record) then different=true end
  end
  if nextCount>maxEntries then return fail('RESULT_LIMIT','compact') end
  if nextBytes>maxBytes then return fail('DATA_LIMIT','compact') end
  if not different then return true,nil,false,accepted end
  local nextRecords,nextSizes={},{}
  if delta.replace==nil then for id,record in pairs(records) do if not deleted[id] then nextRecords[id],nextSizes[id]=record,sizes[id] end end end
  for id,record in pairs(pending) do nextRecords[id],nextSizes[id]=record,pendingSizes[id] end
  records,sizes,count,bytes=nextRecords,nextSizes,nextCount,nextBytes;revision=revision+1
  return true,nil,true,accepted
 end
 function handle:Update(delta)
  -- Never return canonical records through the public object.
  local ok,err,different=update(delta,false);return ok,err,different
 end
 function handle:Read(id,out,expected)
  local ok,why=current(expected);if not ok then return nil,why end
  if not access(out) then return fail('INACCESSIBLE_VALUE','compact.read') end
  if not idOK(id) or out~=nil and not plain(out) then return fail('INVALID_SCHEMA','compact.read') end
  if out then for key in pairs(out) do if not access(key) then return fail('INACCESSIBLE_VALUE','compact.read') end end end
  local record=records[id];if not record then return nil end
  local value=clone(record)
  if out then for k in pairs(out) do out[k]=nil end;for k,x in pairs(value) do out[k]=x end;return out end
  return value
 end
 function handle:Iterate(expected)
  local ok,why=current(expected);if not ok then return nil,why end
  local readRevision,key,done=revision,nil,false
  return function()
   if done then return nil end
   local valid,err=current(readRevision);if not valid then done=true;return nil,err end
   key=next(records,key);if not key then done=true end;return key
  end
 end
 function handle:GetState()
  local ok,why=current();if not ok then return nil,why end
  return {revision=revision,entries=count,bytes=bytes,maxEntries=maxEntries,maxBytes=maxBytes,maxRecordBytes=maxRecordBytes,identity=clone(identity)}
 end
 function handle:Clear()
  if closed then return true end
  records,sizes,count,bytes={}, {},0,0;revision=revision+1;return true
 end
 function handle:Close()
  if closed then return true end
  self:Clear();closed=true;identity=nil;return true
 end
 if ownedAccess then return handle,function(delta) return update(delta,true) end end
 return handle
end
function Store.Create(config) return create(config,false) end
local _,namespace=...
if type(namespace)=='table' then
 namespace.LycheeSDK=namespace.LycheeSDK or {};namespace.LycheeSDK.CompactStore=Store
 -- Assembly-only ownership capability. It creates a new private instance and
 -- is absent from the public module/object; it cannot open an existing store.
 namespace.LycheeSDK._CreateOwnedCompactStore=function(config) return create(config,true) end
end
return Store
