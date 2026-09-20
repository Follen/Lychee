-- Real locale chunks; a baseline exported from the old release may be supplied
-- as arg[1] for an independent, exhaustive before/after text comparison.
local expected=arg[1] and dofile(arg[1])
local root="addon/Lychee/"
local resources,checks={},0
for _,locale in ipairs({"enUS","zhCN","enGB","zhTW","frFR"}) do
    LycheeInternal={Locale={code=locale}}
    dofile(root.."Providers/Definitions.lua")
    dofile(root.."Providers/Shared/Support.lua")
    dofile(root.."Core/ProviderLocales.lua")
    local I=LycheeInternal
    local family=(locale=="zhCN" or locale=="zhTW") and "zhCN" or "enUS"
    for _,spec in ipairs(I.ProviderModules.Definitions) do
        local base=root.."Providers/"..spec.module.."/Locales/"
        local other=family=="enUS" and "zhCN" or "enUS"
        local prior=I.ProviderLocaleData and I.ProviderLocaleData[spec.id]
        dofile(base..other..".lua")
        assert((I.ProviderLocaleData and I.ProviderLocaleData[spec.id])==prior,"inactive language published a table")
        dofile(base..family..".lua")
        local dictionary=I.ProviderLocaleData[spec.id]
        local translator=assert(I.ProviderLocales:Module(spec.id))
        assert(translator.dictionary==dictionary and rawget(translator,"resources")==nil)
        assert(not dictionary.enUS and not dictionary.zhCN)
        for key,value in pairs(dictionary) do
            assert(type(value)=="string" and translator:Text(key)==value)
            if expected then assert(expected[spec.id][family][key]==value,spec.id..":"..key) end
            checks=checks+1
        end
        if expected then for key in pairs(expected[spec.id][family]) do assert(dictionary[key]~=nil) end end
        resources[spec.id]=resources[spec.id] or {}
        if locale==family then resources[spec.id][family]=dictionary
        else for key,value in pairs(resources[spec.id][family]) do assert(dictionary[key]==value) end end
        assert(I.ProviderLocales:Module(spec.id)==translator)
    end
end
-- Translation keys/format signatures are checked offline across both files;
-- this never requires shipping both dictionaries in the live session.
for id,pair in pairs(resources) do
    assert(LycheeInternal.ProviderLocales:Compile(pair))
    for key in pairs(pair.enUS) do assert(pair.zhCN[key]~=nil,id..":"..key) end
end
print("Provider locale loading PASS: 16 modules, 5 locales, "..checks.." text checks, selected dictionaries only")
