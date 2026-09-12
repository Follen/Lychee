-- Callable SDK example; no automatic registration or load-time game work.
return function(sdk, id, items)
    assert(sdk:Supports(2,7),"Lychee SDK revision 7 required")
    return sdk:RegisterProvider({
        id=id,title="Managed example",version="1",apiVersion=2,minApiRevision=7,
        scope={products={"retail"}},i18n={enUS={NAME="Managed example"}},entries={},
        onEnable=function(handle)
            local resources=assert(handle:Resources())
            local settings=assert(handle:Settings())
            local cache=assert(resources:Cache("preview",{entries=8,bytes=8192}))
            assert(resources:OnEvent("PLAYER_LEVEL_UP",function()
                -- Same-frame events replace this pending refresh.
                assert(resources:After("refresh",0,function()
                    cache:Clear()
                    settings:Set("lastRefresh",true)
                end))
            end))
        end,
        query=function(_,reply,context)
            local token,err=context.resources:Run("scan",function()
                local results={}
                for index=1,math.min(#items,20) do
                    results[#results+1]={id=items[index].id,title=items[index].title}
                    if index%8==0 then coroutine.yield() end
                end
                return results
            end,{complete=reply,error=function() reply({}) end,combat=function() reply({}) end})
            if not token then error(err.code) end
            -- The Host owns this query scope; no duplicated cancellation state.
        end,
    })
end
