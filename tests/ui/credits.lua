local fixture=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=_G.LycheeInternal
I.Registry:SetReady(true)
local p=Lychee.UI.Palette:Create()
p:Show();p:OpenSettings("about")
assert(#p.social.buttons==2,"footer keeps only repository and contact links")
assert(p.social.frame:GetWidth()==64,"two footer buttons keep their existing right alignment")
assert(p.social.buttons[1].frame.point[4]==0 and p.social.buttons[2].frame.point[4]==36)
local github=p.social.buttons[1].frame
github.scripts.OnClick(github)
assert(p.social.title:GetText()=="GitHub" and p.social.input:GetText()=="https://github.com/Follen/Lychee")
assert(p.social.input.focused and p.social.input.highlighted)
local socialPopup=p.social.popup
p.social.input.scripts.OnEscapePressed()
local contact=p.social.buttons[2].frame
contact.scripts.OnClick(contact)
assert(p.social.popup==socialPopup,"footer modes reuse one popup")
if I.Locale:IsChinese() then
    assert(p.social.title:GetText()=="作者微信" and p.social.code.texture=="Interface\\AddOns\\Lychee\\Media\\About\\wechat-contact.tga")
    assert(p.social.code:IsShown() and not p.social.input:IsShown())
else
    assert(p.social.title:GetText()=="X · @follenfang" and p.social.input:GetText()=="https://x.com/follenfang")
    assert(p.social.input:IsShown() and not p.social.code:IsShown())
end
p.social:Close(false)
assert(not p.social.backdrop:IsShown() and p.social.input:GetText()=="" and p.social.code.texture==nil)
local footerFrameCount=fixture.state.createdFrames
for n=1,20 do
    local button=p.social.buttons[n%2+1].frame
    button.scripts.OnClick(button);p.social:Close(false)
end
assert(fixture.state.createdFrames==footerFrameCount,"warm footer popup must reuse frames")
_G.__combat=true;github.scripts.OnClick(github)
assert(not p.social.backdrop:IsShown(),"footer cannot open during combat")
_G.__combat=false;contact.scripts.OnClick(contact);p:Hide()
assert(not p.social.backdrop:IsShown(),"closing the launcher closes its social popup")
p:Show();p:OpenSettings("about")
print("Social links PASS: two aligned buttons, repository/contact modes, focus, Esc, cleanup, combat, reopen and stable frame count")
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
