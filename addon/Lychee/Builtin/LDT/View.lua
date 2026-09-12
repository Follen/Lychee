-- Creature reference extends the existing Lychee surface: one model, six rows,
-- warm text and sparse red selection. No per-model update loop or window copy.
local I=_G.LycheeInternal
local M=I.Builtin.LDT
local L=I.ProviderLocales:Builtin(M.id)
local PER_PAGE=6
local flags={{"interruptible","可打断"},{"magic","魔法"},{"curse","诅咒"},{"poison","中毒"},{"disease","疾病"},{"enrage","激怒"},{"bleed","流血"}}
local types={Humanoid="人型生物",Beast="野兽",Undead="亡灵",Demon="恶魔",Dragonkin="龙类",Elemental="元素生物",Mechanical="机械",Giant="巨人",Aberration="畸变怪"}
local controls={{"Stun","昏迷"},{"Fear","恐惧"},{"Incapacitate","瘫痪"},{"Disorient","迷惑"},{"Slow","减速"},{"Root","定身"},
    {"Banish","放逐"},{"Grip","拉拽"},{"Hibernate","休眠"},{"Imprison","禁锢"},{"Knock","击退"},{"Mind Control","精神控制"},
    {"Mind Soothe","安抚心灵"},{"Polymorph","变形"},{"Repentance","忏悔"},{"Sap","闷棍"},{"Scare Beast","恐吓野兽"},
    {"Shackle Undead","束缚亡灵"},{"Silence","沉默"},{"Sleep Walk","梦游"},{"Taunt","嘲讽"}}
