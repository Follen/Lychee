local env=dofile('tests/support/palette.lua')
local locale=arg[1] or 'zhCN'
GetLocale=function() return locale end
local I=LycheeInternal
I.Locale.IsChinese=function() return locale=='zhCN' or locale=='zhTW' end
dofile('addon/Lychee/Locales/UI.enUS.lua')
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
assert(p:Show());assert(not p.settingsView)
assert(p:OpenSettings('providers'))
local settings=p.settingsView
assert(settings.tabs.about and not settings.about and metadataReads==0,'about must be lazy')
local social=settings.social
assert(social.frame:IsShown() and #social.buttons==3 and not social.popup)
settings.tabs.about.frame.scripts.OnClick(settings.tabs.about.frame)
assert(settings.tab=='about' and settings.about:IsShown() and not settings.scrollFrame:IsShown())
local found=false
for _,label in ipairs(strings) do if label:GetText():find('9.8.7',1,true) then found=true end end
assert(found and metadataReads==1,'version must come from installed metadata')
assert(p.status:GetText()==I.Locale['关于'])
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
assert(p:OpenSettings('about'));click(2)
_G.__combat=true;p:Hide('combat');_G.__combat=false
settings.frame.scripts.OnHide(settings.frame)
assert(not social.frame:IsShown() and not social.backdrop:IsShown() and not social.input:HasFocus())
assert(social.input:GetText()=='' and not social.code.texture)
print('About/social PASS '..locale..': lazy metadata, localized footer, links/QR, Escape/backdrop/toggle, switching, reuse, combat cleanup')
