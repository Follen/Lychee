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
local social=p.social
assert(social.frame:IsShown() and social.frame:GetParent()==p.footer,'home owns the same footer icons before settings exist')
assert(p.footer:GetHeight()==56,'all pages use the approved settings footer spacing')
local homeFooter=p.footer:GetHeight()
assert(p:OpenSettings('providers'))
local listHeight=p.frame:GetHeight()
local settings=p.settingsView
assert(settings.tabs.about and not settings.about and metadataReads==0,'about must be lazy')
assert(p.social==social and not settings.social,'settings must not own a second social bar')
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
 if label:GetText()==I.Locale['在游戏里搜技能、物品和插件设置。'] then intro=true end
 if label:GetText():find('Follen',1,true) then author=true end
 if label.parent==settings.about then
  assert(label.point[4]==0,'about copy shares a single reading edge')
  assert(-label.point[5]+label:GetHeight()<=settings.about:GetHeight(),'all about text fits above the shared footer')
 end
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
click(2);p:CloseSettings(true)
assert(social.frame:IsShown() and not social.backdrop:IsShown() and not social.input:HasFocus())
assert(p.footer:GetHeight()==Lychee.UI.Theme.Metrics.footerHeight and p.content.point[5]==Lychee.UI.Theme.Metrics.footerHeight,'search restores its own footer and content bounds')
assert(p.footer:GetHeight()==homeFooter,'changing pages cannot change the footer baseline')
p.input:SetText('retained search');p:SetQueryMode('retained search')
local navigated=0
local activate,move=p.ActivateSelected,p.list.Move
p.ActivateSelected=function() navigated=navigated+1 end
p.list.Move=function() navigated=navigated+1 end
click(2)
assert(not p.input.frame:HasFocus(),'opening a link releases search focus')
p.input.frame.scripts.OnEnterPressed(p.input.frame)
p.input.frame.scripts.OnArrowPressed(p.input.frame,'DOWN')
assert(navigated==0,'a social popup owns keyboard input')
social:Close()
assert(p.input.frame:HasFocus() and p.input:GetText()=='retained search','close restores search focus without changing its text')
p.ActivateSelected,p.list.Move=activate,move
p:SetStatus('search',8)
local textRight=p.frame:GetWidth()-Lychee.UI.Theme.Metrics.footerInset-Lychee.UI.Theme.Metrics.footerSocialWidth-Lychee.UI.Theme.Metrics.footerSocialGap
assert(p.status:GetWidth()+28+16<=textRight-p.footerHint:GetWidth(),'status and keyboard hint occupy separate columns')
assert(not p.status.wordWrap and not p.footerHint.wordWrap and p.status.maxLines==1 and p.footerHint.maxLines==1)
p:SetStatusText(I.Locale['固定项数据异常，原始存档已保留'])
assert(p.status:GetWidth()==464 and p.footerHint:GetText()=='','long status uses the full text lane')
p:ResizeForMode('search',8)
assert(p.frame:GetHeight()-56-homeFooter-20==8*46+7*6,'eight complete rows fit above the larger footer')
assert(p:OpenView({create=function() return {} end},{},{}))
assert(social.frame:IsShown() and p.footer:GetHeight()==homeFooter,'provider details retain the shared footer')
click(2);assert(social.backdrop:IsShown());social:Close()
assert(not p.input.frame:HasFocus(),'closing a popup over details must not focus hidden search')
p:CloseView('social-detail-test')
assert(p:OpenSettings('about'));click(2)
_G.__combat=true;RunPaletteCombatSnippet(p.frame);p:Hide('combat');_G.__combat=false
assert(not p.frame:IsShown() and not social.backdrop:IsShown() and not social.input:HasFocus())
assert(social.input:GetText()=='' and not social.code.texture)
assert(p:Show());assert(p:OpenSettings('about'))
p.input.frame:SetText('pending')
p:SetQueryCallback(function() p.searchPending=true;p.list.items={} end)
p:CloseSettings()
assert(p.searchPending and p.footer:GetHeight()==Lychee.UI.Theme.Metrics.footerHeight,'pending empty results must also restore the search footer')
assert(social.frame:IsShown(),'pending search keeps social controls')
p:Hide('deferred-focus-test')
local deferred
C_Timer={After=function(_,callback) deferred=callback end}
assert(p:Show());click(2);assert(deferred);deferred()
assert(not p.input.frame:HasFocus() and social.input:HasFocus(),'deferred opening focus cannot steal the link field')
C_Timer=nil
social:Close();assert(p.input.frame:HasFocus())
p:Hide('test-end')
print('About/social PASS '..locale..': lazy metadata, localized footer, links/QR, Escape/backdrop/toggle, switching, reuse, combat cleanup')
