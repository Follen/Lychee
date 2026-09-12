local frames,textures,timers={},0,{}
local combat,visible,present=false,true,true
function InCombatLockdown() return combat end
UIParent={}
local function noop() end
function CreateFrame()
    local f={scripts={},events={},attrs={},shown=false}
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:RegisterEvent(e) self.events[e]=true end
    f.RegisterUnitEvent=f.RegisterEvent
    function f:UnregisterAllEvents() self.events={} end
    function f:SetAttribute(k,v) self.attrs[k]=v end
    function f:Show() self.shown=true end
    function f:Hide()
        local was=self.shown;self.shown=false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetParent(p) self.parent=p end
    function f:SetAllPoints(p) self.anchor=p end
    function f:ClearAllPoints() self.anchor=nil end
    function f:CreateTexture()
        textures=textures+1
        return {SetPoint=noop,SetColorTexture=noop,SetHeight=noop,SetWidth=noop,SetAllPoints=noop}
    end
    f.EnableMouse=noop;f.SetFrameLevel=noop;f.SetSize=noop;f.RegisterForClicks=noop
    frames[#frames+1]=f;return f
end
C_Timer={NewTimer=function(_,fn)
    local t={callback=fn,Cancel=function(self) self.cancelled=true end}
    timers[#timers+1]=t;return t
end}
local slot=2
C_Container={GetContainerNumSlots=function(b) return b==0 and 4 or 0 end,
    GetContainerItemID=function(_,s) return present and s==slot and 123 or 999 end,
    GetContainerItemInfo=function(_,s) return {itemID=s==slot and 123 or 999,itemName="测试物品",stackCount=1} end,
    SetItemSearch=function(text) assert(text=="", "locating must never leave a global name filter") end}
function OpenAllBags() end
local bagButton={IsVisible=function() return visible end,GetFrameLevel=function() return 3 end}
local locatedSlot
function ContainerFrameUtil_GetItemButtonAndContainer(_,s) locatedSlot=s;return bagButton end
LycheeInternal={Builtin={CatalogProvider={New=function(_,id,title,events,build,actions)
    return {build=build,actions=actions}
end}}}
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "fixture", 120100 end
-- Exclude the shared bootstrap frame from this isolated feature cost fixture.
local featureCreateFrame=CreateFrame
CreateFrame=nil
dofile("package/Lychee/".."Bootstrap.lua");dofile("package/Lychee/Core/CharacterStore.lua")
CreateFrame=featureCreateFrame
dofile("package/Lychee/".."Builtin/Definitions.lua")
dofile("package/Lychee/".."Builtin/Shared/Support.lua")
dofile("package/Lychee/".."Core/ProviderLocales.lua")
dofile("package/Lychee/".."Builtin/Achievements/Locales.lua")
dofile("package/Lychee/".."Builtin/AddonInspector/Locales.lua")
dofile("package/Lychee/".."Builtin/Bags/Locales.lua")
dofile("package/Lychee/".."Builtin/BlizzardSettings/Locales.lua")
dofile("package/Lychee/".."Builtin/Bosses/Locales.lua")
dofile("package/Lychee/".."Builtin/Crests/Locales.lua")
dofile("package/Lychee/".."Builtin/EquipmentSets/Locales.lua")
dofile("package/Lychee/".."Builtin/GameMenus/Locales.lua")
dofile("package/Lychee/".."Builtin/GreatVault/Locales.lua")
dofile("package/Lychee/".."Builtin/Keystones/Locales.lua")
dofile("package/Lychee/".."Builtin/Mounts/Locales.lua")
dofile("package/Lychee/".."Builtin/PlayerSpells/Locales.lua")
dofile("package/Lychee/".."Builtin/TalentLoadouts/Locales.lua")
dofile("package/Lychee/".."Search/RuntimeIdentity.lua")
dofile('package/Lychee/Builtin/Bags/Provider.lua')
local bags=LycheeInternal.Builtin.Bags
assert(#frames==0 and #timers==0)
local entry={payload={itemID=123}}
local records={};bags.build(bags,function(r) records[#records+1]=r end,noop)
assert(records[1].actions[1].kind=='secure-item' and records[1].actions[2]=='locate')
assert(bags.actions.locate.run(entry).ok and locatedSlot==2)
local glow=frames[1]
assert(glow.shown and textures==5 and glow.anchor==bagButton)
slot=4;assert(bags.actions.locate.run(entry).ok and locatedSlot==4)
assert(timers[1].cancelled and #frames==1)
glow.scripts.OnEvent(glow,'BAG_UPDATE_DELAYED')
assert(not glow.shown and not next(glow.events) and not glow.anchor)
assert(bags.actions.locate.run(entry).ok)
glow:Hide();assert(not next(glow.events) and timers[#timers].cancelled)
assert(bags.actions.locate.run(entry).ok)
timers[#timers].callback();assert(not glow.shown and not next(glow.events))
combat=true;assert(not bags.actions.locate.run(entry).ok);combat=false
visible=false;assert(not bags.actions.locate.run(entry).ok and not glow.shown);visible=true
present=false;assert(not bags.actions.locate.run(entry).ok);present=true
-- Adapter fixtures model the versioned source structures, not global frame names.
local getter=ContainerFrameUtil_GetItemButtonAndContainer
ContainerFrameUtil_GetItemButtonAndContainer=function() error("custom bags must not select hidden Blizzard buttons") end
local custom={IsVisible=function() return true end,GetFrameLevel=function() return 3 end,GetID=function() return slot end}
local count=0
NDui_Backpack={IsVisible=function() return true end,GetButton=function(_,b,s) assert(b==0 and s==slot);count=count+1;return custom end}
assert(bags.actions.locate.run(entry).ok and glow.anchor==custom and count==1)
NDui_Backpack=nil
local box={GetText=function() return "old search" end,SetText=function(_,text) assert(text=="");count=count+1 end}
local frame={IsVisible=function() return true end,Bags={[0]={[slot]=custom}},editBox=box}
ElvUI={{GetModule=function(_,name) assert(name=="Bags");return {BagFrame=frame} end}}
assert(bags.actions.locate.run(entry).ok and glow.anchor==custom)
ElvUI=nil
local scroll
custom.GetTop=function() return 100 end
local parent={IsVisible=function() return true end,GetID=function() return 0 end,GetChildren=function() return custom end}
EUI_Bags={IsVisible=function() return true end,_searchBox=box,
    SetSelectedView=function(_,view) assert(view==0) end,RefreshInventory=function() count=count+1 end,
    _scrollChild={GetChildren=function() return parent end},
    _scrollFrame={GetTop=function() return 500 end,GetVerticalScroll=function() return 0 end,
        GetVerticalScrollRange=function() return 900 end,SetVerticalScroll=function(_,value) scroll=value end}}
assert(bags.actions.locate.run(entry).ok and glow.anchor==custom and scroll==392)
bags:onStop();assert(not glow.shown and not next(glow.events))
EUI_Bags=nil;ContainerFrameUtil_GetItemButtonAndContainer=getter
print("Bag adapters PASS Blizzard / ElvUI / NDui / Ellesmere, no persistent name filter")
timers={};collectgarbage('collect');local memory=collectgarbage('count');collectgarbage('stop')
local started=os.clock()
for n=1,100 do assert(bags.actions.locate.run(entry).ok);bags:onStop() end
local elapsed=(os.clock()-started)*1000
local allocated=collectgarbage('count')-memory
timers={};collectgarbage('restart');collectgarbage('collect');local growth=collectgarbage('count')-memory
assert(#frames==1 and textures==5 and allocated<256 and growth<32 and not glow.shown and not next(glow.events))
print(string.format('Bag highlight PASS frames=1 textures=5 locate100_ms=%.2f allocated_KiB=%.1f retained_growth_KiB=%.1f idle_work=0',elapsed,allocated,growth))

Lychee={Secure={}}
local valid=true
local palette={ValidateRowAction=function() return valid end,Hide=noop,TouchRecent=noop}
LycheeInternal.Host={PaletteController=palette}
C_Item={GetItemCount=function() return present and 1 or 0 end}
function IsPlayerSpell() return true end
dofile('package/Lychee/Secure/Descriptor.lua')
dofile('package/Lychee/Secure/Policy.lua')
dofile('package/Lychee/Secure/SecureActionBroker.lua')
local broker=LycheeInternal.Host.SecureBroker
local token={controller=palette,row={},item={},session=1,generation=1}
local action={kind='secure-item',itemID=123}
assert(not Lychee.Secure.Descriptor.FromAction({kind='secure-item',itemID=-1}))
local button=assert(broker:Prepare(action,token))
assert(button.attrs.type=='item' and button.attrs.item=='item:123' and not button.attrs.spell)
local located=0;palette.ShowRowActions=function() located=located+1 end
button.scripts.OnMouseDown(button,'RightButton');assert(located==1 and not button.itemClicked)
button.scripts.PreClick(button);assert(button.itemClicked and not next(broker.eventFrame.events))
button.scripts.PostClick(button,'LeftButton');assert(not button.busy and not button.attrs.item)
button=assert(broker:Prepare(action,token));valid=false;button.scripts.PreClick(button)
assert(not button.attrs.type and not button.attrs.item and not button.pendingCast);valid=true
button=assert(broker:Prepare({kind='secure-spell',spellID=1},token))
assert(button.attrs.type=='spell' and button.attrs.spell==1 and not button.attrs.item)
broker:Release(button)
present=false;assert(not broker:Prepare(action,token));present=true
combat=true;assert(not broker:Prepare(action,token));combat=false
broker:Flush()
assert(not next(broker.eventFrame.events))
print('Bag secure action PASS right-click/no-use, stale identity, reuse, combat, missing item')
