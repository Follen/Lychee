-- Runnable module example: register a query-only catalog with delayed completion.
-- Supply string-title entries (actions={"open"}) and an ordinary onOpen callback.
-- The 0.1-second timer stands in for an integration's event/asynchronous source.
return function(SDK, providerID, entries, onOpen)
    if not SDK or not SDK:Supports(3,1) then return nil,{code="UNSUPPORTED_API"} end
    local byID={}
    for _, entry in ipairs(entries) do byID[entry.id]=entry end
    return SDK:RegisterProvider({
        id=providerID,apiVersion=3,minApiRevision=1,version="2.2.0",title={key="TITLE"},
        scope={products={"retail"}},
        i18n={enUS={TITLE="Deferred catalog",OPEN="Open"},zhCN={TITLE="延迟目录",OPEN="打开"}},
        actions={open={title={key="OPEN"},run=onOpen}},
        query=function(request,reply)
            local timer=C_Timer.NewTimer(0.1,function()
                local results={}
                for _, entry in ipairs(entries) do
                    if type(entry.title)=="string" and entry.title:lower():find(request.raw:lower(),1,true) then
                        results[#results+1]=entry
                        if #results>=request.limit then break end
                    end
                end
                reply(assert(SDK.SDK.Score(request,results)))
            end)
            return function() timer:Cancel() end
        end,
        resolve=function(entryID) return byID[entryID] end,
    })
end
