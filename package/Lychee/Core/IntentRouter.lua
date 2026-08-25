local I = _G.LycheeInternal
local Router={handlers={},byExt={}}
I.Router=Router
function Router:Add(ext,h) if type(h.type)~="string" or type(h.handle)~="function" then return nil,{code="INVALID_HANDLER"} end; self.handlers[h.type]=self.handlers[h.type] or {}; self.handlers[h.type][#self.handlers[h.type]+1]={ext=ext,handler=h}; self.byExt[ext]=self.byExt[ext] or {}; self.byExt[ext][#self.byExt[ext]+1]=h.type; return true end
function Router:RemoveExtension(ext) local ts=self.byExt[ext]; if ts then for i=1,#ts do local l=self.handlers[ts[i]]; for j=#l,1,-1 do if l[j].ext==ext then table.remove(l,j) end end end end; self.byExt[ext]=nil end
function Router:Execute(intent,ctx) if type(intent)~="table" or type(intent.type)~="string" then return nil,{code="INVALID_INTENT"} end; local l=self.handlers[intent.type]; if not l then return nil,{code="HANDLER_UNAVAILABLE"} end; local h=l[1]; local ok,res=pcall(h.handler.handle,intent.payload or {},ctx); if not ok then return nil,{code="HANDLER_FAILED"} end; return res end
