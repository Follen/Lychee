local I=_G.LycheeInternal
local M=I.ProviderModules.LDT
local S=M.Survival
local L=I.ProviderLocales:Module(M.id)
local groupNames={"单体外援","团队增益","团队主动"}
local function amount(value)
    if not value then return "—" end
    local digits=string.format("%.0f",value)
    return (digits:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
end
function M:CreateSurvivalView(owner)
    if owner.calculator then return owner.calculator end
    local C,Theme=_G.Lychee.UI.Components,_G.Lychee.UI.Theme
    local v={rows={},tabs={},selected={},group=1,level=10,contentHeight=252}
    owner.calculator=v
    v.toolbar=CreateFrame("Frame",nil,owner.frame);v.toolbar:SetPoint("TOPLEFT",16,-12);v.toolbar:SetPoint("RIGHT",-16,0);v.toolbar:SetHeight(60);v.toolbar:Hide()
    v.viewport=CreateFrame("ScrollFrame",nil,owner.frame);v.viewport:SetPoint("TOPLEFT",16,-252);v.viewport:SetPoint("BOTTOMRIGHT",-4,0);v.viewport:Hide()
    v.results=CreateFrame("Frame",nil,owner.frame);v.results:SetPoint("TOPLEFT",16,-88);v.results:SetSize(584,104);v.results:Hide()
    Theme:CreateRoundedSurface(v.results,"field",8)
    v.controls=CreateFrame("Frame",nil,owner.frame);v.controls:SetPoint("TOPLEFT",16,-212);v.controls:SetSize(584,28);v.controls:Hide()
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
        local f=(parent or v.results):CreateFontString(nil,"ARTWORK","GameFontHighlight")
        Theme:SetFont(f,role);Theme:SetTextColor(f,"textMuted");f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
        f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h);return f
    end
    local function button(caption,x,y,w,fn,direction,parent)
        local b=C:CreateNavigationButton(parent or v.frame,{text=caption,width=w,height=24,direction=direction,onClick=function()
            if v.active and owner.active and not (InCombatLockdown and InCombatLockdown()) then fn() end
        end});Theme:SetFont(b.label,"body");b.frame:SetPoint("TOPLEFT",x,-y);scrollable(b.frame);return b
    end
    function v:Layout()
        local height=math.ceil(#self.list/2)*42
        if self.contentHeight~=height then self.contentHeight=height;self.frame:SetHeight(height);self.effects:SetHeight(height) end
        resize()
        if owner.context then owner.context:Resize(512) end
    end
    function v:Refresh()
        if not self.active then return end
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        self:LoadDamage()
        self:Render()
    end
    function v:LoadDamage()
        if not self.active then return end
        local descriptionID=S:DescriptionSpell(owner.selected)
        local description=C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(descriptionID)
        self.input=S:Parse(description,self.input,owner.selected)
        self.input.confirmed=self.input.damageValid==true
        self.input.boss=owner.enemy.isBoss
        self.input.tooltipVers=self.stats.vers
        if not description and not self.input.periodicOnly then owner:Request(descriptionID) end
    end
    function v:Render()
        if not self.active then return end
        local stats,input=self.stats,self.input
        input.level=self.level
        self.levelLabel:SetText(L:Format("%d 层",self.level))
        self.minus:SetEnabled(self.level>0);self.plus:SetEnabled(self.level<35)
        self.result=S:Calculate(stats,input,self.selected,self.result)
        local r=self.result
        self.values[1]:SetText(amount(r.health or stats.health))
        self.values[2]:SetText(amount(r.first))
        local status=r.status=="lethal" and "会致死" or r.status=="survives" and "可承受" or r.status=="noDirect" and "无首段直接伤害" or "伤害数据暂不可用"
        self.values[3]:SetText(L[status]);Theme:SetFont(self.values[3],(r.status=="lethal" or r.status=="survives") and "aboutBrand" or "body");Theme:SetTextColor(self.values[3],r.status=="lethal" and "danger" or r.status=="survives" and "success" or "text")
        self.lethalIcon:SetShown(r.status=="lethal");self.safeShort:SetShown(r.status=="survives");self.safeLong:SetShown(r.status=="survives")
        local hasIcon=r.status=="lethal" or r.status=="survives"
        -- Rounded UI pixels can otherwise ellipsize an exactly measured label.
        local width=math.min(160,math.ceil(self.values[3]:GetUnboundedStringWidth())+4)
        local x=476-width/2+(hasIcon and 12 or 0)
        if self.verdictX~=x or self.verdictWidth~=width then
            self.verdictX,self.verdictWidth=x,width
            self.values[3]:ClearAllPoints();self.values[3]:SetPoint("TOPLEFT",x,-42);self.values[3]:SetWidth(width)
            self.lethalIcon:ClearAllPoints();self.lethalIcon:SetPoint("TOPLEFT",x-24,-46)
            self.safeShort:ClearAllPoints();self.safeShort:SetPoint("TOPLEFT",x-22,-55)
            self.safeLong:ClearAllPoints();self.safeLong:SetPoint("TOPLEFT",x-18,-52)
        end
        self.summary:SetText(r.remaining and (r.remaining>0 and L:Format("承受后剩余生命 %s",amount(r.remaining)) or L:Format("超出生命 %s",amount(-r.remaining))) or L["自动读取技能伤害与自身属性"])
        local selected=0;for _,value in pairs(self.selected) do if value then selected=selected+1 end end
        self.resetSelection:SetEnabled(selected>0)
        self.resetSelection:SetText(selected>0 and L:Format("重置模拟 (%d)",selected) or L["勾选模拟减伤"])
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
        for i,b in ipairs(self.tabs) do
            b:SetSelected(i==self.group);b.indicator:SetShown(i==self.group)
            local width=math.ceil(b.label:GetUnboundedStringWidth())
            if b.indicatorWidth~=width then b.indicatorWidth=width;b.indicator:SetWidth(width) end
        end
        self:Layout()
    end
    function v:Open()
        self.active=true;self.group=1
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        self:LoadDamage()
        self.name:SetText(M:SpellName(owner.selected) or L["技能"]);self.spellIcon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(owner.selected))
        self.contextLabel:SetText(M:Name(owner.enemy).."  ·  "..M:Name(owner.dungeon))
        owner.title:Hide();owner.subtitle:Hide();owner.creatureMeta:Hide()
        owner:StopDrag();owner.model:Hide();owner.modelMessage:Hide();owner.reset.frame:Hide();owner.skillArea:Hide()
        owner.abilities:Hide();owner.previous.frame:Hide();owner.next.frame:Hide();owner.pageLabel:Hide();owner.survivalButton.frame:Hide()
        self.toolbar:Show();self.results:Show();self.controls:Show();self.viewport:Show();self.frame:Show();self.bar:SetValue(0);self:Render();owner:SetHint(L["仅计算首段直接伤害"])
    end
    function v:Close()
        self.active=false;self.results:Hide();self.controls:Hide();self.contextLabel:SetText("");owner.title:Show();owner.subtitle:Show();owner.creatureMeta:Show();C:HideTooltip(self.refresh.frame);self.toolbar:Hide();self.spellIcon:SetTexture(nil);self.frame:Hide();self.viewport:Hide();self.bar:StopDrag()
        for _,row in ipairs(self.rows) do row.effect=nil;row.pressed=nil;row.icon:SetTexture(nil);row.label:SetText("");C:HideTooltip(row.frame) end
        for key in pairs(self.selected) do self.selected[key]=nil end
        self.stats,self.input,self.result,self.list=nil,nil,nil,nil
    end
    v.spellIcon=v.toolbar:CreateTexture(nil,"ARTWORK");v.spellIcon:SetSize(40,40);v.spellIcon:SetPoint("TOPLEFT",0,-4);v.spellIcon:SetTexCoord(.07,.93,.07,.93)
    v.name=text("aboutBrand",54,2,344,28,v.toolbar);Theme:SetTextColor(v.name,"text");v.name:SetWordWrap(false)
    v.contextLabel=text("meta",54,34,344,18,v.toolbar);v.contextLabel:SetWordWrap(false)
    v.levelControl=CreateFrame("Frame",nil,v.toolbar);v.levelControl:SetPoint("TOPLEFT",440,-8);v.levelControl:SetSize(144,28)
    Theme:CreateRoundedSurface(v.levelControl,"field",6);scrollable(v.levelControl)
    v.levelLabel=text("body",28,0,48,28,v.levelControl);v.levelLabel:SetJustifyH("CENTER");v.levelLabel:SetJustifyV("MIDDLE");Theme:SetTextColor(v.levelLabel,"text")
    local function tool(x,fn)
        local b=C:CreateButton(v.levelControl,{width=24,height=24,radius=4,
            colors={normal="transparent",hover="surfaceHover",pressed="actionHover",disabled="transparent"},
            textColors={normal="textMuted",hover="accentHover",pressed="accent",disabled="disabled"},
            onClick=function() if v.active and owner.active and not (InCombatLockdown and InCombatLockdown()) then fn() end end})
        b.frame:SetPoint("TOPLEFT",x,-2);scrollable(b.frame);return b
    end
    local function stepper(x,delta)
        local b=tool(x,function() v.level=math.max(0,math.min(35,v.level+delta));v:Render() end)
        b.strokes={}
        for i=1,delta>0 and 2 or 1 do
            local line=b.frame:CreateTexture(nil,"ARTWORK");line:SetPoint("CENTER",0,0);line:SetSize(i==1 and 7 or 1,i==1 and 1 or 7)
            Theme:SetColorTexture(line,"textMuted");b.strokes[i]=line
        end
        return b
    end
    v.minus=stepper(2,-1);v.plus=stepper(78,1)
    local separator=v.levelControl:CreateTexture(nil,"ARTWORK");separator:SetSize(1,12);separator:SetPoint("LEFT",108,0);Theme:SetColorTexture(separator,"borderStrong");Theme:SetAlpha(separator,.5)
    local iconRoot="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
    local function icon(parent,asset,x,y,size)
        local t=parent:CreateTexture(nil,"ARTWORK");t:SetSize(size,size);t:SetPoint("TOPLEFT",x,-y);t:SetTexture(iconRoot..asset..".tga");return t
    end
    v.refresh=tool(116,function() v:Refresh() end)
    icon(v.refresh.frame,"reload",4,4,16)
    v.refresh.frame:HookScript("OnEnter",function() if v.active then C:ShowTooltip(v.refresh.frame,{title=L["刷新"]}) end end)
    v.refresh.frame:HookScript("OnLeave",function() C:HideTooltip(v.refresh.frame) end)
    for i=1,2 do
        local divider=v.results:CreateTexture(nil,"ARTWORK")
        divider:SetPoint("TOPLEFT",i*184+16,-22);divider:SetSize(1,54);Theme:SetColorTexture(divider,"border")
    end
    v.values={}
    for i,caption in ipairs({"生命值","直接承伤","是否致死"}) do
        local label=text("meta",(i-1)*184+16,18,184,18);label:SetText(L[caption]);label:SetJustifyH("CENTER")
        v.values[i]=text("aboutBrand",(i-1)*184+16,42,184,28);v.values[i]:SetJustifyH("CENTER");Theme:SetTextColor(v.values[i],"text")
    end
    v.lethalIcon=icon(v.results,"skull",548,14,16)
    v.safeShort=v.results:CreateTexture(nil,"ARTWORK");v.safeShort:SetSize(5,2);v.safeShort:SetPoint("TOPLEFT",550,-22);v.safeShort:SetRotation(-math.pi/4);Theme:SetColorTexture(v.safeShort,"success")
    v.safeLong=v.results:CreateTexture(nil,"ARTWORK");v.safeLong:SetSize(10,2);v.safeLong:SetPoint("TOPLEFT",554,-19);v.safeLong:SetRotation(math.pi/4);Theme:SetColorTexture(v.safeLong,"success")
    v.summary=text("meta",384,74,184,22);v.summary:SetJustifyH("CENTER")
    v.effects=CreateFrame("Frame",nil,v.frame);v.effects:SetSize(584,252);v.effects:SetPoint("TOPLEFT",0,0);scrollable(v.effects)
    for i,caption in ipairs(groupNames) do
        v.tabs[i]=button(L[caption],(i-1)*112,0,104,function() v.group=i;v:RenderEffects() end,nil,v.controls)
        local tab=v.tabs[i]
        tab.label:ClearAllPoints();tab.label:SetPoint("LEFT",0,0);tab.label:SetSize(104,18);tab.label:SetJustifyH("LEFT")
        tab.indicator=tab.frame:CreateTexture(nil,"ARTWORK");tab.indicator:SetPoint("TOPLEFT",tab.label,"BOTTOMLEFT",0,-5);tab.indicator:SetSize(1,2);Theme:SetColorTexture(tab.indicator,"accentHover")
    end
    v.resetSelection=button(L["勾选模拟减伤"],378,0,206,function()
        for id in pairs(v.selected) do v.selected[id]=nil end;v:Render()
    end,nil,v.controls)
    v.resetSelection.label:SetJustifyH("RIGHT");Theme:SetFont(v.resetSelection.label,"meta")
    for i=1,12 do
        local row
        row=C:CreateCheckbox(v.effects,{width=284,height=38,checkSide="left",variant="choice",onClick=function()
            if not v.active or not owner.active or (InCombatLockdown and InCombatLockdown()) then return end
            if row.pressed~=row.generation or not row.effect then return end
            row.pressed=nil;local id=row.effect.id;v.selected[id]=not v.selected[id];v:Render()
        end})
        row.frame:SetPoint("TOPLEFT",((i-1)%2)*300,-(math.floor((i-1)/2)*42));scrollable(row.frame)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",72,0);row.label:SetPoint("RIGHT",-10,0);row.label:SetHeight(18);row.label:SetJustifyH("LEFT")
        row.icon=row.frame:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",38,0);row.icon:SetSize(26,26);row.icon:SetTexCoord(.07,.93,.07,.93)
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
