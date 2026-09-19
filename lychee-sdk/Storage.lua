-- Optional SDK storage. The AddOn owns its SV and signals when it is restored.
-- No Host globals, global registry, implicit migration, or file-loading work.
local Storage = {}
local function failure(code) return nil,{code=code,retryable=false} end
local function accessible(value)
    if issecretvalue then local ok,result=pcall(issecretvalue,value);if not ok or result then return false end end
    if canaccessvalue then local ok,result=pcall(canaccessvalue,value);if not ok or not result then return false end end
    return true
end
local function plain(value,checked)
    if not checked and not accessible(value) or type(value)~="table" then return false end
    if canaccesstable then local ok,result=pcall(canaccesstable,value);if not ok or not result then return false end end
    return getmetatable(value)==nil
end
local function keyOK(key)
    return accessible(key) and type(key)=="string" and #key>0 and #key<=96
end
local function copyValue(value,seen,depth,budget,checked)
    if not checked and not accessible(value) then return failure("INACCESSIBLE_VALUE") end
    local kind=type(value)
    budget.nodes=budget.nodes+1;budget.bytes=budget.bytes+(kind=="string" and #value or 16)
    if budget.nodes>256 or budget.bytes>16384 then return failure("DATA_LIMIT") end
    if kind=="nil" or kind=="string" or kind=="boolean" then return value end
    if kind=="number" then
        if value~=value or value==math.huge or value==-math.huge then return failure("INVALID_SETTINGS") end
        return value
    end
    if not plain(value,true) or seen[value] or depth>=6 then return failure("INVALID_SETTINGS") end
    seen[value]=true
    local out={}
    for key,child in next,value do
        if not accessible(key) or type(key)~="string" and type(key)~="number" then return failure("INVALID_SETTINGS") end
        local copiedKey,err=copyValue(key,seen,depth+1,budget,true);if err then return nil,err end
        local copied;copied,err=copyValue(child,seen,depth+1,budget);if err then return nil,err end
        out[copiedKey]=copied
    end
    seen[value]=nil
    return out
end
local function copy(value)
    local budget={nodes=0,bytes=0}
    local owned,err=copyValue(value,{},0,budget)
    return owned,err,budget.bytes
end
local function settings(values,changedKey,changedValue,writing)
    if not plain(values) then return failure("INVALID_SETTINGS") end
    local out,count,bytes={},0,0
    for key,value in next,values do
        if not keyOK(key) then return failure("INVALID_SETTINGS") end
        if key~=changedKey then
            count=count+1;if count>64 then return failure("DATA_LIMIT") end
            local owned,err,size=copy(value);if err then return nil,err end
            bytes=bytes+#key+size;if bytes>65536 then return failure("DATA_LIMIT") end
            out[key]=owned
        end
    end
    if writing and changedValue~=nil then
        local owned,err,size=copy(changedValue);if err then return nil,err end
        count=count+1;bytes=bytes+#changedKey+size
        if count>64 or bytes>65536 then return failure("DATA_LIMIT") end
        out[changedKey]=owned
    end
    return out
end

local optionKeys={id=true,version=true,root=true,ready=true,migrations=true}
function Storage.Open(options)
    if not plain(options) then return failure("INVALID_SCHEMA") end
    for key,value in next,options do
        if not accessible(key) or not optionKeys[key] or not accessible(value) then return failure("INVALID_SCHEMA") end
    end
    if type(options)~="table" or not keyOK(options.id) or type(options.root)~="function"
        or type(options.ready)~="function" or type(options.version)~="number" or options.version<1
        or options.version>1000000 or options.version~=math.floor(options.version)
        or options.migrations~=nil and not plain(options.migrations) then return failure("INVALID_SCHEMA") end
    local id,version,getRoot,isReady=options.id,options.version,options.root,options.ready
    local migrations={}
    for step,fn in pairs(options.migrations or {}) do
        if not accessible(step) or not accessible(fn) or type(step)~="number" or step<1 or step>=version or step~=math.floor(step) or type(fn)~="function" then
            return failure("INVALID_SCHEMA")
        end
        migrations[step]=fn
    end
    local closed,busy=false,false
    local function root()
        if closed then return failure("STORAGE_CLOSED") end
        if busy then return failure("STORAGE_BUSY") end
        busy=true
        local ok,ready=pcall(isReady)
        busy=false
        if closed then return failure("STORAGE_CLOSED") end
        if not ok or ready~=true then return failure("STORAGE_NOT_READY") end
        busy=true
        local loaded,data=pcall(getRoot)
        busy=false
        if closed then return failure("STORAGE_CLOSED") end
        if not loaded or not plain(data) then return failure("INVALID_SETTINGS") end
        return data
    end
    local function slot(data,allowOld)
        local value=data[id]
        if value==nil then return nil end
        if not plain(value) or not accessible(value.version) or type(value.version)~="number"
            or value.version<1 or value.version~=math.floor(value.version) or not plain(value.values) then
            return failure("INVALID_SETTINGS")
        end
        if value.version>version then return failure("STORAGE_NEWER_VERSION") end
        if value.version<version and not allowOld then return failure("STORAGE_MIGRATION_REQUIRED") end
        return value
    end
    local function publish(data,previous,values)
        local current,err=root();if not current then return nil,err end
        if current~=data or current[id]~=previous then return failure("STALE_STORAGE") end
        current[id]={version=version,values=values}
        return true
    end
    local handle={}
    function handle:Get(key,default)
        if not keyOK(key) then return failure("INVALID_SCHEMA") end
        local data,err=root();if not data then return nil,err end
        local current;current,err=slot(data);if err then return nil,err end
        local value=current and current.values[key]
        if value==nil then value=default end
        local owned,why=copy(value);return owned,why
    end
    function handle:Set(key,value)
        if not keyOK(key) then return failure("INVALID_SCHEMA") end
        local data,err=root();if not data then return nil,err end
        local current;current,err=slot(data);if err then return nil,err end
        local values;values,err=settings(current and current.values or {},key,value,true)
        if not values then return nil,err end
        return publish(data,current,values)
    end
    -- Owner-driven relocation: validate the whole namespace, then publish once.
    -- Never merge into existing data or delete an external migration source.
    function handle:Import(values)
        local data,err=root();if not data then return nil,err end
        if data[id]~=nil then return failure("STORAGE_EXISTS") end
        local owned;owned,err=settings(values);if not owned then return nil,err end
        return publish(data,nil,owned)
    end
    function handle:Migrate()
        local data,err=root();if not data then return nil,err end
        local current;current,err=slot(data,true);if err then return nil,err end
        if not current or current.version==version then return true end
        if version-current.version>32 then return failure("STORAGE_MIGRATION_LIMIT") end
        local values;values,err=settings(current.values);if not values then return nil,err end
        busy=true
        local steps=migrations
        for step=current.version,version-1 do
            local fn=steps[step]
            if not fn then busy=false;return failure("STORAGE_MIGRATION_MISSING") end
            local ok,result=pcall(fn,values)
            if closed then busy=false;return failure("STORAGE_CLOSED") end
            if not ok then busy=false;return failure("STORAGE_MIGRATION_FAILED") end
            values,err=settings(result)
            if not values then busy=false;return nil,err end
        end
        busy=false
        return publish(data,current,values)
    end
    function handle:Close() closed=true;getRoot,isReady,migrations=nil,nil,nil end
    return handle
end

local _,namespace=...
if type(namespace)=="table" then
    namespace.LycheeSDK=namespace.LycheeSDK or {}
    namespace.LycheeSDK.Storage=Storage
end
return Storage
