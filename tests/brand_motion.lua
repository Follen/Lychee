-- Geometry and bounded lifecycle regressions for the original logo.
dofile("tests/brand_geometry.lua")
GetTimePreciseSec=nil
-- Exercise production Palette/Components against the business harness.
dofile("tests/interaction_smoke.lua")
local p=LycheeInternal.Host.PaletteController
local motion=Lychee.UI.Motion
LycheeCharacterDB.palette.reduceMotion=false
p:Hide("brand-test");p:FinishHide("brand-test")
assert(p:Show());local job=assert(motion.brand)
assert(job.region==p.brandMark and job.parent==p.brandComponent.frame)
assert(p.settingsButton.allPoints==p.brandComponent.frame,"hit rect must follow fixed component, never animated texture")
local driver=motion.brandDriver
local function tick(t) if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver,t) end end
tick(.2);local elapsed=job.elapsed
p.settingsButton.scripts.OnEnter();assert(job.elapsed==elapsed,"hover during opening is coalesced")
tick(1.4);assert(not motion.brand)
p.settingsButton.scripts.OnEnter();assert(motion.brand and job.elapsed==0,"idle hover replays once")
tick(.3);p:Hide("brand-test")
assert(not motion.brand and not driver.scripts.OnUpdate,"close cancels before the window fade ends")
assert(p.brandMark:GetWidth()==42 and p.brandMark:GetHeight()==42 and p.brandMark.point[1]=="LEFT")
p.settingsButton.scripts.OnEnter();assert(not motion.brand,"closing header cannot restart logo")
assert(p:Show());assert(motion.brand,"rapid reopen reuses the driver")
p.brandComponent.frame.scripts.OnHide();assert(not motion.brand,"component hide cancels")
p.brandComponent:PlayMotion();motion:SetReduced(true);assert(not motion.brand)
motion:SetReduced(false);p:Hide("brand-test");p:FinishHide("brand-test")
assert(p.brandMark.texture=="Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga","original asset preserved")
print("Brand palette integration PASS: local owner, fixed hit rect, open, hover, close, reopen, component hide, reduced motion")
