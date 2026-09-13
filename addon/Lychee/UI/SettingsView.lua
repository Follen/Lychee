local EMPTY_UI_PROPS = {}
local L = _G.LycheeInternal.Locale
local I, Lychee = _G.LycheeInternal, _G.Lychee
local Settings = {}
local management=I.ProviderManagement
local metrics=Lychee.UI.Theme.Metrics
local rowWidth=metrics.resultTileWidth-metrics.listInset
local rowStride=metrics.rowHeight+metrics.rowGap
Lychee.UI.SettingsView = Settings
local function text(region, value)
    value = value or ""
    if region:GetText() ~= value then region:SetText(value) end
end
local function shown(region, value)
    if region:IsShown() ~= value then region:SetShown(value) end
end
local function label(parent, role, color)
    local result = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Lychee.UI.Theme:SetFont(result, role or "body")
    Lychee.UI.Theme:SetTextColor(result, color or "text")
    result:SetJustifyH("LEFT")
    return result
end
local function button(parent, title, width, callback)
    local control = Lychee.UI.Components:CreateNavigationButton(parent, {width=width, height=28, text=title,
        onClick=callback})
    Lychee.UI.Theme:SetFont(control.label,"body")
    return control
end
local function settingRow(parent, index, title, detail)
    local row=CreateFrame("Frame",nil,parent);row:SetSize(rowWidth,metrics.rowHeight)
    row:SetPoint("TOPLEFT",parent,"TOPLEFT",0,-rowStride*index)
    local name=label(row,"body");name:SetPoint("TOPLEFT",row,"TOPLEFT",metrics.listTitleInset,-7);name:SetText(L[title])
    local caption=label(row,"meta","textMuted");caption:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-3);caption:SetText(L[detail])
    return row
end
local iconRoot = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
local function rowIcon(record)
    local pin = type(record.pin) == "table" and record.pin or nil
    local icon = record.item and record.item.icon or pin and pin.icon
    if type(icon) == "string" and icon ~= "" or type(icon) == "number" and icon > 0 then return icon end
    return record.icon or iconRoot .. "settings.tga"
end
local function displayTitle(value, fallback) return L:Resolve(value, fallback) end
local function releaseIdentity(row)
    if row.toggle then row.toggle:FinishMotion() end
    row._bindingGeneration=(row._bindingGeneration or 0)+1
    row.providerID,row.pinIndex,row._bindingIdentity=nil,nil,nil
end
local function bindPress(control,row,component)
    control:SetScript("OnMouseDown",function()
        control._pressGeneration=row._bindingGeneration
        if component and component.enabled==false then control._pressGeneration=false end
        if component then component:SetState("pressed") end
    end)
    control:SetScript("OnHide",function()
        if control.FinishMotion then control:FinishMotion() end
        if control._pressGeneration~=nil then control._pressGeneration=false end
        if component then component._hovered=false;component:SetState("normal") end
    end)
    if component then
        local setEnabled=component.SetEnabled
        function component:SetEnabled(enabled)
            if enabled==false and control._pressGeneration~=nil then control._pressGeneration=false end
            return setEnabled(self,enabled)
        end
    end
end

