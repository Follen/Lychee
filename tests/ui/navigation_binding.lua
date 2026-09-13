-- Real public Provider + Palette publication, with native frame/event substitutes.
dofile("tests/support/palette.lua")
assert(Lychee.UI.Palette:Create())
local I=LycheeInternal
I.Registry:SetReady(true)
local p=I.Host.PaletteController
local calls,last=0,nil
assert(dofile("tests/support/provider_fixture.lua"):Register({id='binding.regression',apiVersion="1.0.0",title='Binding fixture',version='1',
 catalog={{id='a',title='Binding fixture A',actions={'open','other'}},{id='b',title='Binding fixture B',actions={'open','other'}}},
 actions={open={title='Open',run=function(e) calls=calls+1;last=e.id;return {ok=true} end},
 other={title='Other',run=function(e) calls=calls+1;last=e.id;return {ok=true} end}}}))
local function start()
    p:Show();p:CloseSettings(true);p.input:SetText('binding');p:SetQueryMode('binding')
    local _,items=I.Search.Query:Query('Binding fixture',{visible=true},nil)
    local by={};for _,item in ipairs(items) do if item.providerID=='binding.regression' then by[item.id]=item end end
    assert(by.a and by.b)
    return by
end
local by=start()
local function publish(item) assert(p:ApplyResults({item},p.generation,p.session)) end
do
    local field='primaryTarget'
    publish(by.a)
    local button=p.list.rows[1][field];local before=calls
    button.scripts.OnMouseDown(button,'LeftButton')
    publish(by.b)
    button.scripts.OnClick(button,'LeftButton')
    assert(calls==before,'rebound '..field..' must not execute B')
    button.scripts.OnMouseDown(button,'LeftButton');button.scripts.OnClick(button,'LeftButton')
    assert(calls==before+1 and last=='b','fresh '..field..' click remains usable')
end
do
    by=start();publish(by.a)
    local target=p.list.rows[1].primaryTarget
    target.scripts.OnMouseDown(target,'RightButton');target.scripts.OnClick(target,'RightButton')
    local secondary=p.actionMenu.buttons[2].frame;local before=calls
    secondary.scripts.OnMouseDown(secondary,'LeftButton')
    publish(by.b)
    secondary.scripts.OnClick(secondary)
    assert(calls==before,'rebound result cancels the old secondary menu action')
    target.scripts.OnMouseDown(target,'RightButton');target.scripts.OnClick(target,'RightButton')
    secondary=p.actionMenu.buttons[2].frame
    secondary.scripts.OnMouseDown(secondary,'LeftButton');secondary.scripts.OnClick(secondary)
    assert(calls==before+1 and last=='b','secondary action remains available through right-click')
    by=start()
