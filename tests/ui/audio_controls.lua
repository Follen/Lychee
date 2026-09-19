local env=dofile("tests/support/palette.lua")
local I=LycheeInternal
local nativeCreate=CreateFrame
function CreateFrame(kind,...)
 local frame=nativeCreate(kind,...)
 if kind=="Slider" then
  -- Retail 12.1.0: a new thumb is unanchored; SetValue also skips layout
  -- when its value equals the existing default minimum (zero).
  frame.value,frame.setCalls=0,0
  function frame:SetOrientation() end
  function frame:SetMinMaxValues(min,max) self.min,self.max=min,max end
  function frame:SetValueStep() end
  function frame:SetThumbTexture(thumb) self.thumb=thumb end
  function frame:GetValue() return self.value end
  function frame:SetValue(value)
   self.setCalls=self.setCalls+1
   if self.value==value then return end
   self.value=value
   if self.thumb then self.thumb.position=value end
   local fn=self:GetScript("OnValueChanged");if fn then fn(self,value) end
  end
 end
 return frame
end
local values={master=30,music=0,sfx=100,ambience=10,dialog=10}
local channels={}
for _,id in ipairs({"master","music","sfx","ambience","dialog"}) do channels[#channels+1]={id=id,title=id} end
I.Builtin=I.Builtin or {}
I.Builtin.AudioAdapter={channels=channels,Read=function(channel) return values[channel] end}
dofile(arg[1] or "addon/Lychee/Builtin/Audio/View.lua")
local view=I.Builtin.AudioView.Create()
local observers,edits,pushes,cancels={},0,0,0
local context={contentFrame=CreateFrame("Frame"),Resize=function() end}
function context:Observe(target,callback)
 observers[target.key.channel]=callback
 return function() observers[target.key.channel]=nil end
end
function context:BeginEdit()
 edits=edits+1
 return {Push=function() pushes=pushes+1 end,Finish=function() end,Cancel=function() cancels=cancels+1 end}
end
view:Mount(context,{channel="music"})
local function positioned(row,value)
 local thumb=row.slider.thumb
 if thumb.position~=nil then return thumb.position==value end
 local point=thumb.point
 return value==0 and point and point[1]=="LEFT" and point[2]==row.slider and point[3]=="LEFT" and point[4]==0 and point[5]==0
end
for _,row in ipairs(view.rows) do
 assert(positioned(row,values[row.channel]),row.channel.." thumb unpositioned on first mount")
end
assert(edits==0 and pushes==0,"mount wrote an audio edit")
local music=view.rows[2]
local count=music.slider.setCalls
for _=1,20 do view:Refresh(music) end
assert(music.slider.setCalls==count,"unchanged refresh repeats native setter")
values.music=100;observers.music({})
assert(music.slider.thumb.position==100,"external maximum not displayed")
values.music=0;observers.music({})
assert(music.slider.thumb.position==0,"external zero not displayed")
music.slider:GetScript("OnMouseDown")(music.slider)
music.slider:SetValue(40)
assert(edits==1 and pushes==1,"drag no longer submits edit")
view:Refresh(music)
assert(music.slider:GetValue()==40,"refresh overwrote an active drag")
view:Unmount()
assert(cancels==1 and not next(observers) and not music.dragging,"unmount left edits or observers")
local frames=env.state.createdFrames
view:Mount(context,{channel="music"})
assert(music.slider.thumb.position==0,"reopen failed to restore actual zero")
assert(env.state.createdFrames==frames,"reopen rebuilt sliders")
view:Unmount()
print("Audio controls PASS: zero/max initialization, external updates, drag, unchanged refresh, reopen and cleanup")
