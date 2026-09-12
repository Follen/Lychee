function GetLocale() return 'enUS' end
function GetBuildInfo() return '12.1.0','12345','today',120100 end
function InCombatLockdown() return false end
UIParent={}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end,Hide=function() end,Show=function() end} end
C_Timer={NewTimer=function(_,callback) return {callback=callback,Cancel=function(self) self.cancelled=true end} end}
local root=os.getenv('LYCHEE_PERF_ROOT') or 'package/Lychee/'
local coreRoot=os.getenv('LYCHEE_PERF_CORE_ROOT') or root
for _,path in ipairs({'Bootstrap.lua', 'Core/CharacterStore.lua', 'Builtin/Definitions.lua','Builtin/Shared/Support.lua','Core/ProviderLocales.lua','Core/ContextStore.lua','Search/RuntimeIdentity.lua','Search/Normalizer.lua',
    'Search/Storage.lua', 'Search/StaticIndex.lua','Core/CommandCatalog.lua','Core/CapabilityBroker.lua','Core/Boundary.lua',
    'Core/IntentRouter.lua','Core/Scheduler.lua','Core/ExtensionRegistry.lua','Search/QueryOrchestrator.lua',
    'Core/ProviderRuntime.lua','PublicAPI/SDK.lua'}) do dofile((path:match('^Core/') and coreRoot or root)..path) end
local I=LycheeInternal
I.Registry:SetReady(true)
local entries={}
for n=1,500 do entries[n]={id='item'..n,title='Entry '..n,payload={value=n}} end
local replies={}
local handle=assert(Lychee:RegisterProvider({id='perf.core',title='Core',version='1.0',apiVersion=2,entries=entries,
    query=function(_,reply) replies[#replies+1]=reply end}))
for run=1,5 do
    collectgarbage('collect'); collectgarbage('stop')
    local memory,started=collectgarbage('count'),os.clock()
    for n=1,100 do assert(handle:Update({upsert={{id='item1',title='Update '..run..'-'..n}}})) end
    local allocated=collectgarbage('count')-memory
    print(string.format('provider run=%d directory=500 single_updates=100 ms=%.3f allocated_kib=%.3f',run,(os.clock()-started)*1000,allocated))
    collectgarbage('restart')
    if arg[1]~='--measure' then
        assert(allocated<768,'provider allocation budget: 100 single-record updates must allocate <768 KiB')
    end
end
if arg[1]=='--measure' then return end
local request={normalized='entry',filter={sourceID='perf.core:records'}}
for n=1,200 do I.Providers:Search(request,{},function() end) end
local jobs=0; for _ in pairs(I.Providers.jobs) do jobs=jobs+1 end
print('provider pending jobs after 200 searches='..jobs)
assert(jobs==1,'superseded requests must not accumulate jobs')
local ok,err=replies[1]({{id='old',title='Old'}})
assert(not ok and err.code=='STALE_REQUEST','old query cannot publish')
assert(handle:Update({upsert={{id='changed',title='Changed'}}}))
ok,err=replies[#replies]({{id='old',title='Old'}})
assert(not ok and err.code=='STALE_REQUEST','old provider revision cannot publish')
I.Providers:CancelQueries('test')
assert(next(I.Providers.jobs)==nil)
assert(handle:Unregister())
local reentered=false
local reentrant=assert(Lychee:RegisterProvider({id='perf.reentrant',title='Reentrant',version='1',apiVersion=2,
    query=function() return function()
        if not reentered then reentered=true; I.Providers:Search({normalized='new'}, {}) end
    end end}))
I.Providers:Search({normalized='first'}, {})
I.Providers:Search({normalized='second'}, {})
jobs=0; for _ in pairs(I.Providers.jobs) do jobs=jobs+1 end
assert(jobs==1,'cancel callback reentry must leave only newest query')
assert(reentrant:Unregister() and next(I.Providers.jobs)==nil)
print('perf_core_provider regression passed')
