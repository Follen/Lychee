-- Offline UI allocation/identity regression. Optional argument is an addon root
-- for measuring an unchanged baseline; --check enforces the new budget.
local root, check = "addon/Lychee/", false
for _, value in ipairs(arg or {}) do
    if value == "--check" then check = true else root = value:gsub("[/\\]$", "") .. "/" end
end
local objects, setters, resolves = 0, 0, 0
local methods = {}
local function object(parent)
    objects = objects + 1
    return setmetatable({parent=parent, shown=true, height=400, width=592, scripts={}}, {__index=methods})
end
function methods:SetScript(event, fn) self.scripts[event]=fn end
function methods:SetAllPoints() setters=setters+1 end
function methods:ClearAllPoints() setters=setters+1 end
function methods:SetPoint(...) setters=setters+1; self.point={...} end
function methods:SetSize(w,h) setters=setters+1;self.width,self.height=w,h end
function methods:SetWidth(w) setters=setters+1;self.width=w end
function methods:SetHeight(h) setters=setters+1;self.height=h end
function methods:GetHeight() return self.height end
function methods:GetText() return self.text or "" end
function methods:SetText(v) setters=setters+1;self.text=v end
function methods:SetShown(v) setters=setters+1;self.shown=v end
function methods:IsShown() return self.shown end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false);if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetTexture(v) setters=setters+1;self.texture=v;return true end
function methods:SetColorTexture() setters=setters+1 end
function methods:SetTextColor() setters=setters+1 end
function methods:SetFont() setters=setters+1;return true end
function methods:SetShadowOffset() end
function methods:SetJustifyH() end
function methods:EnableMouseWheel() end
function methods:EnableMouse() end
function methods:RegisterForDrag() end
function methods:SetScrollChild(v) self.child=v end
function methods:SetVerticalScroll(v) setters=setters+1;self.verticalScroll=v end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:IsMouseOver() return self.hovered==true end
function methods:CreateTexture() return object(self) end
function methods:CreateFontString() return object(self) end
function CreateFrame(_,_,parent) return object(parent) end
function GetLocale() return "zhCN" end
function InCombatLockdown() return _G.combat==true end
STANDARD_TEXT_FONT="test.ttf"
Lychee={UI={}}
local pins={}
for i=1,30 do pins[i]={entryID=tostring(i),title="Pin "..i} end
LycheeInternal={Providers={entries={}},Registry={entries={}},UserPreferences={}}
local I=LycheeInternal
local mutations=0
function I.UserPreferences:GetPins() return pins end
function I.UserPreferences:Resolve(pin) resolves=resolves+1;return {text=pin.title,icon=1,sourceTitle="Source"} end
function I.UserPreferences:Move(from,to)
    if not pins[from] or not pins[to] then return false end
    mutations=mutations+1
    table.insert(pins,to,table.remove(pins,from));return true
end
function I.UserPreferences:Remove(index) mutations=mutations+1;return table.remove(pins,index) end
function I.Registry:SetUserEnabled(id,value) mutations=mutations+1;self.entries[id].userEnabled=value;return true end
local controller={MarkHomeDirty=function() end,SetStatusText=function() end}
local frameFactory=CreateFrame
CreateFrame=nil
dofile(root.."Bootstrap.lua")
CreateFrame=frameFactory
I.Search=I.Search or {}
dofile(root.."Core/ProviderManagement.lua")
for _, name in ipairs({"Theme","Runtime","Components","SettingsView"}) do dofile(root.."UI/"..name..".lua") end
for i=1,1000 do
    local id=string.format("external.%04d",i)
    I.Providers.entries[id]={instanceToken=i,definition={title=id,version="1"}}
    I.Registry.entries[id]={userEnabled=true}
end
local view=Lychee.UI.SettingsView:Create(object(),controller)
view.scrollFrame.height=400;view.frame:Show()
collectgarbage("collect")
local before=collectgarbage("count")
local started=os.clock()
view:Refresh()
local cold=(os.clock()-started)*1000
collectgarbage("collect")
local retained=collectgarbage("count")-before
local firstObjects,firstRows=objects,#view.rows
collectgarbage("stop")
before=collectgarbage("count");started=os.clock()
for i=1,20 do view:Refresh() end
local refresh=(os.clock()-started)*1000
local allocated=collectgarbage("count")-before
collectgarbage("restart")
-- Visit the end and return repeatedly; pool growth must depend on viewport.
for i=1,20 do
    view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-1000)
    view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,1000)
end
print(string.format("providers=1000 rows=%d objects=%d cold_ms=%.3f retained_kib=%.1f refresh20_ms=%.3f refresh20_alloc_kib=%.1f pool_growth=%d",firstRows,firstObjects,cold,retained,refresh,allocated,objects-firstObjects))
if check then
    assert(#view.rows<=math.ceil(400/46)+1,"row pool must be bounded by viewport")
    assert(retained<1024,"1000-source UI retained allocation stays below 1 MiB")
    assert(allocated<512,"20 unchanged refreshes allocate less than 512 KiB")
    view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-1000)
    local last
    for _,row in ipairs(view.rows) do if row:IsShown() then last=row end end
    assert(last.providerID=="external.1000","last source remains reachable")
    last.toggle.scripts.OnClick()
    assert(I.Registry.entries["external.1000"].userEnabled==false,"reused toggle targets current source")
