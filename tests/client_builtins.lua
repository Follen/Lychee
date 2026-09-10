-- Real built-in modules under a bounded client fixture, with isolated locales.
local root="package/Lychee/"
local captured={}
local product,locale="anniversary","enUS"
_G.LycheeInternal={Builtin={},Search={RuntimeIdentity={Current=function() return {product=product} end}},
    Locale={code=locale,IsChinese=function(self) return self.code=="zhCN" or self.code=="zhTW" end}}
local I=LycheeInternal
_G.Lychee={RegisterProvider=function(_,definition) captured[definition.id]=definition;return {} end}
function GetLocale() return locale end
function InCombatLockdown() return false end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "General",0,0,4 end
BOOKTYPE_SPELL="spell"
function GetSpellBookItemInfo(slot) return slot==3 and "FUTURESPELL" or "SPELL",100+slot end
function GetSpellBookItemName(slot) return "Spell "..slot,"Rank "..slot end
function GetSpellBookItemTexture(slot) return 500+slot end
function IsPassiveSpell(slot) return slot==2 end
function GetBuildInfo() return "2.5.7","70000","fixture",20507 end
local function load(path) dofile(root..path) end
load("Builtin/Definitions.lua");load("Builtin/Shared/Support.lua");load("Core/ProviderLocales.lua");load("Builtin/Achievements/Locales.lua");load("Builtin/AddonInspector/Locales.lua");load("Builtin/Bags/Locales.lua");load("Builtin/BlizzardSettings/Locales.lua");load("Builtin/Bosses/Locales.lua");load("Builtin/Crests/Locales.lua");load("Builtin/EquipmentSets/Locales.lua");load("Builtin/GameMenus/Locales.lua");load("Builtin/GreatVault/Locales.lua");load("Builtin/Keystones/Locales.lua");load("Builtin/Mounts/Locales.lua");load("Builtin/PlayerSpells/Locales.lua");load("Builtin/TalentLoadouts/Locales.lua")
for id,resources in pairs(I.BuiltinLocaleData) do
    local translator,err=I.ProviderLocales:Builtin(id)
    assert(translator,id..":"..tostring(err and err.field))
    local count=0
    for key,value in pairs(resources.enUS) do
        count=count+1;assert(type(value)=="string" and value~="")
        assert(resources.zhCN[key]==key,"Chinese fallback belongs to provider")
    end
    assert(count<=256)
end
local spellLocale=assert(I.ProviderLocales:Builtin("builtin.player-spells"))
assert(spellLocale["玩家技能"]=="Player spells")
I.Locale.code="zhCN"
assert(I.ProviderLocales:Builtin("builtin.player-spells")["玩家技能"]=="玩家技能")
I.Locale.code="enUS"
load("Builtin/PlayerSpells/Provider.lua")
local spells=I.Builtin.PlayerSpells.Provider
assert(spells:RefreshFromSpellBook())
assert(spells.lastRefresh=="legacy-spellbook")
assert(spells.items[101] and spells.items[104] and not spells.items[102] and not spells.items[103])
local records=spells:BuildSearchRecords()
assert(#records==2 and records[1].actions[1].spellID==101)
assert(records[1].actions[1].title=="Cast")
load("Builtin/Shared/InterfaceActions.lua");load("Builtin/GameMenus/Provider.lua")
for _,client in ipairs({"retail","classic","titan","anniversary"}) do
    product=client;I.Builtin.GameMenus.handle=nil;I.Builtin.GameMenus:Init()
    local def=captured["builtin.game-menus"]
    assert(def.minApiRevision==2 and def.i18n.enUS and #def.scope.products==4)
    local entries={};for _,entry in ipairs(def.entries) do entries[entry.id]=entry end
    assert(entries.spellbook and entries.talents and entries.settings)
    assert((entries["warband-scenes"]~=nil)==(client=="retail"))
    assert((entries.achievements~=nil)==(client~="anniversary"))
    assert(entries.spellbook.title=="Spellbook")
    if client~="retail" then
        SpellBookFrame={bookType="spell",IsShown=function(self) return self.shown end}
        function ToggleSpellBook(book) SpellBookFrame.bookType=book;SpellBookFrame.shown=true end
        assert(def.actions.open.run(entries.spellbook).ok)
    end
end
load("Builtin/Shared/CatalogProvider.lua");load("Builtin/BlizzardSettings/Provider.lua")
for _,client in ipairs({"retail","classic","titan","anniversary"}) do
    product=client;local found={}
    I.Builtin.BlizzardSettings.build({},function(row) found[row.id]=row end,function() end)
    assert(found.reload and found.reload.title=="Reload UI")
    assert((found.cdm~=nil)==(client=="retail"))
end
-- No journal UI creation: English names come from IDs; fallback never leaks Chinese.
I.Builtin.JournalCatalog={instances={[7]={"中文副本",1}},encounters={{9,7,"中文首领"}}}
load("Builtin/Bosses/Provider.lua")
local rows={}
I.Builtin.Bosses.build({},function(row) rows[#rows+1]=row end,function() end)
assert(rows[1].title=="Boss 9" and rows[1].subtitle=="Instance 7")
function EJ_GetEncounterInfo() return "Native Boss" end
function EJ_GetInstanceInfo() return "Native Instance" end
I.Builtin.Bosses.build({},function(row) rows[#rows+1]=row end,function() end)
assert(rows[2].title=="Native Boss" and rows[2].subtitle=="Native Instance")
assert(I.Builtin.Bosses.defaultEnabled and I.Builtin.Bosses.batchSize==16)
print("client builtins: locale isolation, legacy spells, four-client menus/settings and native boss names passed")
