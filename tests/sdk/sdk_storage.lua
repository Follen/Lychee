local Storage=dofile("lychee-sdk/Storage.lua")
local db,ready={},false
local function options(id,version,migrations)
    return {id=id,version=version or 1,migrations=migrations,root=function() return db end,ready=function() return ready end}
end
local function fails(code,ok,err) assert(ok==nil and err and err.code==code,"expected "..code..", got "..tostring(err and err.code)) end
local configReads=0
fails("INVALID_SCHEMA",Storage.Open(setmetatable({}, {__index=function(_,key) configReads=configReads+1;return options("meta")[key] end})))
assert(configReads==0,"Storage.Open invoked an untrusted configuration metatable")
local secretConfig=options("secret",999)
_G.issecretvalue=function(value) return value==999 end
local secretHandle,secretError=Storage.Open(secretConfig)
_G.issecretvalue=nil
fails("INVALID_SCHEMA",secretHandle,secretError)
local inheritedSteps=options("steps",2,setmetatable({}, {__index=function() error("migration metatable read") end}))
fails("INVALID_SCHEMA",Storage.Open(inheritedSteps))
local unknownConfig=options("unknown");unknownConfig.extra=true
fails("INVALID_SCHEMA",Storage.Open(unknownConfig))
local first=assert(Storage.Open(options("one")))
fails("STORAGE_NOT_READY",first:Get("test"))
assert(next(db)==nil,"opening storage never writes or captures an unrestored SV")
ready=true
assert(first:Get("missing","default")=="default" and next(db)==nil)
local second=assert(Storage.Open(options("two")))
assert(first:Set("test",{value=1}));assert(second:Set("test",2))
local result=first:Get("test");result.value=100
assert(first:Get("test").value==1 and second:Get("test")==2,"isolated values and namespaces")
local original=db.one
fails("DATA_LIMIT",first:Set("oversize",string.rep("x",16385)))
assert(db.one==original,"failed write leaves original slot")
local cycle={};cycle.loop=cycle
fails("INVALID_SETTINGS",first:Set("cycle",cycle))
db={};assert(first:Get("test")==nil,"root replaced after role restore is read fresh")
assert(first:Set("test",3))
local upgraded=assert(Storage.Open(options("one",2,{[1]=function(values) values.test=values.test+1;return values end})))
fails("STORAGE_MIGRATION_REQUIRED",upgraded:Get("test"))
local sibling=db.two
assert(upgraded:Migrate() and upgraded:Get("test")==4 and db.two==sibling)
fails("STORAGE_NEWER_VERSION",first:Set("test",9))
original=db.one
local bad=assert(Storage.Open(options("one",3,{[2]=function(values) values.test=99;error("broken") end})))
fails("STORAGE_MIGRATION_FAILED",bad:Migrate())
assert(db.one==original and db.one.values.test==4,"failed migration preserves original")
local swapped=assert(Storage.Open(options("one",3,{[2]=function(values) db={};return values end})))
fails("STALE_STORAGE",swapped:Migrate())
assert(next(db)==nil,"migration cannot publish into a different character root")
assert(second:Set("zero",false) and second:Get("zero")==false)
for n=1,63 do assert(second:Set("key"..n,n)) end
fails("DATA_LIMIT",second:Set("one-too-many",1))
assert(second:Set("key1",nil));assert(second:Set("replacement",1))
first:Close();fails("STORAGE_CLOSED",first:Get("test"))
assert(LycheeInternal==nil and LycheeCharacterDB==nil,"storage works without Host or Host SV")
local a,b={},{}
assert(loadfile("lychee-sdk/Storage.lua"))("AddonA",a)
assert(loadfile("lychee-sdk/Storage.lua"))("AddonB",b)
assert(a.LycheeSDK.Storage~=b.LycheeSDK.Storage,"embedded SDK copies remain local")
-- Relocating legacy settings must be atomic and must never replace a newer
-- child-owned namespace. The owner, not the SDK, decides when to remove source.
db={};local imported=assert(Storage.Open(options("imported")))
local legacy={choice={text="original"},showDetails=false}
assert(imported:Import(legacy))
assert(legacy.choice.text=="original" and imported:Get("showDetails")==false)
legacy.choice.text="changed"
assert(imported:Get("choice").text=="original")
original=db.imported
fails("STORAGE_EXISTS",imported:Import({choice="overwrite"}))
assert(db.imported==original)
local rejected=assert(Storage.Open(options("rejected")))
fails("DATA_LIMIT",rejected:Import({good=true,large=string.rep("x",16385)}))
assert(db.rejected==nil,"failed import cannot leave partially copied settings")
-- Accessors are external callbacks too: reject reentry before it can recurse.
local reentrant,readyCalls,rootCalls
readyCalls,rootCalls=0,0
reentrant=assert(Storage.Open({id="reentry",version=1,
    ready=function()
        readyCalls=readyCalls+1
        fails("STORAGE_BUSY",reentrant:Get("value"))
        return true
    end,
    root=function()
        rootCalls=rootCalls+1
        fails("STORAGE_BUSY",reentrant:Import({value=999}))
        return db
    end,
}))
assert(reentrant:Import({value=7}) and reentrant:Get("value")==7)
assert(readyCalls==3 and rootCalls==3,"accessor reentry is bounded")
local closing
closing=assert(Storage.Open({id="closed",version=1,ready=function() closing:Close();return true end,root=function() error("closed accessor ran") end}))
fails("STORAGE_CLOSED",closing:Get("value"))
assert(db.closed==nil)
local migrationClosing
db.closeMigration={version=1,values={value=4}}
original=db.closeMigration
migrationClosing=assert(Storage.Open(options("closeMigration",2,{[1]=function(values) migrationClosing:Close();return values end})))
fails("STORAGE_CLOSED",migrationClosing:Migrate())
assert(db.closeMigration==original)
local competing=assert(Storage.Open(options("competing")))
assert(competing:Import({value=4}));original=db.competing
local upgrade=assert(Storage.Open(options("competing",2,{[1]=function(values)
    assert(competing:Set("value",5));return values
end})))
fails("STALE_STORAGE",upgrade:Migrate())
assert(db.competing~=original and competing:Get("value")==5,"migration cannot overwrite a concurrent write")
print("SDK storage PASS: no Host, ready/root ownership, isolation, quotas, transactional migrations, newer versions, independent copies")
