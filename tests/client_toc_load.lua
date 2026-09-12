-- Load the shipped files in TOC order without optional game APIs. This catches
-- unguarded load-time API access; it does not simulate secure hardware actions.
local frames=0
function CreateFrame()
    frames=frames+1
    return {RegisterEvent=function() end,UnregisterAllEvents=function() end,SetScript=function(self,event,fn) self[event]=fn end}
end
function InCombatLockdown() return false end
local clients={{"Mainline",1,120100,"retail"},{"Mists",19,50504,"classic"},{"Wrath",11,38002,"titan"},{"TBC",5,20506,"anniversary"}}
for _,client in ipairs(clients) do
    for _,locale in ipairs({"enUS","zhCN"}) do
        LycheeInternal=nil;Lychee=nil;LycheeDB=nil
        WOW_PROJECT_ID=client[2]
        GetLocale=function() return locale end
        GetBuildInfo=function() return "fixture","70000","",client[3] end
        local loaded={}
        for line in io.lines("addon/Lychee/Lychee_"..client[1]..".toc") do
            line=line:gsub("\r$","")
            if line~="" and line:sub(1,1)~="#" then
                dofile("addon/Lychee/"..line);loaded[line]=true
            end
        end
        local I=LycheeInternal
        assert(I.Search.RuntimeIdentity.product==client[4])
        assert(loaded["Core/ProviderLocales.lua"] and loaded["Builtin/GameMenus/Locales.lua"])
        assert(not (I.Host and I.Host.PaletteController),"loading must not create the search UI")
        if client[4]~="retail" then
            for _,name in ipairs({"Crests","Keystones","Bosses","GreatVault"}) do
                assert(not loaded["Builtin/"..name.."/Provider.lua"],"retail module leaked into other TOC: "..name)
            end
            assert(not loaded["Builtin/Bosses/JournalCatalog.lua"])
        end
        -- Test the Init dispatcher independently from each module's adapters:
        -- absent capabilities prevent Init, supported generic modules get one call.
        local calls={}
        for name,module in pairs(I.Builtin) do
            if type(module)=="table" and type(module.Init)=="function" then
                module.Init=function() calls[name]=(calls[name] or 0)+1 end
            end
        end
        I.Builtin:Init();I.Builtin:Init()
        assert(calls.GameMenus==1 and calls.BlizzardSettings==1)
        assert(not calls.Bags and not calls.Mounts and not calls.Achievements and not calls.EquipmentSets and not calls.AddonInspector)
        if client[4]~="retail" then assert(not calls.TalentLoadouts and not calls.Keystones) end
        -- With required functions present, every shipped supported module starts
        -- once. Removing any declared function must reject only that availability.
        local function owner(symbol)
            local namespace=_G
            local parts={};for part in symbol:gmatch("[^.]+") do parts[#parts+1]=part end
            for index=1,#parts-1 do
                namespace[parts[index]]=namespace[parts[index]] or {}
                namespace=namespace[parts[index]]
            end
            return namespace,parts[#parts]
        end
        local restored={}
        for _,definition in ipairs(I.Builtin.Definitions) do
            for _,symbol in ipairs(definition.requires) do
                local namespace,key=owner(symbol)
                restored[#restored+1]={namespace,key,namespace[key]}
                namespace[key]=function() end
            end
        end
        calls={};I.Builtin._initialized=nil
        I.Builtin:Init();I.Builtin:Init()
        for _,definition in ipairs(I.Builtin.Definitions) do
            local allowed=I.Builtin.Support:Available(definition,client[4])
            assert(calls[definition.module]==(allowed and 1 or nil),definition.id)
            assert(not I.Builtin.Support:Available(definition,"unknown"))
            if allowed then
                for _,symbol in ipairs(definition.requires) do
                    local namespace,key=owner(symbol);local previous=namespace[key];namespace[key]=nil
                    assert(not I.Builtin.Support:Available(definition,client[4]),symbol)
                    namespace[key]=previous
                end
            end
        end
        for index=#restored,1,-1 do
            local entry=restored[index];entry[1][entry[2]]=entry[3]
        end
    end
end
print("Shipped TOC load order/capability dispatch PASS: 4 clients x 2 languages; no optional APIs")
