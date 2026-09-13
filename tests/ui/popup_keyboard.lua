-- Real keyboard handlers and Provider publication; substitute native geometry,
-- pointer delivery and clock. No claim about client rasterization.
dofile('tests/support/palette.lua')
local I=LycheeInternal;I.Registry:SetReady(true)
local calls={}
local entries={}
for i=1,24 do entries[i]={id='entry'..i,title='Audit entry '..i,actions={'open'}} end
assert(dofile('tests/support/provider_fixture.lua'):Register({id='audit.popup',apiVersion='1.0.0',version='1',title='Audit',catalog=entries,
 actions={open={title='Open',run=function(entry) calls[#calls+1]=entry.id;return {ok=true} end}}}))
local p=Lychee.UI.Palette;p:Create()
local M,home=Lychee.UI.Motion,p.homeView
p.frame.CreateAnimationGroup=dofile('tests/support/native_animation.lua')
home.frame.GetHeight=function() return p.frame:GetHeight()-112 end
home.frame.GetWidth=function() return 616 end
local setHeight=p.frame.SetHeight
p.frame.SetHeight=function(frame,height) setHeight(frame,height);home.frame.scripts.OnSizeChanged(home.frame) end
local now=0
GetTimePreciseSec=function() return now end
local function finish()
 assert(M.presence,'expected active entrance')
 now=now+1
 M.presenceDriver.scripts.OnUpdate(M.presenceDriver,1)
 assert(not M.presence,'native OnUpdate must finish entrance')
end
local function down() p.input.frame.scripts.OnArrowPressed(p.input.frame,'DOWN') end
local function recent()
 LycheeCharacterDB.palette.recent={}
 for i=1,5 do LycheeCharacterDB.palette.recent[i]={providerID='audit.popup',entryID='entry'..i} end
end
local case=assert(arg[1])
recent()
if case=='hover' then
 p:Show()
 local tile=home.tiles[1]
 tile.IsMouseOver=function() return true end
 tile.IsVisible=function() return p.visible and home.frame:IsShown() end
 tile.scripts.OnEnter(tile)
 assert(p._deferredHover==tile)
 down()
 local chosen=home.selected
 assert(chosen==2,'keyboard must choose second row during entrance')
 local later=home.tiles[3]
 later.IsMouseOver=function() return true end
 later.IsVisible=tile.IsVisible
 later.scripts.OnEnter(later)
 finish()
 print('hover: keyboard chose '..chosen..'; entrance completion selected '..home.selected)
 assert(home.selected==chosen,'deferred pointer overwrites explicit keyboard selection')
 later.scripts.OnEnter(later)
 assert(home.selected==3,'new mouse hover after entrance remains usable')
 p:Hide('keyboard-reopen');finish();p:Show()
 tile.scripts.OnEnter(tile);finish()
 assert(home.selected==1,'keyboard priority leaked into a new entrance')
elseif case=='scroll' then
 LycheeCharacterDB.pinned={}
 for i=6,19 do LycheeCharacterDB.pinned[#LycheeCharacterDB.pinned+1]={providerID='audit.popup',entryID='entry'..i} end
 p:Show();finish()
 assert(#home.sections==19,'14 pins plus five recents')
 home:Select(1);home:SetScroll(0)
 for i=2,#home.sections do down() end
 local tile=home.tiles[home.selected]
 local top=-tile.point[5]
 local bottom=top+tile:GetHeight()
 print('scroll: selected '..home.selected..'; row='..top..'..'..bottom..'; viewport='..home.scroll..'..'..(home.scroll+home.frame:GetHeight()))
 assert(top>=home.scroll and bottom<=home.scroll+home.frame:GetHeight(),'keyboard selected row is outside visible viewport')
 local scroll=home.scroll
 home:SetHover(home.tiles[1],true)
 assert(home.scroll==scroll,'mouse selection must not force scrolling')
 p.input.frame.scripts.OnArrowPressed(p.input.frame,'UP')
 assert(home.scroll==-home.tiles[1].point[5],'keyboard boundary brings the first row back into view')
 home:Select(3);home.sections[2].enabled=false
 p.input.frame.scripts.OnArrowPressed(p.input.frame,'UP')
 assert(home.selected==1,'keyboard still skips unavailable pins')
elseif case=='filter' then
 p:Show();finish()
 assert(p:ActivateHomeFilter({sourceID='audit.popup:records'}))
 assert(p.input:GetText()=='' and p.list.frame:IsShown() and not home.frame:IsShown())
 assert(#p.list.items>1,'filter must publish actual catalog results')
 local before=p.list.selected
 down()
 local after=p.list.selected
 print('filter: list selection '..tostring(before)..' -> '..tostring(p.list.selected)..'; hidden home selection='..home.selected)
 local expected=p.list.items[p.list.selected].id
 p.input.frame.scripts.OnEnterPressed(p.input.frame)
 print('filter: visible result='..expected..'; executed='..tostring(calls[#calls]))
 assert(after~=before and calls[#calls]==expected,'blank filtered search routes keyboard to hidden home')
 p:Hide('text-search-control');if M.presence then finish() end;p:Show();finish()
 p.input:SetText('Audit');assert(I.Search.Session:Input('Audit'));p:SetQueryMode('Audit')
 down();expected=p.list.items[p.list.selected].id
 p.input.frame.scripts.OnEnterPressed(p.input.frame)
 assert(calls[#calls]==expected and #calls==2,'text search keyboard activation remains usable')
else error('unknown case') end
