-- Recorded reopen sequence: real Palette/Home/Presence, native geometry and
-- pointer delivery substitutes. This does not emulate WoW rasterization.
dofile("tests/support/palette.lua")
local Fixture=dofile("tests/support/provider_fixture.lua")
local I=LycheeInternal;I.Registry:SetReady(true)
local entries={}
local calls=0
for i=1,8 do entries[i]={id="item"..i,title="Popup "..i,actions={"open"}} end
entries[1].actions={{id="cast",kind="secure-spell",spellID=31884,title="Cast"}}
assert(Fixture:Register({id="popup.fixture",apiVersion="1.0.0",version="1",title="Popup",catalog=entries,
    actions={open={title="Open",run=function() calls=calls+1;return {ok=true} end}}}))
local p=Lychee.UI.Palette;p:Create()
local M,home=Lychee.UI.Motion,p.homeView
p.frame.CreateAnimationGroup=dofile("tests/support/native_animation.lua")
home.frame.GetHeight=function() return p.frame:GetHeight()-88 end
home.frame.GetWidth=function() return 616 end
local setHeight=p.frame.SetHeight
p.frame.SetHeight=function(frame,height)
    setHeight(frame,height);home.frame.scripts.OnSizeChanged(home.frame)
end
local firstHeight,pointer
local show=p.frame.Show
p.frame.Show=function(frame) firstHeight=frame:GetHeight();show(frame) end
local failures={}
local function check(ok,message) if not ok then failures[#failures+1]=message end end
local function enter(owner)
    pointer=owner
    owner.IsMouseOver=function(self) return pointer==self end
    owner.IsVisible=function(self)
        while self and self~=UIParent do if not self:IsShown() then return false end;self=self:GetParent() end
        return true
    end
    owner.scripts.OnEnter(owner)
end
local function noTooltip()
    local tip=Lychee.UI.Components.tooltip
    return not tip or not tip:IsShown()
end
local function close()
    p:Hide("popup-test");M:StopPresence(true,true)
end
local function recent(count)
    LycheeCharacterDB.palette.recent={}
    for i=1,count do LycheeCharacterDB.palette.recent[i]={providerID="popup.fixture",entryID="item"..i} end
end
recent(5);p:Show()
check(firstHeight==390,"cold opening shows a partial home height")
check(not M.height,"cold opening resizes the list during entrance")
M:StopHeight(true);M:StopPresence(true,true)
check(home.scrollbar.maximum==0,"five fitting rows have a phantom scroll range")
home:SetScroll(20)
check(home.scroll==0,"five fitting rows can shift above their viewport")

-- Return from search, as in the recording, then cross two rows with a fixed
-- pointer while the entrance moves the window beneath it.
p.input:SetText("Popup");p:SetQueryMode("Popup")
local _,items=I.Search.Query:Query("Popup",{visible=true})
assert(#items==8);assert(p:ApplyResults(items,p.generation,p.session));M:StopHeight(true)
close();p:Show()
check(firstHeight==390 and not M.height,"reopening changes home geometry after showing")
local selection=home.selected
local secure
for _,button in ipairs(p.secureBroker.buttons) do
    if button.busy and button.token and button.token.row==home.tiles[1] then secure=button end
end
assert(secure,"fixture must exercise the secure row's real hover target")
enter(secure);enter(home.tiles[2])
check(home.selected==selection and noTooltip(),"entrance triggers selection and tooltips for passing rows")
M:StopPresence(true,true)
check(home.selected==2 and not noTooltip(),"settled pointer does not regain normal hover")
check(not p._deferredHover,"completed entrance retains a hover target")

close();p:Show();enter(home.tiles[3])
home:Invalidate();p:PrepareHome();M:StopPresence(true,true)
check(noTooltip(),"rebound row revives an old deferred hover")

close();p:Show();enter(home.tiles[3]);assert(p:ShowRowActions(home.tiles[3]))
M:StopPresence(true,true)
check(noTooltip(),"entrance completion paints a tooltip over an opened action menu")
Lychee.UI.Components:HideActionMenu()

close();p:Show();enter(home.tiles[3]);p:Hide("reverse");p:Show()
check(not p._deferredHover and noTooltip(),"quick reversal carries the previous hover into the new home")
M:StopPresence(true,true)

close();p:Show()
p.input:SetText("Popup");p:SetQueryMode("Popup")
assert(p:ApplyResults(items,p.generation,p.session))
local primary=p.list.rows[2].primaryTarget
enter(primary)
check(noTooltip(),"query typed during entrance bypasses the result-row hover gate")
M:StopPresence(true,true)
check(not noTooltip() and Lychee.UI.Components.tooltip._owner==primary,"search hover is not restored at the actual pointer")

close();p:Show();p.input:SetText("Popup");p:SetQueryMode("Popup")
assert(p:ApplyResults(items,p.generation,p.session));enter(p.list.rows[2].primaryTarget)
assert(p:ApplyResults({items[1],items[4]},p.generation,p.session));M:StopPresence(true,true)
check(noTooltip(),"reused primary target transfers deferred hover to a different search result")

close();p:Show();enter(home.tiles[3]);pointer=nil;home.tiles[3].scripts.OnLeave(home.tiles[3]);M:StopPresence(true,true)
check(noTooltip(),"pointer that left the list revives a deferred tooltip")
close();p:Show();enter(home.tiles[3]);close()
check(noTooltip() and not p._deferredHover,"closing retains a deferred hover")

-- A successful search action may change the saved home while it is hidden.
recent(1);p:Show();M:StopHeight(true);M:StopPresence(true,true)
p.input:SetText("Popup");p:SetQueryMode("Popup");close()
recent(5);p:Show()
check(firstHeight==390 and not M.height,"changed recents reopen at the previous home height")
local tile=home.tiles[3]
tile.scripts.OnMouseDown(tile,"LeftButton");tile.scripts.OnClick(tile,"LeftButton")
check(calls==1,"entrance blocks a deliberate physical click")
close()

-- Actual overflow still scrolls within the native viewport and remains bounded.
home.content:SetHeight(700);p.frame:SetHeight(518);home:SetScroll(1000)
check(home.scroll==270 and home.scrollbar.maximum==270,"real overflow uses inconsistent scroll bounds")
for _,message in ipairs(failures) do print("FAIL: "..message) end
assert(#failures==0,"popup geometry regressions: "..#failures)
print("Popup geometry PASS: cold/reopen layout, stationary hover, secure target, leave/close, clicks and scroll bounds")
