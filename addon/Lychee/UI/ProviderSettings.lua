local EMPTY_UI_PROPS = {}
local I,UI=_G.LycheeInternal,_G.Lychee.UI
local L=I.Locale
local management=I.ProviderManagement
local CLIENTS={retail="正式服",classic="经典怀旧服",titan="泰坦重铸",anniversary="周年纪念服"}
local P={};UI.ProviderSettings=P
function P:Create(parent,controller,onBack)
    local metrics=UI.Theme.Metrics
    local width=metrics.resultTileWidth-metrics.listInset
    local valueX=136;local valueWidth=width-valueX-8
    local tokenWidth=valueWidth-68
    local view={generation=0};local outer=CreateFrame("Frame",nil,parent);view.frame=outer
    outer:SetPoint("TOPLEFT",parent,"TOPLEFT",metrics.listInset,0)
    outer:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-metrics.listInset,2);outer:Hide()
    local scroll=CreateFrame("ScrollFrame",nil,outer)
    scroll:SetPoint("TOPLEFT",outer,"TOPLEFT",0,-32);scroll:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",0,8)
    local contentHeight=392
    local frame=CreateFrame("Frame",nil,scroll);frame:SetSize(width,contentHeight);scroll:SetScrollChild(frame)
    local bar
    bar=UI.Components:CreateScrollbar(scroll,function(value) bar.value=value;scroll:SetVerticalScroll(value) end)
    bar.frame:ClearAllPoints();bar.frame:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-32);bar.frame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,10)
    local function range() bar:SetRange(contentHeight,scroll:GetHeight(),bar.value);scroll:SetVerticalScroll(bar.value) end
    scroll:SetScript("OnSizeChanged",range)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    scroll:SetScript("OnMouseWheel",function(_,delta) if not InCombatLockdown() then bar:SetValue(bar.value-delta*52) end end)
    local function current()
        return outer:IsShown() and controller.visible and controller.settingsOpen and not InCombatLockdown()
            and management:IsCurrent(view.id,view.instanceToken)
    end
    local function label(value,x,y,w,style)
        local text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        UI.Theme:SetFont(text,style or "body");UI.Theme:SetTextColor(text,"textMuted")
        text:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y);text:SetSize(w or width,22);text:SetJustifyH("LEFT");text:SetText(value)
        return text
    end
    local function button(value,x,y,w,fn,container,height,navigation,primary,direction)
        local b
        container=container or frame
        b=UI.Components:CreateNavigationButton(container,{text=value,width=w,height=height or 28,primary=primary,direction=direction,onClick=function()
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
    view.back=button(L["返回功能来源"],0,0,152,back,outer,28,true,false,"left")
    view.back.label:ClearAllPoints();view.back.label:SetPoint("TOPLEFT",view.back.frame,"TOPLEFT",22,0)
    view.back.label:SetPoint("BOTTOMRIGHT",view.back.frame,"BOTTOMRIGHT",-8,0);view.back.label:SetJustifyH("LEFT")
    view.icon=frame:CreateTexture(nil,"ARTWORK");view.icon:SetSize(metrics.iconSize,metrics.iconSize);view.icon:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listIconInset,-10)
    view.title=label("",metrics.listTitleInset,-4,width-160);UI.Theme:SetTextColor(view.title,"text")
    view.detail=label("",metrics.listTitleInset,-24,width-160,"meta")
    view.toggle=UI.Components:CreateToggle(frame);view.toggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-14)
    view.state=label("",width-128,-12,80,"meta");view.state:SetJustifyH("RIGHT")
    view.toggle:SetScript("OnClick",function()
        local pressed=view.toggle.press;view.toggle.press=nil
        if not current() or pressed~=nil and pressed~=view.generation then return end
        local ok,err=management:ToggleUserEnabled(view.id,view.instanceToken)
        if not ok then
            if not management:IsCurrent(view.id,view.instanceToken) then back() end
            controller:ReportActionResult(false,err);return
        end
        management:Read(view.id,view.instanceToken,view.info)
        controller:MarkHomeDirty();view.toggle:SetChecked(view.info.userEnabled)
        view.state:SetText(L[view.info.userEnabled and "已启用" or "已关闭"])
    end)
    view.toggle:SetScript("OnMouseDown",function() view.toggle.press=view.generation end)
    view.globalLabel=label(L["普通搜索"],8,-60,120);UI.Theme:SetTextColor(view.globalLabel,"text")
    view.globalHint=label("",valueX,-60,valueWidth-50,"meta");view.globalHint:SetHeight(22)
    view.globalToggle=UI.Components:CreateToggle(frame);view.globalToggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-62)
    view.globalToggle:SetScript("OnMouseDown",function() view.globalToggle.press=view.generation end)
    view.globalToggle:SetScript("OnClick",function()
        local pressed=view.globalToggle.press;view.globalToggle.press=nil
        if not current() or pressed~=nil and pressed~=view.generation then return end
        local global,prefixes,keywords=management:GetConfiguration(view.id,view.instanceToken)
        local ok,err=management:SetConfiguration(view.id,view.instanceToken,not global,prefixes,keywords)
        if not ok then view:Failure(err);view.globalToggle:SetChecked(global);return end
        view.global=not global;view.globalToggle:SetChecked(view.global);view:UpdateExamples()
        view.error:SetText("");view:Layout();controller:SetStatusText(L["更改即时生效"])
    end)
    view.fields={}
    for _,kind in ipairs({"prefix","keyword"}) do
        local field={};view.fields[kind]=field
        local function action(key,fn)
            return {OnMouseDown=function() field[key.."Press"]=view.generation end,
                click=function()
                    local pressed=field[key.."Press"];field[key.."Press"]=nil
                    if current() and (pressed==nil or pressed==view.generation) then fn() end
                end}
        end
        field.ui=UI:Create(frame,{type="Fragment",children={
            {type="Text",key="label",props={text=L[kind=="prefix" and "搜索前缀" or "快捷关键词"],role="body",color="text",width=valueX-24,height=22,point={"TOPLEFT",frame,"TOPLEFT",8,0}}},
            {type="Text",key="hint",props={role="meta",color="textMuted",width=valueWidth,height=28,point={"TOPLEFT",frame,"TOPLEFT",valueX,0}}},
            {type="Button",key="edit",props={text=L["编辑"],role="body",width=140,height=28,point={"TOPLEFT",frame,"TOPLEFT",valueX,0}},on=action("edit",function() view:BeginEdit(kind) end)},
            {type="Input",key="input",props={role="body",color="text",width=valueWidth,height=32,maxBytes=400,textInsets={10,10,0,0}},on={
                OnTextChanged=function(_,_,_,_,userInput) if userInput and current() and view.editing==kind then field.inputStyle:SetInvalid(false);view.error:SetText("");view:Layout() end end,
                OnEnterPressed=function() if view.editing==kind then view:Save() end end,
                OnEscapePressed=function() if current() and view.editing==kind then view:CancelEdit() end end,
            }},
            {type="Text",key="example",props={text=L["多个词用逗号分隔；清空可移除此入口"],role="meta",color="textMuted",width=valueWidth,height=36,point={"TOPLEFT",frame,"TOPLEFT",valueX,0}}},
            {type="Button",key="save",props={text=L["保存"],role="body",width=64,height=28,primary=true,point={"TOPLEFT",frame,"TOPLEFT",0,0}},on=action("save",function() if view.editing==kind then view:Save() end end)},
            {type="Button",key="cancel",props={text=L["取消"],role="body",width=64,height=28,point={"TOPLEFT",frame,"TOPLEFT",0,0}},on=action("cancel",function() if view.editing==kind then view:CancelEdit() end end)},
        }})
        assert(field.ui:Update(EMPTY_UI_PROPS))
        field.label,field.hint=field.ui:Get("label"),field.ui:Get("hint")
        field.input,field.example=field.ui:Get("input"),field.ui:Get("example")
        field.edit,field.save,field.cancel=field.ui:GetComponent("edit"),field.ui:GetComponent("save"),field.ui:GetComponent("cancel")
        field.inputStyle=field.input._lycheeField
        field.tokens={}
        for index=1,8 do
            local chip=CreateFrame("Frame",nil,frame)
            local text=chip:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            UI.Theme:SetFont(text,"body");UI.Theme:SetTextColor(text,"text")
            if text.SetWordWrap then text:SetWordWrap(false) end
            if text.SetMaxLines then text:SetMaxLines(1) end
            text:SetPoint("LEFT",chip,"LEFT",0,0);text:SetJustifyH("LEFT")
            field.tokens[index]={frame=chip,label=text};chip:Hide()
        end
    end
    view.prefixInput=view.fields.prefix.input;view.keywordInput=view.fields.keyword.input
    view.error=label("",8,0,width-16,"meta");view.error:SetHeight(36);UI.Theme:SetTextColor(view.error,"warning")
    view.technical=label("",8,0,width-16,"meta");view.technical:SetHeight(36)
    function view:ClearFocus() for _,field in pairs(self.fields) do field.input:ClearFocus();field.inputStyle:SetInvalid(false) end end
    function view:CancelEdit()
        if not current() then return end
        self:ClearFocus();self.editing=nil;self.generation=self.generation+1
        self.error:SetText("");self:Layout();controller:SetStatusText(L["更改即时生效"])
    end
    function view:BeginEdit(kind)
        if not current() or self.editing then return end
        local _,prefixes,keywords=management:GetConfiguration(self.id,self.instanceToken)
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
        local global,prefixes,keywords=management:GetConfiguration(self.id,self.instanceToken)
        if global==nil then return end
        self.global=global
        self.globalHint:SetText(L["在普通搜索结果中包含此功能"])
        for kind,field in pairs(self.fields) do
            local words=kind=="prefix" and prefixes or keywords
            local word=representative(words);field.count=#words
            field.edit:SetText(L[word and "编辑" or kind=="prefix" and "+ 添加前缀" or "+ 添加关键词"])
            field.wordsKey=table.concat(words,"\031")
            for index,chip in ipairs(field.tokens) do
                local value=words[index]
                if value and chip.value~=value then
                    chip.value=value;chip.label:SetWidth(tokenWidth);chip.label:SetText(value)
                    local measured=chip.label.GetStringWidth and chip.label:GetStringWidth() or #value*7
                    chip.width=math.min(tokenWidth,math.max(16,measured))
                    chip.frame:SetSize(chip.width,24);chip.label:SetSize(chip.width,22)
                end
            end
            if kind=="prefix" then
                field.hint:SetText(word and L:Format("输入 %s，只搜索此功能",word..(L:IsChinese() and "：" or ": ")..self.sample)
                    or L["加上前缀，只搜此功能"])
            else
                field.hint:SetText(word and L:Format("输入 %s，查看此功能结果",word)
                    or L["设一个词，直达此功能结果"])
            end

        end
    end
    function view:Layout()
        if not self.info then return end
        local hasError=self.error:GetText()~=""
        local key=tostring(self.editing)..":"..tostring(self.aboutOpen)..":"..tostring(hasError)
            ..":"..self.fields.prefix.wordsKey..":"..self.fields.keyword.wordsKey
        if self.layoutKey==key then return end
        self.layoutKey=key
        local y=104;local errorY=90
        for _,kind in ipairs({"prefix","keyword"}) do
            local field=self.fields[kind];local editing=self.editing==kind
            local function at(region,x,offset) region:ClearAllPoints();region:SetPoint("TOPLEFT",frame,"TOPLEFT",x,-y-offset) end
            at(field.label,8,3);field.label:SetShown(true)
            local x,rowY=valueX,0
            for index,chip in ipairs(field.tokens) do
                local shown=not editing and index<=field.count
                if shown then
                    if x+chip.width>valueX+tokenWidth then x=valueX;rowY=rowY+28 end
                    at(chip.frame,x,rowY);chip.x,chip.y=x,rowY
                    x=x+chip.width+14
                end
                chip.frame:SetShown(shown)
            end
            local configured=field.count>0
            local editWidth=configured and 64 or 140
            field.edit.frame:SetWidth(editWidth);at(field.edit.frame,width-8-editWidth,0)
            field.edit.label:ClearAllPoints();field.edit.label:SetAllPoints(field.edit.frame)
            field.edit.label:SetJustifyH("RIGHT")
            field.edit.frame:SetShown(not editing);field.edit:SetEnabled(self.editing==nil)
            field.hint:SetWidth(configured and valueWidth or valueWidth-editWidth-12)
            at(field.hint,valueX,configured and rowY+26 or 3);field.hint:SetShown(not editing)
            at(field.input,valueX,0);field.input:SetShown(editing)
            at(field.example,valueX,40);field.example:SetShown(editing)
            at(field.cancel.frame,width-144,78);field.cancel.frame:SetShown(editing)
            at(field.save.frame,width-72,78);field.save.frame:SetShown(editing)
            if editing then errorY=y+112 end
            y=y+(editing and (hasError and 152 or 112) or rowY+(configured and 64 or 48))
        end
        if not self.editing then errorY=y end
        self.error:ClearAllPoints();self.error:SetPoint("TOPLEFT",frame,"TOPLEFT",valueX,-errorY);self.error:SetWidth(valueWidth);self.error:SetShown(hasError)
        if hasError and not self.editing then y=y+40 end
        local aboutY=y
        self.about.frame:ClearAllPoints();self.about.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-aboutY)
        self.about:SetText(L[self.aboutOpen and "收起版本信息" or "版本与兼容性"])
        self.about:SetDirection(self.aboutOpen and "down" or "right")
        self.reset.frame:ClearAllPoints();self.reset.frame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-aboutY)
        self.technical:ClearAllPoints();self.technical:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-aboutY-28)
        self.technical:SetShown(self.aboutOpen==true)
        local height=aboutY+(self.aboutOpen and 70 or 32)
        if contentHeight~=height then contentHeight=height;frame:SetHeight(height);range() end
    end

    function view:Failure(err)
        if not management:IsCurrent(self.id,self.instanceToken) then back();return end
        local message=type(err)=="table" and (err.message or err.code) or err
        if self.editing then self.fields[self.editing].inputStyle:SetInvalid(true) end
        self.error:SetText(L[message]);self:Layout();controller:SetStatusText(L[message])
    end
    function view:Save()
        if not current() or not self.editing then return end
        local kind=self.editing;local list={}
        if self.fields[kind].input:GetText()==self.fields[kind].before then self:CancelEdit();return end
        for value in self.fields[kind].input:GetText():gsub("，",","):gmatch("[^,]+") do
            if value:find("%S") then list[#list+1]=value end
        end
        -- Read committed siblings at save time: a toggle may have changed while editing.
        local global,prefixes,keywords=management:GetConfiguration(self.id,self.instanceToken)
        local ok,err=management:SetConfiguration(self.id,self.instanceToken,global,kind=="prefix" and list or prefixes,kind=="keyword" and list or keywords)
        if not ok then self:Failure(err);return end
        self:CancelEdit();self:UpdateExamples();self:Layout();controller:SetStatusText(L["搜索设置已保存"])
    end
    view.reset=button(L["恢复默认"],0,0,120,function()
        local ok,err=management:ResetConfiguration(view.id,view.instanceToken)
        if not ok then view:Failure(err);return end
        view.generation=view.generation+1;view:Refresh();controller:SetStatusText(L["已恢复默认搜索设置"])
    end,frame,30,true)
    view.reset.label:ClearAllPoints();view.reset.label:SetAllPoints(view.reset.frame);view.reset.label:SetJustifyH("RIGHT")
    view.about=button(L["版本与兼容性"],0,0,200,function() view.aboutOpen=not view.aboutOpen;view:Layout() end,nil,28,true,false,"right")
    view.about.label:ClearAllPoints();view.about.label:SetPoint("LEFT",view.about.frame,"LEFT",22,0);view.about.label:SetSize(170,24);view.about.label:SetJustifyH("LEFT")
    function view:Refresh()
        if not current() then return end
        self:ClearFocus();self.layoutKey=nil;self.editing=nil
        management:Read(self.id,self.instanceToken,self.info)
        self:RefreshStatus()
        self:UpdateExamples();self.globalToggle:SetChecked(self.global,true);self.globalToggle:SetShown(true)
        self.globalLabel:SetShown(true);self.globalHint:SetShown(true)
        self.reset:SetEnabled(true);self.error:SetText("")
        local clients={}
        for _,product in ipairs(self.info.products) do clients[#clients+1]=L[CLIENTS[product] or product] end
        self.technical:SetText(L["版本"].." "..tostring(self.info.version).."  ·  "..table.concat(clients,", "));self:Layout()
    end
    function view:RefreshStatus()
        if not current() then return end
        local info=management:Read(self.id,self.instanceToken,self.info)
        if not info then return end
        self.toggle:SetChecked(info.userEnabled,true)
        self.state:SetText(L[not info.userEnabled and "已关闭" or info.effectiveEnabled and "已启用" or "暂不可用"])
        self.title:SetText(info.title)
        self.detail:SetText(info.userEnabled and info.statusReason or info.description or self.description or "")
    end
    function view:Show(id,icon,description)
        local info=management:Read(id,nil,self.info)
        if not info then return false end
        self.id,self.instanceToken,self.info,self.description=id,info.instanceToken,info,description
        self.sample=info.sample or L["名称"]
        self.aboutOpen=false
        self.generation=self.generation+1
        for _,field in pairs(self.fields) do field.ui:Update(EMPTY_UI_PROPS) end
        outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon or info.icon);self:Refresh()
        controller:SetStatusText(L["更改即时生效"])
        return true
    end
    outer:SetScript("OnHide",function()
        view:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.instanceToken,view.info,view.sample=nil,nil,nil,nil
        view.description=nil
        for _,field in pairs(view.fields) do field.editPress,field.savePress,field.cancelPress=nil,nil,nil;field.ui:Release("hide") end
    end)
    return view
end
