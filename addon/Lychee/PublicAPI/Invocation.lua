local I = _G.LycheeInternal
local API = {}
for _,name in ipairs({"ValidateSchema","NormalizeArgs","ParsePatterns","NormalizeStoredRef","Equal","ToInvocation","Release","Invoke","BeginEdit"}) do
 local method=name
 API[method]=function(_,...) return I.Invocations[method](I.Invocations,...) end
end
function API:Prepare(providerID,actionID,target,args,context,reply)
 return I.Invocations:PrepareAvailable(providerID,actionID,target,args,context,reply)
end
function API:PrepareStoredRef(ref,context,reply)
 local normalized,err=I.Invocations:NormalizeStoredRef(ref);if not normalized then return nil,err end
 if normalized.kind~="invocation" then return nil,{code="INCOMPLETE_INVOCATION"} end
 if normalized.product~=I.Search.RuntimeIdentity:Current().product then return nil,{code="INCOMPATIBLE_PRODUCT"} end
 return I.Invocations:PrepareAvailable(normalized.providerID,normalized.actionID,normalized.target,normalized.args,context,reply,normalized.actionVersion)
end
_G.Lychee.SDK.Invocation=API
function _G.Lychee:PrepareInvocation(...) return API:Prepare(...) end
function _G.Lychee:InvokeInvocation(...) return I.Invocations:Invoke(...) end
