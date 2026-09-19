local L = _G.LycheeInternal.Locale
local UI=_G.Lychee.UI
function UI.CreateAddonInspector(owner)
    local T,C=UI.Theme,UI.Components
    local view={owner=owner,expanded=false,copying=false}
    local frame=CreateFrame("Frame",nil,UIParent)
    -- AuraButtonTooltip has a separate, raised tooltip layer. Reserve the
    -- inspection panel's level without changing protected tooltip objects.
    view.frame=frame;frame:Hide();frame:SetSize(320,120);frame:SetFrameStrata("TOOLTIP");frame:SetFrameLevel(10000)
    frame:SetClampedToScreen(true);frame:EnableMouse(true)
    T:CreateRoundedSurface(frame,"window",10)
    local function textNode(key,role,color,y,width,height,text)
        return {type="Text",key=key,props={role=role,color=color,text=text,width=width,height=height,justifyH="LEFT",justifyV="TOP",point={"TOPLEFT",frame,"TOPLEFT",16,y}}}
    end
    view.display=UI:Create(frame,{type="Fragment",children={
        textNode("heading","title","text",-18,250,24),
        textNode("confidence","body","textMuted",-50,288,32),
        textNode("name","body","text",-94,368,32),
        textNode("detailMeta","meta","textDim",-134,368,18),
        textNode("sourceLabel","meta","textDim",-168,368,16,L["创建位置"]),
        textNode("details","body","textMuted",-190,368,40),
        textNode("parentLabel","meta","textDim",-246,368,16,L["父级关联"]),
        textNode("parents","body","textMuted",-268,368,32),
        textNode("footer","meta","textDim",-96,368,16),
    }})
    assert(view.display:Update({}))
    for _,key in ipairs({"heading","confidence","name","detailMeta","sourceLabel","details","parentLabel","parents","footer"}) do view[key]=view.display:Get(key) end
    view.divider=frame:CreateTexture(nil,"BACKGROUND")
    view.divider:SetHeight(1);view.divider:SetPoint("TOPLEFT",16,-84);view.divider:SetPoint("TOPRIGHT",-16,-84)
    T:SetColorTexture(view.divider,"border")
    view.heading:SetMaxLines(1);view.heading:SetWordWrap(false)
    view.name:SetMaxLines(2);view.details:SetMaxLines(3);view.parents:SetMaxLines(2)
    local function button(title,x,y,width,action,rounded)
        local b=C:CreateNavigationButton(frame,{text=title,width=width,height=30,point="TOPLEFT",x=x,y=y,onClick=action})
        T:SetFont(b.label,"body");return b
    end
    view.close=button("Esc",266,-6,40,function() owner:Stop() end)
    view.copy=button(L["复制信息"],16,-302,140,function()
        if not owner.data and not view.hasDiagnostic then return end
        if not owner.data and not view.diagnosticReady then return end
        view.copying=not view.copying;view:Layout()
        if view.copying then
            view.report=owner:Report();view.edit:SetText(view.report);view.edit:Show();view:SyncReport();view.edit:SetFocus();view.edit:HighlightText();view:ScrollTo(0)
        else view.edit:ClearFocus();view.edit:Hide() end
    end,true)
    view.parent=button(L["上一级"],164,-302,140,function() owner:Parent() end,true)
    view.setup=button(L["启用来源记录并重载"],16,-338,288,function()
        if owner:EnableSource()==false then view.footer:SetText(L["无法启用来源记录，请稍后重试"]) end
    end)
    local reportHost=CreateFrame("Frame",nil,frame);view.reportHost=reportHost;reportHost:Hide()
    reportHost:SetPoint("TOPLEFT",16,-60);reportHost:SetSize(448,280)
    T:CreateRoundedSurface(reportHost,"field",6)
    local scroll=CreateFrame("ScrollFrame",nil,reportHost);view.reportScroll=scroll
    scroll:SetPoint("TOPLEFT",10,-10);scroll:SetSize(414,260)
    local edit=CreateFrame("EditBox",nil,scroll);view.edit=edit
    edit:SetPoint("TOPLEFT");edit:SetSize(414,260);edit:SetMultiLine(true);edit:SetAutoFocus(false)
    T:SetFont(edit,"body");T:SetTextColor(edit,"text");edit:Hide()
    edit:SetTextInsets(0,0,0,0);scroll:SetScrollChild(edit)
    view.reportBar=C:CreateScrollbar(reportHost,function(value) view:ScrollTo(value) end)
    view.reportBar.frame:ClearAllPoints();view.reportBar.frame:SetPoint("TOPRIGHT",-2,-10);view.reportBar.frame:SetHeight(260)
    function view:ScrollTo(value)
        local maximum=math.max(0,scroll:GetVerticalScrollRange())
        self.reportOffset=math.max(0,math.min(maximum,value or 0))
        scroll:SetVerticalScroll(self.reportOffset)
        self.reportBar:SetRange(scroll:GetHeight()+maximum,scroll:GetHeight(),self.reportOffset)
    end
    function view:SyncReport()
        if not self.copying then return end
        scroll:UpdateScrollChildRect();self:ScrollTo(self.reportOffset)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta) if view.copying then view:ScrollTo((view.reportOffset or 0)-delta*36) end end)
    edit:SetScript("OnEscapePressed",function() owner:Stop() end)
    edit:SetScript("OnSizeChanged",function() view:SyncReport() end)
    edit:SetScript("OnCursorChanged",function(_,x,y,w,h)
        if not view.copying then return end
        local offset=view.reportOffset or 0;local top=-y
        if top<offset then view:ScrollTo(top)
        elseif top+h>offset+scroll:GetHeight() then view:ScrollTo(top+h-scroll:GetHeight()) end
    end)
    edit:SetScript("OnTextChanged",function(_,userInput)
        if userInput and view.report then edit:SetText(view.report);edit:HighlightText() end
        view:SyncReport()
    end)
    local outline=CreateFrame("Frame",nil,UIParent);view.outline=outline
    -- Keep the marker below the panel even when it is shown after the panel.
    outline:SetFrameStrata("TOOLTIP");outline:SetFrameLevel(0);outline:EnableMouse(false);outline:Hide()
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local texture=outline:CreateTexture(nil,"OVERLAY")
        T:SetColorTexture(texture,"accent")
        if edge=="TOP" or edge=="BOTTOM" then
            texture:SetHeight(1);texture:SetPoint(edge.."LEFT");texture:SetPoint(edge.."RIGHT")
        else texture:SetWidth(1);texture:SetPoint("TOP"..edge);texture:SetPoint("BOTTOM"..edge) end
    end
    function view:Layout()
        local expanded=(self.expanded and (self.hasTarget or self.hasDiagnostic)) or self.copying
        local sourceSetting=owner:SourceSetting()
        local setup=expanded and self.hasTarget and not self.copying and sourceSetting~=nil and sourceSetting~="1"
        self.width=self.copying and 480 or (expanded and (self.hasTarget and 400 or 360) or 320)
        local height=self.copying and 420 or (expanded and (self.hasTarget and (setup and 414 or 378) or 174) or 120)
        frame:SetSize(self.width,height)
        self.heading:SetWidth(self.width-86);self.confidence:SetWidth(self.width-32)
        self.close.frame:ClearAllPoints();self.close.frame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-10)
        self.heading:SetText(self.copying and L["检查报告"] or (owner.data and owner.data.title or L["插件识别"]))
        for _,region in ipairs({self.name,self.details,self.detailMeta,self.sourceLabel,self.parentLabel,self.parents,self.divider}) do
            region:SetShown(expanded and self.hasTarget and not self.copying)
        end
        self.confidence:SetShown(not self.copying)
        self.copy:SetText(self.copying and L["返回信息"] or L["复制信息"])
        self.copy.frame:SetShown(expanded);self.parent.frame:SetShown(expanded and self.hasTarget and not self.copying)
        self.copy.frame:ClearAllPoints();self.copy.frame:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,38)
        self.parent.frame:ClearAllPoints();self.parent.frame:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-16,38)
        self.setup.frame:SetShown(setup)
        self.setup.frame:ClearAllPoints();self.setup.frame:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,74)
        self.footer:SetWidth(self.width-32);self.footer:ClearAllPoints();self.footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,12)
        self.footer:SetText(self.copying and L["Ctrl+C 复制 · 滚轮浏览 · Esc 退出"] or (expanded and L["松开 Shift 继续识别 · Esc 退出"] or L["按住 Shift 查看详情 · Esc 退出"]))
        reportHost:SetShown(self.copying)
        if not self.copying then
            self.report=nil;self.reportOffset=0;self.reportBar:StopDrag();edit:ClearFocus();edit:Hide();edit:SetText("");scroll:SetVerticalScroll(0)
        end
        self:Place(owner.target,true)
    end
    function view:Update(target,data)
        self.hasTarget=data~=nil
        local state=owner:SelectionState()
        self.hasDiagnostic=state and state.hasDiagnostic or false
        self.diagnosticPending=state and state.pending or false
        self.diagnosticReady=state and state.ready or false
        self.copying=false;self.report=nil;edit:ClearFocus();edit:Hide();edit:SetText("")
        self.heading:SetText(data and data.title or L["插件识别"])
        self.confidence:SetText(data and (data.contentUnverified and L["原生命中 · 内容无法验证"] or data.confidence) or self.hasDiagnostic and
            L["暂未识别此处界面"] or L["指向界面，查看来自哪个插件"])
        self.name:SetText(data and data.name or self.hasDiagnostic and L["按住 Shift 可复制检查信息"] or L["无需点击 · Esc 退出"])
        local location=data and data.location or ""
        self.details:SetText(location)
        self.detailMeta:SetText(data and (data.kind.."  ·  "..data.size.."  ·  "..data.strata) or "")
        self.parents:SetText(data and (#data.parents>0 and table.concat(data.parents,"\n",1,math.min(2,#data.parents)) or L["未发现可确认的父级来源"]) or "")
        self.copy:SetEnabled(data~=nil or (self.hasDiagnostic and self.diagnosticReady))
        local parent=target and owner:Read(target,"GetParent")
        self.parent:SetEnabled(parent~=nil and parent~=UIParent and parent~=WorldFrame)
        self.outline:Hide();self.outline:ClearAllPoints()
        if target and not data.contentUnverified then
            local ok=pcall(self.outline.SetAllPoints,self.outline,data.outlineTarget or target)
            if ok then self.outline:Show() end
        end
        self:Layout()
    end
    function view:SetPaused(paused)
        if self.paused==paused then return end
        self.paused=paused;self.expanded=paused
        self:Layout()
    end
    function view:Place(target,force)
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        if type(width)~="number" or type(height)~="number" or width<=32 or height<=32 then return end
        local panelWidth=self.width or 320
        local scale=math.min(T.Metrics.uiScale or 1,(width-32)/panelWidth,(height-32)/frame:GetHeight())
        if self.scale~=scale then frame:SetScale(scale);self.scale=scale;force=true end
        local w,h=panelWidth*scale,frame:GetHeight()*scale
        local x,top=self.anchorX,self.anchorTop
        if not ((self.paused or self.copying) and x and top) then
            if not GetCursorPosition then return end
            local ok,cx,cy=pcall(GetCursorPosition)
            if not ok or (issecretvalue and (issecretvalue(cx) or issecretvalue(cy))) or type(cx)~="number" or type(cy)~="number" then return end
            local rootScale=UIParent:GetEffectiveScale()
            if rootScale<=0 then return end
            cx,cy=cx/rootScale,cy/rootScale
            -- Prefer right/below the pointer; flip at edges rather than letting
            -- screen clamping push the window back underneath the pointer.
            x=cx+20
            if x+w>width-16 then x=cx-20-w end
            top=cy-20
            if top-h<16 then top=cy+20+h end
        end
        x=math.max(16,math.min(width-16-w,x))
        top=math.max(16+h,math.min(height-16,top))
        if x~=self.anchorX or top~=self.anchorTop or force then
            self.anchorX,self.anchorTop=x,top
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,top/scale)
        end
    end
    function view:Show()
        self.expanded=false;self.paused=false;self.copying=false;self.anchorX,self.anchorTop=nil,nil;self:Update(nil,nil)
        frame:RegisterEvent("PLAYER_REGEN_DISABLED");frame:EnableKeyboard(true);frame:Show()
        frame:SetPropagateKeyboardInput(true)
        frame:SetScript("OnUpdate",function() owner:UpdatePointer() end)
        if UI.Motion then UI.Motion:Reveal(frame,"enter") end
    end
    function view:Hide()
        frame:SetScript("OnUpdate",nil)
        frame:UnregisterAllEvents();pcall(frame.EnableKeyboard,frame,false)
        if UI.Motion then UI.Motion:Cancel(frame,true) end
        frame:Hide();outline:Hide();outline:ClearAllPoints();self.reportBar:StopDrag();reportHost:Hide();edit:ClearFocus();edit:Hide();edit:SetText("")
        self.report=nil;self.copying=false
    end
    frame:SetScript("OnKeyDown",function(self,key)
        if InCombatLockdown and InCombatLockdown() then owner:Stop();return end
        if key=="ESCAPE" then self:SetPropagateKeyboardInput(false);owner:Stop()
        else self:SetPropagateKeyboardInput(true) end
    end)
    frame:SetScript("OnEvent",function() owner:Stop() end)
    frame:SetScript("OnHide",function() if owner.running then owner:Stop() end end)
    return view
end
