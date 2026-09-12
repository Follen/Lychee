-- Real delivered TOCs, independent private namespaces, no optional engine APIs.
function CreateFrame()
 return {RegisterEvent=function() end,UnregisterEvent=function() end,UnregisterAllEvents=function() end,SetScript=function(self,key,fn) self[key]=fn end}
end
function InCombatLockdown() return false end
local clients={{"Mainline",1,120100,"retail"},{"Mists",19,50504,"classic"},{"Wrath",11,38002,"titan"},{"TBC",5,20506,"anniversary"}}
local names={"Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"}
for _,client in ipairs(clients) do
 for _,locale in ipairs({"enUS","zhCN"}) do
  LycheeInternal,Lychee,LycheeDB,LycheeCharacterDB,LycheePlayerCharacterDB=nil,nil,nil,nil,nil
  WOW_PROJECT_ID=client[2]
  GetLocale=function() return locale end
  GetBuildInfo=function() return "fixture","70000","",client[3] end
  local loader=dofile("tests/support/package_loader.lua")
  local host=loader:Load("Lychee",client[1])
  assert(host.Search.RuntimeIdentity.product==client[4])
  assert(host.Modules==nil and host.ProviderLocaleData==nil)
  for _,name in ipairs(names) do
   local ns=loader:Load(name,client[1])
   assert(ns~=host)
   if ns.Modules then
    local calls={}
    for key,module in pairs(ns.Modules) do
     if type(module)=="table" and type(module.Init)=="function" then
      module.Init=function() calls[key]=(calls[key] or 0)+1 end
     end
    end
    ns:Initialize();ns:Initialize()
    for _,definition in ipairs(ns.Modules.Definitions) do
     local allowed=ns.Modules.Support:Available(definition,client[4])
     assert(calls[definition.module]==(allowed and 1 or nil),name.." / "..definition.id)
     assert(not ns.Modules.Support:Available(definition,"unknown"))
    end
   end
  end
  assert(not (host.Host and host.Host.PaletteController))
  assert(LycheePlayerCharacterDB==nil,"TOC loading does not initialize saved variables")
  if client[4]~="retail" then assert(loader.namespaces.Lychee_Encounters.Modules==nil) end
  for _,path in ipairs(loader.loaded) do assert(not path:find("..",1,true)) end
 end
end
print("Shipped five-package TOCs PASS: 4 clients x 2 languages, private namespaces, capability dispatch, no premature UI/SV")
