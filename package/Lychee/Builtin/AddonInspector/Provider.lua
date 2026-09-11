local I=_G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.addon-inspector")
I.Builtin=I.Builtin or {}
local M={id="builtin.addon-inspector",epoch=0}
I.Builtin.AddonInspector=M
local function secret(value) return issecretvalue and issecretvalue(value) end
local function clean(value) if not secret(value) then return value end end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok then return clean(value) end
end
local function index(object,key) return object[key] end
local function method(object,key)
    if secret(object) or object==nil then return end
    local ok,fn=pcall(index,object,key)
    if ok and not secret(fn) and type(fn)=="function" then return fn end
end
function M:Read(object,key)
    return call(method(object,key),object)
end
local function text(value,fallback)
    if type(value)~="string" then return fallback or "—" end
    return value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|","||"):sub(1,512)
end
local function addonTitle(folder)
    return call(C_AddOns and C_AddOns.GetAddOnMetadata,folder,"Title")
end
function M:Source(location)
    if type(location)~="string" then return end
    local path=location:gsub("\\","/")
    local folder=path:match("[Ii]nterface/[Aa]dd[Oo]ns/([^/]+)/")
    if folder then
        if folder:lower():match("^blizzard_") then return L["暴雪创建代码"],folder,true end
        return text(addonTitle(folder),folder),folder
    end
    if path:find("FrameXML/",1,true) then return L["暴雪创建代码"],"Blizzard UI",true end
end
local scanRelated
local function scanRelatedList(owner,state,depth,ok,...)
    if not ok then return end
    if select("#",...)>32 then state.truncated=true end
    for i=1,math.min(select("#",...),32) do
        scanRelated(owner,clean(select(i,...)),depth,state)
        if state.remaining<=0 or state.expired then state.truncated=true;break end
    end
end
scanRelated=function(owner,object,depth,state)
    if not object or secret(object) or state.visited[object] then return end
    if state.remaining<=0 or (debugprofilestop and debugprofilestop()-state.started>=1) then
        state.truncated=true;state.expired=true;return
    end
    state.remaining=state.remaining-1;state.visited[object]=true
    if owner:Read(object,"IsForbidden") or owner:Read(object,"IsVisible")~=true then return end
    local kind=owner:Read(object,"GetObjectType")
    local isRegion=kind=="Texture" or kind=="FontString"
    local alpha=owner:Read(object,isRegion and "GetAlpha" or "GetEffectiveAlpha")
    if type(alpha)~="number" or alpha<=0 then return end
    local location=owner:Read(object,"GetSourceLocation")
    local title,folder,native=owner:Source(location)
    if title and not native and not state.folders[folder] then
        state.folders[folder]=true
        if #state.results<3 then
            state.results[#state.results+1]={title=title,folder=folder,location=text(location),
                name=text(owner:Read(object,"GetDebugName"))}
        else state.truncated=true end
    end
    if not isRegion and depth<2 then
        scanRelatedList(owner,state,depth+1,pcall(method(object,"GetRegions"),object))
        if state.remaining>0 and not state.expired then
            scanRelatedList(owner,state,depth+1,pcall(method(object,"GetChildren"),object))
        end
    end
end
function M:RelatedSources(object)
    local kind=self:Read(object,"GetObjectType")
    if kind=="Texture" or kind=="FontString" then object=self:Read(object,"GetParent") end
    if not self:CheckFocus(object) then return end
    local state={remaining=64,started=debugprofilestop and debugprofilestop() or 0,visited={},folders={},results={}}
    scanRelated(self,object,0,state)
    return #state.results>0 and state.results or nil,state.truncated
