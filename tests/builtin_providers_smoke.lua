-- Real Host/index/API 2; deterministic WoW adapters for built-in integrations.
function GetLocale() return "zhCN" end
function GetBuildInfo() return "12.1.0", "69587", "today", 120100 end
local combat = false
function InCombatLockdown() return combat end
STANDARD_TEXT_FONT = "test.ttf"
local frames, calls = {}, {}
local Frame = {}
Frame.__index = Frame
function Frame:SetScript(event, fn) self.scripts[event]=fn end
function Frame:RegisterEvent(event) self.events[event]=true end
function Frame:UnregisterAllEvents() self.events={} end
function Frame:Show() local old=self.shown; self.shown=true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown end
function Frame:IsEnabled() return not self.disabled end
function Frame:GetID() return self.tabID end
function Frame:SetText(text) self.text=text; self.sets=(self.sets or 0)+1 end
function Frame:SetTexture(texture) self.texture=texture end
function Frame:SetParent(parent) self.parent=parent end
function Frame:GetWidth() return 600 end
function Frame:GetHeight() return 360 end
for _, name in ipairs({"SetPoint","SetAllPoints","ClearAllPoints","SetSize","SetWidth","SetHeight","SetJustifyH","SetFont","SetTextColor","SetShadowOffset","SetTexCoord"}) do Frame[name]=function() end end
function CreateFrame(_, name, parent)
    local frame=setmetatable({scripts={},events={},parent=parent,shown=false},Frame)
    frames[#frames+1]=frame
    if name then _G[name]=frame end
    return frame
end
function Frame:CreateFontString() return CreateFrame() end
function Frame:CreateTexture() return CreateFrame() end
UIParent=CreateFrame()
local root="package/Lychee/"
for _, path in ipairs({"Bootstrap.lua", "Builtin/Definitions.lua","Builtin/Shared/Support.lua","Core/ProviderLocales.lua", "Builtin/Achievements/Locales.lua","Builtin/AddonInspector/Locales.lua","Builtin/Bags/Locales.lua","Builtin/BlizzardSettings/Locales.lua","Builtin/Bosses/Locales.lua","Builtin/Crests/Locales.lua","Builtin/EquipmentSets/Locales.lua","Builtin/GameMenus/Locales.lua","Builtin/GreatVault/Locales.lua","Builtin/Keystones/Locales.lua","Builtin/Mounts/Locales.lua","Builtin/PlayerSpells/Locales.lua","Builtin/TalentLoadouts/Locales.lua", "Builtin/Shared/CatalogProvider.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/ProviderPolicy.lua",
    "Search/StaticIndex.lua","Core/CommandCatalog.lua","Core/CapabilityBroker.lua","Core/Boundary.lua","Core/IntentRouter.lua",
    "Core/Scheduler.lua","Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua",
    "UI/Theme.lua","UI/TextHighlight.lua","UI/ViewHost.lua","Core/ResultActionExecutor.lua","Builtin/Shared/InterfaceActions.lua","Builtin/Bosses/JournalCatalog.lua",
    "Builtin/Crests/Provider.lua","Builtin/GameMenus/Provider.lua","Builtin/Bosses/Provider.lua","Builtin/Init.lua"}) do dofile(root..path) end
local I=LycheeInternal
local frameBaseline=#frames
collectgarbage("collect")
local memoryBefore, initStarted=collectgarbage("count"),os.clock()
I.Builtin:Init()
I.Registry:SetReady(true)
local initMS=(os.clock()-initStarted)*1000
collectgarbage("collect")
local indexKB=collectgarbage("count")-memoryBefore
assert(I.Builtin.Crests.handle and I.Builtin.GameMenus.handle and I.Builtin.Bosses.handle, "all providers register through API 2")
assert(#frames==frameBaseline, "registration/search creates no UI or resident event driver")
local function query(text)
    local _, items=I.Search.Query:Query(text,{visible=true})
    return items
end
local function find(text, provider, id)
    for _, item in ipairs(query(text)) do
        if item.providerID==provider and (not id or item.ref.entryID==id) then return item end
    end
    error("missing result: "..text.." / "..tostring(id))
end
local function execute(item)
    local result, err=I.Providers:Execute(item,"open",{})
    if result then return result end
    assert(type(err)=="table" and err.code)
    err.ok=false
    return err
end
for _, alias in ipairs({"纹章","神话","英雄","勇士","老兵","冒险者","迷雾神话纹章","英雄迷雾纹章"}) do
    local count=0
    for _, item in ipairs(query(alias)) do if item.providerID=="builtin.crests" then count=count+1; assert(item.text=="纹章" and item.icon==7734060) end end
    assert(count==1, "one crest result per alias: "..alias)
end
local crest=find("纹章","builtin.crests")
local result=execute(crest)
assert(result.ok and result.view=="balances" and not result.close)
local quantities={[3446]=7,[3445]=12,[3444]=0,[3443]=45,[3442]=0}
local reads=0
C_CurrencyInfo={GetCurrencyInfo=function(id) reads=reads+1; return {quantity=quantities[id],name="",iconFileID=0} end}
local provider=I.Providers.entries["builtin.crests"]
local factory=provider.definition.views.balances
local host=Lychee.UI.ViewHost:Create(UIParent)
assert(host:Mount(factory,{},{}))
local panel=host.panel.instance
assert(#panel.rows==5 and panel.rows[1].quantity.text=="7" and panel.rows[5].quantity.text=="0")
assert(panel.rows[1].icon.texture==7734060 and panel.frame.events.CURRENCY_DISPLAY_UPDATE)
local sets, beforeReads=panel.rows[1].quantity.sets, reads
panel.frame.scripts.OnEvent(panel.frame,"CURRENCY_DISPLAY_UPDATE",999)
assert(reads==beforeReads, "unrelated currency does no work")
panel.frame.scripts.OnEvent(panel.frame,"CURRENCY_DISPLAY_UPDATE",3446)
assert(reads==beforeReads+1 and panel.rows[1].quantity.sets==sets, "one-row refresh skips unchanged setter")
quantities[3446]=19
panel.frame.scripts.OnEvent(panel.frame,"CURRENCY_DISPLAY_UPDATE",3446)
assert(panel.rows[1].quantity.text=="19")
beforeReads=reads
panel.frame.scripts.OnEvent(panel.frame,"CURRENCY_DISPLAY_UPDATE")
assert(reads==beforeReads+5, "global invalidation has bounded five-row work")
C_CurrencyInfo.GetCurrencyInfo=function() error("temporarily unavailable") end
panel:Update()
assert(panel.rows[1].quantity.text=="—", "unavailable balance is not reported as zero")
C_CurrencyInfo.GetCurrencyInfo=function(id) return {quantity=quantities[id]} end
panel:Update()
assert(panel.rows[1].quantity.text=="19", "failed read retries")
local allocated=#frames
host:Unmount("close")
assert(not next(panel.frame.events) and not panel.active and not panel.frame.shown)
assert(host:Mount(factory,{},{}))
assert(host.panel.instance==panel and #frames==allocated, "view rows reused across reopen")
assert(I.Builtin.Crests.handle:SetEnabled(false))
assert(not next(panel.frame.events) and not panel.active, "provider disable releases currency events")
assert(I.Builtin.Crests.handle:SetEnabled(true))
host:Unmount("test")

local function shown(name) local f=_G[name] or CreateFrame("Frame",name); f:Show(); return f end
ToggleCharacter=function(tab, onlyShow) calls.character={tab,onlyShow}; shown("CharacterFrame"); shown(tab) end
local character=find("装备","builtin.game-menus","character")
assert(execute(character).ok and calls.character[1]=="PaperDollFrame" and calls.character[2]==true)
assert(execute(character).ok and PaperDollFrame:IsShown())
PlayerSpellsUtil={OpenToClassTalentsTab=function() calls.talents=true; shown("PlayerSpellsFrame") end}
assert(execute(find("天赋","builtin.game-menus","talents")).ok and calls.talents)
SetCollectionsJournalShown=function(value, tab)
    calls.collection={value,tab}; shown("CollectionsJournal")
    shown(({"MountJournal","PetJournal","ToyBox","HeirloomsJournal","WardrobeCollectionFrame","WarbandSceneJournal"})[tab])
end
assert(execute(find("幻化","builtin.game-menus","appearances")).ok and calls.collection[1] and calls.collection[2]==5)
local toggles=0
ToggleWorldMap=function() toggles=toggles+1; shown("WorldMapFrame") end
local map=find("世界地图","builtin.game-menus","map")
assert(execute(map).ok and execute(map).ok and toggles==1, "repeated open never toggles closed")
local allowed=true
C_LFGInfo={CanPlayerUseGroupFinder=function() return allowed end}
PVEFrame_ShowFrame=function(side,selection) calls.group={side,selection}; shown("PVEFrame"); if side then shown(side) end; if selection then shown(selection) end end
assert(execute(find("团队查找器","builtin.game-menus","raid-finder")).ok and calls.group[2]=="RaidFinderFrame")
assert(execute(find("竞技场","builtin.game-menus","pvp")).ok and calls.group[1]=="PVPUIFrame")
allowed=false
assert(not execute(find("地下城查找器","builtin.game-menus","dungeon-finder")).ok)
local calendar=find("日历","builtin.game-menus","calendar")
assert(execute(calendar).code=="UI_UNAVAILABLE", "missing API leaves palette open")
ToggleCalendar=function() error("restricted") end
assert(execute(calendar).code=="UI_UNAVAILABLE", "native failure is bounded")
ToggleCalendar=function() end
assert(execute(calendar).code=="UI_UNAVAILABLE", "silent failure is not reported as opened")
combat=true
assert(execute(map).code=="COMBAT_LOCKED")
combat=false

-- Journal subpages use the actual enabled button and its ID, including the
-- native click route which also updates the journal's remembered tab.
ShowUIPanel=function(frame) frame:Show() end
local tabLoads, selectedTab = 0, nil
local tabTargets={
    {"旅程","journeys","JourneysTab",11},
    {"旅行者日志","travelers-log","MonthlyActivitiesTab",22},
    {"推荐玩法","suggested-content","suggestTab",33},
    {"地下城","journal-dungeons","dungeonsTab",44},
    {"团队副本","journal-raids","raidsTab",55},
    {"教程","tutorials","TutorialsTab",77},
}
EncounterJournal_LoadUI=function()
    tabLoads=tabLoads+1
    local journal=CreateFrame("Frame","EncounterJournal")
    for _, target in ipairs(tabTargets) do
        local tab=CreateFrame("Button",nil,journal)
        tab.tabID=target[4]; tab:Show(); journal[target[3]]=tab
    end
    EJ_ContentTab_OnClick=function(tab)
        selectedTab=tab:GetID()
        EncounterJournal.selectedTab=selectedTab
    end
    return true
end
for _, target in ipairs(tabTargets) do
    local item=find(target[1],"builtin.game-menus",target[2])
    assert(execute(item).ok and selectedTab==target[4], "journal subpage opens exact runtime tab")
end
assert(tabLoads==1, "journal subpages load the UI only once")
local travelers=find("旅行者日志","builtin.game-menus","travelers-log")
EncounterJournal.MonthlyActivitiesTab.disabled=true
assert(execute(travelers).code=="UI_UNAVAILABLE" and selectedTab==77, "disabled page is not forced open")
EncounterJournal.MonthlyActivitiesTab.disabled=false
EncounterJournal.MonthlyActivitiesTab:Hide()
assert(execute(travelers).code=="UI_UNAVAILABLE", "hidden tab is unavailable")
EncounterJournal.MonthlyActivitiesTab:Show()
assert(execute(travelers).ok and execute(travelers).ok and EncounterJournal:IsShown())
EncounterJournal.MonthlyActivitiesTab.IsEnabled=function() error("restricted state") end
assert(execute(travelers).code=="UI_UNAVAILABLE", "restricted button state stays inside native boundary")
EncounterJournal.MonthlyActivitiesTab.IsEnabled=nil
EJ_ContentTab_OnClick=function() end
assert(execute(find("旅程","builtin.game-menus","journeys")).code=="UI_UNAVAILABLE", "silent tab selection failure is not success")
EncounterJournal=nil
EJ_ContentTab_OnClick=nil
EncounterJournal_LoadUI=function() return false end
assert(execute(travelers).code=="UI_UNAVAILABLE", "journal subpage load failure is recoverable")

local boss=find("格拉布托克","builtin.bosses","boss-89")
assert(boss.payload.encounterID==89 and boss.payload.instanceID==63)
local dungeonBosses=0
for _, item in ipairs(query("死亡矿井")) do
    if item.providerID=="builtin.bosses" then dungeonBosses=dungeonBosses+1; assert(item.payload.instanceID==63) end
end
assert(dungeonBosses>=5, "dungeon name returns individual selectable bosses")
assert(find("熔火之心","builtin.bosses"), "old bosses without overview sections remain searchable")
local loaded=0
EncounterJournal_LoadUI=function()
    loaded=loaded+1
    EncounterJournal_OpenJournal=function(difficulty, instance, encounter)
        assert(difficulty==nil)
        local journal=shown("EncounterJournal")
        journal.instanceID,journal.encounterID=instance,encounter
    end
    return true
end
assert(execute(boss).ok and loaded==1 and EncounterJournal.encounterID==89 and EncounterJournal.instanceID==63)
assert(execute(boss).ok and loaded==1)
EncounterJournal_OpenJournal=function() end
EncounterJournal.encounterID=999
assert(execute(boss).code=="UI_UNAVAILABLE", "journal must reach exact encounter before success")
EncounterJournal_OpenJournal=nil
EncounterJournal_LoadUI=function() return false end
assert(execute(boss).code=="UI_UNAVAILABLE")
assert(#I.Providers.entries["builtin.bosses"].records==#I.Builtin.JournalCatalog.encounters)
for _, frame in ipairs(frames) do assert(not frame.scripts.OnUpdate, "no idle polling") end
local queryStarted=os.clock()
for index=1,100 do query(index%2==0 and "死亡矿井" or "纹章") end
print(string.format("Built-in providers PASS: %d bosses; init %.2f ms / retained %.1f KiB; alternating query mean %.3f ms (offline Lua only)",
    #I.Builtin.JournalCatalog.encounters,initMS,indexKB,(os.clock()-queryStarted)*10))
assert(indexKB < 8192, "built-in retained indexes exceed 8 MiB memory budget")