end
publish(by.a)
local row=p.list.rows[1];local button=row.primaryTarget;local before=calls
button.scripts.OnMouseDown(button,'LeftButton')
button.scripts.OnHide(button)
button.scripts.OnClick(button,'LeftButton')
assert(calls==before,'hiding a target cancels press')
button.scripts.OnMouseDown(button,'LeftButton');p:Hide('test');by=start();publish(by.a)
button.scripts.OnClick(button,'LeftButton');assert(calls==before,'close/reopen never revives press')
local oldSelect=p.onHomeSelect
-- Reusing the protected overlay cannot transfer an unfinished press either.
local broker=p.secureBroker
local action={kind='secure-spell',spellID=31884}
local function token() local r=p.list.rows[1];return {controller=p,row=r,item=r.item,session=p.session,generation=p.generation,extensionID=r.extensionID} end
broker:ReleaseAll();local first=assert(broker:Prepare(action,token()))
first.scripts.OnMouseDown(first,'LeftButton');broker:Release(first);publish(by.b)
local second=assert(broker:Prepare(action,token()));assert(second==first)
second.scripts.PreClick(second)
assert(not second.busy and not second.token and not second._bindingIdentity and not second.activeIndex and not broker.pendingButton)
second=assert(broker:Prepare(action,token()))
second.scripts.OnMouseDown(second,'LeftButton');second.scripts.PreClick(second)
assert(broker.pendingButton==second and second.pendingCast,'normal physical secure press still arms cast observation')
broker:ReleaseAll()
p.input:SetText('');p:SetQueryMode('')
local a={id='a',groupID='pinned',groupTitle='Pins',title='A',item=by.a}
local b={id='b',groupID='pinned',groupTitle='Pins',title='B',item=by.b}
p.onHomeSelect=function() calls=calls+1 end
p:SetHomeSections({a},true);local tile=p.homeView.tiles[1]
tile.scripts.OnMouseDown(tile,'LeftButton');p:SetHomeSections({b},true);tile.scripts.OnClick(tile,'LeftButton')
assert(calls==before,'home tile rebind rejects prior press')
tile.scripts.OnMouseDown(tile,'LeftButton');tile.scripts.OnClick(tile,'LeftButton');assert(calls==before+1)
p.onHomeSelect=oldSelect
for _,mode in ipairs({'home','search'}) do
    if mode=='search' then by=start();publish(by.a) else p.input:SetText('');p:SetQueryMode('') end
    local original=mode=='home' and p.homeView.frame or p.list.frame
    local count=#p.list.items;local session,generation=p.session,p.generation
    for _,phase in ipairs({'create','Mount'}) do
        p.input:Focus()
        local factory={create=function()
            if phase=='create' then p.input:ClearFocus();error('create fixture failure') end
            return {Mount=function() p.input:ClearFocus();error('mount fixture failure') end}
        end}
        local ok,err=p:OpenView(factory,{}, {})
        assert(not ok and err=='PANEL_ERROR')
        assert(original:IsShown() and not p.viewHost:IsActive(),'failure preserves '..mode)
        assert(p.input.frame:HasFocus() and p.session==session and p.generation==generation and #p.list.items==count)
    end
end
local disposed=0
local ok,err=p:OpenView({create=function()
    p:Hide('factory-close')
    return {Dispose=function() disposed=disposed+1 end}
end},{},{})
assert(not ok and err=='PANEL_CANCELLED' and not p.visible and disposed==1,'callback close wins over pending navigation')
p:Show();p:SetQueryMode('')
local nesting
assert(p:OpenView({create=function()
    local success,why=p:OpenView({create=function() error('must not run') end},{},{})
    nesting=not success and why=='PANEL_BUSY'
    return {}
end},{},{}))
assert(nesting and p.viewHost:IsActive());p:CloseView('test')
local updating=assert(dofile("tests/support/provider_fixture.lua"):Register({id='navigation.updating',title='Update fixture',version='1',apiVersion="1.0.0",
 catalog={{id='one',title='Before'}}}))
assert(p:OpenView({create=function() return {} end},{},{}))
assert(p:OpenView({create=function()
    assert(updating.catalog:Update({upsert={{id='one',title='After'}}}))
    return {}
end},{},{}),'background catalogue update is not navigation cancellation')
assert(p.viewHost:IsActive())
local updated,updateError=p:OpenView({create=function()
    assert(updating.catalog:Update({upsert={{id='one',title='After failure'}}}))
    error('after update')
end},{},{})
assert(not updated and updateError=='PANEL_ERROR' and p.homeView.frame:IsShown(),'replacement failure after update restores current presentation')
assert(p:OpenView({create=function() return {} end},{},{}))
local cancelled,cancelError=p:OpenView({create=function()
    p.input:SetText('new query');p:SetQueryMode('new query')
    error('after navigation')
end},{},{})
assert(not cancelled and cancelError=='PANEL_CANCELLED' and not p.viewHost:IsActive())
assert(p.list.frame:IsShown() or p.emptyState:IsShown() or p.searchPending,'query navigation wins even when create then throws')
assert(dofile("tests/support/provider_fixture.lua"):Register({id='navigation.secure',title='Secure navigation',version='1',apiVersion="1.0.0",
 catalog={{id='spell',title='Secure navigation spell',actions={{id='cast',kind='secure-spell',spellID=31884,title='Cast'}}}}}))
p.input:SetText('Secure navigation spell');p:SetQueryMode('Secure navigation spell')
local _,secureItems=I.Search.Query:Query('Secure navigation spell',{},nil)
local secureItem;for _,item in ipairs(secureItems) do if item.providerID=='navigation.secure' then secureItem=item end end
assert(secureItem);assert(p:ApplyResults({secureItem},p.generation,p.session))
local function overlay()
    for _,b in ipairs(broker.buttons) do if b.busy and b.token and b.token.row==p.list.rows[1] and b:IsShown() then return b end end
end
assert(overlay())
assert(p:OpenView({create=function() return {} end},{},{}));assert(not overlay())
p:CloseView('return');assert(overlay(),'returning to search restores physical secure target')
assert(p:OpenView({create=function() return {} end},{},{}))
assert(not p:OpenView({create=function() error('replace') end},{},{}))
local target=assert(overlay(),'replacement failure restores physical secure target')
target.scripts.OnMouseDown(target,'LeftButton');target.scripts.PreClick(target)
assert(target.pendingCast);broker:ReleaseAll();p:Hide('test-end')
print('Navigation/binding PASS: rebind/normal/hidden/reopen/home/secondary menu, page create+Mount failure, focus and cancellation')

-- View resize commits only for the current owner and cannot leak into a replacement.
p:Show();p:SetQueryMode("")
local heightMotion=Lychee.UI.Motion.Height
Lychee.UI.Motion.Height=function(_,frame,height) frame:SetHeight(height) end
local sized={Mount=function(self)
    local before=p.frame:GetHeight()
    assert(p:ResizeView(self,364));assert(p.frame:GetHeight()==before,"Mount cannot resize before presentation commits")
end}
assert(p:OpenView({create=function() return sized end},{},{}))
assert(p.viewHost.panel.contentHeight==364 and p.frame:GetHeight()==452)
assert(p:ResizeView(sized,416) and p.viewHost.panel.contentHeight==416 and p.frame:GetHeight()==504)
assert(p:ResizeView(sized,1000) and p.frame:GetHeight()==518,"Host caps oversized view requests")
assert(not p:ResizeView({},400) and not p:ResizeView(sized,0/0))
p:CloseView("resize-close")
assert(not p:ResizeView(sized,416),"unmounted view cannot resize home/search")
assert(p:OpenView({create=function() return {} end},{},{}))
assert(p.viewHost.panel.contentHeight==nil,"replacement keeps default height")
p:CloseView("resize-done")
Lychee.UI.Motion.Height=heightMotion
print("View height ownership PASS")

p:Show();p:SetQueryMode("")
local footerView={Mount=function(self) assert(p:SetViewFooter(self,"Share current ability")) end}
assert(p:OpenView({create=function() return footerView end},{},{}))
assert(p.footerHint:GetText()=="Share current ability" and p.status:GetText()=="","custom detail footer contains one instruction")
assert(p:SetViewFooter(footerView,"Try again") and p.footerHint:GetText()=="Try again")
assert(not p:SetViewFooter({},"stale") and not p:SetViewFooter(footerView,string.rep("x",257)))
p:CloseView("footer-close")
assert(not p:SetViewFooter(footerView,"stale") and p.footerHint:GetText()~="Try again","closing restores the destination footer")
assert(p:OpenView({create=function() return {} end},{},{}))
assert(p.viewHost.panel.footerHint==nil and p.footerHint:GetText()~="Share current ability")
p:CloseView("footer-test-done")
print("View footer ownership PASS")

p:Show();p:SetQueryMode("")
local originalStatus,originalHint=p.status:GetText(),p.footerHint:GetText()
local failedFooter,failedFooterReason=p:OpenView({create=function() return {
    Mount=function(self) assert(p:SetViewFooter(self,"provisional footer"));error("footer mount failure") end
} end},{},{})
assert(not failedFooter and failedFooterReason=="PANEL_ERROR")
assert(p.status:GetText()==originalStatus and p.footerHint:GetText()==originalHint,"failed Mount cannot publish provisional footer")
print("Failed view footer rollback PASS")

-- One Host return icon replaces Esc for all Provider pages and settings.
p:Show();p:CloseSettings();p.input:SetText("binding")
assert(p:OpenView({create=function() return {} end},{},{}))
assert(p.backIcon:IsShown() and not p.closeComponent.label:IsShown())
assert(p.backIcon._lycheeVertexToken==Lychee.UI.Theme.Colors.text,"return icon starts warm white")
p.close.scripts.OnEnter()
assert(p.backIcon._lycheeVertexToken==Lychee.UI.Theme.Colors.accentHover,"return icon turns red only on interaction")
p.close.scripts.OnLeave()
assert(p.backIcon._lycheeVertexToken==Lychee.UI.Theme.Colors.text,"return icon restores white on leave")
p.close.scripts.OnClick()
assert(not p.viewHost:IsActive() and p.visible and not p.backIcon:IsShown() and p.closeComponent.label:IsShown())
assert(p.input:GetText()=="binding","header return preserves the query")
p:OpenSettings();assert(p.backIcon:IsShown() and not p.closeComponent.label:IsShown())
p.close.scripts.OnClick();assert(not p.settingsOpen and p.visible and p.closeComponent.label:IsShown())
p:Hide("test-end")
function GetCursorPosition() return 100,200 end
function UIParent:GetHeight() return 600 end
p:Show()
p.actionMenu=Lychee.UI.Components:ShowActionMenu(p.frame,function(_,menu) menu:CreateButton("Action",function() end) end)
assert(p:Hide("escape") and p.visible and not Lychee.UI.Components.actionMenu.owner,"Escape closes the menu before the window")
assert(p:Hide("escape") and not p.visible,"next Escape closes the window")