end
function M:Analyze(frame)
    local location=self:Read(frame,"GetSourceLocation")
    local title,folder,native=self:Source(location)
    local resolved=title and not native
    local name=text(self:Read(frame,"GetName"),text(self:Read(frame,"GetDebugName"),L["未命名框体"]))
    local data={name=name,title=native and L["归属未确定"] or title or L["暂未识别"],confidence=native and L["创建位置来自暴雪代码"] or title and L["创建来源"] or L["来源未确定"],
        location=text(location,L["未提供创建位置"]),parents={},kind=text(self:Read(frame,"GetObjectType"))}
    if not title or native then
        local prefix=name:match("^([%a][%w]+)[_%-]")
        local guessed=prefix and addonTitle(prefix)
        if guessed then data.title=text(guessed);data.confidence=L["可能来自 · 根据框体名称"] end
    end
    local parent=self:Read(frame,"GetParent")
    local visited={[frame]=true}
    local started=debugprofilestop and debugprofilestop() or 0
    for depth=1,16 do
        if not parent or parent==UIParent or parent==WorldFrame or visited[parent] then break end
        visited[parent]=true
        local parentTitle,_,parentNative=self:Source(self:Read(parent,"GetSourceLocation"))
        data.parents[#data.parents+1]=text(self:Read(parent,"GetName"),L["未命名父级"])..(parentTitle and " · "..parentTitle or "")
        if (not title or native) and parentTitle and not parentNative and data.confidence~=L["可能来自 · 根据父级来源"] then
            data.title=parentTitle;data.confidence=L["可能来自 · 根据父级来源"]
            resolved=true
        end
        parent=self:Read(parent,"GetParent")
        if debugprofilestop and debugprofilestop()-started>=1 then data.truncated=true;break end
    end
    if parent and parent~=UIParent and parent~=WorldFrame then data.truncated=true end
    if not resolved then
        data.relatedSources,data.relatedTruncated=self:RelatedSources(frame)
        if data.relatedSources then
            local names={}
            for i,source in ipairs(data.relatedSources) do names[i]=source.title end
            data.title=table.concat(names," / ");data.confidence=L["关联插件 · 内部控件来源"]
        end
    end
    local width,height=self:Read(frame,"GetWidth"),self:Read(frame,"GetHeight")
    data.size=type(width)=="number" and type(height)=="number" and string.format("%.0f × %.0f",width,height) or "—"
    data.level=self:Read(frame,"GetFrameLevel")
    data.strata=text(self:Read(frame,"GetFrameStrata"))
    return data
end
function M:CheckFocus(frame)
    frame=clean(frame)
    if not frame or frame==UIParent or frame==WorldFrame or self:Read(frame,"IsForbidden") then return end
    local current=frame
    for depth=1,16 do
        if current==GameTooltip then return end
        if current==self.stackRoot or current==self.stackTooltip then return nil,true end
        if self.view and (current==self.view.frame or current==self.view.outline) then return nil,true end
        if current==UIParent or current==WorldFrame or not current then break end
        current=self:Read(current,"GetParent")
    end
    return frame
end
local Picker=I.Builtin.AddonInspectorPicker
function M:ResetPicking()
    if self.picker then self.picker:Reset() end
end
function M:SelectionState()
    return self.picker and self.picker:State()
end
function M:StackFocus(objects,preferred,frozen)
    if not self.picker then self.picker=Picker.New(function(object) return self:CheckFocus(object)~=nil end) end
    local ok,x,y=pcall(GetCursorPosition)
    if not ok then x,y=nil,nil end
    local result=self.picker:Step(preferred,objects,x,y,frozen)
    return result.object,nil,result.supported
end
function M:PickReport()
    return self.picker and self.picker:Describe() or "Picker: unavailable"
end
local function sampleNative(tooltip,root)
    tooltip:SetOwner(root,"ANCHOR_NONE")
    tooltip:SetParent(root)
    return tooltip:SetFrameStack(false,true,0)
end
function M:NativeFocus()
    if not self.stackRoot then
        self.stackRoot=CreateFrame("Frame",nil,UIParent)
        self.stackRoot:Hide();self.stackRoot:EnableMouse(false)
        self.stackTooltip=call(CreateFrame,"GameTooltip",nil,self.stackRoot,"SharedTooltipTemplate")
        if self.stackTooltip then self.stackTooltip:EnableMouse(false);self.stackTooltip:Hide() end
    end
    local tooltip=self.stackTooltip
    if not tooltip or not method(tooltip,"SetFrameStack") then return end
    -- A hidden parent also contains deferred third-party skinning or Show calls.
    -- Never use the player's GameTooltip/FrameStackTooltip or change their CVars.
    local outline=self.view and self.view.outline
    local restoreOutline=outline and self:Read(outline,"IsShown")
    if restoreOutline then outline:Hide() end
    local target=call(sampleNative,tooltip,self.stackRoot)
    tooltip:Hide();tooltip:ClearLines()
    if restoreOutline then outline:Show() end
    return target
end
function M:Focus()
    local foci=call(GetMouseFoci)
    -- Hovering our controls must not replace the inspected target with our UI.
    local fallback
    if type(foci)=="table" then
        for index=1,math.min(#foci,32) do
            local frame,own=self:CheckFocus(foci[index])
            if own then return nil,true end
            if not fallback and frame and self:Read(frame,"IsVisible")==true then
                local alpha=self:Read(frame,"GetEffectiveAlpha")
                if type(alpha)=="number" and alpha>0 then fallback=frame end
            end
        end
    end
    local target,own,supported=self:StackFocus(C_System and C_System.GetFrameStack,self:NativeFocus())
    if target or supported then return target,own end
    return fallback -- Legacy input-focus compatibility when native APIs are unavailable.
end
function M:UpdatePointer()
    if not self.running then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    self.view:SetPaused(IsShiftKeyDown and IsShiftKeyDown() or false)
    self.view:Place(self.target)
end
function M:Poll()
    if not self.running then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    self:UpdatePointer()
    if not self.running or self.view.copying then return end
    local target,own
    local state=self:SelectionState()
    if self.view.paused and (self.target or self.view.hasDiagnostic) then
        if self.target or not state or state.ready then return end
        target=self:StackFocus(nil,nil,true)
    else target,own=self:Focus() end
    if own then self.view:Place(self.target);return end
    state=self:SelectionState()
    local unverified=state and state.evidence==1 or false
    local reason=state and state.reason
    if target~=self.target or (target and self.data and (self.data.contentUnverified~=unverified or self.data.evidenceReason~=reason
        or self.data.outlineTarget~=(state and state.outline)))
        or (not target and (self.view.hasDiagnostic~=(state and state.hasDiagnostic or false)
        or self.view.diagnosticPending~=(state and state.pending or false)
        or self.view.diagnosticReady~=(state and state.ready or false))) then
        self.target=target;self.data=target and self:Analyze(target) or nil
        if self.data then
            self.data.contentUnverified,self.data.evidenceReason,self.data.outlineTarget=unverified,reason,state and state.outline
        end
        self.view:Update(target,self.data)
    end
    self.view:Place(target)
end
function M:Schedule()
    local epoch=self.epoch
    self.timer=C_Timer.NewTimer(0.1,function()
        if not self.running or epoch~=self.epoch then return end
        self.timer=nil;self:Poll()
        if self.running and epoch==self.epoch then self:Schedule() end
    end)
end
function M:Stop()
    self.running=false;self.epoch=self.epoch+1
    if self.timer then self.timer:Cancel();self.timer=nil end
    self.target,self.data=nil,nil
    self:ResetPicking()
    if self.stackTooltip then self.stackTooltip:Hide();self.stackTooltip:ClearLines() end
    if self.view then self.view:Hide() end
end
function M:SuppressHoverTooltip(tooltip)
    if not self.running or (InCombatLockdown and InCombatLockdown()) then return end
    if self:Read(tooltip,"IsForbidden") then return end
    call(method(tooltip,"Hide"),tooltip)
end
function M:BeginTooltipSuppression()
    local tooltip=GameTooltip
    if not tooltip or self:Read(tooltip,"IsForbidden") then return end
    if self.hoverTooltip~=tooltip then
        self.hoverHideCallback=self.hoverHideCallback or function(shown) self:SuppressHoverTooltip(shown) end
        local ok,installed=pcall(method(tooltip,"HookScript"),tooltip,"OnShow",self.hoverHideCallback)
        if ok and installed~=false then self.hoverTooltip=tooltip end
    end
    -- Existing hover content is stale for inspection. Future real hover events
    -- rebuild it normally after Stop; never re-show old tooltip contents here.
    self:SuppressHoverTooltip(tooltip)
end
function M:Start()
    if not self.enabled then return {ok=false,message=L["请先启用插件识别来源"]} end
    if InCombatLockdown and InCombatLockdown() then return {ok=false,message=L["请在脱离战斗后识别插件"]} end
    self:Stop()
    self.view=self.view or _G.Lychee.UI.CreateAddonInspector(self)
    self.running=true
    self:BeginTooltipSuppression()
    self.view:Show();self:Poll();self:Schedule()
    return {ok=true,close=true}
end
function M:Parent()
    if not self.running or not self.target then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    local parent=self:Read(self.target,"GetParent")
    if not parent or parent==UIParent or parent==WorldFrame or self:Read(parent,"IsForbidden") then return end
    local unverified=self.data and self.data.contentUnverified
    self.target=parent;self.data=self:Analyze(parent)
    self.data.contentUnverified=unverified;self.data.evidenceReason=unverified and "parent-source-only" or nil
    self.view:Update(parent,self.data)
end
function M:Report()
    local data=self.data
    if not data then return self:PickReport() end
    local lines={L["插件识别"],data.confidence.."："..data.title,L["框体："]..data.name,L["类型："]..data.kind,
        L["尺寸："]..data.size,L["层级："]..data.strata.." / "..tostring(data.level or "—"),L["创建位置："]..data.location,L["父级关联（不代表修改来源）："]}
    for _,parent in ipairs(data.parents) do lines[#lines+1]=parent end
    if data.truncated then lines[#lines+1]=L["父级信息已截断"] end
    if data.relatedSources then
        lines[#lines+1]=L["内部控件来源（不代表整个框体归属）："]
        for _,source in ipairs(data.relatedSources) do lines[#lines+1]=source.title.." · "..source.name.." · "..source.location end
    end
    if data.relatedTruncated then lines[#lines+1]=L["关联信息已截断"] end
    if data.contentUnverified then lines[#lines+1]=L["原生命中 · 内容无法验证"].." ("..tostring(data.evidenceReason)..")" end
    lines[#lines+1]=self:PickReport()
    return table.concat(lines,"\n"):sub(1,196608)
end
function M:SourceSetting()
    return call(C_CVar and C_CVar.GetCVar,"enableSourceLocationLookup")
end
function M:EnableSource()
    if not self.running or (InCombatLockdown and InCombatLockdown()) then return end
    if self:SourceSetting()==nil or not C_CVar or not C_CVar.SetCVar or not ReloadUI then return false end
    local ok=pcall(C_CVar.SetCVar,"enableSourceLocationLookup","1")
    if not ok or self:SourceSetting()~="1" then return false end
    self:Stop();ReloadUI();return true
end
function M:Init()
    if self.handle then return true end
    LycheeDB.optionalProviderDefaults=LycheeDB.optionalProviderDefaults or {}
    LycheeDB.disabledProviders=LycheeDB.disabledProviders or {}
    if not LycheeDB.optionalProviderDefaults[self.id] then
        LycheeDB.optionalProviderDefaults[self.id]=true;LycheeDB.disabledProviders[self.id]=true
    end
    self.handle=_G.Lychee:RegisterProvider({id=self.id,apiVersion=2,minApiRevision=2,i18n=L.resources,version="1.0.0",title=L["插件识别"],scope=I.Builtin.Support:Scope("builtin.addon-inspector"),
        entries={{id="inspect",title=L["插件识别"],kindTitle=L["工具"],subtitle=L["指向界面，查看来自哪个插件"],
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\addon-inspector.tga",
            aliases={"这是什么插件","识别插件","框体","界面来源","wtf","inspect","frame"},actions={"inspect"}}},
        actions={inspect={title=L["开始识别"],run=function() return M:Start() end}},
        onEnable=function() M.enabled=true;return function(reason)
            M.enabled=false;M:Stop();if reason=="unregister" then M.handle=nil end
        end end})
    return self.handle~=nil
end
