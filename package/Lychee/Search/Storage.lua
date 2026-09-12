local I = _G.LycheeInternal
I.Search = I.Search or {}
local Storage = {}
I.Search.Storage = Storage

-- Host-private layouts. Keep common fields in the array part; sparse/new
-- string fields retain their names. Public records never use these metatables.
local function layout(names)
    local slots = {}; for index, name in ipairs(names) do slots[name] = index end
    local mt = {}
    function mt.__index(row, name) local slot=slots[name]; if slot then return rawget(row,slot) end end
    function mt.__newindex(row,name,value) rawset(row,slots[name] or name,value) end
    return {names=names,slots=slots,mt=mt}
end
local recordLayout=layout({"id","title","subtitle","kind","kindTitle","icon","aliases","keywords",
    "payload","primaryActionID","actions","drag","category","_extensionID"})
local entryLayout=layout({"key","sourceID","source","record","stableID","fields","categoryID","categoryOrder","indexed"})
Storage.EntrySlots=entryLayout.slots
local layouts={[recordLayout.mt]=recordLayout,[entryLayout.mt]=entryLayout}
local function pack(value, definition)
    if getmetatable(value)==definition.mt then return value end
    -- Non-string extension keys must not collide with private numeric slots.
    for key in pairs(value) do if type(key)~="string" then return value end end
    local row={}
    for index,name in ipairs(definition.names) do row[index]=value[name] end
    for key,child in pairs(value) do if not definition.slots[key] then row[key]=child end end
    return setmetatable(row,definition.mt)
end
function Storage:PackRecord(record) return pack(record,recordLayout) end
function Storage:Entry(key,source,record,fields,categoryID,categoryOrder)
    return setmetatable({key,source.id,source,record,(source.extensionID or source.id)..":"..record.id,
        fields,categoryID,categoryOrder},entryLayout.mt)
end
-- One low-frequency projection avoids invoking __index for every compiled field.
local TITLE,ALIASES,KEYWORDS,CATEGORY=recordLayout.slots.title,recordLayout.slots.aliases,recordLayout.slots.keywords,recordLayout.slots.category
function Storage:SearchFields(record)
    if getmetatable(record)==recordLayout.mt then
        return record[TITLE],record[ALIASES],record[KEYWORDS],record.description,record[CATEGORY],record.scope
    end
    return record.title,record.aliases,record.keywords,record.description,record.category,record.scope
end
function Storage:IsPacked(value) return type(value)=="table" and layouts[getmetatable(value)]~=nil end
local function nextField(value, key)
    local definition=layouts[getmetatable(value)]
    local rawKey,child=next(value,definition and definition.slots[key] or key)
    if rawKey~=nil then return definition and definition.names[rawKey] or rawKey,child end
end
function Storage:Fields(value) return nextField,value,nil end
function Storage:Copy(value)
    if type(value)~="table" then return value end
    local out={}
    for key,child in nextField,value do out[key]=self:Copy(child) end
    return out
end
function Storage:Equal(left,right)
    if left==right then return true end
    if type(left)~="table" or type(right)~="table" then return false end
    local leftPacked,rightPacked=self:IsPacked(left),self:IsPacked(right)
    for key,value in nextField,left do
        if rightPacked and type(key)=="number" then return false end
        if not self:Equal(value,right[key]) then return false end
    end
    for key in nextField,right do
        if leftPacked and type(key)=="number" or left[key]==nil then return false end
    end
    return true
end

-- Posting sets are nil, one string, or a sorted dense string array.
-- Binary lookup; insertion/deletion only shifts the affected posting.
local function lowerBound(list,key)
    local lo,hi=1,#list
    while lo<=hi do local mid=math.floor((lo+hi)/2)
        if list[mid]<key then lo=mid+1 else hi=mid-1 end
    end
    return lo
end
function Storage.AddPosting(map,term,key)
    if not term or term=="" then return end
    local list=map[term]
    if not list then map[term]=key
    elseif type(list)=="string" then
        if list~=key then map[term]=list<key and {list,key} or {key,list} end
    else
        local last=list[#list]
        if key>=last then if key~=last then list[#list+1]=key end;return end
        local at=lowerBound(list,key)
        if list[at]~=key then table.insert(list,at,key) end
    end
end
function Storage.RemovePosting(map,term,key)
    local list=term and map[term]
    if not list then return end
    if type(list)=="string" then if list==key then map[term]=nil end;return end
    local at=list[#list]==key and #list or lowerBound(list,key)
    if list[at]~=key then return end
    table.remove(list,at)
    if #list==1 then map[term]=list[1] elseif #list==0 then map[term]=nil end
end
function Storage.HasPosting(list,key)
    if type(list)=="string" then return list==key end
    return list~=nil and list[lowerBound(list,key)]==key
end
return Storage
