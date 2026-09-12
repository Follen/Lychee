LycheeInternal={}
LycheeDB={schemaVersion=2,palette={reduceMotion=true,recent={{entryID="old"}},providerSearch={{id="lychee.exwind",global=true}}},
    disabledProviders={["lychee.exwind"]=true,["lychee.ellesmere"]=true}}
LycheeCharacterDB={pinned={{entryID="owned-pin"}}}
dofile("addon/Lychee/Core/CharacterStore.lua")
local S=LycheeInternal.CharacterStore
S:Initialize()
local mage=LycheeCharacterDB
assert(S:Palette().reduceMotion and S:Palette().recent[1].entryID=="old")
assert(LycheeDB.palette==nil and mage.pinned[1].entryID=="owned-pin")
assert(next(S:DisabledProviders())==nil,"old automatic account opt-outs must not disable new character defaults")
S:DisabledProviders()["lychee.exwind"]=true
S:Palette().providerSearch[1].global=false
LycheeCharacterDB=nil
S:Initialize()
local paladin=LycheeCharacterDB
assert(S:Palette().reduceMotion==nil and S:Palette().recent==nil and next(S:DisabledProviders())==nil)
S:Palette().reduceMotion=false
S:DisabledProviders()["lychee.mounts"]=true
LycheeCharacterDB=mage
assert(S:Palette().reduceMotion and S:DisabledProviders()["lychee.exwind"] and not S:DisabledProviders()["lychee.mounts"])
S:Initialize()
assert(S:DisabledProviders()["lychee.exwind"],"defaults cannot override explicit saved choices on reload")
LycheeCharacterDB=paladin
assert(not S:Palette().reduceMotion and not S:DisabledProviders()["lychee.exwind"])
-- File execution precedes SV restoration. A discarded early root must not be retained.
local early=S:Data()
LycheeCharacterDB={palette={reduceMotion=true},disabledProviders={["fixture"]=true}}
S:Initialize()
assert(S:Data()~=early and S:Palette().reduceMotion and S:DisabledProviders().fixture)
collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count")
for i=1,10000 do S:Data();S:Palette();S:DisabledProviders();S:Initialize() end
local allocated=collectgarbage("count")-before
collectgarbage("restart")
assert(allocated<8,"warm character reads must not clone SV or allocate settings snapshots")
-- Guard each package registration path against reintroducing account opt-outs.
-- Detailed game business fixtures separately cover activation/side effects.
local function file(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
for _,name in ipairs({"Lychee_Player/Runtime/CatalogProvider","Lychee_Integrations/Ellesmere/Provider","Lychee_Integrations/Exwind/Provider","Lychee_Inspector/Provider"}) do
    local source=file("addon/"..name..".lua")
    assert(not source:find("optionalProviderDefaults",1,true),"must not introduce automatic opt-outs: "..name)
end
for _,path in ipairs({"Core/ExtensionRegistry", "Core/UserPreferences", "UI/Motion", "UI/Palette", "Search/Personalization", "Search/ProviderPolicy"}) do
    local source=file("addon/Lychee/"..path..".lua")
    assert(not source:find("LycheeDB",1,true),"settings owner must be CharacterStore: "..path)
end
print(string.format("Character settings PASS isolation/restored-SV/one-time-transfer/default-on/explicit-opt-out; reads10000 %.2f KiB",allocated))
