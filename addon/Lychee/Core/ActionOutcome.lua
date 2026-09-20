local I=_G.LycheeInternal
local O={}
I.ActionOutcome=O
-- Execution confirmation, not a click or a displayed cooldown, grants history.
function O:Status(result)
    if type(result)=="table" then
        if result.status then return result.status end
        if result.attempted then return "attempted" end
        if result.pending or result.awaitingHardwareClick then return "pending" end
        if result.cancelled then return "cancelled" end
        if result.indeterminate then return "indeterminate" end
        if result.ok then return "succeeded" end
    elseif result==true then return "succeeded" end
    return "failed"
end
function O:RememberEntry(status,item,actionID,result,query)
    if status~="succeeded" or not I.UserPreferences then return false end
    local ok,ref=I.UserPreferences:TouchRecent(item,actionID,result)
    if not ok then return false end
    if query and I.Search.Personalization then
        local remembered=item
        if ref and (ref.actionID or ref.kind) then
            remembered={};for key,value in pairs(item) do remembered[key]=value end;remembered.ref=ref
        end
        I.Search.Personalization:Remember(query,remembered)
    end
    return true
end
function O:RememberInvocation(status,invocation,display)
    if status~="succeeded" or not I.UserPreferences then return false end
    return I.UserPreferences:TouchInvocation(invocation,display)
end
