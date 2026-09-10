local I=_G.LycheeInternal
local P={version=0}
I.Search.ProviderPolicy=P
local function normalize(value) return I.Search.Normalizer:Normalize(value) end
local function literal(value) return value:lower():match("^%s*(.-)%s*$") end
local function prefixes(input,exact)
    if type(input)~="table" or #input<1 or #input>8 then return end
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
    LycheeDB=LycheeDB or {};LycheeDB.palette=type(LycheeDB.palette)=="table" and LycheeDB.palette or {}
    local owner=LycheeDB.palette
    if self.owner~=owner then
        local old=type(owner.providerSearch)=="table" and owner.providerSearch or {}
        local clean,seen={},{}
        for index=1,128 do
            local row=old[index]
            if type(row)=="table" and type(row.id)=="string" and #row.id>0 and #row.id<=64 and not seen[row.id]
                and (row.mode==nil or row.mode=="global" or row.mode=="prefix" or row.mode=="keyword") then
                local list=row.prefixes and prefixes(row.prefixes)
                local words=row.keywords and prefixes(row.keywords,true)
                if (row.prefixes==nil or list) and (row.keywords==nil or words) then clean[#clean+1]={id=row.id,mode=row.mode,prefixes=list,keywords=words};seen[row.id]=true end
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
    if definition.searchPrefixes then return prefixes(definition.searchPrefixes) or {} end
    local list={}
    for prefix,owner in pairs(I.Search.Query and I.Search.Query.categoryPrefixes or {}) do if owner==id then list[#list+1]=prefix end end
    table.sort(list);return list
end
function P:Effective(id,definition)
    if definition.searchable==false then return "global",self:Defaults(id,definition) end
    local row=self:Override(id)
    return row and row.mode or definition.searchMode or "global",row and row.prefixes or self:Defaults(id,definition),row and row.keywords or self:Defaults(id,definition,"keyword")
end
function P:Snapshot()
    self:Data()
    if self.cache then return self.cache end
    local cache={map={},excluded={},keywords={},keywordSources={}}
    for prefix,id in pairs(I.Search.Query and I.Search.Query.categoryPrefixes or {}) do cache.map[prefix]=id end
    for id,entry in pairs(I.Providers and I.Providers.entries or {}) do
        local mode,list,words=self:Effective(id,entry.definition)
        for prefix,owner in pairs(cache.map) do if owner==id then cache.map[prefix]=nil end end
        for _,prefix in ipairs(list) do
            local owner=cache.map[prefix]
            if owner~=nil and owner~=id then cache.map[prefix]=false else cache.map[prefix]=id end
        end
        for _,word in ipairs(words or {}) do
            local owner=cache.keywords[word]
            if owner~=nil and owner~=id then cache.keywords[word]=false else cache.keywords[word]=id end
        end
        if mode=="keyword" then cache.keywordSources[id]=true end
        if mode=="prefix" or mode=="keyword" then cache.excluded[id..":records"]=true end
    end
    self.cache=cache;return cache
end
function P:ValidateDefinition(definition)
    if definition.searchMode==nil and definition.searchPrefixes==nil and definition.searchKeywords==nil then return true end
    if (definition.searchMode=="keyword" or definition.searchKeywords~=nil) and (definition.minApiRevision or 1)<5 then return nil,"searchKeywords.minApiRevision" end
    if (definition.minApiRevision or 1)<4 then return nil,"searchMode.minApiRevision" end
    if definition.searchMode~=nil and definition.searchMode~="global" and definition.searchMode~="prefix" and definition.searchMode~="keyword" then return nil,"searchMode" end
    if definition.searchable==false then return nil,"searchable/searchMode" end
    local list=definition.searchPrefixes and prefixes(definition.searchPrefixes)
    if definition.searchPrefixes~=nil and not list or definition.searchMode=="prefix" and not list then return nil,"searchPrefixes" end
    local map=self:Snapshot().map
    for _,prefix in ipairs(list or {}) do if map[prefix]~=nil and map[prefix]~=definition.id then return nil,"searchPrefixes.conflict" end end
    local words=definition.searchKeywords and prefixes(definition.searchKeywords,true)
    if definition.searchKeywords~=nil and not words or definition.searchMode=="keyword" and not words then return nil,"searchKeywords" end
    local keywords=self:Snapshot().keywords
    for _,word in ipairs(words or {}) do if keywords[word]~=nil and keywords[word]~=definition.id then return nil,"searchKeywords.conflict" end end
    return true
end
function P:Set(id,mode,input,keywordInput)
    local entry=I.Providers.entries[id]
    if not entry or entry.definition.searchable==false then return false,"不可修改独立查询入口" end
    if mode~=nil and mode~="global" and mode~="prefix" and mode~="keyword" then return false,"搜索方式无效" end
    local list=input and prefixes(input)
    if input and not list then return false,"前缀最多8个，每个48字节，不含空格或冒号" end
    local effective=list or self:Defaults(id,entry.definition)
    if (mode or entry.definition.searchMode)=="prefix" and #effective==0 then return false,"请先设置搜索前缀" end
    local map=self:Snapshot().map
    for _,prefix in ipairs(effective) do if map[prefix]~=nil and map[prefix]~=id then return false,"前缀已被其他功能使用" end end
    local words=keywordInput and prefixes(keywordInput,true)
    if keywordInput and not words then return false,"触发词最多8个，每个48字节，不含空格或冒号" end
    local effectiveWords=words or self:Defaults(id,entry.definition,"keyword")
    if (mode or entry.definition.searchMode)=="keyword" and #effectiveWords==0 then return false,"请先设置触发词" end
    local keywords=self:Snapshot().keywords
    for _,word in ipairs(effectiveWords) do if keywords[word]~=nil and keywords[word]~=id then return false,"触发词已被其他功能使用" end end
    local rows=self:Data();local _,index=self:Override(id)
    if mode==nil and input==nil and keywordInput==nil then if index then table.remove(rows,index) end
    else
        if not index and #rows>=128 then return false,"搜索设置已达上限" end
        rows[index or #rows+1]={id=id,mode=mode,prefixes=list,keywords=words}
    end
    self:Invalidate();I.Providers:CancelQueries("search-policy-changed")
    if I.Search.StaticIndex then I.Search.StaticIndex:ClearQueryCache() end
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
        if owner and not snapshot.keywordSources[owner] then text=text:sub(last+1);filter={sourceID=owner..":records"} end
    end
    if next(snapshot.excluded) then
        local copy={}
        for key,value in pairs(filter or {}) do copy[key]=value end
        copy.excludedSources=not copy.sourceID and snapshot.excluded or nil
        copy.policyVersion=self.version;filter=copy
    end
    return text,filter
end
