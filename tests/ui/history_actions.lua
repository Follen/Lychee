local env=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=LycheeInternal
local now,timers=0,{}
GetTime=function() return now end;GetTimePreciseSec=GetTime
C_Timer={NewTimer=function(delay,fn) local t={Cancel=function(self) self.cancelled=true end};timers[#timers+1]=t;return t end}
local english=GetLocale()=="enUS" or GetLocale()=="enGB"
local source=english and "Settings" or "设置"
local openTitle=english and "Open and locate" or "打开并定位"
local adjustTitle=english and "Adjust directly" or "直接调整"
local runs={}
I.Registry:SetReady(true)
local handle=assert(Lychee:RegisterProvider({id="history.actions",apiVersion="1.0.0",version="1",title=source,
 actions={adjust={title=adjustTitle,run=function() runs[#runs+1]="adjust";return {ok=true} end},
 open={title=openTitle,run=function() runs[#runs+1]="open";return {ok=true} end}},
 entries={{id="same",title="Same name",kindTitle=source,primaryActionID="adjust",actions={"adjust","open"}}}}))
local item=assert(I.Providers:Resolve({providerID="history.actions",entryID="same"},{}))
local palette=Lychee.UI.Palette:Create();assert(palette:Show())
local function rowFor(value)
 local row=CreateFrame("Button",nil,palette.frame)
 row.item,row.session,row.generation,row.extensionID=value,palette.session,palette.generation,value.providerID
 return row
end
assert(I.ResultActionExecutor:Execute(rowFor(item),"open"))
local secondary=assert(I.UserPreferences:GetRecent()[1])
local restored=assert(I.UserPreferences:Resolve(secondary))
assert(restored.interaction.primaryActionID=="open","history replay switched the selected secondary action to default")
assert(I.ResultActionExecutor:ExecutePrimary(rowFor(restored)))
assert(runs[2]=="open","history click executed the wrong action")
assert(#I.UserPreferences:GetRecent()==1,"same action replay duplicated history")
assert(I.ResultActionExecutor:ExecutePrimary(rowFor(item)))
assert(#I.UserPreferences:GetRecent()==2,"different actions on one entry merged")
palette:MarkHomeDirty()
local found={}
for _,section in ipairs(palette.homeView.sections) do
 if section.recentRef then found[section.meta]=true;assert(section.title=="Same name","history changed the entry title") end
end
assert(found[source.." · "..openTitle] and found[source.." · "..adjustTitle],"history metadata does not distinguish selected actions")
assert(item.interaction.primaryActionID=="adjust","restoring a secondary action changed the search result")
local missing={providerID="history.actions",entryID="same",actionID="removed"}
assert(not I.UserPreferences:Resolve(missing),"missing saved action fell back to default")
assert(I.Search.RuntimeIdentity:ReferenceKey(secondary)~=I.Search.RuntimeIdentity:ReferenceKey(item.ref),"action identity collides with default")
assert(I.UserPreferences:Pin(restored))
assert(I.UserPreferences:GetPins()[1].actionID=="open","pin lost selected action")
assert(I.Search.Personalization:Remember("selected action",restored))
assert(I.Search.Personalization:Preferred({normalized="selected action"}).actionID=="open","search memory lost selected action")
-- Parameterized results also have ordinary secondary entry actions.
local callback,mode="", "sync"
local function invocation(n) return {kind="invocation",product="retail",providerID="history.params",actionID="set",actionVersion=1,target={version=1,key={id="target"}},args={n=n}} end
local parameterized=assert(Lychee:RegisterProvider({id="history.params",apiVersion="1.0.0",version="1",title=source,
 resolveTarget=function(target) return {status="ready",target=target,identity="target"} end,
 actions={set={title="Set",actionVersion=1,schema={n={type="integer",required=true}},run=function(_,_,reply)
  if mode=="sync" then return {status="succeeded",message="Provider success"} end
  callback=reply;return function() return true end
 end},adjust={title=adjustTitle,run=function() return {ok=true,message="Opened controls"} end}},
 entries={{id="n30",title="Set 30",invocation=invocation(30),actions={"set","adjust"}},
 {id="n50",title="Set 50",invocation=invocation(50),actions={"set","adjust"}}}}))
local thirty=assert(I.Providers:Resolve({providerID="history.params",entryID="n30"},{}))
local fifty=assert(I.Providers:Resolve({providerID="history.params",entryID="n50"},{}))
assert(I.ResultActionExecutor:Execute(rowFor(thirty),"adjust"))
local adjustment=I.UserPreferences:GetRecent()[1]
assert(not adjustment.kind and adjustment.actionID=="adjust","opening controls incorrectly saved a set Invocation")
local controls=assert(I.UserPreferences:Resolve(adjustment))
assert(controls.interaction.primaryActionID=="adjust" and not controls.ref.kind,"controls history replays a write")
assert(thirty.ref.kind=="invocation" and thirty.ref.actionID=="set","history restoration mutated the original Invocation")
assert(palette:ActivateRow(rowFor(thirty)))
assert(palette.status:GetText()=="Provider success","Provider message not used")
assert(palette:ActivateRow(rowFor(fifty)))
local values={}
for _,ref in ipairs(I.UserPreferences:GetRecent()) do if ref.kind=="invocation" and ref.providerID=="history.params" then values[ref.args.n]=true end end
assert(values[30] and values[50],"different arguments merged")
local recentDB=I.CharacterStore:Palette()
local originalRecent=recentDB.recent
recentDB.recent={{providerID="history.params",entryID="n30"},invocation(30),invocation(50)}
palette:MarkHomeDirty()
local unique=0
for _,section in ipairs(palette.homeView.sections) do if section.recentRef then unique=unique+1 end end
assert(unique==2,"equivalent restored references duplicated the same history action")
assert(#recentDB.recent==3,"display deduplication rewrote old saved references")
recentDB.recent=originalRecent;palette:MarkHomeDirty()
palette:SetStatus("home");assert(palette.status:GetText()=="Provider success","home refresh erased feedback")
local count=#I.UserPreferences:GetRecent()
mode="async"
local pending=assert(palette:ActivateRow(rowFor(thirty)))
assert(pending.pending and palette.status:GetText():find(english and "Working" or "正在执行",1,true),"pending reported success")
assert(#I.UserPreferences:GetRecent()==count,"pending added history")
callback({status="failed",code="ACTION_FAILED",message="Provider failure"})
assert(palette.status:GetText()=="Provider failure" and #I.UserPreferences:GetRecent()==count,"failed outcome/history mismatch")
pending=assert(palette:ActivateRow(rowFor(thirty)));assert(pending.operation:Cancel())
assert(palette.status:GetText()==(english and "Cancelled" or "已取消"),"cancelled outcome not shown")
assert(#I.UserPreferences:GetRecent()==count,"cancel added history")
assert(palette:ActivateRow(rowFor(thirty)))
local oldCallback=callback
local success=I.ResultActionExecutor:Execute(rowFor(item),"open");palette:ReportActionResult(success)
local latestFeedback=palette.status:GetText()
oldCallback({status="succeeded",message="Late completion"})
assert(palette.status:GetText()==latestFeedback,"earlier completion overwrote newer action feedback")
palette:SetQueryMode("")
assert(palette.status:GetText()~=latestFeedback,"navigation retained stale action feedback")
assert(palette:ActivateRow(rowFor(thirty)))
callback({status="indeterminate",code="UNCONFIRMED",message="Misleading success"})
assert(palette.status:GetText():find(english and "unconfirmed" or "尚未确认",1,true),"indeterminate outcome presented as failure/success")
palette:Hide("reopen");assert(palette:Show())
assert(not palette.status:GetText():find(english and "unconfirmed" or "尚未确认",1,true),"reopen retained old feedback")
parameterized:Unregister()
handle:Unregister()
palette:Hide("done")
print("History actions PASS: selected action replay, distinct references, source/action metadata and snapshot isolation")
