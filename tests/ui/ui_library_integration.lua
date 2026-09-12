-- Fresh production host fixture; exercise retained UI forms independently.
dofile("tests/support/palette.lua")
assert(Lychee.UI.Palette:Create())
local UI,I=Lychee.UI,LycheeInternal
local source=assert(dofile("tests/support/provider_fixture.lua"):Register({id="ui.library.integration",apiVersion="1.0.0",version="1.0.0",title="UI integration",
    catalog={{id="one",title="UI library first"},{id="two",title="UI library second"}}}))
local parent=CreateFrame("Frame",nil,UIParent)
local controller={visible=true,settingsOpen=true,ResizeForMode=function() end,SetStatusText=function() end}
local page=UI.AliasSettings:Create(parent,controller,function() end)
local first={providerID="ui.library.integration",entryID="one"}
local second={providerID="ui.library.integration",entryID="two"}
page:Show(first,"First")
assert(page.form.active and page.form:Get("input")==page.input)
page.input:SetText("First alias")
page.input.scripts.OnTextChanged(page.input,true)
page.save.frame.scripts.OnMouseDown(page.save.frame)
page.save.frame.scripts.OnClick(page.save.frame)
assert(I.Search.Personalization:Find(first).alias=="First alias","declarative save commits original business action")
page:Edit(first,"First")
page.save.frame.scripts.OnMouseDown(page.save.frame)
page:Edit(second,"Second")
page.input:SetText("Wrong identity")
page.save.frame.scripts.OnClick(page.save.frame)
assert(I.Search.Personalization:Find(second)==nil,"switching identity invalidates old press without closing")
page:Edit(first,"First")
page.save.frame.scripts.OnMouseDown(page.save.frame)
page.frame:Hide();page.frame.scripts.OnHide(page.frame)
assert(not page.form.active and not page.input.focused and page.input:GetText()=="","release clears field and focus")
page:Show(second,"Second")
page.input:SetText("Must not save")
page.save.frame.scripts.OnClick(page.save.frame)
assert(I.Search.Personalization:Find(second)==nil,"press before release cannot act on reopened form")
page.input:SetText("Second alias")
page.save.frame.scripts.OnMouseDown(page.save.frame)
page.save.frame.scripts.OnClick(page.save.frame)
assert(I.Search.Personalization:Find(second).alias=="Second alias","fresh click works after remount")
local create=CreateFrame
local added=0
CreateFrame=function(...) added=added+1;return create(...) end
for _=1,100 do
    page.frame:Hide();page.frame.scripts.OnHide(page.frame)
    page:Show(first,"First")
    page.input:SetText("Draft")
    page.input.scripts.OnTextChanged(page.input,true)
    page.cancel.frame.scripts.OnMouseDown(page.cancel.frame)
    page.cancel.frame.scripts.OnClick(page.cancel.frame)
    assert(not page.editing and not page.form.active,"remounted callbacks work and list view releases editor")
end
CreateFrame=create
assert(added==0,"warm form cycles reuse all native objects")
page.frame:Hide();page.frame.scripts.OnHide(page.frame)
assert(next(page.form.props)==nil and next(page.form.state)==nil and next(page.form.tasks)==nil)
source:Unregister()
print("UI library integration PASS: production form save, release, remount, stale press, 100 warm cycles / 0 new frames")

local example=assert(dofile("lychee-sdk/examples/ComponentPanel/ComponentPanel.lua"))
local factory=I.Providers.entries["example.component-panel"].definition.views.panel
local host=UI.ViewHost:Create(parent)
assert(host:Mount(factory,{contentFrame=host.frame},{}))
local instance=host.panel.instance.view
instance:Get("toggle").scripts.OnClick(instance:Get("toggle"))
assert(instance.state.enabled and instance:Get("status"):GetText()=="状态：已开启")
instance:Get("name"):SetText("Edited")
host:Unmount("test")
assert(not instance.active and next(instance.props)==nil and next(instance.state)==nil)
assert(host:Mount(factory,{contentFrame=host.frame},{}))
assert(host.panel.instance.view==instance and instance:Get("name"):GetText()=="可编辑文字")
host:Unmount("done");example:Unregister()
print("SDK component example PASS: real registration, host mount, state, release, cached remount")

do
    local view=UI.Palette.homeView
    local recent={id="runtime-label",title="受缚的队长",meta="荔枝大米助手 · 小怪",groupID="recent",groupTitle="最近使用"}
    local label=view.tiles[1].category
    label.GetStringWidth=function(self) return math.min(self:GetWidth(),#self:GetText()*6) end
    label.GetUnboundedStringWidth=function(self) return #self:GetText()*6 end
    label:SetWidth(80)
    view:SetSections({recent},true)
    local tile=view.tiles[1]
    assert(tile.category.wordWrap==false and tile.category.nonSpaceWrap==false and tile.category.maxLines==1,
        "recent source label must remain one line, including CJK suffix")
    assert(tile.category:GetWidth()==160,"long recent source uses bounded measured width")
    assert(tile.title.point[2]==tile.category and tile.title.point[3]=="LEFT","title reserves measured source width")
    recent.meta="技能";view:SetSections({recent},true)
    assert(tile.category:GetWidth()==80,"rebound short source releases spare width")
    recent.groupID="pinned";view:SetSections({recent},true)
    assert(not tile.category:IsShown(),"pinned grid hides source label")
    recent.groupID="recent";view:SetSections({recent},true)
    assert(tile.category:IsShown() and tile.title.point[2]==tile.category,"reused recent row restores category anchor")
end
print("Recent source label layout PASS")
