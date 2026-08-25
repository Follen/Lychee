local I = _G.LycheeInternal
local Index={map={},version=0}
I.Search.StaticIndex=Index
function Index:Add(key,item,fields)
    fields=fields or {}; local all={item.title}; for _,f in ipairs({fields.aliases,fields.keywords}) do if type(f)=="table" then for i=1,#f do local x=I.Search.Normalizer:AliasText(f[i]); if x then all[#all+1]=x end end end end
    for i=1,#all do local n=I.Search.Normalizer:Normalize(all[i]); if n~="" then self.map[n]=self.map[n] or {}; self.map[n][#self.map[n]+1]={key=key,item=item} end end; self.version=self.version+1
end
function Index:Lookup(q,limit) local n=I.Search.Normalizer:Normalize(q); local out={}; local seen={}; for k,v in pairs(self.map) do if k:find(n,1,true) then for i=1,#v do if not seen[v[i].key] then seen[v[i].key]=true; out[#out+1]=v[i].item end end end end; while #out>(limit or 20) do out[#out]=nil end; return out end
