local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.keystones")
local C = I.Builtin.CatalogProvider
local M
-- Factual retail 12.1 season spell/LFG IDs; see versioned validation evidence.
-- Match localized dungeon names at runtime; never infer a spell from key text.
local portals={{3102,1286801},{3106,1286804},{3051,1286807},{3090,1286809},
    {3191,1286812},{2361,393256},{1694,1286828},{1785,1286831}}
local function time() return GetTime and GetTime() or 0 end
local function number(value,maximum)
    return type(value)=="number" and value==value and value>=0 and value<=maximum
end
local function colored(text,color)
    if not color then return text end
    return string.format("|cff%02x%02x%02x%s|r",math.floor(color.r*255+0.5),math.floor(color.g*255+0.5),math.floor(color.b*255+0.5),text)
end
local function fullName(unit)
    local name,realm=UnitFullName(unit)
    if not name then return nil end
    realm=realm and realm~="" and realm or GetNormalizedRealmName()
    return name.."-"..realm:gsub("%s","")
end
local function roster(self)
    local current={}
    for index=0,4 do
        local unit=index==0 and "player" or "party"..index
        if UnitExists(unit) then
            local name,guid=fullName(unit),UnitGUID(unit)
            if name and guid then
                local old=self.members and self.members[name]
                current[name]=old and old.guid==guid and old or {guid=guid}
                current[name].unit=unit
            end
        end
    end
    self.members=current
end
local function member(self,sender)
    if type(sender)~="string" or #sender>128 then return nil end
    local exact=self.members[sender]
    if exact then return exact end
    if sender:find("-",1,true) then return nil end
    local found
    for name,entry in pairs(self.members) do
        if name:match("^([^%-]+)")==sender then
            if found then return nil end
            found=entry
        end
    end
    return found
end
local function own()
    local map=C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level=C_MythicPlus.GetOwnedKeystoneLevel()
    local rating=C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    return map or 0,level or 0,rating and rating.currentSeasonScore or 0
end
local function send(self,request,forceReply)
    if not self.active or not IsInGroup() or IsInRaid() or InCombatLockdown() then return end
    local field=request and "lastRequest" or "lastReply"
    local stamp=time()
    if self[field] and stamp-self[field]<3 then return end
    local message="R"
    local ownMap,ownLevel,ownRating
    if not request then
        -- An already loaded library supplies the same reply; avoid duplicates.
        if LibStub and LibStub("LibKeystone",true) then return end
        local map,level,rating=own()
        if not number(map,100000) or not number(level,1000) or not number(rating,100000) then return end
        if not forceReply and self.sentMap==map and self.sentLevel==level and self.sentRating==rating then return end
        ownMap,ownLevel,ownRating=map,level,rating
        message=string.format("%d,%d,%d",level,map,math.floor(rating))
    end
    self[field]=stamp
    local result=C_ChatInfo.SendAddonMessage("LibKS",message,"PARTY")
    if type(result)=="number" and result~=0 then self.commError="KEY_SEND_"..result
    elseif not request then self.sentMap,self.sentLevel,self.sentRating=ownMap,ownLevel,ownRating end
end
local function teleport(mapID)
    local dungeon=C_ChallengeMode.GetMapUIInfo(mapID)
    if not dungeon or not GetLFGDungeonInfo or not C_SpellBook then return nil end
    for _,pair in ipairs(portals) do
        if GetLFGDungeonInfo(pair[1])==dungeon and C_SpellBook.IsSpellKnown(pair[2]) then return pair[2] end
    end
