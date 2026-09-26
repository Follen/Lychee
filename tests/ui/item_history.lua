local env=assert(loadfile("tests/support/palette.lua"))(arg[1])
local I=LycheeInternal
local clock,timers=0,{}
GetTime=function() return clock end;GetTimePreciseSec=GetTime
C_Timer={NewTimer=function(delay,fn) local timer={delay=delay,callback=fn,Cancel=function(self) self.cancelled=true end};timers[#timers+1]=timer;return timer end}
C_Item={GetItemCount=function() return 1 end,GetItemSpell=function() return "Hearthstone",8690 end}
GetItemSpell=C_Item.GetItemSpell
I.Registry:SetReady(true)
local handle=assert(Lychee:RegisterProvider({id="history.item",apiVersion="1.0.0",version="1",title="Bags",
 actions={locate={title="Locate in bags",run=function() return {ok=true} end}},
 entries={{id="item:6948",title="Hearthstone",primaryActionID="use",actions={{id="use",title="Use item",kind="secure-item",itemID=6948},"locate"}}}}))
local palette=Lychee.UI.Palette:Create();assert(palette:Show())
local function resolve() return assert(I.Providers:Resolve({providerID="history.item",entryID="item:6948"},{})) end
local function rowFor(value)
 local row=CreateFrame("Button",nil,palette.frame)
 row.item,row.session,row.generation,row.extensionID=value,palette.session,palette.generation,value.providerID
 return row
end
local item=resolve()
assert(I.ResultActionExecutor:Execute(rowFor(item),"locate"))
assert(I.UserPreferences:GetRecent()[1].actionID=="locate")
item=resolve()
local row=rowFor(item)
local broker=palette:GetSecureBroker()
local button=assert(broker:Prepare(item.interaction.actions[1],{controller=palette,row=row,item=item,session=row.session,generation=row.generation,extensionID=row.extensionID}))
local function event(name,...) if broker.eventFrame.events and broker.eventFrame.events[name] then broker.eventFrame:GetScript("OnEvent")(broker.eventFrame,name,...) end end
button:GetScript("OnMouseDown")(button,"LeftButton")
button:GetScript("PreClick")(button)
event("UNIT_SPELLCAST_SENT","player","", "Cast-1",8690)
button:GetScript("PostClick")(button,"LeftButton")
assert(I.UserPreferences:GetRecent()[1].actionID=="locate","a click attempt is not a successful use")
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-1",8690)
local latest=assert(I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]))
assert(latest.interaction.primaryActionID=="use","after successful item use, history still replays Locate in bags")
assert(not next(broker.eventFrame.events),"finished item attempt must stop observing events")
local function click(guid,instant)
 assert(palette:Show())
 local fresh=resolve();local target=rowFor(fresh)
 local btn=assert(broker:Prepare(fresh.interaction.actions[1],{controller=palette,row=target,item=fresh,session=target.session,generation=target.generation,extensionID=target.extensionID}))
 btn:GetScript("OnMouseDown")(btn,"LeftButton");btn:GetScript("PreClick")(btn)
 event("UNIT_SPELLCAST_SENT","player","",guid,8690)
 if instant then event("UNIT_SPELLCAST_SUCCEEDED","player",guid,8690) end
 btn:GetScript("PostClick")(btn,"LeftButton")
 assert(not palette.visible and not btn.busy,"item click still closes immediately and releases secure attributes")
 return btn
end
local function locateFirst()
 assert(palette:Show());assert(I.ResultActionExecutor:Execute(rowFor(resolve()),"locate"))
 assert(I.UserPreferences:GetRecent()[1].actionID=="locate")
end
local function located() assert(I.UserPreferences:GetRecent()[1].actionID=="locate","unconfirmed use changed history") end
locateFirst();click("Cast-instant",true)
assert(I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]).interaction.primaryActionID=="use")
assert(not broker.pendingItem and not broker.itemTimer and not next(broker.eventFrame.events))
for _,failure in ipairs({"UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED"}) do
 locateFirst();click("Cast-failed");event(failure,"player","Cast-failed",8690);located()
 assert(not broker.pendingItem and not broker.itemTimer and not next(broker.eventFrame.events))
end
locateFirst();click("Cast-match")
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-other",8690);located()
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-match",999);located()
event("UNIT_SPELLCAST_SUCCEEDED","party1","Cast-match",8690);located()
assert(broker.pendingItem)
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-match",8690)
assert(I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]).interaction.primaryActionID=="use")
locateFirst();click("Cast-timeout");local expired=broker.itemTimer;assert(expired.delay==30);expired.callback();located()
assert(expired.cancelled and not broker.pendingItem and not next(broker.eventFrame.events))
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-timeout",8690);located()
click("Cast-old");local oldTimer=broker.itemTimer
click("Cast-new");oldTimer.callback();assert(broker.pendingItem.guid=="Cast-new")
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-old",8690);located()
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-new",8690)
assert(not broker.pendingItem and oldTimer.cancelled)
locateFirst();click("Cast-unrelated")
event("UNIT_SPELLCAST_SENT","player","","Cast-unrelated2",999)
assert(not broker.pendingItem and not next(broker.eventFrame.events));located()
local getSpell=C_Item.GetItemSpell
C_Item.GetItemSpell=function() return nil end
click("Cast-unknown");event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-unknown",8690);located()
assert(not broker.pendingItem and not next(broker.eventFrame.events));C_Item.GetItemSpell=getSpell
-- Reopening after the click must neither cancel confirmation nor close the new UI.
locateFirst();click("Cast-reopen");assert(palette:Show())
event("UNIT_SPELLCAST_SUCCEEDED","player","Cast-reopen",8690)
assert(palette.visible and I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]).interaction.primaryActionID=="use")
click("Cast-destroy");broker:Destroy()
assert(not broker.pendingItem and not broker.itemTimer and not next(broker.eventFrame.events))
handle:Unregister();palette:Hide("done",true)
print("Item history PASS: locate, fresh search, secure use confirmed, latest history replays use")
