local UI,L=_G.Lychee.UI,_G.LycheeInternal.Locale
local Social={}
UI.SocialLinks=Social
local media="Interface\\AddOns\\Lychee\\Media\\About\\"

function Social:Create(owner,controller)
    local bar=CreateFrame("Frame",nil,UIParent)
    bar:SetSize(100,28);bar:SetPoint("RIGHT",controller.footer,"RIGHT",-UI.Theme.Metrics.footerInset,0);bar:Hide()
    local view={frame=bar,buttons={}}
    function view:Close()
        if not self.backdrop or not self.backdrop:IsShown() then return false end
        self.input:ClearFocus();self.input:SetText("");self.code:SetTexture(nil)
        UI.Motion:Cancel(self.backdrop,true);UI.Motion:Cancel(self.popup,true)
        self.backdrop:Hide();self.active=nil
        return true
    end
    function view:Open(entry,anchor)
        if not controller.visible or not controller.settingsOpen or not owner:IsShown() or InCombatLockdown() then return end
        if self.active==entry then self:Close();return end
        self:Close();UI.Components:HideTooltip()
        if not self.popup then
            local backdrop=CreateFrame("Button",nil,UIParent);self.backdrop=backdrop
            backdrop:SetAllPoints(UIParent);backdrop:SetFrameStrata("DIALOG")
            backdrop:SetFrameLevel(controller.frame:GetFrameLevel()+30)
            local shade=backdrop:CreateTexture(nil,"BACKGROUND");shade:SetAllPoints();shade:SetColorTexture(0,0,0,0.2)
            backdrop:SetScript("OnClick",function() view:Close() end)
            local popup=CreateFrame("Frame",nil,backdrop);self.popup=popup
            popup:EnableMouse(true);popup:SetClampedToScreen(true)
            UI.Theme:CreateRoundedSurface(popup,"window",10)
            local title=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");self.title=title
            UI.Theme:SetFont(title,"body");UI.Theme:SetTextColor(title,"text")
            title:SetPoint("TOPLEFT",popup,"TOPLEFT",16,-12);title:SetJustifyH("LEFT")
            local close=UI.Components:CreateNavigationButton(popup,{width=24,height=24,direction="left",onClick=function() view:Close() end})
            close.frame:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-8,-6)
            local hint=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");self.hint=hint
            UI.Theme:SetFont(hint,"meta");UI.Theme:SetTextColor(hint,"textMuted")
            hint:SetPoint("BOTTOM",popup,"BOTTOM",0,12)
            local input=CreateFrame("EditBox",nil,popup);self.input=input
            input:SetAutoFocus(false);input:SetHeight(28);input:SetTextInsets(8,8,0,0)
            input:SetPoint("TOPLEFT",popup,"TOPLEFT",16,-38);input:SetPoint("RIGHT",popup,"RIGHT",-16,0)
            UI.Components:StyleEditBox(input);UI.Theme:SetFont(input,"body");UI.Theme:SetTextColor(input,"text")
            input:SetScript("OnMouseUp",function(box) box:HighlightText() end)
            input:SetScript("OnEscapePressed",function() view:Close() end)
            input:HookScript("OnHide",function(box) box:ClearFocus() end)
            local code=popup:CreateTexture(nil,"ARTWORK");self.code=code
            code:SetSize(176,176);code:SetPoint("TOP",popup,"TOP",0,-40)
        end
        self.active=entry
        self.popup:SetScale(controller.frame:GetEffectiveScale()/UIParent:GetEffectiveScale())
        self.popup:SetSize(entry.code and 208 or 316,entry.code and 252 or 100)
        self.popup:ClearAllPoints();self.popup:SetPoint("BOTTOMRIGHT",bar,"TOPRIGHT",0,8)
        self.title:SetText(entry.title);self.title:SetWidth(entry.code and 156 or 264)
        self.hint:SetText(entry.code and L["使用微信扫一扫"] or L["Ctrl+C 复制 · Esc 退出"])
        self.input:SetShown(not entry.code);self.code:SetShown(entry.code~=nil)
        if entry.code then self.code:SetTexture(media..entry.code..".tga") else self.input:SetText(entry.url) end
        self.backdrop:SetAlpha(0);self.backdrop:Show();UI.Motion:Alpha(self.backdrop,1,0.14);UI.Motion:Reveal(self.popup,"page")
        if not entry.code then self.input:SetFocus();self.input:HighlightText() end
    end
    local entries=L:IsChinese() and {
        {icon="support",title=L["微信赞赏"],code="wechat-support"},
        {icon="github",title="GitHub",url="https://github.com/Follen/Lychee"},
        {icon="wechat",title=L["作者微信"],code="wechat-contact"},
    } or {
        {icon="paypal",title="PayPal",url="https://www.paypal.me/follenfang"},
        {icon="github",title="GitHub",url="https://github.com/Follen/Lychee"},
        {icon="x",title="X · @follenfang",url="https://x.com/follenfang"},
    }
    for index,entry in ipairs(entries) do
        local button=UI.Components:CreateNavigationButton(bar,{width=28,height=28,onClick=function(self) view:Open(entry,self) end})
        button.frame:SetPoint("LEFT",bar,"LEFT",(index-1)*36,0)
        local icon=button.frame:CreateTexture(nil,"ARTWORK");icon:SetSize(18,18);icon:SetPoint("CENTER")
        icon:SetTexture(media..entry.icon..".tga");button.feedbackIcon=icon;UI.Theme:SetVertexColor(icon,"textMuted")
        button.frame:HookScript("OnLeave",function() UI.Theme:SetVertexColor(icon,"textMuted") end)
        view.buttons[index]=button
    end
    owner:HookScript("OnHide",function() view:Close();bar:Hide() end)
    function view:Show()
        for _,button in ipairs(self.buttons) do UI.Theme:SetVertexColor(button.feedbackIcon,"textMuted") end
        bar:SetScale(controller.frame:GetEffectiveScale()/UIParent:GetEffectiveScale())
        bar:SetFrameStrata("DIALOG");bar:SetFrameLevel(controller.frame:GetFrameLevel()+10);bar:Show()
    end
    return view
end