end
view:SetTab("pins")
local firstResolve=resolves
print("pins30_initial_resolves="..firstResolve)
if check then assert(firstResolve<=10,"only visible pins resolve") end
view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-1000)
if check then
    local last
    for _,row in ipairs(view.rows) do if row:IsShown() then last=row end end
    assert(last.pinIndex==30 and not last.down.enabled,"last pin preserves absolute identity and down disabled")
    local prior=pins[30]
    last.up.frame.scripts.OnClick()
    assert(pins[29]==prior,"recycled up button moves absolute pin")
    view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,1000)
    local dragged=view.rows[1]
    local firstPin=pins[1]
    dragged.scripts.OnDragStart()
    view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-1000)
    for _,row in ipairs(view.rows) do row.hovered=row.pinIndex==30 end
    dragged.scripts.OnDragStop()
    assert(pins[30]==firstPin,"drag across a recycled viewport preserves source and target indices")
    for _,row in ipairs(view.rows) do row.hovered=false end
    view.scrollFrame.height=600;view.scrollFrame.scripts.OnSizeChanged()
    assert(#view.rows<=math.ceil(600/46)+1,"resized pool stays viewport bounded")
    local scrollBefore=view.scroll
    combat=true;view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,1);combat=false
    assert(view.scroll==scrollBefore,"combat wheel does no work")
    view.frame:Hide()
    assert(view.data==nil,"hidden settings releases snapshot")
    for _,row in ipairs(view.rows) do assert(not row.pinIndex and not row.providerID,"release clears identities") end
    view.frame:Show();view:Refresh()
    assert(view.rows[1].pinIndex,"reopen restores rows")
    local function press(control)
        if control.scripts.OnMouseDown then control.scripts.OnMouseDown(control,"LeftButton") end
    end
    local function release(control)
        if control.scripts.OnMouseUp then control.scripts.OnMouseUp(control,"LeftButton") end
        control.scripts.OnClick(control,"LeftButton")
    end
    for _,name in ipairs({"up","down","remove"}) do
        view:SetTab("pins")
        local control=view.rows[2][name].frame
        local before=mutations
        press(control);view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-1);release(control)
        assert(mutations==before,"scroll during "..name.." press must cancel stale click")
    end
    view:SetTab("pins")
    local control=view.rows[2].remove.frame
    local before=mutations
    press(control);pins[2],pins[3]=pins[3],pins[2];view:Refresh();release(control)
    assert(mutations==before,"same index with different pin invalidates press")
    press(control);view.frame:Hide();view.frame:Show();view:Refresh();release(control)
    assert(mutations==before,"hide/reopen cannot revive a press")
    press(control);control:Hide();control:Show();release(control)
    assert(mutations==before,"individual control hide cannot revive a press")
    press(control);view.rows[2].remove:SetEnabled(false);view.rows[2].remove:SetEnabled(true);release(control)
    assert(mutations==before,"disable/enable cannot revive a press")
    press(control);release(control)
    assert(mutations==before+1,"normal mouse sequence remains usable")
    view:SetTab("providers")
    control=view.rows[2].toggle;before=mutations
    press(control);view.scrollFrame.scripts.OnMouseWheel(view.scrollFrame,-2);release(control)
    assert(mutations==before,"scroll during provider press must cancel stale click")
    view:SetTab("providers");control=view.rows[2].toggle
    local id=view.rows[2].providerID
    press(control)
    I.Providers.entries[id]={instanceToken=2001,definition={title=id,version="2"}}
    view:Refresh();release(control)
    assert(mutations==before,"same source ID with new provider invalidates press")
    press(control);release(control)
    assert(mutations==before+1,"normal provider mouse sequence remains usable")
    I.Providers.entries["builtin.mounts"]={instanceToken=2002,definition={title="Mounts",version="1"}}
    I.Registry.entries["builtin.mounts"]={userEnabled=true}
    view:SetTab("providers")
    assert(view.rows[1].providerID=="builtin.mounts","built-in ordering survives reuse")
    assert(view.rows[2]._y==110,"group spacing survives virtualization with shared row gap")
    for id in pairs(I.Providers.entries) do I.Providers.entries[id]=nil end
    local added={"builtin.bags","builtin.talent-loadouts","builtin.equipment-sets","builtin.blizzard-settings","builtin.keystones"}
    local icons={"toys.tga","talents.tga","character.tga","settings.tga","keystone.tga"}
    for _,id in ipairs(added) do
        I.Providers.entries[id]={instanceToken=3000,definition={title="新增功能",version="1.0.0"}}
        I.Registry.entries[id]={userEnabled=false}
    end
    view:SetTab("providers")
    for index,id in ipairs(added) do
        local record,row=view.data[index],view.rows[index]
        assert(record.id==id and record.builtin,"new providers belong to built-in group: "..id)
        assert(not row.detail:GetText():find("builtin.",1,true),"internal ID must not be presented as description")
        assert(row._icon=="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"..icons[index],"provider icon: "..id)
        assert(I.Registry.entries[id].userEnabled==false,"presentation must preserve disabled state")
    end
    for id in pairs(I.Providers.entries) do I.Providers.entries[id]=nil end
    view:Refresh()
    for _,row in ipairs(view.rows) do assert(not row:IsShown(),"empty source list releases pooled rows") end
end
print("performance_ui: PASS"..(check and " (budgets enforced)" or " (measurement only)"))
