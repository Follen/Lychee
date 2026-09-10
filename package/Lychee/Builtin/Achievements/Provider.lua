local I=_G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.achievements")
local N=I.Search.Normalizer
local M
local LIMIT=32768
local function combat() return InCombatLockdown and InCombatLockdown() end
local function integer(v) return type(v)=="number" and v>0 and v<=2147483647 and v==math.floor(v) end
local function identityKey()
    local r=I.Search.RuntimeIdentity:Current()
    local guid=UnitGUID("player")
    if type(guid)~="string" then error("ACHIEVEMENT_IDENTITY_PENDING") end
    local domain=table.concat({"achievement-v3",r.product,r.build,r.locale},"|").."|"
    return domain..guid,domain
end
-- Persistent base is immutable. Blocks are parallel ids/texts/categories arrays.
-- Role ops are {signedStart, length, ...}: positive references base, negative extra.
-- Updates store changed IDs in first-update order; new IDs append when materialized.
-- Never publish the mutable active arrays into SavedVariables.
local function dense(array,limit,checkpoint)
    if type(array)~="table" or #array>limit then return false end
    local count,n=0,#array
    for key in pairs(array) do
        count=count+1
        if count>limit or not integer(key) or key>n then return false end
        if count%16==0 then checkpoint() end
    end
    return count==n
end
local function block(ids,texts,categories)
    return {ids=ids or {},texts=texts or {},categories=categories or {},bytes=0}
end
local function validateBlock(raw,checkpoint)
    if type(raw)~="table" or not dense(raw.ids,LIMIT,checkpoint)
        or not dense(raw.texts,LIMIT,checkpoint) or not dense(raw.categories,LIMIT,checkpoint) then return end
    local n=#raw.ids
    if #raw.texts~=n or #raw.categories~=n then return end
    local bytes,seen=0,{}
    for index=1,n do
        local id,text,category=raw.ids[index],raw.texts[index],raw.categories[index]
        if not integer(id) or seen[id] or type(text)~="string" or #text>512 or not integer(category) then return end
        seen[id]=index;bytes=bytes+#text
        if bytes>4194304 then return end
        if index%16==0 then checkpoint() end
    end
    local value=block(raw.ids,raw.texts,raw.categories);value.bytes=bytes
    return value,seen
end
local function validateRole(raw,base,domain,checkpoint)
    if type(raw)~="table" or type(raw.key)~="string" or #raw.key>#domain+128 or raw.key:sub(1,#domain)~=domain
        or type(raw.counts)~="table" or not dense(raw.ops,LIMIT*2,checkpoint) or #raw.ops%2~=0 then return end
    local stamp=raw.builtAt
    if type(stamp)~="number" or stamp~=stamp or stamp<0 or stamp>GetServerTime() then return end
    local counts,count={},0
    for category,total in pairs(raw.counts) do
        count=count+1
        if count>512 or not integer(category) or type(total)~="number" or total<0 or total>LIMIT or total~=math.floor(total) then return end
        counts[category]=total
        checkpoint()
    end
    local extra=validateBlock(raw.extra,checkpoint)
    local updates=validateBlock(raw.updates,checkpoint)
    if not extra or not updates then return end
    local n=0
    for index=1,#raw.ops,2 do
        local first,length=raw.ops[index],raw.ops[index+1]
        if type(first)~="number" or not integer(math.abs(first)) or not integer(length) then return end
        local source=first>0 and base or extra
        if math.abs(first)+length-1>#source.ids then return end
        n=n+length;if n>LIMIT then return end
        if index%16==1 then checkpoint() end
    end
    return {key=raw.key,ops=raw.ops,extra=extra,updates=updates,counts=counts,builtAt=stamp}
end
local function trimStore(store)
    local entries=store.entries
    while #entries>10 do table.remove(entries) end
    local count,bytes,ops=#store.base.ids,store.base.bytes,0
    for _,role in ipairs(entries) do
        count=count+#role.extra.ids+#role.updates.ids
        bytes=bytes+role.extra.bytes+role.updates.bytes
        ops=ops+#role.ops
    end
    while #entries>0 and (count>LIMIT*2 or bytes>4194304 or ops>LIMIT*2) do
        local role=table.remove(entries)
        count=count-#role.extra.ids-#role.updates.ids
        bytes=bytes-role.extra.bytes-role.updates.bytes
        ops=ops-#role.ops
    end
