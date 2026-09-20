local count,calls,scripts=0,0,0
local locked=false
function InCombatLockdown() return locked end
local M={}
local function mutate() assert(not locked,"native mutation in combat");calls=calls+1 end
function M:SetScript(key,fn) mutate();scripts=scripts+1;self.scripts[key]=fn end
function M:GetScript(key) return self.scripts[key] end
function M:SetText(value) mutate();if self.failText then self.failText=false;error("setter failure") end;self.text=value;local fn=self.scripts.OnTextChanged;if fn then fn(self,false) end end
function M:GetText() return self.text end
function M:Show() mutate();self.shown=true end
function M:Hide() mutate();self.shown=false;local fn=self.scripts.OnHide;if fn then fn(self) end end
function M:IsShown() return self.shown end
function M:IsMouseOver() return false end
function M:GetParent() return self.parent end
function M:GetWidth() return self.width or 400 end
function M:GetHeight() return self.height or 300 end
function M:SetWidth(value) mutate();self.width=value end
function M:SetHeight(value) mutate();self.height=value end
function M:SetSize(w,h) mutate();self.width,self.height=w,h end
function M:GetFrameLevel() return 1 end
function M:ClearFocus() mutate();self.focus=false end
for _,name in ipairs({"SetAllPoints","SetPoint","ClearAllPoints","SetAlpha","SetFont","SetTextColor","SetColorTexture","SetTexture","SetJustifyH","SetJustifyV","SetWordWrap","SetMaxLines","SetMaxBytes","SetMultiLine","SetAutoFocus","SetTextInsets","SetFrameLevel","SetTexCoord","SetEnabled","Enable","Disable","SetRotation"}) do M[name]=mutate end
function CreateFrame(kind,name,parent)
    mutate();count=count+1
    return setmetatable({parent=parent,scripts={},shown=true},{__index=M})
