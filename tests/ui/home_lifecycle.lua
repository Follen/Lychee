local env=dofile("tests/support/palette.lua")
local Fixture=dofile("tests/support/provider_fixture.lua")
local I=LycheeInternal
I.Registry:SetReady(true)
local catalog={}
for i=1,12 do catalog[i]={id="home"..i,title="Home "..i,actions={"open"}} end
local calls=0
local provider=assert(Fixture:Register({id="home.lifecycle",apiVersion="1.0.0",version="1",title="Home",
    catalog=catalog,actions={open={title="Open",run=function() calls=calls+1;return {ok=true} end}}}))
local p=Lychee.UI.Palette
p:Show()
local _,items=I.Search.Query:Query("Home",{visible=true})
assert(#items==12)
for _,item in ipairs(items) do assert(p:SetPinned(item,true)) end
assert(p:TouchRecent(items[1]))
local home=p.homeView
assert(home:Prepare(p.session,p.generation,true))
assert(home:GetContentHeight()>0)
local target=home.tiles[1]
target.scripts.OnMouseDown(target,"LeftButton")
home:ReleaseBindings()
home:Invalidate()
assert(home:Prepare(p.session,p.generation,true))
target.scripts.OnClick(target,"LeftButton")
assert(calls==0,"release and restore cannot transfer an unfinished press")
target.scripts.OnMouseDown(target,"LeftButton");target.scripts.OnClick(target,"LeftButton")
assert(calls==1,"fresh physical click remains usable")
local frames=env.state.createdFrames
for _=1,20 do
    home:ReleaseBindings()
    assert(home:Prepare(p.session,p.generation,true))
end
assert(env.state.createdFrames==frames,"warm recovery keeps the native pool")

-- A temporarily unavailable Provider restores disabled pins once, without
-- re-resolving the entire list on every subsequent Prepare.
assert(provider:SetAvailability(false))
local original=I.UserPreferences.Resolve
local resolves=0
I.UserPreferences.Resolve=function(self,pin) resolves=resolves+1;return original(self,pin) end
home:Invalidate()
assert(home:Prepare(p.session,p.generation,true))
assert(resolves==12)
assert(home:Prepare(p.session,p.generation,true) and resolves==12)
I.UserPreferences.Resolve=original
assert(not home.tiles[1].item and home.tiles[1]:IsShown(),"unavailable pin remains a placeholder")
assert(provider:SetAvailability(true))
home:Invalidate();assert(home:Prepare(p.session,p.generation,true))
assert(home.tiles[1].item,"restored Provider makes the pin usable")
_G.__combat=true
home:Invalidate();assert(not home:Prepare(p.session,p.generation,true))
assert(env.state.createdFrames==frames,"combat cannot expand the pool")
_G.__combat=false
p:Hide("home-test");p:FinishHide("home-test")
for _,tile in ipairs(home.tiles) do assert(not tile.item and not tile.section and not tile._bindingIdentity) end
p:Show()
assert(home.tiles[1].item and env.state.createdFrames==frames,"reopen restores content in the same pool")
p:Hide("home-test-end")
print("Home lifecycle PASS: saved recovery, press identity, bounded pool, unavailable pins, combat and reopen")
