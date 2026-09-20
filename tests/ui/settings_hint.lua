local fixture=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=LycheeInternal
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
