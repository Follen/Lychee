local I, Lychee = _G.LycheeInternal, _G.Lychee
local Settings = {}
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
    local control = Lychee.UI.Components:CreateButton(parent, {width=width, height=28, text=title,
        colors={normal="transparent",hover="surfaceHover",pressed="surfaceSelected",disabled="transparent"},
        textColors={normal="textMuted",hover="text",pressed="text",disabled="disabled"},onClick=callback})
    Lychee.UI.Theme:SetFont(control.label,"body")
    return control
end
local builtinOrder = { ["builtin.player-spells"]=1, ["builtin.mounts"]=2, ["builtin.bosses"]=3,
    ["builtin.game-menus"]=4,["builtin.crests"]=5,["builtin.great-vault"]=6 }
local iconRoot = "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
local providerIcons = {
    ["builtin.player-spells"] = iconRoot .. "spellbook.tga",
    ["builtin.mounts"] = iconRoot .. "mounts.tga",
    ["builtin.bosses"] = iconRoot .. "journal-dungeons.tga",
    ["builtin.game-menus"] = iconRoot .. "game-menu.tga",
    ["builtin.crests"] = iconRoot .. "currency.tga",
    ["builtin.great-vault"] = iconRoot .. "great-vault.tga",
}
local function rowIcon(record)
    local pin = type(record.pin) == "table" and record.pin or nil
    local icon = record.item and record.item.icon or pin and pin.icon
    if type(icon) == "string" and icon ~= "" or type(icon) == "number" and icon > 0 then return icon end
    return providerIcons[record.id or pin and pin.providerID] or iconRoot .. "settings.tga"
end
local function displayTitle(value, fallback)
    if type(value)=="string" then return value end
    if type(value)=="table" then return value[GetLocale and GetLocale() or "enUS"] or value.default or value.enUS or fallback end
    return fallback
end

