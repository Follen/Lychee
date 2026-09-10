local I=_G.LycheeInternal
local N=I.Search.Normalizer
local M
local LIMIT=32768
local function combat() return InCombatLockdown and InCombatLockdown() end
local function fullBuild(self,checkpoint)
    if not GetCategoryList or not GetAchievementInfo then error("ACHIEVEMENT_API_UNAVAILABLE") end
    local ids,texts,seen,counts={},{},{},{}
    local bytes=0
    local function add(id)
        if not id or seen[id] then return false end
        seen[id]=true
        local found,name=GetAchievementInfo(id)
        if found and name then
            if #ids>=LIMIT then error("ACHIEVEMENT_CATALOG_LIMIT") end
            local text=N:Normalize(name)
            bytes=bytes+#text
            if #text>512 or bytes>4194304 then error("ACHIEVEMENT_TEXT_LIMIT") end
            ids[#ids+1]=id;texts[#texts+1]=text
        end
        checkpoint()
        return true
    end
    local categories=GetCategoryList()
    if #categories>512 then error("ACHIEVEMENT_CATEGORY_LIMIT") end
    for _,category in ipairs(categories) do
        -- Match the category-index domain used by Blizzard's achievement list.
        -- Superseded stages are added through the series APIs below.
        local total=GetCategoryNumAchievements(category) or 0
        counts[category]=total
        for index=1,total do
            local id=GetAchievementInfo(category,index)
            if add(id) then
                local previous=GetPreviousAchievement(id)
                while previous and not seen[previous] do add(previous);previous=GetPreviousAchievement(previous) end
                local nextID=GetNextAchievement(id)
                while nextID and not seen[nextID] do add(nextID);nextID=GetNextAchievement(nextID) end
            else checkpoint() end
        end
        checkpoint()
    end
    local positions={}
    for index,id in ipairs(ids) do positions[id]=index;checkpoint() end
    local cache={key=self.cacheKey,ids=ids,texts=texts,counts=counts,builtAt=GetServerTime(),bytes=bytes}
    LycheeDB.achievementCatalog=cache
    self.ids,self.texts,self.positions,self.cache=ids,texts,positions,cache
    self.pendingIDs,self.pendingCount={},0
    self.forceFull=nil
end
local function identityKey()
    local r=I.Search.RuntimeIdentity:Current()
    local guid=UnitGUID("player")
    if type(guid)~="string" then error("ACHIEVEMENT_IDENTITY_PENDING") end
    return table.concat({"achievement-v1",r.product,r.build,r.locale,guid},"|")
end
local function integer(v) return type(v)=="number" and v>0 and v<=2147483647 and v==math.floor(v) end
local function restore(self,checkpoint)
    local examined=0
    local function metadataCheckpoint()
        examined=examined+1
        if examined%16==0 then checkpoint() end
    end
    local cache=LycheeDB.achievementCatalog
    if type(cache)~="table" or cache.key~=self.cacheKey or type(cache.ids)~="table" or type(cache.texts)~="table" or type(cache.counts)~="table" then return false end
    local stamp=cache.builtAt
    local now=GetServerTime()
    if type(stamp)~="number" or stamp~=stamp or stamp>now or stamp<now-604800 then return false end
    local n=#cache.ids
    if n<1 or n>LIMIT or #cache.texts~=n then return false end
    local count=0
    for k in pairs(cache.ids) do
        count=count+1;if count>LIMIT or not integer(k) or k>n then return false end
        metadataCheckpoint()
    end
    if count~=n then return false end
    count=0
    for k in pairs(cache.texts) do
        count=count+1;if count>LIMIT or not integer(k) or k>n then return false end
        metadataCheckpoint()
    end
    if count~=n then return false end
    local positions,bytes={},0
    for index=1,n do
        local id,text=cache.ids[index],cache.texts[index]
        if not integer(id) or positions[id] or type(text)~="string" or #text>512 then return false end
        bytes=bytes+#text;if bytes>4194304 then return false end
        positions[id]=index;metadataCheckpoint()
    end
    count=0
    for id,total in pairs(cache.counts) do
        count=count+1
        if count>512 or not integer(id) or type(total)~="number" or total<0 or total>LIMIT or total~=math.floor(total) then return false end
        metadataCheckpoint()
    end
    local categories=GetCategoryList()
    if #categories~=count then return false end
    for _,category in ipairs(categories) do
        if cache.counts[category]~=(GetCategoryNumAchievements(category) or 0) then return false end
        checkpoint()
    end
    cache={key=self.cacheKey,ids=cache.ids,texts=cache.texts,counts=cache.counts,builtAt=stamp,bytes=bytes}
    LycheeDB.achievementCatalog=cache
    self.ids,self.texts,self.positions,self.cache=cache.ids,cache.texts,positions,cache
    return true
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
        self.ids[index],self.texts[index],self.positions[id]=id,text,index
        self.cache.bytes=bytes
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
        local category=GetAchievementCategory(id)
        if category and self.cache.counts[category]~=nil then
            self.cache.counts[category]=GetCategoryNumAchievements(category) or 0
        end
        self.pendingIDs[id]=nil;self.pendingCount=self.pendingCount-1
        checkpoint()
    end
end
local function build(self,_,checkpoint)
    if self.restoreCache then
        self.cacheKey=identityKey()
        local restored=restore(self,checkpoint)
        self.restoreCache=nil
        if not restored then LycheeDB.achievementCatalog=nil;self.forceFull=true end
    end
    if not self.ids or self.forceFull then fullBuild(self,checkpoint)
    elseif self.pendingCount>0 then increment(self,checkpoint) end
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
    local progress=completed and "已完成" or (total>0 and ("条件 "..done.."/"..total) or "未完成")
    if not completed and quantity and required and required>0 then progress="进度 "..quantity.."/"..required end
    return {id="achievement:"..id,title=name,kind="achievement",kindTitle="成就",icon=icon,
        subtitle=progress.." · "..(points or 0).." 点 · Shift 点击贴到聊天框",
        description=description,payload={achievementID=id},actions={"open","share"}}
end
local function share(entry)
    if combat() then return {ok=false,code="COMBAT_LOCKED"} end
    local link=GetAchievementLink(entry.payload.achievementID)
    if not link or not ChatFrameUtil then return {ok=false,message="当前无法生成成就链接"} end
    if not ChatFrameUtil.InsertLink(link) and not ChatFrameUtil.OpenChat(link) then return {ok=false,message="当前无法打开聊天输入框"} end
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
    end)
end
M=I.Builtin.CatalogProvider:New("builtin.achievements","成就",{"ACHIEVEMENT_EARNED"},build,
    {open={title="查看成就",run=open},share={title="贴到聊天框",run=share}})
M.resolve=function(key)
    local id=type(key)=="string" and tonumber(key:match("^achievement:(%d+)$"))
    return id and record(id) or nil
end
M.batchSize,M.batchDelay=128,0
function M:onReady()
    self.needsWork=false
    local resume=self.resumeQuery;self.resumeQuery=nil
    if resume then resume()
    elseif I.Search.Session then I.Search.Session:SourceChanged("achievements-ready") end
end
function M:onStart()
    self.lastError=nil;self.restoreCache=true;self.needsWork=true
    self.pendingIDs,self.pendingCount={},0
end
function M:MarkDirty()
    if combat() and self.cancelQuery then self.cancelQuery() end
    if not self.needsWork then return end
    return I.Builtin.CatalogProvider.MarkDirty(self)
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
                    for _,term in ipairs(terms) do if not title:find(term,1,true) then match=false;break end end
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