end
local function promote(self,role)
    local entries=self.store.entries
    for index=#entries,1,-1 do if entries[index].key==role.key then table.remove(entries,index) end end
    table.insert(entries,1,role)
    trimStore(self.store)
    LycheeDB.achievementCatalog=self.store
end
local function save(self,cache,checkpoint)
    local base=self.store.base
    if #base.ids==0 then
        local ids,texts,categories,positions={},{},{},{}
        for index,id in ipairs(cache.ids) do
            ids[index],texts[index],categories[index],positions[id]=id,cache.texts[index],cache.categories[index],index
            if index%16==0 then checkpoint() end
        end
        base=block(ids,texts,categories);base.bytes=cache.bytes
        self.store.base,self.basePositions=base,positions
    end
    local role={key=cache.key,counts=cache.counts,builtAt=cache.builtAt,ops={},extra=block(),updates=block()}
    local ops,extra=role.ops,role.extra
    for index,id in ipairs(cache.ids) do
        local position=self.basePositions[id]
        local reference
        if position and base.texts[position]==cache.texts[index] and base.categories[position]==cache.categories[index] then
            reference=position
        else
            local at=#extra.ids+1
            extra.ids[at],extra.texts[at],extra.categories[at]=id,cache.texts[index],cache.categories[index]
            extra.bytes=extra.bytes+#cache.texts[index]
            reference=-at
        end
        local n=#ops
        if n>0 and ((reference>0 and ops[n-1]>0 and reference==ops[n-1]+ops[n])
            or (reference<0 and ops[n-1]<0 and reference==ops[n-1]-ops[n])) then
            ops[n]=ops[n]+1
        else ops[n+1],ops[n+2]=reference,1 end
        if index%16==0 then checkpoint() end
    end
    self.role,self.updatePositions=role,{}
    promote(self,role)
