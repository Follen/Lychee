local fixture=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=LycheeInternal
local theme=Lychee.UI.Theme
local setFont=theme.SetFont
function theme:SetFont(region,role)
    if region then region.requestedFontRole=role end
    return setFont(self,region,role)
end
LycheeDB=nil
assert(not I.UserPreferences:NeedsSettingsHint(),"wait for saved variables")
assert(not I.UserPreferences:DismissSettingsHint() and LycheeDB==nil)
I.Registry:SetReady(true)
local p=Lychee.UI.Palette:Create()
p:Show()
local hint=assert(p.settingsHint)
assert(hint.frame:IsShown())
assert(hint.label:GetText()==I.Locale["点击荔枝图标，打开设置"])
assert(LycheeDB==nil,"showing does not acknowledge")
p:Hide();p:Show();assert(p.settingsHint==hint and hint.frame:IsShown())
local frameCount=fixture.state.createdFrames
hint.dismiss.frame.scripts.OnClick(hint.dismiss.frame)
assert(LycheeDB.settingsHintDismissed and not hint.frame:IsShown())
for n=1,20 do p:Hide();p:Show();assert(not hint.frame:IsShown()) end
assert(fixture.state.createdFrames==frameCount)
LycheeCharacterDB={};assert(not I.UserPreferences:NeedsSettingsHint(),"account acknowledgement survives character change")
dofile("addon/Lychee/Core/UserPreferences.lua")
assert(not I.UserPreferences:NeedsSettingsHint(),"acknowledgement survives module reload")
LycheeDB.settingsHintDismissed=nil
p:Hide();p:Show();assert(hint.frame:IsShown())
p:OpenSettings();assert(LycheeDB.settingsHintDismissed and not hint.frame:IsShown())
p:Hide();_G.__combat=true
assert(p:Show()==false)
_G.__combat=false
LycheeDB="invalid"
assert(not I.UserPreferences:NeedsSettingsHint() and not I.UserPreferences:DismissSettingsHint())
assert(LycheeDB=="invalid","do not replace malformed saved root")
print("Settings hint PASS: first use, locale, deferred SV, dismissal, settings click, reload, character sharing, stable frames, combat, invalid storage")

-- A shortcut conflict remains actionable even after the ordinary onboarding
-- was acknowledged. Only a successful manual change ends the conflict hint.
local bindings={['ALT-SPACE']='CLICK OtherLauncher:LeftButton',SPACE='JUMP'}
local overrides,saveFails={},false
function GetBindingKey(action)
    for _,key in ipairs({'ALT-SPACE','F6','CTRL-L'}) do if bindings[key]==action then return key end end
end
function GetBindingAction(key,override) return override and overrides[key] or bindings[key] or '' end
function SetBinding(key,action) bindings[key]=action;return true end
function GetCurrentBindingSet() return 2 end
function SaveBindings() return not saveFails end
LycheeDB={};LycheeCharacterDB={}
p:Hide();p:Show();assert(hint.frame:GetHeight()==64)
bindings['ALT-SPACE']='TOGGLELYCHEE';p:UpdateSettingsHint()
assert(hint.frame:IsShown() and hint.frame:GetHeight()==42 and hint.dismiss.frame.point[1]=='RIGHT',"resolved conflict restores the ordinary hint layout")
bindings['ALT-SPACE']='CLICK OtherLauncher:LeftButton'
LycheeDB.settingsHintDismissed=true
p:Hide();p:Show()
assert(hint.frame:IsShown(),"a conflict must show even if account onboarding was dismissed")
assert(hint.label:GetText()==I.Locale['alt+space已被其他插件占用'])
assert(hint.dismiss.label:GetText()==I.Locale['点击换绑'])
assert(hint.frame:GetHeight()==64 and hint.dismiss.frame.point[1]=='TOPLEFT',"conflict CTA is below its message")
local color=Lychee.UI.Theme.Colors.accentHover
assert(hint.dismiss.label.textColor[1]==color[1] and hint.dismiss.label.textColor[2]==color[2],"CTA uses Lychee red")
assert(hint.dismiss.label.requestedFontRole=='meta' and Lychee.UI.Theme.FontSizes.meta==11,"CTA uses the existing small text size")
local beforeFrames=fixture.state.createdFrames
p:Hide();p:Show();assert(p.settingsHint==hint and fixture.state.createdFrames==beforeFrames)
hint.dismiss.frame.scripts.OnClick(hint.dismiss.frame)
assert(p.settingsOpen and p.settingsView.tab=='general' and not hint.frame:IsShown())
local capture=p.settingsView.bindingCapture.frame
assert(capture:GetScript('OnKeyDown') and capture:IsKeyboardEnabled(),"CTA starts shortcut capture")
capture:GetScript('OnKeyDown')(capture,'ESCAPE')
assert(not LycheeCharacterDB.bindingHintDismissed,"cancelling capture must not acknowledge the conflict")
p:CloseSettings();p:UpdateSettingsHint();assert(hint.frame:IsShown())
hint.dismiss.frame.scripts.OnClick(hint.dismiss.frame)
saveFails=true;capture:GetScript('OnKeyDown')(capture,'F6');saveFails=false
assert(not LycheeCharacterDB.bindingHintDismissed and not bindings.F6,"save failure keeps the hint and rolls back the new key")
p:CloseSettings();p:UpdateSettingsHint();assert(hint.frame:IsShown())
bindings['ALT-SPACE']='TOGGLELYCHEE';p:UpdateSettingsHint();assert(not hint.frame:IsShown())
overrides['ALT-SPACE']='CLICK OtherLauncher:LeftButton';p:UpdateSettingsHint();assert(hint.frame:IsShown(),"an effective override conflict is also detected")
hint.dismiss.frame.scripts.OnClick(hint.dismiss.frame)
capture:GetScript('OnKeyDown')(capture,'F6')
assert(bindings.F6=='TOGGLELYCHEE' and LycheeCharacterDB.bindingHintDismissed and LycheeDB.settingsHintDismissed)
p:CloseSettings();p:Hide();p:Show();assert(not hint.frame:IsShown(),"manual success never returns to the original onboarding")
bindings.F6=nil;bindings['ALT-SPACE']='CLICK OtherLauncher:LeftButton'
LycheeCharacterDB={bindingHintDismissed=LycheeCharacterDB.bindingHintDismissed}
dofile('addon/Lychee/Core/UserPreferences.lua')
for n=1,20 do p:Hide();p:Show();assert(not hint.frame:IsShown(),"stored completion survives reopening and root restoration") end
LycheeCharacterDB={};p:Hide();p:Show();assert(hint.frame:IsShown(),"another character has its own conflict state")
bindings['CTRL-L']='TOGGLELYCHEE';p:UpdateSettingsHint()
assert(not hint.frame:IsShown() and LycheeCharacterDB.bindingHintDismissed,"an existing custom game binding is recognized as completed")
print('Shortcut conflict hint PASS: locale, red lower CTA, account/character state, overrides, capture, cancel/failure/retry, manual completion and storage restoration')
