local I=_G.LycheeInternal
local M=I.ProviderModules.LDT
local S=M.Survival
local L=I.ProviderLocales:Module(M.id)
local groupNames={"单体外援","团队增益","团队主动"}
local function amount(value) return value and string.format("%.0f",value) or "—" end
function M:CreateSurvivalView(owner)
    if owner.calculator then return owner.calculator end
    local C,Theme=_G.Lychee.UI.Components,_G.Lychee.UI.Theme
    local v={rows={},tabs={},selected={},group=1,level=10,contentHeight=388}
    owner.calculator=v
    v.toolbar=CreateFrame("Frame",nil,owner.frame);v.toolbar:SetPoint("TOPLEFT",16,-60);v.toolbar:SetPoint("RIGHT",-16,0);v.toolbar:SetHeight(30);v.toolbar:Hide()
    v.viewport=CreateFrame("ScrollFrame",nil,owner.frame);v.viewport:SetPoint("TOPLEFT",16,-98);v.viewport:SetPoint("BOTTOMRIGHT",-4,0);v.viewport:Hide()
    v.frame=CreateFrame("Frame",nil,v.viewport);v.frame:SetSize(584,v.contentHeight);v.viewport:SetScrollChild(v.frame)
    v.bar=C:CreateScrollbar(v.viewport,function(value)
        v.viewport:SetVerticalScroll(value)
        v.bar:SetRange(v.contentHeight,v.viewport:GetHeight(),value)
    end)
    local function resize()
        v.bar:SetRange(v.contentHeight,v.viewport:GetHeight(),v.bar.value or 0)
        v.viewport:SetVerticalScroll(v.bar.value)
    end
    local function wheel(_,delta)
        if v.active then C:HideTooltip();v.bar:SetValue((v.bar.value or 0)-delta*32) end
    end
    local function scrollable(frame) frame:EnableMouseWheel(true);frame:SetScript("OnMouseWheel",wheel) end
    v.viewport:SetScript("OnSizeChanged",resize);scrollable(v.viewport);scrollable(v.frame);scrollable(v.bar.frame)
    local function text(role,x,y,w,h,parent)
        local f=(parent or v.frame):CreateFontString(nil,"ARTWORK","GameFontHighlight")
        Theme:SetFont(f,role);Theme:SetTextColor(f,"textMuted");f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
        f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h);return f
    end
    local function button(caption,x,y,w,fn,direction,parent)
        local b=C:CreateNavigationButton(parent or v.frame,{text=caption,width=w,height=24,direction=direction,onClick=function()
            if v.active and owner.active and not (InCombatLockdown and InCombatLockdown()) then fn() end
        end});Theme:SetFont(b.label,"body");b.frame:SetPoint("TOPLEFT",x,-y);scrollable(b.frame);return b
    end
    function v:Layout()
        self.contentHeight=328;self.frame:SetHeight(self.contentHeight)
        self.effects:ClearAllPoints();self.effects:SetPoint("TOPLEFT",0,-100)
        resize()
        if owner.context then owner.context:Resize(470) end
    end
    function v:Refresh()
        if not self.active then return end
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        self:LoadDamage()
        self:Render()
    end
    function v:LoadDamage()
        if not self.active then return end
        local description=C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(owner.selected)
        self.input=S:Parse(description,self.input)
        self.input.confirmed=self.input.damageValid==true
        self.input.boss=owner.enemy.isBoss
        self.input.tooltipVers=self.stats.vers
        if not description then owner:Request(owner.selected) end
    end
    function v:Render()
        if not self.active then return end
        local stats,input=self.stats,self.input
        input.level=self.level
        self.levelLabel:SetText(L["层数"].." "..self.level)
        self.result=S:Calculate(stats,input,self.selected,self.result)
        local r=self.result
        self.values[1]:SetText(amount(r.health or stats.health))
        self.values[2]:SetText(amount(r.first))
        local status=r.status=="lethal" and "会致死" or r.status=="survives" and "可承受" or r.status=="noDirect" and "无首段直接伤害" or "伤害数据暂不可用"
        self.values[3]:SetText(L[status]);Theme:SetTextColor(self.values[3],r.status=="lethal" and "danger" or "text")
        self.summary:SetText(r.remaining and (r.remaining>0 and L:Format("承受后剩余生命 %s",amount(r.remaining)) or L:Format("超出生命 %s",amount(-r.remaining))) or L["自动读取技能伤害与自身属性"])
        self:RenderEffects()
    end
    function v:RenderEffects()
        local list=self.list or {};self.list=list
        for k=#list,1,-1 do list[k]=nil end
        for _,e in ipairs(S.effects) do if e.group==self.group then list[#list+1]=e end end
        for index,row in ipairs(self.rows) do
            row.frame:Hide();row.effect=nil;row.generation=(row.generation or 0)+1
            local e=list[index]
            if e then
                row.effect=e
                local active=self.stats.active[e.id]
                row.label:SetText(M:SpellName(e.id) or (L["技能"].." "..e.id))
                row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id) or "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\spellbook.tga")
                row:SetChecked(active or self.selected[e.id]==true)
                row:SetEnabled(not active);row.frame:Show()
            end
        end
        for i,b in ipairs(self.tabs) do b:SetSelected(i==self.group);b.indicator:SetShown(i==self.group) end
    end
    function v:Open()
        self.active=true;self.group=1
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        self:LoadDamage()
        self.name:SetText(M:SpellName(owner.selected) or L["技能"]);self.spellIcon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(owner.selected))
        owner:StopDrag();owner.model:Hide();owner.modelMessage:Hide();owner.reset.frame:Hide();owner.skillArea:Hide()
        owner.abilities:Hide();owner.previous.frame:Hide();owner.next.frame:Hide();owner.pageLabel:Hide();owner.survivalButton.frame:Hide()
        self.toolbar:Show();self.viewport:Show();self.frame:Show();self:Layout();self.bar:SetValue(0);self:Render();owner:SetHint(L["仅计算首段直接伤害"])
    end
    function v:Close()
        self.active=false;self.toolbar:Hide();self.spellIcon:SetTexture(nil);self.frame:Hide();self.viewport:Hide();self.bar:StopDrag()
        for _,row in ipairs(self.rows) do row.effect=nil;row.pressed=nil;row.icon:SetTexture(nil);row.label:SetText("");C:HideTooltip(row.frame) end
        for key in pairs(self.selected) do self.selected[key]=nil end
        self.stats,self.input,self.result,self.list=nil,nil,nil,nil
    end
    v.spellIcon=v.toolbar:CreateTexture(nil,"ARTWORK");v.spellIcon:SetSize(28,28);v.spellIcon:SetPoint("LEFT",0,0);v.spellIcon:SetTexCoord(.07,.93,.07,.93)
    v.name=text("title",38,5,304,20,v.toolbar);Theme:SetTextColor(v.name,"text");v.name:SetWordWrap(false)
    v.levelLabel=text("body",410,6,80,18,v.toolbar);v.levelLabel:SetJustifyH("CENTER")
    v.minus=button("−",378,0,28,function() v.level=math.max(0,v.level-1);v:Render() end,nil,v.toolbar)
    v.plus=button("+",496,0,28,function() v.level=math.min(35,v.level+1);v:Render() end,nil,v.toolbar)
    v.refresh=button(L["刷新"],536,0,48,function() v:Refresh() end,nil,v.toolbar)
    v.values={}
    for i,caption in ipairs({"生命值","直接承伤","是否致死"}) do
        text("meta",(i-1)*196,8,188,18):SetText(L[caption])
        v.values[i]=text("title",(i-1)*196,34,188,26);Theme:SetTextColor(v.values[i],"text")
    end
    v.summary=text("meta",0,68,584,20)
    v.effects=CreateFrame("Frame",nil,v.frame);v.effects:SetSize(584,228);scrollable(v.effects)
    for i,caption in ipairs(groupNames) do
        v.tabs[i]=button(L[caption],(i-1)*196,0,188,function() v.group=i;v:RenderEffects() end,nil,v.effects)
        local tab=v.tabs[i]
        tab.label:ClearAllPoints();tab.label:SetPoint("CENTER",0,0);tab.label:SetSize(180,18);tab.label:SetJustifyH("CENTER")
        tab.indicator=tab.frame:CreateTexture(nil,"ARTWORK");tab.indicator:SetPoint("TOP",tab.label,"BOTTOM",0,-5);tab.indicator:SetSize(28,2);Theme:SetColorTexture(tab.indicator,"accentHover")
    end
    for i=1,12 do
        local row
        row=C:CreateCheckbox(v.effects,{width=284,height=28,onClick=function()
            if not v.active or not owner.active or (InCombatLockdown and InCombatLockdown()) then return end
            if row.pressed~=row.generation or not row.effect then return end
            row.pressed=nil;local id=row.effect.id;v.selected[id]=not v.selected[id];v:Render()
        end})
        row.frame:SetPoint("TOPLEFT",((i-1)%2)*294,-(36+math.floor((i-1)/2)*32));scrollable(row.frame)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",36,0);row.label:SetPoint("RIGHT",-30,0);row.label:SetHeight(18);row.label:SetJustifyH("LEFT")
        row.icon=row.frame:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",4,0);row.icon:SetSize(22,22);row.icon:SetTexCoord(.07,.93,.07,.93)
        row.frame:HookScript("OnMouseDown",function(_,mouse) if mouse=="LeftButton" then row.pressed=row.generation end end)
        row.frame:HookScript("OnHide",function() row.pressed=nil;C:HideTooltip(row.frame) end)
        row.frame:HookScript("OnEnter",function()
            local e=row.effect;if not v.active or not e then return end
            C:ShowTooltip(row.frame,{title=M:SpellName(e.id) or tostring(e.id),description=e.flaskRating and L:Format("模拟效果：全能提高 %d 点。",e.flaskRating) or C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(e.id),
                hint=v.stats.active[e.id] and L["当前已生效"] or e.flaskRating and L["已有增益自动计入，不重复叠加"] or e.absorb and L["吸收按自身生命与全能估算"] or e.id==357170 and L["只计即时减伤，延后伤害由治疗处理"] or L["勾选模拟此效果"]})
        end)
        row.frame:HookScript("OnLeave",function() C:HideTooltip(row.frame) end)
        v.rows[i]=row
    end
    return v
end
