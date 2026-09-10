local UI=_G.Lychee.UI
function UI.CreateAddonInspector(owner)
    local T,C=UI.Theme,UI.Components
    local view={owner=owner,expanded=false,copying=false}
    local frame=CreateFrame("Frame",nil,UIParent)
    view.frame=frame;frame:Hide();frame:SetSize(360,164);frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true);frame:EnableMouse(true)
    T:CreateRoundedSurface(frame,"window",10)
    local function label(role,color,x,y,width,height)
        local value=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        value:SetPoint("TOPLEFT",x,y);value:SetSize(width,height);value:SetJustifyH("LEFT");value:SetJustifyV("TOP")
        T:SetFont(value,role);T:SetTextColor(value,color);return value
    end
    view.heading=label("title","text",16,-16,265,22)
    view.confidence=label("meta","textMuted",16,-43,328,18)
    view.name=label("body","textMuted",16,-65,328,32)
    view.details=label("body","textMuted",16,-108,328,176);view.details:Hide()
    view.footer=label("meta","textDim",16,-140,328,18)
    local function button(title,x,y,width,action)
        local b=C:CreateButton(frame,{text=title,width=width,height=28,point="TOPLEFT",x=x,y=y,
            colors={normal="transparent",hover="surfaceHover",pressed="surfaceSelected",disabled="transparent"},
            textColors={normal="textMuted",hover="text",pressed="text",disabled="disabled"},onClick=action})
        T:SetFont(b.label,"body");return b
    end
    view.close=button("Esc",304,-10,40,function() owner:Stop() end)
    view.copy=button("复制信息",10,-103,84,function()
        if not owner.data then return end
        view.copying=not view.copying;view:Layout()
        if view.copying then
            view.report=owner:Report();view.edit:SetText(view.report);view.edit:Show();view.edit:SetFocus();view.edit:HighlightText()
        else view.edit:ClearFocus();view.edit:Hide() end
    end)
    view.toggle=button("技术详情",108,-103,84,function() view.expanded=not view.expanded;view.copying=false;view:Layout() end)
    view.parent=button("上一级",208,-103,74,function() owner:Parent() end)
    view.setup=button("启用来源记录并重载",10,-287,210,function()
        if owner:EnableSource()==false then view.footer:SetText("无法启用来源记录，请稍后重试") end
    end)
    local edit=CreateFrame("EditBox",nil,frame);view.edit=edit
    edit:SetPoint("TOPLEFT",16,-64);edit:SetSize(328,212);edit:SetMultiLine(true);edit:SetAutoFocus(false)
    T:SetFont(edit,"body");T:SetTextColor(edit,"text");edit:Hide()
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
        frame:SetHeight(expanded and 340 or 164)
        self.details:SetShown(self.expanded and not self.copying)
        self.name:SetShown(not self.copying)
        self.toggle:SetText(self.expanded and "收起详情" or "技术详情")
        self.copy:SetText(self.copying and "返回信息" or "复制信息")
        for _,b in ipairs({self.copy,self.toggle,self.parent}) do
            local x=b==self.copy and 10 or b==self.toggle and 108 or 208
            b.frame:ClearAllPoints();b.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",x,expanded and -287 or -103)
        end
        local sourceSetting=owner:SourceSetting()
        self.setup.frame:SetShown(self.expanded and not self.copying and sourceSetting~=nil and sourceSetting~="1")
        if self.setup.frame:IsShown() then
            self.copy.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-249)
            self.toggle.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",108,-249)
            self.parent.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",208,-249)
            self.details:SetHeight(136)
        else self.details:SetHeight(176) end
        self.footer:ClearAllPoints();self.footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,10)
        self.footer:SetText(self.copying and "Ctrl+C 复制 · Esc 退出识别" or (sourceSetting=="0" and "来源记录未开启 · Shift 操作 · Esc 退出" or "Shift 暂停并操作 · Esc 退出"))
        if not self.copying then self.report=nil;edit:ClearFocus();edit:Hide();edit:SetText("") end
        self:Place(owner.target,true)
    end
    function view:Update(target,data)
        self.copying=false;self.report=nil;edit:ClearFocus();edit:Hide();edit:SetText("")
        self.heading:SetText(data and data.title or "插件识别")
        self.confidence:SetText(data and data.confidence or "指向界面，查看来自哪个插件")
        self.name:SetText(data and data.name or "无需点击 · Esc 退出")
        self.details:SetText(data and ("类型："..data.kind.."    尺寸："..data.size.."\n创建位置："..data.location.."\n父级关联：\n"..table.concat(data.parents,"\n",1,math.min(4,#data.parents))) or "")
        self.copy:SetEnabled(data~=nil);self.toggle:SetEnabled(data~=nil)
        local parent=target and owner:Read(target,"GetParent")
        self.parent:SetEnabled(parent~=nil and parent~=UIParent and parent~=WorldFrame)
        self.outline:Hide();self.outline:ClearAllPoints()
        if target then
            local ok=pcall(self.outline.SetAllPoints,self.outline,target)
            if ok then self.outline:Show() end
        end
        self:Layout()
    end
    function view:Place(target,force)
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        if type(width)~="number" or type(height)~="number" or width<=32 or height<=32 then return end
        local scale=math.min(1,(width-32)/360,(height-32)/340)
        if self.scale~=scale then frame:SetScale(scale);self.scale=scale end
        local w,h=360*scale,frame:GetHeight()*scale
        local left,right,bottom,top
        if target then
            left=owner:Read(target,"GetLeft");right=owner:Read(target,"GetRight")
            bottom=owner:Read(target,"GetBottom");top=owner:Read(target,"GetTop")
            local targetScale=owner:Read(target,"GetEffectiveScale")
            local rootScale=UIParent:GetEffectiveScale()
            if type(targetScale)=="number" and rootScale>0 then
                local ratio=targetScale/rootScale
                if type(left)=="number" then left=left*ratio end
                if type(right)=="number" then right=right*ratio end
                if type(bottom)=="number" then bottom=bottom*ratio end
                if type(top)=="number" then top=top*ratio end
            end
        end
        local cursorX,cursorY
        if GetCursorPosition then
            local ok,x,y=pcall(GetCursorPosition)
            if ok and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) and type(x)=="number" and type(y)=="number" then
                local rootScale=UIParent:GetEffectiveScale()
                if rootScale>0 then cursorX,cursorY=x/rootScale,y/rootScale end
            end
        end
        local best,bestArea=1,math.huge
        -- Start at the current corner: ties preserve position instead of bouncing
        -- back as soon as moving the popup exposes the frame underneath it.
        for offset=0,3 do
            local index=((self.corner or 1)-1+offset)%4+1
            local x=index%2==1 and width-w-16 or 16
            local y=index<=2 and height-h-16 or 16
            local area=0
            if type(left)=="number" and type(right)=="number" and type(bottom)=="number" and type(top)=="number" then
                area=math.max(0,math.min(x+w,right)-math.max(x,left))*math.max(0,math.min(y+h,top)-math.max(y,bottom))
            end
            if cursorX and cursorX>=x-32 and cursorX<=x+w+32 and cursorY>=y-32 and cursorY<=y+h+32 then
                area=area+width*height+1
            end
            if area<bestArea then best,bestArea=index,area end
            if area==0 then break end
        end
        if self.corner~=best or self.screenWidth~=width or self.screenHeight~=height or force then
            self.corner,self.screenWidth,self.screenHeight=best,width,height
            frame:ClearAllPoints()
            local anchor=best==1 and "TOPRIGHT" or best==2 and "TOPLEFT" or best==3 and "BOTTOMRIGHT" or "BOTTOMLEFT"
            frame:SetPoint(anchor,UIParent,anchor,best%2==1 and -16/scale or 16/scale,best<=2 and -16/scale or 16/scale)
        end
    end
    function view:Show()
        self.expanded=false;self.copying=false;self:Update(nil,nil)
        frame:RegisterEvent("PLAYER_REGEN_DISABLED");frame:EnableKeyboard(true);frame:Show()
        frame:SetPropagateKeyboardInput(true)
        if UI.Motion then UI.Motion:Reveal(frame,"enter") end
    end
    function view:Hide()
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
