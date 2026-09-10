local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.bosses")
local function build(self,put,checkpoint)
    self.hasFallback=false
    local data=I.Builtin.JournalCatalog
    -- One localized name per bounded instance catalogue, reused across encounters.
    local instances={}
    for _,encounter in ipairs(data.encounters) do
        local instance=data.instances[encounter[2]]
        local name=instances[encounter[2]]
        if not name then
            name=EJ_GetInstanceInfo and EJ_GetInstanceInfo(encounter[2])
            if not name then self.hasFallback=true end
            name=name or (I.Locale:IsChinese() and instance[1]) or L:Format("副本 %d",encounter[2])
            instances[encounter[2]]=name
        end
        local title=EJ_GetEncounterInfo and EJ_GetEncounterInfo(encounter[1])
        if not title then self.hasFallback=true end
        title=title or (I.Locale:IsChinese() and encounter[3]) or L:Format("首领 %d",encounter[1])
        local record={id="boss-"..encounter[1],title=title,subtitle=name,kindTitle=L["首领"],
            icon=instance[2],aliases={name},keywords={"首领","boss",tostring(encounter[1])},
            payload={encounterID=encounter[1],instanceID=encounter[2]},actions={"open"}}
        put(record,title.."\0"..name)
        checkpoint()
    end
end
local M=I.Builtin.CatalogProvider:New("builtin.bosses",L["首领"],{"ADDON_LOADED"},build,
    {open={title=L["查看首领指南"],run=function(entry)
        return I.Builtin.InterfaceActions:Run(function()
            return I.Builtin.InterfaceActions:OpenJournal(entry.payload.instanceID,entry.payload.encounterID)
        end,L)
    end}})
M.defaultEnabled=true
M.batchSize=16
function M:onEvent(event,addon)
    if event=="ADDON_LOADED" and addon=="Blizzard_EncounterJournal" and self.hasFallback then self:MarkDirty() end
end
function M:onReady()
    if not self.hasFallback and self.frame then self.frame:UnregisterEvent("ADDON_LOADED") end
end
-- Chinese uses the shipped canonical catalogue, preserving its zero-driver
-- startup baseline. English native lookup is separately bounded by the builder.
if I.Locale:IsChinese() then
    function M:Init()
        if self.handle then return true end
        local data,records=I.Builtin.JournalCatalog,{}
        for _,encounter in ipairs(data.encounters) do
            local instance=data.instances[encounter[2]]
            records[#records+1]={id="boss-"..encounter[1],title=encounter[3],subtitle=instance[1],
                kindTitle=L["首领"],icon=instance[2],aliases={instance[1]},keywords={"首领","boss"},
                payload={encounterID=encounter[1],instanceID=encounter[2]},actions={"open"}}
        end
        local handle,err=Lychee:RegisterProvider({id=self.id,apiVersion=2,minApiRevision=2,version="1.0.0",
            title=L["首领"],i18n=L.resources,scope=I.Builtin.Support:Scope("builtin.bosses"),entries=records,actions=self.actions,
            onEnable=function() return function(reason) if reason=="unregister" then M.handle=nil end end end})
        self.handle=handle
        return handle~=nil,err
    end
end
I.Builtin.Bosses=M
