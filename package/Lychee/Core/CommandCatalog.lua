local I = _G.LycheeInternal
local Catalog={commands={}, byExt={}, version=0}
I.Catalog=Catalog
function Catalog:Add(ext,c)
    if type(c)~="table" or type(c.id)~="string" then return nil,{code="INVALID_COMMAND"} end
    local key=ext..":"..c.id; if self.commands[key] then return nil,{code="DUPLICATE_COMMAND"} end
    c._ext=ext; c._key=key; self.commands[key]=c; self.byExt[ext]=self.byExt[ext] or {}; self.byExt[ext][#self.byExt[ext]+1]=key; self.version=self.version+1; return true
end
function Catalog:RemoveExtension(ext) local a=self.byExt[ext]; if not a then return end; for i=1,#a do self.commands[a[i]]=nil end; self.byExt[ext]=nil; self.version=self.version+1 end
function Catalog:SetExtensionEnabled(ext,enabled) local a=self.byExt[ext]; if a then for i=1,#a do self.commands[a[i]]._enabled=enabled end end end
function Catalog:Query(q,limit)
    limit=limit or 20; local out={}; local n=0; local norm=q.normalized or ""
    for _,c in pairs(self.commands) do
        if c._enabled~=false then
            local hay=I.Search.Normalizer:MatchFields(norm,c.title,c.aliases,c.keywords)
            if hay then n=n+1; out[n]={id=c.id,text=c.title,subtext=c.subtext,icon=c.icon,command=c,payload=c.payload or {}} end
        end
    end
    table.sort(out,function(a,b) return (a.command.priority or 0)>(b.command.priority or 0) or a.id<b.id end)
    while #out>limit do out[#out]=nil end
    return out
end
