-- Animation boundary double. It models playback/reset/independent tracks;
-- its easing is deliberately not evidence of the client's rendered trajectory.
local Animation={}
function Animation:SetSmoothing(v) self.smoothing=v end
function Animation:GetSmoothProgress() return self.progress end
function Animation:SetFromAlpha(v) self.from=v end
function Animation:SetToAlpha(v) self.to=v end
function Animation:SetScaleFrom(x,y) assert(x==y);self.from=x end
function Animation:SetScaleTo(x,y) assert(x==y);self.to=x end
function Animation:SetDuration(v) self.duration=v end
function Animation:SetOffset(x,y) self.x,self.y=x,y end
function Animation:SetOrder(v) assert(v==1);self.order=v end
function Animation:SetOrigin(p,x,y) self.origin,self.x,self.y=p,x,y end
local Group={}
function Group:SetScript(k,v) self.scripts[k]=v end
function Group:Stop()
    self.playing=false
    for _,a in ipairs(self.animations) do a.progress=0 end
    if self.onStop then self.onStop() end
end
function Group:IsPlaying() return self.playing end
function Group:Play()
    self.playing=true;self.elapsed=0
    for _,a in ipairs(self.animations) do a.progress=0 end
end
function Group:CreateAnimation(kind)
    assert(kind=="Alpha" or kind=="Translation" or kind=="Scale")
    local a=setmetatable({kind=kind,progress=0},{__index=Animation})
    self.animations[#self.animations+1]=a;self.a=a
    return a
end
function Group:Advance(seconds)
    if not self.playing then return end
    self.elapsed=self.elapsed+seconds
    local done=true
    for _,a in ipairs(self.animations) do
        local u=math.min(1,self.elapsed/a.duration)
        a.progress=a.smoothing=="IN" and u*u or (a.smoothing=="OUT" and 1-(1-u)^2 or u)
        if u<1 then done=false end
    end
    if done then
        self.playing=false
        if self.scripts.OnFinished then self.scripts.OnFinished(self) end
    end
end
return function()
    return setmetatable({scripts={},animations={},playing=false,elapsed=0},{__index=Group})
end
