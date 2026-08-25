local I = _G.LycheeInternal
local Broker={providers={},byExt={}}
I.Broker=Broker
function Broker:Add(ext,p)
    if type(p.type)~="string" or type(p.query)~="function" then return nil,{code="INVALID_PROVIDER"} end
    self.providers[p.type]=self.providers[p.type] or {}; local list=self.providers[p.type]; list[#list+1]={ext=ext,provider=p}; table.sort(list,function(a,b) return (a.provider.priority or 0)>(b.provider.priority or 0) end); self.byExt[ext]=self.byExt[ext] or {}; self.byExt[ext][#self.byExt[ext]+1]=p.type; return true
end
function Broker:RemoveExtension(ext) local types=self.byExt[ext]; if not types then return end; for i=1,#types do local list=self.providers[types[i]]; for j=#list,1,-1 do if list[j].ext==ext then table.remove(list,j) end end end; self.byExt[ext]=nil end
function Broker:Query(t,request,context)
    local list=self.providers[t]; if not list then return nil,{code="CAPABILITY_UNAVAILABLE"} end
    for i=1,#list do local ok,res=pcall(list[i].provider.query,request,context); if ok and type(res)=="table" then return res end end
    return nil,{code="CAPABILITY_FAILED"}
end
