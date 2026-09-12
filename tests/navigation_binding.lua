-- Real public Provider + Palette publication, with native frame/event substitutes.
dofile('tests/interaction_smoke.lua')
local I=LycheeInternal
local p=I.Host.PaletteController
local calls,last=0,nil
assert(Lychee:RegisterProvider({id='binding.regression',apiVersion=2,title='Binding fixture',version='1',
 entries={{id='a',title='Binding fixture A',actions={'open','other'}},{id='b',title='Binding fixture B',actions={'open','other'}}},
 actions={open={title='Open',run=function(e) calls=calls+1;last=e.id;return {ok=true} end},
 other={title='Other',run=function(e) calls=calls+1;last=e.id;return {ok=true} end}}}))
local function start()
    p:Show();p:CloseSettings(true);p.input:SetText('binding');p:SetQueryMode('binding')
    local _,items=I.Search.Query:Query('Binding fixture',{},nil)
    local by={};for _,item in ipairs(items) do if item.providerID=='binding.regression' then by[item.id]=item end end
    assert(by.a and by.b)
    return by
end
local by=start()
local function publish(item) assert(p:ApplyResults({item},p.generation,p.session)) end
for _,field in ipairs({'primaryTarget','secondary'}) do
    publish(by.a)
    local button=p.list.rows[1][field];local before=calls
    button.scripts.OnMouseDown(button,'LeftButton')
    publish(by.b)
    button.scripts.OnClick(button,'LeftButton')
    assert(calls==before,'rebound '..field..' must not execute B')
    button.scripts.OnMouseDown(button,'LeftButton');button.scripts.OnClick(button,'LeftButton')
    assert(calls==before+1 and last=='b','fresh '..field..' click remains usable')
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
local updating=assert(Lychee:RegisterProvider({id='navigation.updating',title='Update fixture',version='1',apiVersion=2,
 entries={{id='one',title='Before'}}}))
assert(p:OpenView({create=function() return {} end},{},{}))
assert(p:OpenView({create=function()
    assert(updating:Update({upsert={{id='one',title='After'}}}))
    return {}
end},{},{}),'background catalogue update is not navigation cancellation')
assert(p.viewHost:IsActive())
local updated,updateError=p:OpenView({create=function()
    assert(updating:Update({upsert={{id='one',title='After failure'}}}))
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
assert(Lychee:RegisterProvider({id='navigation.secure',title='Secure navigation',version='1',apiVersion=2,
 entries={{id='spell',title='Secure navigation spell',actions={{id='cast',kind='secure-spell',spellID=31884,title='Cast'}}}}}))
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
print('Navigation/binding PASS: rebind/normal/hidden/reopen/home/secondary, page create+Mount failure, focus and cancellation')
