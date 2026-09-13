local locale=arg[1] or 'zhCN'
local env=assert(loadfile('tests/support/palette.lua'))(locale)
local I=LycheeInternal
dofile('addon/Lychee/Locales/UI.enUS.lua')
assert(I.Locale.code==locale and I.Locale.name:find(I.Locale:IsChinese() and '荔枝' or 'Lychee',1,true),'brand and language must be initialized for the actual client locale')
I.Registry:SetReady(true)
local metadataReads=0
C_AddOns={GetAddOnMetadata=function(name,key)
 assert(name=='Lychee' and key=='Version');metadataReads=metadataReads+1;return '9.8.7'
end}
local create=CreateFrame
local strings={}
CreateFrame=function(...)
 local frame=create(...)
 local font=frame.CreateFontString
 frame.CreateFontString=function(self,...)
  local result=font(self,...);strings[#strings+1]=result;return result
 end
 frame.HighlightText=function(self) self.selectedText=self:GetText() end
 return frame
end
local p=Lychee.UI.Palette
Lychee.UI.Motion:SetReduced(true)
assert(p:Show());assert(not p.settingsView)
assert(p:OpenSettings('providers'))
local listHeight=p.frame:GetHeight()
local settings=p.settingsView
assert(settings.tabs.about and not settings.about and metadataReads==0,'about must be lazy')
local social=settings.social
assert(social.frame:IsShown() and #social.buttons==3 and not social.popup)
assert(p.footer:GetHeight()>=social.frame:GetHeight()+24,'footer must leave space above and below the icon hit areas')
settings.tabs.about.frame.scripts.OnClick(settings.tabs.about.frame)
assert(settings.tab=='about' and settings.about:IsShown() and not settings.scrollFrame:IsShown())
assert(p.frame:GetHeight()<listHeight-80,'about must not retain the tall provider list shell')
local found=false
local dedication,intro,author=false,false,false
for _,label in ipairs(strings) do
 if label:GetText():find('9.8.7',1,true) then found=true end
 if label:GetText()=='谨献给爱人：荔枝小月亮' then dedication=true end
 if label:GetText()==I.Locale['少一点翻找，多一点冒险。'] then intro=true end
 if label:GetText()=='Follen' then author=true end
end
assert(found and metadataReads==1,'version must come from installed metadata')
assert(intro and author and dedication==I.Locale:IsChinese(),'brand introduction, author and Chinese-only dedication')
assert(p.status:GetText()==I.Locale['感谢使用荔枝'])
local function click(index)
 local b=social.buttons[index].frame;b.scripts.OnClick(b)
end
local chinese=I.Locale:IsChinese()
click(1)
assert(social.backdrop:IsShown())
if chinese then
 assert(social.code.texture:find('wechat%-support.tga') and not social.input:IsShown())
else
 assert(social.input:GetText()=='https://www.paypal.me/follenfang' and social.input:HasFocus())
 assert(social.input.selectedText==social.input:GetText() and not social.code:IsShown())
end
local popup=social.popup
assert(popup:GetWidth()<p.frame:GetWidth()*0.5,'social popup must stay secondary to the main panel')
assert(popup.point[1]=='BOTTOMRIGHT' and popup.point[2]==social.frame and popup.point[3]=='TOPRIGHT','popup opens inward with the footer right edge')
click(2)
assert(social.popup==popup and social.input:GetText()=='https://github.com/Follen/Lychee')
assert(social.input.selectedText==social.input:GetText() and social.input:HasFocus())
social.input.scripts.OnEscapePressed(social.input)
assert(not social.backdrop:IsShown() and not social.input:HasFocus() and p.visible)
click(3)
if chinese then assert(social.code.texture:find('wechat%-contact.tga'))
else assert(social.input:GetText()=='https://x.com/follenfang') end
p.escapeFrame:Hide();p.escapeFrame.scripts.OnHide(p.escapeFrame)
assert(not social.backdrop:IsShown() and p.visible and p.escapeFrame:IsShown(),'Escape closes popup before palette')
click(2);social.backdrop.scripts.OnClick(social.backdrop)
assert(not social.backdrop:IsShown() and not social.input:HasFocus())
click(1);click(1);assert(not social.backdrop:IsShown(),'same icon toggles closed')
click(2);settings:SetTab('general')
assert(not social.backdrop:IsShown() and not social.input:HasFocus() and not settings.about:IsShown())
settings:SetTab('about')
local frames=env.state.createdFrames
for _=1,30 do
 click(1);click(2);click(3);social:Close();settings:SetTab('providers');settings:SetTab('about')
end
assert(env.state.createdFrames==frames and metadataReads==1,'warm visits reuse objects and metadata')
click(2);p:CloseSettings(true);settings.frame.scripts.OnHide(settings.frame)
assert(not social.frame:IsShown() and not social.backdrop:IsShown() and not social.input:HasFocus())
assert(p.footer:GetHeight()==Lychee.UI.Theme.Metrics.footerHeight and p.content.point[5]==Lychee.UI.Theme.Metrics.footerHeight,'search restores its own footer and content bounds')
assert(p:OpenSettings('about'));click(2)
_G.__combat=true;p:Hide('combat');_G.__combat=false
settings.frame.scripts.OnHide(settings.frame)
assert(not social.frame:IsShown() and not social.backdrop:IsShown() and not social.input:HasFocus())
assert(social.input:GetText()=='' and not social.code.texture)
assert(p:Show());assert(p:OpenSettings('about'))
p.input.frame:SetText('pending')
p:SetQueryCallback(function() p.searchPending=true;p.list.items={} end)
p:CloseSettings()
assert(p.searchPending and p.footer:GetHeight()==Lychee.UI.Theme.Metrics.footerHeight,'pending empty results must also restore the search footer')
print('About/social PASS '..locale..': lazy metadata, localized footer, links/QR, Escape/backdrop/toggle, switching, reuse, combat cleanup')
