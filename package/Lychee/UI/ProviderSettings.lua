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
    local contentHeight=392
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
    view.globalLabel=label(L["参与普通搜索"],8,-56,width-70)
    view.globalHint=label(L["按内容名称搜索时显示此来源"],8,-78,width-70,"meta")
    view.globalToggle=UI.Components:CreateToggle(frame);view.globalToggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-62)
    view.globalToggle:SetScript("OnMouseDown",function() view.globalToggle.press=view.generation end)
    view.globalToggle:SetScript("OnClick",function()
        local pressed=view.globalToggle.press;view.globalToggle.press=nil
        if not current() or view.entry.definition.searchable==false or pressed~=nil and pressed~=view.generation then return end
        view.global=not view.global;view.globalToggle:SetChecked(view.global);view:UpdateDirty()
    end)
    view.heading=label(L["快捷入口"],8,-112)
    view.fields={}
    for _,spec in ipairs({{"keyword","直接打开列表",136},{"prefix","在此来源内搜索",228}}) do
        local kind,title,y=spec[1],spec[2],spec[3]
        local field={};view.fields[kind]=field
        field.label=label(L[title],8,-y,width-16)
        local input=CreateFrame("EditBox",nil,frame);field.input=input
        input:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-y-24);input:SetSize(width-16,32)
        input:SetAutoFocus(false);input:SetTextInsets(10,10,0,0);UI.Theme:SetFont(input,"body");UI.Theme:SetTextColor(input,"text")
        if input.SetMaxBytes then input:SetMaxBytes(400) end
        UI.Theme:CreateRoundedSurface(input,"surfaceSelected",4)
        local line=input:CreateTexture(nil,"ARTWORK");field.line=line
        line:SetPoint("BOTTOMLEFT",input,"BOTTOMLEFT",4,0);line:SetPoint("BOTTOMRIGHT",input,"BOTTOMRIGHT",-4,0);line:SetHeight(1)
        UI.Theme:SetColorTexture(line,"borderStrong");line:Hide()
        input:SetScript("OnEditFocusGained",function() line:Show() end)
        input:SetScript("OnEditFocusLost",function() line:Hide() end)
        field.example=label("",8,-y-60,width-16,"meta")
        input:SetScript("OnTextChanged",function(_,userInput) if userInput then view:UpdateDirty() end;view:UpdateExamples() end)
        input:SetScript("OnEnterPressed",function() view:Save() end)
        input:SetScript("OnEscapePressed",function() if current() then input:ClearFocus();back() end end)
    end
    view.prefixInput=view.fields.prefix.input;view.keywordInput=view.fields.keyword.input
    view.help=label(L["独立查询入口，由功能自身决定触发词"],8,-64,width-16);view.help:SetHeight(44);view.help:Hide()
    view.error=label("",8,-316,width-16,"meta");view.error:SetHeight(36);UI.Theme:SetTextColor(view.error,"warning")
    view.technical=label("",8,-316,width-16,"meta");view.technical:SetHeight(36)
    function view:ClearFocus()
        for _,field in pairs(self.fields) do field.input:ClearFocus();field.line:Hide() end
    end
    function view:UpdateExamples()
        for kind,field in pairs(self.fields) do
            local word=""
            for value in field.input:GetText():gsub("，",","):gmatch("[^,]+") do
                value=value:match("^%s*(.-)%s*$")
                if word=="" then word=value end
                if L:IsChinese() and value:find("[\128-\255]") then word=value;break end
            end
            field.example:SetText(word=="" and L["未设置 · 填写名称，多个名称用逗号分隔"] or L:Format(kind=="keyword" and "输入 %s → 显示此来源列表" or "输入 %s：内容 → 搜索此来源",word))
        end
    end
    function view:UpdateDirty()
        if not current() then return end
        self.resetDraft=false
        self.dirty=self.global~=self.savedGlobal or self.prefixInput:GetText()~=self.savedPrefix or self.keywordInput:GetText()~=self.savedKeyword
        self.save:SetEnabled(self.dirty and self.entry.definition.searchable~=false)
        self.error:SetText("");self.technical:Show()
        controller:SetStatusText(L[self.dirty and "点击保存应用搜索设置" or "搜索设置已保存"])
    end
    function view:Save()
        if not current() or not self.dirty or self.entry.definition.searchable==false then return end
        local function values(input)
            local list={}
            for value in input:GetText():gsub("，",","):gmatch("[^,]+") do
                if value:find("%S") then list[#list+1]=value end
            end
            return list
        end
        local ok,err
        if self.resetDraft then ok,err=I.Search.ProviderPolicy:Set(self.id,nil,nil,nil)
        else ok,err=I.Search.ProviderPolicy:SetConfiguration(self.id,self.global,values(self.prefixInput),values(self.keywordInput)) end
        if not ok then self.technical:Hide();self.error:SetText(L[err]);return end
        self:ClearFocus();self:Refresh();controller:SetStatusText(L["搜索设置已保存"])
    end
    view.save=button(L["保存"],0,0,72,function() view:Save() end,outer,30,true)
    view.save.frame:ClearAllPoints();view.save.frame:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",-8,6)
    view.cancel=button(L["取消"],0,0,72,back,outer,30,true)
    view.cancel.frame:ClearAllPoints();view.cancel.frame:SetPoint("RIGHT",view.save.frame,"LEFT",-8,0)
    view.reset=button(L["恢复默认"],0,0,120,function()
        local global,list,words=I.Search.ProviderPolicy:Configuration(view.id,view.entry.definition,true)
        view.global=global;view.globalToggle:SetChecked(global)
        view.prefixInput:SetText(table.concat(list,", "));view.keywordInput:SetText(table.concat(words,", "))
        view:UpdateExamples();view:UpdateDirty()
        view.resetDraft=true;view.dirty=view.dirty or I.Search.ProviderPolicy:Override(view.id)~=nil;view.save:SetEnabled(view.dirty)
        if view.dirty then controller:SetStatusText(L["点击保存应用搜索设置"]) end
    end,outer,30,true)
    view.reset.frame:ClearAllPoints();view.reset.frame:SetPoint("BOTTOMLEFT",outer,"BOTTOMLEFT",0,6)
    function view:Refresh()
        if not current() then return end
        local definition=self.entry.definition;local independent=definition.searchable==false
        local state=I.Registry.entries[self.id];self.toggle:SetChecked(state.userEnabled,true)
        self.state:SetText(L[state.userEnabled and "已启用" or "已关闭"])
        local global,list,words=I.Search.ProviderPolicy:Configuration(self.id,definition)
        self.global,self.savedGlobal=global,global
        self.savedPrefix,self.savedKeyword=table.concat(list,", "),table.concat(words,", ")
        self.globalToggle:SetChecked(global,true);self.globalToggle:SetShown(not independent)
        self.globalLabel:SetShown(not independent);self.globalHint:SetShown(not independent);self.heading:SetShown(not independent)
        self.help:SetShown(independent)
        for kind,field in pairs(self.fields) do
            field.label:SetShown(not independent);field.input:SetShown(not independent);field.example:SetShown(not independent)
            field.input:EnableMouse(not independent);if field.input.EnableKeyboard then field.input:EnableKeyboard(not independent) end
            field.input:SetText(kind=="prefix" and self.savedPrefix or self.savedKeyword)
        end
        self:ClearFocus();self:UpdateExamples();self.resetDraft,self.dirty=false,false
        self.save:SetEnabled(false);self.reset:SetEnabled(not independent)
        local desiredHeight=independent and 160 or 352
        if contentHeight~=desiredHeight then contentHeight=desiredHeight;frame:SetHeight(contentHeight);range() end
        self.technical:ClearAllPoints();self.technical:SetPoint("TOPLEFT",frame,"TOPLEFT",8,independent and -120 or -316)
        self.error:SetText("");self.technical:Show()
        local clients={}
        for _,product in ipairs(definition.scope.products or {definition.scope.product or "retail"}) do clients[#clients+1]=L[CLIENTS[product] or product] end
        self.technical:SetText(L["版本"].." "..tostring(definition.version).."  ·  "..table.concat(clients,", "))
    end
    function view:Show(id,icon,description)
        self.id,self.entry=id,I.Providers.entries[id]
        self.generation=self.generation+1;outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon);self.title:SetText(self.entry.definition.title);self.detail:SetText(description or "");self:Refresh()
        controller:SetStatusText(L["来源启停即时生效，其余设置保存后生效"])
    end
    outer:SetScript("OnHide",function()
        view:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.entry=nil,nil
    end)
    return view
end
