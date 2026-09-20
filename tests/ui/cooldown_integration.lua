local env=dofile("tests/support/palette.lua")
local I=LycheeInternal
C_Container={GetItemCooldown=function() return 1,30,1 end}
C_Timer={NewTimer=function(_,fn) return {Cancel=function() end} end}
I.Registry:SetReady(true)
local actions={{id="one",kind="secure-item",itemID=1,title="First"},{id="two",kind="secure-item",itemID=2,title="Second"}}
local handle=assert(Lychee:RegisterProvider({id="cooldown.fixture",title="Cooldown",version="1",apiVersion="1.0.0",
    entries={{id="test",title="Cooldown fixture",icon=1,actions=actions,primaryActionID="one"}}}))
local p=Lychee.UI.Palette:Create();p:Show()
p.input:SetText("Cooldown fixture");p:SetQueryMode("Cooldown fixture")
I.Search.Session:Input("Cooldown fixture");I.Search.Query:Flush()
local row=assert(p.list.rows[1]);assert(row.item and row.item.id=="test")
assert(I.ActionCooldown.count==1,"search row must bind its primary action")
-- Native IsVisible includes hidden ancestors; the old mock only checked the row.
local originalVisible=row.IsVisible
row.IsVisible=function() return p.list.frame:IsShown() and row:IsShown() end
p.list.frame:Hide();I.ActionCooldown:ReleaseAll()
assert(not I.ActionCooldown:BindRow(row),"hidden ancestor cannot acquire observers")
p.list.frame:Show();assert(row.scripts.OnShow)(row)
assert(I.ActionCooldown.count==1,"native parent show must acquire the first results")
row.IsVisible=originalVisible

assert(I.ResultActionExecutor:ShowActions(row))
assert(I.ActionCooldown.count==3,"menu observes each protected action independently")
Lychee.UI.Components:HideActionMenu();assert(I.ActionCooldown.count==1)
p:OpenSettings();assert(I.ActionCooldown.count==0 and not I.ActionCooldown.listening)
p:Hide("test",true);assert(not I.ActionCooldown.timer)
p:Show();p.input:SetText("Cooldown fixture");p:SetQueryMode("Cooldown fixture");I.Search.Session:Input("Cooldown fixture");I.Search.Query:Flush()
assert(I.ActionCooldown.count==1,"reopen must restore observers")
assert(handle:Unregister());assert(I.ActionCooldown.count==0,"source invalidation releases row observers")
p:Hide("test",true)
print("Cooldown UI integration PASS: search, per-action menu, settings, close/reopen and unregister")
