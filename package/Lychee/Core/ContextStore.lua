local I = _G.LycheeInternal
local Store={slices={},listeners={},version=0}
I.Context=Store
function Store:Get(name) local s=self.slices[name]; return s and s.data,s and s.version or 0 end
function Store:Set(name,data)
    local s=self.slices[name]; if s and s.data==data then return s.version end
    self.version=self.version+1; self.slices[name]={data=data,version=self.version}
    local ls=self.listeners[name]; if ls then for i=1,#ls do pcall(ls[i],data,self.version) end end
    return self.version
end
function Store:On(name,fn) self.listeners[name]=self.listeners[name] or {}; self.listeners[name][#self.listeners[name]+1]=fn end
function Store:Snapshot() local out={}; for k,s in pairs(self.slices) do out[k]=s.data end; return out,self.version end
