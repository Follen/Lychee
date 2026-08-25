local I = _G.LycheeInternal
local Q={generation=0,active=false,last=nil,ambientEnabled={},limit=20}
I.Search.Query=Q
function Q:Query(raw,context,externalGeneration)
    self.generation=externalGeneration or (self.generation+1); local g=self.generation; local normalized=I.Search.Normalizer:Normalize(raw); local q={generation=g,raw=raw or "",normalized=normalized,tokens=I.Search.Normalizer:Terms(normalized),limit=self.limit,contextToken=context and context.token}
    local out=I.Catalog and I.Catalog:Query(q,self.limit) or {}
    local all={}; for i=1,#out do all[#all+1]=out[i] end
    if #normalized>0 and I.Catalog then
        for _,c in pairs(I.Catalog.commands) do if c._enabled~=false and c.match and c.match.type=="ambient" and not (self.ambientEnabled[c._key]==false) and #normalized>=c.match.minLength and #normalized<=c.match.maxLength and type(c.resolve)=="function" then
            local ok,items=pcall(c.resolve,q,context or {}); if ok and type(items)=="table" then for j=1,#items do items[j]._ext=c._ext; items[j].command=c; all[#all+1]=items[j] end end
        end end
    end
    table.sort(all,function(a,b) local pa=(a.command and a.command.priority or 0); local pb=(b.command and b.command.priority or 0); return pa>pb or (pa==pb and tostring(a.id)<tostring(b.id)) end)
    while #all>self.limit do all[#all]=nil end; self.last={generation=g,results=all}; return g,all
end
function Q:Invalidate() self.generation=self.generation+1; self.last=nil end
function Q:SetAmbientEnabled(key,enabled) self.ambientEnabled[key]=enabled end
