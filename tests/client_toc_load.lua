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
        for line in io.lines("package/Lychee/Lychee_"..client[1]..".toc") do
            line=line:gsub("\r$","")
            if line~="" and line:sub(1,1)~="#" then
                dofile("package/Lychee/"..line);loaded[line]=true
            end
        end
        local I=LycheeInternal
        assert(I.Search.RuntimeIdentity.product==client[4])
        assert(loaded["Core/ProviderLocales.lua"] and loaded["Locales/Builtin.enUS.lua"])
        assert(not (I.Host and I.Host.PaletteController),"loading must not create the search UI")
        if client[4]~="retail" then
            for _,name in ipairs({"Crests","Keystones","Bosses","GreatVault"}) do
                assert(not loaded["Builtin/"..name..".lua"],"retail module leaked into other TOC: "..name)
            end
            assert(not loaded["Builtin/Data/JournalCatalog.lua"])
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
    end
end
print("Shipped TOC load order/capability dispatch PASS: 4 clients x 2 languages; no optional APIs")
