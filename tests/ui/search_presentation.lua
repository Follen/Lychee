local env=dofile("tests/support/palette.lua")
local I=LycheeInternal
I.Registry:SetReady(true)
local entries={}
for n=1,6 do entries[n]={id=tostring(n),title="resize fixture "..n,actions={"open"}} end
assert(Lychee:RegisterProvider({id="fixture.resize",apiVersion="1.0.0",version="1",title="Resize",entries=entries,actions={open={title="Open",run=function() return {ok=true} end}}}))
local _,items=I.Search.Query:Query("resize",{visible=true})
assert(#items==6,"fixture result count: "..#items)
local p=Lychee.UI.Palette:Create()
p.visible=true;p.frame:Show();p.input.frame:SetText("resize")
local motion=Lychee.UI.Motion
local function settle()
    if motion.height then motion.driver.scripts.OnUpdate(motion.driver,1) end
    assert(not motion.height,"resize completes without a remaining task")
end
local m=Lychee.UI.Theme.Metrics
local function expected(n)
    local rows=math.ceil(n/p.list.gridColumns)
    return math.max(m.paletteMinHeight,math.min(m.paletteMaxHeight,m.headerHeight+m.footerHeight+m.resultPadding+rows*m.rowHeight+(rows-1)*m.rowGap))
end
for n=6,1,-1 do
    local subset={};for k=1,n do subset[k]=items[k] end
    p:ApplySearchState(1,7-n,false,subset,false);settle()
    assert(p.frame:GetHeight()==expected(n),"final height for "..n.." results: "..p.frame:GetHeight().." expected "..expected(n))
end
p:ApplySearchState(1,8,false,items,false);settle()
local height=p.frame:GetHeight()
p:ApplySearchState(1,9,true,nil,false)
assert(p.waitingPresentation and p._searchActionsSuspended,"old result actions revoked during wait")
assert(p.frame:GetHeight()==height and p.list.frame:IsShown(),"waiting preserves previous visual height and list")
p:ApplySearchState(1,9,true,{items[1]},false)
assert(not p.waitingPresentation and p.list.frame:IsShown() and #p.list.items==1,"ready partial results are immediately shown")
p:ApplySearchState(1,9,false,{items[1]},false);settle()
assert(p.frame:GetHeight()==expected(1),"terminal partial result shrinks fully")
print("Palette search presentation PASS: 6-to-1 final geometry, frozen waiting, immediate partial results, final shrink")
