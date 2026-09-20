-- Native animation boundaries only; the real LycheeGlow owns geometry/lifecycle.
local base=CreateFrame
local function noop() end
function CreateFrame(...)
    local f=base(...)
    f.GetWidth=function(self) return self.testWidth or 36 end
    f.GetHeight=function(self) return self.testHeight or 36 end
    f.SetPoint=function(self,point,parent,relative,x,y) self.anchor=parent end
    local createTexture=f.CreateTexture
    function f:CreateTexture(...)
        local t=createTexture(self,...)
        t.SetTexture=noop;t.SetBlendMode=noop;t.SetSize=noop;t.SetVertexColor=noop
        t.ClearAllPoints=noop
        t.SetPoint=function(self,point,parent,relative,x,y) self.x,self.y=x,y end
        function t:CreateAnimationGroup()
            local g={}
            g.SetLooping=noop
            function g:Play() self.playing=true end
            function g:Stop() self.playing=false end
            function g:IsPlaying() return self.playing==true end
            function g:CreateAnimation(kind)
                assert(kind=="Path")
                local a={}
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
