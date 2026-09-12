-- Creature reference extends the existing Lychee surface: one model, bounded rows,
-- warm text and sparse red selection. Updates only while dragging; no separate window.
local I=_G.LycheeInternal
local M=I.Builtin.LDT
local L=I.ProviderLocales:Builtin(M.id)
local PER_PAGE,MAX_ROWS,ROW_HEIGHT=6,8,26
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
-- Highlight readable numbers only. Preserve native links, colors and media escapes byte-for-byte.
function M:FormatDescription(value)
    if not value then return nil end
    local color=_G.Lychee.UI.Theme.MatchColorCode
    local function numbers(part)
        return (part:gsub("%d[%d,%.]*%%?",function(number)
            local tail=number:match("[,.]+$") or ""
            number=number:sub(1,#number-#tail)
            return color..number.."|r"..tail
        end))
    end
    local pieces,pos={},1
    while pos<=#value do
        local pipe=value:find("|",pos,true)
        if not pipe then pieces[#pieces+1]=numbers(value:sub(pos));break end
        pieces[#pieces+1]=numbers(value:sub(pos,pipe-1))
        local kind=value:sub(pipe+1,pipe+1)
        local closing=kind=="c" and "|r" or kind=="T" and "|t" or kind=="A" and "|a" or kind=="H" and "|h"
        local stop=closing and value:find(closing,pipe+2,true)
        if kind=="H" and stop then stop=value:find("|h",stop+2,true) end
        if closing and not stop then pieces[#pieces+1]=value:sub(pipe);break end
        stop=stop and stop+1 or pipe+1
        pieces[#pieces+1]=value:sub(pipe,stop);pos=stop+1
    end
    return table.concat(pieces)
end
function M:CreateView()
    if self.panel then return self.panel end
    local panel={rows={},page=1,facing=0,zoom=0}
    local Theme=_G.Lychee.UI.Theme
    local Components=_G.Lychee.UI.Components
    local function label(parent,role,color,x,y,width,height)
        local f=text(parent,role,color);f:SetPoint("TOPLEFT",x,y);f:SetWidth(width);f:SetHeight(height);return f
    end
    local function nav(parent,caption,width,fn,direction)
        local component=Components:CreateNavigationButton(parent,{text=caption,width=width,height=24,onClick=fn,direction=direction})
        Theme:SetFont(component.label,"body");return component
    end
    function panel:StopDrag()
        self.dragX=nil
        if self.model then self.model:SetScript("OnUpdate",nil) end
    end
    function panel:ShowTraits()
        if not self.active or not GameTooltip then return end
        local enemy=self.enemy
        local affected={}
        for _,item in ipairs(controls) do if enemy.characteristics and enemy.characteristics[item[1]] then affected[#affected+1]=L[item[2]] end end
        GameTooltip:SetOwner(self.traits.frame,"ANCHOR_LEFT");GameTooltip:ClearLines()
        GameTooltip:AddLine(M:Name(enemy),1,1,1)
        GameTooltip:AddLine(L["可受控制"].."："..(#affected>0 and table.concat(affected," / ") or L["未记录"]),0.85,0.85,0.85,true)
        GameTooltip:AddLine(L["基础生命"].." "..(enemy.health or "—").."  ·  "..L["基础进度"].." "..(enemy.count or "—"),0.85,0.85,0.85,true)
        if enemy.stealth then GameTooltip:AddLine(L["隐形"],0.85,0.85,0.85) end
        if enemy.stealthDetect then GameTooltip:AddLine(L["侦测隐形"],0.85,0.85,0.85) end
        GameTooltip:AddLine(L["基础资料，随难度和变体变化"],0.7,0.7,0.7,true);GameTooltip:Show()
    end
    function panel:Request(id)
        if self.pending[id]~=nil or not C_Spell or not C_Spell.RequestLoadSpellData then return end
        self.pending[id]=true
        if not pcall(C_Spell.RequestLoadSpellData,id) then self.pending[id]=false end
    end
    function panel:Flatten(reveal)
        local flat=self.flat or {};for i=#flat,1,-1 do flat[i]=nil end;self.flat=flat
        for index,group in ipairs(self.groups) do
            group.page=math.ceil(index/PER_PAGE)
            flat[#flat+1]=group.heading
            if self.expanded[group.key] then
                for _,entry in ipairs(group.entries) do flat[#flat+1]=entry end
            end
            if reveal and group.ids[self.selected] then self.page=group.page;self.revealID=self.selected end
        end
        self.page=math.max(1,math.min(self.page,math.max(1,math.ceil(#self.groups/PER_PAGE))))
    end
    function panel:BuildGroups(reveal)
        local anchor=self.pageItems and self.pageItems[(self.rowOffset or 0)+1]
        local anchorID=anchor and anchor.spellID
        for _,row in ipairs(self.rows) do if row.spellID==self.selected and row.frame:IsShown() then reveal=true;break end end
        local groups,byName={},{}
        for _,spell in ipairs(self.enemy.spells) do
            local name=M:SpellName(spell.id)
            local key=name or spell.id -- Unknown names must never collapse together.
            local group=byName[key]
            if not group then
                group={key=key,name=name,entries={},ids={}}
                group.heading={group=group,spellID=spell.id};byName[key]=group;groups[#groups+1]=group
            end
            group.entries[#group.entries+1]={group=group,spellID=spell.id,child=true}
            group.ids[spell.id]=true
            if not name then self:Request(spell.id) end
        end
        self.groups=groups
        -- Search may target a non-leading member. Keep that exact ID visible.
        if reveal then for _,group in ipairs(groups) do
            if group.ids[self.selected] and group.heading.spellID~=self.selected then self.expanded[group.key]=true end
        end end
        self:Flatten(reveal)
        if not reveal and anchorID then
            for _,group in ipairs(groups) do
                if group.ids[anchorID] then
                    self.page=group.page;self.anchorID,self.anchorChild=anchorID,anchor.child;break
                end
            end
        end
    end
    function panel:LayoutSkills()
        local items=self.pageItems or {};for i=#items,1,-1 do items[i]=nil end;self.pageItems=items
        for _,entry in ipairs(self.flat) do if entry.group.page==self.page then items[#items+1]=entry end end
        self.visibleRows=math.min(MAX_ROWS,#items)
        local offset=self.rowOffset or 0
        if self.renderedPage~=self.page then offset=0;self.renderedPage=self.page end
        local fallback
        for index,entry in ipairs(items) do
            if self.anchorID then
                if entry.spellID==self.anchorID and entry.child==self.anchorChild then offset=index-1;self.anchorID=nil
                elseif not entry.child and entry.group.ids[self.anchorID] then fallback=index-1 end
            end
        end
        if self.anchorID and fallback then offset=fallback end
        self.anchorID,self.anchorChild=nil,nil
        if self.revealID then
            local index
            for i,entry in ipairs(items) do
                if entry.spellID==self.revealID then index=i end
            end
            if index then offset=math.min(offset,index-1);offset=math.max(offset,index-self.visibleRows) end
            self.revealID=nil
        end
        if self.revealGroup then
            local first,last
            for i,entry in ipairs(items) do if entry.group.key==self.revealGroup then first=first or i;last=i end end
            if first then
                if last-first+1<=MAX_ROWS then offset=math.max(0,last-MAX_ROWS) else offset=first-1 end
            end
            self.revealGroup=nil
        end
        self.rowOffset=math.max(0,math.min(offset,math.max(0,#items-self.visibleRows)))
        local sectionEnd=math.max(250,84+self.visibleRows*ROW_HEIGHT+10)
        if self.sectionEnd~=sectionEnd then
            self.sectionEnd=sectionEnd
            self.divider:ClearAllPoints();self.divider:SetPoint("TOPLEFT",16,-sectionEnd);self.divider:SetPoint("RIGHT",-16,0)
            self.detailTitle:ClearAllPoints();self.detailTitle:SetPoint("TOPLEFT",16,-sectionEnd-12)
            self.detailMeta:ClearAllPoints();self.detailMeta:SetPoint("TOPLEFT",280,-sectionEnd-13);self.detailMeta:SetPoint("RIGHT",-16,0)
            self.descriptionScroll:ClearAllPoints();self.descriptionScroll:SetPoint("TOPLEFT",16,-sectionEnd-38);self.descriptionScroll:SetPoint("RIGHT",-16,0)
            self.hint:ClearAllPoints();self.hint:SetPoint("TOPRIGHT",-16,-sectionEnd-94)
        end
        local areaHeight=math.max(ROW_HEIGHT,self.visibleRows*ROW_HEIGHT)
        if self.skillArea:GetHeight()~=areaHeight then self.skillArea:SetHeight(areaHeight) end
        local c=I.Host and I.Host.PaletteController
        if c and c.ResizeView then c:ResizeView(self,sectionEnd+114) end
        self.skillBar:SetRange(#items*ROW_HEIGHT,self.visibleRows*ROW_HEIGHT,self.rowOffset*ROW_HEIGHT)
    end
    function panel:UpdateDescriptionSize()
        if not self.descriptionScroll then return end
        local width=math.max(1,self.descriptionScroll:GetWidth()-14)
        self.descriptionBody:SetWidth(width);self.description:SetWidth(width)
        local height=math.max(self.descriptionScroll:GetHeight(),self.description:GetStringHeight())
        self.descriptionBody:SetHeight(height)
        local value=math.min(self.descriptionScroll:GetVerticalScroll(),math.max(0,height-self.descriptionScroll:GetHeight()))
        self.descriptionScroll:SetVerticalScroll(value)
        self.descriptionBar:SetRange(height,self.descriptionScroll:GetHeight(),value)
    end
    function panel:Describe()
        if not self.active then return end
        local id=self.selected
        local spell
        for _,entry in ipairs(self.enemy.spells) do if entry.id==id then spell=entry;break end end
        self.detailTitle:SetText(id and (M:SpellName(id) or (L["技能"].." "..id)) or L["暂无技能资料"])
        self.detailMeta:SetText(id and ("ID "..id..(spell and tags(spell)~="" and "  ·  "..tags(spell) or "")) or "")
        local description=id and C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
        if self.describedID~=id or self.descriptionRaw~=description then
            self.describedID,self.descriptionRaw=id,description
            self.description:SetText(M:FormatDescription(description) or (id and L["技能资料暂未加载"] or ""))
            self.descriptionScroll:SetVerticalScroll(0);self:UpdateDescriptionSize()
        end
        if id and not description then self:Request(id) end
    end
    function panel:LinkSpell(id)
        if not self.active or (InCombatLockdown and InCombatLockdown()) then return end
        local link=C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(id)
        if not link then self.hint:SetText(L["链接暂不可用，请稍后重试"]);self:Request(id);return end
        local chat=ChatFrameUtil
        if not chat then return end
        local controller=I.Host and I.Host.PaletteController
        if controller and controller.input then controller.input:ClearFocus() end
        local edit=chat.GetActiveWindow and chat.GetActiveWindow()
        if edit then edit:Insert(link);edit:SetFocus()
        elseif chat.OpenChat then chat.OpenChat(link) end
    end
    function panel:RenderSkills()
        if not self.active then return end
        local pages=math.max(1,math.ceil(#self.groups/PER_PAGE))
        self.page=math.max(1,math.min(self.page,pages))
        self:LayoutSkills()
        for i,row in ipairs(self.rows) do
            row.frame:Hide();row.spellID=nil;row.group=nil
            row.binding=(row.binding or 0)+1
            local entry=i<=self.visibleRows and self.pageItems[self.rowOffset+i]
            if entry then
                local group=entry.group
                local expanded=self.expanded[group.key]
                local id=not entry.child and not expanded and group.ids[self.selected] and self.selected or entry.spellID
                row.spellID,row.group=id,group
                row.label:SetText(group.name or (L["技能"].." "..id))
                row.label:ClearAllPoints();row.label:SetPoint("LEFT",entry.child and 46 or 34,0)
                row.label:SetPoint("RIGHT",-70,0);row.label:SetHeight(18);row.label:SetJustifyH("LEFT")
                row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or "Interface\\AddOns\\Lychee\\Media\\MenuIcons\\spellbook.tga")
                row.icon:ClearAllPoints();row.icon:SetPoint("LEFT",entry.child and 20 or 8,0)
                row.meta:SetText(entry.child and tostring(id) or "")
                local multiple=not entry.child and #group.entries>1
                row.expand.frame:SetShown(multiple)
                if multiple then row.expand:SetText(tostring(#group.entries));row.expand:SetDirection(expanded and "down" or "right") end
                local selected=id==self.selected and (entry.child or not expanded)
                row.mark:SetShown(selected);row.bg:SetShown(selected)
                row.frame:Show()
            end
        end
        self.pageLabel:SetText(self.page.." / "..pages)
        self.previous:SetEnabled(self.page>1);self.next:SetEnabled(self.page<pages)
        self.previous.frame:SetShown(pages>1);self.next.frame:SetShown(pages>1);self.pageLabel:SetShown(pages>1)
        self.abilities:SetText(L["技能"].."  ·  "..#self.groups)
        self:Describe()
    end
    function panel:Create(parent)
        self.frame=CreateFrame("Frame",nil,parent);self.frame:SetAllPoints(parent);self.frame:Hide()
        self.title=label(self.frame,"input","text",16,-4,400,22);self.title:SetPoint("RIGHT",-178,0)
        self.subtitle=label(self.frame,"meta","textMuted",16,-30,584,16);self.subtitle:SetPoint("RIGHT",-16,0)
        self.back=nav(self.frame,L["返回搜索"],94,function()
            if not self.active then return end
            local c=I.Host and I.Host.PaletteController
            if c and c.viewHost and c.viewHost:IsOwnedBy(M.id) then c:CloseView("reference-back") end
        end,"left");self.back.frame:SetPoint("TOPRIGHT",-12,-2)
        self.traits=nav(self.frame,L["特性"],48,function() self:ShowTraits() end);self.traits.frame:SetPoint("TOPRIGHT",-118,-2)
        self.traits.frame:HookScript("OnLeave",function() if GameTooltip and GameTooltip:GetOwner()==self.traits.frame then GameTooltip:Hide() end end)
        local function line(y)
            local f=self.frame:CreateTexture(nil,"BORDER");f:SetPoint("TOPLEFT",16,y);f:SetPoint("RIGHT",-16,0);f:SetHeight(1);Theme:SetColorTexture(f,"border");return f
        end
        line(-52);self.divider=line(-250)
        self.model=CreateFrame("PlayerModel",nil,self.frame);self.model:SetPoint("TOPLEFT",16,-62);self.model:SetSize(214,168)
        self.model:EnableMouse(true);self.model:EnableMouseWheel(true)
        local function drag()
            if not self.active or (InCombatLockdown and InCombatLockdown()) or not IsMouseButtonDown("LeftButton") then self:StopDrag();return end
            local x=GetCursorPosition()/self.model:GetEffectiveScale()
            if x~=self.dragX then self.facing=(self.facing+(x-self.dragX)*0.012)%(2*math.pi);self.dragX=x;self.model:SetFacing(self.facing) end
        end
        self.model:SetScript("OnMouseDown",function(_,mouse)
            if mouse=="LeftButton" and self.active and not (InCombatLockdown and InCombatLockdown()) then self.dragX=GetCursorPosition()/self.model:GetEffectiveScale();self.model:SetScript("OnUpdate",drag) end
        end)
        self.model:SetScript("OnMouseUp",function() self:StopDrag() end)
        self.model:SetScript("OnHide",function() self:StopDrag() end)
        self.model:SetScript("OnMouseWheel",function(_,delta)
            if not self.active or (InCombatLockdown and InCombatLockdown()) then return end
            local zoom=math.max(0,math.min(0.7,self.zoom+delta*0.15))
            if zoom~=self.zoom then self.zoom=zoom;self.model:SetPortraitZoom(zoom) end
        end)
        self.modelMessage=label(self.frame,"body","textMuted",32,-142,180,32)
        self.dragHint=label(self.frame,"meta","textMuted",16,-233,170,16);self.dragHint:SetText(L["拖动旋转 · 滚轮缩放"])
        self.reset=nav(self.frame,L["复位"],40,function() if self.active then self:StopDrag();self.facing,self.zoom=0,0;self.model:SetFacing(0);self.model:SetPortraitZoom(0) end end)
        self.reset.frame:SetPoint("TOPLEFT",192,-225)
        self.abilities=label(self.frame,"body","text",252,-64,160,18)
        self.previous=nav(self.frame,"",20,function() if self.active then self.page=self.page-1;self:RenderSkills() end end,"left")
        self.next=nav(self.frame,"",20,function() if self.active then self.page=self.page+1;self:RenderSkills() end end,"right")
        self.next.frame:SetPoint("TOPRIGHT",-16,-60);self.previous.frame:SetPoint("TOPRIGHT",-90,-60)
        self.pageLabel=label(self.frame,"meta","textMuted",0,0,52,18);self.pageLabel:ClearAllPoints();self.pageLabel:SetPoint("RIGHT",self.next.frame,"LEFT",-4,0);self.pageLabel:SetJustifyH("CENTER")
        self.skillArea=CreateFrame("Frame",nil,self.frame);self.skillArea:SetPoint("TOPLEFT",244,-84);self.skillArea:SetPoint("RIGHT",-12,0);self.skillArea:SetHeight(PER_PAGE*ROW_HEIGHT)
        self.skillArea:EnableMouseWheel(true)
        self.skillBar=Components:CreateScrollbar(self.skillArea,function(value)
            local offset=math.floor(value/ROW_HEIGHT+0.5)
            if self.active and offset~=self.rowOffset then self.rowOffset=offset;self:RenderSkills() end
        end)
        self.skillArea:SetScript("OnMouseWheel",function(_,delta) if self.active then self.skillBar:SetValue((self.rowOffset-delta)*ROW_HEIGHT) end end)
        for i=1,MAX_ROWS do
            local row
            row=nav(self.skillArea,"",320,function()
                if not self.active or not row.spellID or row.pressed~=row.binding then return end
                row.pressed=nil
                if IsShiftKeyDown and IsShiftKeyDown() then self:LinkSpell(row.spellID);return end
                self.selected=row.spellID;self:RenderSkills()
            end)
            row.frame:SetPoint("TOPLEFT",0,-(i-1)*ROW_HEIGHT);row.frame:SetPoint("RIGHT",-14,0);row.frame:SetHeight(ROW_HEIGHT)
            row.frame:EnableMouseWheel(true);row.frame:SetScript("OnMouseWheel",function(_,delta) if self.active then self.skillBar:SetValue((self.rowOffset-delta)*ROW_HEIGHT) end end)
            row.icon=row.frame:CreateTexture(nil,"ARTWORK");row.icon:SetSize(20,20)
            row.meta=text(row.frame,"meta","textDim");row.meta:SetPoint("RIGHT",-6,0);row.meta:SetWidth(68);row.meta:SetHeight(16);row.meta:SetJustifyH("RIGHT")
            row.mark=row.frame:CreateTexture(nil,"ARTWORK");Theme:SetColorTexture(row.mark,"accent");row.mark:SetPoint("LEFT",0,0);row.mark:SetSize(2,22)
            row.bg=row.frame:CreateTexture(nil,"BACKGROUND");Theme:SetColorTexture(row.bg,"surfaceSelected");row.bg:SetPoint("TOPLEFT",0,-2);row.bg:SetPoint("BOTTOMRIGHT",0,2)
            row.expand=nav(row.frame,"",44,function()
                if not self.active or row.expandPressed~=row.binding or not row.group then return end
                row.expandPressed=nil
                local key=row.group.key;self.expanded[key]=not self.expanded[key];self.revealGroup=key;self:Flatten(false);self:RenderSkills()
            end,"right");row.expand.frame:SetPoint("RIGHT",0,0)
            row.expand.frame:HookScript("OnMouseDown",function(_,mouse) if mouse=="LeftButton" then row.expandPressed=row.binding end end)
            row.frame:HookScript("OnMouseDown",function(_,mouse) if mouse=="LeftButton" and self.active then row.pressed=row.binding end end)
            row.frame:HookScript("OnEnter",function()
                if not self.active or not row.spellID or not GameTooltip then return end
                GameTooltip:SetOwner(row.frame,"ANCHOR_LEFT");GameTooltip:ClearLines()
                GameTooltip:AddLine(M:SpellName(row.spellID) or (L["技能"].." "..row.spellID),1,1,1,true)
                GameTooltip:AddLine("ID "..row.spellID,0.71,0.705,0.69)
                GameTooltip:AddLine(L["Shift + 左键：贴入聊天框"],0.71,0.705,0.69);GameTooltip:Show()
            end)
            row.frame:HookScript("OnLeave",function() if GameTooltip and GameTooltip:GetOwner()==row.frame then GameTooltip:Hide() end end)
            row.frame:HookScript("OnHide",function()
                row.pressed=nil;row.expandPressed=nil
                if GameTooltip and GameTooltip:GetOwner()==row.frame then GameTooltip:Hide() end
            end)
            self.rows[i]=row
        end
        self.detailTitle=label(self.frame,"body","text",16,-262,250,18)
        self.detailMeta=label(self.frame,"meta","textMuted",280,-263,320,16);self.detailMeta:SetPoint("RIGHT",-16,0);self.detailMeta:SetJustifyH("RIGHT")
        self.descriptionScroll=CreateFrame("ScrollFrame",nil,self.frame);self.descriptionScroll:SetPoint("TOPLEFT",16,-288);self.descriptionScroll:SetPoint("RIGHT",-16,0);self.descriptionScroll:SetHeight(52)
        self.descriptionBody=CreateFrame("Frame",nil,self.descriptionScroll);self.descriptionBody:SetSize(570,52)
        self.description=text(self.descriptionBody,"body","textMuted");self.description:SetPoint("TOPLEFT");self.description:SetWidth(570)
        self.descriptionScroll:SetScrollChild(self.descriptionBody);self.descriptionScroll:EnableMouseWheel(true)
        self.descriptionBar=Components:CreateScrollbar(self.descriptionScroll,function(value) self.descriptionScroll:SetVerticalScroll(value);self:UpdateDescriptionSize() end)
        self.descriptionScroll:SetScript("OnMouseWheel",function(_,delta) self.descriptionBar:SetValue(self.descriptionScroll:GetVerticalScroll()-delta*24) end)
        self.descriptionScroll:SetScript("OnSizeChanged",function() if self.active then self:UpdateDescriptionSize() end end)
        self.hint=label(self.frame,"meta","textMuted",252,-352,348,16);self.hint:ClearAllPoints();self.hint:SetPoint("BOTTOMRIGHT",-16,0);self.hint:SetJustifyH("RIGHT")
    end
    function panel:Mount(context,state)
        local enemy,dungeon=M:Find(state.dungeonID,state.npcID,state.spellID);assert(enemy,L["资料暂不可用"])
        if not self.frame then self:Create(context.contentFrame) end
        if self.parent~=context.contentFrame then self.frame:SetParent(context.contentFrame);self.frame:ClearAllPoints();self.frame:SetAllPoints(context.contentFrame);self.parent=context.contentFrame end
        self.active,self.enemy,self.dungeon,self.pending,self.expanded=true,enemy,dungeon,{},{}
        self.resources=context.resources
        self.selected=state.spellID~=0 and state.spellID or enemy.spells[1] and enemy.spells[1].id
        self.page,self.facing,self.zoom,self.rowOffset,self.renderedPage=1,0,0,0,nil
        self.title:SetText(M:Name(enemy))
        self.subtitle:SetText(M:Name(dungeon).."  ·  "..L[enemy.isBoss and "首领" or "小怪"].."  ·  "..(types[enemy.creatureType] and L[types[enemy.creatureType]] or enemy.creatureType or "").." "..(enemy.level or "").."  ·  NPC "..enemy.id)
        self.hint:SetText(L["Shift + 左键：贴入聊天框"])
        self.event=context.resources:OnEvent("SPELL_DATA_LOAD_RESULT",function(_,id)
            if self.active and self.pending[id]==true then
                self.pending[id]=false
                if not self.refreshToken then self.refreshToken=self.resources:After("ldt-view-refresh",0,function()
                    self.refreshToken=nil
                    if self.active then self:BuildGroups(false);self:RenderSkills() end
                end) end
            end
        end)
        self.frame:Show();self.model:Show()
        local ok=pcall(function() self.model:ClearModel();self.model:SetDisplayInfo(enemy.displayId);self.model:SetPortraitZoom(0);self.model:SetCamDistanceScale(1);self.model:SetFacing(0) end)
        self.modelMessage:SetText(ok and "" or L["模型暂不可用"])
        self:BuildGroups(true);self:RenderSkills()
    end
    function panel:Unmount()
        self.active=false;self:StopDrag()
        if self.event then self.event:Cancel();self.event=nil end
        if self.refreshToken then self.refreshToken:Cancel();self.refreshToken=nil end
        for _,row in ipairs(self.rows) do row.spellID=nil;row.group=nil;row.frame:Hide();row.label:SetText("");row.meta:SetText("");row.icon:SetTexture(nil) end
        self.enemy,self.dungeon,self.pending,self.selected,self.groups,self.flat,self.expanded,self.resources=nil,nil,nil,nil,nil,nil,nil,nil
        self.pageItems,self.anchorID,self.anchorChild,self.revealID,self.revealGroup,self.renderedPage=nil,nil,nil,nil,nil,nil
        self.describedID,self.descriptionRaw=nil,nil
        if self.frame then
            if GameTooltip and GameTooltip:GetOwner()==self.traits.frame then GameTooltip:Hide() end
            self.title:SetText("");self.subtitle:SetText("");self.detailTitle:SetText("");self.detailMeta:SetText("");self.description:SetText("")
            self.descriptionBar:StopDrag();self.skillBar:StopDrag();self.model:Hide();pcall(self.model.ClearModel,self.model);self.frame:Hide()
        end
    end
    function panel:Dispose() self:Unmount() end
    M.panel=panel
    return panel
end
