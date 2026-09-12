LycheeInternal={Providers={CanRemember=function() return true end}}
dofile('addon/Lychee/Core/CharacterStore.lua')
dofile('addon/Lychee/Core/UserPreferences.lua')
local P=LycheeInternal.UserPreferences
local function pin(id) return {providerID='fixture',entryID=tostring(id),title='Saved title'} end
local function reject(raw)
    LycheeCharacterDB={pinned=raw}
    assert(#P:GetPins()==0 and P:GetRecoveryError()=='PIN_DATA_INVALID')
    assert(LycheeCharacterDB.pinned==raw,'raw data is preserved, not silently truncated')
    local ok,err=P:Pin({ref={providerID='fixture',entryID='new'},text='new'})
    assert(not ok and err=='PIN_DATA_INVALID' and LycheeCharacterDB.pinned==raw)
end
local tooMany={};for i=1,65 do tooMany[i]=pin(i) end;reject(tooMany)
local huge=pin(1);huge.title=string.rep('x',1024*1024);reject({huge})
local total={};for i=1,32 do total[i]=pin(i);total[i].title=string.rep('x',4096) end;reject(total)
reject({pin(1),pin(1)});reject({[2]=pin(2)});reject({pin(1),false})
reject(setmetatable({pin(1)},{__index=function() error('must not execute saved metadata') end}))
local extra=pin(1);extra.payload={};reject({extra})
local raw={pin(1),pin(2)};LycheeCharacterDB={pinned=raw}
assert(P:GetPins()==raw and not P:GetRecoveryError())
local removed=P:Remove(1);assert(removed==raw[2] or removed.entryID=='1')
assert(P:Restore(removed,1) and raw[1]==removed,'undo preserves object identity')
assert(not P:Move(1,0/0) and not P:Remove(1.5))
local current=P:GetPins();collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count')
for i=1,10000 do assert(P:GetPins()==current and not P:GetRecoveryError()) end
local allocation=collectgarbage('count')-before;collectgarbage('restart')
assert(allocation<1,'warm restoration/access has no copies')
print(string.format('Pin restore PASS: bounded input, preserved raw data, stable undo, warm10000 %.2f KiB',allocation))
