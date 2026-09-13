-- Actual Input -> Palette -> SearchSession -> Provider path; native IME state is the boundary substitute.
local env=dofile('tests/support/palette.lua')
local Fixture=dofile('tests/support/provider_fixture.lua')
local I=LycheeInternal
I.Registry:SetReady(true)
local p=Lychee.UI.Palette
p:Show()
local motion=Lychee.UI.Motion
motion:SetReduced(true)
p:SetQueryCallback(function(text) return I.Search.Session:Input(text) end)
local queries,replies={},{}
local provider=assert(Fixture:Register({id='composition.test',apiVersion='1.0.0',version='1',title='Composition',
 query=function(request,reply)
  queries[#queries+1]=request.normalized
  if request.normalized=='pending' then replies.pending=reply;return end
  local items={}
  for i=1,(request.normalized=='毒牙' and 2 or 8) do items[i]={id='row'..i,title='Row '..i} end
  assert(reply(items))
 end}))
local edit=p.input.frame
local composing=false
edit.IsInIMECompositionMode=function() return composing end
local function input(value,ime)
 composing=ime;edit:SetText(value);edit.scripts.OnTextChanged(edit,true)
 if I.Search.Query.pending then I.Search.Query:Flush() end
end
input('ready',false)
local height,count,items=p.frame:GetHeight(),#queries,p.list.items
local generation=I.Search.Session.generation
input('d',true);input('du',true);input("du'ya",true)
assert(#queries==count,'IME preedit must not query providers')
assert(p.frame:GetHeight()==height and p.list.items==items,'IME preedit preserves displayed list and height')
assert(I.Search.Session.generation<=generation+1,'one composition invalidates at most once')
local submits,moves,closes=0,0,0
p.input:SetSubmitCallback(function() submits=submits+1 end)
p.input:SetMoveCallback(function() moves=moves+1 end)
local hide=p.Hide;p.Hide=function() closes=closes+1 end
edit.scripts.OnEnterPressed(edit);edit.scripts.OnArrowPressed(edit,'DOWN');edit.scripts.OnEscapePressed(edit)
assert(submits==0 and moves==0 and closes==0,'candidate keys belong to the IME')
p.Hide=hide
input('毒牙',false)
assert(#queries==count+1 and queries[#queries]=='毒牙','committed Chinese text searches once')
assert(#p.list.items==2 and p.frame:GetHeight()<height,'committed results resize normally')
edit.scripts.OnEnterPressed(edit);edit.scripts.OnArrowPressed(edit,'DOWN')
assert(submits==1 and moves==1,'normal keyboard navigation resumes')
input('pending',false)
assert(replies.pending and p.searchPending)
count=#queries;items=p.list.items;height=p.frame:GetHeight()
input('tu',true)
assert(not replies.pending({{id='late',title='Late result'}}),'pre-composition reply is cancelled')
assert(#queries==count and p.list.items==items and p.frame:GetHeight()==height,'late reply cannot move the composition snapshot')
I.Search.Session:SourceChanged('composition-test')
I.Search.Session:RefreshSource()
assert(#queries==count,'source refresh cannot restart a suspended query')
input('pending',false)
assert(#queries==count+1,'cancelling composition resumes the original text search')
assert(replies.pending({{id='returned',title='Returned result'}}))
input('x',true)
p:Hide('composition-close')
assert(p:Show())
assert(not p.input.composing,'hide/reopen clears composition ownership')
input('english',false)
assert(queries[#queries]=='english','English text searches normally')
-- Stop a resize at its current position, without snapping to the old target.
p.frame.CreateAnimationGroup=dofile('tests/support/native_animation.lua')
motion:SetReduced(false)
input('毒牙',false)
assert(motion.height,'short result starts a resize')
motion.driver.scripts.OnUpdate(motion.driver,0.04)
height=p.frame:GetHeight();items=p.list.items;count=#queries
input('du',true)
assert(not motion.height and not motion.driver.scripts.OnUpdate,'composition stops the height driver')
assert(p.frame:GetHeight()==height and p.list.items==items,'stopping animation cannot snap the view')
local frames=env.state.createdFrames
for i=1,100 do input("du'ya",true) end
assert(env.state.createdFrames==frames and #queries==count,'preedit reuses UI and schedules no searches')
input('毒牙',false)
assert(motion.height,'commit resumes the interrupted resize')
motion.driver.scripts.OnUpdate(motion.driver,1)
input('x',true)
p:Hide('animated-close')
assert(not p.input.composing and not I.Search.Session.inputSuspended)
assert(p:Show(),'composition can reopen during exit')
motion:SetReduced(true)
input('ready',false);input('d',true)
_G.__combat=true
RunPaletteCombatSnippet(p.frame)
p.frame.scripts.OnEvent(p.frame,'PLAYER_REGEN_DISABLED')
assert(not p.visible and not I.Search.Session.inputSuspended and not p.input.composing,'combat releases composition')
_G.__combat=false
p.frame.scripts.OnEvent(p.frame,'PLAYER_REGEN_ENABLED')
assert(not p.visible,'combat cleanup does not reopen')
assert(p:Show())
height=p.frame:GetHeight()
input('',true)
local points=env.geometry.SetPoint
I.Search.Session:SourceChanged('empty-preedit')
assert(p.frame:GetHeight()==height and env.geometry.SetPoint==points,'source changes preserve home during empty preedit')
input('',false)
edit.IsInIMECompositionMode=nil
input('fallback',false)
assert(queries[#queries]=='fallback','clients without IME state keep ordinary input')
-- Cancel a debounce that has not reached providers, including late timer delivery.
edit.IsInIMECompositionMode=function() return composing end
C_Timer={NewTimer=function(_,callback)
 return {callback=callback,Cancel=function(self) self.cancelled=true end}
end}
composing=false;edit:SetText('queued');edit.scripts.OnTextChanged(edit,true)
local timer=assert(I.Search.Query.timer)
count=#queries
input('q',true)
assert(timer.cancelled and not I.Search.Query.pending,'preedit cancels the scheduled search')
timer.callback()
assert(#queries==count,'cancelled debounce cannot query providers')
input('committed',false)
assert(#queries==count+1 and queries[#queries]=='committed','timer path searches committed text once')
C_Timer=nil
assert(provider:Unregister())
p:Hide('test-end')
print('IME input PASS: preedit/commit/cancel, candidate keys, stale replies, source refresh, reopen and fallback')
