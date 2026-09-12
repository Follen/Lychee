-- Independent expectations: this test does not execute the selected product code.
local loader=dofile("tests/support/runtime.lua")
local order={}
local paths=loader.Load("provider",nil,{load=function(path)
    assert(not order[path],"each module loads once");order[path]=#order+1;order[#order+1]=path
end})
assert(#paths==#order)
assert(order["Bootstrap.lua"]==1)
assert(order["Core/Boundary.lua"]<order["Core/Resources.lua"])
assert(order["Core/Resources.lua"]<order["Core/ProviderRuntime.lua"])
assert(order["Core/ProviderData.lua"]<order["Core/ProviderRuntime.lua"])
assert(order["Core/ProviderRuntime.lua"]<order["PublicAPI/SDK.lua"])
assert(order["Search/ResultSnapshot.lua"]<order["Search/QueryOrchestrator.lua"])
assert(order["Core/ProviderRuntime.lua"]<order["Core/ProviderManagement.lua"])
assert(not order["UI/Palette.lua"] and not order["Core/CommandCatalog.lua"])
local calls=0
local ok=pcall(loader.Load,"provider",{"missing.lua"},{load=function() calls=calls+1 end})
assert(not ok and calls==0,"missing modules fail before any partial initialization")
assert(not pcall(loader.Load,"unknown"))
for _,path in ipairs({"Core/Modules.lua","Core/ProviderManifest.lua","Shared/Support.lua","Shared/CatalogProvider.lua"}) do
    local invoked=0
    assert(not pcall(loader.Load,"provider",{path},{load=function() invoked=invoked+1 end}),"retired paths must not be silently ignored: "..path)
    assert(invoked==0,"invalid selectors fail before loading")
end
local search=loader.Load("search",nil,{load=function(path) assert(path:match("^Search/")) end})
assert(#search==3)
assert(not _G.LycheeInternal,"assembly itself installs no globals or mocks")
print("Test assembly PASS: actual TOC order, independent prerequisites, fail-before-load, isolated profiles")
