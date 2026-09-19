-- Standalone SDK module: no Host, native UI, timers, or private state.
local Store=assert(loadfile('lychee-sdk/CompactStore.lua'))()
assert(Store._CreateOwnedCompactStore==nil,'internal creator leaked through public module')
do
 local s,e=Store.Create({maxEntries=2,maxBytes=4096,maxRecordBytes=1024})
 assert(not s and e.code=='INVALID_SCHEMA','identity must be explicit')
end
local function create(overrides)
 local config={maxEntries=3,maxBytes=1000,maxRecordBytes=500,identity={product='retail',locale='enUS',revision='fixture-1'}}
 for k,v in pairs(overrides or {}) do config[k]=v end
 return Store.Create(config)
end
for _,n in ipairs({0,-1,1.5,math.huge,9007199254740992}) do local s,e=create({maxBytes=n});assert(not s and e.code=='INVALID_SCHEMA') end
local s=assert(create());local row={id='first',title='Alpha',aliases={'One'}}
assert(s:Update({replace={row}}));row.aliases[1]='mutated'
assert(s:Read('first').aliases[1]=='One')
local state=s:GetState();state.identity.locale='changed';assert(s:GetState().identity.locale=='enUS')
local r=s:Read('first');r.aliases[1]='changed';assert(s:Read('first').aliases[1]=='One')
local out={unrelated=true};assert(s:Read('first',out)==out and out.unrelated==nil)
local version=s:GetState().revision
assert(s:Update({upsert={{id='first',title='Alpha',aliases={'One'}}}}));assert(s:GetState().revision==version)
local iterator=assert(s:Iterate(version));assert(iterator()=='first' and iterator()==nil)
iterator=assert(s:Iterate(version));assert(s:Update({upsert={{id='second',title='Beta'}}}))
local value,e=iterator();assert(not value and e.code=='STALE_RESULT')
value,e=s:Read('first',nil,version);assert(not value and e.code=='STALE_RESULT')
local old=s:GetState().revision
local ok,err=s:Update({upsert={{id='huge',title=string.rep('x',600)}}});assert(not ok and err.code=='DATA_LIMIT')
assert(s:GetState().revision==old and not s:Read('huge') and s:Read('first'))
ok,err=s:Update({replace={{id='same',title='One'},{id='same',title='Two'}}});assert(not ok and err.code=='DUPLICATE_ID')
assert(s:GetState().entries==2 and s:GetState().revision==old)
ok,err=s:Update({upsert={{id='third',title='Third'},{id='fourth',title='Fourth'}}});assert(not ok and err.code=='RESULT_LIMIT')
assert(s:GetState().entries==2)
for _,field in ipairs({'replace','upsert','remove'}) do
 for _,bad in ipairs({false,true,1,'bad'}) do
  local before=s:GetState();local ok,err=s:Update({[field]=bad})
  assert(not ok and err and s:GetState().revision==before.revision and s:GetState().entries==before.entries,'invalid delta changed store: '..field)
 end
end
do
 local oldSecret=issecretvalue
 issecretvalue=function(value) return value=='sensitive-key' end
 local config={maxEntries=2,maxBytes=4096,maxRecordBytes=1024,identity={}}
 config['sensitive-key']=true
 local value,err=Store.Create(config)
 assert(not value and err and not tostring(err.field):find('sensitive-key',1,true),'secret config key was reflected')
 local value,err=s:Update({['sensitive-key']=true})
 assert(not value and err and not tostring(err.field):find('sensitive-key',1,true),'secret delta key was reflected')
 local output={['sensitive-key']=true,keep=true}
 value,err=s:Read('first',output)
 assert(not value and err and output.keep,'secret output key was deleted')
 assert(not s:Update({remove={['sensitive-key']='first'}}))
 issecretvalue=oldSecret
end
assert(s:Update({remove={'first'},upsert={{id='third',title='Third'}}}));assert(not s:Read('first') and s:Read('third'))
local cycle={id='cycle'};cycle.loop=cycle;assert(not s:Update({upsert={cycle}}))
assert(not s:Update({upsert={setmetatable({id='meta',title='No'},{})}}))
assert(not s:Update({remove={'third','third'}}))
assert(not s:Update({remove={'third'},upsert={{id='third',title='Conflicting'}}}))
local limited=assert(create({maxBytes=120,maxRecordBytes=120}))
assert(limited:Update({replace={{id='a',title='a'}}}))
local before=limited:GetState().revision
assert(not limited:Update({upsert={{id='b',title=string.rep('b',80)}}}))
assert(limited:GetState().entries==1 and limited:GetState().revision==before)
iterator=assert(s:Iterate());assert(s:Clear());value,e=iterator();assert(not value and e.code=='STALE_RESULT')
assert(s:GetState().bytes==0 and s:GetState().entries==0)
assert(s:Close() and s:Close());value,e=s:Read('third');assert(not value and e.code=='RESOURCE_CLOSED')
do
 local namespace={};local public=assert(loadfile('lychee-sdk/CompactStore.lua'))('owned.fixture',namespace)
 local config={maxEntries=3,maxBytes=1000,maxRecordBytes=500,identity={source='owned.fixture'}}
 local standalone,hidden=public.Create(config,true)
 assert(standalone and hidden==nil and standalone.UpdateOwned==nil,'public Create exposed ownership capability')
 standalone:Close()
 local owned,write=namespace.LycheeSDK._CreateOwnedCompactStore(config)
 assert(owned and type(write)=='function' and owned.UpdateOwned==nil)
 local first={id='a',title='A',aliases={'Shared'}}
 local second={id='b',title='B',aliases=first.aliases}
 local ok,err,different,canonical=write({replace={first,second}})
 assert(ok and different and canonical[1]==first and canonical[2]==second and canonical[1].aliases==canonical[2].aliases)
 local isolated=owned:Read('a');isolated.aliases[1]='caller';assert(owned:Read('a').aliases[1]=='Shared')
 local revision=owned:GetState().revision
 local changed={id='b',title='Changed',aliases={'Shared'}}
 ok,err,different,canonical=write({upsert={{id='a',title='A',aliases={'Shared'}},changed}})
 assert(ok and different and canonical[1]==first and canonical[2]==changed,'mixed update split unchanged canonical root')
 assert(owned:GetState().revision==revision+1)
 ok,err,different,canonical=write({upsert={{id='a',title='A',aliases={'Shared'}}}})
 assert(ok and not different and canonical[1]==first,'unchanged transfer lost original canonical root')
 local before=owned:GetState()
 ok,err=write({upsert={{id='bad',title=string.rep('x',600)}}})
 assert(not ok and err.code=='DATA_LIMIT' and owned:GetState().revision==before.revision and owned:Read('b').title=='Changed')
 local incoming={id='c',title='Public',aliases={'Value'}}
 local leaked;ok,err,different,leaked=owned:Update({upsert={incoming}})
 assert(ok and leaked==nil,'public Update leaked canonical records')
 incoming.aliases[1]='mutated';assert(owned:Read('c').aliases[1]=='Value','owned instance public Update must still copy')
 assert(owned:Clear());assert(owned:GetState().entries==0)
 assert(write({replace={{id='after-clear',title='Again'}}}))
 assert(owned:Close());ok,err=write({replace={first}});assert(not ok and err.code=='RESOURCE_CLOSED')
end
print('CompactStore PASS: independent SDK, finite explicit budgets, isolation, atomic failure/update, revision, iterator, clear/close')
