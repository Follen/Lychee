local I = _G.LycheeInternal
local L = I.ProviderLocales:Module("builtin.ellesmere")
local N = I.Search.Normalizer
local A = I.ProviderModules.EllesmereAdapter
local M = {id="builtin.ellesmere"}
I.ProviderModules.Ellesmere = M
local icon = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga"
local function combat() return InCombatLockdown and InCombatLockdown() end
local function clock() return debugprofilestop and debugprofilestop() or 0 end
local function failure(message) return {ok=false,code="EUI_UNAVAILABLE",message=L[message]} end
local translated,exists,ready=A.Translate,A.Page,A.Ready
-- Reversible identities survive localization, ordering changes and reloads.
local function encode(value)
    return (value:gsub("[^%w_.]",function(c) return string.format("-%02X",c:byte()) end))
end
local function decode(value) return (value:gsub("%-(%x%x)",function(c) return string.char(tonumber(c,16)) end)) end
local function pageID(folder,page)
    local id="page/"..encode(folder).."/"..encode(page)
    if #id>128 then error("EUI_CATALOG_LIMIT") end
    return id
end
local function pageRecord(eui, folder, config, page, id)
    id=id or pageID(folder,page)
    local moduleName=type(config.title)=="string" and config.title or folder
    local display=A.Display(eui,page)
    return {id=id,title=translated(eui,display),kind="setting",kindTitle="Ellesmere UI",icon=icon,
        subtitle=translated(eui,moduleName).." · "..translated(eui,page),
        aliases={page,translated(eui,page),display,moduleName,translated(eui,moduleName)},
        payload={module=folder,page=page},actions={"open"}}
end
local function unlockRecord()
    return {id="unlock",title=L["解锁界面"],kind="command",kindTitle="Ellesmere UI",icon=icon,
        subtitle=L["进入 Ellesmere UI 解锁模式"],aliases={"解锁","unlock","unlock mode"},actions={"unlock"}}
end
local function statusRecord(message)
    return {id="status",title=L[message],kind="setting",kindTitle="Ellesmere UI",icon=icon,
        payload={message=message},actions={"status"}}
end
local function optionID(key)
    local a,b=0,0
    for index=1,#key do local byte=key:byte(index);a=(a*31+byte)%2147483647;b=(b*37+byte)%2147483647 end
    return "option/"..a.."/"..b
