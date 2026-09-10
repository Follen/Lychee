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
    local function button(value,x,y,w,fn,container,height,navigation,primary)
        local b
        container=container or frame
        b=UI.Components:CreateButton(container,{text=value,width=w,height=height or 28,radius=not navigation and 4 or nil,
            colors=navigation and {normal="transparent"} or {normal="transparent",hover="surfaceHover",pressed="surfaceSelected"},
            textColors={normal=primary and "text" or "textMuted",hover="text",pressed="text",disabled="disabled"},onClick=function()
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
    local policy=I.Search.ProviderPolicy
    view.globalLabel=label(L["直接搜索名称"],8,-68,width-88);UI.Theme:SetTextColor(view.globalLabel,"text")
    view.globalHint=label("",8,-92,width-16,"meta")
    view.globalToggle=UI.Components:CreateToggle(frame);view.globalToggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-70)
    view.globalToggle:SetScript("OnMouseDown",function() view.globalToggle.press=view.generation end)
    view.globalToggle:SetScript("OnClick",function()
        local pressed=view.globalToggle.press;view.globalToggle.press=nil
        if not current() or view.entry.definition.searchable==false or pressed~=nil and pressed~=view.generation then return end
        local global,prefixes,keywords=policy:Configuration(view.id,view.entry.definition)
        local ok,err=policy:SetConfiguration(view.id,not global,prefixes,keywords)
        if not ok then view:Failure(err);view.globalToggle:SetChecked(global);return end
        view.global=not global;view.globalToggle:SetChecked(view.global);view:UpdateExamples()
        view.error:SetText("");view:Layout();controller:SetStatusText(L["更改即时生效"])
    end)
    view.fields={}
    for _,kind in ipairs({"prefix","keyword"}) do
        local field={};view.fields[kind]=field
        field.label=label(L[kind=="prefix" and "限定搜索范围" or "一词查看结果"],8,0,width-200)
        UI.Theme:SetTextColor(field.label,"text")
        field.hint=label(L[kind=="prefix" and "只在此功能中查找匹配名称" or "完整输入设定词，无需指定内容名称"],8,0,width-16,"meta")
        field.caption=label(L["输入示例"],8,0,76,"meta")
        field.summary=label("",88,0,width-104,"body");UI.Theme:SetTextColor(field.summary,"text")
        field.state=label(L["未设置"],width-164,0,76,"meta");field.state:SetJustifyH("RIGHT")
        field.edit=button(L["修改"],width-80,0,72,function() view:BeginEdit(kind) end,nil,28,true)
        local input=CreateFrame("EditBox",nil,frame);field.input=input
        input:SetSize(width-16,32);input:SetAutoFocus(false);input:SetTextInsets(10,10,0,0)
        UI.Theme:SetFont(input,"body");UI.Theme:SetTextColor(input,"text");if input.SetMaxBytes then input:SetMaxBytes(400) end
        UI.Theme:CreateRoundedSurface(input,"surfaceSelected",4)
        field.example=label(L["多个词用逗号分隔；清空可移除此入口"],8,0,width-170,"meta");field.example:SetHeight(36)
        field.save=button(L["保存"],0,0,64,function() if view.editing==kind then view:Save() end end,nil,28,true,true)
        field.cancel=button(L["取消"],0,0,64,function() if view.editing==kind then view:CancelEdit() end end,nil,28,true)
        input:SetScript("OnTextChanged",function(_,userInput) if userInput and current() and view.editing==kind then
            view.error:SetText("");view:Layout()
        end end)
        input:SetScript("OnEnterPressed",function() if view.editing==kind then view:Save() end end)
        input:SetScript("OnEscapePressed",function() if current() and view.editing==kind then view:CancelEdit() end end)
    end
    view.prefixInput=view.fields.prefix.input;view.keywordInput=view.fields.keyword.input
    view.help=label(L["独立查询入口，由功能自身决定触发词"],8,-68,width-16);view.help:SetHeight(44)
    view.error=label("",8,0,width-16,"meta");view.error:SetHeight(36);UI.Theme:SetTextColor(view.error,"warning")
    view.technical=label("",8,0,width-16,"meta");view.technical:SetHeight(36)
    function view:ClearFocus() for _,field in pairs(self.fields) do field.input:ClearFocus() end end
    function view:CancelEdit()
        if not current() then return end
        self:ClearFocus();self.editing=nil;self.generation=self.generation+1
        self.error:SetText("");self:Layout();controller:SetStatusText(L["更改即时生效"])
    end
    function view:BeginEdit(kind)
        if self.editing or self.entry.definition.searchable==false then return end
        local _,prefixes,keywords=policy:Configuration(self.id,self.entry.definition)
        self.editing=kind;self.generation=self.generation+1
        local field=self.fields[kind];field.before=table.concat(kind=="prefix" and prefixes or keywords,", ")
        field.input:SetText(field.before)
        self.error:SetText("");self:Layout();self.fields[kind].input:SetFocus()
        controller:SetStatusText(L["Enter 保存 · Esc 取消编辑"])
    end
    local function representative(words)
        local word=words[1]
        if L:IsChinese() then for _,value in ipairs(words) do if value:find("[\128-\255]") then return value end end end
        return word
    end
    function view:UpdateExamples()
        local global,prefixes,keywords=policy:Configuration(self.id,self.entry.definition)
        self.global=global
        self.globalHint:SetText(L["在普通搜索结果中包含此功能"])
        for kind,field in pairs(self.fields) do
            local words=kind=="prefix" and prefixes or keywords
            local word=representative(words);field.count=#words
            field.edit:SetText(L[word and "修改" or "设置入口"])
            local example=word and (kind=="prefix" and word..(L:IsChinese() and "：" or ": ")..self.sample or word)
            field.summary:SetText(example or "")
        end
    end
    function view:Layout()
        local independent=self.entry.definition.searchable==false
        local hasError=self.error:GetText()~=""
        local key=tostring(independent)..":"..tostring(self.editing)..":"..tostring(self.aboutOpen)..":"..tostring(hasError)
            ..":"..tostring(self.fields.prefix.count>0)..":"..tostring(self.fields.keyword.count>0)
        if self.layoutKey==key then return end
        self.layoutKey=key
        local y=136;local errorY=116
        for _,kind in ipairs({"prefix","keyword"}) do
            local field=self.fields[kind];local editing=self.editing==kind and not independent
            local function at(region,x,offset) region:ClearAllPoints();region:SetPoint("TOPLEFT",frame,"TOPLEFT",x,-y-offset) end
            at(field.label,8,0);field.label:SetShown(not independent)
            at(field.hint,8,24);field.hint:SetShown(not independent)
            at(field.edit.frame,width-80,0);field.edit.frame:SetShown(not independent and not editing)
            field.edit:SetEnabled(self.editing==nil)
            local hasExample=not independent and not editing and field.count>0
            at(field.caption,8,48);field.caption:SetShown(hasExample)
            at(field.summary,88,48);field.summary:SetShown(hasExample)
            at(field.state,width-164,3);field.state:SetShown(not independent and not editing and field.count==0)
            at(field.input,8,50);field.input:SetShown(editing)
            at(field.example,8,90);field.example:SetShown(editing)
            at(field.cancel.frame,width-144,86);field.cancel.frame:SetShown(editing)
            at(field.save.frame,width-72,86);field.save.frame:SetShown(editing)
            if editing then errorY=y+122 end
            y=y+(editing and (hasError and 174 or 138) or 96)
        end
        if not self.editing then errorY=independent and 116 or y end
        self.error:ClearAllPoints();self.error:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-errorY);self.error:SetShown(hasError)
        if hasError and not self.editing then y=y+40 end
        local aboutY=independent and 128 or y+4
        self.about.frame:ClearAllPoints();self.about.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-aboutY)
        self.about:SetText(L[self.aboutOpen and "收起版本信息" or "版本与兼容性"])
        self.technical:ClearAllPoints();self.technical:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-aboutY-30)
        self.technical:SetShown(self.aboutOpen==true)
        local height=aboutY+(self.aboutOpen and 72 or 38)
        if contentHeight~=height then contentHeight=height;frame:SetHeight(height);range() end
    end
    function view:Failure(err)
        self.error:SetText(L[err]);self:Layout();controller:SetStatusText(L[err])
    end
    function view:Save()
        if not current() or not self.editing or self.entry.definition.searchable==false then return end
        local kind=self.editing;local list={}
        if self.fields[kind].input:GetText()==self.fields[kind].before then self:CancelEdit();return end
        for value in self.fields[kind].input:GetText():gsub("，",","):gmatch("[^,]+") do
            if value:find("%S") then list[#list+1]=value end
        end
        -- Read committed siblings at save time: a toggle may have changed while editing.
        local global,prefixes,keywords=policy:Configuration(self.id,self.entry.definition)
        local ok,err=policy:SetConfiguration(self.id,global,kind=="prefix" and list or prefixes,kind=="keyword" and list or keywords)
        if not ok then self:Failure(err);return end
        self:CancelEdit();self:UpdateExamples();self:Layout();controller:SetStatusText(L["搜索设置已保存"])
    end
    view.reset=button(L["恢复默认"],0,0,120,function()
        if view.entry.definition.searchable==false then return end
        local ok,err=policy:Set(view.id,nil,nil,nil)
        if not ok then view:Failure(err);return end
        view.generation=view.generation+1;view:Refresh();controller:SetStatusText(L["已恢复默认搜索设置"])
    end,outer,30,true)
    view.reset.frame:ClearAllPoints();view.reset.frame:SetPoint("BOTTOMLEFT",outer,"BOTTOMLEFT",0,6)
    view.about=button(L["版本与兼容性"],0,0,200,function() view.aboutOpen=not view.aboutOpen;view:Layout() end,nil,28,true)
    view.about.label:ClearAllPoints();view.about.label:SetPoint("LEFT",view.about.frame,"LEFT",8,0);view.about.label:SetSize(184,24);view.about.label:SetJustifyH("LEFT")
    function view:Refresh()
        if not current() then return end
        self:ClearFocus();self.layoutKey=nil;self.editing=nil
        local definition=self.entry.definition;local independent=definition.searchable==false
        local state=I.Registry.entries[self.id];self.toggle:SetChecked(state.userEnabled,true)
        self.state:SetText(L[state.userEnabled and "已启用" or "已关闭"])
        self:UpdateExamples();self.globalToggle:SetChecked(self.global,true);self.globalToggle:SetShown(not independent)
        self.globalLabel:SetShown(not independent);self.globalHint:SetShown(not independent);self.help:SetShown(independent)
        self.reset:SetEnabled(not independent);self.error:SetText("")
        local clients={}
        for _,product in ipairs(definition.scope.products or {definition.scope.product or "retail"}) do clients[#clients+1]=L[CLIENTS[product] or product] end
        self.technical:SetText(L["版本"].." "..tostring(definition.version).."  ·  "..table.concat(clients,", "));self:Layout()
    end
    function view:Show(id,icon,description)
        self.id,self.entry=id,I.Providers.entries[id]
        local first=self.entry.records and self.entry.records[1]
        self.sample=first and type(first.title)=="string" and #first.title<=42 and not first.title:find("|",1,true) and first.title or L["名称"]
        self.aboutOpen=false
        self.generation=self.generation+1;outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon);self.title:SetText(self.entry.definition.title);self.detail:SetText(description or "");self:Refresh()
        controller:SetStatusText(L["更改即时生效"])
    end
    outer:SetScript("OnHide",function()
        view:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.entry=nil,nil
    end)
    return view
end
