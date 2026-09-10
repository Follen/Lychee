local I,UI=_G.LycheeInternal,_G.Lychee.UI
local L=I.Locale
local A={}
UI.AliasSettings=A
local function label(parent,value,x,y,width)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    UI.Theme:SetFont(text,"body");UI.Theme:SetTextColor(text,"textMuted")
    text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);text:SetWidth(width);text:SetHeight(22);text:SetJustifyH("LEFT");text:SetText(value)
    return text
end
local function button(parent,value,width,x,y,callback)
    local control=UI.Components:CreateNavigationButton(parent,{text=value,width=width,height=28,onClick=callback})
    control.frame:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    return control
end
function A:Create(parent,controller,onBack)
    local metrics=UI.Theme.Metrics
    local width=metrics.resultTileWidth-metrics.listInset
    local view={rows={},offset=0}
    local frame=CreateFrame("Frame",nil,parent);view.frame=frame
    frame:SetPoint("TOPLEFT",parent,"TOPLEFT",metrics.listInset,-metrics.settingsTabsHeight)
    frame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-metrics.listInset,2);frame:Hide()
    local function active() return frame:IsShown() and controller.visible and controller.settingsOpen and not InCombatLockdown() end
    local back=button(frame,L["返回综合设置"],140,0,0,function() if active() then frame:Hide();onBack() end end)
    view.back=back
    local scroll=CreateFrame("ScrollFrame",nil,frame);view.scroll=scroll
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-36);scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    local content=CreateFrame("Frame",nil,scroll);view.content=content;content:SetSize(width,1);scroll:SetScrollChild(content)
    view.bar=UI.Components:CreateScrollbar(scroll,function(value) view.offset=value;scroll:SetVerticalScroll(value);view:Render() end)
    view.bar.frame:ClearAllPoints()
    view.bar.frame:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-metrics.settingsTabsHeight-36)
    view.bar.frame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,2)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        if not active() then return end
        view.offset=math.max(0,math.min(math.max(0,content:GetHeight()-scroll:GetHeight()),view.offset-delta*(metrics.rowHeight+metrics.rowGap)))
        scroll:SetVerticalScroll(view.offset);view:Render()
    end)
    scroll:SetScript("OnSizeChanged",function() if active() and not view.editing then view:Render() end end)
    view.empty=label(content,L["还没有别名。右键搜索结果，选择设置别名。"],0,-10,width-20)
    local editor=CreateFrame("Frame",nil,frame);view.editor=editor;editor:SetAllPoints(scroll);editor:Hide()
    view.target=label(editor,"",0,-8,width-20)
    label(editor,L["输入别名，留空可删除"],0,-40,width-20)
    local input=CreateFrame("EditBox",nil,editor);view.input=input
    input:SetSize(width-24,36);input:SetPoint("TOPLEFT",editor,"TOPLEFT",0,-70)
    input:SetAutoFocus(false);input:SetTextInsets(10,10,0,0);UI.Theme:SetFont(input,"input")
    UI.Theme:SetTextColor(input,"text")
    if input.SetMaxBytes then input:SetMaxBytes(192) end
    local background=input:CreateTexture(nil,"BACKGROUND");background:SetAllPoints(input);UI.Theme:SetColorTexture(background,"surfaceSelected")
    local line=input:CreateTexture(nil,"ARTWORK");line:SetHeight(1);line:SetPoint("BOTTOMLEFT",input,"BOTTOMLEFT",0,0);line:SetPoint("BOTTOMRIGHT",input,"BOTTOMRIGHT",0,0);UI.Theme:SetColorTexture(line,"borderStrong")
    view.error=label(editor,"",0,-150,width-20)
    view.error:SetHeight(44)
    UI.Theme:SetTextColor(view.error,"warning")
    local function cancel() if active() then input:ClearFocus();view:ShowList() end end
    local function save()
        if not active() or not view.editing then return end
        local ok,err=I.Search.Personalization:SetAlias(view.ref,input:GetText(),view.title)
        if not ok then
            view.error:SetText(err=="ALIAS_LIMIT" and L["别名已达上限，请先删除一项"] or L["别名最多96字节，不能包含换行或竖线"]);return
        end
        input:ClearFocus();controller:SetStatusText(L["别名已保存"]);view:ShowList()
    end
    view.save=button(editor,L["保存"],72,0,-114,save)
    view.cancel=button(editor,L["取消"],72,88,-114,cancel)
    input:SetScript("OnEnterPressed",save);input:SetScript("OnEscapePressed",cancel)
    frame:SetScript("OnHide",function()
        input:ClearFocus();view.ref,view.title,view.data,view.editing=nil,nil,nil,nil
        view.bar:StopDrag()
        for _,row in ipairs(view.rows) do row.record=nil;row.edit.frame.press=false;row.remove.frame.press=false end
    end)
    function view:Edit(ref,title)
        if not active() then return end
        self.ref={providerID=ref.providerID,entryID=ref.entryID};self.title=title;self.editing=true
        scroll:Hide();editor:Show();self.target:SetText(title or ref.entryID);self.error:SetText("")
        local row=I.Search.Personalization:Find(ref)
        input:SetText(row and row.alias or "");input:SetFocus()
        if input.HighlightText then input:HighlightText() end
    end
    function view:Render()
        if not self.data or self.editing or not active() then return end
        local stride=metrics.rowHeight+metrics.rowGap
        local height=math.max(36,#self.data*stride)
        if content:GetHeight()~=height then content:SetHeight(height) end
        local viewport=scroll:GetHeight()
        local offset=math.max(0,math.min(self.offset,math.max(0,height-viewport)))
        if self.offset~=offset then self.offset=offset;scroll:SetVerticalScroll(offset) end
        self.bar:SetRange(height,viewport,self.offset)
        self.empty:SetShown(#self.data==0)
        local first=math.floor(self.offset/stride)+1
        local count=math.min(9,math.ceil(viewport/stride)+1,#self.data-first+1)
        for index=1,math.max(0,count) do
            local row=self.rows[index]
            if not row then
                row=CreateFrame("Frame",nil,content);row:SetSize(width,metrics.rowHeight)
                row.title=label(row,"",0,-4,width-180);UI.Theme:SetTextColor(row.title,"text")
                row.alias=label(row,"",0,-25,width-180)
                local function current(control)
                    local pressed=control.press;control.press=nil
                    if not active() or (pressed~=nil and pressed~=row.record) then return false end
                    for _,entry in ipairs(I.Search.Personalization:Aliases()) do if entry==row.record then return true end end
                    return false
                end
                row.edit=button(row,L["修改"],64,width-152,-9,function() if current(row.edit.frame) then self:Edit(row.record.ref,row.record.title) end end)
                row.remove=button(row,L["删除"],64,width-80,-9,function()
                    if current(row.remove.frame) then I.Search.Personalization:Remove(row.record);self:ShowList();controller:SetStatusText(L["别名已删除"]) end
                end)
                for _,control in ipairs({row.edit.frame,row.remove.frame}) do
                    control:SetScript("OnMouseDown",function() control.press=row.record end)
                    if control.HookScript then control:HookScript("OnHide",function() if control.press then control.press=false end end) end
                end
                self.rows[index]=row
            end
            local position=first+index-1;row.record=self.data[position]
            if row.position~=position then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-(position-1)*stride);row.position=position end
            if row.title:GetText()~=row.record.title then row.title:SetText(row.record.title) end
            if row.aliasValue~=row.record.alias then row.alias:SetText(L["别名"].." · "..row.record.alias);row.aliasValue=row.record.alias end
            if not row:IsShown() then row:Show() end
        end
        for index=math.max(0,count)+1,#self.rows do self.rows[index].record=nil;self.rows[index]:Hide() end
    end
    function view:ShowList()
        input:ClearFocus();self.editing=false;self.ref=nil;editor:Hide();scroll:Show()
        local current=I.Search.RuntimeIdentity:Current().product
        self.data={}
        for _,row in ipairs(I.Search.Personalization:Aliases()) do if row.product==current then self.data[#self.data+1]=row end end
        self:Render()
    end
    function view:Show(ref,title)
        frame:Show()
        if self.offset~=0 then self.offset=0;scroll:SetVerticalScroll(0) end
        if ref then self:Edit(ref,title) else self:ShowList() end
    end
    return view
end
