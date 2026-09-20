-- Native animation boundaries only; the real LycheeGlow owns geometry/lifecycle.
local base=CreateFrame
local function noop() end
function CreateFrame(...)
    local f=base(...)
    f.IsShown=function(self) return self.shown end
    f.GetWidth=function(self) return self.testWidth or 36 end
    f.GetHeight=function(self) return self.testHeight or 36 end
    f.SetPoint=function(self,point,parent,relative,x,y) self.anchor=parent end
    local createTexture=f.CreateTexture
    function f:CreateTexture(...)
        local t=createTexture(self,...)
        t.SetTexture=noop;t.SetBlendMode=noop;t.SetSize=noop;t.SetVertexColor=noop
        t.SetAtlas=noop;t.SetDesaturated=noop;t.SetTexCoord=noop
        t.Show=function(self) self.shown=true end;t.Hide=function(self) self.shown=false end
        t.ClearAllPoints=noop
        t.SetPoint=function(self,point,parent,relative,x,y) self.x,self.y=x,y end
        function t:CreateAnimationGroup()
            local g={scripts={}}
            function g:SetScript(k,v) self.scripts[k]=v end
            g.SetLooping=noop
            function g:Play() self.playing=true end
            function g:Stop() self.playing=false end
            function g:IsPlaying() return self.playing==true end
            function g:CreateAnimation(kind)
                assert(kind=="Path" or kind=="FlipBook")
                local a={}
                a.SetFlipBookRows=noop;a.SetFlipBookColumns=noop;a.SetFlipBookFrames=noop
                a.SetFlipBookFrameWidth=noop;a.SetFlipBookFrameHeight=noop
                a.SetCurveType=function(_,value) assert(value=="NONE" or value=="SMOOTH") end;a.SetSmoothing=noop
                function a:SetDuration(value) self.duration=value end
                function a:CreateControlPoint(_,_,order)
                    return {order=order,SetOffset=function(self,x,y) self.x,self.y=x,y end}
                end
                return a
            end
            return g
        end
        return t
    end
    return f
end
