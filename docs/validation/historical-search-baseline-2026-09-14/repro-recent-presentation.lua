local env=assert(loadfile('tests/support/palette.lua'))('zhCN')
env.state:InstallTimers()
local I=LycheeInternal;I.Registry:SetReady(true);I.OnLogin()
local F=dofile('tests/support/provider_fixture.lua')
local slowReply
local handle=assert(F:Register({id='repro.recent',apiVersion='1.0.0',version='1',title='Recent fixture',
 catalog={{id='spell',title='Recent spell',icon=135846,actions={'open'}}},
 prepare=function(context,reply)
  if context.publicscope=='restore' then slowReply=reply;return function() end end
  return {status='ready'}
 end,
 actions={open={title='Open',run=function() return {ok=true} end}}}))
local p=Lychee.UI.Palette;p:Show();p.homeView.frame.scripts.OnShow(p.homeView.frame);env.state:FlushTimers()
local _,items=I.Search.Query:Query('Recent spell',{visible=true})
local item
for _,x in ipairs(items) do if x.ref.providerID=='repro.recent' then item=x;break end end
assert(item,'fixture did not produce a real result')
assert(I.UserPreferences:TouchRecent(item))
local ref=I.UserPreferences:GetRecent()[1]
local hasDisplay=ref.title==item.text and ref.icon==item.icon
print('recentSavedDisplay',hasDisplay,'title',ref.title,'icon',ref.icon)
p:Hide('repro');p:FinishHide('repro')
p:Show();p.homeView.frame.scripts.OnShow(p.homeView.frame);env.state:FlushTimers()
assert(slowReply and I.Search.Session:GetHomeStatus(ref)=='pending','fixture did not reach pending restoration')
local tile=p.homeView.tiles[1]
local title=tile.section.title;local meta=tile.section.meta
local tooltip;local original=Lychee.UI.ResultList.ShowTextTooltip
Lychee.UI.ResultList.ShowTextTooltip=function(_,value) tooltip=value end
p.homeView:ShowTooltip(tile)
Lychee.UI.ResultList.ShowTextTooltip=original
print('pendingTitle',title,'pendingMeta',meta,'tooltip',tooltip)
local duplicated=title==meta and tooltip==title..'\n'..meta
print('duplicateStatus',duplicated)
p:Hide('repro-end');p:FinishHide('repro-end')
assert(hasDisplay and not duplicated,'REPRODUCED: recent loses display fields and duplicates pending title/meta in tooltip')
