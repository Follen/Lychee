-- Real TOC/SDK assembly; fixtures supply engine data, not provider behavior.
local locale,combat="zhCN",false
local clock,frames,timers,spellCalls,requests=0,{},{},0,0
local methods={}
function methods:SetScript(key,fn) self.scripts[key]=fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key,fn) local old=self.scripts[key];self.scripts[key]=function(...) if old then old(...) end;fn(...) end end
function methods:RegisterEvent(key) self.events[key]=true end
function methods:UnregisterEvent(key) self.events[key]=nil end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:SetTexture(v) self.texture=v end
function methods:SetDisplayInfo(v) assert(v>0);self.displayID=v end
function methods:ClearModel() self.displayID=nil end
function methods:SetParent(p) self.parent=p end
function methods:GetParent() return self.parent end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 616 end
function methods:GetHeight() return self.height or 360 end
function methods:IsMouseOver() return false end
for _,name in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetFont','SetTextColor','SetColorTexture','SetShadowOffset','SetShadowColor','SetJustifyH','SetJustifyV','SetFacing','SetPortraitZoom','SetCamDistanceScale','Enable','Disable','SetAlpha','SetVertexColor','SetRotation','SetHitRectInsets','SetDrawLayer','EnableMouse','RegisterForClicks'}) do methods[name]=function() end end
function methods:SetWordWrap(value) self.wordWrap=value end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:SetScale(value) self.scale=value end
function CreateFrame(kind,name,parent)
    local f=setmetatable({kind=kind,parent=parent,scripts={},events={}},{__index=methods});frames[#frames+1]=f;return f
end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0","69587","fixture",120100 end
function InCombatLockdown() return combat end
function debugprofilestop() return os.clock()*1000 end
function GetTime() return clock end
STANDARD_TEXT_FONT="fixture"
GameTooltip={lines={}}
function GameTooltip:SetOwner(owner) self.owner=owner end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:ClearLines() self.lines={} end
function GameTooltip:AddLine(line) self.lines[#self.lines+1]=line end
function GameTooltip:SetSpellByID(id) self.spellID=id end
function GameTooltip:Show() self.shown=true end
function GameTooltip:Hide() self.shown=false;self.owner=nil end
local mouseHeld,shiftHeld,cursorX=false,false,0
function GetCursorPosition() return cursorX,0 end
function IsMouseButtonDown() return mouseHeld end
function IsShiftKeyDown() return shiftHeld end
function methods:GetEffectiveScale() return 1 end
function methods:GetStringHeight() return math.max(14,#(self.text or "")/8) end
function methods:SetScrollChild(value) self.child=value end
function methods:SetSpacing(value) self.spacing=value end
function methods:SetVerticalScroll(value) self.scroll=value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:EnableMouseWheel() end
local activeChat,opened,linked
ChatFrameUtil={GetActiveWindow=function() return activeChat end,OpenChat=function(value) opened=value end}
local missing,failed,synchronous,forbidSpellReads={},false,false,false
local function fire(event,...)
    for _,frame in ipairs(frames) do if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event,...) end end
end
C_Timer={NewTimer=function(delay,fn)
    local t={due=clock+delay,fn=fn};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
local maxBatch=0
local function drain()
    local count=0
    while #timers>0 do
        count=count+1;assert(count<10000,"runaway work")
        table.sort(timers,function(a,b)return a.due<b.due end)
        local t=table.remove(timers,1)
        if not t.cancelled then clock=t.due;local start=os.clock();t.fn();maxBatch=math.max(maxBatch,(os.clock()-start)*1000) end
    end
end
C_Spell={GetSpellLink=function(id) return not missing[id] and ("|Hspell:"..id.."|h[Ability]|h") or nil end,GetSpellName=function(id)
    assert(not forbidSpellReads,"exact creature lookup must not touch unrelated spell data")
    spellCalls=spellCalls+1
    if missing[id] then return nil end
    if id==1287798 then return locale=="zhCN" and "缠绕测试" or "Coil Test" end
    return "Ability "..id
end,GetSpellTexture=function(id)return id end,GetSpellDescription=function(id)return "Description "..id end,
RequestLoadSpellData=function(id)
    requests=requests+1
    local function loaded() if not failed then missing[id]=nil end;fire("SPELL_DATA_LOAD_RESULT",id,not failed) end
    if synchronous then loaded() else C_Timer.NewTimer(0.1,loaded) end
end}
local loader=dofile("tests/support/runtime.lua")
loader.Load("provider",{"Search/ProviderPolicy.lua","Core/Scheduler.lua","UI/Theme.lua","UI/Motion.lua","UI/Presence.lua","UI/Runtime.lua","UI/Components.lua","UI/Components.lua"})
local I=LycheeInternal
collectgarbage("collect");local before=collectgarbage("count")
loader.Load(nil,{"Builtin/LDT/Locales.lua","Builtin/LDT/Data.lua","Builtin/LDT/Catalog.lua","Builtin/LDT/View.lua","Builtin/LDT/Provider.lua"})
collectgarbage("collect");local moduleMemory=collectgarbage("count")-before
assert(moduleMemory<512,"feature loading budget")
local M=I.Builtin.LDT
I.Registry:SetReady(true)
local count=#frames
assert(M:Init());assert(M.active and #frames==count and #timers==0,"default enable has no activity")
local definition=I.Providers.entries[M.id].definition
assert(definition.title=="荔枝大米助手", "localized provider title")
assert(definition.searchGlobal==true and definition.scope.products[1]=="retail" and #definition.scope.products==1)
local function query(input)
    local result
    local _,initial=I.Search.Query:Query(input,{visible=true},nil,function(rows) result=rows end)
    drain()
    local out={}
    for _,item in ipairs(result or initial) do out[#out+1]=assert(I.Providers.entries[M.id].dynamic[item.id]) end
    return out
end
assert(not M:Find(160,236091,1221063) and not M:Resolve("160/236091/1221063"),"excluded affix cannot restore from a saved reference")
assert(#query("1221063")==0,"excluded affix cannot appear in search")
do
    local target
    for _,did in ipairs(M.dungeonIDs) do
        M:ScanDungeon(did,function(enemy,dungeon)
            local _,second=enemy.spellIDs:match("^(%d+),(%d+)")
            if second and second~="1287798" then target=dungeon.id.."/"..enemy.id.."/"..second end
        end,{})
    end
    assert(target)
    local resources=assert(I.Resources:Create(function() return true end))
    local ranked
    M:Query({normalized="ability",limit=20,ranking={[target]=30}},function(rows) ranked=rows end,
        {resources=resources,fail=function(problem) error(problem.code) end})
    drain();I.Resources:Close(resources,"complete")
    assert(ranked and #ranked==20 and ranked[1].id==target,"preferred second skill survives representative choice and Top20")
    local failure,called
    M:Query({normalized="ability",limit=20},function()called=true end,
        {resources={Own=function()return {} end,OnEvent=function()return nil end},fail=function(problem) failure=problem.code end})
    assert(failure=="RESOURCE_UNAVAILABLE" and not called,"resource failure cannot masquerade as successful empty search")
    I.Search.Query:Query("ability",{visible=true})
    I.Search.Normalizer.locale="enUS"
    drain()
    assert(I.Search.Query.last.incomplete,"locale change invalidates in-flight name search")
    I.Search.Normalizer.locale=locale
end

do
    local function equal(a,b,path)
        assert(type(a)==type(b),"transcript type "..path)
        if type(a)~="table" then assert(a==b,"transcript value "..path);return end
        for key,value in pairs(a) do equal(value,b[key],path.."/"..tostring(key)) end
        for key in pairs(b) do assert(a[key]~=nil,"transcript missing "..path.."/"..tostring(key)) end
    end
    local savedClock=debugprofilestop
    debugprofilestop=function() return 0 end -- Match reference ranking independently from CPU budgets.
    for _,case in ipairs(dofile("tests/fixtures/ldt_search.lua")) do
        locale=case.locale;I.Search.Normalizer.locale=locale
        local rows={}
        for _,row in ipairs(query(case.input)) do
            rows[#rows+1]={id=row.id,title=row.title,subtitle=row.subtitle,icon=row.icon,kind=row.kind,kindTitle=row.kindTitle:gsub("^荔枝大米助手","LDT"),aliases=row.aliases,payload=row.payload,actions=row.actions}
        end
        equal(rows,case.rows,case.locale..":"..case.input)
    end
    debugprofilestop=savedClock;locale="zhCN";I.Search.Normalizer.locale=locale
end
forbidSpellReads=true
local boss=query("毒牙老二")[1]
assert(boss.kindTitle=="荔枝大米助手 · 首领", "localized result kind")
assert(boss and boss.title=="扭缠盘蛇" and boss.payload.npcID==259446,"boss ordinal comes from journal order")
assert(query("毒牙二号boss")[1].id==boss.id)
assert(query("ldt:毒牙老2")[1].id==boss.id)
assert(query("毒牙尾王")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(query("毒牙尾王boss")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(query("毒牙最终boss")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(query("毒牙祭坛尾王")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(query("Altar of Fangs final boss")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(query("Altar of Fangs last boss")[1].payload.npcID==259447,"final boss alias resolves the actual last journal encounter")
assert(#query("不存在副本尾王")==0)
assert(query("259446")[1].payload.npcID==259446)
forbidSpellReads=false
local skill=query("缠绕测试")[1]
assert(skill and skill.payload.npcID==259446 and skill.payload.spellID==1287798,"global spell lookup links the actual creature")
assert(query("1287798")[1].payload.spellID==1287798)
assert(#query("definitely-absent-npc")==0)
assert(not I.Search.Normalizer.cache["ability 1287811"],"scanning must not fill shared normalization cache")
local recovered=M:Resolve(skill.id);assert(recovered.payload.spellID==1287798)
assert(not M:Resolve("164/259446/1") and not M:Resolve("bogus"))
for _,sync in ipairs({false,true}) do
    synchronous=sync;missing[1287798]=true
    assert(query("缠绕测试")[1].payload.spellID==1287798,"uncached spell loading including synchronous completion")
end
synchronous=false;failed=true;missing[1287798]=true
assert(#query("缠绕测试")==0);failed=false;missing[1287798]=nil
local callback=false
I.Search.Query:Query("缠绕测试",{visible=true},nil,function() callback=true end)
I.Providers:CancelQueries("test-close");drain();assert(not callback,"cancelled query cannot publish")
missing[1287798]=true;local requestBase=requests;callback=false
I.Search.Query:Query("缠绕测试",{visible=true},nil,function() callback=true end)
local steps=0
while requests==requestBase and #timers>0 do
    steps=steps+1;assert(steps<300)
    table.sort(timers,function(a,b)return a.due<b.due end)
    local t=table.remove(timers,1);if not t.cancelled then clock=t.due;t.fn() end
end
assert(requests>requestBase,"spell request was actually pending before cancellation")
I.Providers:CancelQueries("late-load-close");drain();assert(not callback,"late spell data cannot publish after cancellation")
do
    local scan=M.ScanDungeon
    local borrowed=setmetatable({},{__mode="v"})
    M.ScanDungeon=function(self,id,visit,scratch) borrowed[1]=scratch;return scan(self,id,visit,scratch) end
    I.Search.Query:Query("cancel-borrowed-scratch",{visible=true})
    local steps=0
    while not borrowed[1] and #timers>0 do
        steps=steps+1;assert(steps<300)
        table.sort(timers,function(a,b)return a.due<b.due end)
        local t=table.remove(timers,1);if not t.cancelled then clock=t.due;t.fn() end
    end
    assert(borrowed[1],"the real scan must have borrowed a scratch record")
    I.Providers:CancelQueries("scratch-close");drain();M.ScanDungeon=scan
    collectgarbage("collect")
    assert(not borrowed[1],"cancel must release the suspended scan's borrowed record")
end
locale="enUS";I.Search.Normalizer.locale=locale
assert(query("Coil Test")[1].payload.spellID==1287798)
locale="zhCN";I.Search.Normalizer.locale=locale
combat=true;assert(#query("毒牙老二")==0);combat=false
assert(I.Registry:SetUserEnabled(M.id,false));assert(M.active and M:Resolve(boss.id) and #query("毒牙老二")==0,"search opt-out preserves explicit restoration")
assert(I.Registry:SetUserEnabled(M.id,true))
assert(M.handle:SetAvailability(false));assert(not M.active and not M:Resolve(boss.id))
assert(M.handle:SetAvailability(true));assert(query("毒牙老二")[1].id==boss.id)
I.Providers:CancelQueries("warmup-end");drain()
collectgarbage("collect");before=collectgarbage("count");collectgarbage("stop")
for i=1,20 do query(i%2==0 and "缠绕测试" or "毒牙老二");I.Providers:CancelQueries("close") end
local allocated=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect");local growth=collectgarbage("count")-before
assert(allocated<4096 and growth<128,"query allocation and retention budget")
assert(maxBatch<8,"bounded task maximum callback budget")
UIParent=CreateFrame("Frame");UIParent:SetSize(1000,800)
function UIParent:GetEffectiveScale() return 1 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetScale(value) self.scale=value end
local view=M:CreateView()
local parent=CreateFrame("Frame")
local resources=assert(I.Resources:Create(function()return true end,nil,assert(M.handle:Resources())))
local function mount() view:Mount({contentFrame=parent,resources=resources,
    SetFooter=function(_,value) parent.footer=value;return true end,Resize=function(_,height) parent.requestedHeight=height;return true end,
    ClearFocus=function() return true end,Close=function() return true end},{dungeonID=164,npcID=259446,spellID=1287798}) end
mount();assert(view.model.displayID==144156 and view.selected==1287798 and #view.rows==8)
assert(parent.footer=="","detail has no permanent footer hint")
assert(not view.traits and not view.back and not view.descriptionScroll,"detail removes traits, duplicate back and bottom reading area")
view.rows[1].frame.scripts.OnEnter()
assert(not GameTooltip.owner and not GameTooltip.shown,"Lychee details do not alter the global game tooltip")
assert(Lychee.UI.Components.tooltip.labels[3]:GetText()~="","skill description is in tooltip")
local delayedRow=view.rows[1]
local delayedID=delayedRow.spellID
local descriptionAPI=C_Spell.GetSpellDescription
local ready=false
C_Spell.GetSpellDescription=function(id) if id==delayedID and not ready then return nil end;return descriptionAPI(id) end
delayedRow.frame.IsMouseOver=function() return true end
view.pending[delayedID]=nil
delayedRow.frame.scripts.OnEnter()
assert(Lychee.UI.Components.tooltip.labels[3]:GetText()=="技能资料暂未加载")
ready=true;drain()
assert(Lychee.UI.Components.tooltip._owner==delayedRow.frame and Lychee.UI.Components.tooltip.labels[3]:GetText()==M:FormatDescription(descriptionAPI(delayedID)),"late data refreshes the currently hovered skill tooltip")
C_Spell.GetSpellDescription=descriptionAPI
delayedRow.frame.IsMouseOver=function() return false end
local row=view.rows[2]
row.frame.scripts.OnMouseDown(row.frame,"LeftButton");row.frame.scripts.OnClick(row.frame)
assert(view.selected==row.spellID,"normal click selects bound skill")
row.frame.scripts.OnMouseDown(row.frame,"LeftButton");view.page=2;view:RenderSkills()
local selected=view.selected;row.frame.scripts.OnClick(row.frame);assert(view.selected==selected,"stale press after rebind ignored")
view:Unmount();assert(not view.enemy and not view.selected and not view.model.displayID and not view.active)
assert(not Lychee.UI.Components.tooltip:IsShown(),"owned skill tooltip closes with view")
-- Duplicate spell names collapse without losing any IDs; unrelated unknown names stay separate.
mount()
local originalName=C_Spell.GetSpellName
local first,second,third=view.enemy.spells[1].id,view.enemy.spells[2].id,view.enemy.spells[3].id
C_Spell.GetSpellName=function(id) if id==first or id==second then return "同名触发技能" end;return originalName(id) end
view.selected=first;view:BuildGroups(true);view:RenderSkills()
local group=view.groups[1]
assert(#group.entries==2 and #view.groups==#view.enemy.spells-1 and not view.expanded[group.key])
local groupRow=view.rows[1]
local function clickSkill(row)
    row.frame.scripts.OnMouseDown(row.frame,"LeftButton");row.frame.scripts.OnClick(row.frame)
end
clickSkill(groupRow)
assert(view.expanded[group.key],"whole group heading expands")
clickSkill(view.rows[3])
assert(view.selected==second and view.expanded[group.key],"child selects its exact ID without collapsing")
clickSkill(groupRow)
assert(not view.expanded[group.key] and view.selected==second and groupRow.spellID==second,"heading collapses and retains exact selection")
shiftHeld=true;clickSkill(groupRow);shiftHeld=false
assert(opened==C_Spell.GetSpellLink(second) and not view.expanded[group.key],"shift heading links exact selection without toggling")
groupRow.frame.scripts.OnMouseDown(groupRow.frame,"LeftButton");view:RenderSkills();groupRow.frame.scripts.OnClick(groupRow.frame)
assert(not view.expanded[group.key],"stale heading press cannot toggle a rebound group")
view.selected=first;view:RenderSkills()
groupRow.expand.frame.scripts.OnMouseDown(groupRow.expand.frame,"LeftButton");groupRow.expand.frame.scripts.OnClick(groupRow.expand.frame)
assert(view.expanded[group.key] and view.flat[2].spellID==first and view.flat[3].spellID==second)
local child=view.rows[3]
shiftHeld=true
child.frame.scripts.OnMouseDown(child.frame,"LeftButton");child.frame.scripts.OnClick(child.frame)
assert(opened==C_Spell.GetSpellLink(second) and view.selected==first,"shift click links exact child ID without selection")
activeChat={Insert=function(_,value) linked=value end,SetFocus=function(self) self.focused=true end}
child.frame.scripts.OnMouseDown(child.frame,"LeftButton");child.frame.scripts.OnClick(child.frame)
assert(linked==C_Spell.GetSpellLink(second) and activeChat.focused,"existing chat receives link")
assert(parent.footer=="","successful links keep the footer empty")
linked=nil;child.frame.scripts.OnMouseDown(child.frame,"LeftButton");view:RenderSkills();child.frame.scripts.OnClick(child.frame)
assert(not linked,"rebound row cannot insert a stale link")
missing[second]=true
child.frame.scripts.OnMouseDown(child.frame,"LeftButton");child.frame.scripts.OnClick(child.frame)
assert(not linked and view.hintText=="链接暂不可用，请稍后重试")
drain();assert(not linked,"late spell load never inserts a link automatically")
clickSkill(child)
assert(linked==C_Spell.GetSpellLink(second) and parent.footer=="","retry success clears the temporary failure hint")
shiftHeld=false;activeChat=nil
view.selected=second;view:BuildGroups(true);view:RenderSkills()
assert(view.expanded[group.key] and view.selected==second,"deep-linked member is revealed")
C_Spell.GetSpellName=function(id) if id==first or id==third then return nil end;return originalName(id) end
view:BuildGroups(false);assert(#view.groups==#view.enemy.spells,"unknown names remain separate")
C_Spell.GetSpellName=originalName;drain()
-- Async name regrouping keeps a visible selection visible; deliberate paging keeps its anchor.
local actualEnemy=view.enemy
local regrouped=false
view.enemy={spells={}}
for i=1,12 do view.enemy.spells[i]={id=900000+i} end
C_Spell.GetSpellName=function(id)
    if id>900000 and id<=900012 then return regrouped and id<=900006 and "合并技能" or ("技能 "..id) end
    return originalName(id)
end
view.expanded={};view.selected=900008;view:BuildGroups(true);view:RenderSkills()
assert(view.page==2 and view.rows[2].spellID==900008)
regrouped=true;view:BuildGroups(false);view:RenderSkills()
assert(view.page==1 and view.rows[3].spellID==900008,"async regroup must keep the previously visible selection visible")
regrouped=false;view.selected=900002;view:BuildGroups(true);view:RenderSkills()
view.page=2;view:RenderSkills()
regrouped=true;view:BuildGroups(false);view:RenderSkills()
assert(view.page==1 and view.rows[2].spellID==900007 and not view.expanded["合并技能"],"async regroup preserves manual page anchor without revealing an off-page selection")
-- Expanded group headers cannot steal an exact child anchor on a later page.
C_Spell.GetSpellName=function(id) if id>900001 and id<=900012 then return "展开分组" end;return "技能 "..id end
view.expanded={["展开分组"]=true};view.selected=900001;view:BuildGroups(true);view:RenderSkills()
view.rowOffset=4;view:RenderSkills()
local anchoredID=view.rows[1].spellID
view:BuildGroups(false);view:RenderSkills()
assert(view.page==1 and view.rows[1].spellID==anchoredID,"an unchanged expanded child viewport must not jump to its group header")
C_Spell.GetSpellName=function(id) return "技能 "..id end
view.expanded={};view.selected=900008;view:BuildGroups(true);view:RenderSkills()
local tooltipRow=view.rows[2]
tooltipRow.frame.scripts.OnEnter(tooltipRow.frame)
assert(Lychee.UI.Components.tooltip:IsShown() and Lychee.UI.Components.tooltip.labels[1]:GetText()=="技能 900008" and Lychee.UI.Components.tooltip.labels[2]:GetText()=="ID 900008")
view:RenderSkills();assert(not Lychee.UI.Components.tooltip:IsShown(),"rebind closes the old skill tooltip")
-- The sixth group expands inline rather than pushing its children onto another page.
view.enemy={spells={}};for i=1,9 do view.enemy.spells[i]={id=910000+i} end
C_Spell.GetSpellName=function(id) return (id==910006 or id==910007) and "同步毒液" or ("技能 "..id) end
view.expanded={};view.selected=910006;view:BuildGroups(true);view:RenderSkills()
local oldHeight=parent.requestedHeight
local sixth=view.rows[6]
sixth.expand.frame.scripts.OnMouseDown(sixth.expand.frame,"LeftButton");sixth.expand.frame.scripts.OnClick(sixth.expand.frame)
assert(view.page==1 and view.rows[7].spellID==910006 and view.rows[8].spellID==910007,"both children of the last group are immediately visible")
assert(view.rows[7].frame:IsShown() and view.rows[8].frame:IsShown() and parent.requestedHeight==oldHeight)
sixth.expand.frame.scripts.OnMouseDown(sixth.expand.frame,"LeftButton");sixth.expand.frame.scripts.OnClick(sixth.expand.frame)
assert(parent.requestedHeight==oldHeight and not view.rows[7].frame:IsShown(),"collapse keeps the enlarged model layout stable")
C_Spell.GetSpellName=function(id) return "全部同名" end
view.expanded={};view:BuildGroups(true);view:RenderSkills()
view.expanded["全部同名"]=true;view:Flatten(false);view:RenderSkills()
assert(view.skillBar.maximum>0)
local originalDescription=C_Spell.GetSpellDescription
C_Spell.GetSpellDescription=function() return string.rep("description 123 ",200) end
local readingRow=view.rows[1]
readingRow.frame.scripts.OnEnter()
local tip=Lychee.UI.Components.tooltip
assert(tip.reading:IsShown() and tip.reading.bar.maximum>0,"long skill description gets bounded tooltip scrolling")
readingRow.frame.scripts.OnMouseWheel(nil,-1)
assert(tip.reading:GetVerticalScroll()>0,"wheel over the hovered skill reads its long tooltip")
assert(tip.labels[3]:GetText():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")==C_Spell.GetSpellDescription(),"tooltip preserves complete long text")
view.skillArea.scripts.OnMouseWheel(view.skillArea,-1)
assert(not tip:IsShown(),"skill list scrolling closes stale tooltip")
C_Spell.GetSpellDescription=originalDescription
readingRow.frame.scripts.OnEnter()
assert(not tip.reading:IsShown() and tip.labels[3]:GetParent()==tip and tip.labels[3]:GetWidth()==372,"short descriptions leave the scroll child and restore full text width")
readingRow.frame.scripts.OnLeave()

view.skillArea.scripts.OnMouseWheel(view.skillArea,-100)
assert(view.rows[8].spellID==910009 and #view.rows==8,"scroll reaches the final child without allocating more rows")
local raw="对5码内造成29,647点伤害，在6秒内每2秒造成26,353点伤害，提高6.5%。"
local highlighted=M:FormatDescription(raw)
assert(highlighted:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")==raw,"numeric styling preserves the description text")
for _,number in ipairs({"5","29,647","6","2","26,353","6.5%"}) do assert(highlighted:find(Lychee.UI.Theme.MatchColorCode..number.."|r",1,true)) end
local markup="|cffff0000已有5秒|r |Hspell:123|h[技能2]|h |T123:16|t |Aatlas:16:16|a"
assert(M:FormatDescription(markup)==markup,"native color, hyperlink and texture/atlas markup is preserved")
C_Spell.GetSpellName=originalName;view.enemy=actualEnemy
-- Drag has one active update script; release outside, combat, hide and unmount stop it.
mouseHeld=true;cursorX=10;view.model.scripts.OnMouseDown(view.model,"LeftButton")
assert(view.model.scripts.OnUpdate)
local facing=view.facing;cursorX=50;view.model.scripts.OnUpdate();assert(view.facing~=facing)
mouseHeld=false;view.model.scripts.OnUpdate();assert(not view.model.scripts.OnUpdate)
mouseHeld=true;view.model.scripts.OnMouseDown(view.model,"LeftButton");combat=true;view.model.scripts.OnUpdate()
assert(not view.model.scripts.OnUpdate);combat=false
view.model.scripts.OnMouseWheel(view.model,100);assert(view.zoom==0.7)
view.model.scripts.OnMouseWheel(view.model,-100);assert(view.zoom==0)
view.facing,view.zoom=1,0.3
view.reset.frame.scripts.OnClick(view.reset.frame)
assert(view.facing==0 and view.zoom==0 and not view.model.scripts.OnUpdate,"icon reset restores the model camera and ends dragging")
assert(view.reset.label:GetText()=="" and view.reset.icon.texture=="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\reload.tga")
view.reset.frame.scripts.OnEnter(view.reset.frame)
assert(Lychee.UI.Components.tooltip:IsShown() and Lychee.UI.Components.tooltip.labels[1]:GetText()=="重置视角")
view.model.scripts.OnMouseDown(view.model,"LeftButton");view:Unmount()
assert(not view.model.scripts.OnUpdate and not view.groups and not view.flat and not view.expanded and not view.resources)
assert(not Lychee.UI.Components.tooltip:IsShown() and not view.hintText,"closing clears owned tooltip, and footer reference")
mouseHeld=false
local high=#frames

for _=1,20 do mount();view:Unmount() end
assert(#frames==high,"views reuse frames and model")
I.Resources:Close(resources,"done");assert(M.handle:SetAvailability(false));drain()
for _,frame in ipairs(frames) do assert(not frame.events.SPELL_DATA_LOAD_RESULT,"no idle spell subscription") end
assert(#timers==0 and not M.data and not M.nameCache,"no runtime catalogue/name cache retained")
print(string.format("LDT PASS: module=%.1f KiB query20_alloc=%.1f KiB growth=%.1f KiB max_batch=%.2f ms spell_calls=%d models=1",moduleMemory,allocated,growth,maxBatch,spellCalls))
