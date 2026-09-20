local fixture=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=_G.LycheeInternal
I.Registry:SetReady(true)
local p=Lychee.UI.Palette:Create()
p:Show();p:OpenSettings("about")
local view=p.settingsView
assert(not view.credits,"credits must be lazy")
if not I.Locale:IsChinese() then
    assert(not view.tabs.credits)
    assert(view:SetTab("credits")==false and view.tab=="about")
    print("Credits PASS: non-Chinese tab absent")
    return
end
assert(view.tabs.credits.frame.point[2]==view.tabs.general.frame)
assert(view.tabs.about.frame.point[2]==view.tabs.credits.frame)
view:SetTab("credits")
local page=view.credits
assert(page and #page.buttons==2 and not view.about:IsShown())
assert(not page.dedication,"dedication belongs in footer only")
assert(p.status:GetText()=="谨献给挚爱：荔枝小月亮")
local urls={"https://v.douyin.com/BHwvNPtS3AE/","https://space.bilibili.com/455259"}
local function click(index)
    local b=page.buttons[index].frame
    b.scripts.OnClick(b)
    assert(p.social.input:GetText()==urls[index])
    assert(p.social.input.focused and p.social.input.highlighted)
    assert(p.social.popup.point[2]==b)
end
click(1)
local popup=p.social.popup
p.social.input.scripts.OnEscapePressed()
assert(not p.social.backdrop:IsShown() and p.social.input:GetText()=="")
click(2);assert(p.social.popup==popup)
view:SetTab("about");assert(not p.social.backdrop:IsShown() and not page:IsShown())
view:SetTab("credits");click(1)
local count=fixture.state.createdFrames
for n=1,20 do
    view:SetTab("about");view:SetTab("credits");click(n%2+1)
end
assert(fixture.state.createdFrames==count,"warm page/popup must reuse frames")
p.social:Close(false)
_G.__combat=true
local b=page.buttons[1].frame;b.scripts.OnClick(b)
assert(not p.social.backdrop:IsShown())
_G.__combat=false
click(2);p:Hide()
assert(not p.social.backdrop:IsShown())
p:Show();p:OpenSettings("credits");click(1);p:Hide()
print("Credits PASS: tab order, lazy creation, two URLs, focus, Esc, switching, combat, reopen, stable frame count")
