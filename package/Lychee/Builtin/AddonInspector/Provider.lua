local I=_G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.addon-inspector")
I.Builtin=I.Builtin or {}
local M={id="builtin.addon-inspector",epoch=0}
I.Builtin.AddonInspector=M
local function secret(value) return issecretvalue and issecretvalue(value) end
local function clean(value) if not secret(value) then return value end end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok then return clean(value) end
end
local function index(object,key) return object[key] end
local function method(object,key)
    if secret(object) or object==nil then return end
    local ok,fn=pcall(index,object,key)
    if ok and not secret(fn) and type(fn)=="function" then return fn end
end
function M:Read(object,key)
    return call(method(object,key),object)
end
local function text(value,fallback)
    if type(value)~="string" then return fallback or "—" end
    return value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|","||"):sub(1,512)
end
local function addonTitle(folder)
    return call(C_AddOns and C_AddOns.GetAddOnMetadata,folder,"Title")
end
function M:Source(location)
    if type(location)~="string" then return end
    local path=location:gsub("\\","/")
    local folder=path:match("[Ii]nterface/[Aa]dd[Oo]ns/([^/]+)/")
    if folder then
        if folder:lower():match("^blizzard_") then return L["暴雪创建代码"],folder,true end
        return text(addonTitle(folder),folder),folder
    end
    if path:find("FrameXML/",1,true) then return L["暴雪创建代码"],"Blizzard UI",true end
end
local scanRelated
local function scanRelatedList(owner,state,depth,ok,...)
    if not ok then return end
    if select("#",...)>32 then state.truncated=true end
    for i=1,math.min(select("#",...),32) do
        scanRelated(owner,clean(select(i,...)),depth,state)
        if state.remaining<=0 or state.expired then state.truncated=true;break end
    end
end
scanRelated=function(owner,object,depth,state)
    if not object or secret(object) or state.visited[object] then return end
    if state.remaining<=0 or (debugprofilestop and debugprofilestop()-state.started>=1) then
        state.truncated=true;state.expired=true;return
    end
    state.remaining=state.remaining-1;state.visited[object]=true
    if owner:Read(object,"IsForbidden") or owner:Read(object,"IsVisible")~=true then return end
    local kind=owner:Read(object,"GetObjectType")
    local isRegion=kind=="Texture" or kind=="FontString"
    local alpha=owner:Read(object,isRegion and "GetAlpha" or "GetEffectiveAlpha")
    if type(alpha)~="number" or alpha<=0 then return end
    local location=owner:Read(object,"GetSourceLocation")
    local title,folder,native=owner:Source(location)
    if title and not native and not state.folders[folder] then
        state.folders[folder]=true
        if #state.results<3 then
            state.results[#state.results+1]={title=title,folder=folder,location=text(location),
                name=text(owner:Read(object,"GetDebugName"))}
        else state.truncated=true end
    end
    if not isRegion and depth<2 then
        scanRelatedList(owner,state,depth+1,pcall(method(object,"GetRegions"),object))
        if state.remaining>0 and not state.expired then
            scanRelatedList(owner,state,depth+1,pcall(method(object,"GetChildren"),object))
        end
    end
end
function M:RelatedSources(object)
    local kind=self:Read(object,"GetObjectType")
    if kind=="Texture" or kind=="FontString" then object=self:Read(object,"GetParent") end
    if not self:CheckFocus(object) then return end
    local state={remaining=64,started=debugprofilestop and debugprofilestop() or 0,visited={},folders={},results={}}
    scanRelated(self,object,0,state)
    return #state.results>0 and state.results or nil,state.truncated