end
function M:CreateFontString() return CreateFrame("FontString",nil,self) end
function M:CreateTexture() return CreateFrame("Texture",nil,self) end
Lychee={UI={Theme={Metrics={switchWidth=32,switchHeight=18}}}}
local theme=Lychee.UI.Theme
function theme:SetColorTexture(frame) frame:SetColorTexture();return true end
function theme:SetTextColor(frame) frame:SetTextColor();return true end
function theme:SetFont(frame) frame:SetFont() end
function theme:CreateRoundedSurface() return {SetColor=function() end} end
function theme:CreateSurface() end
function theme:ApplySurface() end
dofile("addon/Lychee/UI/Components.lua")
dofile("addon/Lychee/UI/Runtime.lua")
local UI=Lychee.UI
local parent=CreateFrame("Frame")
local activated,edited=0,0
local definition={type="Fragment",children={
    {type="Text",key="title",props={role="body"},bind={text="title"}},
    {type="Button",key="button",props={text="Go",role="body"},bind={enabled="enabled"},on={click=function(props) activated=props.id end}},
    {type="Input",key="input",bind={text="value"},on={change=function() edited=edited+1 end}},
    {type="Text",key="state",bind={text=function(_,state) return state.status end}},
}}
local before=count
local view=assert(UI:Create(parent,definition))
assert(count==before,"lazy Create must not construct native objects")
local props={id=1,title="First",enabled=true,value="input"}
assert(view:Update(props));assert(view:Get("title"):GetText()=="First" and edited==0)
local high=count
local callBase,scriptBase=calls,scripts
collectgarbage("collect");collectgarbage("stop")
local memory=collectgarbage("count")
for _=1,1000 do assert(view:Update(props)) end
local allocated=collectgarbage("count")-memory
collectgarbage("restart")
assert(allocated<64,"unchanged Update allocation budget exceeded")
assert(count==high and calls==callBase and scripts==scriptBase,"unchanged Update must do no native work")
props.title="Mutated";assert(view:Update(props));assert(view:Get("title"):GetText()=="Mutated")
assert(view:SetState("status","ready"));assert(view:Get("state"):GetText()=="ready")
local button=view:Get("button")
button.scripts.OnMouseDown(button);props.id=2;assert(view:Update(props));button.scripts.OnClick(button)
assert(activated==0,"old press cannot activate new props")
button.scripts.OnMouseDown(button);button.scripts.OnClick(button);assert(activated==2)
button.scripts.OnMouseDown(button);view:Release("close");assert(view:Update(props));button.scripts.OnClick(button)
assert(activated==2,"release/reopen invalidates old press")
local cancels=0;assert(view:Own("work",function() cancels=cancels+1 end))
view:Get("input").focus=true
assert(view:Release("close"));assert(cancels==1 and not view.active and next(view.props)==nil and next(view.state)==nil)
assert(view:Get("input"):GetText()=="" and not view:Get("input").focus)
assert(view:Release());assert(cancels==1)
for _=1,100 do assert(view:Update(props));view:Release() end
assert(count==high,"warm mount must reuse the native tree")
locked=true;local nativeCalls=calls
assert(select(2,view:Update(props))=="UI_COMBAT")
view:Release("combat");assert(calls==nativeCalls)
locked=false;assert(view:Update(props))
view:Get("title").failText=true;props.title="Retry"
assert(not view:Update(props));assert(view:Update(props));assert(view:Get("title"):GetText()=="Retry","failed setter must retry")
local busyResult
local reentrant={type="Text",update=function(_,_,v) busyResult=select(2,v:Update({})) end}
local re=assert(UI:Create(parent,reentrant));assert(re:Update({}));assert(busyResult=="UI_BUSY")
re.definition.update=function(_,_,v) v:Release("inside") end
assert(select(2,re:Update({}))=="UI_CANCELLED" and not re.active)
local nativeCreates,nativeUpdates,nativeReleases=0,0,0
local nd={type="Native",key="native",create=function(p)
    nativeCreates=nativeCreates+1
    return {frame=CreateFrame("Frame",nil,p),Update=function(self,p) nativeUpdates=nativeUpdates+1;self.record=p.record end,
        Release=function(self) nativeReleases=nativeReleases+1;self.record=nil end}
end}
local nv=assert(UI:Create(parent,nd));assert(nv:Update({record={}}));nv:Release();assert(nv:Update({record={}}));nv:Release()
assert(nativeCreates==1 and nativeUpdates==2 and nativeReleases==2 and nv:GetComponent("native").record==nil)
local broken=assert(UI:Create(parent,{type="Native",create=function() error("factory") end}))
assert(not broken:Update({}) and not broken.active)
assert(not UI:Create(parent,{type="Nope"}))
assert(not UI:Create(parent,{type="Fragment",children={{type="Text",key="x"},{type="Text",key="x"}}}))
local factory=UI:AsView(definition);local panel=factory.create({contentFrame=parent})
panel:Mount({contentFrame=parent},props);panel:Unmount("close");panel:Dispose("close")
assert(factory.create({contentFrame=parent})==panel);panel:Mount({contentFrame=parent},props);panel:Update(props);panel:Unmount("close")
local intrinsic,eventCalls,eventView=0,0
local eventDef={type="Native",create=function(p)
    local frame=CreateFrame("Frame",nil,p)
    frame:SetScript("OnEnter",function()
        intrinsic=intrinsic+1
        if eventView.active then eventView:Release();assert(eventView:Update({id=2})) end
    end)
    return {frame=frame}
end,on={enter=function() eventCalls=eventCalls+1 end}}
eventView=assert(UI:Create(parent,eventDef));assert(eventView:Update({id=1}))
local eventFrame=eventView.nodes[1].frame
eventFrame.scripts.OnEnter(eventFrame)
assert(eventCalls==0 and eventView.props.id==2,"preexisting script rebind cancels original event")
eventView:Release();eventFrame.scripts.OnEnter(eventFrame)
assert(intrinsic==2 and eventCalls==0,"inactive intrinsic cleanup remains callable")
local partialFrame,partialReleases
partialReleases=0
local partial=assert(UI:Create(parent,{type="Fragment",children={
    {type="Native",create=function(p)
        partialFrame=CreateFrame("Frame",nil,p)
        return {frame=partialFrame,Release=function() partialReleases=partialReleases+1 end}
    end},
    {type="Native",create=function() error("second child") end},
}}))
assert(not partial:Update({}) and partialReleases==1 and not partialFrame.shown,"partial construction releases already configured siblings")
local releaseCalls=0
local cleanup=assert(UI:Create(parent,{type="Text",release=function(_,v) releaseCalls=releaseCalls+1;v:Release("reentry") end}))
assert(cleanup:Update({}));cleanup:Release();local releasedGeneration=cleanup.generation;cleanup:Release()
assert(releaseCalls==1 and cleanup.generation==releasedGeneration and cleanup.cancelReason==nil,"release is idempotent despite cleanup reentry")
assert(cleanup:Update({}),"cleanup reentry cannot poison next mount")
local cancelledNew=0
assert(cleanup:Own("work",function() cleanup:Release("cancel reentry") end))
local owned,why=cleanup:Own("work",function() cancelledNew=cancelledNew+1 end)
assert(not owned and why=="UI_CANCELLED" and cancelledNew==1 and next(cleanup.tasks)==nil,"replacement cancellation reentry cannot retain task or report success")
assert(cleanup:Update({}));assert(select(2,cleanup:SetState(nil,true))=="UI_STATE" and not cleanup.busy)
local shared={type="Text"}
local badCount=count
assert(not UI:Create(parent,{type="Fragment",children={shared,shared}}),"same anonymous definition cannot alias different tree positions")
assert(not UI:Create(parent,{type="Text",props={misspelled=true}}))
assert(not UI:Create(parent,{type="Text",bind={unknown="value"}}))
assert(count==badCount,"invalid definitions fail before constructing native objects")
local staticInput=assert(UI:Create(parent,{type="Input",key="field",props={text="Default"}}))
assert(staticInput:Update({}));staticInput:Release();assert(staticInput:Get("field"):GetText()=="")
assert(staticInput:Update({}));assert(staticInput:Get("field"):GetText()=="Default","static input default restored after release")
local controlledInput=assert(UI:Create(parent,{type="Input",key="field",bind={text="value"}}))
local controlledProps={value="owned"};assert(controlledInput:Update(controlledProps))
controlledInput:Get("field"):SetText("user typed")
assert(controlledInput:Update(controlledProps));assert(controlledInput:Get("field"):GetText()=="owned","same controlled prop corrects native user edits")
-- Use the actual cancellation implementation; only native AnimationGroup is a
-- stand-in. Stopping it is allowed here, setters still assert outside combat.
dofile("addon/Lychee/UI/Motion.lua")
local stopping=0
local animView=assert(UI:Create(parent,{type="Button",key="button",props={text="Animated"}}))
assert(animView:Update({}))
local animatedFrame=animView:Get("button")
local animatedLabel=animView:GetComponent("button").label
local function animated(region)
    local state={playing=true,from=0,to=1,finished=function() error("released callback") end,
        alpha={GetSmoothProgress=function() return 0.5 end},group={Stop=function() stopping=stopping+1 end}}
    region._lycheeMotion=state
    return state
