-- Callable SDK example; no automatic registration or load-time game work.
-- settings is created by the caller with SDK Storage.Open and its own SV root.
return function(sdk, id, items, settings)
    assert(sdk:Supports("1.0.0"),"Lychee SDK 1.0.0 / API 1.0.0 required")
    return sdk:RegisterProvider({
        id=id,title="Managed example",version="1",apiVersion="1.0.0",scope={products={"retail"}},i18n={enUS={NAME="Managed example"}},
        onEnable=function(handle)
            local resources=assert(handle:Resources())
            assert(settings,"AddOn-owned settings required")
            local cache=assert(resources:Cache("preview",{entries=8,bytes=8192}))
            assert(resources:OnEvent("PLAYER_LEVEL_UP",function()
                -- Same-frame events replace this pending refresh.
                assert(resources:After("refresh",0,function()
                    cache:Clear()
                    settings:Set("lastRefresh",true)
                end))
            end))
        end,
        query=function(request,reply,context)
            local token,err=context.resources:Run("scan",function()
                local results={}
                for index=1,math.min(#items,20) do
                    results[#results+1]={id=items[index].id,title=items[index].title}
                    if index%8==0 then coroutine.yield() end
                end
                return results
            end,{complete=function(rows) reply(assert(sdk.SDK.Score(request,rows))) end,error=function() reply({}) end,combat=function() reply({}) end})
            if not token then error(err.code) end
            -- The Host owns this query scope; no duplicated cancellation state.
        end,
    })
end