function Settings:Create(parent, controller)
    local view = {controller=controller, rows={}, groups={}, tab="providers",scroll=0}
    local frame=CreateFrame("Frame",nil,parent);frame:SetAllPoints(parent);frame:Hide();view.frame=frame
    view.tabs={}
    local previous
    for _,entry in ipairs({{"providers","功能来源"},{"pins","已固定"},{"general","综合设置"},{"about","关于"}}) do
        local tab=button(frame,L[entry[2]],86,function() view:SetTab(entry[1]) end)
        if previous then tab.frame:SetPoint("LEFT",previous,"RIGHT",12,0)
        else tab.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset,-2) end
        view.tabs[entry[1]]=tab;previous=tab.frame
    end
    view.underline=frame:CreateTexture(nil,"ARTWORK");view.underline:SetSize(60,2)
    Lychee.UI.Theme:SetColorTexture(view.underline,"accent")
    view.undo=button(frame,L["撤销"],48,function()
        if view.removed and I.UserPreferences:Restore(view.removed,view.removedIndex) then
            view.removed=nil;controller:MarkHomeDirty();view:Refresh();controller:SetStatusText(L["已恢复固定"])
        end
    end)
    view.undo.frame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-2);view.undo.frame:Hide()
    local scroll=CreateFrame("ScrollFrame",nil,frame);scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset,-metrics.settingsTabsHeight);scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-metrics.listInset,2)
    local content=CreateFrame("Frame",nil,scroll);content:SetSize(rowWidth,1);scroll:SetScrollChild(content)
    view.scrollFrame,view.content=scroll,content
    view.scrollbar=Lychee.UI.Components:CreateScrollbar(scroll,function(value) view:SetScroll(value) end)
    view.scrollbar.frame:ClearAllPoints()
    view.scrollbar.frame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,-metrics.settingsTabsHeight)
    view.scrollbar.frame:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,2)
    function view:SetScroll(value)
        if InCombatLockdown and InCombatLockdown() then return end
        local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
        value=math.max(0,math.min(maximum,value))
        if value~=self.scroll then self.scroll=value;scroll:SetVerticalScroll(value);self:RenderVisible() end
    end
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    scroll:SetScript("OnMouseWheel",function(_,delta)
        if InCombatLockdown and InCombatLockdown() then return end
        view:SetScroll(view.scroll-delta*rowStride)
    end)
    scroll:SetScript("OnSizeChanged",function() if view.data then view:RenderVisible() end end)
    frame:SetScript("OnHide",function()
        if view.providerView then view.providerView.frame:Hide() end
        if view.aliasView then view.aliasView.frame:Hide() end
        view.dragIndex,view.data=nil,nil
        for _,row in ipairs(view.rows) do releaseIdentity(row) end
    end)
    local function currentClick(control,row)
        local generation=control._pressGeneration
        control._pressGeneration=nil
        if generation~=nil and generation~=row._bindingGeneration then return false end
        if not frame:IsShown() or not row:IsShown() or (InCombatLockdown and InCombatLockdown()) then return false end
        if row.providerID then return management:IsCurrent(row.providerID,row._bindingIdentity) end
        return row.pinIndex~=nil and I.UserPreferences:GetPins()[row.pinIndex]==row._bindingIdentity
    end

    function view:Acquire(index)
        if self.rows[index] then return self.rows[index] end
        local row=CreateFrame("Button",nil,content);row:SetSize(rowWidth,metrics.rowHeight)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(metrics.iconSize,metrics.iconSize);row.icon:SetPoint("LEFT",row,"LEFT",metrics.listIconInset,0)
        row.ui=Lychee.UI:Create(row,{type="Fragment",children={
            {type="Text",key="name",props={role="body",color="text",height=17,maxLines=1,wordWrap=false,nonSpaceWrap=false,points={{"TOPLEFT",row,"TOPLEFT",metrics.listTitleInset,-7},{"RIGHT",row,"RIGHT",-124,0}}}},
            {type="Text",key="detail",props={role="meta",color="textMuted",height=14,maxLines=1,wordWrap=false,nonSpaceWrap=false,points={{"TOPLEFT","name","BOTTOMLEFT",0,-3},{"RIGHT",row,"RIGHT",-124,0}}}},
            {type="Text",key="state",props={role="meta",color="textMuted",width=118,justifyH="RIGHT",point={"RIGHT",row,"RIGHT",-54,0}}},
        }})
        assert(row.ui:Update(EMPTY_UI_PROPS));row.name,row.detail,row.state=row.ui:Get("name"),row.ui:Get("detail"),row.ui:Get("state")
        row.toggle=Lychee.UI.Components:CreateToggle(row);row.toggle:SetPoint("RIGHT",row,"RIGHT",-metrics.listIconInset,0)
        row.manage=button(row,L["设置"],54,function()
            if currentClick(row.manage.frame,row) then self:OpenProvider(row.providerID,row._icon) end
        end)
        row.manage.frame:SetPoint("RIGHT",row,"RIGHT",-52,0)
        bindPress(row.manage.frame,row,row.manage)
        row.hover=row:CreateTexture(nil,"BACKGROUND");row.hover:SetAllPoints(row)
        Lychee.UI.Theme:SetColorTexture(row.hover,"surfaceHover");row.hover:Hide()
        row:SetScript("OnEnter",function() if self.tab=="providers" then row.hover:Show() end end)
        row:SetScript("OnLeave",function() row.hover:Hide() end)
        row.toggle:SetScript("OnClick",function()
            if not currentClick(row.toggle,row) then return end
            if not row.providerID then return end
            local ok,err=management:ToggleUserEnabled(row.providerID,row._bindingIdentity)
            if not ok then controller:ReportActionResult(false,err);return end
            controller:MarkHomeDirty();self:Refresh();controller:SetStatusText(L["更改已保存，固定记录保留"])
        end)
        row.up=button(row,L["上移"],40,function() if currentClick(row.up.frame,row) then self:Move(row.pinIndex,-1) end end);row.up.frame:SetPoint("RIGHT",row,"RIGHT",-132,0)
        row.down=button(row,L["下移"],40,function() if currentClick(row.down.frame,row) then self:Move(row.pinIndex,1) end end);row.down.frame:SetPoint("RIGHT",row,"RIGHT",-88,0)
        row.remove=button(row,L["取消固定"],76,function()
            if not currentClick(row.remove.frame,row) then return end
            if not row.pinIndex then return end
            self.removedIndex=row.pinIndex;self.removed=I.UserPreferences:Remove(row.pinIndex)
            controller:MarkHomeDirty();self:Refresh();controller:SetStatusText(L["已取消固定，可以撤销"])
        end);row.remove.frame:SetPoint("RIGHT",row,"RIGHT",-8,0)
        bindPress(row.toggle,row)
        bindPress(row,row)
        local release=row.GetScript and row:GetScript("OnHide")
        row:SetScript("OnHide",function() row.hover:Hide();if release then release() end end)
        row:SetScript("OnClick",function()
            if self.tab=="providers" and currentClick(row,row) then self:OpenProvider(row.providerID,row._icon) end
        end)
        bindPress(row.up.frame,row,row.up);bindPress(row.down.frame,row,row.down);bindPress(row.remove.frame,row,row.remove)
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart",function() if self.tab=="pins" then self.dragIndex=row.pinIndex end end)
        row:SetScript("OnDragStop",function()
            local from=self.dragIndex;self.dragIndex=nil
            if not from then return end
            for _,target in ipairs(self.rows) do
                if target:IsShown() and target.pinIndex and target.IsMouseOver and target:IsMouseOver() then
                    if I.UserPreferences:Move(from,target.pinIndex) then controller:MarkHomeDirty();self:Refresh();controller:SetStatusText(L["固定顺序已保存"]) end
                    break
                end
            end
        end)
        self.rows[index]=row;return row
    end
    function view:Move(index,delta)
        if index and I.UserPreferences:Move(index,index+delta) then controller:MarkHomeDirty();self:Refresh();controller:SetStatusText(L["固定顺序已保存"]) end
    end
    function view:Header(index,title,y)
        local header=self.groups[index]
        if not header then header=label(content,"meta","textMuted");self.groups[index]=header end
        if header._y~=y then header:ClearAllPoints();header:SetPoint("TOPLEFT",content,"TOPLEFT",10,-y);header._y=y end
        text(header,title);shown(header,true)
    end
    function view:SetTab(tab)
        controller:SetStatusText(tab=="about" and L["感谢使用荔枝"] or L["更改即时生效"])
        self.social:Close();self.social:Show()
        if self.providerView then self.providerView.frame:Hide() end
        if self.aliasView then self.aliasView.frame:Hide() end
        if Lychee.UI.Motion then
            Lychee.UI.Motion:Cancel(content,true)
            if self.general then Lychee.UI.Motion:Cancel(self.general,true) end
            if self.about then Lychee.UI.Motion:Cancel(self.about,true) end
        end
        self.tab=tab;self.scroll=0;scroll:SetVerticalScroll(0);self:Refresh()
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(tab=="general" and self.general or tab=="about" and self.about or content,"page") end
    end
    function view:Refresh()
        if InCombatLockdown and InCombatLockdown() then return end
        if self.providerView and self.providerView.frame:IsShown() then
            if management:IsCurrent(self.providerView.id,self.providerView.instanceToken) then self.providerView:RefreshStatus();return end
            self.providerView.frame:Hide()
            controller:SetStatusText(L["该功能已断开连接，配置已保留"])
        end
        if self.aliasView and self.aliasView.frame:IsShown() then return end
        if frame:IsShown() and controller.ResizeForMode then controller:ResizeForMode("settings") end
        for id,tab in pairs(self.tabs) do tab.frame:Show();tab:SetSelected(id==self.tab) end
        self.underline:Show()
        if self._underlineTab~=self.tab then self.underline:ClearAllPoints();self.underline:SetPoint("BOTTOM",self.tabs[self.tab].frame,"BOTTOM",0,-3);self._underlineTab=self.tab end
        shown(self.undo.frame,self.tab=="pins" and self.removed~=nil)
        shown(scroll,self.tab~="general" and self.tab~="about")
        if self.general then shown(self.general,self.tab=="general") end
        if self.about then shown(self.about,self.tab=="about") end
        if self.tab=="about" then
            self.data=nil
            for _,row in ipairs(self.rows) do releaseIdentity(row);shown(row,false) end
            if not self.about then
                local about=CreateFrame("Frame",nil,frame);self.about=about
                about:SetSize(rowWidth,L:IsChinese() and metrics.aboutHeight or metrics.aboutEnglishHeight)
                about:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset+10,-metrics.settingsTabsHeight-12)
                local version=C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Lychee","Version") or L["暂不可用"]
                local function copy(value,x,y,width,role,color,height)
                    local region=label(about,role,color)
                    region:SetPoint("TOPLEFT",about,"TOPLEFT",x,-y)
                    region:SetWidth(width);region:SetHeight(height or 18)
                    region:SetJustifyV("TOP");region:SetText(value)
                end
                copy(L.name,0,0,376,"input","text",22)
                copy(L["少一点翻找，多一点冒险。"],0,32,376,"title","text",22)
                copy(L["将技能、物品与插件入口，收进一个搜索框。\n常用的入口、熟悉的名字，都按你的习惯留下。"],0,66,376,"body","textMuted",48)
                copy(L["作者"],432,2,140,"meta","textMuted")
                copy("Follen",432,24,140,"title","text",22)
                copy(L["版本"].."  "..version,432,54,140,"meta","textMuted",32)
                if L:IsChinese() then copy(L["谨献给爱人：荔枝小月亮"],0,144,rowWidth-20,"title","tooltipAccent",24) end
            end
            return
        end
        if self.tab=="general" then
            self.data=nil
            for _,row in ipairs(self.rows) do releaseIdentity(row);shown(row,false) end
            if not self.general then
                local general=settingRow(frame,0,"动态效果","窗口、页面与控件的过渡动画");self.general=general
                general:ClearAllPoints()
                general:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset,-metrics.settingsTabsHeight)
                local icon=general:CreateTexture(nil,"ARTWORK");icon:SetSize(metrics.iconSize,metrics.iconSize)
                icon:SetPoint("LEFT",general,"LEFT",metrics.listIconInset,0);icon:SetTexture(iconRoot.."settings.tga")
                local toggle=Lychee.UI.Components:CreateToggle(general)
                self.motion={frame=toggle,label=label(general,"meta","textMuted")}
                self.motion.label:SetPoint("RIGHT",toggle,"LEFT",-12,0)
                toggle:SetScript("OnClick",function()
                    local motion=Lychee.UI.Motion
                    if not motion or not frame:IsShown() or view.tab~="general" or (InCombatLockdown and InCombatLockdown()) then return end
                    motion:SetReduced(not motion:IsReduced())
                    toggle:SetChecked(not motion:IsReduced())
                    text(view.motion.label,motion:IsReduced() and L["关闭"] or L["开启"])
                end)
                self.motion.frame:SetPoint("RIGHT",general,"RIGHT",-metrics.listIconInset,0)
                local aliases=settingRow(general,1,"自定义别名","用自己熟悉的名字搜索条目")
                self.aliasManage=button(aliases,L["管理别名"],110,function() view:OpenAliases() end)
                self.aliasManage.frame:SetPoint("RIGHT",aliases,"RIGHT",-metrics.listIconInset,0)
                local memory=settingRow(general,2,"搜索记忆","相同搜索优先显示上次选择")
                self.clearChoices=button(memory,L["清空记忆"],110,function()
                    if not frame:IsShown() or view.tab~="general" or InCombatLockdown() then return end
                    I.Search.Personalization:ClearChoices();controller:SetStatusText(L["搜索记忆已清空"])
                end)
                self.clearChoices.frame:SetPoint("RIGHT",memory,"RIGHT",-metrics.listIconInset,0)
            end
            local enabled=not (Lychee.UI.Motion and Lychee.UI.Motion:IsReduced())
            self.motion.frame:SetChecked(enabled,true)
            text(self.motion.label,enabled and L["开启"] or L["关闭"])
            shown(self.general,true)
            return
        end
        if self.general then shown(self.general,false) end
        local data,count=self.data or {},0
        if self.tab=="providers" then
            management:FillList(data)
            table.sort(data,function(a,b)
                if a.sourceID~=b.sourceID then return a.sourceID<b.sourceID end
                if a.order~=b.order then return a.order<b.order end
                return a.id<b.id
            end)
        else
            for index,pin in ipairs(I.UserPreferences:GetPins()) do
                count=count+1
                local record=data[count] or {};data[count]=record
                record.id,record.instanceToken,record.title,record.version,record.sourceID,record.order=nil,nil,nil,nil,nil,nil
                record.sourceTitle,record.description,record.icon,record.groupY=nil,nil,nil,nil
                record.status,record.lifecycle,record.userEnabled,record.ownerEnabled,record.effectiveEnabled=nil,nil,nil,nil,nil
                record.pin,record.pinIndex=pin,index
            end
            for index=#data,count+1,-1 do data[index]=nil end
        end
        local y,groupCount,lastGroup=0,0,nil
        for index,record in ipairs(data) do
            record.groupY=nil
            if self.tab=="providers" then
                if record.sourceID~=lastGroup then
                    if lastGroup then y=y+18 end
                    record.groupY=y;y=y+26;lastGroup=record.sourceID
                end
            end
            record.y=y;y=y+rowStride
        end
        if #data==0 then groupCount=1;self:Header(1,self.tab=="pins" and L["还没有固定项。搜索条目后，右键固定到首页。"] or L["没有已接入的功能来源"],12) end
        for index=groupCount+1,#self.groups do shown(self.groups[index],false) end
        self.data=data
        local height=math.max(40,y+12);if content:GetHeight()~=height then content:SetHeight(height) end
        self:RenderVisible()
    end
    function view:RenderVisible()
        if not self.data or (InCombatLockdown and InCombatLockdown()) then return end
        local data=self.data
        local viewport=scroll:GetHeight()
        local maximum=math.max(0,content:GetHeight()-viewport)
        if self.scroll>maximum then self.scroll=maximum;scroll:SetVerticalScroll(maximum) end
        self.scrollbar:SetRange(content:GetHeight(),viewport,self.scroll)
        -- Geometry is sorted once per data refresh; wheel work is O(log N + K).
        local low,high=1,#data
        while low<=high do
            local middle=math.floor((low+high)/2)
            if data[middle].y+metrics.rowHeight<=self.scroll then low=middle+1 else high=middle-1 end
        end
        local visible,visibleGroups=0,0
        for index=low,#data do
            local record=data[index]
            if record.groupY and record.groupY+20>self.scroll and record.groupY<self.scroll+viewport then
                visibleGroups=visibleGroups+1;self:Header(visibleGroups,record.sourceTitle,record.groupY)
            end
            if record.y>=self.scroll+viewport then break end
            visible=visible+1
            local row=self:Acquire(visible)
            local y=record.y
            if row._y~=y then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);row._y=y end
            local identity=self.tab=="pins" and record.pin or record.instanceToken
            local rebound=row.providerID~=record.id or row.pinIndex~=record.pinIndex or row._bindingIdentity~=identity
            if rebound then
                row.hover:Hide();row.manage._hovered=false;row.manage:SetState("normal")
                row.toggle:FinishMotion()
                row._bindingGeneration=(row._bindingGeneration or 0)+1
                row.up._hovered,row.down._hovered,row.remove._hovered=false,false,false
                row.up:SetState("normal");row.down:SetState("normal");row.remove:SetState("normal")
            end
            row.providerID,row.pinIndex,row._bindingIdentity=record.id,record.pinIndex,identity
            if self.tab=="pins" then
                -- Resolve only visible pins, and retain no resolved catalog item.
                record.item=I.UserPreferences:Resolve(record.pin)
                local pin=record.pin
                record.title=record.item and record.item.text or type(pin)=="table" and (pin.title or pin.entryID) or tostring(pin)
            end
            local icon=rowIcon(record)
            if row._icon~=icon and row.icon:SetTexture(icon)~=false then row._icon=icon end
            text(row.name,record.title)
            if self.tab=="providers" then
                local global,prefixes,keywords=management:GetConfiguration(record.id,record.instanceToken)
                text(row.detail,(global==false and L["仅通过快捷入口"].." · "..(#keywords>0 and table.concat(keywords," / ") or (prefixes[1] or "").."：")
                    or record.description or L["全局搜索"]))
                text(row.state,"")
                if record.status and record.status~="user-disabled" then
                    text(row.detail,record.statusReason or record.status=="incompatible" and L["版本不兼容"] or record.status=="pending" and L["尚未加载"]
                        or record.status=="user-disabled" and L["已关闭"] or L["扩展自行停用"])
                end
                row.toggle:SetChecked(record.userEnabled,rebound)
            else
                text(row.detail,record.item and displayTitle(record.item.sourceTitle, "") or L["来源已关闭或条目暂不可用"])
                text(row.state,"")
                row.up:SetEnabled(index>1);row.down:SetEnabled(index<#data)
            end
            shown(row.manage.frame,self.tab=="providers")
            shown(row.toggle,self.tab=="providers");shown(row.up.frame,self.tab=="pins");shown(row.down.frame,self.tab=="pins");shown(row.remove.frame,self.tab=="pins")
            record.item=nil
            shown(row,true)
        end
        for index=visible+1,#self.rows do
            local row=self.rows[index];releaseIdentity(row)
            if row._icon~=nil and row.icon:SetTexture(nil)~=false then row._icon=nil end
            shown(row,false)
        end
        if #data==0 then visibleGroups=1 end
        for index=visibleGroups+1,#self.groups do shown(self.groups[index],false) end
    end
    function view:OpenAliases(ref,title)
        if not frame:IsShown() or InCombatLockdown() then return false end
        if not self.aliasView then self.aliasView=Lychee.UI.AliasSettings:Create(frame,controller,function() view:SetTab("general") end) end
        if self.providerView then self.providerView.frame:Hide() end
        if self.general then self.general:Hide() end
        if self.about then self.about:Hide() end
        scroll:Hide();self.undo.frame:Hide()
        self.aliasView:Show(ref,title)
        for _,tab in pairs(self.tabs) do tab.frame:Hide() end
        self.underline:Hide()
        return true
    end
    function view:OpenProvider(id,icon)
        if not frame:IsShown() or InCombatLockdown() or not management:GetInstance(id) then return end
        if not self.providerView then self.providerView=Lychee.UI.ProviderSettings:Create(frame,controller,function() view:Refresh();controller:SetStatusText(L["更改即时生效"]) end) end
        if self.aliasView then self.aliasView.frame:Hide() end
        if self.general then self.general:Hide() end
        if self.about then self.about:Hide() end
        scroll:Hide();self.undo.frame:Hide()
        self.providerView:Show(id,icon)
        if controller.ResizeForMode then controller:ResizeForMode("settings") end
        for _,tab in pairs(self.tabs) do tab.frame:Hide() end
        self.underline:Hide()
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(self.providerView.frame,"page") end
    end
    view.social=Lychee.UI.SocialLinks:Create(frame,controller)
    return view
end