function Settings:Create(parent, controller)
    local view = {controller=controller, rows={}, groups={}, tab="providers",scroll=0}
    local frame=CreateFrame("Frame",nil,parent);frame:SetAllPoints(parent);frame:Hide();view.frame=frame
    local sourceTab=button(frame,"功能来源",86,function() view:SetTab("providers") end)
    sourceTab.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-2)
    local pinsTab=button(frame,"已固定",86,function() view:SetTab("pins") end)
    pinsTab.frame:SetPoint("LEFT",sourceTab.frame,"RIGHT",12,0)
    view.tabs={providers=sourceTab,pins=pinsTab}
    view.underline=frame:CreateTexture(nil,"ARTWORK");view.underline:SetSize(60,2)
    Lychee.UI.Theme:SetColorTexture(view.underline,"accent")
    view.add=button(frame,"＋ 添加固定",94,function() controller:CloseSettings(true);controller:SetStatusText("搜索条目后，右键选择固定到首页") end)
    view.add.frame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-2)
    view.undo=button(frame,"撤销",48,function()
        if view.removed and I.UserPreferences:Restore(view.removed,view.removedIndex) then
            view.removed=nil;controller:MarkHomeDirty();view:Refresh();controller:SetStatusText("已恢复固定")
        end
    end)
    view.undo.frame:SetPoint("RIGHT",view.add.frame,"LEFT",-6,0);view.undo.frame:Hide()
    local scroll=CreateFrame("ScrollFrame",nil,frame);scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-42);scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-8,0)
    local content=CreateFrame("Frame",nil,scroll);content:SetSize(592,1);scroll:SetScrollChild(content)
    view.scrollFrame,view.content=scroll,content
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    scroll:SetScript("OnMouseWheel",function(_,delta)
        local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
        local value=math.max(0,math.min(maximum,view.scroll-delta*46))
        if value~=view.scroll then view.scroll=value;scroll:SetVerticalScroll(value) end
    end)
    frame:SetScript("OnHide",function() view.dragIndex=nil end)

    function view:Acquire(index)
        if self.rows[index] then return self.rows[index] end
        local row=CreateFrame("Button",nil,content);row:SetSize(592,46)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(28,28);row.icon:SetPoint("LEFT",row,"LEFT",10,0)
        row.name=label(row,"body");row.name:SetPoint("TOPLEFT",row,"TOPLEFT",50,-7);row.name:SetPoint("RIGHT",row,"RIGHT",-188,0);row.name:SetHeight(17)
        row.detail=label(row,"meta","textMuted");row.detail:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-3);row.detail:SetPoint("RIGHT",row,"RIGHT",-180,0);row.detail:SetHeight(14)
        row.state=label(row,"meta","textMuted");row.state:SetPoint("RIGHT",row,"RIGHT",-54,0);row.state:SetWidth(118);row.state:SetJustifyH("RIGHT")
        row.line=row:CreateTexture(nil,"BACKGROUND");row.line:SetHeight(1);row.line:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",8,0);row.line:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-8,0);Lychee.UI.Theme:SetColorTexture(row.line,"border")
        row.toggle=CreateFrame("Button",nil,row);row.toggle:SetSize(30,18);row.toggle:SetPoint("RIGHT",row,"RIGHT",-10,0)
        row.toggle.bg=row.toggle:CreateTexture(nil,"BACKGROUND");row.toggle.bg:SetAllPoints()
        row.toggle.knob=row.toggle:CreateTexture(nil,"ARTWORK");row.toggle.knob:SetSize(12,12);Lychee.UI.Theme:SetColorTexture(row.toggle.knob,"text")
        row.toggle:SetScript("OnClick",function()
            if not row.providerID then return end
            local source=I.Registry.entries[row.providerID]
            if not source then return end
            local ok,err=I.Registry:SetUserEnabled(row.providerID,not source.userEnabled)
            if not ok then controller:ReportActionResult(false,err);return end
            controller:MarkHomeDirty();self:Refresh();controller:SetStatusText("更改已保存，固定记录保留")
        end)
        row.up=button(row,"上移",40,function() self:Move(row.pinIndex,-1) end);row.up.frame:SetPoint("RIGHT",row,"RIGHT",-132,0)
        row.down=button(row,"下移",40,function() self:Move(row.pinIndex,1) end);row.down.frame:SetPoint("RIGHT",row,"RIGHT",-88,0)
        row.remove=button(row,"取消固定",76,function()
            if not row.pinIndex then return end
            self.removedIndex=row.pinIndex;self.removed=I.UserPreferences:Remove(row.pinIndex)
            controller:MarkHomeDirty();self:Refresh();controller:SetStatusText("已取消固定，可以撤销")
        end);row.remove.frame:SetPoint("RIGHT",row,"RIGHT",-8,0)
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart",function() if self.tab=="pins" then self.dragIndex=row.pinIndex end end)
        row:SetScript("OnDragStop",function()
            local from=self.dragIndex;self.dragIndex=nil
            if not from then return end
            for _,target in ipairs(self.rows) do
                if target:IsShown() and target.pinIndex and target.IsMouseOver and target:IsMouseOver() then
                    if I.UserPreferences:Move(from,target.pinIndex) then controller:MarkHomeDirty();self:Refresh();controller:SetStatusText("固定顺序已保存") end
                    break
                end
            end
        end)
        self.rows[index]=row;return row
    end
    function view:Move(index,delta)
        if index and I.UserPreferences:Move(index,index+delta) then controller:MarkHomeDirty();self:Refresh();controller:SetStatusText("固定顺序已保存") end
    end
    function view:Header(index,title,y)
        local header=self.groups[index]
        if not header then header=label(content,"meta","textMuted");self.groups[index]=header end
        if header._y~=y then header:ClearAllPoints();header:SetPoint("TOPLEFT",content,"TOPLEFT",10,-y);header._y=y end
        text(header,title);shown(header,true)
    end
    function view:SetTab(tab)
        self.tab=tab;self.scroll=0;scroll:SetVerticalScroll(0);self:Refresh()
    end
    function view:Refresh()
        if InCombatLockdown and InCombatLockdown() then return end
        for id,tab in pairs(self.tabs) do Lychee.UI.Theme:SetTextColor(tab.label,id==self.tab and "text" or "textMuted") end
        if self._underlineTab~=self.tab then self.underline:ClearAllPoints();self.underline:SetPoint("BOTTOM",self.tabs[self.tab].frame,"BOTTOM",0,-3);self._underlineTab=self.tab end
        shown(self.add.frame,self.tab=="pins");shown(self.undo.frame,self.tab=="pins" and self.removed~=nil)
        local data={}
        if self.tab=="providers" then
            for id,provider in pairs(I.Providers.entries) do
                local state=I.Registry.entries[id]
                if id~="lychee.settings" and state then data[#data+1]={id=id,state=state,title=displayTitle(provider.definition.title,id),version=provider.definition.version,
                    builtin=builtinOrder[id]~=nil,order=builtinOrder[id] or 100} end
            end
            table.sort(data,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
        else
            I.UserPreferences:MigratePins()
            for index,pin in ipairs(I.UserPreferences:GetPins()) do
                local item=I.UserPreferences:Resolve(pin)
                data[#data+1]={pin=pin,pinIndex=index,item=item,title=item and item.text or type(pin)=="table" and (pin.title or pin.entryID) or tostring(pin)}
            end
        end
        local y,groupCount,lastGroup=0,0,nil
        for index,record in ipairs(data) do
            if self.tab=="providers" then
                local group=record.builtin and "内置" or "第三方"
                if group~=lastGroup then
                    if lastGroup then y=y+12 end
                    groupCount=groupCount+1;self:Header(groupCount,group,y);y=y+23;lastGroup=group
                end
            end
            local row=self:Acquire(index)
            if row._y~=y then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);row._y=y end
            row.providerID,row.pinIndex=record.id,record.pinIndex
            local icon=rowIcon(record)
            if row._icon~=icon and row.icon:SetTexture(icon)~=false then row._icon=icon end
            text(row.name,record.title)
            if self.tab=="providers" then
                local state=record.state
                text(row.detail,(record.builtin and "内置功能" or record.id).."  ·  "..tostring(record.version or ""))
                text(row.state,state.incompatible and "版本不兼容" or state.state=="pending" and "尚未加载" or state.userEnabled==false and "已关闭" or state.ownerEnabled==false and "扩展自行停用" or "已启用")
                Lychee.UI.Theme:SetColorTexture(row.toggle.bg,state.userEnabled and "accent" or "disabled")
                if row.toggle._enabled~=state.userEnabled then
                    row.toggle.knob:ClearAllPoints();row.toggle.knob:SetPoint("LEFT",row.toggle,"LEFT",state.userEnabled and 15 or 3,0);row.toggle._enabled=state.userEnabled
                end
            else
                text(row.detail,record.item and displayTitle(record.item.sourceTitle, "") or "来源已关闭或条目暂不可用")
                text(row.state,"")
                row.up:SetEnabled(index>1);row.down:SetEnabled(index<#data)
            end
            shown(row.toggle,self.tab=="providers");shown(row.up.frame,self.tab=="pins");shown(row.down.frame,self.tab=="pins");shown(row.remove.frame,self.tab=="pins")
            shown(row,true);y=y+46
        end
        for index=#data+1,#self.rows do
            local row=self.rows[index];row.providerID,row.pinIndex=nil,nil
            if row._icon~=nil and row.icon:SetTexture(nil)~=false then row._icon=nil end
            shown(row,false)
        end
        if #data==0 then groupCount=1;self:Header(1,self.tab=="pins" and "还没有固定项。搜索条目后，右键固定到首页。" or "没有已接入的功能来源",12) end
        for index=groupCount+1,#self.groups do shown(self.groups[index],false) end
        local height=math.max(40,y+12);if content:GetHeight()~=height then content:SetHeight(height) end
        local maximum=math.max(0,height-scroll:GetHeight());if self.scroll>maximum then self.scroll=maximum;scroll:SetVerticalScroll(maximum) end
    end
    return view
end
