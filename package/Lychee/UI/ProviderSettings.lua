local I,UI=_G.LycheeInternal,_G.Lychee.UI
local L=I.Locale
local CLIENTS={retail="正式服",classic="经典怀旧服",titan="泰坦重铸",anniversary="周年纪念服"}
local P={};UI.ProviderSettings=P
function P:Create(parent,controller,onBack)
    local metrics=UI.Theme.Metrics
    local width=metrics.resultTileWidth-metrics.listInset
    local view={generation=0};local outer=CreateFrame("Frame",nil,parent);view.frame=outer
    outer:SetPoint("TOPLEFT",parent,"TOPLEFT",metrics.listInset,-metrics.settingsTabsHeight)
    outer:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-metrics.listInset,2);outer:Hide()
    local scroll=CreateFrame("ScrollFrame",nil,outer);scroll:SetAllPoints(outer)
    local frame=CreateFrame("Frame",nil,scroll);frame:SetSize(width,444);scroll:SetScrollChild(frame)
    local bar
    bar=UI.Components:CreateScrollbar(scroll,function(value) bar.value=value;scroll:SetVerticalScroll(value) end)
    bar.frame:ClearAllPoints();bar.frame:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-metrics.settingsTabsHeight);bar.frame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,2)
    local function range() bar:SetRange(444,scroll:GetHeight(),bar.value);scroll:SetVerticalScroll(bar.value) end
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
    local function button(value,x,y,w,fn)
        local b
        b=UI.Components:CreateNavigationButton(frame,{text=value,width=w,height=28,onClick=function()
            local pressed=b.press;b.press=nil
            if current() and (pressed==nil or pressed==view.generation) then fn() end
        end})
        local previous=b.frame.GetScript and b.frame:GetScript("OnMouseDown")
        b.frame:SetScript("OnMouseDown",function(...)
            b.press=view.generation;if previous then previous(...) end
        end)
        b.frame:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y);return b
    end
    view.back=button(L["返回功能来源"],0,0,150,function() outer:Hide();onBack() end)
    view.icon=frame:CreateTexture(nil,"ARTWORK");view.icon:SetSize(metrics.iconSize,metrics.iconSize);view.icon:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-42)
    view.title=label("",42,-42,width-110);UI.Theme:SetTextColor(view.title,"text")
    view.detail=label("",42,-66,width-50,"meta")
    view.toggle=UI.Components:CreateToggle(frame);view.toggle:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-46)
    view.toggle:SetScript("OnClick",function()
        local pressed=view.toggle.press;view.toggle.press=nil
        if not current() or pressed~=nil and pressed~=view.generation then return end
        local state=I.Registry.entries[view.id]
        local ok,err=I.Registry:SetUserEnabled(view.id,not state.userEnabled)
        if not ok then controller:ReportActionResult(false,err);return end
        controller:MarkHomeDirty();view:Refresh()
    end)
    view.toggle:SetScript("OnMouseDown",function() view.toggle.press=view.generation end)
    label(L["搜索方式"],0,-108)
    view.choices={}
    view.selection=frame:CreateTexture(nil,"ARTWORK");view.selection:SetSize(132,2);UI.Theme:SetColorTexture(view.selection,"accent")
    for index,choice in ipairs({{"default","跟随默认"},{"global","全局搜索"},{"prefix","仅前缀搜索"}}) do
        local mode,title=choice[1],choice[2]
        view.choices[mode]=button(L[title],(index-1)*150,-136,140,function()
            view.mode=mode;view:PaintChoice();controller:SetStatusText(L["点击保存应用搜索设置"])
        end)
    end
    view.help=label("",0,-174,width);view.help:SetHeight(36)
    label(L["搜索前缀"],0,-216)
    local input=CreateFrame("EditBox",nil,frame);view.input=input
    input:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-244);input:SetSize(width-8,34)
    input:SetAutoFocus(false);input:SetTextInsets(10,10,0,0);UI.Theme:SetFont(input,"input");UI.Theme:SetTextColor(input,"text")
    if input.SetMaxBytes then input:SetMaxBytes(400) end
    local bg=input:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints(input);UI.Theme:SetColorTexture(bg,"surfaceSelected")
    view.example=label("",0,-285,width,"meta")
    view.error=label("",0,-351,width,"meta");view.error:SetHeight(34);UI.Theme:SetTextColor(view.error,"warning")
    local function save()
        if not current() or view.entry.definition.searchable==false then return end
        local raw=input:GetText();local list={}
        for value in raw:gsub("，",","):gmatch("[^,]+") do list[#list+1]=value end
        local mode=view.mode~="default" and view.mode or nil
        local original=table.concat(I.Search.ProviderPolicy:Defaults(view.id,view.entry.definition),", ")
        local custom=raw~=original and list or nil
        local ok,err=I.Search.ProviderPolicy:Set(view.id,mode,custom)
        if not ok then view.error:SetText(L[err]);return end
        input:ClearFocus();controller:SetStatusText(L["搜索设置已保存"]);view:Refresh()
    end
    view.save=button(L["保存"],0,-316,72,save)
    view.reset=button(L["恢复默认"],96,-316,110,function()
        local ok,err=I.Search.ProviderPolicy:Set(view.id,nil,nil)
        if ok then view:Refresh() else view.error:SetText(L[err]) end
    end)
    view.technical=label("",0,-394,width,"meta");view.technical:SetHeight(44)
    input:SetScript("OnEnterPressed",save)
    input:SetScript("OnEscapePressed",function() if current() then input:ClearFocus();outer:Hide();onBack() end end)
    input:SetScript("OnTextChanged",function(_,userInput)
        if userInput then controller:SetStatusText(L["点击保存应用搜索设置"]) end
        local prefix=(input:GetText():gsub("，",","):match("^[^,]+") or ""):match("^%s*(.-)%s*$")
        view.example:SetText(prefix~="" and L:Format("搜索示例：%s：关键词",prefix) or L["多个前缀用逗号分隔"])
    end)
    function view:PaintChoice()
        for mode,control in pairs(self.choices) do control:SetState(mode==self.mode and "hover" or "normal") end
        self.selection:ClearAllPoints();self.selection:SetPoint("TOPLEFT",frame,"TOPLEFT",(self.mode=="global" and 150 or self.mode=="prefix" and 300 or 0)+4,-165)
        self.selection:SetShown(self.entry.definition.searchable~=false)
    end
    function view:Refresh()
        if not current() then return end
        local policy=I.Search.ProviderPolicy;local definition=self.entry.definition
        local state=I.Registry.entries[self.id];self.toggle:SetChecked(state.userEnabled,true)
        local row=policy:Override(self.id);local effective,list=policy:Effective(self.id,definition)
        self.mode=row and row.mode or "default"
        local independent=definition.searchable==false
        self.help:SetText(independent and L["独立查询入口，由功能自身决定触发词"] or L:Format("默认：%s；多个前缀用逗号分隔",L[definition.searchMode=="prefix" and "仅前缀搜索" or "全局搜索"]))
        for _,b in pairs(self.choices) do b:SetEnabled(not independent) end
        self.save:SetEnabled(not independent);self.reset:SetEnabled(not independent)
        input:SetText(table.concat(list,", "));input:ClearFocus();input:EnableMouse(not independent)
        if input.EnableKeyboard then input:EnableKeyboard(not independent) end
        if independent then input:SetText("") end
        self.error:SetText("");self:PaintChoice()
        local clients={}
        for _,product in ipairs(definition.scope.products or {definition.scope.product or "retail"}) do clients[#clients+1]=L[CLIENTS[product] or product] end
        self.technical:SetText(L["版本"].." "..tostring(definition.version).."  ·  "..table.concat(clients,", ").."\n"..self.id)
    end
    function view:Show(id,icon,description)
        self.id,self.entry=id,I.Providers.entries[id]
        self.generation=self.generation+1;outer:Show();bar.value=0;scroll:SetVerticalScroll(0);range()
        self.icon:SetTexture(icon);self.title:SetText(self.entry.definition.title);self.detail:SetText(description or "");self:Refresh()
        controller:SetStatusText(L["点击保存应用搜索设置"])
    end
    outer:SetScript("OnHide",function()
        input:ClearFocus();bar:StopDrag();if UI.Motion then UI.Motion:Cancel(outer,true) end
        view.generation=view.generation+1;view.id,view.entry=nil,nil
    end)
    return view
end
