local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
local Ledger = {}
Ledger.__index = Ledger
I.Builtin.CatalogLedger = Ledger

-- Private business adapters compare/retain named snapshots and translate IDs.
-- The ledger owns only committed values, never a second full search catalogue.
function Ledger:New(adapter)
    return setmetatable({values={},adapter=adapter or {},epoch=0},self)
end

function Ledger:Invalidate(clear, stale)
    self.epoch=self.epoch+1
    self.operation=nil
    self.stale=stale
    if clear then self.values={}
    elseif stale then for id in pairs(self.values) do self.values[id]=false end end
end

local function failure(code) return false,{code=code} end

-- nil/false removes a value in a full snapshot; false explicitly removes it in
-- a partial update. Build runs only for changed values, before the first write.
-- No batchSize means one atomic Host delta. Batched callers yield between
-- commits, remove obsolete IDs first and retain each successful chunk on error.
function Ledger:Reconcile(handle, desired, build, options)
    options=options or {}
    if self.operation then return failure("UPDATE_IN_PROGRESS") end
    local values,adapter,epoch=self.values,self.adapter,self.epoch
    local operation={}
    self.operation=operation
    local function current()
        return self.operation==operation and self.epoch==epoch
            and (not options.current or options.current())
    end
    local function finish(ok,err)
        if self.operation==operation then self.operation=nil end
        return ok,err
    end
    if not current() then return finish(failure("CATALOG_CANCELLED")) end
    local changed,remove,removedKeys={},{},{}
    local function removeKey(id)
        removedKeys[#removedKeys+1]=id
        remove[#remove+1]=adapter.recordID and adapter.recordID(id) or id
    end
    for id,value in pairs(desired) do
        if value then
            local old=values[id]
            local same=old and (adapter.same and adapter.same(old,value) or not adapter.same and old==value)
            if not same then changed[id]=value end
        elseif values[id]~=nil then removeKey(id) end
        if options.checkpoint then options.checkpoint() end
        if not current() then return finish(failure("CATALOG_CANCELLED")) end
    end
    if options.full then
        for id in pairs(values) do
            if desired[id]==nil then removeKey(id) end
        end
    end
    local additions={}
    if next(changed) then
        local ok,result=pcall(build,changed)
        if not ok or type(result)~="table" then return finish(failure("CATALOG_BUILD_FAILED")) end
        additions=result
    end
    if not current() then return finish(failure("CATALOG_CANCELLED")) end
    if #additions==0 and #remove==0 then return finish(true) end
    local function commit(upsert,deleted,keys)
        if not current() then return failure("CATALOG_CANCELLED") end
        local accepted,err=handle:Update({upsert=upsert,remove=deleted})
        -- A successful transaction belongs to its original registration. A
        -- disable can invalidate signatures; unregister replaces the map itself.
        if accepted and self.values==values then
            for _,row in ipairs(upsert) do
                local id=adapter.key and adapter.key(row) or row.id
                local value=changed[id]
                if self.epoch~=epoch and self.stale then values[id]=false
                else values[id]=adapter.remember and adapter.remember(value) or value end
            end
            for _,id in ipairs(keys) do values[id]=nil end
        end
        if not current() then return failure("CATALOG_CANCELLED") end
        if not accepted then return false,err or {code="SOURCE_COMMIT_FAILED"} end
        if options.afterCommit then options.afterCommit() end
        if not current() then return failure("CATALOG_CANCELLED") end
        return true
    end
    if not options.batchSize then
        return finish(commit(additions,remove,removedKeys))
    end
    local size=options.batchSize
    for first=1,#remove,size do
        local deleted,keys={},{}
        for index=first,math.min(first+size-1,#remove) do
            deleted[#deleted+1],keys[#keys+1]=remove[index],removedKeys[index]
        end
        local ok,err=commit({},deleted,keys)
        if not ok then return finish(ok,err) end
    end
    for first=1,#additions,size do
        local upsert={}
        for index=first,math.min(first+size-1,#additions) do
            upsert[#upsert+1]=additions[index]
            additions[index]=false
        end
        local ok,err=commit(upsert,{},{})
        if not ok then return finish(ok,err) end
    end
    return finish(true)
end
