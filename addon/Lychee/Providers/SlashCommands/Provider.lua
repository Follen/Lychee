local I = _G.LycheeInternal
local L = I.ProviderLocales:Module("builtin.slash-commands")
local N = I.Search.Normalizer
local M = {id="builtin.slash-commands"}
I.ProviderModules.SlashCommands = M
local ICON = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\slash-commands.tga"
local function now() return debugprofilestop and debugprofilestop() or 0 end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function plain(value, maximum)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="string" and #value<=maximum
end
local function command(value)
    if plain(value,256) and value:match("^/[^%s|]+$") then return value:lower() end
end
local function proxy(list)
    local mt=type(list)=="table" and getmetatable(list)
    return type(mt)=="table" and type(mt.__index)=="table" and mt.__index or nil
end
local function secure(value)
    return type(IsSecureCmd)=="function" and IsSecureCmd(value)
end
-- Pending registrations override the imported hash, just as ImportListToHash
-- does before dispatch. Read only: importing here would taint Blizzard state.
local function scan(put,checkpoint)
    local list=_G.SlashCmdList
    local hash=_G.hash_SlashCmdList
    local imported=proxy(list)
    local seen,count={},0
    local function step()
        count=count+1
        if count>8192 then error("SLASH_COMMAND_LIMIT") end
        checkpoint()
    end
    local function add(value,fn,key,index)
        local slash=command(value)
        if slash and type(fn)=="function" and not seen[slash] then
            seen[slash]=true
            if not secure(slash) then put(slash,fn,key,index) end
        end
        step()
    end
    local function registrations(source, pending)
        if type(source)~="table" then return end
        for key,fn in pairs(source) do
            step()
            if plain(key,256) and type(fn)=="function" then
                for index=1,65 do
                    local alias=_G["SLASH_"..key..index]
                    if alias==nil then break end
                    if index>64 then error("SLASH_COMMAND_LIMIT") end
                    -- A removed imported hash is an explicit unregistration.
                    if pending or type(hash)~="table" then add(alias,fn,key,index) end
                end
            end
        end
    end
    registrations(list,true)
    if type(hash)=="table" then
        for alias,fn in pairs(hash) do
            local upper=plain(alias,256) and alias:upper()
            local key=upper and type(_G.hash_ChatTypeInfoList)=="table" and _G.hash_ChatTypeInfoList[upper]
            add(alias,fn,plain(key,256) and key or nil)
        end
    else
        registrations(imported,false)
    end
end
local function metadata(folder,key)
    local fn=C_AddOns and C_AddOns.GetAddOnMetadata
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,folder,key)
    if ok and plain(value,512) and value~="" then return value end
end
local function presentation(slash,key)
    -- Explicit integration, not a guessed prefix-to-addon ownership map.
    -- RurutiaSuite Core/Init.lua registers rs through AceConsole and exports RS.
    if slash=="/rs" and key=="ACECONSOLE_RS" and type(_G.RurutiaSuite)=="table"
        and type(_G.RurutiaSuite.OnChatCommand)=="function" then
        local icon=metadata("RurutiaSuite","IconTexture")
        local title=metadata("RurutiaSuite","Title")
        if title then
            title=title:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t",""):gsub("|A.-|a","")
            return L["露露提亚工具箱"],icon and (tonumber(icon) or icon) or ICON,title
        end
    end
    return slash,ICON
end
local function entry(slash,key)
    local title,icon,owner=presentation(slash,key)
    return {id="slash:"..slash,title=title,icon=icon,kind="command",kindTitle=L["斜杠命令"],
        subtitle=owner and slash.." · "..owner or L["点击运行命令"],
        aliases={slash,slash:sub(2),owner or slash},payload={command=slash},actions={"run"}}
end
local function status(message)
    return {id="status",title=L[message],icon=ICON,kind="command",kindTitle=L["斜杠命令"],rememberable=false,actions={}}
