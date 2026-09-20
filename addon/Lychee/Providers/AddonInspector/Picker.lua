local I=_G.LycheeInternal
I.ProviderModules=I.ProviderModules or {}
local Picker={};Picker.__index=Picker
I.ProviderModules.AddonInspectorPicker=Picker
local strata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local layers={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
local function secret(v) return issecretvalue and issecretvalue(v) end
local function lookup(object,key) return object[key] end
local function returned(ok,...)
    if not ok then return "error" end
    return "known",...
end
local function nativeRead(object,key)
    if not object or secret(object) then return "unavailable" end
    local ok,fn=pcall(lookup,object,key)
    if not ok then return "error" end
    if secret(fn) then return "secret" end
    if type(fn)~="function" then return "unsupported" end
    return returned(pcall(fn,object))
end
local function value(p,object,key)
    local status,v=p.read(object,key)
    if status~="known" or secret(v) then return nil end
    return v
end
local function rect(p,object)
    local scale=value(p,object,"GetEffectiveScale")
    local status,l,b,w,h=p.read(object,"GetRect")
    if status~="known" or secret(l) or secret(b) or secret(w) or secret(h)
        or type(l)~="number" or type(b)~="number" or type(w)~="number" or type(h)~="number"
        or type(scale)~="number" then return nil,"geometry-unreadable" end
    if w<=0 or h<=0 or scale<=0 then return nil,"geometry-empty" end
    return l*scale,b*scale,(l+w)*scale,(b+h)*scale
end
local function inside(p,l,b,r,t) return p.x>=l and p.x<=r and p.y>=b and p.y<=t end
-- All probes return rejected (0), unavailable (1), or verified (2).
-- A missing/secret value is never converted into a negative observation.
local function guard(p,object)
    local grade,reason=2
    local current=object
    local kind=value(p,object,"GetObjectType")
    local isRegion=kind=="Texture" or kind=="FontString"
    local ignoreParentAlpha=isRegion and value(p,object,"IsIgnoringParentAlpha")
    for depth=1,16 do
        if not current then break end
        local shown=value(p,current,"IsVisible")
        if shown==false then return 0,"hidden" end
        if shown~=true then grade,reason=1,"visibility-unreadable" end
        if depth==1 or (isRegion and depth==2 and ignoreParentAlpha~=true) then
            local alpha=value(p,current,isRegion and depth==1 and "GetAlpha" or "GetEffectiveAlpha")
            if type(alpha)=="number" then
                if alpha<=0 then
                    if isRegion and depth==2 and ignoreParentAlpha~=false then grade,reason=1,reason or "alpha-inheritance-unreadable"
                    else return 0,"transparent" end
                end
            else grade,reason=1,reason or "alpha-unreadable" end
        end
        local clipping=value(p,current,"DoesClipChildren")
        -- Regions have no child-clipping method; their parent supplies it.
        if clipping==true then
            local l,b,r,t=rect(p,current)
            if not l and b=="geometry-empty" then return 0,"clipped-content"
            elseif not l then grade,reason=1,reason or b
            elseif not inside(p,l,b,r,t) then return 0,"clipped-content" end
        elseif clipping==nil and not (isRegion and depth==1) then grade,reason=1,reason or "clip-unreadable" end
        local status,parent=p.read(current,"GetParent")
        if status~="known" or secret(parent) then grade,reason=1,reason or "parent-unreadable";break end
        current=parent
        if depth==16 and current then grade,reason=1,reason or "ancestry-truncated" end
    end
    return grade,reason
end
local function region(p,object,button)
    if not object or secret(object) then return 1,"region-unreadable",math.huge end
    local grade,reason=guard(p,object)
    if grade==0 then return 0,reason end
    local kind=value(p,object,"GetObjectType")
    if kind=="FontString" then
        local s=value(p,object,"GetText")
        if type(s)~="string" then grade,reason=1,reason or "text-unreadable"
        elseif not s:find("%S") then return 0,"text-empty" end
    elseif kind=="Texture" then
        local texture=value(p,object,"GetTexture") or value(p,object,"GetAtlas")
        if not texture or texture=="" then
            if value(p,object,"IsObjectLoaded")==false then return 0,"texture-empty" end
            grade,reason=1,reason or "texture-content-unavailable"
        end
    else return 1,reason or "region-type-unreadable",math.huge end
    local status,_,_,_,alpha=p.read(object,kind=="Texture" and "GetVertexColor" or "GetTextColor")
    if status=="known" and not secret(alpha) and type(alpha)=="number" then
        if alpha<=0 then return 0,"transparent-color" end
    else grade,reason=1,reason or "color-unreadable" end
    local l,b,r,t=rect(p,object)
    if not l then
        if b=="geometry-empty" then return 0,b end
        return 1,reason or b,math.huge
    end
    if not inside(p,l,b,r,t) then
        if not button then return 0,"outside-pointer" end
        local bl,bb,br,bt=rect(p,button)
        if not bl or not inside(p,bl,bb,br,bt) then return 0,"outside-pointer" end
        l,b,r,t=math.max(l,bl),math.max(b,bb),math.min(r,br),math.min(t,bt)
        if r<=l or t<=b then return 0,"button-content-outside" end
    end
    -- Check the actual paint intersection, including text inside button padding.
    local parent=value(p,object,"GetParent")
    for depth=1,16 do
        if not parent then break end
        if value(p,parent,"DoesClipChildren")==true then
            local cl,cb,cr,ct=rect(p,parent)
            if not cl and cb=="geometry-empty" then return 0,"clipped-content"
            elseif not cl then grade,reason=1,reason or cb
            else
                l,b,r,t=math.max(l,cl),math.max(b,cb),math.min(r,cr),math.min(t,ct)
                if r<=l or t<=b then return 0,"clipped-content" end
            end
        end
        parent=value(p,parent,"GetParent")
    end
    return grade,reason,(r-l)*(t-b),object
end
local function ownRegions(p,button,status,...)
    if status~="known" then return 1,"regions-unreadable",math.huge end
    local grade,reason,area,paint=0,"no-visible-content"
    for i=1,math.min(select("#",...),32) do
        local candidate=select(i,...)
        local g,r,a,o=region(p,candidate,button)
        if g>grade or (g==grade and a and (not area or a<area)) then grade,reason,area,paint=g,r,a,o end
    end
    if grade==0 and select("#",...)>32 then return 1,"regions-truncated",math.huge end
    return grade,reason,area,paint
end
local function evaluate(p,object)
    if not object or secret(object) or not p.allowed(object) then return 0,"excluded" end
    local guardGrade,guardReason=guard(p,object)
    if guardGrade==0 then return 0,guardReason end
    local kind=value(p,object,"GetObjectType")
    local grade,reason,area,paint
    if kind=="Texture" or kind=="FontString" then
        grade,reason,area,paint=region(p,object)
    elseif not kind then grade,reason,area=1,"type-unreadable",math.huge
    else
        local button=(kind=="Button" or kind=="CheckButton") and value(p,object,"IsMouseClickEnabled")==true and object or nil
        grade,reason,area,paint=ownRegions(p,button,p.read(object,"GetRegions"))
        -- A layout container is not paint. Neither child existence nor an
        -- unreadable visibility flag supplies self-content evidence. Native
        -- descendants remain independent candidates in the fallback snapshot.
    end
    if grade==0 then return 0,reason end
    if guardGrade==1 then grade,reason=1,guardReason end
    local l,b,r,t=rect(p,object)
    local outline
    if grade==2 then outline=l and inside(p,l,b,r,t) and object or paint end
    local frame=(kind=="Texture" or kind=="FontString") and value(p,object,"GetParent") or object
    local level=value(p,frame,"GetFrameLevel")
    return grade,reason,outline,strata[value(p,frame,"GetFrameStrata")] or 0,
        type(level)=="number" and level or 0,layers[value(p,object,"GetDrawLayer")] or 0,area or math.huge
end
local function wipe(t) for key in pairs(t) do t[key]=nil end end
function Picker.New(allowed,reader,clock)
    return setmetatable({allowed=allowed,read=reader or nativeRead,clock=clock or function() return debugprofilestop and debugprofilestop() or 0 end,
        result={},queue={},seen={},reasons={}},Picker)
end
function Picker:State() return self.result end
function Picker:Reset()
    wipe(self.result);wipe(self.queue);wipe(self.seen);wipe(self.reasons)
    self.preferred,self.best,self.bestOutline,self.details=nil,nil,nil,nil
    self.x,self.y,self.head,self.tail,self.rawReason=nil,nil,nil,nil,nil
end
local function commit(p,object,grade,reason,outline)
    local r=p.result;r.object,r.evidence,r.reason,r.outline=object,grade,reason,outline
end
local function better(p,object,g,s,l,d,a)
    if not p.best then return true end
    if s~=p.bestStrata then return s>p.bestStrata end
    if l~=p.bestLevel then return l>p.bestLevel end
    if d~=p.bestLayer then return d>p.bestLayer end
    if g~=p.bestGrade then return g>p.bestGrade end
    if a~=p.bestArea then return a<p.bestArea end
    return object==p.result.object -- Stable identity only at an actual ordering tie.
end
local function safeText(v)
    if secret(v) or type(v)~="string" then return "—" end
    return v:gsub("|","||")
end
local function record(p,object,reason)
    p.result.checked=p.result.checked+1
    if reason then p.reasons[reason]=(p.reasons[reason] or 0)+1 end
    if p.details then
        p.details[#p.details+1]=safeText(value(p,object,"GetDebugName")):sub(1,120).." | "..(reason or "visible").." | "..
            safeText(value(p,object,"GetSourceLocation")):sub(1,160)
    end
end
local function seed(p,snapshot)
    wipe(p.queue);wipe(p.seen);wipe(p.reasons)
    p.head,p.tail,p.best,p.bestOutline,p.details=1,0,nil,nil,nil
    local r=p.result;r.checked,r.capped,r.ready,r.detailsCount=0,false,false,0
    if type(snapshot)=="function" then local ok,list=pcall(snapshot);snapshot=ok and not secret(list) and list or nil end
    r.supported=type(snapshot)=="table" or p.preferred~=nil
    if type(snapshot)=="table" then
        for i=1,math.min(#snapshot,512) do
            local object=snapshot[i]
            if object and not secret(object) and not p.seen[object] then
                p.tail=p.tail+1;p.queue[p.tail]=object;p.seen[object]=true
            end
        end
        r.capped=#snapshot>512
    end
    r.queued=p.tail;r.hasDiagnostic=p.preferred~=nil or p.tail>0
end
-- One call consumes a native highlight and, only after a rejection, a bounded
-- native snapshot. No derived object is ever promoted into a native candidate.
function Picker:Step(preferred,snapshot,x,y,frozen)
    local r=self.result
    if frozen then
        if r.object or r.ready then return r end
        if not self.details then
            self.details={};self.head=1;self.best=nil;r.checked=0;wipe(self.reasons)
        end
    else
        if secret(x) or secret(y) or type(x)~="number" or type(y)~="number" then self:Reset();return r end
        local moved=self.x~=x or self.y~=y
        self.x,self.y=x,y;r.x,r.y=x,y
        if moved then commit(self,nil);self.head=nil end
        local g,reason,outline=evaluate(self,preferred)
        if preferred and g>0 then
            wipe(self.queue);wipe(self.seen);wipe(self.reasons)
            self.preferred,self.rawReason,self.details,self.best,self.bestOutline=preferred,reason,nil,nil,nil
            self.head,self.tail=nil,0
            r.checked,r.queued,r.pending,r.capped,r.ready,r.supported,r.hasDiagnostic=1,1,false,false,false,true,true
            r.detailsCount=0
            commit(self,preferred,g,reason,outline);return r
        end
        if not self.head or not r.pending or (preferred and preferred~=self.preferred and not self.seen[preferred]) then
            self.preferred,self.rawReason=preferred,reason
            seed(self,snapshot)
        end
    end
    -- Revalidate the committed object; rejected/removed objects disappear now,
    -- while partially scanned replacements are never published.
    if r.object then
        local g,reason,outline=evaluate(self,r.object)
        if not self.seen[r.object] or g==0 then commit(self,nil)
        else commit(self,r.object,g,reason,outline) end
    end
    local started=self.clock()
    for i=1,128 do
        local object=self.queue[self.head]
        if not object then break end
        self.head=self.head+1
        local g,reason,outline,s,l,d,a=evaluate(self,object)
        record(self,object,reason)
        if g>0 and better(self,object,g,s,l,d,a) then
            self.best,self.bestGrade,self.bestReason,self.bestOutline=object,g,reason,outline
            self.bestStrata,self.bestLevel,self.bestLayer,self.bestArea=s,l,d,a
        end
        if self.clock()-started>=0.75 then break end
    end
    r.pending=self.head<=self.tail
    r.ready=self.details~=nil and not r.pending
    r.detailsCount=self.details and #self.details or 0
    if not r.pending then
        -- Facts may change while a batch was pending; never publish a stale winner.
        local g,reason,outline=evaluate(self,self.best)
        if g>0 then commit(self,self.best,g,reason,outline) else commit(self,nil) end
    end
    return r
end
function Picker:Describe()
    local r=self.result
    local lines={"Picker: "..(r.pending and "pending" or "complete"),
        "checked="..(r.checked or 0).." queued="..(r.queued or 0).." capped="..tostring(r.capped or false),
        "native="..safeText(value(self,self.preferred,"GetDebugName")),"nativeFilter="..tostring(self.rawReason),
        "evidence="..(r.evidence==2 and "verified" or r.evidence==1 and "unverified" or "none")}
    if r.reason then lines[#lines+1]="evidenceReason="..r.reason end
    if self.preferred then
        lines[#lines+1]="nativeType="..safeText(value(self,self.preferred,"GetObjectType"))
        local l,b,right,top=rect(self,self.preferred)
        lines[#lines+1]="nativeRect="..(l and (l..","..b..","..right..","..top) or b)
    end
    for reason,count in pairs(self.reasons) do lines[#lines+1]=reason.."="..count end
    if self.details then
        lines[#lines+1]="Frozen pointer: "..self.x..", "..self.y
        lines[#lines+1]="Candidate | filter | creation source"
        for _,detail in ipairs(self.details) do lines[#lines+1]=detail end
    end
    return table.concat(lines,"\n")
end