local function tags(data)
    local result={}
    for _,flag in ipairs(flags) do if data[flag[1]] then result[#result+1]=L[flag[2]] end end
    return table.concat(result," · ")
end
local function text(parent,role,color)
    local region=parent:CreateFontString(nil,"ARTWORK","GameFontHighlight")
    _G.Lychee.UI.Theme:SetFont(region,role)
    _G.Lychee.UI.Theme:SetTextColor(region,color)
    region:SetJustifyH("LEFT");region:SetJustifyV("TOP")
    return region
end
local function button(parent,label,width,fn)
    return _G.Lychee.UI.Components:CreateNavigationButton(parent,{text=L[label],width=width,height=24,onClick=fn})
end
function M:CreateView()
    if self.panel then return self.panel end
    local panel={rows={},page=1,facing=0}
    function panel:ShowTraits()
        if not self.active or not GameTooltip then return end
        local enemy=self.enemy
        local affected={}
        for _,item in ipairs(controls) do if enemy.characteristics and enemy.characteristics[item[1]] then affected[#affected+1]=L[item[2]] end end
        GameTooltip:SetOwner(self.traits.frame,"ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(M:Name(enemy),1,1,1)
        GameTooltip:AddLine(L["可受控制"].."："..(#affected>0 and table.concat(affected," / ") or L["未记录"]),0.85,0.85,0.85,true)
        if enemy.stealth then GameTooltip:AddLine(L["隐形"],0.85,0.85,0.85) end
        if enemy.stealthDetect then GameTooltip:AddLine(L["侦测隐形"],0.85,0.85,0.85) end
        GameTooltip:AddLine(L["基础资料，随难度和变体变化"],0.7,0.7,0.7,true)
        GameTooltip:Show()
    end
    function panel:Request(id)
        if self.pending[id]~=nil or not C_Spell or not C_Spell.RequestLoadSpellData then return end
        self.pending[id]=true
        local ok=pcall(C_Spell.RequestLoadSpellData,id)
        if not ok then self.pending[id]=false end
    end
    function panel:Describe()
        if not self.active then return end
        local id=self.selected
        local description=id and C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
        self.description:SetText(description or (id and L["技能资料暂未加载"] or L["暂无技能资料"]))
        if id and not description then self:Request(id) end
    end
    function panel:RenderSkills()
        if not self.active then return end
        local spells=self.enemy.spells
        local pages=math.max(1,math.ceil(#spells/PER_PAGE))
        self.page=math.max(1,math.min(self.page,pages))
        for i,row in ipairs(self.rows) do
            row.spellID=nil
            row.binding=(row.binding or 0)+1
            local spell=spells[(self.page-1)*PER_PAGE+i]
            row.frame:Hide() -- resets pressed/hover state before rebinding
            if spell then
                row.spellID=spell.id
                local name=M:SpellName(spell.id)
                row.label:SetText(name or (L["技能"].." "..spell.id))
                local texture=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell.id)
                row.icon:SetTexture(texture or "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\spellbook.tga")
                row.tags:SetText(tags(spell))
                row.mark:SetShown(self.selected==spell.id)
                row.frame:Show()
                if not name then self:Request(spell.id) end
            end
        end
        self.pageLabel:SetText(self.page.." / "..pages)
        self.previous:SetEnabled(self.page>1);self.next:SetEnabled(self.page<pages)
        self:Describe()
    end
    function panel:Create(parent)
        self.frame=CreateFrame("Frame",nil,parent);self.frame:SetAllPoints(parent)
        self.frame:Hide()
        self.back=button(self.frame,"返回搜索",86,function()
            if not self.active then return end
            local controller=I.Host and I.Host.PaletteController
            if controller and controller.viewHost and controller.viewHost:IsOwnedBy(M.id) then controller:CloseView("reference-back") end
        end)
        self.back.frame:SetPoint("TOPLEFT",16,-4)
        self.title=text(self.frame,"title","text");self.title:SetPoint("TOPLEFT",16,-34);self.title:SetPoint("RIGHT",-16,0);self.title:SetHeight(20)
        self.subtitle=text(self.frame,"meta","textMuted");self.subtitle:SetPoint("TOPLEFT",16,-56);self.subtitle:SetPoint("RIGHT",-16,0);self.subtitle:SetHeight(16)
        self.model=CreateFrame("PlayerModel",nil,self.frame)
        self.model:SetPoint("TOPLEFT",16,-80);self.model:SetSize(224,178)
        self.modelMessage=text(self.frame,"body","textMuted");self.modelMessage:SetPoint("TOPLEFT",24,-154);self.modelMessage:SetWidth(208)
        self.turnLeft=button(self.frame,"左转",50,function() if self.active then self.facing=self.facing-0.4;self.model:SetFacing(self.facing) end end)
        self.turnRight=button(self.frame,"右转",50,function() if self.active then self.facing=self.facing+0.4;self.model:SetFacing(self.facing) end end)
        self.reset=button(self.frame,"重置",50,function() if self.active then self.facing=0;self.model:SetFacing(0) end end)
        self.turnLeft.frame:SetPoint("TOPLEFT",30,-260);self.reset.frame:SetPoint("TOPLEFT",102,-260);self.turnRight.frame:SetPoint("TOPLEFT",174,-260)
        self.stats=text(self.frame,"meta","textMuted");self.stats:SetPoint("TOPLEFT",16,-290);self.stats:SetWidth(230);self.stats:SetHeight(42)
        self.traits=button(self.frame,"查看特性",100,function() self:ShowTraits() end)
        self.traits.frame:SetPoint("BOTTOMLEFT",16,2)
        self.traits.frame:HookScript("OnEnter",function() self:ShowTraits() end)
        self.traits.frame:HookScript("OnLeave",function() if GameTooltip and GameTooltip:GetOwner()==self.traits.frame then GameTooltip:Hide() end end)
        self.abilities=text(self.frame,"body","text");self.abilities:SetPoint("TOPLEFT",264,-78);self.abilities:SetText(L["技能"])
        for i=1,PER_PAGE do
            local row
            row=button(self.frame,"技能",320,function()
                if not self.active or not row.spellID or row.pressed~=row.binding then return end
                row.pressed=nil
                self.selected=row.spellID;self:RenderSkills()
            end)
            row.frame:SetPoint("TOPLEFT",264,-98-(i-1)*30);row.frame:SetPoint("RIGHT",self.frame,"RIGHT",-16,0);row.frame:SetHeight(28)
            row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT",34,-1);row.label:SetPoint("RIGHT",-3,0);row.label:SetHeight(14);row.label:SetJustifyH("LEFT")
            row.icon=row.frame:CreateTexture(nil,"ARTWORK");row.icon:SetSize(24,24);row.icon:SetPoint("LEFT",4,0)
            row.tags=text(row.frame,"meta","textMuted");row.tags:SetPoint("TOPLEFT",34,-15);row.tags:SetPoint("RIGHT",-3,0);row.tags:SetHeight(12)
            row.mark=row.frame:CreateTexture(nil,"ARTWORK");row.mark:SetColorTexture(unpack(_G.Lychee.UI.Theme.Colors.accent));row.mark:SetPoint("LEFT",0,0);row.mark:SetSize(2,22)
            row.frame:HookScript("OnEnter",function()
                if self.active and row.spellID and GameTooltip and GameTooltip.SetSpellByID then
                    GameTooltip:SetOwner(row.frame,"ANCHOR_RIGHT");GameTooltip:SetSpellByID(row.spellID);GameTooltip:Show()
                end
            end)
            row.frame:HookScript("OnLeave",function() if GameTooltip and GameTooltip:GetOwner()==row.frame then GameTooltip:Hide() end end)
            row.frame:HookScript("OnMouseDown",function(_,mouseButton) if mouseButton=="LeftButton" and self.active then row.pressed=row.binding end end)
            row.frame:HookScript("OnHide",function()
                row.pressed=nil
                if GameTooltip and GameTooltip:GetOwner()==row.frame then GameTooltip:Hide() end
            end)
            self.rows[i]=row
        end
        self.description=text(self.frame,"meta","textMuted");self.description:SetPoint("TOPLEFT",264,-282);self.description:SetPoint("RIGHT",-16,0);self.description:SetHeight(32)
        self.previous=button(self.frame,"上一页",70,function() if self.active then self.page=self.page-1;self:RenderSkills() end end)
        self.next=button(self.frame,"下一页",70,function() if self.active then self.page=self.page+1;self:RenderSkills() end end)
        self.previous.frame:SetPoint("BOTTOMLEFT",264,2);self.next.frame:SetPoint("BOTTOMRIGHT",-16,2)
        self.pageLabel=text(self.frame,"meta","textMuted");self.pageLabel:SetPoint("BOTTOM",self.frame,"BOTTOMRIGHT",-176,8);self.pageLabel:SetWidth(64);self.pageLabel:SetJustifyH("CENTER")
    end
    function panel:Mount(context,state)
        local enemy,dungeon=M:Find(state.dungeonID,state.npcID,state.spellID)
        assert(enemy,L["资料暂不可用"])
        if not self.frame then self:Create(context.contentFrame) end
        if self.parent~=context.contentFrame then self.frame:SetParent(context.contentFrame);self.frame:ClearAllPoints();self.frame:SetAllPoints(context.contentFrame);self.parent=context.contentFrame end
        self.active,self.enemy,self.dungeon,self.pending=true,enemy,dungeon,{}
        self.selected=state.spellID~=0 and state.spellID or enemy.spells[1] and enemy.spells[1].id
        self.page=1;self.facing=0
        for index,spell in ipairs(enemy.spells) do if spell.id==self.selected then self.page=math.ceil(index/PER_PAGE);break end end
        self.title:SetText(M:Name(enemy))
        self.subtitle:SetText(M:Name(dungeon).." · "..L[enemy.isBoss and "首领" or "小怪"].." · NPC "..enemy.id)
        local summary=(types[enemy.creatureType] and L[types[enemy.creatureType]] or enemy.creatureType or L["未记录"]).." · "..L["等级"].." "..(enemy.level or "—")
        summary=summary.."\n"..L["基础生命"].." "..(enemy.health or "—").." · "..L["基础进度"].." "..(enemy.count or "—")
        self.stats:SetText(summary)
        self.event=context.resources:OnEvent("SPELL_DATA_LOAD_RESULT",function(_,id)
            if self.active and self.pending[id]==true then self.pending[id]=false;self:RenderSkills() end
        end)
        self.frame:Show();self.model:Show()
        local ok=pcall(function() self.model:ClearModel();self.model:SetDisplayInfo(enemy.displayId);self.model:SetPortraitZoom(0);self.model:SetCamDistanceScale(1);self.model:SetFacing(0) end)
        self.modelMessage:SetText(ok and "" or L["模型暂不可用"])
        self:RenderSkills()
    end
    function panel:Unmount()
        self.active=false
        if self.event then self.event:Cancel();self.event=nil end
        for _,row in ipairs(self.rows) do
            if GameTooltip and GameTooltip:GetOwner()==row.frame then GameTooltip:Hide() end
            row.spellID=nil;row.frame:Hide();row.label:SetText("");row.tags:SetText("");row.icon:SetTexture(nil)
        end
        self.enemy,self.dungeon,self.pending,self.selected=nil,nil,nil,nil
        if self.frame then
            if GameTooltip and GameTooltip:GetOwner()==self.traits.frame then GameTooltip:Hide() end
            self.title:SetText("");self.subtitle:SetText("");self.stats:SetText("");self.description:SetText("")
            self.model:Hide();pcall(self.model.ClearModel,self.model);self.frame:Hide()
        end
    end
    function panel:Dispose() self:Unmount() end
    M.panel=panel
    return panel
end
