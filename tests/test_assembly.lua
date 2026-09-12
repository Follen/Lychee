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
assert(not order["UI/Palette.lua"] and not order["Core/CommandCatalog.lua"])
local calls=0
local ok=pcall(loader.Load,"provider",{"missing.lua"},{load=function() calls=calls+1 end})
assert(not ok and calls==0,"missing modules fail before any partial initialization")
assert(not pcall(loader.Load,"unknown"))
local search=loader.Load("search",nil,{load=function(path) assert(path:match("^Search/")) end})
assert(#search==3)
assert(not _G.LycheeInternal,"assembly itself installs no globals or mocks")
print("Test assembly PASS: actual TOC order, independent prerequisites, fail-before-load, isolated profiles")
