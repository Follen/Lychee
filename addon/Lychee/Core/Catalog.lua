local I = _G.LycheeInternal
local type, pairs = type, pairs
local Factory = {}
-- Never exposed to public callbacks; the Host only reads empty internal hits.
local EMPTY_HITS = {}
I.CatalogFactory = Factory
local failure=I.Boundary.Failure
local OPTION_KEYS={id=true,title=true,scope=true,i18n=true,actions=true,drags=true,views=true,active=true,changed=true,mode=true,readEntry=true,compact=true}
local function requestOK(request)
    local ok,err=I.Boundary:Validate(request,"query")
    if not ok then return nil,err end
    if type(request)~="table" then return failure("INVALID_SCHEMA","query") end
    local normalized,limit,preferred,filter,ranking = request.normalized,request.limit,request.preferredEntryID,request.filter,request.ranking
    if type(normalized)~="string" or #normalized>1024
        or (limit~=nil and (type(limit)~="number" or limit%1~=0 or limit<1 or limit>256))
        or (preferred~=nil and (type(preferred)~="string" or #preferred>128))
        or (filter~=nil and type(filter)~="table") then return failure("INVALID_SCHEMA","query") end
    if ranking~=nil then
        if type(ranking)~="table" then return failure("INVALID_SCHEMA","query.ranking") end
        local count=0
        for id,weight in pairs(ranking) do
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

local function documentCatalog(owned,state)
    local index,store,writeOwned,closed,busy,reading,clearing=nil,nil,nil,false,false,false,false
    local revision,count,jobs,jobSerial=0,0,{},0
    local maximum=owned.compact and owned.compact.maxEntries or 4096
    if owned.compact then
        local create=I.LycheeSDK and I.LycheeSDK._CreateOwnedCompactStore
        if type(create)~="function" then return failure("SDK_UNAVAILABLE","compact") end
        store,writeOwned=create(owned.compact);if not store then return nil,writeOwned end
    end
    local sourceID=owned.id..":records"
    local handle={}
    local function notifyFailure(context,problem)
        -- Consumer notification cannot interrupt release or poison catalog state.
        if context and type(context.fail)=="function" then pcall(context.fail,problem) end
    end
    local function current(search)
        if closed then return failure("CATALOG_CLOSED") end
        if busy then return failure("CATALOG_BUSY") end
        if search and owned.active then
            busy=true;local called,active=pcall(owned.active);busy=false
            if closed then return failure("CATALOG_CLOSED") end
            if not called or not active then return failure("PROVIDER_DISABLED") end
        end
        return true
    end
    local function release(job)
        if job.done then return end
        job.done=true;jobs[job]=nil
        local task,owner=job.task,job.owner;job.task,job.owner=nil,nil
        job.request,job.reply,job.context,job.hits=nil,nil,nil,nil
        if task then task:Cancel("catalog-ended") end
        if owner then owner:Cancel("catalog-ended") end
    end
    local function cancelJobs(code)
        local pending={};for job in pairs(jobs) do pending[#pending+1]=job end
        for _,job in ipairs(pending) do
            local context=job.context;release(job)
            notifyFailure(context,{code=code or "CATALOG_CANCELLED"})
        end
    end
    local function changed()
        revision=revision+1
        local expected=revision
        cancelJobs("STALE_RESULT")
        if closed then return failure("CATALOG_CLOSED") end
        if revision~=expected then return true end
        if owned.changed and not pcall(owned.changed) then return failure("CALLBACK_ERROR","catalog.changed") end
        return true
    end
    local function ensureIndex()
        if not index then
            index=I.Search.StaticIndex:New();index.resultLimit=257;index.candidateLimit=math.max(maximum,257)
            assert(index:RegisterSource({id=sourceID,version=1,priority=0,scope=owned.scope or {},revision=0,title=owned.title,_extensionID=owned.id}))
        end
        return index
    end
    local function update(delta)
        local valid,why=I.Boundary:Validate(delta,"catalog.update",{maxFields=math.max(maximum,128),maxDepth=12})
        if not valid then return nil,why end
        if type(delta)~="table" then return failure("INVALID_SCHEMA","catalog.update") end
        for key in pairs(delta) do if key~="replace" and key~="upsert" and key~="remove" then return failure("INVALID_SCHEMA","catalog.update."..tostring(key)) end end
        if delta.replace~=nil and (delta.upsert~=nil or delta.remove~=nil) then return failure("INVALID_SCHEMA","catalog.replace") end
        for _,field in ipairs({"replace","upsert","remove"}) do
            if delta[field]~=nil and not array(delta[field],maximum) then return failure("INVALID_SCHEMA","catalog."..field) end
        end
        local list,map=I.RecordCodec:ReceiveDocuments(state,delta.replace or delta.upsert or {},maximum)
        if not list then return nil,map end
        if not array(delta.remove or {},maximum) then return failure("INVALID_SCHEMA","catalog.remove") end
        local removed,nextCount={},delta.replace~=nil and #list or count
        for _,id in ipairs(delta.remove or {}) do
            if type(id)~="string" or id=="" or removed[id] or map[id] then return failure("INVALID_SCHEMA","catalog.remove") end
            removed[id]=true;if index and index:GetRecord(sourceID,id) then nextCount=nextCount-1 end
        end
        if delta.replace==nil then for _,record in ipairs(list) do if not index or not index:GetRecord(sourceID,record.id) then nextCount=nextCount+1 end end end
        if nextCount>maximum then return failure("RESULT_LIMIT","catalog") end
        -- The receiving boundary owns these records. Storage and index share
        -- that one canonical graph; no public object exposes the write capability.
        if store then
            local accepted,err,_,canonical=writeOwned(delta.replace~=nil and {replace=list} or {upsert=list,remove=delta.remove})
            if not accepted then return nil,err end
            list=canonical
        end
        local target=ensureIndex();local ok,code,_,different
        if delta.replace~=nil then ok,code,_,different=target:CommitSnapshot(sourceID,list)
        else ok,code,_,different=target:ApplyDelta(sourceID,list,delta.remove or {}) end
        if not ok then return failure(code or "INVALID_RESULT","catalog.update") end
        count=nextCount;return true,nil,different
    end
    function handle:Update(delta)
        local valid,why=current(false);if not valid then return nil,why end
        busy=true;local called,ok,err,different=pcall(update,delta);busy=false
        if not called then return failure("CALLBACK_ERROR","catalog.update") end
        if ok and different then return changed() end
        return ok,err
    end
    function handle:Invalidate()
        local valid,why=current(false);if not valid then return nil,why end
        return changed()
    end
    local function read(id,expected,reason,resources)
        if reading then return failure("CATALOG_BUSY","readEntry") end
        if closed or revision~=expected then return failure("STALE_RESULT","readEntry") end
        reading=true
        local called,record,err=pcall(owned.readEntry,id,{ref={providerID=owned.id,entryID=id},revision=expected,reason=reason,resources=resources})
        reading=false
        if closed or revision~=expected then return failure("STALE_RESULT","readEntry") end
        if not called then return failure("CALLBACK_ERROR","readEntry") end
        if record==nil then return nil,err end
        local result,why=I.RecordCodec:ReceivePublic(state,record)
        if not result then return nil,why end
        if result.id~=id then return failure("INVALID_REFERENCE","readEntry.id") end
        return result
    end
    local function public(hits)
        local out={}
        for n,hit in ipairs(hits) do out[n]={entry=hit.entry.record,confidence=hit.confidence,
            evidence=hit.evidence} end
        return out
    end
    local function collect(request,context,expected,checkpoint)
        local target=index
        local out,seen,readIDs={},{},{}
        local limit=request.limit or 20
        local more=false
        local function search(maximum)
            if not target then return {} end
            local hits=target:Search(request.normalized,maximum,request.filter,"transfer",request.preferredEntryID and sourceID..":"..request.preferredEntryID,request.ranking,checkpoint)
            target:ClearQueryCache()
            return hits
        end
        local function consume(hits)
            more=#hits>256
            for at,hit in ipairs(hits) do
                if at>256 then break end
                local id=hit.entry.record.id
                if not readIDs[id] then
                    if checkpoint then checkpoint() end
                    readIDs[id]=true
                    local record,err=read(id,expected,"query",context and context.resources)
                    if err then return nil,err end
                    if record then
                        local ref=record.invocation or record.command or record.targetRef or {providerID=owned.id,entryID=record.id}
                        local key,why=I.Search.RuntimeIdentity:ReferenceKey(ref)
                        if not key then return nil,why end
                        if not seen[key] then
                            seen[key]=true;hit.entry={record=record};out[#out+1]=hit
                            if #out>=limit then break end
                        end
                    end
                end
            end
            return true
        end
        local hits=search(limit)
        local ok,err=consume(hits);if not ok then return nil,err end
        -- Most readers are one-to-one. Only missing/duplicate identities need
        -- the bounded overflow scan; never materialize 257 hit objects by default.
        if #out<limit and #hits==limit then
            hits=search(257)
            ok,err=consume(hits);if not ok then return nil,err end
        end
        if closed or revision~=expected then return failure("STALE_RESULT","catalog.query") end
        if more and #out<limit then return failure("RESULT_LIMIT","catalog.query") end
        return out
    end
    function handle:Search(request)
        local valid,why=current(true);if not valid then return nil,why end
        valid,why=requestOK(request);if not valid then return nil,why end
        local called,hits,err=pcall(collect,request,nil,revision)
        if not called then return failure("CALLBACK_ERROR","catalog.search") end
        if not hits then return nil,err end
        return public(hits)
    end
    local function deliver(request,reply,context,expected,checkpoint)
        local hits,err=collect(request,context,expected,checkpoint)
        if not hits then return nil,err end
        return reply(public(hits))
    end
    local function publish(reply,definition,hits)
        return reply(public(hits))
    end
    function handle:Query(request,reply,context)
        local valid,why=current(true);if not valid then return nil,why end
        valid,why=requestOK(request);if not valid then return nil,why end
        if type(reply)~="function" then return failure("INVALID_SCHEMA","query.reply") end
        if not context or not context.resources then
            local called,ok,err=pcall(deliver,request,reply,context,revision)
            if not called then return failure("CALLBACK_ERROR","catalog.query") end
            return ok,err
        end
        if type(context.fail)~="function" or type(context.deadline)~="number" or context.deadline~=context.deadline then return failure("INVALID_SCHEMA","query.context") end
        local job={request=I.Boundary.CopyPlain(request),reply=reply,context=context,revision=revision};jobs[job]=true
        local function failed(problem)
            if job.done then return end
            local ctx=job.context;release(job)
            if type(problem)~="table" then problem={code="CALLBACK_ERROR",field="catalog.query"} end
            notifyFailure(ctx,problem)
        end
        local resources=context.resources
        jobSerial=jobSerial+1
        local resourceKey="catalog:"..owned.id..":"..jobSerial
        local owner,err=resources:Own(resourceKey,function() release(job) end)
        if not owner then failed(err);return nil,err end
        if job.done then owner:Cancel("catalog-ended");return failure("CATALOG_CANCELLED") end
        job.owner=owner
        local token
        token,err=resources:Run(resourceKey,function()
            local n,started=0,I.Providers:QueryTime()
            local function checkpoint()
                if job.done or closed or revision~=job.revision then error({code="STALE_RESULT"}) end
                local now=I.Providers:QueryTime()
                if now>=job.context.deadline then error({code="QUERY_TIMEOUT"}) end
                n=n+1
                if n>=256 or now-started>=0.001 then
                    n=0;coroutine.yield();started=I.Providers:QueryTime()
                    if job.done or closed or revision~=job.revision then error({code="STALE_RESULT"}) end
                    if started>=job.context.deadline then error({code="QUERY_TIMEOUT"}) end
                    return (started-now)*1000
                end
            end
            checkpoint()
            local hits,problem=collect(job.request,job.context,job.revision,checkpoint)
            if not hits then error(problem) end
            job.hits=hits;return hits
        end,{complete=function(hits)
            if job.done then return end
            local send,ctx,expected=job.reply,job.context,job.revision
            if closed or revision~=expected then failed({code="STALE_RESULT"});return end
            if I.Providers:QueryTime()>=ctx.deadline then failed({code="QUERY_TIMEOUT"});return end
            local definition=owned;release(job)
            local called,ok,problem=pcall(publish,send,definition,hits)
            if not called then notifyFailure(ctx,{code="CALLBACK_ERROR",field="query.reply"})
            elseif not ok and problem and problem.code~="STALE_REQUEST" then notifyFailure(ctx,problem) end
        end,error=failed})
        if not token then failed(err);return nil,err end
        if job.done then token:Cancel("catalog-ended") else job.task=token end
        return true
    end
    function handle:Resolve(id)
        local valid,why=current(false);if not valid then return nil,why end
        valid,why=I.Boundary.Access(id,"resolve.id");if not valid then return nil,why end
        if type(id)~="string" or #id==0 or #id>128 then return failure("INVALID_SCHEMA","resolve.id") end
        local record,err=read(id,revision,"resolve");if not record then return nil,err end
        return record
    end
    local function clear(closing)
        if closed then return true end
        if clearing then if closing then closed=true end;return true end
        clearing,busy=true,true
        if closing then closed=true end
        local old=index;index=nil;count=0;revision=revision+1
        cancelJobs("CATALOG_CANCELLED")
        if old then old:Clear() end
        if store then if closed then store:Close() else store:Clear() end end
        state.metadataPool,state.actionRecords,state.actionLists=nil,nil,nil
        if closed then owned,state,store,writeOwned=nil,nil,nil,nil end
        clearing,busy=false,false
        return true
    end
    function handle:Clear() return clear(false) end
    function handle:Close()
        return clear(true)
    end
    function handle:GetState()
        if closed then return failure("CATALOG_CLOSED") end
        local out={revision=revision,entries=count}
        if store then out.bytes=store:GetState().bytes end
        return out
    end
    return handle
end

-- Optional SDK factory. Each returned object is owned by its caller; no Host
-- registry, saved variable, active catalog list, or source subscription retains it.
function Factory:Create(options)
    local ok,err=I.Boundary:Validate(options,"catalog",{maxFields=256,maxDepth=12,
        callbacks={run=true,begin=true,create=true,changed=true,active=true,readEntry=true}})
    if not ok then return nil,err end
    if type(options)~="table" or type(options.id)~="string" or #options.id>64
        or not options.id:match("^[a-z0-9][a-z0-9%.%-]*$") then return failure("INVALID_SCHEMA","catalog.id") end
    for key in pairs(options) do
        if not OPTION_KEYS[key] then return failure("INVALID_SCHEMA","catalog."..tostring(key)) end
    end
    for _,key in ipairs({"active","changed"}) do if options[key]~=nil and type(options[key])~="function" then return failure("INVALID_SCHEMA","catalog."..key) end end
    for _,key in ipairs({"actions","drags","views"}) do if options[key]~=nil and type(options[key])~="table" then return failure("INVALID_SCHEMA","catalog."..key) end end
    if options.mode~=nil and options.mode~="entries" and options.mode~="documents" then return failure("INVALID_SCHEMA","catalog.mode") end
    if options.mode=="documents" then
        if type(options.readEntry)~="function" then return failure("INVALID_SCHEMA","catalog.readEntry") end
        if options.compact~=nil and type(options.compact)~="table" then return failure("INVALID_SCHEMA","catalog.compact") end
    elseif options.readEntry~=nil or options.compact~=nil then return failure("INVALID_SCHEMA","catalog.mode") end
    local scopeOK,scopeError=I.Boundary:ValidateScope(options.scope or {},"catalog.scope")
    if not scopeOK then return nil,scopeError end
    local owned
    -- Public options are validated before copying; callbacks remain caller-owned.
    owned=I.Boundary.CopyPlain(options)
    local localizer
    if owned.i18n then localizer,err=I.ProviderLocales:Compile(owned.i18n);if not localizer then return nil,err end end
    local state={id=owned.id,definition=owned,localizer=localizer}
    if owned.mode=="documents" then return documentCatalog(owned,state) end
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
        for _,field in ipairs({"replace","upsert","remove"}) do
            if delta[field]~=nil and not array(delta[field],4096) then return failure("INVALID_SCHEMA","catalog."..field) end
        end
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
    function handle:Invalidate()
        local valid,why=current();if not valid then return nil,why end
        if index then index:Invalidate(sourceID) end
        return changed()
    end
    function handle:Search(request)
        local valid,why=current();if not valid then return nil,why end
        valid,why=requestOK(request);if not valid then return nil,why end
        if not index then return {} end
        if count==0 then index:ClearQueryCache();return {} end
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
        local hits=index and count>0 and index:Search(request.normalized,request.limit,request.filter,"transfer",
            request.preferredEntryID and sourceID..":"..request.preferredEntryID,request.ranking) or EMPTY_HITS
        if index then index:ClearQueryCache() end
        local public={}
        for at,hit in ipairs(hits) do public[at]={entry=I.RecordCodec:Public(hit.entry.record,owned.id),confidence=hit.confidence,evidence=I.Boundary.CopyPlain(hit.evidence)} end
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
