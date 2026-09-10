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
    view.globalLabel=label(L["普通搜索"],8,-56,width-70)
    view.globalHint=label(L["按内容名称搜索时显示此来源"],8,-78,width-70,"meta")
    view.globalToggle=UI.Components:CreateToggle(frame);view.globalToggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-62)
    view.globalToggle:SetScript("OnMouseDown",function() view.globalToggle.press=view.generation end)
    view.globalToggle:SetScript("OnClick",function()
        local pressed=view.globalToggle.press;view.globalToggle.press=nil
        if not current() or view.entry.definition.searchable==false or pressed~=nil and pressed~=view.generation then return end
        view.global=not view.global;view.globalToggle:SetChecked(view.global);view.globalHint:SetText(L[view.global and "直接输入名称即可搜索" or "通过下面的快捷入口查找"]);view:UpdateDirty()
    end)
    view.heading=label(L["快捷搜索"],8,-112)
    view.fields={}
    for _,spec in ipairs({{"keyword","直接打开列表",136},{"prefix","在此来源内搜索",228}}) do
        local kind,title,y=spec[1],spec[2],spec[3]
        local field={};view.fields[kind]=field
        field.label=label(L[title],8,-y,width-110)
        field.summary=label("",8,-y-22,width-110,"body");UI.Theme:SetTextColor(field.summary,"text")
        field.edit=button(L["修改"],width-88,-y,80,function()
            if view.editing==kind then
                field.input:SetText(field.before or "");view.editing=nil;view:UpdateDirty();view:Layout()
            else
                view:ClearFocus();view.editing=kind;field.before=field.input:GetText();view:Layout();field.input:SetFocus()
            end
        end,nil,28,true)
        field.add=button("",0,-y,width,function()
            view:ClearFocus();view.editing=kind;field.before=field.input:GetText();view:Layout();field.input:SetFocus()
        end,nil,32,true)
        field.add.label:SetJustifyH("LEFT");field.add.label:ClearAllPoints();field.add.label:SetPoint("LEFT",field.add.frame,"LEFT",8,0);field.add.label:SetSize(width-16,24)
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
        input:SetScript("OnEscapePressed",function() if current() then input:SetText(field.before or "");view.editing=nil;view:UpdateDirty();view:Layout() end end)
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
            local word="";local count=0
            for value in field.input:GetText():gsub("，",","):gmatch("[^,]+") do
                value=value:match("^%s*(.-)%s*$")
                if value~="" then
                    count=count+1
                    if word=="" or L:IsChinese() and not word:find("[\128-\255]") and value:find("[\128-\255]") then word=value end
                end
            end
            field.word,field.count=word,count
            local example=kind=="keyword" and word or word.."："..(self.sample or L["名称"])
            field.summary:SetText(L:Format("搜索 %s",example)..(count>1 and L:Format(" · 另有 %d 个入口",count-1) or ""))
            field.example:SetText(word=="" and L["填写你想输入的词，多个词用逗号分隔"] or L:Format(kind=="keyword" and "搜索 %s，显示列表" or "搜索 %s，只查找此功能",example))
        end
    end
    function view:Layout()
        local independent=self.entry.definition.searchable==false
        local key=tostring(independent)..":"..tostring(self.editing)..":"..tostring(self.fields.prefix.count>0)..":"..tostring(self.fields.keyword.count>0)..":"..tostring(self.aboutOpen)..":"..tostring(self.dirty)..":"..tostring(self.error:GetText()~="")
        if self.layoutKey==key then return end
        self.layoutKey=key
        local y=128
        for _,kind in ipairs({"prefix","keyword"}) do
            local field=self.fields[kind];local editing=self.editing==kind and not independent
            local exists=field.count>0
            field.add:SetText(L:Format(kind=="keyword" and "添加打开%s列表的关键词" or "添加只搜索%s的前缀",self.entry.definition.title))
            field.add.frame:ClearAllPoints();field.add.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-y)
            field.add.frame:SetShown(not independent and not exists and not editing)
            field.label:ClearAllPoints();field.label:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-y)
            field.label:SetText(L:Format(kind=="keyword" and "打开%s列表" or "只搜索%s",self.entry.definition.title))
            field.label:SetShown(not independent and (exists or editing))
            field.edit.frame:ClearAllPoints();field.edit.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",width-88,-y)
            field.edit:SetText(L[editing and "取消编辑" or "修改"]);field.edit.frame:SetShown(not independent and (exists or editing))
            field.summary:ClearAllPoints();field.summary:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-y-24)
            field.summary:SetShown(not independent and exists and not editing)
            field.input:ClearAllPoints();field.input:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-y-28);field.input:SetShown(editing)
            field.example:ClearAllPoints();field.example:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-y-64);field.example:SetShown(editing)
            y=y+(editing and 108 or exists and 68 or 44)
        end
        self.about.frame:ClearAllPoints();self.about.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-(independent and 116 or y+12))
        self.about:SetText(L[self.aboutOpen and "收起功能信息" or "关于此功能"])
        self.technical:ClearAllPoints();self.technical:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-(independent and 148 or y+44))
        self.technical:SetShown(self.aboutOpen==true)
        local errorY=independent and 180 or y+44+(self.aboutOpen and 36 or 0)
        self.error:ClearAllPoints();self.error:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-errorY)
        local height=errorY+(self.error:GetText()~="" and 40 or 8)
        if contentHeight~=height then contentHeight=height;frame:SetHeight(height);range() end
        self.save.frame:SetShown(not independent and (self.dirty or self.editing~=nil))
        self.cancel.frame:SetShown(not independent and (self.dirty or self.editing~=nil))
    end
    function view:UpdateDirty()
        if not current() then return end
        local hint=L[self.global and "直接输入名称即可搜索" or "通过下面的快捷入口查找"]
        if self.globalHint:GetText()~=hint then self.globalHint:SetText(hint) end
        self.resetDraft=false
        self.dirty=self.global~=self.savedGlobal or self.prefixInput:GetText()~=self.savedPrefix or self.keywordInput:GetText()~=self.savedKeyword
        self.save:SetEnabled(self.dirty and self.entry.definition.searchable~=false)
        self.error:SetText("");self:UpdateExamples();self:Layout()
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
        if not ok then
            self.error:SetText(L[err]);self:Layout();controller:SetStatusText(L[err])
            bar:SetValue(math.max(0,contentHeight-scroll:GetHeight()));return
        end
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
        view.editing=nil;view:Layout()
        if view.dirty then controller:SetStatusText(L["点击保存应用搜索设置"]) end
    end,outer,30,true)
    view.reset.frame:ClearAllPoints();view.reset.frame:SetPoint("BOTTOMLEFT",outer,"BOTTOMLEFT",0,6)
    view.about=button(L["关于此功能"],0,0,160,function() view.aboutOpen=not view.aboutOpen;view:Layout() end,nil,28,true)
    view.about.label:SetJustifyH("LEFT")
    function view:Refresh()
        if not current() then return end
        self.layoutKey=nil
        local definition=self.entry.definition;local independent=definition.searchable==false
        local state=I.Registry.entries[self.id];self.toggle:SetChecked(state.userEnabled,true)
        self.state:SetText(L[state.userEnabled and "已启用" or "已关闭"])
        self.editing=nil
        local global,list,words=I.Search.ProviderPolicy:Configuration(self.id,definition)
        self.globalHint:SetText(L[global and "直接输入名称即可搜索" or "通过下面的快捷入口查找"] )
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
        self.technical:SetText(L["版本"].." "..tostring(definition.version).."  ·  "..table.concat(clients,", "));self:Layout()
    end
    function view:Show(id,icon,description)
        self.id,self.entry=id,I.Providers.entries[id]
        local first=self.entry.records and self.entry.records[1]
        self.sample=first and type(first.title)=="string" and #first.title<=42 and not first.title:find("|",1,true) and first.title or L["名称"]
        self.aboutOpen=false
        self.generation=self.generation+1;outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon);self.title:SetText(self.entry.definition.title);self.detail:SetText(description or "");self:Refresh()
        controller:SetStatusText(L["修改搜索设置不影响已固定的内容"])
    end
    outer:SetScript("OnHide",function()
        view:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.entry=nil,nil
    end)
    return view
end
