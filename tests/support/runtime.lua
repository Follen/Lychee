-- Test-only assembly. No globals, mocks, result oracles or load-time game work.
-- The real TOC controls order; profiles only select the required module scope.
local M={}
local profiles={
    search={"Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua"},
    provider={"Bootstrap.lua","Core/CharacterStore.lua","Providers/Definitions.lua","Providers/Shared/Support.lua",
        "Core/ProviderLocales.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
        "Search/StaticIndex.lua","Core/Boundary.lua",
        "Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua"},
}
function M.Load(profile,extra,options)
    options=options or {}
    local root=options.root or "addon/Lychee/"
    local selected={}
    if profile then for _,path in ipairs(assert(profiles[profile],"Unknown test profile")) do selected[path]=true end end
    for _,path in ipairs(extra or {}) do selected[path]=true end
    if selected["UI/ResultList.lua"] or selected["Secure/SecureActionBroker.lua"] then selected["Core/InteractionBinding.lua"]=true end
    if selected["UI/Palette.lua"] then selected["UI/HomeView.lua"]=true;selected["UI/SocialLinks.lua"]=true end
    if profile=="provider" then selected["SDK/CompactStore.lua"]=true;selected["Core/Catalog.lua"]=true;selected["Core/RecordCodec.lua"]=true;selected["Core/InvocationRuntime.lua"]=true;selected["PublicAPI/Invocation.lua"]=true end
    if selected["Core/Preparation.lua"] then selected["Search/SourceAccess.lua"]=true;selected["Search/ProviderPolicy.lua"]=true;selected["Core/AddonDiscovery.lua"]=true;selected["Core/AddonLoader.lua"]=true end
    local settingsProvider=selected["Providers/BlizzardSettings/Provider.lua"]
    local loaded={}
    for line in io.lines(root..(options.toc or "Lychee_Mainline.toc")) do
        local path=line:gsub("\r$","")
        -- Settings is one provider with required audio/invocation helpers.
        -- Follow the production TOC instead of exercising the retired fallback.
        if settingsProvider and path:match("^Providers/BlizzardSettings/") then selected[path]=true end
        if profile=="provider" and (path=="Core/Resources.lua" or path=="Core/ProviderData.lua") then selected[path]=true end
        if path=="Search/ResultSnapshot.lua" and selected["Search/QueryOrchestrator.lua"] then selected[path]=true end
        if path=="Core/ProviderManagement.lua" and profile=="provider" then selected[path]=true end
        if path=="Providers/Shared/CatalogLedger.lua" and (selected["Providers/Shared/CatalogProvider.lua"] or selected["Providers/Mounts/Provider.lua"] or selected["Providers/PlayerSpells/Provider.lua"]) then selected[path]=true end
        if selected[path] then
            selected[path]=nil;loaded[#loaded+1]=path
        end
    end
    assert(not next(selected),"Requested test module absent from TOC: "..tostring(next(selected)))
    for _,path in ipairs(loaded) do
        if options.load then options.load(path)
        else assert(loadfile(options.overrides and options.overrides[path] or root..path))("Lychee",_G.LycheeInternal) end
    end
    return loaded
end
return M
