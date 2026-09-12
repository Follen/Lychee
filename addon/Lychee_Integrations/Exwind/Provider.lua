local _,I=...
local L=I.ProviderLocales:ForProvider("lychee.exwind")
local N=I.Search.Normalizer
local M={id="lychee.exwind"}
I.Modules.Exwind=M
local icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga"
local function combat() return InCombatLockdown and InCombatLockdown() end
local function now() return debugprofilestop and debugprofilestop() or 0 end
local function text(value)
    if type(value)~="string" then return "" end
    return (value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t",""):gsub("|A.-|a",""):match("^%s*(.-)%s*$"))
end
local function name(core,value)
    if type(value)~="string" then return "" end
    return text(type(core.L)=="table" and core.L[value] or value)
end
local function encode(value) return (value:gsub("[^%w_.]",function(c) return string.format("-%02X",c:byte()) end)) end
local function failure(message) return {ok=false,code="EXWIND_UNAVAILABLE",message=L[message]} end
local function available()
    local core=_G.ExwindTools
    if type(core)~="table" then return nil,"请先启用 Exwind Core" end
    if type(core.UnifiedPanel)~="table" or type(core.UnifiedPanel.Providers)~="table" then return nil,"Exwind 设置暂不可用" end
    return core
end
local function entry(target,matchedLabel)
    local subtitle=target.owner.." · "..L["打开所在设置页"]
    if matchedLabel then subtitle=matchedLabel.." · "..subtitle end
    return {id=target.id,title=target.title,kind="setting",kindTitle="Exwind",icon=icon,subtitle=subtitle,
        aliases={target.key or target.title,target.owner,matchedLabel or target.title},description=target.description,
        actions={"open"}}
end
local function unlock()
    return {id="unlock",title=L["解锁界面"],kind="command",kindTitle="Exwind",icon=icon,
        subtitle=L["进入 Exwind 编辑模式"],aliases={"解锁","编辑模式","unlock","edit"},actions={"unlock"}}
end
local function status(message)
    return {id="status",title=L[message],kind="setting",kindTitle="Exwind",icon=icon,payload={message=message},actions={"status"}}
end
-- Read declarations only. No layout builders, getConfig, visibility callbacks,
-- saved-variable scans, frame walking, hooks or replacement addon functions.
local function destinations(core,put,checkpoint)
    local shell=core.UnifiedPanel
    local count,seen=0,{}
    local function add(target)
        count=count+1
        if count>1024 or #target.id>128 or #target.title>512 then error("EXWIND_CATALOG_LIMIT") end
        if not seen[target.id] and target.title~="" then seen[target.id]=true;put(target) end
        checkpoint()
    end
    for id,provider in pairs(shell.Providers) do
        if type(id)=="string" and type(provider)=="table" and type(provider.ApplyRoute)=="function" then
            local meta=shell.ProviderMeta and shell.ProviderMeta[id]
            local title=name(core,meta and meta.title or provider.title or id)
            add({id="app/"..encode(id),title=title,owner="Exwind",kind="app",key=id})
        end
    end
    if shell.Providers.tools and type(core.ModuleList)=="table" then
        if #core.ModuleList>512 then error("EXWIND_CATALOG_LIMIT") end
        for _,meta in ipairs(core.ModuleList) do
            if type(meta)=="table" and type(meta.Key)=="string" and type(meta.Name)=="string" and not meta.HideCfg then
                add({id="tool/"..encode(meta.Key),title=name(core,meta.Name),description=text(meta.Desc),owner="ExwindTools",kind="tool",key=meta.Key})
            end
        end
    end
    local state=core.UI and core.UI.EditModeState
    local total=0
    for _,module in pairs(state and state.modules or {}) do
        total=total+1;if total>1024 then error("EXWIND_CATALOG_LIMIT") end
        -- Tools already has its authoritative HideCfg-aware ModuleList.
        if type(module)=="table" and module.addon~="ExwindTools" and type(module.addon)=="string"
            and type(module.settingsPage)=="string" and type(module.name)=="string"
            and type(state.routers and state.routers[module.addon])=="function" then
            add({id="edit/"..encode(module.addon).."/"..encode(module.settingsPage),title=name(core,module.name),
                owner=module.addon,kind="edit",key=module.key,page=module.settingsPage})
        end
        checkpoint()
    end
    -- Disabled ExBoss tools remain configurable through their declared PanelTab.
    local boss=_G.ExBoss
    if shell.Providers.boss and type(boss)=="table" and type(boss.ModuleList)=="table" then
        if #boss.ModuleList>512 then error("EXWIND_CATALOG_LIMIT") end
        for _,meta in ipairs(boss.ModuleList) do
            if type(meta)=="table" and type(meta.PanelTab)=="string" and type(meta.Name)=="string" and not meta.HideCfg then
                local title=type(boss.L)=="table" and boss.L[meta.Name] or meta.Name
                add({id="edit/EXBoss/"..encode(meta.PanelTab),title=text(title),owner="EXBoss",kind="boss",key=meta.Key,page=meta.PanelTab})
            end
        end
    end
end
local function layoutFor(core,key)
    if not key then return end
    local controller=core.ModuleDefinitions and core.ModuleDefinitions[key]
    local definition=type(controller)=="table" and controller.definition
    local layout
    if type(definition)=="table" and type(definition.settings)=="table" then layout=definition.settings.layout end
    if layout==nil then layout=core.RegisteredLayouts and core.RegisteredLayouts[key] end
    if type(layout)=="table" then return layout end
end
function M:Query(request,reply,context)
    if not self.active or not request.filter or request.filter.sourceID~=self.id..":records" then reply({});return end
    local query=request.normalized or ""
    local terms=N:Terms(query)
    local limit=math.max(1,math.min(50,tonumber(request.limit) or 20))
    local selected,fields={},{}
    local function score(title,alias,owner,description)
        if query=="" then return 0 end
        fields[1],fields[2],fields[3]="title",title,N:Normalize(title)
        fields[4],fields[5],fields[6]="alias",alias,N:Normalize(alias)
        fields[7],fields[8],fields[9]="alias",owner,N:Normalize(owner)
        fields[10],fields[11],fields[12]="description",description or "",N:Normalize(description or "")
        return N:ScoreCompiled(query,fields,terms,false)
    end
    local function add(target,rank,label)
        if not rank then return end
        local at=#selected+1
        for index,row in ipairs(selected) do if rank>row.score or rank==row.score and target.id<row.target.id then at=index;break end end
        if at<=limit then
            table.insert(selected,at,{target=target,score=rank,label=label})
            if #selected>limit then selected[#selected]=nil end
        end
    end
    local function work()
        local core,why=available()
        if not core then return {status(why)} end
        local batch,visited,started=0,0,now()
        local function checkpoint()
            batch=batch+1;visited=visited+1
            if visited>32768 then error("EXWIND_CATALOG_LIMIT") end
            if batch>=32 or now()-started>=1 then coroutine.yield();batch,started=0,now() end
        end
        local unlockEntry=unlock()
        local unlockScore=score(unlockEntry.title,"解锁 编辑模式 unlock edit","Exwind")
        if unlockScore then add({id="unlock",title=unlockEntry.title},unlockScore) end
        destinations(core,function(target)
            local best=score(target.title,target.key or target.title,target.owner,target.description)
            local matchedLabel
            local visitedTables={}
            local function walk(layout,depth)
                if type(layout)~="table" or visitedTables[layout] then return end
                if depth>8 or #layout>2048 then error("EXWIND_CATALOG_LIMIT") end
                visitedTables[layout]=true
                for _,node in ipairs(layout) do
                    checkpoint()
                    if type(node)=="table" and not node.hidden and node.visible~=false and type(node.visible)~="function" then
                        local label=text(node.label)
                        if #label>512 then error("EXWIND_CATALOG_LIMIT") end
                        if label~="" and node.type~="description" and node.type~="button" then
                            local rank=score(label,target.title,target.owner)
                            if rank and (not best or rank>best) then best,matchedLabel=rank,label end
                        end
                        walk(node.children,depth+1)
                        walk(type(node.opts)=="table" and node.opts.fields,depth+1)
                    end
                end
            end
            if query~="" then walk(layoutFor(core,target.key),1) end
            add(target,best,matchedLabel)
        end,checkpoint)
        local records={}
        for _,row in ipairs(selected) do records[#records+1]=row.target.id=="unlock" and unlock() or entry(row.target,row.label) end
        return records
    end
    local resources=assert(context and context.resources,"Managed query resources required")
    local token,err=resources:Run("query",work,{
        complete=function(records) self.lastError=nil;reply(records) end,
        combat=function() reply({status("请先脱离战斗")}) end,
        error=function(value)
            self.lastError=tostring(value)
            reply({status(self.lastError:find("EXWIND_CATALOG_LIMIT",1,true) and "Exwind 设置目录超出限制" or "Exwind 设置暂不可用")})
        end,
    })
    if not token then reply({status("查询暂不可用")});return end
    return function(reason) token:Cancel(reason) end
end
function M:Find(id)
    local core=available()
    if not core then return end
    local found
    destinations(core,function(target) if target.id==id then found=target end end,function() end)
    return found,core
end
function M:Resolve(id)
    if not self.active then return end
    if id=="unlock" then return unlock() end
    local target=self:Find(id)
    if target then return entry(target) end
end
local actions={
    open={title=L["打开所在设置页"],run=function(record)
        if combat() then return failure("请先脱离战斗") end
        local target,core=M:Find(record.id)
        if not target then return failure("此设置页面已不可用") end
        local shell=core.UnifiedPanel
        if target.kind=="edit" then
            if type(core.UI.OpenModuleSettings)~="function" then return failure("Exwind 设置暂不可用") end
            core.UI:OpenModuleSettings(target.owner,target.page)
        elseif type(shell.Show)=="function" then
            if target.kind=="tool" then shell:Show("tools",{moduleKey=target.key})
            elseif target.kind=="boss" then shell:Show("boss",{tab=target.page})
            else shell:Show(target.key) end
        else return failure("Exwind 设置暂不可用") end
        if not shell.Frame or not shell.Frame:IsShown() then return failure("Exwind 设置暂不可用") end
        return {ok=true,close=true}
    end},
    unlock={title=L["解锁界面"],run=function()
        if combat() then return failure("请先脱离战斗") end
        local core,why=available()
        if not core then return failure(why) end
        local ui=core.UI
        if not ui or type(ui.IsEditModeActive)~="function" or type(ui.ToggleEditMode)~="function" then return failure("Exwind 设置暂不可用") end
        if not ui:IsEditModeActive() then ui:ToggleEditMode(true) end
        if not ui:IsEditModeActive() then return failure("Exwind 设置暂不可用") end
        if type(core.UnifiedPanel.Hide)=="function" then core.UnifiedPanel:Hide() end
        return {ok=true,close=true}
    end},
    status={title=L["打开面板"],run=function(record) return failure(record.payload.message) end},
}
function M:Init()
    if self.handle and self.handle:GetState() then return end
    self.handle=I.Modules.Support:Register({id=self.id,title="Exwind",version="1.0.0",apiVersion=3,minApiRevision=1,
        scope=I.Modules.Support:Scope(self.id),i18n=L.resources,searchGlobal=false,searchPrefixes={"ex"},searchKeywords={},catalog={},actions=actions,
        query=function(request,reply,context) return self:Query(request,reply,context) end,resolve=function(id) return self:Resolve(id) end,
        onEnable=function() self.active=true;return function() self.active=false end end})
end
