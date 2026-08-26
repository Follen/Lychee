local I = _G.LycheeInternal
local Catalog={commands={}, byExt={}, version=0}
I.Catalog=Catalog
function Catalog:Add(ext,c)
    if type(c)~="table" or type(c.id)~="string" then return nil,{code="INVALID_COMMAND"} end
    local key=ext..":"..c.id; if self.commands[key] then return nil,{code="DUPLICATE_COMMAND"} end
    if I.Search and I.Search.StaticIndex then
        if not I.Search.StaticIndex.sources[ext] then I.Search.StaticIndex:RegisterSource({id=ext,priority=c.priority or 0}) end
        I.Search.StaticIndex:AddRecord(ext,{id=c.id,kind="command",title=c.title,aliases=c.aliases,keywords=c.keywords,description=c.description,payload=c},{id=ext,priority=c.priority or 0})
    end
    c._ext=ext; c._key=key; self.commands[key]=c; self.byExt[ext]=self.byExt[ext] or {}; self.byExt[ext][#self.byExt[ext]+1]=key; self.version=self.version+1; return true
end
function Catalog:RemoveExtension(ext) local a=self.byExt[ext]; if not a then return end; for i=1,#a do self.commands[a[i]]=nil end; self.byExt[ext]=nil; if I.Search and I.Search.StaticIndex then I.Search.StaticIndex:UnregisterSource(ext) end; self.version=self.version+1 end
function Catalog:SetExtensionEnabled(ext,enabled) local a=self.byExt[ext]; if a then for i=1,#a do self.commands[a[i]]._enabled=enabled end end end
function Catalog:Query(q,limit)
    limit=limit or 20; local out={}; local index=I.Search and I.Search.StaticIndex
    local hits=index and index:Search(q.normalized or "", limit * 2) or {}
    local function display(value)
        if type(value) == "string" then return value end
        if type(value) ~= "table" then return "" end
        if value.text then return value.text end
        local locale = I.Search.Normalizer.locale
        return value[locale] or value.default or value.enUS or ""
    end
    for i=1,#hits do
        local hit, c = hits[i], hits[i].item
        if c and c._enabled ~= false and c._ext and hit.record.kind == "command" then
            local category = c.category
            out[#out+1] = {
                id=c.id, text=display(c.title), subtext=c.subtext, description=c.description,
                icon=c.icon, category=display(category and category.title or category),
                command=c, payload=c.payload or {}, confidence=hit.confidence, evidence=hit.evidence,
                sourcePriority=hit.sourcePriority, categoryOrder=hit.categoryOrder,
                stableID=hit.stableID,
            }
        end
    end
    table.sort(out,function(a,b)
        if (a.confidence or 0) ~= (b.confidence or 0) then return (a.confidence or 0) > (b.confidence or 0) end
        local ap, bp = a.sourcePriority or (a.command and a.command.priority) or 0, b.sourcePriority or (b.command and b.command.priority) or 0
        if ap ~= bp then return ap > bp end
        local ac, bc = a.categoryOrder or 0, b.categoryOrder or 0
        if ac ~= bc then return ac < bc end
        return tostring(a.stableID or a.id) < tostring(b.stableID or b.id)
    end)
    while #out>limit do out[#out]=nil end
    return out
end
