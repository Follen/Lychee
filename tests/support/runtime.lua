-- Test-only assembly. No globals, mocks, result oracles or load-time game work.
-- The real TOC controls order; profiles only select the required module scope.
local M={}
local profiles={
    search={"Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua"},
    provider={"Bootstrap.lua","Core/CharacterStore.lua","Builtin/Definitions.lua","Builtin/Shared/Support.lua",
        "Core/ProviderLocales.lua","Core/ContextStore.lua","Search/RuntimeIdentity.lua","Search/Normalizer.lua",
        "Search/StaticIndex.lua","Core/Boundary.lua",
        "Core/ExtensionRegistry.lua","Search/QueryOrchestrator.lua","Core/ProviderRuntime.lua","PublicAPI/SDK.lua"},
}
function M.Load(profile,extra,options)
    options=options or {}
    local root=options.root or "package/Lychee/"
    local selected={}
    if profile then for _,path in ipairs(assert(profiles[profile],"Unknown test profile")) do selected[path]=true end end
    for _,path in ipairs(extra or {}) do selected[path]=true end
    if selected["UI/ResultList.lua"] or selected["Secure/SecureActionBroker.lua"] then selected["Core/InteractionBinding.lua"]=true end
    local loaded={}
    for line in io.lines(root..(options.toc or "Lychee_Mainline.toc")) do
        local path=line:gsub("\r$","")
        if profile=="provider" and (path=="Core/Resources.lua" or path=="Core/ProviderData.lua") then selected[path]=true end
        if path=="Search/ResultSnapshot.lua" and selected["Search/QueryOrchestrator.lua"] then selected[path]=true end
        if path=="Core/ProviderManagement.lua" and profile=="provider" then selected[path]=true end
        if path=="Builtin/Shared/CatalogLedger.lua" and (selected["Builtin/Shared/CatalogProvider.lua"] or selected["Builtin/Mounts/Provider.lua"] or selected["Builtin/PlayerSpells/Provider.lua"]) then selected[path]=true end
        if selected[path] then
            selected[path]=nil;loaded[#loaded+1]=path
        end
    end
    assert(not next(selected),"Requested test module absent from TOC: "..tostring(next(selected)))
    for _,path in ipairs(loaded) do
        if options.load then options.load(path)
        else dofile(options.overrides and options.overrides[path] or root..path) end
    end
    return loaded
end
return M
