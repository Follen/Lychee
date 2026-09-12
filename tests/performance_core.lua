-- Lua 5.1 offline boundary allocation and scheduler lifecycle regression.
LycheeInternal = { VERSION={api=2,revision=1} }
local frames = 0
function CreateFrame()
    frames=frames+1
    return {Hide=function(self) self.shown=false end, Show=function(self) self.shown=true end,
        SetScript=function() end}
end
local root=os.getenv('LYCHEE_PERF_ROOT') or 'addon/Lychee/'
dofile(root..'Core/Boundary.lua')
dofile(root..'Core/Scheduler.lua')
dofile(root..'Core/ExtensionRegistry.lua')
local I=LycheeInternal
local record={id='example',kind='entry',title='Example',category={id='sample',title='Sample'},
    actions={{id='open',title='Open',kind='open-panel',panel='main',state={}}},payload={value=1}}
local samples={}
for run=1,5 do
    for n=1,100 do assert(I.Boundary:ValidateSearchRecord(record)) end
    collectgarbage('collect'); collectgarbage('stop')
    local memory,started=collectgarbage('count'),os.clock()
    for n=1,10000 do assert(I.Boundary:ValidateSearchRecord(record)) end
    samples[run]={ms=(os.clock()-started)*1000,kib=collectgarbage('count')-memory}
    collectgarbage('restart')
end
for run,sample in ipairs(samples) do
    print(string.format('boundary run=%d records=10000 ms=%.3f allocated_kib=%.3f',run,sample.ms,sample.kib))
    if arg[1]~='--measure' then
        assert(sample.kib<8192,'boundary allocation budget: 10000 validations must allocate <8192 KiB')
    end
end
local S=I.Scheduler
local function noop() end
for _,count in ipairs({1,16,256}) do
    for n=1,count do assert(S:Add(n,noop)) end
    for n=1,100 do S:_Tick(.01) end
    collectgarbage('collect'); collectgarbage('stop')
    local memory,started=collectgarbage('count'),os.clock()
    for n=1,1000 do S:_Tick(.01) end
    print(string.format('scheduler subscribers=%d ticks=1000 ms=%.3f allocated_kib=%.3f',count,(os.clock()-started)*1000,collectgarbage('count')-memory))
    collectgarbage('restart'); S:Clear()
end
collectgarbage('collect')
local retained=collectgarbage('count')
for n=1,2000 do assert(I.Registry:RegisterReady(noop)):Cancel() end
collectgarbage('collect')
print(string.format('ready cancellations=2000 retained_kib=%.3f pending=%d',collectgarbage('count')-retained,#I.Registry.readyListeners))
if arg[1]=='--measure' then return end
local called=0
S:Add('first',function() S:Add('later',function() called=called+1; return false end); return false end)
S:_Tick(.01)
assert(called==0,'callback Add must take effect next tick')
S:_Tick(.01); assert(called==1 and #S.keys==0 and not S.frame.shown)
local old,new=0,0
S:Add('replace',function() old=old+1; S:Add('replace',function() new=new+1; return false end); return false end)
S:_Tick(.01); assert(old==1 and new==0 and S.active.replace,'old completion must not remove replacement')
S:_Tick(.01); assert(new==1)
local calls=0
S:Add('reentrant',function() calls=calls+1; if calls==1 then S:_Tick(.01) end; return false end)
S:_Tick(.01); assert(calls==1,'reentrant Tick must not execute callback twice')
S:Add('a',function() S:Remove('b'); return false end)
S:Add('b',function() error('removed callback ran') end)
S:Add('c',function() calls=calls+1; return false end)
S:_Tick(.01); assert(calls==2 and #S.keys==0,'swap removal must not skip remaining subscription')
S:Add('clear',function() S:Clear(); S:Add('after',function() calls=calls+1; return false end); return false end)
S:Add('discard',function() error('cleared callback ran') end)
S:_Tick(.01); assert(calls==2); S:_Tick(.01); assert(calls==3)
S:Add('error',function() error('expected callback error') end)
assert(not pcall(S._Tick,S,.01)); assert(not S.active.error,'failed subscription must stop repeated frame errors')
S:Add('recover',function() calls=calls+1; return false end)
S:_Tick(.01); assert(calls==4,'callback failure must release reentry guard')
for n=1,S.limit do assert(S:Add(n,function() end)) end
local accepted,why=S:Add('overflow',function() end)
assert(accepted==false and why=='TASK_LIMIT','overload must explicitly reject')
assert(S:Add(1,function() end),'replacement remains legal at capacity')
S:Clear(); assert(not S.frame.shown and #S.keys==0)
for n=1,2000 do assert(I.Registry:RegisterReady(function() end)):Cancel() end
assert(#I.Registry.readyListeners==0,'cancelled ready subscriptions must leave no retained tombstones')
print('performance_core regression passed; scheduler frame count='..frames)
