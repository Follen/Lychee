local L = _G.LycheeInternal.Locale
local UI=_G.Lychee.UI
function UI.CreateAddonInspector(owner)
    local T,C=UI.Theme,UI.Components
    local view={owner=owner,expanded=false,copying=false}
    local frame=CreateFrame("Frame",nil,UIParent)
    view.frame=frame;frame:Hide();frame:SetSize(320,140);frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true);frame:EnableMouse(true)
    T:CreateRoundedSurface(frame,"window",10)
    local function label(role,color,x,y,width,height)
        local value=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        value:SetPoint("TOPLEFT",x,y);value:SetSize(width,height);value:SetJustifyH("LEFT");value:SetJustifyV("TOP")
        T:SetFont(value,role);T:SetTextColor(value,color);return value
    end
    view.kicker=label("meta","textDim",16,-12,220,16)
    view.kicker:SetText(L["插件识别"])
    view.heading=label("title","text",16,-34,288,22)
    view.confidence=label("meta","textMuted",16,-60,288,18)
    view.name=label("body","textMuted",16,-84,288,18)
    view.detailMeta=label("meta","textMuted",16,-124,288,18)
    view.sourceLabel=label("meta","textDim",16,-150,288,16);view.sourceLabel:SetText(L["创建位置"])
    view.details=label("body","textMuted",16,-170,288,48)
    view.parentLabel=label("meta","textDim",16,-226,288,16);view.parentLabel:SetText(L["父级关联"])
    view.parents=label("body","textMuted",16,-246,288,42)
    view.divider=frame:CreateTexture(nil,"BACKGROUND")
    view.divider:SetHeight(1);view.divider:SetPoint("TOPLEFT",16,-112);view.divider:SetPoint("TOPRIGHT",-16,-112)
    T:SetColorTexture(view.divider,"border")
    view.footer=label("meta","textDim",16,-116,288,16)
    for _,region in ipairs({view.heading,view.confidence,view.name}) do
        if region.SetMaxLines then region:SetMaxLines(1) end
        if region.SetWordWrap then region:SetWordWrap(false) end
    end
    if view.details.SetMaxLines then view.details:SetMaxLines(3);view.parents:SetMaxLines(3) end
    local function button(title,x,y,width,action,rounded)
        local b=C:CreateNavigationButton(frame,{text=title,width=width,height=30,point="TOPLEFT",x=x,y=y,onClick=action})
        T:SetFont(b.label,"body");return b
    end
    view.close=button("Esc",266,-6,40,function() owner:Stop() end)
    view.copy=button(L["复制信息"],16,-302,140,function()
        if not owner.data then return end
        view.copying=not view.copying;view:Layout()
        if view.copying then
            view.report=owner:Report();view.edit:SetText(view.report);view.edit:Show();view.edit:SetFocus();view.edit:HighlightText()
        else view.edit:ClearFocus();view.edit:Hide() end
    end,true)
    view.parent=button(L["上一级"],164,-302,140,function() owner:Parent() end,true)
    view.setup=button(L["启用来源记录并重载"],16,-338,288,function()
        if owner:EnableSource()==false then view.footer:SetText(L["无法启用来源记录，请稍后重试"]) end
    end)
    local edit=CreateFrame("EditBox",nil,frame);view.edit=edit
    edit:SetPoint("TOPLEFT",16,-60);edit:SetSize(288,230);edit:SetMultiLine(true);edit:SetAutoFocus(false)
    T:SetFont(edit,"body");T:SetTextColor(edit,"text");edit:Hide()
    edit:SetTextInsets(10,10,8,8);C:StyleEditBox(edit)
    edit:SetScript("OnEscapePressed",function() owner:Stop() end)
    edit:SetScript("OnTextChanged",function(_,userInput)
        if userInput and view.report then edit:SetText(view.report);edit:HighlightText() end
    end)
    local outline=CreateFrame("Frame",nil,UIParent);view.outline=outline
    outline:SetFrameStrata("TOOLTIP");outline:EnableMouse(false);outline:Hide()
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local texture=outline:CreateTexture(nil,"OVERLAY")
        T:SetColorTexture(texture,"accent")
        if edge=="TOP" or edge=="BOTTOM" then
            texture:SetHeight(1);texture:SetPoint(edge.."LEFT");texture:SetPoint(edge.."RIGHT")
        else texture:SetWidth(1);texture:SetPoint("TOP"..edge);texture:SetPoint("BOTTOM"..edge) end
    end
    function view:Layout()
        local expanded=self.expanded or self.copying
        local sourceSetting=owner:SourceSetting()
        local setup=self.expanded and not self.copying and sourceSetting~=nil and sourceSetting~="1"
        frame:SetHeight(expanded and (setup and 402 or 366) or 140)
        for _,region in ipairs({self.details,self.detailMeta,self.sourceLabel,self.parentLabel,self.parents,self.divider}) do
            region:SetShown(self.expanded and not self.copying)
        end
        self.name:SetShown(not self.copying)
        self.confidence:SetShown(not self.copying)
        self.copy:SetText(self.copying and L["返回信息"] or L["复制信息"])
        self.copy.frame:SetShown(expanded);self.parent.frame:SetShown(expanded and not self.copying)
        self.setup.frame:SetShown(setup)
        self.footer:ClearAllPoints();self.footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,12)
        self.footer:SetText(self.copying and L["Ctrl+C 复制 · Esc 退出"] or (expanded and L["松开 Shift 继续识别 · Esc 退出"] or L["按住 Shift 查看详情 · Esc 退出"]))
        if not self.copying then self.report=nil;edit:ClearFocus();edit:Hide();edit:SetText("") end
        self:Place(owner.target,true)
    end
    function view:Update(target,data)
        self.copying=false;self.report=nil;edit:ClearFocus();edit:Hide();edit:SetText("")
        self.heading:SetText(data and data.title or L["插件识别"])
        self.confidence:SetText(data and data.confidence or L["指向界面，查看来自哪个插件"])
        self.name:SetText(data and data.name or L["无需点击 · Esc 退出"])
        local location=data and data.location or ""
        self.details:SetText(location)
        self.detailMeta:SetText(data and (data.kind.."  ·  "..data.size.."  ·  "..data.strata) or "")
        self.parents:SetText(data and (#data.parents>0 and table.concat(data.parents,"\n",1,math.min(2,#data.parents)) or L["未发现可确认的父级来源"]) or "")
        self.copy:SetEnabled(data~=nil)
        local parent=target and owner:Read(target,"GetParent")
        self.parent:SetEnabled(parent~=nil and parent~=UIParent and parent~=WorldFrame)
        self.outline:Hide();self.outline:ClearAllPoints()
        if target then
            local ok=pcall(self.outline.SetAllPoints,self.outline,target)
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
        local scale=math.min(1,(width-32)/320,(height-32)/402)
        if self.scale~=scale then frame:SetScale(scale);self.scale=scale;force=true end
        local w,h=320*scale,frame:GetHeight()*scale
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
        frame:Hide();outline:Hide();outline:ClearAllPoints();edit:ClearFocus();edit:Hide();edit:SetText("")
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
