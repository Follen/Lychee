-- Replay character SavedVariables swaps; the account DB remains the same.
LycheeInternal={Providers={CanRemember=function() return true end}}
dofile("addon/Lychee/Core/Boundary.lua")
local legacy={providerID="spells",entryID="portal"}
LycheeDB={palette={pinned={legacy},reduceMotion=true}}
LycheeCharacterDB=nil
dofile("addon/Lychee/Core/CharacterStore.lua");dofile("addon/Lychee/Core/UserPreferences.lua")
local P=LycheeInternal.UserPreferences
assert(#P:GetPins()==0,"new character must not inherit the account's mage portal pin")
assert(#P:GetPins()==0,"account pins are never used")
assert(LycheeDB.palette.reduceMotion==true,"clearing pins preserves other preferences")
local function item(id) return {ref={providerID="spells",entryID=id},text=id} end
assert(P:Pin(item("portal")))
assert(P:Pin(item("blink")))
local mage=LycheeCharacterDB
LycheeCharacterDB=nil
assert(#P:GetPins()==0,"paladin starts with a separate empty list")
assert(P:Pin(item("holy")))
assert(P:Pin(item("shield")))
assert(P:Move(2,1))
local removed=P:Remove(2)
assert(P:Restore(removed,1))
assert(P:Pin(item("holy")) and #P:GetPins()==2,"duplicate remains idempotent per character")
local paladin=LycheeCharacterDB
LycheeCharacterDB=mage
assert(#P:GetPins()==2 and P:GetPins()[1].entryID=="portal" and P:GetPins()[2].entryID=="blink",
    "paladin mutations cannot change mage order or contents")
assert(P:PinIndex(item("holy").ref)==nil)
P:Remove(1)
LycheeCharacterDB=paladin
assert(P:GetPins()[1].entryID=="holy" and P:GetPins()[2].entryID=="shield")
dofile("addon/Lychee/Core/CharacterStore.lua");dofile("addon/Lychee/Core/UserPreferences.lua")
P=LycheeInternal.UserPreferences
P:Initialize()
assert(#P:GetPins()==2,"reload keeps this character's saved pins")
LycheeDB.palette.pinned={legacy}
P:Initialize()
assert(#P:GetPins()==2,"legacy data never overwrites character pins")
LycheeCharacterDB=false
P:Initialize()
assert(#P:GetPins()==0,"malformed character DB resets locally")
for i=1,64 do assert(P:Pin(item(tostring(i)))) end
local ok,err=P:Pin(item("overflow"))
assert(not ok and err=="PIN_LIMIT","64 pin budget remains enforced per character")
for _,suffix in ipairs({"","_Mainline","_Mists","_Wrath","_TBC"}) do
    local file=assert(io.open("addon/Lychee/Lychee"..suffix..".toc","r"))
    local toc=file:read("*a");file:close()
    assert(toc:find("## SavedVariablesPerCharacter: LycheeCharacterDB",1,true),
        "every shipped client TOC must persist the character database")
end
collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count")
for i=1,10000 do P:GetPins() end
local allocated=collectgarbage("count")-before
collectgarbage("restart")
assert(allocated<8,"warm pin access must not allocate or copy character databases")
print(string.format("Pin reads10000 allocated_KiB=%.2f",allocated))
print("Character pins PASS: isolation, empty legacy reset, reorder/remove/undo, reload, malformed DB, limit")
