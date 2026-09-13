local I = _G.LycheeInternal
local Factory = {}
I.CatalogFactory = Factory
local failure=I.Boundary.Failure
local OPTION_KEYS={id=true,title=true,scope=true,i18n=true,actions=true,drags=true,views=true,active=true,changed=true}
local function requestOK(request)
    local ok,err=I.Boundary:Validate(request,"query")
    if not ok then return nil,err end
    if type(request)~="table" or type(request.normalized)~="string" or #request.normalized>1024
        or (request.limit~=nil and (type(request.limit)~="number" or request.limit%1~=0 or request.limit<1 or request.limit>256))
        or (request.preferredEntryID~=nil and (type(request.preferredEntryID)~="string" or #request.preferredEntryID>128))
        or (request.filter~=nil and type(request.filter)~="table") then return failure("INVALID_SCHEMA","query") end
    if request.ranking~=nil then
        if type(request.ranking)~="table" then return failure("INVALID_SCHEMA","query.ranking") end
        local count=0
        for id,weight in pairs(request.ranking) do
            count=count+1
            if count>72 or type(id)~="string" or #id>128 or not id:match("^[A-Za-z0-9][A-Za-z0-9%._:/%-]*$")
                or type(weight)~="number" or weight%1~=0 or weight<0 or weight>38 then return failure("INVALID_SCHEMA","query.ranking") end
        end
    end
    return true
end

-- Shared scalar rule; confidence remains the original matching evidence.
function Factory:RankValue(preferred,weights,id,confidence)
    if confidence==nil then return nil end
    return confidence+(preferred~=nil and preferred==id and 2 or 0)+(weights and weights[id] or 0)*0.001
end
function Factory:CreateRanker(request)
    local ok,err=requestOK(request);if not ok then return nil,err end
    local preferred,weights=request.preferredEntryID
    if request.ranking then weights={};for id,weight in pairs(request.ranking) do weights[id]=weight end end
    -- Capture only this Provider's bounded preferences, never the request/context.
    return function(id,confidence)
        local valid,why=I.Boundary.Access(id,"rank");if not valid then return nil,why end
        valid,why=I.Boundary.Access(confidence,"rank");if not valid then return nil,why end
        if type(id)~="string" or #id==0 or #id>128 or confidence~=nil and
            (type(confidence)~="number" or confidence~=confidence or confidence<0 or confidence>1) then return failure("INVALID_SCHEMA","rank") end
        return Factory:RankValue(preferred,weights,id,confidence)
    end
end
local array=I.Boundary.Array

-- Optional SDK factory. Each returned object is owned by its caller; no Host
-- registry, saved variable, active catalog list, or source subscription retains it.
function Factory:Create(options)
    local ok,err=I.Boundary:Validate(options,"catalog",{maxFields=256,maxDepth=12,
        callbacks={run=true,begin=true,create=true,changed=true,active=true}})
    if not ok then return nil,err end
    if type(options)~="table" or type(options.id)~="string" or #options.id>64
        or not options.id:match("^[a-z0-9][a-z0-9%.%-]*$") then return failure("INVALID_SCHEMA","catalog.id") end
    for key in pairs(options) do
        if not OPTION_KEYS[key] then return failure("INVALID_SCHEMA","catalog."..tostring(key)) end
    end
    for _,key in ipairs({"active","changed"}) do if options[key]~=nil and type(options[key])~="function" then return failure("INVALID_SCHEMA","catalog."..key) end end
    for _,key in ipairs({"actions","drags","views"}) do if options[key]~=nil and type(options[key])~="table" then return failure("INVALID_SCHEMA","catalog."..key) end end
    local scopeOK,scopeError=I.Boundary:ValidateScope(options.scope or {},"catalog.scope")
    if not scopeOK then return nil,scopeError end
    local owned
    -- Public options are validated before copying; callbacks remain caller-owned.
    owned=I.Boundary.CopyPlain(options)
    local localizer
    if owned.i18n then localizer,err=I.ProviderLocales:Compile(owned.i18n);if not localizer then return nil,err end end
    local state={id=owned.id,definition=owned,localizer=localizer}
    local index,closed,busy,version,count=nil,false,false,0,0
    local sourceID=owned.id..":records"
    local handle={}
    local function current()
        if closed then return failure("CATALOG_CLOSED") end
        if busy then return failure("CATALOG_BUSY") end
        if owned.active then
            busy=true;local called,active=pcall(owned.active);busy=false
            if closed then return failure("CATALOG_CLOSED") end
            if not called or not active then return failure("PROVIDER_DISABLED") end
        end
        return true
    end
    local function ensureIndex()
        if index then return index end
        index=I.Search.StaticIndex:New()
        assert(index:RegisterSource({id=sourceID,version=1,priority=0,scope=owned.scope or {},
            revision=0,title=owned.title,_extensionID=owned.id}))
        return index
    end
    local function changed()
        version=version+1
        if owned.changed then
            local called=pcall(owned.changed)
            if not called then return failure("CALLBACK_ERROR","catalog.changed") end
        end
        return true
    end
    local function update(delta)
        local valid,why=I.Boundary:Validate(delta,"catalog.update",{maxFields=4096,maxDepth=12})
        if not valid then return nil,why end
        if type(delta)~="table" then return failure("INVALID_SCHEMA","catalog.update") end
        for key in pairs(delta) do if key~="replace" and key~="upsert" and key~="remove" then return failure("INVALID_SCHEMA","catalog.update."..tostring(key)) end end
        if delta.replace~=nil and (delta.upsert~=nil or delta.remove~=nil) then return failure("INVALID_SCHEMA","catalog.replace") end
        local list,map=I.RecordCodec:Receive(state,delta.replace or delta.upsert or {},4096)
        if not list then return nil,map end
        if not array(delta.remove or {},4096) then return failure("INVALID_SCHEMA","catalog.remove") end
        local removed={}
        local nextCount=count
        for _,id in ipairs(delta.remove or {}) do
            if type(id)~="string" or id=="" or removed[id] or map[id] then return failure("INVALID_SCHEMA","catalog.remove") end
            removed[id]=true
            if index and index:GetRecord(sourceID,id) then nextCount=nextCount-1 end
        end
        for _,record in ipairs(list) do if not index or not index:GetRecord(sourceID,record.id) then nextCount=nextCount+1 end end
        if delta.replace==nil and nextCount>4096 then return failure("RESULT_LIMIT","catalog") end
        local target=ensureIndex()
        local accepted,code,revision,different
        if delta.replace~=nil then accepted,code,revision,different=target:CommitSnapshot(sourceID,list)
        else accepted,code,revision,different=target:ApplyDelta(sourceID,list,delta.remove or {}) end
        if closed or index~=target then return failure("CATALOG_CANCELLED","catalog.update") end
        if not accepted then return failure(code or "INVALID_RESULT","catalog.update") end
        count=delta.replace~=nil and #list or nextCount
        return true,nil,different
    end
    function handle:Update(delta)
        local valid,why=current();if not valid then return nil,why end
        busy=true
        local called,accepted,err,different=pcall(update,delta)
        busy=false
        if not called then return failure("CALLBACK_ERROR","catalog.update") end
        if accepted and different then return changed() end
        return accepted,err
    end
    function handle:Search(request)
        local valid,why=current();if not valid then return nil,why end
        valid,why=requestOK(request);if not valid then return nil,why end
        if not index then return {} end
        local preferred=request.preferredEntryID and sourceID..":"..request.preferredEntryID
        local hits=index:Search(request.normalized,request.limit,request.filter,true,preferred,request.ranking)
        local out={}
        for at,hit in ipairs(hits) do
            out[at]={entry=I.RecordCodec:Public(hit.entry.record,owned.id),confidence=hit.confidence,evidence=hit.evidence}
        end
        -- Index candidates are useful within a query only. Keep the canonical
        -- catalog/index, not a reference chain to the previous input candidates.
        index:ClearQueryCache()
        return out
    end
    -- Optional direct handoff to the current Host query; no canonical record is
    -- exposed to Provider code and ownership stays with this catalog.
    function handle:Query(request,reply)
        local valid,why=current();if not valid then return nil,why end
        valid,why=requestOK(request);if not valid then return nil,why end
        if type(reply)~="function" then return failure("INVALID_SCHEMA","query.reply") end
        local hits=index and index:Search(request.normalized,request.limit,request.filter,"transfer",
            request.preferredEntryID and sourceID..":"..request.preferredEntryID,request.ranking) or {}
        if index then index:ClearQueryCache() end
        local delivered,err=Factory:Deliver(reply,owned,hits)
        if delivered~=false then return delivered,err end
        local public={}
        for at,hit in ipairs(hits) do public[at]={entry=I.RecordCodec:Public(hit.entry.record,owned.id),confidence=hit.confidence,evidence={matchedField=hit.matchedField,matchedText=hit.matchedText,matchType=hit.matchType,confidence=hit.confidence,distance=hit.distance}} end
        return reply(public)
    end
    function handle:Resolve(id)
        local valid,why=current();if not valid then return nil,why end
        local record=index and index:GetRecord(sourceID,id)
        return record and I.RecordCodec:Public(record,owned.id)
    end
    function handle:Clear()
        if closed then return true end
        if index then index:Clear();index=nil end
        count=0
        state.metadataPool,state.actionRecords,state.actionLists=nil,nil,nil
        version=version+1
        return true
    end
    function handle:Close()
        if closed then return true end
        self:Clear();closed=true
        owned,state,index=nil,nil,nil
        return true
    end
    function handle:GetState()
        if closed then return failure("CATALOG_CLOSED") end
        return {revision=version,entries=count}
    end
    return handle
end

-- Dynamic providers may use the shared scorer or supply equivalent evidence
-- themselves. Empty/semantic queries can deliberately return a 0.75 fallback.
function Factory:Score(request,entries,scope)
    local checked,why=requestOK(request);if not checked then return nil,why end
    if scope then checked,why=I.Boundary:ValidateScope(scope,"score.scope");if not checked then return nil,why end end
    local valid,err=I.Boundary:Validate(entries,"score.entries",{maxFields=256,maxDepth=12})
    if not valid then return nil,err end
    if not array(entries,256) or type(request)~="table" or type(request.normalized)~="string" then return failure("INVALID_SCHEMA","score") end
    local hits={}
    for at,entry in ipairs(entries) do
        if type(entry)~="table" then return failure("INVALID_SCHEMA","score.entries") end
        if entry.scope then local ok,why=I.Boundary:ValidateScope(entry.scope,"score.scope");if not ok then return nil,why end end
        local match=I.Search.Normalizer:MatchRecord(request.normalized,entry,scope)
        hits[at]={entry=entry,confidence=match and match.confidence or 0.75,evidence=match}
    end
    return hits
end

-- Batched counterpart to CreateRanker, including the bounded catalog/dynamic
-- merge (20 catalog + at most 256 dynamic hits). Sorts a new array, not entries.
function Factory:SortHits(request,hits,limit)
    local ok,err=requestOK(request);if not ok then return nil,err end
    ok,err=I.Boundary:Validate(hits,"sort.hits",{maxFields=276,maxDepth=14})
    if not ok then return nil,err end
    ok,err=I.Boundary.Access(limit,"sort.limit");if not ok then return nil,err end
    if not array(hits,276) or limit~=nil and (type(limit)~="number" or limit%1~=0 or limit<1 or limit>256) then return failure("INVALID_SCHEMA","sort") end
    local out={}
    for at,hit in ipairs(hits) do
        if type(hit)~="table" or type(hit.entry)~="table" or type(hit.entry.id)~="string" or #hit.entry.id==0 or #hit.entry.id>128
            or type(hit.confidence)~="number" or hit.confidence<0 or hit.confidence>1 then return failure("INVALID_SCHEMA","sort.hit") end
        out[at]=hit
    end
    table.sort(out,function(a,b)
        if request.preferredEntryID or request.ranking then
            local ar=self:RankValue(request.preferredEntryID,request.ranking,a.entry.id,a.confidence)
            local br=self:RankValue(request.preferredEntryID,request.ranking,b.entry.id,b.confidence)
            if ar~=br then return ar>br end
        end
        if a.confidence~=b.confidence then return a.confidence>b.confidence end
        local ac=type(a.entry.category)=="table" and a.entry.category.order or 0
        local bc=type(b.entry.category)=="table" and b.entry.category.order or 0
        if type(ac)~="number" then ac=0 end;if type(bc)~="number" then bc=0 end
        if ac~=bc then return ac<bc end
        return a.entry.id<b.entry.id
    end)
    for at=#out,(limit or #out)+1,-1 do out[at]=nil end
    return out
end