end
function M:Find(slash)
    if not self.active or not command(slash) or secure(slash) then return end
    local handler,key
    local ok=pcall(scan,function(alias,fn,registration)
        if alias==slash then handler,key=fn,registration end
    end,function() end)
    if ok then return handler,key end
end
function M:Resolve(id)
    if type(id)~="string" or id:sub(1,6)~="slash:" then return end
    local slash=id:sub(7)
    local fn,key=self:Find(slash)
    if fn then return entry(slash,key) end
end
function M:Query(request,reply,context)
    if not self.active then reply({});return end
    local query=request.normalized or ""
    local terms=N:Terms(query)
    local limit=math.max(1,math.min(20,tonumber(request.limit) or 20))
    local ranker=(request.preferredEntryID or request.ranking) and _G.Lychee.SDK.CreateRanker(request)
    local function work()
        local selected,fields={},{}
        local batch,started=0,now()
        local function checkpoint()
            batch=batch+1
            if batch>=128 or now()-started>=1 then coroutine.yield();batch=0;started=now() end
        end
        scan(function(slash,fn,key)
            local title,_,owner=presentation(slash,key)
            fields[1],fields[2],fields[3]="title",title,N:Normalize(title,false)
            fields[4],fields[5],fields[6]="alias",slash,N:Normalize(slash,false)
            fields[7],fields[8],fields[9]="alias",slash:sub(2),N:Normalize(slash:sub(2),false)
            fields[10],fields[11],fields[12]="alias",owner or "",N:Normalize(owner or "",false)
            local score=query=="" and 0 or N:ScoreCompiled(query,fields,terms,false)
            if not score then return end
            local id="slash:"..slash
            local weighted=ranker and ranker(id,score) or score
            local at=#selected+1
            for index,row in ipairs(selected) do
                if weighted>row.weighted or weighted==row.weighted and (score>row.score or score==row.score and slash<row.slash) then at=index;break end
            end
            if at<=limit then
                table.insert(selected,at,{slash=slash,key=key,score=score,weighted=weighted})
                if #selected>limit then selected[#selected]=nil end
            end
        end,checkpoint)
        local rows={}
        for _,row in ipairs(selected) do rows[#rows+1]=entry(row.slash,row.key) end
        return rows
    end
    local token=context.resources:Run("slash-query",work,{
        complete=function(rows) self.lastError=nil;reply(rows) end,
        combat=function() reply({}) end,
        error=function(value)
            self.lastError=tostring(value)
            reply({status(self.lastError:find("SLASH_COMMAND_LIMIT",1,true) and "命令数量超出限制" or "命令暂不可用，请重试")})
        end,
    })
    if not token then reply({status("命令暂不可用，请重试")});return end
    return function(reason) token:Cancel(reason) end
end
local function run(record)
    if combat() then return {ok=false,message=L["请先脱离战斗"]} end
    local slash=record.payload and record.payload.command
    if not slash or record.id~="slash:"..slash then return {ok=false,message=L["命令已注销，请重新搜索"]} end
    local handler=M:Find(slash)
    if not handler then return {ok=false,message=L["命令已注销，请重新搜索"]} end
    local editBox=DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    local ok=pcall(handler,"",editBox)
    if not ok then return {ok=false,message=L["命令执行失败，请检查插件错误后重试"]} end
    return {ok=true,close=true}
end
function M:Init()
    if self.handle and self.handle:GetState() then return end
    self.handle=_G.Lychee:RegisterProvider({id=self.id,title=L["斜杠命令"],description=L["搜索并运行已注册的斜杠命令"],icon=ICON,
        version="1.0.0",apiVersion="1.0.0",scope=I.ProviderModules.Support:Scope(self.id),
        searchGlobal=true,searchPrefixes={"cmd","命令"},entries={},actions={run={title=L["运行命令"],run=run}},
        query=function(request,reply,context) return self:Query(request,reply,context) end,
        resolve=function(id) return self:Resolve(id) end,
        onEnable=function() self.active=true;return function() self.active=false end end})
end