end
local function updateRole(self,id,text,category)
    local updates=self.role.updates
    local position=self.updatePositions[id]
    updates.bytes=updates.bytes-(position and #updates.texts[position] or 0)+#text
    position=position or #updates.ids+1
    updates.ids[position],updates.texts[position],updates.categories[position]=id,text,category
    self.updatePositions[id]=position
    trimStore(self.store)
end
local function restore(self,checkpoint)
    local raw=LycheeDB.achievementCatalog
    local store={schema=3,domain=self.cacheDomain,base=block(),entries={}}
    local base,basePositions
    if type(raw)=="table" and raw.schema==3 and raw.domain==self.cacheDomain then
        base,basePositions=validateBlock(raw.base,checkpoint)
        if base and dense(raw.entries,10,checkpoint) then
            store.base=base
            local keys={}
            for _,candidate in ipairs(raw.entries) do
                local role=validateRole(candidate,base,self.cacheDomain,checkpoint)
                if role and not keys[role.key] then keys[role.key]=true;store.entries[#store.entries+1]=role end
            end
        else base,basePositions=nil,nil end
    end
    self.store,self.basePositions=store,basePositions or {}
    trimStore(store);LycheeDB.achievementCatalog=store
    local role
    for _,candidate in ipairs(store.entries) do if candidate.key==self.cacheKey then role=candidate;break end end
    if not role or role.builtAt<GetServerTime()-604800 then return false end
    local ids,texts,owners,positions={},{},{},{}
    local bytes=0
    for index=1,#role.ops,2 do
        local first,length=role.ops[index],role.ops[index+1]
        local source=first>0 and base or role.extra
        first=math.abs(first)
        for at=first,first+length-1 do
            local id=source.ids[at]
            if positions[id] then return false end
            local n=#ids+1
            ids[n],texts[n],owners[n],positions[id]=id,source.texts[at],source.categories[at],n
            bytes=bytes+#texts[n]
            if n%16==0 then checkpoint() end
        end
    end
    local updatePositions={}
    for at,id in ipairs(role.updates.ids) do
        local index=positions[id] or #ids+1
        if index>LIMIT then return false end
        bytes=bytes-(texts[index] and #texts[index] or 0)+#role.updates.texts[at]
        ids[index],texts[index],owners[index],positions[id]=id,role.updates.texts[at],role.updates.categories[at],index
        updatePositions[id]=at
        if at%16==0 then checkpoint() end
    end
    if bytes>4194304 then return false end
    for index,category in ipairs(owners) do
        if role.counts[category]==nil then return false end
        if index%16==0 then checkpoint() end
    end
    local categories=GetCategoryList()
    if #categories>512 then error("ACHIEVEMENT_CATEGORY_LIMIT") end
    local live,changed={},{}
    for _,category in ipairs(categories) do
        live[category]=true
        if role.counts[category]~=(GetCategoryNumAchievements(category) or 0) then changed[category]=true end
        checkpoint()
    end
    for category in pairs(role.counts) do if not live[category] then changed[category]=true end end
    self.ids,self.texts,self.positions=ids,texts,positions
    self.cache={key=role.key,ids=ids,texts=texts,categories=owners,counts=role.counts,builtAt=role.builtAt,bytes=bytes}
    self.role,self.updatePositions=role,updatePositions
    self.changedCategories=next(changed) and changed or nil
    promote(self,role)
    return true
end
local function fullBuild(self,checkpoint,changed)
    if not GetCategoryList or not GetAchievementInfo then error("ACHIEVEMENT_API_UNAVAILABLE") end
    local ids,texts,owners,positions,counts={},{},{},{},{}
    local bytes=0
    local function put(id,text,category)
        if positions[id] then return false end
        if #ids>=LIMIT then error("ACHIEVEMENT_CATALOG_LIMIT") end
        bytes=bytes+#text
        if #text>512 or bytes>4194304 then error("ACHIEVEMENT_TEXT_LIMIT") end
        local index=#ids+1
        ids[index],texts[index],owners[index],positions[id]=id,text,category,index
        return true
    end
    if changed then
        for index,id in ipairs(self.ids) do
            local category=self.cache.categories[index]
            if not changed[category] then put(id,self.texts[index],category) end
            if index%16==0 then checkpoint() end
        end
    end
    local function add(id,category,name)
        if not integer(id) or positions[id] then return false end
        if not name then local found;found,name=GetAchievementInfo(id);if not found then return false end end
        if not name then return false end
        local added=put(id,N:Normalize(name),category)
        checkpoint()
        return added
    end
    local categories=GetCategoryList()
    if #categories>512 then error("ACHIEVEMENT_CATEGORY_LIMIT") end
    for _,category in ipairs(categories) do
        local total=GetCategoryNumAchievements(category) or 0
        counts[category]=total
        if not changed or changed[category] then
            for index=1,total do
                local id,name=GetAchievementInfo(category,index)
                if add(id,category,name) then
                    local previous=GetPreviousAchievement(id)
                    while add(previous,category) do previous=GetPreviousAchievement(previous) end
                    local nextID=GetNextAchievement(id)
                    while add(nextID,category) do nextID=GetNextAchievement(nextID) end
                else checkpoint() end
            end
        end
        checkpoint()
    end
    local cache={key=self.cacheKey,ids=ids,texts=texts,categories=owners,counts=counts,
        builtAt=changed and self.cache.builtAt or GetServerTime(),bytes=bytes}
    save(self,cache,checkpoint)
    self.ids,self.texts,self.positions,self.cache=ids,texts,positions,cache
    if not changed then self.pendingIDs,self.pendingCount={},0 end
    self.forceFull,self.changedCategories=nil,nil
end
local function increment(self,checkpoint)
    local seen={}
    local function add(id)
        if not integer(id) or seen[id] then return false end
        seen[id]=true
        local found,name=GetAchievementInfo(id)
        if not found or not name then error("ACHIEVEMENT_DATA_PENDING") end
        local text=N:Normalize(name)
        local index=self.positions[id]
        local bytes=self.cache.bytes-(index and #self.texts[index] or 0)+#text
        if #text>512 or bytes>4194304 or (not index and #self.ids>=LIMIT) then error("ACHIEVEMENT_CATALOG_LIMIT") end
        index=index or #self.ids+1
        local category=GetAchievementCategory(id)
        if not integer(category) then error("ACHIEVEMENT_CATEGORY_PENDING") end
        if self.ids[index]==id and self.texts[index]==text and self.cache.categories[index]==category then
            checkpoint();return true
        end
        self.ids[index],self.texts[index],self.positions[id]=id,text,index
        self.cache.categories[index]=category
        if self.cache.counts[category]==nil then self.cache.counts[category]=GetCategoryNumAchievements(category) or 0 end
        self.cache.bytes=bytes
        updateRole(self,id,text,category)
        checkpoint()
        return true
    end
    for id in pairs(self.pendingIDs) do
        if add(id) then
            local previous=GetPreviousAchievement(id)
            while add(previous) do previous=GetPreviousAchievement(previous) end
            local nextID=GetNextAchievement(id)
            while add(nextID) do nextID=GetNextAchievement(nextID) end
        end
        local category=self.cache.categories[self.positions[id]]
        if category and self.cache.counts[category]~=nil then
            self.cache.counts[category]=GetCategoryNumAchievements(category) or 0
        end
        self.pendingIDs[id]=nil;self.pendingCount=self.pendingCount-1
        checkpoint()
    end
end
local function build(self,_,checkpoint)
    if self.restoreCache then
        self.cacheKey,self.cacheDomain=identityKey()
        local restored=restore(self,checkpoint)
        self.restoreCache=nil
        if not restored then self.forceFull=true end
    end
    if not self.ids or self.forceFull then fullBuild(self,checkpoint)
    elseif self.changedCategories then fullBuild(self,checkpoint,self.changedCategories) end
    if self.pendingCount>0 then increment(self,checkpoint) end
end
local function record(id)
    local found,name,points,completed,_,_,_,description,_,icon=GetAchievementInfo(id)
    if not found or not name then return nil end
    local total=GetAchievementNumCriteria(id) or 0
    local done,quantity,required=0,nil,nil
    -- Criteria can be numerous; summarize conditions, not their full text trees.
    if total>256 then total=0 end
    for index=1,total do
        local _,_,complete,q,r=GetAchievementCriteriaInfo(id,index)
        if complete then done=done+1 end
        if total==1 then quantity,required=q,r end
    end
    local progress=completed and L["已完成"] or (total>0 and (L:Format("条件 %d/%d",done,total)) or L["未完成"])
    if not completed and quantity and required and required>0 then progress=L:Format("进度 %s/%s",quantity,required) end
    return {id="achievement:"..id,title=name,kind="achievement",kindTitle=L["成就"],icon=icon,
        subtitle=L:Format("%s · %d 点 · Shift 点击贴到聊天框",progress,points or 0),
        description=description,payload={achievementID=id},actions={"open","share"}}
end
local function share(entry)
    if combat() then return {ok=false,code="COMBAT_LOCKED"} end
    local link=GetAchievementLink(entry.payload.achievementID)
    if not link or not ChatFrameUtil then return {ok=false,message=L["当前无法生成成就链接"]} end
    if not ChatFrameUtil.InsertLink(link) and not ChatFrameUtil.OpenChat(link) then return {ok=false,message=L["当前无法打开聊天输入框"]} end
    return {ok=true,close=true}
end
local function open(entry)
    if IsShiftKeyDown() then return share(entry) end
    return I.Builtin.InterfaceActions:Run(function()
        local id=entry.payload.achievementID
        if not GetAchievementInfo(id) then return false end
        if not AchievementFrame or not AchievementFrame:IsShown() then ToggleAchievementFrame() end
        if not AchievementFrame or not AchievementFrame:IsShown() or not AchievementFrame_SelectAchievement then return false end
        AchievementFrame_SelectAchievement(id,true)
        return true
    end,L)
end
M=I.Builtin.CatalogProvider:New("builtin.achievements",L["成就"],{"ACHIEVEMENT_EARNED"},build,
    {open={title=L["查看成就"],run=open},share={title=L["贴到聊天框"],run=share}})
M.resolve=function(key)
    local id=type(key)=="string" and tonumber(key:match("^achievement:(%d+)$"))
    return id and record(id) or nil
end
M.batchSize,M.batchDelay=128,0
function M:onReady()
    self.needsWork=false
    local resume=self.resumeQuery;self.resumeQuery=nil
    if resume then resume();return true end
end
function M:onStart()
    self.lastError=nil;self.restoreCache=true;self.needsWork=true
    self.pendingIDs,self.pendingCount={},0
end
function M:hasWork()
    return self.needsWork
end
function M:onPause()
    if self.cancelQuery then self.cancelQuery() end
end
function M:onEvent(event,id)
    if event=="ACHIEVEMENT_EARNED" then
        if not integer(id) then return end
        if not self.pendingIDs[id] then
            if self.pendingCount>=256 then self.forceFull=true
            else self.pendingIDs[id]=true;self.pendingCount=self.pendingCount+1 end
        end
        self.needsWork=true
    end
    self:MarkDirty()
end
function M:onStop()
    if self.cancelQuery then self.cancelQuery();self.cancelQuery=nil end
    self.ids,self.texts,self.positions,self.cache=nil,nil,nil,nil
    self.pendingIDs,self.pendingCount,self.needsWork=nil,0,false
    self.store,self.changedCategories=nil,nil
    self.basePositions,self.role,self.updatePositions=nil,nil,nil
end
M.query=function(request,reply)
    if M.cancelQuery then M.cancelQuery() end
    if combat() then reply({});return end
    local query=request.normalized or ""
    if query=="成就" or query=="achievements" or query=="achievement" then query="" end
    local terms=N:Terms(query)
    local numericID=tonumber(query)
    local selected,position={},1
    local limit=math.min(50,tonumber(request.limit) or 50)
    local timer,cancelled,result,records
    local function cancel()
        cancelled=true
        if timer then timer:Cancel();timer=nil end
        selected=nil;reply=nil;result=nil;records=nil
        M.resumeQuery=nil
        if M.cancelQuery==cancel then M.cancelQuery=nil end
    end
    M.cancelQuery=cancel
    local function step()
        timer=nil
        if cancelled or not M.active or combat() then cancel();return end
        if not M.ids then
            if M.lastError then local send=reply;cancel();send({});return end
            M.resumeQuery=step;return
        else
            local started=debugprofilestop and debugprofilestop() or 0
            local count=0
            while position<=#M.ids and count<256 do
                local id,title=M.ids[position],M.texts[position]
                local match=true
                if numericID~=id then
                    for _,term in ipairs(terms) do if not I.Search.Normalizer:FindLiteral(term,title) then match=false;break end end
                end
                if match then
                    local rank=(numericID==id or query==title) and 3 or (query~="" and title:find(query,1,true)==1 and 2 or 1)
                    local at=#selected+1
                    for i,item in ipairs(selected) do if rank>item.rank or (rank==item.rank and id<item.id) then at=i;break end end
                    if at<=limit then
                        table.insert(selected,at,{id=id,rank=rank})
                        if #selected>limit then selected[#selected]=nil end
                    end
                end
                position=position+1;count=count+1
                if debugprofilestop and debugprofilestop()-started>=1 then break end
            end
            if position>#M.ids then
                result={}
                -- Materialization is sliced independently of the directory scan.
                for _,item in ipairs(selected) do result[#result+1]=item.id end
                local index=1;records={}
                local function finish()
                    timer=nil
                    if cancelled or not M.active or combat() then cancel();return end
                    local started=debugprofilestop and debugprofilestop() or 0
                    local count=0
                    while index<=#result and count<8 do
                        local value=record(result[index]);if value then records[#records+1]=value end
                        index=index+1;count=count+1
                        if debugprofilestop and debugprofilestop()-started>=1 then break end
                    end
                    if index<=#result then timer=C_Timer.NewTimer(0,finish)
                    else local send,output=reply,records;cancel();send(output) end
                end
                finish();return
            end
        end
        timer=C_Timer.NewTimer(0,step)
    end
    step()
    return cancel
end
I.Builtin.Achievements=M
