local I,UI=_G.LycheeInternal,_G.Lychee.UI
local L=I.Locale
local CLIENTS={retail="正式服",classic="经典怀旧服",titan="泰坦重铸",anniversary="周年纪念服"}
local P={};UI.ProviderSettings=P
function P:Create(parent,controller,onBack)
    local metrics=UI.Theme.Metrics
    local width=metrics.resultTileWidth-metrics.listInset
    local view={generation=0};local outer=CreateFrame("Frame",nil,parent);view.frame=outer
    outer:SetPoint("TOPLEFT",parent,"TOPLEFT",metrics.listInset,0)
    outer:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-metrics.listInset,2);outer:Hide()
    local scroll=CreateFrame("ScrollFrame",nil,outer)
    scroll:SetPoint("TOPLEFT",outer,"TOPLEFT",0,-32);scroll:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",0,48)
    local contentHeight=348
    local frame=CreateFrame("Frame",nil,scroll);frame:SetSize(width,contentHeight);scroll:SetScrollChild(frame)
    local bar
    bar=UI.Components:CreateScrollbar(scroll,function(value) bar.value=value;scroll:SetVerticalScroll(value) end)
    bar.frame:ClearAllPoints();bar.frame:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-32);bar.frame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,50)
    local function range() bar:SetRange(contentHeight,scroll:GetHeight(),bar.value);scroll:SetVerticalScroll(bar.value) end
    scroll:SetScript("OnSizeChanged",range)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    scroll:SetScript("OnMouseWheel",function(_,delta) if not InCombatLockdown() then bar:SetValue(bar.value-delta*52) end end)
    local function current()
        return outer:IsShown() and controller.visible and controller.settingsOpen and not InCombatLockdown()
            and view.entry and I.Providers.entries[view.id]==view.entry
    end
    local function label(value,x,y,w,style)
        local text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        UI.Theme:SetFont(text,style or "body");UI.Theme:SetTextColor(text,"textMuted")
        text:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y);text:SetSize(w or width,22);text:SetJustifyH("LEFT");text:SetText(value)
        return text
    end
    local function button(value,x,y,w,fn,container,height,navigation)
        local b
        container=container or frame
        b=UI.Components:CreateButton(container,{text=value,width=w,height=height or 28,radius=not navigation and 4 or nil,
            colors=navigation and {normal="transparent"} or {normal="transparent",hover="surfaceHover",pressed="surfaceSelected"},
            textColors={normal="textMuted",hover="text",pressed="text",disabled="disabled"},onClick=function()
            local pressed=b.press;b.press=nil
            if current() and (pressed==nil or pressed==view.generation) then fn() end
        end})
        local previous=b.frame.GetScript and b.frame:GetScript("OnMouseDown")
        b.frame:SetScript("OnMouseDown",function(...)
            b.press=view.generation;if previous then previous(...) end
        end)
        UI.Theme:SetFont(b.label,"body")
        b.frame:SetPoint("TOPLEFT",container,"TOPLEFT",x,y);return b
    end
    local function back() outer:Hide();onBack() end
    view.back=button(L["返回功能来源"],0,0,132,back,outer,28,true)
    view.back.label:ClearAllPoints();view.back.label:SetPoint("TOPLEFT",view.back.frame,"TOPLEFT",8,0)
    view.back.label:SetPoint("BOTTOMRIGHT",view.back.frame,"BOTTOMRIGHT",-8,0);view.back.label:SetJustifyH("LEFT")
    view.icon=frame:CreateTexture(nil,"ARTWORK");view.icon:SetSize(metrics.iconSize,metrics.iconSize);view.icon:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listIconInset,-10)
    view.title=label("",metrics.listTitleInset,-4,width-160);UI.Theme:SetTextColor(view.title,"text")
    view.detail=label("",metrics.listTitleInset,-24,width-160,"meta")
    view.toggle=UI.Components:CreateToggle(frame);view.toggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-14)
    view.state=label("",width-128,-12,80,"meta");view.state:SetJustifyH("RIGHT")
    view.toggle:SetScript("OnClick",function()
        local pressed=view.toggle.press;view.toggle.press=nil
        if not current() or pressed~=nil and pressed~=view.generation then return end
        local state=I.Registry.entries[view.id]
        local ok,err=I.Registry:SetUserEnabled(view.id,not state.userEnabled)
        if not ok then controller:ReportActionResult(false,err);return end
        controller:MarkHomeDirty();view.toggle:SetChecked(state.userEnabled)
        view.state:SetText(L[state.userEnabled and "已启用" or "已关闭"])
    end)
    view.toggle:SetScript("OnMouseDown",function() view.toggle.press=view.generation end)
    label(L["搜索方式"],8,-56)
    view.choices={}
    for index,choice in ipairs({{"default","跟随默认","使用此功能推荐的搜索方式"},{"global","全局搜索","直接输入关键词，也可使用前缀"},{"prefix","仅前缀搜索","输入前缀后才搜索此功能"}}) do
        local mode,title=choice[1],choice[2]
        local b=button(L[title],0,-80-(index-1)*44,width,function()
            view.mode=mode;view:PaintChoice();view:UpdateDirty()
        end,nil,40)
        b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b.frame,"TOPLEFT",16,-3);b.label:SetSize(width-32,18);b.label:SetJustifyH("LEFT")
        b.detail=b.frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");UI.Theme:SetFont(b.detail,"meta");UI.Theme:SetTextColor(b.detail,"textMuted")
        b.detail:SetPoint("TOPLEFT",b.frame,"TOPLEFT",16,-22);b.detail:SetSize(width-32,14);b.detail:SetJustifyH("LEFT");b.detail:SetText(L[choice[3]])
        b.mark=b.frame:CreateTexture(nil,"ARTWORK");b.mark:SetSize(metrics.selectionWidth,metrics.selectionHeight)
        b.mark:SetPoint("LEFT",b.frame,"LEFT",0,0);UI.Theme:SetColorTexture(b.mark,"accent");b.mark:Hide()
        local setState=b.SetState
        function b:SetState(state)
            local changed=setState(self,state)
            if self.enabled~=false and view.mode==mode then UI.Theme:SetTextColor(self.label,"text") end
            return changed
        end
        view.choices[mode]=b
    end
    view.help=label("",8,-84,width-16);view.help:SetHeight(40);view.help:Hide()
    view.prefixLabel=label(L["搜索前缀"],8,-220)
    local input=CreateFrame("EditBox",nil,frame);view.input=input
    input:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-248);input:SetSize(width-16,32)
    input:SetAutoFocus(false);input:SetTextInsets(10,10,0,0);UI.Theme:SetFont(input,"body");UI.Theme:SetTextColor(input,"text")
    if input.SetMaxBytes then input:SetMaxBytes(400) end
    UI.Theme:CreateRoundedSurface(input,"surfaceSelected",4)
    view.inputLine=input:CreateTexture(nil,"ARTWORK");view.inputLine:SetPoint("BOTTOMLEFT",input,"BOTTOMLEFT",4,0);view.inputLine:SetPoint("BOTTOMRIGHT",input,"BOTTOMRIGHT",-4,0);view.inputLine:SetHeight(1)
    UI.Theme:SetColorTexture(view.inputLine,"borderStrong");view.inputLine:Hide()
    input:SetScript("OnEditFocusGained",function() view.inputLine:Show() end)
    input:SetScript("OnEditFocusLost",function() view.inputLine:Hide() end)
    view.example=label("",8,-284,width-16,"meta")
    view.error=label("",8,-308,width-16,"meta");view.error:SetHeight(36);UI.Theme:SetTextColor(view.error,"warning")
    local function save()
        if not current() or not view.dirty or view.entry.definition.searchable==false then return end
        local raw=input:GetText();local list={}
        for value in raw:gsub("，",","):gmatch("[^,]+") do list[#list+1]=value end
        local mode=view.mode~="default" and view.mode or nil
        local original=table.concat(I.Search.ProviderPolicy:Defaults(view.id,view.entry.definition),", ")
        local custom=raw~=original and list or nil
        local ok,err=I.Search.ProviderPolicy:Set(view.id,mode,custom)
        if not ok then view.technical:Hide();view.error:SetText(L[err]);return end
        input:ClearFocus();view:Refresh();controller:SetStatusText(L["搜索设置已保存"])
    end
    view.save=button(L["保存"],0,0,80,save,outer,30)
    view.save.frame:ClearAllPoints();view.save.frame:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",-8,6)
    UI.Theme:CreateRoundedSurface(view.save.frame,"surfaceSelected",4)
    view.cancel=button(L["取消"],0,0,72,back,outer,30)
    view.cancel.frame:ClearAllPoints();view.cancel.frame:SetPoint("RIGHT",view.save.frame,"LEFT",-8,0)
    view.reset=button(L["恢复默认"],0,0,120,function()
        view.mode="default"
        input:SetText(table.concat(I.Search.ProviderPolicy:Defaults(view.id,view.entry.definition),", "))
        view:PaintChoice();view:UpdateDirty()
    end,outer,30)
    view.reset.frame:ClearAllPoints();view.reset.frame:SetPoint("BOTTOMLEFT",outer,"BOTTOMLEFT",0,6)
    view.technical=label("",8,-308,width-16,"meta");view.technical:SetHeight(36)
    input:SetScript("OnEnterPressed",save)
    input:SetScript("OnEscapePressed",function() if current() then input:ClearFocus();outer:Hide();onBack() end end)
    function view:UpdateExample()
        local prefix=""
        for value in input:GetText():gsub("，",","):gmatch("[^,]+") do
            value=value:match("^%s*(.-)%s*$")
            if prefix=="" then prefix=value end
            if L:IsChinese() and value:find("[\128-\255]") then prefix=value;break end
        end
        self.example:SetText(L["多个前缀用逗号分隔"]..(prefix~="" and " · "..L:Format("搜索示例：%s：关键词",prefix) or ""))
    end
    input:SetScript("OnTextChanged",function(_,userInput)
        if userInput then view:UpdateDirty() end
        view:UpdateExample()
    end)
    function view:PaintChoice()
        for mode,control in pairs(self.choices) do control.mark:SetShown(mode==self.mode);UI.Theme:SetTextColor(control.label,mode==self.mode and "text" or "textMuted") end
    end
    function view:UpdateDirty()
        if not current() then return end
        self.dirty=self.mode~=self.savedMode or input:GetText()~=self.savedText
        self.save:SetEnabled(self.dirty and self.entry.definition.searchable~=false)
        self.error:SetText("");self.technical:Show()
        self:UpdateExample()
        controller:SetStatusText(L[self.dirty and "点击保存应用搜索设置" or "搜索设置已保存"])
    end
    function view:Refresh()
        if not current() then return end
        local policy=I.Search.ProviderPolicy;local definition=self.entry.definition
        local state=I.Registry.entries[self.id];self.toggle:SetChecked(state.userEnabled,true)
        self.state:SetText(L[state.userEnabled and "已启用" or "已关闭"])
        local row=policy:Override(self.id);local effective,list=policy:Effective(self.id,definition)
        self.mode=row and row.mode or "default"
        local independent=definition.searchable==false
        local desiredHeight=independent and 176 or 348
        if contentHeight~=desiredHeight then contentHeight=desiredHeight;frame:SetHeight(contentHeight);range() end
        self.technical:ClearAllPoints();self.technical:SetPoint("TOPLEFT",frame,"TOPLEFT",8,independent and -132 or -308)
        self.help:SetText(L["独立查询入口，由功能自身决定触发词"]);self.help:SetShown(independent)
        self.choices.default.detail:SetText(L["使用此功能推荐的搜索方式"].." · "..L[definition.searchMode=="prefix" and "仅前缀搜索" or "全局搜索"])
        for _,b in pairs(self.choices) do b:SetEnabled(not independent);b.frame:SetShown(not independent) end
        self.save:SetEnabled(false);self.reset:SetEnabled(not independent)
        self.prefixLabel:SetShown(not independent);input:SetShown(not independent);self.example:SetShown(not independent)
        input:SetText(table.concat(list,", "));input:ClearFocus();input:EnableMouse(not independent)
        if input.EnableKeyboard then input:EnableKeyboard(not independent) end
        if independent then input:SetText("") end
        self.savedMode,self.savedText,self.dirty=self.mode,input:GetText(),false
        self:UpdateExample()
        self.error:SetText("");self.technical:Show();self:PaintChoice()
        local clients={}
        for _,product in ipairs(definition.scope.products or {definition.scope.product or "retail"}) do clients[#clients+1]=L[CLIENTS[product] or product] end
        self.technical:SetText(L["版本"].." "..tostring(definition.version).."  ·  "..table.concat(clients,", "))
    end
    function view:Show(id,icon,description)
        self.id,self.entry=id,I.Providers.entries[id]
        self.generation=self.generation+1;outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon);self.title:SetText(self.entry.definition.title);self.detail:SetText(description or "");self:Refresh()
        controller:SetStatusText(L["开关即时生效，搜索设置需保存"])
    end
    outer:SetScript("OnHide",function()
        input:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.entry=nil,nil
    end)
    return view
end
