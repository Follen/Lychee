-- Test assembly follows real TOCs and private AddOn namespaces.
local M={}
local profiles={
 search={"Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua"},
 provider={"Bootstrap.lua","Core/CharacterStore.lua","Core/ProviderLocales.lua","Core/ContextStore.lua",
 "Search/RuntimeIdentity.lua","Search/Normalizer.lua","Search/StaticIndex.lua","Search/ProviderPolicy.lua","Core/Boundary.lua",
 "Core/RecordCodec.lua","Core/Catalog.lua","Core/Resources.lua","Core/ProviderData.lua",
 "Core/ExtensionRegistry.lua","Search/ResultSnapshot.lua","Search/QueryOrchestrator.lua",
 "Core/ProviderRuntime.lua","Core/ProviderManagement.lua","PublicAPI/SDK.lua"},
}
local packages={"Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"}
function M.Load(profile,extra,options)
 options=options or {}
 local root=options.root or "addon/Lychee/"
 local selected,children={},{}
 if profile then for _,path in ipairs(assert(profiles[profile],"Unknown test profile")) do selected[path]=true end end
 for _,path in ipairs(extra or {}) do
  local name,relative=path:match("^%.%./(Lychee_[^/]+)/(.+)$")
  if name then children[name]=children[name] or {};children[name][relative]=true
  elseif path~="Core/Modules.lua" and path~="Core/ProviderManifest.lua" and path~="Shared/Support.lua" then selected[path]=true end
 end
 if selected["UI/ResultList.lua"] or selected["Secure/SecureActionBroker.lua"] then selected["Core/InteractionBinding.lua"]=true end
 if selected["Shared/CatalogProvider.lua"] or selected["Shared/CatalogLedger.lua"] or selected["Shared/InterfaceActions.lua"] then
  for _,name in ipairs({"Lychee_Player","Lychee_Encounters"}) do
   if children[name] then
    for _,file in ipairs({"CatalogProvider.lua","CatalogLedger.lua","InterfaceActions.lua"}) do children[name]["Runtime/"..file]=true end
   end
  end
  selected["Shared/CatalogProvider.lua"],selected["Shared/CatalogLedger.lua"],selected["Shared/InterfaceActions.lua"]=nil,nil,nil
 end
 local loaded={}
 for line in io.lines(root..(options.toc or "Lychee_Mainline.toc")) do
  local path=line:gsub("\r$","")
  if selected[path] then selected[path]=nil;loaded[#loaded+1]=path end
 end
 assert(not next(selected),"Requested test module absent from TOC: "..tostring(next(selected)))
 for _,name in ipairs(packages) do
  local set=children[name]
  if set then
   set["Bootstrap.lua"],set["Manifest.lua"]=true,true
   if name=="Lychee_Player" then set["SDK/Storage.lua"],set["Storage.lua"]=true,true end
   if set["Mounts/Provider.lua"] or set["PlayerSpells/Provider.lua"] then set["Runtime/CatalogLedger.lua"]=true end
   if set["Runtime/CatalogProvider.lua"] then set["Runtime/CatalogLedger.lua"]=true end
   for line in io.lines(root.."../"..name.."/"..name.."_"..(options.toc and options.toc:match("_(%w+)%.toc") or "Mainline")..".toc") do
    local path=line:gsub("\r$","")
    if path:match("Locales.lua$") or set[path] then set[path]=nil;loaded[#loaded+1]="../"..name.."/"..path end
   end
   assert(not next(set),"Requested child module absent from TOC: "..tostring(next(set)))
  end
 end
 if options.load then for _,path in ipairs(loaded) do options.load(path) end;return loaded end
 if profile=="provider" or not _G.TestPackages then
  _G.TestPackages={namespaces={},Modules={}}
  function TestPackages:File(path)
   local name=assert(path:match("(Lychee_[^/]+)/"))
   local ns=assert(self.namespaces[name],"Load the private namespace first")
   assert(loadfile(path))(name,ns);self:Refresh()
  end
  function TestPackages:Refresh()
   for _,namespace in pairs(self.namespaces) do for key,value in pairs(namespace.Modules or {}) do self.Modules[key]=value end end
  end
  function TestPackages.Modules:Init()
   for _,name in ipairs(packages) do local ns=TestPackages.namespaces[name];if ns then ns:Initialize() end end
  end
 end
 for _,path in ipairs(loaded) do
  local name,relative=path:match("^%.%./(Lychee_[^/]+)/(.+)$")
  local file=options.overrides and options.overrides[path] or root..path
  if name then
   local ns=TestPackages.namespaces[name]
   if not ns then ns={};TestPackages.namespaces[name]=ns end
   if relative~="Bootstrap.lua" or not ns.SDK then assert(loadfile(file))(name,ns) end
   if relative=="Storage.lua" then ns.savedVariablesReady=true;ns.Store:Initialize() end
  else dofile(file) end
  if options.afterLoad then options.afterLoad(path) end
 end
 TestPackages:Refresh()
 return loaded
end
return M
