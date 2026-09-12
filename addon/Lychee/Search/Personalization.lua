local I = _G.LycheeInternal
local P = {limit=128, aliasBytes=96, queryBytes=128}
I.Search.Personalization = P
local function identity()
    local current=I.Search.RuntimeIdentity and I.Search.RuntimeIdentity:Current()
    return current and current.product or "unknown", I.Locale and I.Locale.code or "enUS"
end
local function same(a,b)
    return a and b and a.providerID==b.providerID and a.entryID==b.entryID
end
local function validString(value,limit)
    return type(value)=="string" and #value>0 and #value<=limit and not value:find("[%c|]")
end
local function copyRef(ref)
    if type(ref)~="table" or not validString(ref.providerID,192) or not validString(ref.entryID,192) then return end
    return {providerID=ref.providerID,entryID=ref.entryID}
end
local function safeTitle(value,fallback)
    if type(value)~="string" then return fallback end
    if #value<=256 then return value end
    local boundary=257
    while boundary>1 and value:byte(boundary)>=128 and value:byte(boundary)<192 do boundary=boundary-1 end
    return value:sub(1,boundary-1)
end
function P:Data()
    local saved=I.CharacterStore:Palette()
    if self.owner==saved then return self.data end
    local old=type(saved.searchPersonalization)=="table" and saved.searchPersonalization or {}
    local clean={aliases={},choices={}}
    for _,kind in ipairs({"aliases","choices"}) do
        local rows=type(old[kind])=="table" and old[kind] or {}
        for index=1,self.limit do
            local row=rows[index]
            if type(row)=="table" then
                local ref=copyRef(row.ref)
                local value=kind=="aliases" and row.alias or row.query
                if ref and validString(row.product,32) and validString(value,kind=="aliases" and self.aliasBytes or self.queryBytes) then
                    local duplicate=false
                    for _,kept in ipairs(clean[kind]) do
                        if kept.product==row.product and (kind=="aliases" and same(kept.ref,ref)
                            or kind=="choices" and kept.query==value and kept.locale==row.locale) then duplicate=true;break end
                    end
                    if not duplicate then
                        clean[kind][#clean[kind]+1]={ref=ref,product=row.product,alias=kind=="aliases" and value or nil,
                            query=kind=="choices" and value or nil,locale=type(row.locale)=="string" and row.locale:sub(1,8) or "enUS",
                            title=safeTitle(row.title,ref.entryID)}
                    end
                end
            end
        end
    end
    saved.searchPersonalization=clean;self.owner,self.data=saved,clean
    return clean
end
function P:Aliases() return self:Data().aliases end
function P:Find(ref)
    local product=identity()
    for index,row in ipairs(self:Aliases()) do if row.product==product and same(row.ref,ref) then return row,index end end
end
function P:SetAlias(ref,value,title)
    local copy=copyRef(ref)
    if not copy then return false,"ALIAS_UNAVAILABLE" end
    value=type(value)=="string" and value:match("^%s*(.-)%s*$") or ""
    if value~="" and not validString(value,self.aliasBytes) then return false,"ALIAS_INVALID" end
    local rows=self:Aliases();local old,index=self:Find(ref)
    if value=="" then if index then table.remove(rows,index) end;return true end
    if not old and #rows>=self.limit then return false,"ALIAS_LIMIT" end
    local product=identity()
    local row={ref=copy,alias=value,product=product,title=safeTitle(title,copy.entryID)}
    rows[index or #rows+1]=row
    return true
end
function P:Remove(row)
    for index,current in ipairs(self:Aliases()) do if current==row then table.remove(self:Aliases(),index);return true end end
    return false
end
function P:Remember(query,item)
    if not I.UserPreferences or not I.UserPreferences:CanPin(item) then return end
    query=I.Search.Normalizer:Normalize(query)
    if not validString(query,self.queryBytes) then return end
    local product,locale=identity();local rows=self:Data().choices
    for index=#rows,1,-1 do
        if rows[index].product==product and rows[index].locale==locale and rows[index].query==query then table.remove(rows,index) end
    end
    table.insert(rows,1,{query=query,product=product,locale=locale,ref=copyRef(item.ref)})
    if #rows>self.limit then rows[#rows]=nil end
end
function P:ClearChoices() self:Data().choices={} end
function P:Preferred(request)
    local product,locale=identity()
    for _,choice in ipairs(self:Data().choices) do
        if choice.product==product and choice.locale==locale and choice.query==(request.preferenceKey or request.normalized) then
            return choice.ref
        end
    end
end
function P:Promote(results,request)
    local preferred=self:Preferred(request)
    if not preferred then return end
    for index,item in ipairs(results) do
        if same(preferred,item.ref) then
            if index>1 then table.remove(results,index);table.insert(results,1,item) end
            return
        end
    end
end
local function aliasLess(left,right,scores,preferred)
    local lp,rp=same(left.ref,preferred),same(right.ref,preferred)
    if lp~=rp then return lp end
    if scores[left]~=scores[right] then return scores[left]>scores[right] end
    local a,b=left.ref,right.ref
    if a.providerID~=b.providerID then return a.providerID<b.providerID end
    return a.entryID<b.entryID
end
function P:AddAliases(results,request,context)
    local product=identity();local normalizer=I.Search.Normalizer
    if request.normalized=="" then return end
    local candidates,scores={},{}
    local filter=type(request.filter)=="table" and request.filter or nil
    for _,row in ipairs(self:Aliases()) do
        local provider=I.Providers and I.Providers.entries[row.ref.providerID]
        if row.product==product and not (provider and provider.definition.searchable==false)
            and not (filter and filter.excludedSources and filter.excludedSources[row.ref.providerID..":records"])
            and (not filter or not filter.sourceID or filter.sourceID==row.ref.providerID..":records") then
            local score=normalizer:ScoreNormalized(request.normalized,normalizer:Normalize(row.alias),"alias",false)
            if score then
                candidates[#candidates+1],scores[row]=row,score
            end
        end
    end
    -- Rank the bounded declaration set before resolving records. Missing,
    -- disabled or filtered references must not consume visible result slots.
    local preferred=self:Preferred(request)
    table.sort(candidates,function(left,right) return aliasLess(left,right,scores,preferred) end)
    local resolved=0
    for _,row in ipairs(candidates) do
        if resolved>=request.limit then break end
        local score=scores[row]
        local item=I.Providers and I.Providers:Resolve(row.ref,context or {})
        local category=item and item.searchRecord and item.searchRecord.category
        local categoryID=type(category)=="table" and category.id or category
        if item and (not filter or (not filter.sourceID or item.sourceID==filter.sourceID)
            and (not filter.categoryID or categoryID==filter.categoryID)) then
            resolved=resolved+1
            local found
            for _,existing in ipairs(results) do if same(existing.ref,item.ref) then found=existing;break end end
            if not found then
                item.confidence=score;item.subtext=I.Locale["别名"].." · "..row.alias
                results[#results+1]=item
            elseif score>(found.confidence or 0) then
                found.confidence=score
            end
        end
    end
end
