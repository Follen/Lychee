-- Real TOCs, real AddOn argument namespaces. No business or lifecycle mocks.
local Loader={namespaces={},loaded={}}
function Loader:Load(name,suffix,options)
    options=options or {}
    local namespace={};self.namespaces[name]=namespace
    local root=options.root or "addon/"
    for line in io.lines(root..name.."/"..name.."_"..(suffix or "Mainline")..".toc") do
        local path=line:gsub("\r$","")
        if path~="" and path:sub(1,1)~="#" then
            assert(not path:find("..",1,true),"TOC escapes AddOn")
            self.loaded[#self.loaded+1]=name.."/"..path
            assert(loadfile(root..name.."/"..path))(name,namespace)
        end
    end
    return namespace
end
function Loader:Ready(name)
    assert(LycheeInternal and LycheeInternal.DeliverAddonLoaded)
    LycheeInternal.DeliverAddonLoaded(name)
end
return Loader
