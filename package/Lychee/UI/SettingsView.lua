local L = _G.LycheeInternal.Locale
local I, Lychee = _G.LycheeInternal, _G.Lychee
local Settings = {}
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
local builtinOrder = { ["builtin.player-spells"]=1, ["builtin.mounts"]=2, ["builtin.bosses"]=3,
    ["builtin.game-menus"]=4,["builtin.crests"]=5,["builtin.great-vault"]=6,
    ["builtin.bags"]=7,["builtin.talent-loadouts"]=8,["builtin.equipment-sets"]=9,
    ["builtin.blizzard-settings"]=10,["builtin.keystones"]=11,["builtin.achievements"]=12,["builtin.addon-inspector"]=13 }
local providerDescriptions = {
    ["builtin.bags"]=L["搜索物品并定位背包"],
    ["builtin.talent-loadouts"]=L["搜索并切换天赋方案"],
    ["builtin.equipment-sets"]=L["搜索并切换装备方案"],
    ["builtin.blizzard-settings"]=L["定位设置、重载界面与冷却管理器"],
    ["builtin.keystones"]=L["队伍钥匙、分数与副本传送"],
    ["builtin.achievements"]=L["搜索成就、查看进度与分享链接"],
    ["builtin.addon-inspector"]=L["指向界面，识别来源插件"],
}
local iconRoot = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
local providerIcons = {
    ["builtin.player-spells"] = iconRoot .. "spellbook.tga",
    ["builtin.mounts"] = iconRoot .. "mounts.tga",
    ["builtin.bosses"] = iconRoot .. "skull.tga",
    ["builtin.game-menus"] = iconRoot .. "game-menu.tga",
    ["builtin.crests"] = iconRoot .. "currency.tga",
    ["builtin.great-vault"] = iconRoot .. "great-vault.tga",
    ["builtin.bags"] = iconRoot .. "toys.tga",
    ["builtin.talent-loadouts"] = iconRoot .. "talents.tga",
    ["builtin.equipment-sets"] = iconRoot .. "character.tga",
    ["builtin.blizzard-settings"] = iconRoot .. "settings.tga",
    ["builtin.keystones"] = iconRoot .. "keystone.tga",
    ["builtin.achievements"] = iconRoot .. "achievements.tga",
    ["builtin.addon-inspector"] = iconRoot .. "addon-inspector.tga",
}
local function rowIcon(record)
    local pin = type(record.pin) == "table" and record.pin or nil
    local icon = record.item and record.item.icon or pin and pin.icon
    if type(icon) == "string" and icon ~= "" or type(icon) == "number" and icon > 0 then return icon end
    return providerIcons[record.id or pin and pin.providerID] or iconRoot .. "settings.tga"
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
    local sourceTab=button(frame,L["功能来源"],86,function() view:SetTab("providers") end)
    sourceTab.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset,-2)
    local pinsTab=button(frame,L["已固定"],86,function() view:SetTab("pins") end)
    pinsTab.frame:SetPoint("LEFT",sourceTab.frame,"RIGHT",12,0)
    local generalTab=button(frame,L["综合设置"],86,function() view:SetTab("general") end)
    generalTab.frame:SetPoint("LEFT",pinsTab.frame,"RIGHT",12,0)
    view.tabs={providers=sourceTab,pins= pinsTab,general=generalTab}
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
        view.dragIndex,view.data=nil,nil
        for _,row in ipairs(view.rows) do releaseIdentity(row) end
    end)
    local function currentClick(control,row)
        local generation=control._pressGeneration
        control._pressGeneration=nil
        if generation~=nil and generation~=row._bindingGeneration then return false end
        if not frame:IsShown() or not row:IsShown() or (InCombatLockdown and InCombatLockdown()) then return false end
        if row.providerID then return I.Providers.entries[row.providerID]==row._bindingIdentity end
        return row.pinIndex~=nil and I.UserPreferences:GetPins()[row.pinIndex]==row._bindingIdentity
    end

    function view:Acquire(index)
        if self.rows[index] then return self.rows[index] end
        local row=CreateFrame("Button",nil,content);row:SetSize(rowWidth,metrics.rowHeight)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(metrics.iconSize,metrics.iconSize);row.icon:SetPoint("LEFT",row,"LEFT",metrics.listIconInset,0)
        row.name=label(row,"body");row.name:SetPoint("TOPLEFT",row,"TOPLEFT",metrics.listTitleInset,-7);row.name:SetPoint("RIGHT",row,"RIGHT",-188,0);row.name:SetHeight(17)
        row.detail=label(row,"meta","textMuted");row.detail:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-3);row.detail:SetPoint("RIGHT",row,"RIGHT",-180,0);row.detail:SetHeight(14)
        row.state=label(row,"meta","textMuted");row.state:SetPoint("RIGHT",row,"RIGHT",-54,0);row.state:SetWidth(118);row.state:SetJustifyH("RIGHT")
        row.toggle=Lychee.UI.Components:CreateToggle(row);row.toggle:SetPoint("RIGHT",row,"RIGHT",-metrics.listIconInset,0)
        row.toggle:SetScript("OnClick",function()
            if not currentClick(row.toggle,row) then return end
            if not row.providerID then return end
            local source=I.Registry.entries[row.providerID]
            if not source then return end
            local ok,err=I.Registry:SetUserEnabled(row.providerID,not source.userEnabled)
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
        if Lychee.UI.Motion then
            Lychee.UI.Motion:Cancel(content,true)
            if self.general then Lychee.UI.Motion:Cancel(self.general,true) end
        end
        self.tab=tab;self.scroll=0;scroll:SetVerticalScroll(0);self:Refresh()
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(tab=="general" and self.general or content,"page") end
    end
    function view:Refresh()
        if InCombatLockdown and InCombatLockdown() then return end
        for id,tab in pairs(self.tabs) do tab:SetSelected(id==self.tab) end
        if self._underlineTab~=self.tab then self.underline:ClearAllPoints();self.underline:SetPoint("BOTTOM",self.tabs[self.tab].frame,"BOTTOM",0,-3);self._underlineTab=self.tab end
        shown(self.undo.frame,self.tab=="pins" and self.removed~=nil)
        shown(scroll,self.tab~="general")
        if self.tab=="general" then
            self.data=nil
            for _,row in ipairs(self.rows) do releaseIdentity(row);shown(row,false) end
            if not self.general then
                local general=CreateFrame("Frame",nil,frame);self.general=general
                general:SetSize(rowWidth,metrics.rowHeight)
                general:SetPoint("TOPLEFT",frame,"TOPLEFT",metrics.listInset,-metrics.settingsTabsHeight)
                local icon=general:CreateTexture(nil,"ARTWORK");icon:SetSize(metrics.iconSize,metrics.iconSize)
                icon:SetPoint("LEFT",general,"LEFT",metrics.listIconInset,0);icon:SetTexture(iconRoot.."settings.tga")
                local title=label(general,"body");title:SetPoint("TOPLEFT",general,"TOPLEFT",metrics.listTitleInset,-7);title:SetText(L["动态效果"])
                local detail=label(general,"meta","textMuted");detail:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-3);detail:SetText(L["窗口、页面与控件的过渡动画"])
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
            for id,provider in pairs(I.Providers.entries) do
                local state=I.Registry.entries[id]
                if id~="lychee.settings" and state then
                    count=count+1
                    local record=data[count] or {};data[count]=record
                    if record.pinIndex~=nil then record.pin,record.pinIndex=nil,nil end
                    record.id,record.state,record.provider=id,state,provider
                    record.title,record.version=displayTitle(provider.definition.title,id),provider.definition.version
                    record.builtin,record.order=builtinOrder[id]~=nil,builtinOrder[id] or 100
                end
            end
            for index=#data,count+1,-1 do data[index]=nil end
            table.sort(data,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
        else
            I.UserPreferences:MigratePins()
            for index,pin in ipairs(I.UserPreferences:GetPins()) do
                count=count+1
                local record=data[count] or {};data[count]=record
                record.id,record.state,record.title,record.version,record.builtin,record.order=nil,nil,nil,nil,nil,nil
                record.provider=nil
                record.pin,record.pinIndex=pin,index
            end
            for index=#data,count+1,-1 do data[index]=nil end
        end
        local y,groupCount,lastGroup=0,0,nil
        for index,record in ipairs(data) do
            if self.tab=="providers" then
                local group=record.builtin and L["内置"] or L["第三方"]
                if group~=lastGroup then
                    if lastGroup then y=y+12 end
                    groupCount=groupCount+1;self:Header(groupCount,group,y);y=y+23;lastGroup=group
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
        local visible=0
        for index=low,#data do
            local record=data[index]
            if record.y>=self.scroll+viewport then break end
            visible=visible+1
            local row=self:Acquire(visible)
            local y=record.y
            if row._y~=y then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);row._y=y end
            local identity=self.tab=="pins" and record.pin or record.provider
            local rebound=row.providerID~=record.id or row.pinIndex~=record.pinIndex or row._bindingIdentity~=identity
            if rebound then
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
                local state=record.state
                text(row.detail,providerDescriptions[record.id] or (record.builtin and L["内置功能"] or record.id).."  ·  "..tostring(record.version or ""))
                text(row.state,state.incompatible and L["版本不兼容"] or state.state=="pending" and L["尚未加载"] or state.userEnabled==false and L["已关闭"] or state.ownerEnabled==false and L["扩展自行停用"] or L["已启用"])
                row.toggle:SetChecked(state.userEnabled,rebound)
            else
                text(row.detail,record.item and displayTitle(record.item.sourceTitle, "") or L["来源已关闭或条目暂不可用"])
                text(row.state,"")
                row.up:SetEnabled(index>1);row.down:SetEnabled(index<#data)
            end
            shown(row.toggle,self.tab=="providers");shown(row.up.frame,self.tab=="pins");shown(row.down.frame,self.tab=="pins");shown(row.remove.frame,self.tab=="pins")
            record.item=nil
            shown(row,true)
        end
        for index=visible+1,#self.rows do
            local row=self.rows[index];releaseIdentity(row)
            if row._icon~=nil and row.icon:SetTexture(nil)~=false then row._icon=nil end
            shown(row,false)
        end
    end
    return view
end