end
function M:Capture(eui,label,labelLoc,tooltip,folder,page,section,setter,selector,isSection)
    if not self.active or self.hooked~=eui or A.Get()~=eui or A.Suppressed(eui) then return end
    if type(label)~="string" or type(folder)~="string" or type(page)~="string" then return end
    label=label:match("^%s*(.-)%s*$")
    if label=="" or #label>256 or #folder>64 or #page>128 then return end
    local key=folder.."\1"..page.."\1"..label
    local id=optionID(key)
    local previous=self.options[id]
    if previous then if previous.key~=key then self.overflow=true end;return end
    if type(labelLoc)~="string" or #labelLoc>256 then labelLoc=nil end
    -- Dynamic tooltips must never execute merely because the user searches.
    if type(tooltip)~="string" or #tooltip>1024 then tooltip=nil end
    if type(section)~="string" or #section>256 then section=nil end
    if type(setter)~="function" or not (type(selector)=="string" and #selector<=128 or type(selector)=="number") then setter,selector=nil,nil end
    local bytes=#key+#label+#folder+#page+#(labelLoc or "")+#(tooltip or "")+#(section or "")
    if self.optionCount>=4096 or self.optionBytes+bytes>2097152 then self.overflow=true;return end
    self.options[id]={id=id,key=key,label=label,labelLoc=labelLoc,tooltip=tooltip,module=folder,page=page,
        section=section,setter=setter,selector=selector,isSection=isSection==true}
    self.optionCount,self.optionBytes=self.optionCount+1,self.optionBytes+bytes
end
function M:Attach()
    local eui=A.Get()
    if eui and self.hooked and self.hooked~=eui then
        self.options=self.active and {} or nil
        self.optionCount,self.optionBytes,self.overflow=0,0,nil
        self.hooked=nil
    end
    A.Observe(self)
end
local function optionRecord(eui,option,config)
    config=config or exists(eui,option.module,option.page)
    if not config then return end
    local moduleName=type(config.title)=="string" and config.title or option.module
    return {id=option.id,title=option.labelLoc or translated(eui,option.label),kind="setting",kindTitle="Ellesmere UI",icon=icon,
        subtitle=translated(eui,moduleName).." · "..translated(eui,option.page)..(option.section and " · "..translated(eui,option.section) or ""),
        aliases={option.label,translated(eui,moduleName),translated(eui,option.page)},description=option.tooltip,
        payload={module=option.module,page=option.page},actions={"open"}}
end
function M:Query(request,reply,context)
    -- Host routes prefixes. This extra guard prevents accidental global loading
    -- even when a user turns on ordinary search in Provider settings.
    if not self.active or not request.filter or request.filter.sourceID~=self.id..":records" then reply({});return end
    self:Attach()
    local query=request.normalized or ""
    local terms=N:Terms(query)
    local fields={}
    local limit=math.max(1,math.min(50,tonumber(request.limit) or 20))
    local selected={}
    local ranker=(request.preferredEntryID or request.ranking) and assert(_G.Lychee.SDK.CreateRanker(request))
    local length=0
    local function field(kind,value)
        if type(value)~="string" or value=="" then return end
        fields[length+1],fields[length+2],fields[length+3]=kind,value,N:Normalize(value)
        length=length+3
    end
    local function scoreText(title,a,b,c,d,e,description)
        if query=="" then return 0 end
        length=0
        field("title",title);field("alias",a);field("alias",b);field("alias",c);field("alias",d);field("alias",e)
        field("description",description)
        for index=#fields,length+1,-1 do fields[index]=nil end
        return N:ScoreCompiled(query,fields,terms,false)
    end
    local function position(id,score)
        if not score then return end
        local rank=ranker and ranker(id,score) or score
        local at=#selected+1
        for index,row in ipairs(selected) do
            if rank>row.rank or rank==row.rank and (score>row.score or score==row.score and id<row.record.id) then at=index;break end
        end
        if at<=limit then return at end
    end
    local function consider(at,record,score)
        local row=#selected==limit and table.remove(selected) or {}
        row.record,row.score,row.rank=record,score,ranker and ranker(record.id,score) or score
        table.insert(selected,at,row)
    end
    local function work()
        if combat() then return {statusRecord("请先脱离战斗")} end
        local eui=A.Get()
        if type(eui)~="table" then return {statusRecord("请先启用 Ellesmere UI")} end
        -- Unlock does not need to load the options addon at all.
        if query=="解锁" or query=="unlock" or query=="unlock mode" then return {unlockRecord()} end
        local why
        eui,why=ready()
        if not context.resources:IsActive() or not self.active then return {} end
        if not eui then return {statusRecord(why)} end
        self:Attach()
        local function checkOwner()
            if A.Get()~=eui then self:Attach();error("EUI_UPSTREAM_CHANGED") end
        end
        coroutine.yield() -- Give the upstream one-time load its own execution.
        checkOwner()
        local unlock=unlockRecord()
        local unlockScore=scoreText(unlock.title,"解锁","unlock","unlock mode")
        local unlockAt=position(unlock.id,unlockScore)
        if unlockAt then consider(unlockAt,unlock,unlockScore) end
        local count,modules,batch,started=0,0,0,clock()
        for folder,config in pairs(A.Modules(eui)) do
            modules=modules+1
            if modules>128 then error("EUI_CATALOG_LIMIT") end
            if type(folder)=="string" and #folder<=64 and type(config)=="table" and type(config.pages)=="table" then
                if #config.pages>1024 then error("EUI_CATALOG_LIMIT") end
                local moduleName=type(config.title)=="string" and config.title or folder
                local moduleLoc=translated(eui,moduleName)
                for _,page in ipairs(config.pages) do
                    count=count+1;batch=batch+1
                    if count>4096 then error("EUI_CATALOG_LIMIT") end
                    if type(page)=="string" and #page>0 and #page<=128 then
                        local display=A.Display(eui,page)
                        local score=scoreText(translated(eui,display),page,translated(eui,page),display,moduleName,moduleLoc)
                        if score then
                            local id=pageID(folder,page)
                            local at=position(id,score)
                            if at then consider(at,pageRecord(eui,folder,config,page,id),score) end
                        end
                    end
                    if batch>=32 or clock()-started>=1 then
                        coroutine.yield();checkOwner();batch,started=0,clock()
                    end
                end
            end
        end
        for _,option in pairs(self.options) do
            local config=exists(eui,option.module,option.page)
            if config then
                local score=scoreText(option.labelLoc or translated(eui,option.label),option.label,
                    translated(eui,config.title or option.module),translated(eui,option.page),nil,nil,option.tooltip)
                local at=position(option.id,score)
                if at then consider(at,optionRecord(eui,option,config),score) end
            end
            batch=batch+1
            if batch>=32 or clock()-started>=1 then coroutine.yield();checkOwner();batch,started=0,clock() end
        end
        checkOwner()
        local records={}
        if self.overflow then records[#records+1]=statusRecord("Ellesmere UI 设置目录超出限制") end
        for _,row in ipairs(selected) do records[#records+1]=row.record end
        return records
    end
    local resources=assert(context and context.resources,"Managed query resources required")
    local token,err=resources:Run("query",work,{
        complete=function(records) self.lastError=nil;reply(records) end,
        combat=function() reply({statusRecord("请先脱离战斗")}) end,
        error=function(value)
            self.lastError=tostring(value)
            reply({statusRecord(self.lastError:find("EUI_CATALOG_LIMIT",1,true) and "Ellesmere UI 设置目录超出限制" or "Ellesmere UI 设置暂不可用")})
        end,
    })
    if not token then reply({statusRecord("查询暂不可用")});return end
    return function(reason) token:Cancel(reason) end
end
function M:Resolve(id)
    if not self.active then return end
    if id=="unlock" then return unlockRecord() end
    self:Attach()
    local option=self.options and self.options[id]
    if option and A.Get() then return optionRecord(A.Get(),option) end
    if type(id)~="string" then return end
    local folder,page=id:match("^page/([^/]+)/([^/]+)$")
    if not folder then return end
    folder,page=decode(folder),decode(page)
    local eui=A.Get()
    local config=type(eui)=="table" and exists(eui,folder,page)
    if config then return pageRecord(eui,folder,config,page) end
end
local actions={
    open={title=L["打开设置"],run=function(entry)
        M:Attach()
        local eui,why=ready()
        if not eui then return failure(why) end
        if A.Get()~=eui then M:Attach();return failure("Ellesmere UI 设置暂不可用") end
        local p=entry.payload
        if not p or not exists(eui,p.module,p.page) then return failure("此设置页面已不可用") end
        -- EUI owns first-open deferral and page construction; no filter or value mutation.
        local option=M.options and M.options[entry.id]
        if entry.id:match("^option/") and not option then return failure("此设置页面已不可用") end
        if not A.Navigate(eui,p.module,p.page,option) then return failure("Ellesmere UI 设置暂不可用") end
        return {ok=true,close=true}
    end},
    unlock={title=L["解锁界面"],run=function()
        local ok,why=A.Unlock()
        if not ok then return failure(why) end
        return {ok=true,close=true}
    end},
    status={title=L["打开设置"],run=function(entry) return failure(entry.payload.message) end},
}
function M:Init()
    if self.handle and self.handle:GetState() then return end
    self.handle=_G.Lychee:RegisterProvider({id=self.id,apiVersion="1.0.0",version="1.0.0",title="Ellesmere UI",
        scope=I.ProviderModules.Support:Scope(self.id),i18n=L.resources,searchGlobal=false,searchPrefixes={"eui"},searchKeywords={},
        entries={},actions=actions,query=function(request,reply,context) return self:Query(request,reply,context) end,
        resolve=function(id) return self:Resolve(id) end,
        onEnable=function()
            self.active=true;self.options={};self.optionCount,self.optionBytes=0,0;self.overflow=nil
            self:Attach()
            return function()
                self.active=false;self.options=nil;self.optionCount,self.optionBytes=0,0;self.overflow=nil
            end
        end})
end
