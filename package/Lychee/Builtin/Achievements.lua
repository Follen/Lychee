local I=_G.LycheeInternal
local N=I.Search.Normalizer
local M
local LIMIT=32768
local function combat() return InCombatLockdown and InCombatLockdown() end
local function build(self,_,checkpoint)
    if not GetCategoryList or not GetAchievementInfo then error("ACHIEVEMENT_API_UNAVAILABLE") end
    local ids,texts,seen={},{},{}
    local function add(id)
        if not id or seen[id] then return false end
        seen[id]=true
        local found,name=GetAchievementInfo(id)
        if found and name then
            if #ids>=LIMIT then error("ACHIEVEMENT_CATALOG_LIMIT") end
            ids[#ids+1]=id;texts[#texts+1]=N:Normalize(name)
        end
        checkpoint()
        return true
    end
    local categories=GetCategoryList()
    for _,category in ipairs(categories) do
        local total=GetCategoryNumAchievements(category,true) or 0
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
    self.ids,self.texts=ids,texts
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
M=I.Builtin.CatalogProvider:New("builtin.achievements","成就",{},build,
    {open={title="查看成就",run=open},share={title="贴到聊天框",run=share}})
M.resolve=function(key)
    local id=type(key)=="string" and tonumber(key:match("^achievement:(%d+)$"))
    return id and record(id) or nil
end
function M:onStart() self.lastError=nil end
function M:onStop()
    if self.cancelQuery then self.cancelQuery();self.cancelQuery=nil end
    self.ids,self.texts=nil,nil
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
        if M.cancelQuery==cancel then M.cancelQuery=nil end
    end
    M.cancelQuery=cancel
    local function step()
        timer=nil
        if cancelled or not M.active or combat() then cancel();return end
        if not M.ids then
            if M.lastError then local send=reply;cancel();send({});return end
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
                    if index<=#result then timer=C_Timer.NewTimer(0.01,finish)
                    else local send,output=reply,records;cancel();send(output) end
                end
                finish();return
            end
        end
        timer=C_Timer.NewTimer(0.01,step)
    end
    step()
    return cancel
end
I.Builtin.Achievements=M
