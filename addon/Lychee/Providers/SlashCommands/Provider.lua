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
local owners,ownerCount={},0
local weakOwner={__mode="v"}
local watched=setmetatable({},{__mode="k"})
local consoles=setmetatable({},{__mode="k"})
local function origin(object,key)
    if type(object)~="table" or not plain(key,512) or type(issecurevariable)~="function" then return end
    local ok,isSecure,addon=pcall(issecurevariable,object,key)
    if ok and isSecure==false and plain(addon,256) and addon~="" then return addon end
end
local function forget(_,alias)
    if M.active==false or not plain(alias,255) then return end
    local slash=command("/"..alias)
    if slash and owners[slash] then owners[slash]=nil;ownerCount=ownerCount-1 end
end
local function capture(receiver,alias,method)
    if M.active==false or type(receiver)~="table" or not plain(alias,255) then return end
    local slash=command("/"..alias)
    if not slash then return end
    local key="ACECONSOLE_"..alias:upper()
    local handler=type(SlashCmdList)=="table" and SlashCmdList[key]
    if type(handler)~="function" then return end
    -- The library's closure belongs to its first loader, not to the caller.
    -- Prefer the caller's method field; a validated AceAddon name is a fallback.
    local owner=type(method)=="string" and origin(receiver,method)
    if not owner or not metadata(owner,"Title") then
        owner=rawget(receiver,"name")
        if not plain(owner,256) or not metadata(owner,"Title") then owner=nil end
    end
    if not owner then forget(nil,alias);return end
    if not owners[slash] then
        if ownerCount>=4096 then M.ownershipLimited=true;return end
        ownerCount=ownerCount+1
    end
    owners[slash]=setmetatable({handler=handler,owner=owner},weakOwner)
end
local function watch(receiver,library)
    if type(receiver)~="table" or type(receiver.RegisterChatCommand)~="function" then return end
    if receiver~=library and receiver.RegisterChatCommand==library.RegisterChatCommand then return end
    if watched[receiver]==receiver.RegisterChatCommand then return end
    hooksecurefunc(receiver,"RegisterChatCommand",capture)
    if type(receiver.UnregisterChatCommand)=="function" then hooksecurefunc(receiver,"UnregisterChatCommand",forget) end
    watched[receiver]=receiver.RegisterChatCommand
end
function M:ObserveConsole()
    if self.active==false or type(hooksecurefunc)~="function" or type(LibStub)~="table" or type(LibStub.GetLibrary)~="function" then return end
    local ok,library=pcall(LibStub.GetLibrary,LibStub,"AceConsole-3.0",true)
    if not ok or type(library)~="table" then return end
    watch(library,library)
    if not consoles[library] and type(library.Embed)=="function" then
        hooksecurefunc(library,"Embed",function(_,receiver)
            if M.active~=false then watch(receiver,library) end
        end)
        consoles[library]=true
    end
    -- Existing embeds keep their original function reference when the library
    -- field is hooked. Hook those references too; never replace their methods.
    local count=0
    for receiver in pairs(type(library.embeds)=="table" and library.embeds or {}) do
        count=count+1;if count>512 then self.ownershipLimited=true;break end
        watch(receiver,library)
    end
end
local function ownerFor(slash,key,handler)
    local captured=owners[slash]
    if captured and captured.handler==handler then return captured.owner end
    -- An uncaptured AceConsole closure's taint identifies the library loader.
    -- Do not display that unrelated addon's logo as the command owner.
    if key and key:match("^ACECONSOLE_") then return end
    return key and origin(SlashCmdList,key) or origin(hash_SlashCmdList,slash:upper())
end
local function presentation(slash,key,handler)
    local owner=ownerFor(slash,key,handler)
    local title=owner and metadata(owner,"Title")
    if title then
        title=title:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t",""):gsub("|A.-|a","")
        local icon=metadata(owner,"IconTexture")
        return title,icon and (tonumber(icon) or icon) or ICON,owner
    end
    return slash,ICON
end
local function entry(slash,key,handler)
    local title,icon,owner=presentation(slash,key,handler)
    return {id="slash:"..slash,title=title,icon=icon,kind="command",kindTitle=L["斜杠命令"],
        subtitle=owner and slash or L["点击运行命令"],
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
    if fn then return entry(slash,key,fn) end
end
function M:Query(request,reply,context)
    if not self.active then reply({});return end
    self:ObserveConsole()
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
            local title,_,owner=presentation(slash,key,fn)
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
                table.insert(selected,at,{slash=slash,key=key,handler=fn,score=score,weighted=weighted})
                if #selected>limit then selected[#selected]=nil end
            end
        end,checkpoint)
        local rows={}
        for _,row in ipairs(selected) do rows[#rows+1]=entry(row.slash,row.key,row.handler) end
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
        onEnable=function()
            self.active=true;self:ObserveConsole()
            return function(reason)
                self.active=false
                if reason=="unregister" then owners={};ownerCount=0;self.ownershipLimited=nil end
            end
        end})
end

-- Observe before later addons initialize; no frame, event or idle timer.
M:ObserveConsole()