end
local frameMotion,labelMotion=animated(animatedFrame),animated(animatedLabel)
locked=true;local beforeCancel=calls;animView:Release("combat")
assert(calls==beforeCancel and stopping==2 and not frameMotion.playing and not labelMotion.playing
    and frameMotion.finished==nil and labelMotion.finished==nil,"combat release stops native animation without geometry/alpha/hide setters")
locked=false
local invalidBefore=count
for _=1,3 do assert(not UI:Create(parent,{type="Button",props={width="invalid"}})) end
assert(not UI:Create(parent,{type="Text",props={alpha=0/0}}))
assert(not UI:Create(parent,{type="Text",props={role=123}}))
assert(not UI:Create(parent,{type="Text",props={point={"TOP",nil,"TOP","invalid",0}}}))
assert(count==invalidBefore,"invalid static dimensions/font/points must create zero native objects")
local invalidBinding=assert(UI:Create(parent,{type="Button",bind={width="width"}}))
for _=1,3 do assert(not invalidBinding:Update({width="invalid"})) end
assert(count==invalidBefore,"invalid dynamic dimensions must be rejected before construction")
local sizeSetter=M.SetSize
M.SetSize=function() error("native size rejected") end
local failedConstruction=assert(UI:Create(parent,{type="Button",props={width=100,height=30}}))
assert(not failedConstruction:Update({}))
local failedCount=count
M.SetSize=sizeSetter
for _=1,3 do
    local ok,err=failedConstruction:Update({})
    assert(not ok and string.find(err,"UI_BUILD_FAILED",1,true))
end
assert(failedCount>invalidBefore and count==failedCount,"partial builtin factory failure cannot repeatedly allocate inaccessible Frames")
print(string.format("UI runtime PASS lazy/reuse/props/state/events/identity/release/combat/errors/AsView; 1000 unchanged updates %.2f KiB",allocated))