end
function M:Analyze(frame)
    local location=self:Read(frame,"GetSourceLocation")
    local title,folder,native=self:Source(location)
    local resolved=title and not native
    local name=text(self:Read(frame,"GetName"),text(self:Read(frame,"GetDebugName"),L["未命名框体"]))
    local data={name=name,title=native and L["归属未确定"] or title or L["暂未识别"],confidence=native and L["创建位置来自暴雪代码"] or title and L["创建来源"] or L["来源未确定"],
        location=text(location,L["未提供创建位置"]),parents={},kind=text(self:Read(frame,"GetObjectType"))}
    if not title or native then
        local prefix=name:match("^([%a][%w]+)[_%-]")
        local guessed=prefix and addonTitle(prefix)
        if guessed then data.title=text(guessed);data.confidence=L["可能来自 · 根据框体名称"] end
    end
    local parent=self:Read(frame,"GetParent")
    local visited={[frame]=true}
    local started=debugprofilestop and debugprofilestop() or 0
    for depth=1,16 do
        if not parent or parent==UIParent or parent==WorldFrame or visited[parent] then break end
        visited[parent]=true
        local parentTitle,_,parentNative=self:Source(self:Read(parent,"GetSourceLocation"))
        data.parents[#data.parents+1]=text(self:Read(parent,"GetName"),L["未命名父级"])..(parentTitle and " · "..parentTitle or "")
        if (not title or native) and parentTitle and not parentNative and data.confidence~=L["可能来自 · 根据父级来源"] then
            data.title=parentTitle;data.confidence=L["可能来自 · 根据父级来源"]
            resolved=true
        end
        parent=self:Read(parent,"GetParent")
        if debugprofilestop and debugprofilestop()-started>=1 then data.truncated=true;break end
    end
    if parent and parent~=UIParent and parent~=WorldFrame then data.truncated=true end
    if not resolved then
        data.relatedSources,data.relatedTruncated=self:RelatedSources(frame)
        if data.relatedSources then
            local names={}
            for i,source in ipairs(data.relatedSources) do names[i]=source.title end
            data.title=table.concat(names," / ");data.confidence=L["关联插件 · 内部控件来源"]
        end
    end
    local width,height=self:Read(frame,"GetWidth"),self:Read(frame,"GetHeight")
    data.size=type(width)=="number" and type(height)=="number" and string.format("%.0f × %.0f",width,height) or "—"
    data.level=self:Read(frame,"GetFrameLevel")
    data.strata=text(self:Read(frame,"GetFrameStrata"))
    return data
end
function M:CheckFocus(frame)
    frame=clean(frame)
    if not frame or frame==UIParent or frame==WorldFrame or self:Read(frame,"IsForbidden") then return end
    local current=frame
    for depth=1,16 do
        if current==GameTooltip then return end
        if current==self.stackRoot or current==self.stackTooltip then return nil,true end
        if self.view and (current==self.view.frame or current==self.view.outline) then return nil,true end
        if current==UIParent or current==WorldFrame or not current then break end
        current=self:Read(current,"GetParent")
    end
    return frame
end
local strataOrder={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local layerOrder={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
local Evidence={}
function M:ResetVisual()
    self.visualBest,self.visualBestFrame,self.visualX,self.visualY=nil,nil,nil,nil
    self.visualProvisional=nil
    self.visualFromPrevious=nil
    self.visualUnknown,self.unknownReason=nil,nil
end
function M:Reject(reason)
    self.pickReason=reason
end
function M:HitRect(object,scale)
    local l,b,r,t=Evidence.rect(self,object,scale)
    if not l then return self:Reject(b) end
    local x,y=self.visualX,self.visualY
    if x>=l and x<=r and y>=b and y<=t then return (r-l)*(t-b) end
    return self:Reject("outside-pointer")
end
function M:VisualFrame(frame)
    local shown=self:Read(frame,"IsVisible")
    if shown~=true then return self:Reject(shown==false and "hidden" or "visibility-unreadable") end
    local alpha=self:Read(frame,"GetEffectiveAlpha")
    if type(alpha)~="number" then return self:Reject("alpha-unreadable") end
    if alpha<=0 then return self:Reject("transparent") end
    local valid=self:CheckFocus(frame)
    if not valid then return self:Reject("excluded") end
    local parent=frame -- Its own regions are clipped here too (chat FontStringContainer).
    for depth=1,16 do
        if not parent then break end
        if self:Read(parent,"DoesClipChildren")==true and not self:HitRect(parent,self:Read(parent,"GetEffectiveScale")) then return self:Reject("clipped-or-unreadable") end
        parent=self:Read(parent,"GetParent")
    end
    return self:Read(frame,"GetEffectiveScale")
end
-- Rendering evidence is separate from source attribution. Unknown content is
-- never painted as a confirmed selection, nor treated as a proven empty region.
function Evidence.rect(owner,object,scale)
    scale=scale or owner:Read(object,"GetEffectiveScale")
    local ok,l,b,w,h=pcall(method(object,"GetRect"),object)
    if not ok or secret(l) or secret(b) or secret(w) or secret(h)
        or type(l)~="number" or type(b)~="number" or type(w)~="number" or type(h)~="number"
        or type(scale)~="number" then return nil,"geometry-unreadable" end
    if scale<=0 or w<=0 or h<=0 then return nil,"geometry-empty" end
    return l*scale,b*scale,(l+w)*scale,(b+h)*scale
end
function Evidence.clip(owner,frame,l,b,r,t)
    for depth=1,16 do
        if not frame then break end
        local clipping=owner:Read(frame,"DoesClipChildren")
        if clipping==nil then return nil,"clip-unreadable" end
        if clipping then
            local cl,cb,cr,ct=Evidence.rect(owner,frame)
            if not cl then return nil,"clipped-or-unreadable" end
            l,b,r,t=math.max(l,cl),math.max(b,cb),math.min(r,cr),math.min(t,ct)
            if r<=l or t<=b then return nil,"clipped-content" end
        end
        frame=owner:Read(frame,"GetParent")
    end
    return l,b,r,t
end
function Evidence.region(owner,region,frame,button)
    local shown=owner:Read(region,"IsVisible")
    if shown~=true then return nil,shown==false and "hidden" or "visibility-unreadable" end
    local alpha=owner:Read(region,"GetAlpha")
    if type(alpha)~="number" then return nil,"alpha-unreadable" end
    if alpha<=0 then return nil,"transparent" end
    local kind=owner:Read(region,"GetObjectType")
    local grade,reason=2
    if kind=="Texture" then
        local texture=owner:Read(region,"GetTexture") or owner:Read(region,"GetAtlas")
        if not texture or texture=="" then
            if owner:Read(region,"IsObjectLoaded")==false then return nil,"texture-empty" end
            grade,reason=1,"texture-content-unavailable"
        end
    elseif kind=="FontString" then
        local value=owner:Read(region,"GetText")
        if type(value)~="string" then grade,reason=1,"text-unreadable"
        elseif not value:find("%S") then return nil,"text-empty" end
    else return nil,"unsupported-region" end
    local ok,_,_,_,a=pcall(method(region,kind=="Texture" and "GetVertexColor" or "GetTextColor"),region)
    a=clean(a)
    if not ok or type(a)~="number" then grade,reason=1,"color-unreadable"
    elseif a<=0 then return nil,"transparent-color" end
    local l,b,r,t=Evidence.rect(owner,region)
    if not l then
        if b=="geometry-unreadable" then return math.huge,1,b end
        return nil,b
    end
    local x,y=owner.visualX,owner.visualY
    if not (x>=l and x<=r and y>=b and y<=t) then
        if not button then return nil,"outside-pointer" end
        local fl,fb,fr,ft=Evidence.rect(owner,button)
        if not fl then return nil,fb end
        l,b,r,t=math.max(l,fl),math.max(b,fb),math.min(r,fr),math.min(t,ft)
        if r<=l or t<=b then return nil,"button-content-outside" end
    end
    l,b,r,t=Evidence.clip(owner,frame,l,b,r,t)
    if not l then return nil,b end
    return (r-l)*(t-b),grade,reason
end
local function above(strata,level,layer,area,bs,bl,bd,ba,tie)
    return strata>bs or (strata==bs and (level>bl or (level==bl and
        (layer>bd or (layer==bd and (area<ba or (area==ba and tie)))))))
end
function Evidence.publish(owner,target,frame,area,grade,reason,strata,level,layer,native)
    if grade==1 then
        if not native then return end
        if not owner.visualUnknown or above(strata,level,layer,area,owner.unknownStrata,owner.unknownLevel,owner.unknownLayer,owner.unknownArea,false) then
            owner.visualUnknown,owner.unknownReason=target,reason
            owner.unknownStrata,owner.unknownLevel,owner.unknownLayer,owner.unknownArea=strata,level,layer,area
        end
    elseif not owner.visualBest or above(strata,level,layer,area,owner.visualStrata,owner.visualLevel,owner.visualLayer,owner.visualArea,owner.visualProvisional) then
        owner.visualBest,owner.visualBestFrame=target,frame
        owner.visualProvisional,owner.visualFromPrevious=nil,nil
        owner.visualStrata,owner.visualLevel,owner.visualLayer,owner.visualArea=strata,level,layer,area
    end
end
function Evidence.regions(owner,target,frame,scale,strata,level,native,ok,...)
    if not ok then return 0,"regions-unreadable" end
    local kind=owner:Read(target,"GetObjectType")
    local button=(kind=="Button" or kind=="CheckButton") and owner:Read(target,"IsMouseClickEnabled")==true
        and owner:HitRect(frame,scale) and frame or nil
    local best,bestReason=0,"no-visible-content"
    for i=1,math.min(select("#",...),32) do
        local region=clean(select(i,...))
        local area,grade,reason=Evidence.region(owner,region,frame,button)
        if area then
            if grade>best then best,bestReason=grade,reason end
            Evidence.publish(owner,target,frame,area,grade,reason,strata,level,layerOrder[owner:Read(region,"GetDrawLayer")] or 0,native)
        elseif best==0 then bestReason=grade end
    end
    return best,bestReason
end
local function considerObject(owner,object,native)
    owner.pickReason="no-visible-content"
    object=owner:CheckFocus(object)
    if not object then return owner:Reject("excluded") end
    local kind=owner:Read(object,"GetObjectType")
    local isRegion=kind=="Texture" or kind=="FontString"
    local frame=isRegion and owner:Read(object,"GetParent") or object
    local scale=frame and owner:VisualFrame(frame)
    if not scale then return end
    local strata=strataOrder[owner:Read(frame,"GetFrameStrata")] or 0
    local level=owner:Read(frame,"GetFrameLevel")
    if type(level)~="number" then return owner:Reject("level-unreadable") end
    local grade,reason
    if isRegion then grade,reason=Evidence.regions(owner,object,frame,scale,strata,level,native,true,object)
    else grade,reason=Evidence.regions(owner,object,frame,scale,strata,level,native,pcall(method(frame,"GetRegions"),frame)) end
    -- Native engine-managed containers cannot expose all drawn children to addons.
    -- Presence of their public protocol is evidence of managed content, not pixels.
    if grade==0 and native and method(object,"SetAuraProcessingPolicy") then
        local area=owner:HitRect(frame,scale)
        if area then
            grade,reason=1,"engine-content-unavailable"
            Evidence.publish(owner,object,frame,area,grade,reason,strata,level,0,true)
        end
    end
    owner.pickReason=grade==2 and nil or reason
end
-- One sweep owns all fallback candidates. Budget exhaustion yields the cursor,
-- not the answer: later objects must eventually be considered at a stationary pointer.
local function enqueue(pick,object)
    if not object or secret(object) or object==UIParent or object==WorldFrame or pick.seen[object] then return end
    if pick.tail>=512 then pick.capped=true;return end
    pick.seen[object]=true;pick.tail=pick.tail+1;pick.queue[pick.tail]=object
end
local function enqueueList(pick,ok,...)
    if not ok then pick.unreadable=true;return end
    for i=1,math.min(select("#",...),512) do enqueue(pick,clean(select(i,...))) end
    if select("#",...)>512 then pick.capped=true end
end
function M:ResetPicking()
    self.pick,self.lastPick,self.lastPickX,self.lastPickY=nil,nil,nil,nil
    self.selectionEvidence,self.selectionReason=nil,nil
    self:ResetVisual()
end
local function belongsToSweep(owner,pick,object)
    -- Descendants discovered in the previous sweep may not be queued yet in the
    -- new one. An admitted ancestor establishes membership, never visibility.
    for i=1,16 do
        if not object or object==UIParent or object==WorldFrame then return false end
        if pick.seen[object] then return true end
        object=owner:Read(object,"GetParent")
    end
    return false
end
function M:StackFocus(objects,preferred,frozen)
    self:ResetVisual()
    local ok,x,y
    if frozen and self.pick then ok,x,y=true,self.pick.x,self.pick.y
    else ok,x,y=pcall(GetCursorPosition) end
    if not ok or secret(x) or secret(y) or type(x)~="number" or type(y)~="number" then self:ResetPicking();return end
    self.visualX,self.visualY=x,y
    if preferred then considerObject(self,preferred,true) end
    if self.visualBest then
        local target=self.visualBest
        self.pick=nil;self.selectionEvidence,self.selectionReason=2,nil;self.lastPick,self.lastPickX,self.lastPickY=target,x,y
        self:ResetVisual();return target,nil,true
    end
    local rawReason=preferred and self.pickReason or nil
    local pick=self.pick
    -- Native highlight can alternate between empty overlays at one position.
    -- Finish the bounded sweep there; refresh its native seeds on the next sweep.
    if not pick or not pick.pending or pick.x~=x or pick.y~=y
        or (preferred and preferred~=pick.preferred and not belongsToSweep(self,pick,preferred)) then
        if not pick then pick={queue={},seen={},reasons={},native={}};self.pick=pick end
        for key in pairs(pick.queue) do pick.queue[key]=nil end
        for key in pairs(pick.seen) do pick.seen[key]=nil end
        for key in pairs(pick.reasons) do pick.reasons[key]=nil end
        for key in pairs(pick.native) do pick.native[key]=nil end
        pick.unverified=nil
        pick.x,pick.y,pick.preferred=x,y,preferred
        pick.head,pick.tail,pick.checked=1,0,0
        pick.capped,pick.unreadable=false,false
        pick.details,pick.detailsCapped=nil,nil
        pick.rawReason=rawReason
        -- Seed native identity and its ancestors, never the global roots. Children
        -- and regions are ordinary work items, not another depth-limited algorithm.
        local scope=preferred
        for i=1,16 do
            if not scope or not self:CheckFocus(scope) then break end
            enqueue(pick,scope);scope=self:Read(scope,"GetParent")
        end
        if preferred and pick.seen[preferred] then pick.native[preferred]=true end
        local snapshot=type(objects)=="function" and call(objects) or objects
        pick.supported=type(snapshot)=="table"
        if pick.supported then
            for i=1,math.min(#snapshot,512) do
                local item=clean(snapshot[i]);enqueue(pick,item)
                if item and pick.seen[item] then pick.native[item]=true end
            end
            if #snapshot>512 then pick.capped=true end
        end
        pick.seedTail=pick.tail
    end
    -- Publish progressively without flicker, but revalidate on every poll so a
    -- hidden, faded, clipped or moved winner cannot linger between sweep batches.
    if self.lastPickX==x and self.lastPickY==y and self.lastPick and belongsToSweep(self,pick,self.lastPick) then
        considerObject(self,self.lastPick,pick.native[self.lastPick])
        self.visualFromPrevious=self.visualBest~=nil
    end
    if pick.unverified then considerObject(self,pick.unverified,pick.native[pick.unverified]) end
    local started=debugprofilestop and debugprofilestop() or 0
    for i=1,128 do
        local object=pick.queue[pick.head]
        if not object then break end
        pick.head=pick.head+1;pick.checked=pick.checked+1
        self.visualProvisional=self.visualFromPrevious and pick.head-1<=pick.seedTail
        considerObject(self,object,pick.native[object])
        local reason=self.pickReason
        if reason then pick.reasons[reason]=(pick.reasons[reason] or 0)+1 end
        if pick.details and #pick.details<512 then
            pick.details[#pick.details+1]=text(self:Read(object,"GetDebugName")):sub(1,120).." | "..(reason or "visible")
                .." | "..text(self:Read(object,"GetSourceLocation")):sub(1,160)
        elseif pick.details then pick.detailsCapped=true end
        local kind=self:Read(object,"GetObjectType")
        if kind~="Texture" and kind~="FontString" and self:CheckFocus(object) then
            local scale=self:VisualFrame(object)
            if scale and self:HitRect(object,scale) then
                enqueueList(pick,pcall(method(object,"GetRegions"),object))
                enqueueList(pick,pcall(method(object,"GetChildren"),object))
            end
        end
        if debugprofilestop and debugprofilestop()-started>=0.75 then break end
    end
    pick.pending=pick.head<=pick.tail
    pick.unverified=self.visualUnknown
    local target=self.visualBest
    local grade,reason=target and 2,nil
    if not target and (not pick.pending or self.lastPick==self.visualUnknown) then target,grade,reason=self.visualUnknown,1,self.unknownReason end
    self.selectionEvidence,self.selectionReason=target and grade or nil,reason
    self.lastPick,self.lastPickX,self.lastPickY=target,x,y
    -- Keep only this bounded snapshot until the next sweep or Stop, so Shift
    -- can explain a just-completed miss without resampling over the popup.
    self:ResetVisual()
    return target,nil,pick.supported or preferred~=nil
end
function M:PickReport()
    local pick=self.pick
    if not pick then return "Picker: native selection passed" end
    local lines={"Picker: "..(pick.pending and "pending" or "complete"),
        "checked="..pick.checked.." queued="..pick.tail.." capped="..tostring(pick.capped),
        "native="..text(self:Read(pick.preferred,"GetDebugName")),"nativeFilter="..tostring(pick.rawReason)}
    lines[#lines+1]="evidence="..(self.selectionEvidence==2 and "verified" or self.selectionEvidence==1 and "unverified" or "none")
    if self.selectionReason then lines[#lines+1]="evidenceReason="..self.selectionReason end
    for reason,count in pairs(pick.reasons) do lines[#lines+1]=reason.."="..count end
    if pick.unreadable then lines[#lines+1]="Some child/region lists could not be read" end
    if pick.details then
        lines[#lines+1]="Frozen pointer: "..pick.x..", "..pick.y
        lines[#lines+1]="Candidate | filter | creation source"
        for _,detail in ipairs(pick.details) do lines[#lines+1]=detail end
        if pick.detailsCapped then lines[#lines+1]="Candidate details truncated at 512 entries" end
    end
    return table.concat(lines,"\n")
end
local function sampleNative(tooltip,root)
    tooltip:SetOwner(root,"ANCHOR_NONE")
    tooltip:SetParent(root)
    return tooltip:SetFrameStack(false,true,0)
end
function M:NativeFocus()
    if not self.stackRoot then
        self.stackRoot=CreateFrame("Frame",nil,UIParent)
        self.stackRoot:Hide();self.stackRoot:EnableMouse(false)
        self.stackTooltip=call(CreateFrame,"GameTooltip",nil,self.stackRoot,"SharedTooltipTemplate")
        if self.stackTooltip then self.stackTooltip:EnableMouse(false);self.stackTooltip:Hide() end
    end
    local tooltip=self.stackTooltip
    if not tooltip or not method(tooltip,"SetFrameStack") then return end
    -- A hidden parent also contains deferred third-party skinning or Show calls.
    -- Never use the player's GameTooltip/FrameStackTooltip or change their CVars.
    local outline=self.view and self.view.outline
    local restoreOutline=outline and self:Read(outline,"IsShown")
    if restoreOutline then outline:Hide() end
    local target=call(sampleNative,tooltip,self.stackRoot)
    tooltip:Hide();tooltip:ClearLines()
    if restoreOutline then outline:Show() end
    return target
end
function M:Focus()
    local foci=call(GetMouseFoci)
    -- Hovering our controls must not replace the inspected target with our UI.
    local fallback
    if type(foci)=="table" then
        for index=1,math.min(#foci,32) do
            local frame,own=self:CheckFocus(foci[index])
            if own then return nil,true end
            if not fallback and frame and self:Read(frame,"IsVisible")==true then
                local alpha=self:Read(frame,"GetEffectiveAlpha")
                if type(alpha)=="number" and alpha>0 then fallback=frame end
            end
        end
    end
    local target,own,supported=self:StackFocus(C_System and C_System.GetFrameStack,self:NativeFocus())
    if target or supported then return target,own end
    return fallback -- Legacy input-focus compatibility when native APIs are unavailable.
end
function M:UpdatePointer()
    if not self.running then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    self.view:SetPaused(IsShiftKeyDown and IsShiftKeyDown() or false)
    self.view:Place(self.target)
end
function M:Poll()
    if not self.running then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    self:UpdatePointer()
    if not self.running or self.view.copying then return end
    local target,own
    if self.view.paused and (self.target or self.view.hasDiagnostic) then
        if self.target or not self.pick or (self.pick.details and not self.pick.pending) then return end
        local pick=self.pick
        if not pick.details then
            -- Explicit diagnostic request: replay this bounded snapshot, including
            -- already-checked objects, while the user moves onto the copy button.
            pick.details={};pick.head=1;pick.checked=0;pick.pending=true
            for key in pairs(pick.reasons) do pick.reasons[key]=nil end
        end
        target=self:StackFocus(nil,pick.preferred,true)
    else target,own=self:Focus() end
    if own then self.view:Place(self.target);return end
    if target~=self.target or (target and self.data and (self.data.contentUnverified~=(self.selectionEvidence==1) or self.data.evidenceReason~=self.selectionReason)) or (not target and self.view.hasDiagnostic~=(self.pick and (self.pick.preferred~=nil or self.pick.checked>0) or false))
        or (not target and self.view.diagnosticPending~=(self.pick and self.pick.pending or false))
        or (not target and self.view.diagnosticReady~=(self.pick and self.pick.details~=nil and not self.pick.pending or false)) then
        self.target=target;self.data=target and self:Analyze(target) or nil
        if self.data then
            self.data.contentUnverified=self.selectionEvidence==1
            self.data.evidenceReason=self.selectionReason
        end
        self.view:Update(target,self.data)
    end
    self.view:Place(target)
end
function M:Schedule()
    local epoch=self.epoch
    self.timer=C_Timer.NewTimer(0.1,function()
        if not self.running or epoch~=self.epoch then return end
        self.timer=nil;self:Poll()
        if self.running and epoch==self.epoch then self:Schedule() end
    end)
end
function M:Stop()
    self.running=false;self.epoch=self.epoch+1
    if self.timer then self.timer:Cancel();self.timer=nil end
    self.target,self.data=nil,nil
    self:ResetPicking()
    if self.stackTooltip then self.stackTooltip:Hide();self.stackTooltip:ClearLines() end
    if self.view then self.view:Hide() end
end
function M:SuppressHoverTooltip(tooltip)
    if not self.running or (InCombatLockdown and InCombatLockdown()) then return end
    if self:Read(tooltip,"IsForbidden") then return end
    call(method(tooltip,"Hide"),tooltip)
end
function M:BeginTooltipSuppression()
    local tooltip=GameTooltip
    if not tooltip or self:Read(tooltip,"IsForbidden") then return end
    if self.hoverTooltip~=tooltip then
        self.hoverHideCallback=self.hoverHideCallback or function(shown) self:SuppressHoverTooltip(shown) end
        local ok,installed=pcall(method(tooltip,"HookScript"),tooltip,"OnShow",self.hoverHideCallback)
        if ok and installed~=false then self.hoverTooltip=tooltip end
    end
    -- Existing hover content is stale for inspection. Future real hover events
    -- rebuild it normally after Stop; never re-show old tooltip contents here.
    self:SuppressHoverTooltip(tooltip)
end
function M:Start()
    if not self.enabled then return {ok=false,message=L["请先启用插件识别来源"]} end
    if InCombatLockdown and InCombatLockdown() then return {ok=false,message=L["请在脱离战斗后识别插件"]} end
    self:Stop()
    self.view=self.view or _G.Lychee.UI.CreateAddonInspector(self)
    self.running=true
    self:BeginTooltipSuppression()
    self.view:Show();self:Poll();self:Schedule()
    return {ok=true,close=true}
end
function M:Parent()
    if not self.running or not self.target then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop();return end
    local parent=self:Read(self.target,"GetParent")
    if not parent or parent==UIParent or parent==WorldFrame or self:Read(parent,"IsForbidden") then return end
    local unverified=self.data and self.data.contentUnverified
    self.target=parent;self.data=self:Analyze(parent)
    self.data.contentUnverified=unverified;self.data.evidenceReason=unverified and "parent-source-only" or nil
    self.view:Update(parent,self.data)
end
function M:Report()
    local data=self.data
    if not data then return self:PickReport() end
    local lines={L["插件识别"],data.confidence.."："..data.title,L["框体："]..data.name,L["类型："]..data.kind,
        L["尺寸："]..data.size,L["层级："]..data.strata.." / "..tostring(data.level or "—"),L["创建位置："]..data.location,L["父级关联（不代表修改来源）："]}
    for _,parent in ipairs(data.parents) do lines[#lines+1]=parent end
    if data.truncated then lines[#lines+1]=L["父级信息已截断"] end
    if data.relatedSources then
        lines[#lines+1]=L["内部控件来源（不代表整个框体归属）："]
        for _,source in ipairs(data.relatedSources) do lines[#lines+1]=source.title.." · "..source.name.." · "..source.location end
    end
    if data.relatedTruncated then lines[#lines+1]=L["关联信息已截断"] end
    if data.contentUnverified then lines[#lines+1]=L["原生命中 · 内容无法验证"].." ("..tostring(data.evidenceReason)..")" end
    lines[#lines+1]=self:PickReport()
    return table.concat(lines,"\n"):sub(1,196608)
end
function M:SourceSetting()
    return call(C_CVar and C_CVar.GetCVar,"enableSourceLocationLookup")
end
function M:EnableSource()
    if not self.running or (InCombatLockdown and InCombatLockdown()) then return end
    if self:SourceSetting()==nil or not C_CVar or not C_CVar.SetCVar or not ReloadUI then return false end
    local ok=pcall(C_CVar.SetCVar,"enableSourceLocationLookup","1")
    if not ok or self:SourceSetting()~="1" then return false end
    self:Stop();ReloadUI();return true
end
function M:Init()
    if self.handle then return true end
    LycheeDB.optionalProviderDefaults=LycheeDB.optionalProviderDefaults or {}
    LycheeDB.disabledProviders=LycheeDB.disabledProviders or {}
    if not LycheeDB.optionalProviderDefaults[self.id] then
        LycheeDB.optionalProviderDefaults[self.id]=true;LycheeDB.disabledProviders[self.id]=true
    end
    self.handle=_G.Lychee:RegisterProvider({id=self.id,apiVersion=2,minApiRevision=2,i18n=L.resources,version="1.0.0",title=L["插件识别"],scope=I.Builtin.Support:Scope("builtin.addon-inspector"),
        entries={{id="inspect",title=L["插件识别"],kindTitle=L["工具"],subtitle=L["指向界面，查看来自哪个插件"],
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\addon-inspector.tga",
            aliases={"这是什么插件","识别插件","框体","界面来源","wtf","inspect","frame"},actions={"inspect"}}},
        actions={inspect={title=L["开始识别"],run=function() return M:Start() end}},
        onEnable=function() M.enabled=true;return function(reason)
            M.enabled=false;M:Stop();if reason=="unregister" then M.handle=nil end
        end end})
    return self.handle~=nil
end
