local env=dofile('tests/support/palette.lua')
local I=LycheeInternal
local picked
local home=Lychee.UI.HomeView:Create(CreateFrame('Frame',nil,UIParent),{onHomeSelect=function(section) picked=section.id end})
home.frame:SetHeight(300);home.frame:Show()
local sections={}
for n=1,64 do sections[n]={id='pin'..n,groupID='pinned',groupTitle='Pins',title='Pin '..n,icon=n,enabled=true} end
for n=65,69 do sections[n]={id='recent'..n,groupID='recent',groupTitle='Recent',title='Recent '..n,icon=n,enabled=true} end
home:SetSections(sections,true)
assert(#home.tiles<=35 and home:GetContentHeight()>300)
local first=home.tiles[1]
I.InteractionBinding:Press(first,first,'LeftButton')
home:SetScroll(100000)
assert(home:GetTile(69) and not I.InteractionBinding:Consume(first,first,'LeftButton'))
home:Select(1);home:ActivateSelected();assert(picked=='pin1' and home:GetTile(1),'offscreen activation must bind its row')
home:SetScroll(100000);home:Select(69);home:ActivateSelected();assert(picked=='recent69')
home:Select(1);home:Move(1);assert(home:GetTile(2),'keyboard must bring selected item into viewport')
local frames=env.state.createdFrames
for n=1,20 do home:SetScroll(0);home:SetScroll(100000) end
assert(env.state.createdFrames==frames,'scrolling must reuse warmed pool')
local pool=#home.tiles
home:FreezePresentation()
local icon=home.tiles[1]._icon
assert(icon,'frozen presentation keeps texture')
home:ReleaseBindings()
for _,tile in ipairs(home.tiles) do assert(not tile.item and not tile.section and not tile._icon and tile.icon.texture==nil and tile.title:GetText()=='') end
home:SetSections(sections,true);assert(#home.tiles==pool and home:GetTile(69),'reopen restores visible bindings')
print(string.format('Home virtualization PASS records=69 pool=%d scroll20_new_frames=0 close_textures=0 keyboard/rebind/freeze/reopen',pool))
