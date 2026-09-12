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
C_Spell={GetSpellName=function(id)
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
loader.Load("provider",{"Search/ProviderPolicy.lua","Core/Scheduler.lua","UI/Theme.lua","UI/Components.lua"})
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
assert(definition.searchGlobal==true and definition.scope.products[1]=="retail" and #definition.scope.products==1)
local function query(input)
    local result
    local _,initial=I.Search.Query:Query(input,{visible=true},nil,function(rows) result=rows end)
    drain()
    local out={}
    for _,item in ipairs(result or initial) do out[#out+1]=assert(I.Providers.entries[M.id].dynamic[item.id]) end
    return out
end
forbidSpellReads=true
local boss=query("毒牙老二")[1]
assert(boss and boss.title=="扭缠盘蛇" and boss.payload.npcID==259446,"boss ordinal comes from journal order")
assert(query("毒牙二号boss")[1].id==boss.id)
assert(query("ldt:毒牙老2")[1].id==boss.id)
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
locale="enUS";I.Search.Normalizer.locale=locale
assert(query("Coil Test")[1].payload.spellID==1287798)
locale="zhCN";I.Search.Normalizer.locale=locale
combat=true;assert(#query("毒牙老二")==0);combat=false
assert(I.Registry:SetUserEnabled(M.id,false));assert(not M.active and not M:Resolve(boss.id))
assert(I.Registry:SetUserEnabled(M.id,true));assert(query("毒牙老二")[1].id==boss.id)
I.Providers:CancelQueries("warmup-end");drain()
collectgarbage("collect");before=collectgarbage("count");collectgarbage("stop")
for i=1,20 do query(i%2==0 and "缠绕测试" or "毒牙老二");I.Providers:CancelQueries("close") end
local allocated=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect");local growth=collectgarbage("count")-before
assert(allocated<32768 and growth<128,"query allocation and retention budget")
assert(maxBatch<8,"bounded task maximum callback budget")
local view=M:CreateView()
local parent=CreateFrame("Frame")
local resources=assert(I.Resources:Create(function()return true end,nil,assert(M.handle:Resources())))
local function mount() view:Mount({contentFrame=parent,resources=resources},{dungeonID=164,npcID=259446,spellID=1287798}) end
mount();assert(view.model.displayID==144156 and view.selected==1287798 and #view.rows==6)
view.enemy.characteristics={Stun=true,["Shackle Undead"]=true,Fear=false}
view:ShowTraits()
assert(GameTooltip.lines[2]:find("昏迷",1,true) and GameTooltip.lines[2]:find("束缚亡灵",1,true) and not GameTooltip.lines[2]:find("恐惧",1,true))
local row=view.rows[2]
row.frame.scripts.OnMouseDown(row.frame,"LeftButton");row.frame.scripts.OnClick(row.frame)
assert(view.selected==row.spellID,"normal click selects bound skill")
row.frame.scripts.OnMouseDown(row.frame,"LeftButton");view.page=2;view:RenderSkills()
local selected=view.selected;row.frame.scripts.OnClick(row.frame);assert(view.selected==selected,"stale press after rebind ignored")
view:Unmount();assert(not view.enemy and not view.selected and not view.model.displayID and not view.active)
assert(not GameTooltip.shown,"owned traits tooltip closes with view")
local high=#frames
for _=1,20 do mount();view:Unmount() end
assert(#frames==high,"views reuse frames and model")
I.Resources:Close(resources,"done");assert(I.Registry:SetUserEnabled(M.id,false));drain()
for _,frame in ipairs(frames) do assert(not frame.events.SPELL_DATA_LOAD_RESULT,"no idle spell subscription") end
assert(#timers==0 and not M.data and not M.nameCache,"no runtime catalogue/name cache retained")
print(string.format("LDT PASS: module=%.1f KiB query20_alloc=%.1f KiB growth=%.1f KiB max_batch=%.2f ms spell_calls=%d models=1",moduleMemory,allocated,growth,maxBatch,spellCalls))
