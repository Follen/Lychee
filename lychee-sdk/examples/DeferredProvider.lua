-- Runnable module example: register a query-only catalog with delayed completion.
-- Supply string-title entries (actions={"open"}) and an ordinary onOpen callback.
-- The 0.1-second timer stands in for an integration's event/asynchronous source.
return function(SDK, providerID, entries, onOpen)
    if not SDK or not SDK:Supports("1.0.0") then return nil,{code="UNSUPPORTED_API"} end
    local byID={}
    for _, entry in ipairs(entries) do byID[entry.id]=entry end
    return SDK:RegisterProvider({
        id=providerID,apiVersion="1.0.0",version="2.2.0",title={key="TITLE"},
        scope={products={"retail"}},
        i18n={enUS={TITLE="Deferred catalog",OPEN="Open"},zhCN={TITLE="延迟目录",OPEN="打开"}},
        actions={open={title={key="OPEN"},run=onOpen}},
        query=function(request,reply)
            local rank=assert(SDK.SDK.CreateRanker(request))
            local timer=C_Timer.NewTimer(0.1,function()
                local results,weights={},{}
                for _, entry in ipairs(entries) do
                    local match=SDK.SDK.Normalizer:MatchRecord(request.normalized,entry)
                    if match then
                        local value=rank(entry.id,match.confidence)
                        local at=#results+1
                        for index,hit in ipairs(results) do
                            if value>weights[index] or value==weights[index] and
                                (match.confidence>hit.confidence or match.confidence==hit.confidence and entry.id<hit.entry.id) then at=index;break end
                        end
                        if at<=request.limit then
                            table.insert(results,at,{entry=entry,confidence=match.confidence,evidence=match})
                            table.insert(weights,at,value)
                            if #results>request.limit then results[#results]=nil;weights[#weights]=nil end
                        end
                    end
                end
                reply(results)
            end)
            return function() timer:Cancel() end
        end,
        resolve=function(entryID) return byID[entryID] end,
    })
end
