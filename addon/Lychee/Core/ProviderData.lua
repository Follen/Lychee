local I = _G.LycheeInternal
local D = {}
I.ProviderData = D
local function failure(code) return nil,{code=code,retryable=false} end
local function keyOK(key)
    return I.Boundary:Validate(key,"key") and type(key)=="string" and #key>0 and #key<=96
end
local function plain(value)
    return I.Boundary:Copy(value,"data",{maxDepth=6,maxFields=128,maxNodes=256,maxBytes=16384,scalarKeys=true})
end
function D:Cache(scope,key,options)
    if not keyOK(key) then return failure("INVALID_SCHEMA") end
    local config,err=I.Boundary:Copy(options==nil and {} or options,"cache")
    if err then return nil,err end
    if type(config)~="table" then return failure("INVALID_SCHEMA") end
    for name in pairs(config) do if name~="entries" and name~="bytes" then return failure("INVALID_SCHEMA") end end
    local limit,budget=config.entries or 32,config.bytes or 32768
    if type(limit)~="number" or limit~=math.floor(limit) or limit<1 or limit>128
        or type(budget)~="number" or budget~=math.floor(budget) or budget<1 or budget>65536 then return failure("INVALID_SCHEMA") end
    local values,order,sizes,bytes={}, {}, {},0
    local active=true
    local token;token,err=I.Resources:OwnCache(scope,key,function() active=false;values,order,sizes=nil,nil,nil;bytes=0 end)
    if not token then return nil,err end
    local function usable() return active and scope:IsActive() end
    local function remove(name)
        if sizes[name] then bytes=bytes-sizes[name];sizes[name],values[name]=nil,nil
            for index,id in ipairs(order) do if id==name then table.remove(order,index);break end end
        end
    end
    return {
        Get=function(_,name)
            if not usable() then return failure("RESOURCE_CLOSED") end
            if not keyOK(name) then return failure("INVALID_SCHEMA") end
            return plain(values[name])
        end,
        Set=function(_,name,value)
            if not usable() then return failure("RESOURCE_CLOSED") end
            if not keyOK(name) then return failure("INVALID_SCHEMA") end
            if value==nil then remove(name);return true end
            local owned,invalid,size=plain(value);if invalid then return nil,invalid end
            size=size+#name
            if size>budget then return failure("DATA_LIMIT") end
            remove(name)
            if owned==nil then return true end
            while #order>=limit or bytes+size>budget do remove(order[1]) end
            values[name],sizes[name]=owned,size;order[#order+1]=name;bytes=bytes+size
            return true
        end,
        Clear=function()
            if not usable() then return failure("RESOURCE_CLOSED") end
            values,order,sizes={}, {}, {};bytes=0;return true
        end,
        GetDiagnostics=function() return {entries=order and #order or 0,bytes=bytes,entryLimit=limit,byteLimit=budget,active=usable()==true} end,
    }
end