end
local function build(self,put,checkpoint)
    roster(self)
    local maps=C_ChallengeMode.GetMapTable()
    if #maps>16 then error("SEASON_MAP_LIMIT") end
    local mine,mineLevel=own()
    for name,entry in pairs(self.members) do
        local isMe=entry.unit=="player"
        local map,level=entry.map,entry.level
        if isMe then map,level=mine,mineLevel
        elseif not entry.received or time()-entry.received>90 then map,level=nil,nil end
        local summary=C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(entry.unit)
        local fresh=entry.received and time()-entry.received<=90
        local total=summary and summary.currentSeasonScore or (fresh and entry.rating)
        if not number(total,100000) then total=nil end
        local lines,scoreRows={L["当季副本成绩"]},{}
        local runs=summary and summary.runs
        if runs and #runs>32 then error("RATING_RUN_LIMIT") end
        for _,id in ipairs(maps) do
            local dungeon=C_ChallengeMode.GetMapUIInfo(id) or L:Format("副本 %d",id)
            local score,best
            if runs then
                for _,run in ipairs(runs) do if run.challengeModeID==id and number(run.mapScore,10000) then score,best=run.mapScore,run;break end end
            end
            local result=runs and L["未完成"] or L["未获取"]
            if best and number(best.bestRunLevel,1000) and best.bestRunLevel>0 then
                result=L:Format(best.finishedSuccess and "限时 +%d" or "超时 +%d",best.bestRunLevel)
            end
            if isMe and C_MythicPlus.GetSeasonBestForMap then
                local timed,overtime=C_MythicPlus.GetSeasonBestForMap(id)
                local seasonBest=timed or overtime
                if seasonBest and number(seasonBest.level,1000) then
                    result=L:Format(timed and "限时 +%d" or "超时 +%d",seasonBest.level)
                end
            end
            local scoreText=score and string.format("%.1f",score) or "—"
            scoreText=colored(scoreText,score and C_ChallengeMode.GetSpecificDungeonScoreRarityColor and C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score))
            scoreRows[#scoreRows+1]={dungeon,result,scoreText}
            lines[#lines+1]=dungeon.."  "..scoreText.." · "..result
        end
        if #maps==0 then lines[#lines+1]=L["赛季副本列表尚未获取"] end
        local dungeon,_,_,dungeonIcon
        if map and map>0 then dungeon,_,_,dungeonIcon=C_ChallengeMode.GetMapUIInfo(map) end
        local _,class=UnitClass(entry.unit)
        local classColor=class and C_ClassColor and C_ClassColor.GetClassColor(class)
        local title=colored(name,classColor).." · "..(dungeon and (dungeon.." +"..level) or (map==0 and L["暂无钥匙"] or L["钥匙未知"]))
        local spell=dungeon and teleport(map)
        local subtitle=spell and L["点击传送至该副本"] or (dungeon and L["尚未解锁对应传送"] or L["等待队友的兼容插件回复"])
        local description=table.concat(lines,"\n")
        local badge=total and (L:Format("分数 %s",colored(string.format("%.0f",total),C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(total)))) or L["分数未知"]
        local id="key:"..entry.guid
        put({id=id,title=title,kind="keystone",kindTitle=badge,subtitle=subtitle,description=description,
            icon=dungeonIcon or "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\keystone.tga",aliases={"钥匙","key","keys","大秘境","分数"},
            payload={guid=entry.guid,mapID=map,level=level,scoreRows=scoreRows},
            actions=spell and {{id="teleport",title=L["传送"],kind="secure-spell",spellID=spell}} or {}},
            title.."\0"..badge.."\0"..description.."\0"..tostring(spell).."\0"..tostring(dungeonIcon))
        checkpoint()
    end
end
M=C:New("builtin.keystones",L["队伍钥匙"],{"GROUP_ROSTER_UPDATE","BAG_UPDATE_DELAYED","CHALLENGE_MODE_MAPS_UPDATE",
    "MYTHIC_PLUS_NEW_WEEKLY_RECORD","INSPECT_READY","SPELLS_CHANGED","CHAT_MSG_ADDON"},build)
M.members={}
function M:onStart()
    roster(self)
    local result=C_ChatInfo.RegisterAddonMessagePrefix("LibKS")
    if type(result)=="number" and result>1 then self.commError="KEY_PREFIX_UNAVAILABLE" end
    C_MythicPlus.RequestMapInfo()
    send(self,true)
end
function M:onStop()
    self.members={}; self.lastRequest=nil; self.lastReply=nil; self.lastQuery=nil
    self.sentMap,self.sentLevel,self.sentRating=nil,nil,nil
end
function M:onEvent(event,prefix,message,channel,sender)
    if InCombatLockdown() and event~="CHAT_MSG_ADDON" then self:MarkDirty();return end
    if event=="CHAT_MSG_ADDON" then
        if prefix~="LibKS" or type(message)~="string" or #message>40 then return end
        local peer=member(self,sender)
        if not peer or peer.unit=="player" then return end
        if channel~="PARTY" and channel~="GUILD" then return end
        if message=="R" then if channel=="PARTY" then send(self,false,true) end; return end
        local level,map,rating=message:match("^(%d+),(%d+),(%d+)$")
        level,map,rating=tonumber(level),tonumber(map),tonumber(rating)
        if not number(level,1000) or not number(map,100000) or not number(rating,100000) then return end
        if (map==0)~=(level==0) then return end
        if peer.received and time()-peer.received<1 then return end
        peer.level,peer.map,peer.rating,peer.received=level,map,rating,time()
    elseif event=="GROUP_ROSTER_UPDATE" then roster(self); send(self,true)
    elseif event=="INSPECT_READY" then
        local found=false
        for _,peer in pairs(self.members) do if peer.guid==prefix then found=true;break end end
        if not found then return end
    elseif event=="BAG_UPDATE_DELAYED" then send(self,false) end
    self:MarkDirty()
end
M.query=function(request,reply)
    local q=request.normalized
    if request.filter and request.filter.sourceID=="builtin.keystones:records" or q=="key" or q=="keys" or q=="钥匙" then
        if not M.lastQuery or time()-M.lastQuery>=10 then
            M.lastQuery=time(); send(M,true); M:MarkDirty()
        end
    end
    reply({})
end
I.Builtin.Keystones=M
