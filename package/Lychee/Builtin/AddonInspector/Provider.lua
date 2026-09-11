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
function M:Analyze(frame)
    local location=self:Read(frame,"GetSourceLocation")
    local title,folder,native=self:Source(location)
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
        end
        parent=self:Read(parent,"GetParent")
        if debugprofilestop and debugprofilestop()-started>=1 then data.truncated=true;break end
    end
    if parent and parent~=UIParent and parent~=WorldFrame then data.truncated=true end
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
        if self.view and (current==self.view.frame or current==self.view.outline) then return nil,true end
        if current==UIParent or current==WorldFrame or not current then break end
        current=self:Read(current,"GetParent")
    end
    return frame
end
local strataOrder={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local layerOrder={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
function M:ResetVisual()
    self.visualCursor,self.visualBest,self.visualBestFrame,self.visualResult,self.visualResultFrame=nil,nil,nil,nil,nil
    self.visualX,self.visualY,self.visualPending=nil,nil,false
end
function M:HitRect(object,scale)
    local ok,left,bottom,width,height=pcall(method(object,"GetRect"),object)
    if not ok or secret(left) or secret(bottom) or secret(width) or secret(height) then return end
    if type(left)~="number" or type(bottom)~="number" or type(width)~="number" or type(height)~="number"
        or type(scale)~="number" or scale<=0 or width<=0 or height<=0 then return end
    local x,y=self.visualX/scale,self.visualY/scale
    if x>=left and x<=left+width and y>=bottom and y<=bottom+height then return width*height*scale*scale end
end
function M:VisualFrame(frame)
    if self:Read(frame,"IsVisible")~=true then return end
    local alpha=self:Read(frame,"GetEffectiveAlpha")
    if type(alpha)~="number" or alpha<=0 then return end
    local valid=self:CheckFocus(frame)
    if not valid then return end
    local parent=self:Read(frame,"GetParent")
    for depth=1,16 do
        if not parent then break end
        if self:Read(parent,"DoesClipChildren")==true and not self:HitRect(parent,self:Read(parent,"GetEffectiveScale")) then return end
        parent=self:Read(parent,"GetParent")
    end
    return self:Read(frame,"GetEffectiveScale")
end
function M:VisualRegion(region,scale)
    if self:Read(region,"IsVisible")~=true then return end
    local alpha=self:Read(region,"GetAlpha")
    if type(alpha)~="number" or alpha<=0 then return end
    local kind=self:Read(region,"GetObjectType")
    local colorMethod
    if kind=="Texture" then
        local texture=self:Read(region,"GetTexture") or self:Read(region,"GetAtlas")
        if not texture or texture=="" then return end
        colorMethod="GetVertexColor"
    elseif kind=="FontString" then
        local value=self:Read(region,"GetText")
        if type(value)~="string" or not value:find("%S") then return end
        colorMethod="GetTextColor"
    else return end
    local ok,_,_,_,colorAlpha=pcall(method(region,colorMethod),region)
    if not ok or secret(colorAlpha) or type(colorAlpha)~="number" or colorAlpha<=0 then return end
    return self:HitRect(region,scale)
end
local function inspectRegions(owner,frame,scale,strata,level,ok,...)
    if not ok then return end
    for i=1,math.min(select("#",...),32) do
        local region=clean(select(i,...))
        local area=owner:VisualRegion(region,scale)
        if area then
            local layer=layerOrder[owner:Read(region,"GetDrawLayer")] or 0
            if not owner.visualBest or strata>owner.visualStrata
                or (strata==owner.visualStrata and (level>owner.visualLevel
                or (level==owner.visualLevel and (layer>owner.visualLayer
                or (layer==owner.visualLayer and area<owner.visualArea))))) then
                owner.visualBest,owner.visualBestFrame=region,frame
                owner.visualStrata,owner.visualLevel,owner.visualLayer,owner.visualArea=strata,level,layer,area
            end
        end
    end
end
function M:VisualFocus()
    if type(EnumerateFrames)~="function" then return end
    local ok,x,y=pcall(GetCursorPosition)
    if not ok or secret(x) or secret(y) or type(x)~="number" or type(y)~="number" then self:ResetVisual();return end
    if x~=self.visualX or y~=self.visualY then self:ResetVisual();self.visualX,self.visualY=x,y end
    if not self.visualPending then self.visualBest,self.visualBestFrame=nil,nil;self.visualPending=true end
    local started=debugprofilestop and debugprofilestop() or 0
    for i=1,128 do
        local frame=call(EnumerateFrames,self.visualCursor)
        if not frame or frame==self.visualCursor then
            self.visualResult,self.visualResultFrame=self.visualBest,self.visualBestFrame
            self.visualCursor,self.visualBest,self.visualBestFrame,self.visualPending=nil,nil,nil,false
            break
        end
        self.visualCursor=frame
        local scale=self:VisualFrame(frame)
        if scale then
            local strata=strataOrder[self:Read(frame,"GetFrameStrata")] or 0
            local level=self:Read(frame,"GetFrameLevel")
            if type(level)=="number" then inspectRegions(self,frame,scale,strata,level,pcall(method(frame,"GetRegions"),frame)) end
        end
        if debugprofilestop and debugprofilestop()-started>=0.75 then break end
    end
    -- Revalidate the retained result at the current pointer; never publish a
    -- previous position or a now-hidden icon while the next batch is pending.
    local scale=self.visualResultFrame and self:VisualFrame(self.visualResultFrame)
    if scale and self:VisualRegion(self.visualResult,scale) then return self.visualResult end
    self.visualResult,self.visualResultFrame=nil,nil
end
function M:Focus()
    local foci=call(GetMouseFoci)
    if type(foci)~="table" then return end
    for index=1,math.min(#foci,32) do
        local frame,own=self:CheckFocus(foci[index])
        if frame or own then self:ResetVisual();return frame,own end
    end
    return self:VisualFocus()
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
    if not self.running or (self.view.paused and self.target) or self.view.copying then return end
    local target,own=self:Focus()
    if own then self.view:Place(self.target);return end
    if target~=self.target then
        self.target=target;self.data=target and self:Analyze(target) or nil
        self.view:Update(target,self.data)
    end
    self.view:Place(target)
end
function M:Schedule()
    local epoch=self.epoch
    local frozen=self.view and ((self.view.paused and self.target) or self.view.copying)
    self.timer=C_Timer.NewTimer(self.visualPending and not frozen and 0.01 or 0.1,function()
        if not self.running or epoch~=self.epoch then return end
        self.timer=nil;self:Poll()
        if self.running and epoch==self.epoch then self:Schedule() end
    end)
end
function M:Stop()
    self.running=false;self.epoch=self.epoch+1
    if self.timer then self.timer:Cancel();self.timer=nil end
    self.target,self.data=nil,nil
    self:ResetVisual()
    if self.view then self.view:Hide() end
end
function M:Start()
    if not self.enabled then return {ok=false,message=L["请先启用插件识别来源"]} end
    if InCombatLockdown and InCombatLockdown() then return {ok=false,message=L["请在脱离战斗后识别插件"]} end
    self:Stop()
    self.view=self.view or _G.Lychee.UI.CreateAddonInspector(self)
    self.running=true
    self.view:Show();self:Poll();self:Schedule()
    return {ok=true,close=true}
end
function M:Parent()
    if not self.running or not self.target then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    local parent=self:Read(self.target,"GetParent")
    if not parent or parent==UIParent or parent==WorldFrame or self:Read(parent,"IsForbidden") then return end
    self.target=parent;self.data=self:Analyze(parent);self.view:Update(parent,self.data)
end
function M:Report()
    local data=self.data
    if not data then return L["尚未选择框体"] end
    local lines={L["插件识别"],data.confidence.."："..data.title,L["框体："]..data.name,L["类型："]..data.kind,
        L["尺寸："]..data.size,L["层级："]..data.strata.." / "..tostring(data.level or "—"),L["创建位置："]..data.location,L["父级关联（不代表修改来源）："]}
    for _,parent in ipairs(data.parents) do lines[#lines+1]=parent end
    if data.truncated then lines[#lines+1]=L["父级信息已截断"] end
    return table.concat(lines,"\n"):sub(1,8192)
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
