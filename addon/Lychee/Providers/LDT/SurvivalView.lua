local I=_G.LycheeInternal
local M=I.ProviderModules.LDT
local S=M.Survival
local L=I.ProviderLocales:Module(M.id)
local schools={"magic","physical","bleed"}
local schoolNames={magic="魔法",physical="物理",bleed="流血"}
local groupNames={"单体外援","团队增益","团队主动"}
local function amount(value) return value and string.format("%.0f",value) or "—" end
function M:CreateSurvivalView(owner)
    if owner.calculator then return owner.calculator end
    local C,Theme=_G.Lychee.UI.Components,_G.Lychee.UI.Theme
    local v={rows={},fields={},tabs={},selected={},group=1,offset=0,level=10}
    owner.calculator=v
    v.viewport=CreateFrame("ScrollFrame",nil,owner.frame);v.viewport:SetPoint("TOPLEFT",16,-62);v.viewport:SetPoint("BOTTOMRIGHT",-4,0);v.viewport:Hide()
    v.frame=CreateFrame("Frame",nil,v.viewport);v.frame:SetSize(584,526);v.viewport:SetScrollChild(v.frame)
    v.bar=C:CreateScrollbar(v.viewport,function(value) v.viewport:SetVerticalScroll(value) end)
    local function resize() v.bar:SetRange(526,v.viewport:GetHeight(),v.bar.value or 0) end
    v.viewport:SetScript("OnSizeChanged",resize);v.viewport:EnableMouseWheel(true)
    v.viewport:SetScript("OnMouseWheel",function(_,delta) if v.active then v.bar:SetValue((v.bar.value or 0)-delta*28) end end)
    local function text(role,x,y,w,h)
        local f=v.frame:CreateFontString(nil,"ARTWORK","GameFontHighlight")
        Theme:SetFont(f,role);Theme:SetTextColor(f,"textMuted");f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
        f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h);return f
    end
    local function button(caption,x,y,w,fn,direction)
        local b=C:CreateNavigationButton(v.frame,{text=caption,width=w,height=24,direction=direction,onClick=function()
            if v.active and owner.active and not (InCombatLockdown and InCombatLockdown()) then fn() end
        end});Theme:SetFont(b.label,"body");b.frame:SetPoint("TOPLEFT",x,-y);return b
    end
    function v:Refresh()
        if not self.active then return end
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        if not self.manual then self:LoadDamage() end
        self:Render()
    end
    function v:LoadDamage()
        if not self.active or self.manual then return end
        local description=C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(owner.selected)
        self.input=S:Parse(description,self.input)
        self.input.confirmed=self.input.valid==true
        self.input.boss=owner.enemy.isBoss
        self.input.tooltipVers=self.stats.vers
        if not description then owner:Request(owner.selected) end
        self.updating=true
        for key,field in pairs(self.fields) do field:SetText(tostring(self.input[key] or 0)) end
        self.updating=false
    end
    function v:Render()
        if not self.active then return end
        local stats,input=self.stats,self.input
        input.level=self.level
        self.levelLabel:SetText(L["层数"].." "..self.level)
        self.result=S:Calculate(stats,input,self.selected,self.result)
        local r=self.result
        self.statsLabel:SetText(stats.valid and L:Format("生命 %s · 全能减伤 %.1f%% · 范围减伤 %.1f%%",amount(stats.health),stats.versDR*100,stats.avoidance*100) or L["属性暂不可用，脱战后刷新"])
        local status=r.status=="lethal" and "首段致死" or r.status=="needsHealing" and "首段可承受，后续需要治疗" or r.status=="survives" and "满血可承受" or "请确认伤害参数"
        self.status:SetText(L[status]);Theme:SetTextColor(self.status,r.status=="lethal" and "danger" or r.status=="unknown" and "textMuted" or "text")
        self.summary:SetText(r.health and L:Format("模拟生命 %s · 估算吸收 %s",amount(r.health),amount(r.shield)) or L["从技能说明提取，复杂机制请校正"])
        self.values[1]:SetText(amount(r.first));self.values[2]:SetText(amount(r.tickBeforeAbsorb));self.values[3]:SetText(amount(r.total))
        self.aoe:SetText(L[input.aoe and "范围伤害：开" or "范围伤害：关"])
        self.kind:SetText(L["伤害类型"]..": "..(input.firstSchool==input.tickSchool and L[schoolNames[input.firstSchool] or "未记录"] or L["分段类型"]))
        self.confirm:SetText(L[input.confirmed and "参数已确认" or "确认参数"])
        self:RenderEffects()
    end
    function v:RenderEffects()
        local list=self.list or {};self.list=list
        for k=#list,1,-1 do list[k]=nil end
        for _,e in ipairs(S.effects) do if e.group==self.group then list[#list+1]=e end end
        self.offset=math.max(0,math.min(self.offset,math.max(0,#list-10)))
        for index,row in ipairs(self.rows) do
            row.frame:Hide();row.effect=nil;row.generation=(row.generation or 0)+1
            local e=list[index+self.offset]
            if e then
                row.effect=e
                local active=self.stats.active[e.id]
                row.label:SetText(M:SpellName(e.id) or (L["技能"].." "..e.id))
                row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id) or "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\spellbook.tga")
                row.mark:SetShown(active or self.selected[e.id]==true)
                row:SetEnabled(not active);row.frame:Show()
            end
        end
        for i,b in ipairs(self.tabs) do b:SetSelected(i==self.group) end
        self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+10<#list)
    end
    function v:Open()
        self.active=true;self.manual=false;self.group,self.offset=1,0
        self.stats=S:Snapshot(self.stats,owner.enemy.level)
        self:LoadDamage()
        self.name:SetText((M:SpellName(owner.selected) or L["技能"]).."  ·  "..owner.selected)
        owner:StopDrag();owner.model:Hide();owner.modelMessage:Hide();owner.reset.frame:Hide();owner.skillArea:Hide()
        owner.abilities:Hide();owner.previous.frame:Hide();owner.next.frame:Hide();owner.pageLabel:Hide();owner.survivalButton.frame:Hide()
        self.viewport:Show();self.frame:Show();owner.context:Resize(590);resize();self.bar:SetValue(0);self:Render()
    end
    function v:Close()
        self.active=false;self.frame:Hide();self.viewport:Hide();self.bar:StopDrag()
        for _,field in pairs(self.fields) do field:ClearFocus() end
        for _,row in ipairs(self.rows) do row.effect=nil;row.pressed=nil;row.icon:SetTexture(nil);row.label:SetText("");C:HideTooltip(row.frame) end
        for key in pairs(self.selected) do self.selected[key]=nil end
        self.stats,self.input,self.result,self.list=nil,nil,nil,nil
        C:HideTooltip(self.passive.frame)
    end
    button(L["怪物资料"],0,0,86,function() v:Close();owner.model:Show();owner.modelMessage:Show();owner.reset.frame:Show();owner.skillArea:Show();owner.abilities:Show();owner:RenderSkills() end)
    button(L["刷新属性"],208,0,90,function() v:Refresh() end)
    v.levelLabel=text("body",432,5,76,18)
    button("−",396,0,28,function() v.level=math.max(0,v.level-1);v:Render() end)
    button("+",510,0,28,function() v.level=math.min(35,v.level+1);v:Render() end)
    v.name=text("body",0,34,574,18);Theme:SetTextColor(v.name,"text")
    v.statsLabel=text("meta",0,60,460,30)
    v.passive=button(L["已计入被动"],470,56,110,function() end)
    v.passive.frame:HookScript("OnEnter",function()
        if not v.active then return end
        local lines={}
        for _,rule in ipairs(S.passives) do if v.stats.passives[rule.id] then lines[#lines+1]=(M:SpellName(rule.id) or tostring(rule.id)).." ×"..v.stats.passives[rule.id] end end
        C:ShowTooltip(v.passive.frame,{title=L["已计入被动"],description=#lines>0 and table.concat(lines,"\n") or L["没有匹配的减伤被动"],hint=L["生命、护甲与全能已含自身属性加成"]})
    end)
    v.passive.frame:HookScript("OnLeave",function() C:HideTooltip(v.passive.frame) end)
    v.status=text("title",0,88,584,22);v.summary=text("meta",0,114,584,18)
    v.values={}
    for i,caption in ipairs({"首段承伤","每跳承伤（吸收前）","完整承伤（不计治疗）"}) do
        text("meta",(i-1)*196,146,188,18):SetText(L[caption])
        v.values[i]=text("title",(i-1)*196,168,188,22);Theme:SetTextColor(v.values[i],"text")
    end
    for i,key in ipairs({"first","tick","ticks"}) do
        text("meta",(i-1)*196,202,188,18):SetText(L[({"首段基础伤害","每跳基础伤害","持续跳数"})[i]])
        local edit=CreateFrame("EditBox",nil,v.frame);edit:SetPoint("TOPLEFT",(i-1)*196,-222);edit:SetSize(176,26)
        edit:SetAutoFocus(false);edit:SetMaxLetters(12);edit:SetFontObject("GameFontHighlight");Theme:SetFont(edit,"body");edit:SetTextInsets(8,8,0,0)
        C:StyleEditBox(edit);v.fields[key]=edit
        edit:SetScript("OnTextChanged",function()
            if not v.active or v.updating then return end
            v.manual=true;v.input[key]=tonumber(edit:GetText());v.input.confirmed=false;v:Render()
        end)
        edit:SetScript("OnEnterPressed",function() edit:ClearFocus();v.input.confirmed=true;v:Render() end)
        edit:SetScript("OnEscapePressed",function() edit:ClearFocus() end)
    end
    v.kind=button("",0,260,194,function()
        local at=0;for i,k in ipairs(schools) do if k==v.input.firstSchool then at=i end end
        local kind=schools[at%3+1];v.manual=true;v.input.firstSchool,v.input.tickSchool=kind,kind;v.input.confirmed=false;v:Render()
    end)
    v.aoe=button("",208,260,150,function() v.manual=true;v.input.aoe=not v.input.aoe;v.input.confirmed=false;v:Render() end)
    v.confirm=button("",432,260,142,function() for _,f in pairs(v.fields) do f:ClearFocus() end;v.input.confirmed=true;v:Render() end)
    for i,caption in ipairs(groupNames) do
        v.tabs[i]=button(L[caption],(i-1)*150,300,136,function() v.group=i;v.offset=0;v:RenderEffects() end)
    end
    v.previous=button("",504,300,26,function() v.offset=math.max(0,v.offset-10);v:RenderEffects() end,"left")
    v.next=button("",544,300,26,function() v.offset=v.offset+10;v:RenderEffects() end,"right")
    for i=1,10 do
        local row
        row=button("",((i-1)%2)*294,336+math.floor((i-1)/2)*28,284,function()
            if row.pressed~=row.generation or not row.effect then return end
            row.pressed=nil;local id=row.effect.id;v.selected[id]=not v.selected[id];v:Render()
        end)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",48,0);row.label:SetPoint("RIGHT",-2,0);row.label:SetHeight(18);row.label:SetJustifyH("LEFT")
        row.icon=row.frame:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",20,0);row.icon:SetSize(22,22);row.icon:SetTexCoord(.07,.93,.07,.93)
        local box=row.frame:CreateTexture(nil,"BACKGROUND");box:SetPoint("LEFT",2,0);box:SetSize(10,10);Theme:SetColorTexture(box,"fieldBorder")
        row.mark=row.frame:CreateTexture(nil,"ARTWORK");row.mark:SetPoint("LEFT",4,0);row.mark:SetSize(6,6);Theme:SetColorTexture(row.mark,"accentHover")
        row.frame:HookScript("OnMouseDown",function(_,mouse) if mouse=="LeftButton" then row.pressed=row.generation end end)
        row.frame:HookScript("OnHide",function() row.pressed=nil;C:HideTooltip(row.frame) end)
        row.frame:HookScript("OnEnter",function()
            local e=row.effect;if not v.active or not e then return end
            C:ShowTooltip(row.frame,{title=M:SpellName(e.id) or tostring(e.id),description=C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(e.id),
                hint=v.stats.active[e.id] and L["当前已生效"] or e.absorb and L["吸收按自身生命与全能估算"] or e.id==357170 and L["只计即时减伤，延后伤害由治疗处理"] or L["勾选模拟此效果"]})
        end)
        row.frame:HookScript("OnLeave",function() C:HideTooltip(row.frame) end)
        v.rows[i]=row
    end
    text("meta",0,486,584,30):SetText(L["满血估算 · 吸收使用自身属性 · 不模拟后续治疗与效果到期"])
    return v
end
