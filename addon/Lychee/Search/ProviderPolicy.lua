local I=_G.LycheeInternal
local P={version=0}
I.Search.ProviderPolicy=P
local function normalize(value) return I.Search.Normalizer:Normalize(value) end
local function literal(value) return value:lower():match("^%s*(.-)%s*$") end
local function prefixes(input,exact,allowEmpty)
    if type(input)~="table" or (not allowEmpty and #input<1) or #input>8 then return end
    local out,seen={},{}
    for key,value in pairs(input) do
        if type(key)~="number" or key%1~=0 or key<1 or key>#input or type(value)~="string" or #value>48 then return end
    end
    for _,value in ipairs(input) do
        value=exact and literal(value) or normalize(value)
        if value=="" or value:find("[%s%c|:,]") or value:find("：",1,true) or value:find("，",1,true) or seen[value] then return end
        seen[value]=true;out[#out+1]=value
    end
    return out
end
function P:Data()
    local owner=I.CharacterStore:Palette()
    if self.owner~=owner then
        local old=type(owner.providerSearch)=="table" and owner.providerSearch or {}
        local clean,seen={},{}
        for index=1,128 do
            local row=old[index]
            if type(row)=="table" and type(row.id)=="string" and #row.id>0 and #row.id<=64 and not seen[row.id]
                and (row.mode==nil or row.mode=="global" or row.mode=="prefix" or row.mode=="keyword") then
                local combined=type(row.global)=="boolean"
                local list=row.prefixes and prefixes(row.prefixes,false,combined)
                local words=row.keywords and prefixes(row.keywords,true,combined)
                if (row.global==nil or combined) and (row.prefixes==nil or list) and (row.keywords==nil or words) then
                    clean[#clean+1]={id=row.id,mode=row.mode,global=row.global,prefixes=list,keywords=words};seen[row.id]=true
                end
            end
        end
        owner.providerSearch=clean;self.owner,self.data=owner,clean;self:Invalidate()
    end
    return self.data
end
function P:Invalidate() self.version=self.version+1;self.cache=nil end
function P:Override(id)
    for index,row in ipairs(self:Data()) do if row.id==id then return row,index end end
end
function P:Defaults(id,definition,kind)
    if kind=="keyword" then return prefixes(definition.searchKeywords,true) or {} end
    return prefixes(definition.searchPrefixes or {},false,true) or {}
end
-- Only persisted exclusive-mode overrides need one-time interpretation.
function P:Configuration(id,definition,defaults)
    local row=not defaults and self:Override(id) or nil
    local mode=row and row.mode or "global"
    local list=row and row.prefixes or self:Defaults(id,definition)
    local words=row and row.keywords or self:Defaults(id,definition,"keyword")
    if row and type(row.global)=="boolean" then return row.global,list,words end
    if definition.searchGlobal~=nil and not (row and row.mode) then return definition.searchGlobal,list,words end
    return mode=="global",mode=="keyword" and {} or list,mode=="keyword" and words or {}
end
function P:Snapshot()
    self:Data()
    if self.cache then return self.cache end
    local cache={map={},excluded={},keywords={},keywordSources={},reservedKeywords={}}
    for id,entry in pairs(I.Providers and I.Providers.entries or {}) do
        local global,list,words=self:Configuration(id,entry.definition)
        local override=self:Override(id)
        local claimed=override and override.keywords or self:Defaults(id,entry.definition,"keyword")
        for _,word in ipairs(claimed or {}) do
            local owner=cache.reservedKeywords[word]
            if owner~=nil and owner~=id then cache.reservedKeywords[word]=false else cache.reservedKeywords[word]=id end
        end
        for prefix,owner in pairs(cache.map) do if owner==id then cache.map[prefix]=nil end end
        for _,prefix in ipairs(list) do
            local owner=cache.map[prefix]
            if owner~=nil and owner~=id then cache.map[prefix]=false else cache.map[prefix]=id end
        end
        for _,word in ipairs(words or {}) do
            local owner=cache.keywords[word]
            if owner~=nil and owner~=id then cache.keywords[word]=false else cache.keywords[word]=id end
        end
        if #words>0 then cache.keywordSources[id]=true end
        if not global then cache.excluded[id..":records"]=true end
    end
    self.cache=cache;return cache
end
function P:ValidateDefinition(definition)
    if definition.searchGlobal~=nil and type(definition.searchGlobal)~="boolean" then return nil,"searchGlobal" end
    local list=prefixes(definition.searchPrefixes or {},false,true)
    local words=prefixes(definition.searchKeywords or {},true,true)
    if not list then return nil,"searchPrefixes" end
    if not words then return nil,"searchKeywords" end
    if definition.searchGlobal==false and #list==0 and #words==0 then return nil,"searchGlobal.routes" end
    local snapshot=self:Snapshot()
    for _,prefix in ipairs(list) do if snapshot.map[prefix]~=nil and snapshot.map[prefix]~=definition.id then return nil,"searchPrefixes.conflict" end end
    for _,word in ipairs(words) do if snapshot.reservedKeywords[word]~=nil and snapshot.reservedKeywords[word]~=definition.id then return nil,"searchKeywords.conflict" end end
    return true
end
function P:SetConfiguration(id,global,input,keywordInput)
    local entry=I.Providers.entries[id]
    if not entry then return false,"功能已不可用" end
    if type(global)~="boolean" then return false,"搜索方式无效" end
    local list=prefixes(input,false,true);local words=prefixes(keywordInput,true,true)
    if not list then return false,"前缀最多8个，每个48字节，不含空格或冒号" end
    if not words then return false,"触发词最多8个，每个48字节，不含空格或冒号" end
    if not global and #list==0 and #words==0 then return false,"请保留普通搜索或至少一个快捷入口" end
    local snapshot=self:Snapshot()
    for _,value in ipairs(list) do if snapshot.map[value]~=nil and snapshot.map[value]~=id then return false,"前缀已被其他功能使用" end end
    for _,value in ipairs(words) do if snapshot.reservedKeywords[value]~=nil and snapshot.reservedKeywords[value]~=id then return false,"触发词已被其他功能使用" end end
    local rows=self:Data();local _,index=self:Override(id)
    if not index and #rows>=128 then return false,"搜索设置已达上限" end
    rows[index or #rows+1]={id=id,global=global,prefixes=list,keywords=words}
    self:Invalidate();I.Providers:CancelQueries("search-policy-changed")
    return true
end
function P:Reset(id)
    if not I.Providers.entries[id] then return false,"PROVIDER_UNAVAILABLE" end
    local rows=self:Data();local _,index=self:Override(id)
    if index then table.remove(rows,index) end
    self:Invalidate();I.Providers:CancelQueries("search-policy-changed")
    return true
end
function P:Route(text,filter)
    local snapshot=self:Snapshot()
    local keywordOwner=next(snapshot.keywords) and snapshot.keywords[literal(text)]
    if not filter and keywordOwner and snapshot.keywordSources[keywordOwner] then
        text="";filter={sourceID=keywordOwner..":records"}
    end
    local first,last=text:find(":",1,true)
    local wide,wideLast=text:find("：",1,true)
    if wide and (not first or wide<first) then first,last=wide,wideLast end
    if first then
        local owner=snapshot.map[normalize(text:sub(1,first-1))]
        if owner then text=text:sub(last+1);filter={sourceID=owner..":records"} end
    end
    if next(snapshot.excluded) then
        local copy={}
        for key,value in pairs(filter or {}) do copy[key]=value end
        copy.excludedSources=not copy.sourceID and snapshot.excluded or nil
        copy.policyVersion=self.version;filter=copy
    end
    return text,filter
end
