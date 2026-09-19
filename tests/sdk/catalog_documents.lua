local clock,timers=0,{}
function GetLocale() return 'enUS' end
function GetBuildInfo() return '12.1.0','69814','fixture',120100 end
function GetTimePreciseSec() return clock end
function InCombatLockdown() return false end
C_Timer={NewTimer=function(delay,fn)
 local t={due=clock+delay,callback=fn};function t:Cancel() self.cancelled=true end;timers[#timers+1]=t;return t
end}
dofile('tests/support/runtime.lua').Load('provider',{'Core/InvocationRuntime.lua','PublicAPI/Invocation.lua'})
local I=LycheeInternal;I.Registry:SetReady(true)
local function step()
 table.sort(timers,function(a,b) return a.due<b.due end)
 local t=table.remove(timers,1);if not t then return false end
 if not t.cancelled then clock=math.max(clock+.001,t.due);t.callback() end;return true
end
local function drain() local count=0;while step() do count=count+1;assert(count<1000,'unbounded timer chain') end end
local built,mode,cat,provider=0,'ok'
local original={};for n=1,120 do original[n]={id='entry:'..n,title='Target '..n,aliases={'Alias '..n},description='Document details',category={id='group',title='Group',order=1}} end
local function read(id,ctx)
 built=built+1;assert(ctx.revision>=1 and ctx.ref.entryID==id and ctx.ref.providerID=='documents.fixture')
 assert(ctx.reason=='query' or ctx.reason=='resolve')
 if mode=='throw' then error('reader failed') end
 if mode=='error' then return nil,{code='PROVIDER_UNAVAILABLE'} end
 if mode=='wrong-id' then return {id='wrong',title='Wrong',actions={'open'}} end
 if mode=='wrong-action' then return {id=id,title='Wrong',actions={'unknown'}} end
 if mode=='invalidate' then mode='ok';assert(cat:Invalidate()) end
 local n=assert(id:match('entry:(%d+)'))
 return {id=id,title='Target '..n,payload={value=tonumber(n)},actions={'open'}}
end
local options={id='documents.fixture',mode='documents',readEntry=read,scope={products={'retail'}},
 actions={open={title='Open',run=function() return {ok=true} end}},changed=function() if provider then provider:Invalidate() end end}
cat=assert(Lychee.SDK.CreateCatalog(options));assert(cat:Update({replace=original}));original[1].title='Mutated caller'
assert(built==0,'document ingestion must not build Entry')
local r=assert(cat:Search({normalized='target',limit=20}));assert(#r==20 and built==20 and r[1].entry.actions[1]=='open')
assert(r[1].evidence.matchedField=='title')
assert(#assert(cat:Search({normalized='target',limit=30}))==30,'explicit limit30 was truncated')
for _,field in ipairs({'replace','upsert','remove'}) do
 for _,bad in ipairs({false,true,1,'bad'}) do
  local before=cat:GetState();local ok,err=cat:Update({[field]=bad})
  assert(not ok and err and cat:GetState().revision==before.revision and cat:GetState().entries==before.entries,'invalid delta changed documents: '..field)
 end
end
local plainCalls=0
cat:Query({normalized='target',limit=30},function(hits) plainCalls=plainCalls+1;assert(#hits==30);return true end)
assert(plainCalls==1,'standalone Query did not deliver ordinary callback')
do
 local entries=assert(Lychee.SDK.CreateCatalog({id='entries.delta',actions=options.actions}))
 assert(entries:Update({replace={{id='kept',title='Kept',actions={'open'}}}}))
 for _,field in ipairs({'replace','upsert','remove'}) do
  local before=entries:GetState();assert(not entries:Update({[field]=false}))
  assert(entries:GetState().revision==before.revision and entries:Resolve('kept'),'invalid delta changed entries')
 end
 entries:Close()
end
do
 local generated=0
 local variants=assert(Lychee.SDK.CreateCatalog({id='documents.variants',mode='documents',
  actions={set={title='Set',actionVersion=1,absolute=true,conflictKey='value',schema={percent={type='integer',min=0,max=100,required=true}},run=function() error('must not execute') end}},
  readEntry=function(id)
   generated=generated+1;local n=tonumber(id:match('%d+'))
   return {id=id,title='Target',actions={'set'},invocation={kind='invocation',product='retail',providerID='documents.variants',
    actionID='set',actionVersion=1,target={version=1,key={channel='master'}},args={percent=n<=20 and 30 or 70}}}
  end}))
 local documents={};for n=1,30 do documents[n]={id=string.format('doc:%03d',n),title='Target'} end
 assert(variants:Update({replace=documents}))
 local hits=assert(variants:Search({normalized='target',limit=2}))
 assert(#hits==2 and generated==21 and hits[1].entry.invocation.args.percent==30 and hits[2].entry.invocation.args.percent==70,'unique 21st reference was truncated')
 hits=assert(variants:Search({normalized='target',limit=30}));assert(#hits==2,'same complete reference was not deduplicated')
 variants:Close()
 local bounded=assert(Lychee.SDK.CreateCatalog({id='documents.bound',mode='documents',readEntry=function(id)
  generated=generated+1
  return {id=id,title='Target',actions={'open'},targetRef={kind='target',product='retail',providerID='documents.bound',target={version=1,key={value='same'}}}}
 end,actions=options.actions}))
 -- Ordinary records give distinct refs; use a target reference for all documents.
 for n=31,257 do documents[n]={id=string.format('doc:%03d',n),title='Target'} end
 assert(bounded:Update({replace=documents}));generated=0
 local value,err=bounded:Search({normalized='target',limit=20})
 assert(not value and err.code=='RESULT_LIMIT' and generated==256,'unseen unique matches must not be silently truncated')
 assert(bounded:Update({remove={'doc:257'}}));generated=0
 hits=assert(bounded:Search({normalized='target',limit=20}));assert(#hits==1 and generated==256,'exactly exhausted duplicate candidates remain complete')
 bounded:Close()
end
do
 local exhausted=I.Resources:Create(function() return true end)
 for n=1,64 do assert(exhausted:Own('busy:'..n,function() end)) end
 local failed=0
 local ok,err=cat:Query({normalized='target'},function() error('full scope delivered') end,
  {resources=exhausted,deadline=clock+5,fail=function(problem) failed=failed+1;assert(problem.code=='RESOURCE_LIMIT') end})
 assert(not ok and err.code=='RESOURCE_LIMIT' and failed==1,'resource acquisition did not settle exactly once')
 I.Resources:Close(exhausted)
end
do
 local scope=I.Resources:Create(function() return true end)
 local occupied={};for n=1,63 do occupied[n]=assert(scope:Own('busy:'..n,function() end)) end
 local failed,calls=0,0
 local ctx={resources=scope,deadline=clock+5}
 ctx.fail=function(problem)
  failed=failed+1;assert(problem.code=='RESOURCE_LIMIT')
  assert(scope:GetDiagnostics().resources==63,'failed Run leaked its owner')
  occupied[1]:Cancel();occupied[2]:Cancel()
  assert(cat:Query({normalized='target',limit=30},function(hits) calls=calls+1;assert(#hits==30);return true end,
   {resources=scope,deadline=clock+5,fail=function() error('reentrant query failed') end}))
 end
 local ok,err=cat:Query({normalized='target'},function() error('failed query delivered') end,ctx)
 assert(not ok and err.code=='RESOURCE_LIMIT' and failed==1)
 drain();assert(calls==1 and scope:GetDiagnostics().resources==61,'failure cleanup cancelled reentrant task')
 I.Resources:Close(scope)
end
do
 local scope=I.Resources:Create(function() return true end);local calls,failed=0,0
 assert(cat:Query({normalized='target'},function() calls=calls+1;return true end,{resources=scope,deadline=clock+5,fail=function() error('older query failed') end}))
 for n=1,62 do assert(scope:Own('busy:'..n,function() end)) end
 local ok=cat:Query({normalized='target'},function() error('new query delivered') end,{resources=scope,deadline=clock+5,fail=function() failed=failed+1 end})
 assert(not ok and failed==1);drain();assert(calls==1,'new resource failure replaced older query')
 I.Resources:Close(scope)
end
r[1].entry.payload.value=999
assert(cat:Resolve('entry:1').payload.value==1)
local revision=cat:GetState().revision
assert(cat:Update({upsert={{id='entry:1',title='Target 1',aliases={'Alias 1'},description='Document details',category={id='group',title='Group',order=1}}}}))
assert(cat:GetState().revision==revision,'unchanged docs keep revision')
assert(not cat:Update({upsert={{id='entry:1',title='Bad',actions={'open'}}}}))
assert(cat:GetState().revision==revision)
for _,bad in ipairs({'wrong-id','wrong-action','error','throw','invalidate'}) do
 mode=bad;local value,err=cat:Search({normalized='target'});assert(not value and err,bad)
end
mode='ok'
provider=assert(Lychee:RegisterProvider({id=options.id,title='Documents',version='1',apiVersion='1.0.0',scope=options.scope,i18n={enUS={}},actions=options.actions,
 query=function(req,reply,ctx) local ok,err=cat:Query(req,reply,ctx);if not ok then ctx.fail(err) end end,
 resolve=function(id) return cat:Resolve(id) end}))
local final,pending,partial
I.Search.Query:Query('Target',{visible=true},1,function(items,_,wait,incomplete) final,pending,partial=items,wait,incomplete end)
assert(I.Providers:HasPendingQuery(),'documents work uses resources')
drain();assert(final and #final==20 and not pending and not partial)
assert(not I.Providers:HasPendingQuery())
mode='error';final=nil
I.Search.Query:Query('Target',{visible=true},2,function(items,_,wait,incomplete) final,pending,partial=items,wait,incomplete end)
drain();assert(final and #final==0 and not pending and partial)
mode='ok';final=nil
I.Search.Query:Query('Target',{visible=true},3,function(items) final=items end)
I.Providers:CancelQueries('fixture-cancel');drain();assert(not I.Providers:HasPendingQuery() and not final)
-- Query again after cancellation; a callback invalidates its own reader generation.
mode='invalidate';final=nil
I.Search.Query:Query('Target',{visible=true},4,function(items,_,wait,incomplete) final,pending,partial=items,wait,incomplete end)
drain();assert(not I.Providers:HasPendingQuery())
mode='ok';assert(cat:Resolve('entry:2').payload.value==2)
assert(cat:Clear());assert(cat:GetState().entries==0)
assert(cat:Resolve('entry:2').payload.value==2,'explicit restore does not require search index')
assert(cat:Update({replace={{id='entry:1',title='Target 1'}}}))
local calls=0
local scope=I.Resources:Create(function() return true end)
assert(cat:Query({normalized='target'},function() calls=calls+1 end,{resources=scope,deadline=clock+5,fail=function() cat:Close() end}))
assert(cat:Clear());drain();assert(calls==0 and not cat:GetState(),'close during failure cleanup is safe')
assert(provider:Unregister())
do
 local factory=I.LycheeSDK._CreateOwnedCompactStore
 assert(type(factory)=='function','Host SDK copy lacks private owned-store assembly')
 local actualStore,stored={},{}
 I.LycheeSDK._CreateOwnedCompactStore=function(config)
  local store,write=factory(config);actualStore=store
  return store,function(delta)
   local ok,err,different,canonical=write(delta)
   if ok then
    if delta.replace then stored={} end
    for _,id in ipairs(delta.remove or {}) do stored[id]=nil end
    for _,record in ipairs(canonical) do stored[record.id]=record end
   end
   return ok,err,different,canonical
  end
 end
 local graph=assert(Lychee.SDK.CreateCatalog({id='compact.graph',mode='documents',actions=options.actions,
  compact={maxEntries=4,maxBytes=2000,maxRecordBytes=500,identity={fixture='graph'}},
  readEntry=function(id) return {id=id,title='Entry '..id,payload={id=id},actions={'open'}} end}))
 I.LycheeSDK._CreateOwnedCompactStore=factory
 local new=I.Search.StaticIndex.New;local builtIndex
 function I.Search.StaticIndex:New() builtIndex=new(self);return builtIndex end
 local input={{id='first',title='Target first',aliases={'Shared'}},{id='second',title='Target second',aliases={'Shared'}}}
 assert(graph:Update({replace=input}));I.Search.StaticIndex.New=new
 local source='compact.graph:records'
 local first=assert(builtIndex:GetRecord(source,'first'))
 assert(first==stored.first and builtIndex:GetRecord(source,'second')==stored.second,'store/index retained different canonical roots')
 assert(first~=input[1] and first.aliases~=input[1].aliases,'caller input reached canonical graph')
 assert(first.aliases==stored.second.aliases,'existing RecordCodec metadata sharing was lost')
 input[1].title='Caller mutation';input[1].aliases[1]='Caller mutation'
 assert(first.title=='Target first' and first.aliases[1]=='Shared')
 local version=graph:GetState().revision
 assert(graph:Update({upsert={{id='first',title='Target first',aliases={'Shared'}},{id='second',title='Target changed',aliases={'Shared'}}}}))
 assert(graph:GetState().revision==version+1 and stored.first==first and builtIndex:GetRecord(source,'first')==first)
 assert(builtIndex:GetRecord(source,'second')==stored.second,'mixed update produced second canonical graph')
 version=graph:GetState().revision
 assert(graph:Update({upsert={{id='first',title='Target first',aliases={'Shared'}}}}))
 assert(graph:GetState().revision==version and stored.first==first)
 local bytes=graph:GetState().bytes
 local ok,err=graph:Update({upsert={{id='too-large',title=string.rep('x',1000)}}})
 assert(not ok and err.code=='DATA_LIMIT' and graph:GetState().revision==version and graph:GetState().bytes==bytes)
 assert(not builtIndex:GetRecord(source,'too-large') and actualStore:Read('first').title=='Target first')
 local public=assert(graph:Search({normalized='target'}));public[1].entry.payload.id='Caller'
 assert(graph:Resolve('first').payload.id=='first')
 assert(graph:Update({remove={'first'}}));assert(not stored.first and not builtIndex:GetRecord(source,'first'))
 assert(graph:Clear());assert(actualStore:GetState().entries==0 and not next(builtIndex.entries))
 assert(graph:Close());local value,problem=actualStore:Read('second');assert(not value and problem.code=='RESOURCE_CLOSED')
end
do
 for _,operation in ipairs({'Clear','Close','Invalidate','Update'}) do
  local scope=I.Resources:Create(function() return true end)
  local notified,delivered=0,0
  local safe=assert(Lychee.SDK.CreateCatalog({id='throwing.cleanup',mode='documents',
   compact={maxEntries=4,maxBytes=2000,maxRecordBytes=500,identity={fixture='throw'}},
   readEntry=function(id) return {id=id,title='Target'} end}))
  assert(safe:Update({replace={{id='one',title='Target'}}}))
  for n=1,3 do assert(safe:Query({normalized='target'},function()delivered=delivered+1 end,
   {resources=scope,deadline=clock+5,fail=function()notified=notified+1;error('consumer-fail-threw')end})) end
  local called,ok=pcall(safe[operation],safe,operation=='Update' and {upsert={{id='one',title='Target changed'}}} or nil)
  assert(called and ok,operation..' escaped a consumer failure callback')
  assert(notified==3 and scope:GetDiagnostics().resources==0,'all pending resources must release despite bad callbacks')
  drain();assert(delivered==0)
  if operation=='Close' then assert(not safe:GetState())
  else
   assert(safe:Update({replace={{id='one',title='Target'}}}),'cleanup poisoned busy state')
   assert(#assert(safe:Search({normalized='target'}))==1)
  end
  safe:Close();I.Resources:Close(scope)
 end
 local scope=I.Resources:Create(function()return true end);local failures=0
 local safe=assert(Lychee.SDK.CreateCatalog({id='throwing.reply',mode='documents',readEntry=function(id)return{id=id,title='Target'}end}))
 assert(safe:Update({replace={{id='one',title='Target'}}}))
 assert(safe:Query({normalized='target'},function()error('consumer-reply-threw')end,
  {resources=scope,deadline=clock+5,fail=function(problem)
   failures=failures+1;assert(problem.code=='CALLBACK_ERROR');error('failure notification also threw')
  end}))
 drain();assert(failures==1 and scope:GetDiagnostics().resources==0,'reply exception lost failure or retained resources')
 assert(safe:Update({replace={{id='one',title='Target next'}}}));safe:Close();I.Resources:Close(scope)
end
print('Catalog documents PASS: lazy generation, isolation, shared canonical storage, revision, failure/cancel, explicit restore, exception-safe cleanup/reentry')
